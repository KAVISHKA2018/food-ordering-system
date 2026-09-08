from django.utils import timezone
from django.conf import settings
from django.http import HttpResponse
from django.shortcuts import get_object_or_404
from django.views.decorators.csrf import csrf_exempt
from django.utils.decorators import method_decorator
from rest_framework import viewsets, permissions, status
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.decorators import action
import stripe
from .models import Order, TableSession, Payment
from .serializers import OrderSerializer, OrderCreateSerializer, TableSessionSerializer, PaymentSerializer
from .permissions import IsOrderOwnerOrRestaurantStaff
from .stripe_gateway import create_checkout_session
from notifications.fcm import send_push_notification

from django.db.models import Sum, Count
from django.db.models.functions import TruncDate
from datetime import datetime, timedelta
from .models import Order, TableSession, Payment, OrderItem


def _complete_order_payment(payment):
    order = payment.order
    payment.status = Payment.Status.COMPLETED
    payment.paid_at = timezone.now()
    payment.save()

    order.status = Order.Status.PENDING
    order.save()

    send_push_notification(
        order.customer,
        title="Payment Confirmed",
        body=f"Your payment for order #{order.id} has been confirmed. It's now being prepared.",
        data={'type': 'order', 'id': order.id},
    )


def _complete_table_session_payment(payment):
    session = payment.table_session
    payment.status = Payment.Status.COMPLETED
    payment.paid_at = timezone.now()
    payment.save()

    session.status = TableSession.Status.PAID
    session.save()

    linked_reservations = session.reservations.exclude(
        status__in=['COMPLETED', 'CANCELLED', 'NO_SHOW']
    )
    for reservation in linked_reservations:
        reservation.status = 'COMPLETED'
        reservation.save()
        send_push_notification(
            reservation.customer,
            title="Reservation Completed",
            body="Your payment has been confirmed. Thank you for dining with us!",
            data={'type': 'reservation', 'id': reservation.id},
        )

    send_push_notification(
        session.customer,
        title="Payment Confirmed",
        body=f"Your payment for Table {session.table_number} has been confirmed. Thank you!",
        data={'type': 'table_session', 'id': session.id},
    )


