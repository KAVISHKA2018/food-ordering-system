from rest_framework import serializers
from .models import Restaurant, Category, MenuItem


class MenuItemSerializer(serializers.ModelSerializer):
    class Meta:
        model = MenuItem
        fields = [
            'id', 'restaurant', 'category', 'name', 'description',
            'price', 'image', 'is_available', 'is_vegetarian',
            'stock_quantity', 'created_at', 'updated_at'
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
    """Includes nested categories + menu items — used for the restaurant detail/menu page."""
    categories = CategorySerializer(many=True, read_only=True)

    class Meta(RestaurantSerializer.Meta):
        fields = RestaurantSerializer.Meta.fields + ['categories']