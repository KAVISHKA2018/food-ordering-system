from rest_framework import viewsets, permissions, status
from rest_framework.response import Response
from rest_framework.decorators import action
from .models import Order
from .serializers import OrderSerializer, OrderCreateSerializer
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
            # restaurant admins see orders placed at restaurants they own
            return Order.objects.filter(restaurant__owner=user)
        # customers see only their own orders
        return Order.objects.filter(customer=user)

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        order = serializer.save()
        return Response(OrderSerializer(order).data, status=status.HTTP_201_CREATED)

    @action(detail=True, methods=['patch'], permission_classes=[permissions.IsAuthenticated])
    def update_status(self, request, pk=None):
        """Restaurant admin updates order status (e.g. CONFIRMED, PREPARING, READY)."""
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