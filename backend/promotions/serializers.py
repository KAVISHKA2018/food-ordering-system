from rest_framework import serializers
from .models import Promotion


class PromotionSerializer(serializers.ModelSerializer):
    restaurant_name = serializers.CharField(source='restaurant.name', read_only=True)

    class Meta:
        model = Promotion
        fields = [
            'id', 'restaurant', 'restaurant_name', 'title', 'description', 'image', 'code',
            'discount_type', 'discount_value', 'min_order_amount',
            'start_date', 'end_date', 'max_uses', 'used_count',
            'is_active', 'created_at'
        ]
        read_only_fields = ['id', 'used_count', 'created_at']