from rest_framework import serializers
from .models import Restaurant, Category, MenuItem, MenuItemVariant


class MenuItemVariantSerializer(serializers.ModelSerializer):
    class Meta:
        model = MenuItemVariant
        fields = ['id', 'menu_item', 'name', 'price', 'display_order']
        read_only_fields = ['id']


class MenuItemSerializer(serializers.ModelSerializer):
    variants = MenuItemVariantSerializer(many=True, read_only=True)

    class Meta:
        model = MenuItem
        fields = [
            'id', 'restaurant', 'category', 'name', 'description',
            'price', 'image', 'is_available', 'is_vegetarian',
            'stock_quantity', 'variants', 'created_at', 'updated_at'
        ]
        read_only_fields = ['id', 'created_at', 'updated_at']


class CategorySerializer(serializers.ModelSerializer):
    menu_items = MenuItemSerializer(many=True, read_only=True)

    class Meta:
        model = Category
        fields = ['id', 'restaurant', 'name', 'display_order', 'menu_items']
        read_only_fields = ['id']


class RestaurantSerializer(serializers.ModelSerializer):
    class Meta:
        model = Restaurant
        fields = [
            'id', 'owner', 'name', 'description', 'address',
            'phone_number', 'email', 'logo', 'cover_image',
            'opening_time', 'closing_time', 'is_active',
            'supports_dine_in', 'supports_takeaway', 'supports_delivery', 'supports_reservations',
            'created_at', 'updated_at'
        ]
        read_only_fields = ['id', 'owner', 'created_at', 'updated_at']

    def update(self, instance, validated_data):
        request = self.context.get('request')
        is_system_admin = request and request.user.is_authenticated and (
            request.user.is_staff or request.user.is_superuser
        )
        if not is_system_admin:
            validated_data.pop('supports_dine_in', None)
            validated_data.pop('supports_takeaway', None)
            validated_data.pop('supports_delivery', None)
            validated_data.pop('supports_reservations', None)
        return super().update(instance, validated_data)


class RestaurantDetailSerializer(RestaurantSerializer):
    categories = CategorySerializer(many=True, read_only=True)
    uncategorized_items = serializers.SerializerMethodField()

    class Meta(RestaurantSerializer.Meta):
        fields = RestaurantSerializer.Meta.fields + ['categories', 'uncategorized_items']

    def get_uncategorized_items(self, obj):
        items = obj.menu_items.filter(category__isnull=True)
        return MenuItemSerializer(items, many=True).data