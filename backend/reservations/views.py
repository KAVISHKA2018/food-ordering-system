from django.db import transaction
from django.utils import timezone
from rest_framework import viewsets, permissions, status
from rest_framework.response import Response
from rest_framework.decorators import action
from .models import Reservation
from .serializers import ReservationSerializer, ReservationCreateSerializer
from .permissions import IsReservationOwnerOrRestaurantStaff
from orders.models import TableSession, Order, OrderItem
from orders.serializers import normalize_table_number
from notifications.fcm import send_push_notification


class ReservationViewSet(viewsets.ModelViewSet):
    permission_classes = [permissions.IsAuthenticated, IsReservationOwnerOrRestaurantStaff]

    def get_serializer_class(self):
        if self.action == 'create':
            return ReservationCreateSerializer
        return ReservationSerializer

    def get_queryset(self):
        user = self.request.user
        if user.role == 'RESTAURANT_ADMIN':
            return Reservation.objects.filter(restaurant__owner=user)
        return Reservation.objects.filter(customer=user)

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        reservation = serializer.save()
        return Response(ReservationSerializer(reservation).data, status=status.HTTP_201_CREATED)

    @action(detail=True, methods=['patch'], permission_classes=[permissions.IsAuthenticated])
    def assign_table(self, request, pk=None):
        """Restaurant admin assigns a table number to a pending reservation.
        Must be done before the reservation can be confirmed."""
        reservation = self.get_object()
        if reservation.restaurant.owner != request.user:
            return Response(
                {"detail": "Only the restaurant owner can assign a table."},
                status=status.HTTP_403_FORBIDDEN
            )
        table_number = normalize_table_number(request.data.get('table_number', ''))
        if not table_number:
            return Response({"detail": "Table number is required."}, status=status.HTTP_400_BAD_REQUEST)

        reservation.table_number = table_number
        reservation.save()
        return Response(ReservationSerializer(reservation).data)

    @action(detail=True, methods=['patch'], permission_classes=[permissions.IsAuthenticated])
    @transaction.atomic
    def update_status(self, request, pk=None):
        """Restaurant admin updates reservation status (CONFIRMED, SEATED, COMPLETED, etc.)."""
        reservation = self.get_object()
        if reservation.restaurant.owner != request.user:
            return Response(
                {"detail": "Only the restaurant owner can update reservation status."},
                status=status.HTTP_403_FORBIDDEN
            )
        new_status = request.data.get('status')
        valid_statuses = [choice[0] for choice in Reservation.Status.choices]
        if new_status not in valid_statuses:
            return Response({"detail": "Invalid status."}, status=status.HTTP_400_BAD_REQUEST)

        if new_status == Reservation.Status.CONFIRMED and not reservation.table_number:
            return Response(
                {"detail": "Please assign a table before confirming this reservation."},
                status=status.HTTP_400_BAD_REQUEST
            )

        if new_status == Reservation.Status.SEATED and reservation.table_session is None:
            # First time being seated — open (or reuse) a table session, and
            # convert any pre-ordered food into a real, kitchen-visible order.
            table_session, _ = TableSession.objects.get_or_create(
                restaurant=reservation.restaurant,
                customer=reservation.customer,
                table_number=reservation.table_number,
                status=TableSession.Status.OPEN,
                defaults={},
            )
            reservation.table_session = table_session

            pre_order_items = reservation.pre_order_items.all()
            if pre_order_items.exists():
                order = Order.objects.create(
                    customer=reservation.customer,
                    restaurant=reservation.restaurant,
                    table_session=table_session,
                    reservation=reservation,
                    order_type=Order.OrderType.DINE_IN,
                    status=Order.Status.PENDING,
                )
                total = 0
                for pre_item in pre_order_items:
                    order_item = OrderItem.objects.create(
                        order=order,
                        menu_item=pre_item.menu_item,
                        item_name=pre_item.item_name,
                        quantity=pre_item.quantity,
                        unit_price=pre_item.unit_price,
                    )
                    total += order_item.subtotal
                order.total_amount = total
                order.save()

        reservation.status = new_status
        reservation.save()

        send_push_notification(
            reservation.customer,
            title="Reservation Update",
            body=f"Your reservation is now {reservation.get_status_display()}.",
            data={'type': 'reservation', 'id': reservation.id},
        )

        return Response(ReservationSerializer(reservation).data)

    @action(detail=False, methods=['get'], permission_classes=[permissions.IsAuthenticated])
    def upcoming(self, request):
        queryset = self.get_queryset().filter(
            reservation_date__gte=timezone.now().date()
        ).exclude(status__in=['CANCELLED', 'COMPLETED', 'NO_SHOW'])
        serializer = ReservationSerializer(queryset, many=True)
        return Response(serializer.data)