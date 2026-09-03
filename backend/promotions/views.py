from django.utils import timezone
from decimal import Decimal
from rest_framework import viewsets, permissions, status
from rest_framework.decorators import action
from rest_framework.response import Response
from .models import Promotion
from .serializers import PromotionSerializer
from .permissions import IsRestaurantOwnerOfPromotion


class PromotionViewSet(viewsets.ModelViewSet):
    serializer_class = PromotionSerializer
    permission_classes = [permissions.IsAuthenticatedOrReadOnly, IsRestaurantOwnerOfPromotion]

    def get_queryset(self):
        user = self.request.user
        if user.is_authenticated and user.role == 'RESTAURANT_ADMIN':
            # Restaurant admin managing their own promotions sees everything,
            # including expired/inactive ones (for editing/history).
            queryset = Promotion.objects.filter(restaurant__owner=user)
        else:
            # Public/customer view — only currently live offers.
            today = timezone.now().date()
            queryset = Promotion.objects.filter(
                is_active=True, start_date__lte=today, end_date__gte=today
            )
            restaurant_id = self.request.query_params.get('restaurant')
            if restaurant_id:
                queryset = queryset.filter(restaurant_id=restaurant_id)
        return queryset

    def perform_create(self, serializer):
        serializer.save()

    @action(detail=False, methods=['post'], permission_classes=[permissions.IsAuthenticated])
    def validate_code(self, request):
        """Customer checks a promo code before checkout — returns the discount
        without applying it. Actual application happens at order creation."""
        restaurant_id = request.data.get('restaurant')
        code = (request.data.get('code') or '').strip()
        subtotal = Decimal(str(request.data.get('subtotal', '0')))

        if not code:
            return Response({"detail": "Please enter a promo code."}, status=status.HTTP_400_BAD_REQUEST)

        promo = Promotion.objects.filter(
            restaurant_id=restaurant_id, code__iexact=code
        ).first()

        if not promo or not promo.is_valid_now():
            return Response({"detail": "This promo code is invalid or expired."}, status=status.HTTP_400_BAD_REQUEST)

        if subtotal < promo.min_order_amount:
            return Response(
                {"detail": f"Minimum order of Rs. {promo.min_order_amount} required for this code."},
                status=status.HTTP_400_BAD_REQUEST
            )

        discount = promo.calculate_discount(subtotal)
        return Response({
            "valid": True,
            "promotion_id": promo.id,
            "title": promo.title,
            "discount_amount": str(discount),
        })