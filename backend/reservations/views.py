from rest_framework import viewsets, permissions, status
from rest_framework.response import Response
from rest_framework.decorators import action
from .models import Reservation
from .serializers import ReservationSerializer, ReservationCreateSerializer
from .permissions import IsReservationOwnerOrRestaurantStaff


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

        reservation.status = new_status
        reservation.save()
        return Response(ReservationSerializer(reservation).data)

    @action(detail=False, methods=['get'], permission_classes=[permissions.IsAuthenticated])
    def upcoming(self, request):
        """Customer's upcoming reservations, or restaurant admin's upcoming bookings."""
        from django.utils import timezone
        queryset = self.get_queryset().filter(
            reservation_date__gte=timezone.now().date()
        ).exclude(status__in=['CANCELLED', 'COMPLETED', 'NO_SHOW'])
        serializer = ReservationSerializer(queryset, many=True)
        return Response(serializer.data)