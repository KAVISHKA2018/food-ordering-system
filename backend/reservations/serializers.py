from rest_framework import serializers
from django.db import transaction
from .models import Reservation, PreOrderItem
from restaurants.models import MenuItem, MenuItemVariant
from orders.serializers import normalize_table_number


class PreOrderItemSerializer(serializers.ModelSerializer):
    class Meta:
        model = PreOrderItem
        fields = ['id', 'menu_item', 'variant', 'item_name', 'variant_name', 'quantity', 'unit_price', 'subtotal']
        read_only_fields = ['id', 'item_name', 'variant_name', 'unit_price', 'subtotal']


class PreOrderItemCreateSerializer(serializers.Serializer):
    menu_item = serializers.PrimaryKeyRelatedField(queryset=MenuItem.objects.all())
    variant = serializers.PrimaryKeyRelatedField(
        queryset=MenuItemVariant.objects.all(), required=False, allow_null=True
    )
    quantity = serializers.IntegerField(min_value=1)

class ReservationSerializer(serializers.ModelSerializer):
    pre_order_items = PreOrderItemSerializer(many=True, read_only=True)
    customer_username = serializers.CharField(source='customer.username', read_only=True)
    restaurant_name = serializers.CharField(source='restaurant.name', read_only=True)
    payment_status = serializers.SerializerMethodField()
    current_bill_total = serializers.SerializerMethodField()
    payment_method = serializers.SerializerMethodField()

    class Meta:
        model = Reservation
        fields = [
            'id', 'customer', 'customer_username', 'restaurant', 'restaurant_name',
            'reservation_date', 'reservation_time', 'party_size',
            'status', 'table_number', 'table_session', 'special_requests', 'pre_order_total',
            'current_bill_total', 'payment_status', 'payment_method', 'pre_order_items', 'created_at', 'updated_at'
        ]
        read_only_fields = ['id', 'customer', 'pre_order_total', 'created_at', 'updated_at']

    def get_payment_status(self, obj):
        if not obj.table_session:
            return 'N/A'
        mapping = {
            'OPEN': 'UNPAID',
            'PAYMENT_PENDING': 'PENDING_CONFIRMATION',
            'PAID': 'PAID',
            'CLOSED': 'PAID',
        }
        return mapping.get(obj.table_session.status, 'UNPAID')

    def get_current_bill_total(self, obj):
        """The full running bill for this table — includes the original
        pre-order plus any 'Add More Food' orders placed after seating.
        Falls back to pre_order_total if not seated yet (no table session)."""
        if obj.table_session:
            return obj.table_session.total_amount
        return obj.pre_order_total

    def get_payment_method(self, obj):
        if not obj.table_session:
            return None
        payment = obj.table_session.payments.order_by('-created_at').first()
        return payment.method if payment else None

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

    def validate(self, data):
        restaurant = data.get('restaurant')
        if restaurant and not restaurant.supports_reservations:
            raise serializers.ValidationError(
                f"{restaurant.name} does not accept table reservations."
            )
        return data

    @transaction.atomic
    def create(self, validated_data):
        items_data = validated_data.pop('pre_order_items', [])
        customer = self.context['request'].user

        reservation = Reservation.objects.create(customer=customer, **validated_data)

        total = 0
        for item_data in items_data:
            menu_item = item_data['menu_item']
            variant = item_data.get('variant')
            quantity = item_data['quantity']

            if not menu_item.is_available:
                raise serializers.ValidationError(
                    f"'{menu_item.name}' is currently unavailable."
                )

            if variant and variant.menu_item_id != menu_item.id:
                raise serializers.ValidationError(
                    f"Selected size does not belong to '{menu_item.name}'."
                )

            unit_price = variant.price if variant else menu_item.price

            pre_order_item = PreOrderItem.objects.create(
                reservation=reservation,
                menu_item=menu_item,
                variant=variant,
                item_name=menu_item.name,
                variant_name=variant.name if variant else '',
                quantity=quantity,
                unit_price=unit_price,
            )
            total += pre_order_item.subtotal

        reservation.pre_order_total = total
        reservation.save()
        return reservation