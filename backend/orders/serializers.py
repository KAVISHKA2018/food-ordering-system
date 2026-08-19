from rest_framework import serializers
from django.db import transaction
from .models import Order, OrderItem, TableSession, Payment
from restaurants.models import MenuItem, MenuItemVariant


def normalize_table_number(value):
    """Treats 3, 03, 003 as the same table — normalizes to a 2-digit format
    when purely numeric. Non-numeric table names (e.g. 'Patio-A') pass through unchanged."""
    value = (value or '').strip()
    if value.isdigit():
        return str(int(value)).zfill(2)
    return value


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
    restaurant_name = serializers.CharField(source='restaurant.name', read_only=True)
    table_number = serializers.SerializerMethodField()
    payment_status = serializers.SerializerMethodField()

    class Meta:
        model = Order
        fields = [
            'id', 'customer', 'customer_username', 'restaurant', 'restaurant_name',
            'table_session', 'table_number', 'order_type', 'status',
            'delivery_address', 'contact_phone', 'total_amount', 'notes',
            'payment_status', 'items', 'created_at', 'updated_at'
        ]
        read_only_fields = ['id', 'customer', 'total_amount', 'created_at', 'updated_at']

    def get_table_number(self, obj):
        return obj.table_session.table_number if obj.table_session else None

    def get_payment_status(self, obj):
        if obj.order_type == Order.OrderType.DINE_IN and obj.table_session:
            mapping = {
                TableSession.Status.OPEN: 'UNPAID',
                TableSession.Status.PAYMENT_PENDING: 'PENDING_CONFIRMATION',
                TableSession.Status.PAID: 'PAID',
                TableSession.Status.CLOSED: 'PAID',
            }
            return mapping.get(obj.table_session.status, 'UNPAID')
        if obj.order_type == Order.OrderType.TAKEAWAY:
            mapping = {
                Order.Status.AWAITING_PAYMENT: 'UNPAID',
                Order.Status.PAYMENT_PENDING: 'PENDING_CONFIRMATION',
            }
            return mapping.get(obj.status, 'PAID')
        return 'N/A'


class OrderCreateSerializer(serializers.ModelSerializer):
    items = OrderItemCreateSerializer(many=True, write_only=True)
    table_number = serializers.CharField(write_only=True, required=False, allow_blank=True)

    class Meta:
        model = Order
        fields = ['id', 'restaurant', 'order_type', 'delivery_address', 'contact_phone', 'notes', 'items', 'table_number']
        read_only_fields = ['id']

    def validate(self, data):
        if not data.get('items'):
            raise serializers.ValidationError("Order must contain at least one item.")
        if data['order_type'] == Order.OrderType.DELIVERY:
            if not data.get('delivery_address'):
                raise serializers.ValidationError("Delivery address is required for delivery orders.")
            if not data.get('contact_phone'):
                raise serializers.ValidationError("Contact phone is required for delivery orders.")
        if data['order_type'] == Order.OrderType.DINE_IN and not (data.get('table_number') or '').strip():
            raise serializers.ValidationError("Table number is required for dine-in orders.")
        return data

    @transaction.atomic
    def create(self, validated_data):
        items_data = validated_data.pop('items')
        table_number = normalize_table_number(validated_data.pop('table_number', ''))
        customer = self.context['request'].user

        table_session = None
        if validated_data['order_type'] == Order.OrderType.DINE_IN:
            table_session, _ = TableSession.objects.get_or_create(
                restaurant=validated_data['restaurant'],
                customer=customer,
                table_number=table_number,
                status=TableSession.Status.OPEN,
                defaults={},
            )

        order = Order.objects.create(customer=customer, table_session=table_session, **validated_data)

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

        if order.order_type == Order.OrderType.TAKEAWAY:
            # This endpoint is now only called by the app AFTER the customer
            # taps "Pay Now" on the payment screen — so by the time we reach
            # here, payment has already been requested. Record it as pending
            # the restaurant's cash confirmation, same as before.
            Payment.objects.create(
                order=order,
                amount=total,
                method=Payment.Method.MOCK,
                status=Payment.Status.PENDING,
            )
            order.status = Order.Status.PAYMENT_PENDING

        order.save()
        return order


class TableSessionSerializer(serializers.ModelSerializer):
    orders = OrderSerializer(many=True, read_only=True)
    restaurant_name = serializers.CharField(source='restaurant.name', read_only=True)
    customer_username = serializers.CharField(source='customer.username', read_only=True)

    class Meta:
        model = TableSession
        fields = [
            'id', 'restaurant', 'restaurant_name', 'customer', 'customer_username',
            'table_number', 'status', 'total_amount', 'orders', 'created_at', 'updated_at'
        ]
        read_only_fields = ['id', 'customer', 'total_amount', 'created_at', 'updated_at']


class PaymentSerializer(serializers.ModelSerializer):
    class Meta:
        model = Payment
        fields = ['id', 'order', 'table_session', 'amount', 'method', 'status', 'created_at', 'paid_at']
        read_only_fields = ['id', 'amount', 'status', 'created_at', 'paid_at']