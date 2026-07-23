from rest_framework import serializers
from django.db import transaction
from .models import Reservation, PreOrderItem
from restaurants.models import MenuItem


class PreOrderItemSerializer(serializers.ModelSerializer):
    class Meta:
        model = PreOrderItem
        fields = ['id', 'menu_item', 'item_name', 'quantity', 'unit_price', 'subtotal']
        read_only_fields = ['id', 'item_name', 'unit_price', 'subtotal']


class PreOrderItemCreateSerializer(serializers.Serializer):
    menu_item = serializers.PrimaryKeyRelatedField(queryset=MenuItem.objects.all())
    quantity = serializers.IntegerField(min_value=1)


class ReservationSerializer(serializers.ModelSerializer):
    pre_order_items = PreOrderItemSerializer(many=True, read_only=True)
    customer_username = serializers.CharField(source='customer.username', read_only=True)

    class Meta:
        model = Reservation
        fields = [
            'id', 'customer', 'customer_username', 'restaurant',
            'reservation_date', 'reservation_time', 'party_size',
            'status', 'special_requests', 'pre_order_total',
            'pre_order_items', 'created_at', 'updated_at'
        ]
        read_only_fields = ['id', 'customer', 'pre_order_total', 'created_at', 'updated_at']


class ReservationCreateSerializer(serializers.ModelSerializer):
    pre_order_items = PreOrderItemCreateSerializer(many=True, required=False, write_only=True)

    class Meta:
        model = Reservation
        fields = [
            'id', 'restaurant', 'reservation_date', 'reservation_time',
            'party_size', 'special_requests', 'pre_order_items'
        ]
        read_only_fields = ['id']

    def validate_party_size(self, value):
        if value < 1:
            raise serializers.ValidationError("Party size must be at least 1.")
        return value

    @transaction.atomic
    def create(self, validated_data):
        items_data = validated_data.pop('pre_order_items', [])
        customer = self.context['request'].user

        reservation = Reservation.objects.create(customer=customer, **validated_data)

        total = 0
        for item_data in items_data:
            menu_item = item_data['menu_item']
            quantity = item_data['quantity']

            if not menu_item.is_available:
                raise serializers.ValidationError(
                    f"'{menu_item.name}' is currently unavailable."
                )

            pre_order_item = PreOrderItem.objects.create(
                reservation=reservation,
                menu_item=menu_item,
                item_name=menu_item.name,
                quantity=quantity,
                unit_price=menu_item.price,
            )
            total += pre_order_item.subtotal

        reservation.pre_order_total = total
        reservation.save()
        return reservation