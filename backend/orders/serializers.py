from rest_framework import serializers
from django.db import transaction
from django.utils import timezone
from .models import Order, OrderItem, TableSession, Payment
from restaurants.models import MenuItem, MenuItemVariant


class OrderItemSerializer(serializers.ModelSerializer):
    class Meta:
        model = OrderItem
        fields = ['id', 'menu_item', 'variant', 'item_name', 'variant_name', 'quantity', 'unit_price', 'subtotal']
        read_only_fields = ['id', 'item_name', 'variant_name', 'unit_price', 'subtotal']


class OrderItemCreateSerializer(serializers.Serializer):
    menu_item = serializers.PrimaryKeyRelatedField(queryset=MenuItem.objects.all())
    variant = serializers.PrimaryKeyRelatedField(
        queryset=MenuItemVariant.objects.all(), required=False, allow_null=True
    )
    quantity = serializers.IntegerField(min_value=1)


class OrderSerializer(serializers.ModelSerializer):
    items = OrderItemSerializer(many=True, read_only=True)
    customer_username = serializers.CharField(source='customer.username', read_only=True)
    table_number = serializers.CharField(source='table_session.table_number', read_only=True, default=None)

    class Meta:
        model = Order
        fields = [
            'id', 'customer', 'customer_username', 'restaurant', 'table_session', 'table_number',
            'order_type', 'status', 'delivery_address', 'total_amount', 'notes',
            'items', 'created_at', 'updated_at'
        ]
        read_only_fields = ['id', 'customer', 'total_amount', 'created_at', 'updated_at']


class OrderCreateSerializer(serializers.ModelSerializer):
    items = OrderItemCreateSerializer(many=True, write_only=True)
    table_number = serializers.CharField(write_only=True, required=False, allow_blank=True)

    class Meta:
        model = Order
        fields = ['id', 'restaurant', 'order_type', 'delivery_address', 'notes', 'items', 'table_number']
        read_only_fields = ['id']

    def validate(self, data):
        if not data.get('items'):
            raise serializers.ValidationError("Order must contain at least one item.")
        if data['order_type'] == Order.OrderType.DELIVERY and not data.get('delivery_address'):
            raise serializers.ValidationError("Delivery address is required for delivery orders.")
        if data['order_type'] == Order.OrderType.DINE_IN and not data.get('table_number'):
            raise serializers.ValidationError("Table number is required for dine-in orders.")
        return data

    @transaction.atomic
    def create(self, validated_data):
        items_data = validated_data.pop('items')
        table_number = validated_data.pop('table_number', '')
        customer = self.context['request'].user

        table_session = None
        if validated_data['order_type'] == Order.OrderType.DINE_IN:
            # Reuse the customer's existing OPEN session for this exact table,
            # or start a new one. This is how multiple orders accumulate under
            # one running tab, and how a fresh session starts after paying.
            table_session, _ = TableSession.objects.get_or_create(
                restaurant=validated_data['restaurant'],
                customer=customer,
                table_number=table_number,
                status=TableSession.Status.OPEN,
                defaults={},
            )

        order = Order.objects.create(customer=customer, table_session=table_session, **validated_data)

        # Takeaway must be paid before the kitchen sees it.
        if order.order_type == Order.OrderType.TAKEAWAY:
            order.status = Order.Status.AWAITING_PAYMENT

        total = 0
        for item_data in items_data:
            menu_item = item_data['menu_item']
            variant = item_data.get('variant')
            quantity = item_data['quantity']

            if not menu_item.is_available:
                raise serializers.ValidationError(f"'{menu_item.name}' is currently unavailable.")

            if variant and variant.menu_item_id != menu_item.id:
                raise serializers.ValidationError(
                    f"Selected size does not belong to '{menu_item.name}'."
                )

            unit_price = variant.price if variant else menu_item.price

            if not variant and menu_item.stock_quantity < quantity:
                raise serializers.ValidationError(
                    f"Not enough stock for '{menu_item.name}'. Available: {menu_item.stock_quantity}"
                )

            order_item = OrderItem.objects.create(
                order=order,
                menu_item=menu_item,
                variant=variant,
                item_name=menu_item.name,
                variant_name=variant.name if variant else '',
                quantity=quantity,
                unit_price=unit_price,
            )
            total += order_item.subtotal

            if not variant:
                menu_item.stock_quantity -= quantity
                menu_item.save()

        order.total_amount = total
        order.save()
        return order


class TableSessionSerializer(serializers.ModelSerializer):
    orders = OrderSerializer(many=True, read_only=True)
    restaurant_name = serializers.CharField(source='restaurant.name', read_only=True)

    class Meta:
        model = TableSession
        fields = [
            'id', 'restaurant', 'restaurant_name', 'customer', 'table_number',
            'status', 'total_amount', 'orders', 'created_at', 'updated_at'
        ]
        read_only_fields = ['id', 'customer', 'total_amount', 'created_at', 'updated_at']


class PaymentSerializer(serializers.ModelSerializer):
    class Meta:
        model = Payment
        fields = ['id', 'order', 'table_session', 'amount', 'method', 'status', 'created_at', 'paid_at']
        read_only_fields = ['id', 'amount', 'status', 'created_at', 'paid_at']