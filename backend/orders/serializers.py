from rest_framework import serializers
from django.db import transaction
from .models import Order, OrderItem, TableSession, Payment
from restaurants.models import MenuItem, MenuItemVariant
from promotions.models import Promotion


def normalize_table_number(value):
    """Treats 3, 03, 003 as the same table — normalizes to a 2-digit format
    when purely numeric. Non-numeric table names (e.g. 'Patio-A') pass through unchanged."""
    value = (value or '').strip()
    if value.isdigit():
        return str(int(value)).zfill(2)
    return value


class OrderItemSerializer(serializers.ModelSerializer):
    has_food_review = serializers.SerializerMethodField()

    class Meta:
        model = OrderItem
        fields = ['id', 'menu_item', 'variant', 'item_name', 'variant_name', 'quantity', 'unit_price', 'subtotal', 'has_food_review']
        read_only_fields = ['id', 'item_name', 'variant_name', 'unit_price', 'subtotal']

    def get_has_food_review(self, obj):
        return hasattr(obj, 'review')


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
    promotion_title = serializers.CharField(source='promotion.title', read_only=True, default=None)
    has_review = serializers.SerializerMethodField()
    latest_payment_id = serializers.SerializerMethodField()
    payment_method = serializers.SerializerMethodField()
    assigned_delivery_staff_name = serializers.SerializerMethodField()

    class Meta:
        model = Order
        fields = [
            'id', 'customer', 'customer_username', 'restaurant', 'restaurant_name', 'table_session', 'table_number',
            'order_type', 'status', 'delivery_address', 'delivery_latitude', 'delivery_longitude', 'contact_phone', 'alternative_phone',
            'subtotal_amount', 'discount_amount', 'promotion', 'promotion_title', 'total_amount', 'notes',
            'payment_status', 'has_review', 'latest_payment_id', 'payment_method',
            'assigned_delivery_staff', 'assigned_delivery_staff_name', 'delivery_started_at',
            'rider_current_latitude', 'rider_current_longitude', 'rider_location_updated_at',
            'items', 'created_at', 'updated_at'
        ]
        read_only_fields = ['id', 'customer', 'subtotal_amount', 'discount_amount', 'total_amount', 'created_at', 'updated_at']

    def get_table_number(self, obj):
        return obj.table_session.table_number if obj.table_session else None

    def get_has_review(self, obj):
        return hasattr(obj, 'review')

    def get_latest_payment_id(self, obj):
        payment = obj.payments.order_by('-created_at').first()
        return payment.id if payment else None

    def get_payment_method(self, obj):
        payment = obj.payments.order_by('-created_at').first()
        return payment.method if payment else None

    def get_assigned_delivery_staff_name(self, obj):
        if obj.assigned_delivery_staff:
            return obj.assigned_delivery_staff.first_name or obj.assigned_delivery_staff.username
        return None

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
    promo_code = serializers.CharField(write_only=True, required=False, allow_blank=True)
    payment_method = serializers.ChoiceField(choices=['CASH', 'CARD'], write_only=True, required=False, default='CASH')

    class Meta:
        model = Order
        fields = ['id', 'restaurant', 'order_type', 'delivery_address', 'delivery_latitude', 'delivery_longitude', 'contact_phone', 'alternative_phone', 'notes', 'items', 'table_number', 'promo_code', 'payment_method']
        read_only_fields = ['id']

    def validate(self, data):
        if not data.get('items'):
            raise serializers.ValidationError("Order must contain at least one item.")

        restaurant = data['restaurant']
        order_type = data['order_type']

        if order_type == Order.OrderType.DINE_IN and not restaurant.supports_dine_in:
            raise serializers.ValidationError(f"{restaurant.name} does not offer dine-in.")
        if order_type == Order.OrderType.TAKEAWAY and not restaurant.supports_takeaway:
            raise serializers.ValidationError(f"{restaurant.name} does not offer takeaway.")
        if order_type == Order.OrderType.DELIVERY and not restaurant.supports_delivery:
            raise serializers.ValidationError(f"{restaurant.name} does not offer delivery.")

        if order_type == Order.OrderType.DELIVERY:
            if not data.get('delivery_address'):
                raise serializers.ValidationError("Delivery address is required for delivery orders.")
            if not data.get('contact_phone'):
                raise serializers.ValidationError("Contact phone is required for delivery orders.")
        if order_type == Order.OrderType.DINE_IN and not (data.get('table_number') or '').strip():
            raise serializers.ValidationError("Table number is required for dine-in orders.")
        return data

    @transaction.atomic
    def create(self, validated_data):
        items_data = validated_data.pop('items')
        table_number = normalize_table_number(validated_data.pop('table_number', ''))
        promo_code = (validated_data.pop('promo_code', '') or '').strip()
        payment_method = validated_data.pop('payment_method', 'CASH')
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

        subtotal = 0
        for item_data in items_data:
            menu_item = item_data['menu_item']
            variant = item_data.get('variant')
            quantity = item_data['quantity']

            if not menu_item.is_available:
                raise serializers.ValidationError(f"'{menu_item.name}' is currently unavailable.")
            if variant and variant.menu_item_id != menu_item.id:
                raise serializers.ValidationError(f"Selected size does not belong to '{menu_item.name}'.")

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
            subtotal += order_item.subtotal

            if not variant:
                menu_item.stock_quantity -= quantity
                menu_item.save()

        discount = 0
        promotion = None
        if promo_code:
            promotion = Promotion.objects.filter(
                restaurant=order.restaurant, code__iexact=promo_code
            ).first()
            if not promotion or not promotion.is_valid_now():
                raise serializers.ValidationError("This promo code is invalid or expired.")
            if subtotal < promotion.min_order_amount:
                raise serializers.ValidationError(
                    f"Minimum order of Rs. {promotion.min_order_amount} required for this code."
                )
            discount = promotion.calculate_discount(subtotal)
            promotion.used_count += 1
            promotion.save()

        order.subtotal_amount = subtotal
        order.discount_amount = discount
        order.total_amount = subtotal - discount
        order.promotion = promotion

        if order.order_type in [Order.OrderType.TAKEAWAY, Order.OrderType.DELIVERY]:
            Payment.objects.create(
                order=order,
                amount=order.total_amount,
                method=Payment.Method.CASH if payment_method == 'CASH' else Payment.Method.CARD,
                status=Payment.Status.PENDING,
            )
            if payment_method == 'CARD':
                order.status = Order.Status.AWAITING_PAYMENT
            elif order.order_type == Order.OrderType.TAKEAWAY:
                # Cash at pickup — restaurant confirms receipt before cooking.
                order.status = Order.Status.PAYMENT_PENDING
            else:
                # Cash on Delivery — the rider collects payment at drop-off,
                # not the restaurant beforehand. The kitchen can start
                # immediately; the Payment gets marked COMPLETED later when
                # the rider taps "Cash Collected" (see mark_delivered below).
                order.status = Order.Status.PENDING

        order.save()
        return order


class TableSessionSerializer(serializers.ModelSerializer):
    orders = OrderSerializer(many=True, read_only=True)
    restaurant_name = serializers.CharField(source='restaurant.name', read_only=True)
    customer_username = serializers.CharField(source='customer.username', read_only=True)
    from_reservation = serializers.SerializerMethodField()
    payment_method = serializers.SerializerMethodField()

    class Meta:
        model = TableSession
        fields = [
            'id', 'restaurant', 'restaurant_name', 'customer', 'customer_username',
            'table_number', 'status', 'total_amount', 'orders', 'from_reservation', 'payment_method',
            'created_at', 'updated_at'
        ]
        read_only_fields = ['id', 'customer', 'total_amount', 'created_at', 'updated_at']

    def get_from_reservation(self, obj):
        reservation = obj.reservations.first()
        return reservation.id if reservation else None

    def get_payment_method(self, obj):
        payment = obj.payments.order_by('-created_at').first()
        return payment.method if payment else None


class PaymentSerializer(serializers.ModelSerializer):
    class Meta:
        model = Payment
        fields = ['id', 'order', 'table_session', 'amount', 'method', 'status', 'created_at', 'paid_at']
        read_only_fields = ['id', 'amount', 'status', 'created_at', 'paid_at']