class OrderViewSet(viewsets.ModelViewSet):
    permission_classes = [permissions.IsAuthenticated, IsOrderOwnerOrRestaurantStaff]

    def get_serializer_class(self):
        if self.action == 'create':
            return OrderCreateSerializer
        return OrderSerializer

    def get_queryset(self):
        user = self.request.user
        if user.role == 'RESTAURANT_ADMIN':
            return Order.objects.filter(restaurant__owner=user)
        return Order.objects.filter(customer=user)

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        order = serializer.save()
        return Response(OrderSerializer(order).data, status=status.HTTP_201_CREATED)

    @action(detail=True, methods=['patch'], permission_classes=[permissions.IsAuthenticated])
    def update_status(self, request, pk=None):
        order = self.get_object()
        if order.restaurant.owner != request.user:
            return Response(
                {"detail": "Only the restaurant owner can update order status."},
                status=status.HTTP_403_FORBIDDEN
            )
        new_status = request.data.get('status')
        valid_statuses = [choice[0] for choice in Order.Status.choices]
        if new_status not in valid_statuses:
            return Response({"detail": "Invalid status."}, status=status.HTTP_400_BAD_REQUEST)

        if new_status == Order.Status.OUT_FOR_DELIVERY and order.order_type != Order.OrderType.DELIVERY:
            return Response(
                {"detail": "Only Delivery orders can be marked Out for Delivery."},
                status=status.HTTP_400_BAD_REQUEST
            )

        order.status = new_status
        order.save()

        send_push_notification(
            order.customer,
            title=f"Order #{order.id} Update",
            body=f"Your order is now {order.get_status_display()}.",
            data={'type': 'order', 'id': order.id},
        )

        return Response(OrderSerializer(order).data)

    @action(detail=True, methods=['post'], permission_classes=[permissions.IsAuthenticated])
    def pay(self, request, pk=None):
        order = self.get_object()
        if order.customer != request.user:
            return Response({"detail": "Not your order."}, status=status.HTTP_403_FORBIDDEN)
        if order.status != Order.Status.AWAITING_PAYMENT:
            return Response(
                {"detail": "This order is not awaiting payment."},
                status=status.HTTP_400_BAD_REQUEST
            )

        Payment.objects.create(
            order=order,
            amount=order.total_amount,
            method=Payment.Method.MOCK,
            status=Payment.Status.PENDING,
        )
        order.status = Order.Status.PAYMENT_PENDING
        order.save()
        return Response(OrderSerializer(order).data)

    @action(detail=True, methods=['post'], permission_classes=[permissions.IsAuthenticated])
    def confirm_payment(self, request, pk=None):
        order = self.get_object()
        if order.restaurant.owner != request.user:
            return Response({"detail": "Only the restaurant owner can confirm payment."}, status=status.HTTP_403_FORBIDDEN)

        payment = order.payments.filter(status=Payment.Status.PENDING).order_by('-created_at').first()
        if not payment:
            return Response({"detail": "No pending payment to confirm for this order."}, status=status.HTTP_400_BAD_REQUEST)

        _complete_order_payment(payment)
        return Response(OrderSerializer(order).data)

    @action(detail=True, methods=['post'], permission_classes=[permissions.IsAuthenticated])
    def cancel(self, request, pk=None):
        """Customer cancels their own order — only allowed while it hasn't
        been confirmed/started by the kitchen yet. Restocks any items that
        weren't sold after all, and marks any pending payment as failed."""
        order = self.get_object()
        if order.customer != request.user:
            return Response({"detail": "Not your order."}, status=status.HTTP_403_FORBIDDEN)

        cancellable_statuses = [
            Order.Status.AWAITING_PAYMENT,
            Order.Status.PAYMENT_PENDING,
            Order.Status.PENDING,
        ]
        if order.status not in cancellable_statuses:
            return Response(
                {"detail": "This order can no longer be cancelled."},
                status=status.HTTP_400_BAD_REQUEST
            )

        order.status = Order.Status.CANCELLED
        order.save()

        for item in order.items.all():
            if item.menu_item and not item.variant:
                item.menu_item.stock_quantity += item.quantity
                item.menu_item.save()

        Payment.objects.filter(order=order, status=Payment.Status.PENDING).update(
            status=Payment.Status.FAILED
        )

        return Response(OrderSerializer(order).data)

    @action(detail=False, methods=['get'])
    def active_count(self, request):
        count = self.get_queryset().exclude(status__in=['COMPLETED', 'CANCELLED']).count()
        return Response({'count': count})

    @action(detail=True, methods=['post'], permission_classes=[permissions.IsAuthenticated])
    def request_cash(self, request, pk=None):
        """Lets the customer switch an unpaid Card order over to Cash,
        without cancelling and recreating it. Reuses the same pending
        Payment record — just changes its method — exactly matching what
        would have happened if Cash had been chosen at checkout time."""
        order = self.get_object()
        if order.customer != request.user:
            return Response({"detail": "Not your order."}, status=status.HTTP_403_FORBIDDEN)
        if order.status != Order.Status.AWAITING_PAYMENT:
            return Response(
                {"detail": "This order is not awaiting payment."},
                status=status.HTTP_400_BAD_REQUEST
            )

        payment = order.payments.filter(status=Payment.Status.PENDING).order_by('-created_at').first()
        if not payment:
            return Response({"detail": "No pending payment found for this order."}, status=status.HTTP_400_BAD_REQUEST)

        payment.method = Payment.Method.CASH
        payment.save()

        order.status = Order.Status.PAYMENT_PENDING
        order.save()

        return Response(OrderSerializer(order).data)


