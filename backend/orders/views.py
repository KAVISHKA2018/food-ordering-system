from django.utils import timezone
from rest_framework import viewsets, permissions, status
from rest_framework.response import Response
from rest_framework.decorators import action
from .models import Order, TableSession, Payment
from .serializers import OrderSerializer, OrderCreateSerializer, TableSessionSerializer, PaymentSerializer
from .permissions import IsOrderOwnerOrRestaurantStaff


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

        order.status = new_status
        order.save()
        return Response(OrderSerializer(order).data)

    @action(detail=True, methods=['post'], permission_classes=[permissions.IsAuthenticated])
    def pay(self, request, pk=None):
        """Mock payment for a single order — used for Takeaway.
        Moves the order from AWAITING_PAYMENT to PENDING so the kitchen sees it."""
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
            status=Payment.Status.COMPLETED,
            paid_at=timezone.now(),
        )
        order.status = Order.Status.PENDING
        order.save()
        return Response(OrderSerializer(order).data)


class TableSessionViewSet(viewsets.ReadOnlyModelViewSet):
    serializer_class = TableSessionSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        user = self.request.user
        if user.role == 'RESTAURANT_ADMIN':
            return TableSession.objects.filter(restaurant__owner=user)
        return TableSession.objects.filter(customer=user)

    @action(detail=False, methods=['get'], permission_classes=[permissions.IsAuthenticated])
    def active(self, request):
        """The customer's currently open table sessions (their running tabs)."""
        sessions = TableSession.objects.filter(customer=request.user, status=TableSession.Status.OPEN)
        return Response(TableSessionSerializer(sessions, many=True).data)

    @action(detail=True, methods=['post'], permission_classes=[permissions.IsAuthenticated])
    def pay(self, request, pk=None):
        """Mock 'Pay Now' for a dine-in table — pays the accumulated total
        across all orders in this session."""
        session = self.get_object()
        if session.customer != request.user:
            return Response({"detail": "Not your table session."}, status=status.HTTP_403_FORBIDDEN)
        if session.status != TableSession.Status.OPEN:
            return Response({"detail": "This table session is not open."}, status=status.HTTP_400_BAD_REQUEST)

        Payment.objects.create(
            table_session=session,
            amount=session.total_amount,
            method=Payment.Method.MOCK,
            status=Payment.Status.COMPLETED,
            paid_at=timezone.now(),
        )
        session.status = TableSession.Status.PAID
        session.save()
        return Response(TableSessionSerializer(session).data)