from rest_framework import serializers
from .models import Review, FoodReview
from orders.models import Order


class ReviewSerializer(serializers.ModelSerializer):
    customer_username = serializers.CharField(source='customer.username', read_only=True)
    restaurant_name = serializers.CharField(source='restaurant.name', read_only=True)

    class Meta:
        model = Review
        fields = [
            'id', 'customer', 'customer_username', 'restaurant', 'restaurant_name',
            'order', 'rating', 'comment', 'restaurant_reply', 'created_at', 'updated_at'
        ]
        read_only_fields = ['id', 'customer', 'restaurant', 'restaurant_reply', 'created_at', 'updated_at']


class ReviewCreateSerializer(serializers.ModelSerializer):
    class Meta:
        model = Review
        fields = ['id', 'order', 'rating', 'comment']
        read_only_fields = ['id']

    def validate_order(self, order):
        request = self.context['request']
        if order.customer != request.user:
            raise serializers.ValidationError("This is not your order.")
        if order.status != Order.Status.COMPLETED:
            raise serializers.ValidationError("You can only review completed orders.")
        if hasattr(order, 'review'):
            raise serializers.ValidationError("You already reviewed this order.")
        return order

    def create(self, validated_data):
        order = validated_data['order']
        return Review.objects.create(
            customer=self.context['request'].user,
            restaurant=order.restaurant,
            order=order,
            rating=validated_data['rating'],
            comment=validated_data.get('comment', ''),
        )


class FoodReviewSerializer(serializers.ModelSerializer):
    customer_username = serializers.CharField(source='customer.username', read_only=True)

    class Meta:
        model = FoodReview
        fields = [
            'id', 'customer', 'customer_username', 'order_item', 'menu_item',
            'item_name', 'rating', 'comment', 'created_at'
        ]
        read_only_fields = ['id', 'customer', 'menu_item', 'item_name', 'created_at']


class FoodReviewCreateSerializer(serializers.ModelSerializer):
    class Meta:
        model = FoodReview
        fields = ['id', 'order_item', 'rating', 'comment']
        read_only_fields = ['id']

    def validate_order_item(self, order_item):
        request = self.context['request']
        if order_item.order.customer != request.user:
            raise serializers.ValidationError("This is not your order item.")
        if order_item.order.status != Order.Status.COMPLETED:
            raise serializers.ValidationError("You can only review items from completed orders.")
        if hasattr(order_item, 'review'):
            raise serializers.ValidationError("You already reviewed this item.")
        if order_item.menu_item is None:
            raise serializers.ValidationError("This item is no longer available for review.")
        return order_item

    def create(self, validated_data):
        order_item = validated_data['order_item']
        return FoodReview.objects.create(
            customer=self.context['request'].user,
            order_item=order_item,
            menu_item=order_item.menu_item,
            item_name=order_item.item_name,
            rating=validated_data['rating'],
            comment=validated_data.get('comment', ''),
        )