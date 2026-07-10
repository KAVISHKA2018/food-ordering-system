from rest_framework import serializers
from django.db import transaction
from .models import Order, OrderItem
from restaurants.models import MenuItem


class OrderItemSerializer(serializers.ModelSerializer):
    class Meta:
        model = OrderItem
        fields = ['id', 'menu_item', 'item_name', 'quantity', 'unit_price', 'subtotal']
        read_only_fields = ['id', 'item_name', 'unit_price', 'subtotal']


class OrderItemCreateSerializer(serializers.Serializer):
    """Used only for input when creating an order — just menu_item + quantity."""
    menu_item = serializers.PrimaryKeyRelatedField(queryset=MenuItem.objects.all())
    quantity = serializers.IntegerField(min_value=1)


class OrderSerializer(serializers.ModelSerializer):
    items = OrderItemSerializer(many=True, read_only=True)
    customer_username = serializers.CharField(source='customer.username', read_only=True)

    class Meta:
        model = Order
        fields = [
            'id', 'customer', 'customer_username', 'restaurant', 'order_type',
            'status', 'delivery_address', 'total_amount', 'notes',
            'items', 'created_at', 'updated_at'
        ]
        read_only_fields = ['id', 'customer', 'total_amount', 'created_at', 'updated_at']


class OrderCreateSerializer(serializers.ModelSerializer):
    items = OrderItemCreateSerializer(many=True, write_only=True)

    class Meta:
        model = Order
        fields = ['id', 'restaurant', 'order_type', 'delivery_address', 'notes', 'items']
        read_only_fields = ['id']

    def validate(self, data):
        if not data.get('items'):
            raise serializers.ValidationError("Order must contain at least one item.")
        if data['order_type'] == Order.OrderType.DELIVERY and not data.get('delivery_address'):
            raise serializers.ValidationError("Delivery address is required for delivery orders.")
        return data

    @transaction.atomic
    def create(self, validated_data):
        items_data = validated_data.pop('items')
        customer = self.context['request'].user

        order = Order.objects.create(customer=customer, **validated_data)

        total = 0
        for item_data in items_data:
            menu_item = item_data['menu_item']
            quantity = item_data['quantity']

            if not menu_item.is_available:
                raise serializers.ValidationError(
                    f"'{menu_item.name}' is currently unavailable."
                )
            if menu_item.stock_quantity < quantity:
                raise serializers.ValidationError(
                    f"Not enough stock for '{menu_item.name}'. Available: {menu_item.stock_quantity}"
                )

            order_item = OrderItem.objects.create(
                order=order,
                menu_item=menu_item,
                item_name=menu_item.name,
                quantity=quantity,
                unit_price=menu_item.price,
            )
            total += order_item.subtotal

            # reduce stock
            menu_item.stock_quantity -= quantity
            menu_item.save()

        order.total_amount = total
        order.save()
        return order