class TableSessionViewSet(viewsets.ReadOnlyModelViewSet):
    serializer_class = TableSessionSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        user = self.request.user
        if user.role == 'RESTAURANT_ADMIN':
            return TableSession.objects.filter(restaurant__owner=user).order_by('-created_at')
        return TableSession.objects.filter(customer=user).order_by('-created_at')

    @action(detail=False, methods=['get'], permission_classes=[permissions.IsAuthenticated])
    def active(self, request):
        sessions = TableSession.objects.filter(
            customer=request.user,
            status__in=[TableSession.Status.OPEN, TableSession.Status.PAYMENT_PENDING],
        )
        return Response(TableSessionSerializer(sessions, many=True).data)

    @action(detail=True, methods=['post'], permission_classes=[permissions.IsAuthenticated])
    def pay(self, request, pk=None):
        """payment_method: 'CASH' or 'CARD'. Reuses an existing pending
        payment for this session if one already exists (e.g. a previously
        abandoned card attempt) instead of creating a duplicate."""
        session = self.get_object()
        if session.customer != request.user:
            return Response({"detail": "Not your table session."}, status=status.HTTP_403_FORBIDDEN)
        if session.status != TableSession.Status.OPEN:
            return Response({"detail": "This table session is not open."}, status=status.HTTP_400_BAD_REQUEST)

        payment_method = request.data.get('payment_method', 'CASH')
        method = Payment.Method.CASH if payment_method == 'CASH' else Payment.Method.CARD

        payment = session.payments.filter(status=Payment.Status.PENDING).order_by('-created_at').first()
        if payment:
            payment.method = method
            payment.amount = session.total_amount
            payment.save()
        else:
            payment = Payment.objects.create(
                table_session=session,
                amount=session.total_amount,
                method=method,
                status=Payment.Status.PENDING,
            )

        if payment_method == 'CASH':
            session.status = TableSession.Status.PAYMENT_PENDING
            session.save()
            send_push_notification(
                session.customer,
                title="Payment Confirmed",
                body=f"Your payment for Table {session.table_number} has been confirmed. Thank you!",
                data={'type': 'table_session', 'id': session.id},
            )

        return Response({**TableSessionSerializer(session).data, 'payment_id': payment.id})

    @action(detail=True, methods=['post'], permission_classes=[permissions.IsAuthenticated])
    def confirm_payment(self, request, pk=None):
        session = self.get_object()
        if session.restaurant.owner != request.user:
            return Response({"detail": "Only the restaurant owner can confirm payment."}, status=status.HTTP_403_FORBIDDEN)

        payment = session.payments.filter(status=Payment.Status.PENDING).order_by('-created_at').first()
        if not payment:
            return Response({"detail": "No pending payment to confirm for this table."}, status=status.HTTP_400_BAD_REQUEST)

        _complete_table_session_payment(payment)
        return Response(TableSessionSerializer(session).data)

    @action(detail=False, methods=['get'])
    def active_count(self, request):
        count = self.get_queryset().filter(status__in=['OPEN', 'PAYMENT_PENDING']).count()
        return Response({'count': count})


class CreateCheckoutSessionView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, payment_id):
        payment = get_object_or_404(Payment, id=payment_id)
        target = payment.order or payment.table_session
        if target.customer != request.user:
            return Response({"detail": "Not your payment."}, status=status.HTTP_403_FORBIDDEN)
        if payment.status != Payment.Status.PENDING:
            return Response({"detail": "This payment is no longer pending."}, status=status.HTTP_400_BAD_REQUEST)

        restaurant = payment.order.restaurant if payment.order else payment.table_session.restaurant
        checkout_url = create_checkout_session(payment, restaurant.name)
        return Response({"checkout_url": checkout_url})


class StripeReturnView(APIView):
    permission_classes = [permissions.AllowAny]

    def get(self, request):
        return HttpResponse(
            "<html><body style='font-family:sans-serif;text-align:center;margin-top:60px;'>"
            "<h3>Payment completed</h3><p>You can close this window now.</p></body></html>"
        )


class StripeCancelView(APIView):
    permission_classes = [permissions.AllowAny]

    def get(self, request):
        return HttpResponse(
            "<html><body style='font-family:sans-serif;text-align:center;margin-top:60px;'>"
            "<h3>Payment cancelled</h3><p>You can close this window now.</p></body></html>"
        )


@method_decorator(csrf_exempt, name='dispatch')
class StripeWebhookView(APIView):
    permission_classes = [permissions.AllowAny]
    authentication_classes = []

    def post(self, request):
        payload = request.body
        sig_header = request.META.get('HTTP_STRIPE_SIGNATURE')

        try:
            event = stripe.Webhook.construct_event(payload, sig_header, settings.STRIPE_WEBHOOK_SECRET)
        except (ValueError, stripe.error.SignatureVerificationError):
            return Response({"detail": "Invalid signature"}, status=status.HTTP_400_BAD_REQUEST)

        if event['type'] == 'checkout.session.completed':
            session = event['data']['object']
            payment_id = session.client_reference_id or (session.metadata or {}).get('payment_id')

            payment = Payment.objects.filter(id=payment_id).first()
            if payment and payment.status == Payment.Status.PENDING:
                payment.gateway_payment_id = session.payment_intent or ''
                payment.save()

                if payment.order:
                    _complete_order_payment(payment)
                elif payment.table_session:
                    _complete_table_session_payment(payment)

        return Response({"detail": "OK"})


