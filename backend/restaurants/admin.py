from django.contrib import admin
from .models import Restaurant, Category, MenuItem


@admin.register(Restaurant)
class RestaurantAdmin(admin.ModelAdmin):
    list_display = ['name', 'owner', 'is_active', 'created_at']
    list_filter = ['is_active']
    search_fields = ['name']


@admin.register(Category)
class CategoryAdmin(admin.ModelAdmin):
    list_display = ['name', 'restaurant', 'display_order']
    list_filter = ['restaurant']


@admin.register(MenuItem)
class MenuItemAdmin(admin.ModelAdmin):
    list_display = ['name', 'restaurant', 'category', 'price', 'is_available', 'stock_quantity']
    list_filter = ['restaurant', 'is_available', 'is_vegetarian']
    search_fields = ['name']