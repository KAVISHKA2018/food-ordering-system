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
            'created_at', 'updated_at'
        ]
        read_only_fields = ['id', 'owner', 'created_at', 'updated_at']


class RestaurantDetailSerializer(RestaurantSerializer):
    categories = CategorySerializer(many=True, read_only=True)
    uncategorized_items = serializers.SerializerMethodField()

    class Meta(RestaurantSerializer.Meta):
        fields = RestaurantSerializer.Meta.fields + ['categories', 'uncategorized_items']

    def get_uncategorized_items(self, obj):
        items = obj.menu_items.filter(category__isnull=True)
        return MenuItemSerializer(items, many=True).data