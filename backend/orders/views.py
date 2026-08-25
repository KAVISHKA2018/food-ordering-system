from django.utils import timezone
from rest_framework import viewsets, permissions, status
from rest_framework.response import Response
from rest_framework.decorators import action
from .models import Order, TableSession, Payment
from .serializers import OrderSerializer, OrderCreateSerializer, TableSessionSerializer, PaymentSerializer
from .permissions import IsOrderOwnerOrRestaurantStaff
from notifications.fcm import send_push_notification


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
        """Customer taps Pay Now (Takeaway) — this only REQUESTS payment.
        The restaurant admin must confirm cash received via confirm_payment."""
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
        """Restaurant admin confirms cash payment received for a Takeaway order."""
        order = self.get_object()
        if order.restaurant.owner != request.user:
            return Response({"detail": "Only the restaurant owner can confirm payment."}, status=status.HTTP_403_FORBIDDEN)

        payment = order.payments.filter(status=Payment.Status.PENDING).order_by('-created_at').first()
        if not payment:
            return Response({"detail": "No pending payment to confirm for this order."}, status=status.HTTP_400_BAD_REQUEST)

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
        """The customer's currently open (or awaiting payment confirmation) table sessions."""
        sessions = TableSession.objects.filter(
            customer=request.user,
            status__in=[TableSession.Status.OPEN, TableSession.Status.PAYMENT_PENDING],
        )
        return Response(TableSessionSerializer(sessions, many=True).data)

    @action(detail=True, methods=['post'], permission_classes=[permissions.IsAuthenticated])
    def pay(self, request, pk=None):
        """Customer taps Pay Now for the whole table — only REQUESTS payment.
        The restaurant admin must confirm cash received via confirm_payment."""
        session = self.get_object()
        if session.customer != request.user:
            return Response({"detail": "Not your table session."}, status=status.HTTP_403_FORBIDDEN)
        if session.status != TableSession.Status.OPEN:
            return Response({"detail": "This table session is not open."}, status=status.HTTP_400_BAD_REQUEST)

        Payment.objects.create(
            table_session=session,
            amount=session.total_amount,
            method=Payment.Method.MOCK,
            status=Payment.Status.PENDING,
        )
        session.status = TableSession.Status.PAYMENT_PENDING
        session.save()

        send_push_notification(
            session.customer,
            title="Payment Confirmed",
            body=f"Your payment for Table {session.table_number} has been confirmed. Thank you!",
            data={'type': 'table_session', 'id': session.id},
        )
        
        return Response(TableSessionSerializer(session).data)

    @action(detail=True, methods=['post'], permission_classes=[permissions.IsAuthenticated])
    def confirm_payment(self, request, pk=None):
        """Restaurant admin confirms cash payment received for a table's bill.
        If this table session came from a reservation, that reservation is
        automatically marked Completed at the same time."""
        session = self.get_object()
        if session.restaurant.owner != request.user:
            return Response({"detail": "Only the restaurant owner can confirm payment."}, status=status.HTTP_403_FORBIDDEN)

        payment = session.payments.filter(status=Payment.Status.PENDING).order_by('-created_at').first()
        if not payment:
            return Response({"detail": "No pending payment to confirm for this table."}, status=status.HTTP_400_BAD_REQUEST)

        payment.status = Payment.Status.COMPLETED
        payment.paid_at = timezone.now()
        payment.save()

        session.status = TableSession.Status.PAID
        session.save()

        # If this table session originated from a reservation, close it out too.
        linked_reservations = session.reservations.exclude(
            status__in=['COMPLETED', 'CANCELLED', 'NO_SHOW']
        )
        for reservation in linked_reservations:
            reservation.status = 'COMPLETED'
            reservation.save()
            send_push_notification(
                reservation.customer,
                title="Reservation Completed",
                body=f"Your payment has been confirmed. Thank you for dining with us!",
                data={'type': 'reservation', 'id': reservation.id},
            )

        send_push_notification(
            session.customer,
            title="Payment Confirmed",
            body=f"Your payment for Table {session.table_number} has been confirmed. Thank you!",
            data={'type': 'table_session', 'id': session.id},
        )

        return Response(TableSessionSerializer(session).data)