class PaymentStatusView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request, payment_id):
        payment = get_object_or_404(Payment, id=payment_id)
        target = payment.order or payment.table_session
        if target.customer != request.user:
            return Response({"detail": "Not yours."}, status=status.HTTP_403_FORBIDDEN)
        return Response({"status": payment.status})


class ReportsView(APIView):
    """Aggregated sales/analytics data for the restaurant admin's own
    restaurant, filterable by date range. One endpoint returns everything
    the Reports page needs, to avoid multiple round trips."""
    permission_classes = [permissions.IsAuthenticated]

    # Orders that have actually been paid for — used for revenue figures.
    # Orders still at AWAITING_PAYMENT/PAYMENT_PENDING haven't been paid
    # yet, and CANCELLED orders were never fulfilled.
    PAID_STATUSES = ['PENDING', 'CONFIRMED', 'PREPARING', 'READY', 'OUT_FOR_DELIVERY', 'COMPLETED']

    def get(self, request):
        if request.user.role != 'RESTAURANT_ADMIN':
            return Response({"detail": "Only restaurant admins can view reports."}, status=status.HTTP_403_FORBIDDEN)

        start_str = request.query_params.get('start_date')
        end_str = request.query_params.get('end_date')
        try:
            end_date = datetime.strptime(end_str, '%Y-%m-%d').date() if end_str else timezone.now().date()
            start_date = datetime.strptime(start_str, '%Y-%m-%d').date() if start_str else end_date - timedelta(days=29)
        except ValueError:
            return Response({"detail": "Invalid date format. Use YYYY-MM-DD."}, status=status.HTTP_400_BAD_REQUEST)

        qs = Order.objects.filter(
            restaurant__owner=request.user,
            created_at__date__gte=start_date,
            created_at__date__lte=end_date,
        )
        paid_qs = qs.filter(status__in=self.PAID_STATUSES)

        revenue_by_day = (
            paid_qs.annotate(day=TruncDate('created_at'))
            .values('day')
            .annotate(revenue=Sum('total_amount'))
            .order_by('day')
        )

        volume_by_day = (
            qs.annotate(day=TruncDate('created_at'))
            .values('day')
            .annotate(order_count=Count('id'), unique_customers=Count('customer', distinct=True))
            .order_by('day')
        )

        status_breakdown = qs.values('status').annotate(count=Count('id')).order_by('-count')

        payments_qs = Payment.objects.filter(
            order__restaurant__owner=request.user,
            order__created_at__date__gte=start_date,
            order__created_at__date__lte=end_date,
            status='COMPLETED',
        )
        payment_breakdown = payments_qs.values('method').annotate(
            count=Count('id'), total=Sum('amount')
        ).order_by('-total')

        top_items = (
            OrderItem.objects.filter(
                order__restaurant__owner=request.user,
                order__created_at__date__gte=start_date,
                order__created_at__date__lte=end_date,
                order__status__in=self.PAID_STATUSES,
            )
            .values('item_name')
            .annotate(quantity_sold=Sum('quantity'), revenue=Sum('subtotal'))
            .order_by('-quantity_sold')[:10]
        )

        summary = paid_qs.aggregate(total_revenue=Sum('total_amount'), total_orders=Count('id'))
        total_revenue = summary['total_revenue'] or 0
        total_orders = summary['total_orders'] or 0
        avg_order_value = (total_revenue / total_orders) if total_orders else 0

        return Response({
            'start_date': str(start_date),
            'end_date': str(end_date),
            'revenue_by_day': [{'date': str(r['day']), 'revenue': float(r['revenue'] or 0)} for r in revenue_by_day],
            'volume_by_day': [
                {'date': str(v['day']), 'order_count': v['order_count'], 'unique_customers': v['unique_customers']}
                for v in volume_by_day
            ],
            'status_breakdown': [{'status': s['status'], 'count': s['count']} for s in status_breakdown],
            'payment_breakdown': [
                {'method': p['method'], 'count': p['count'], 'total': float(p['total'] or 0)}
                for p in payment_breakdown
            ],
            'top_items': [
                {'item_name': i['item_name'], 'quantity_sold': i['quantity_sold'], 'revenue': float(i['revenue'] or 0)}
                for i in top_items
            ],
            'summary': {
                'total_revenue': float(total_revenue),
                'total_orders': total_orders,
                'avg_order_value': round(float(avg_order_value), 2),
            },
        })