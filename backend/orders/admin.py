from django.contrib import admin
from .models import Order, OrderItem


class OrderItemInline(admin.TabularInline):
    model = OrderItem
    extra = 0
    readonly_fields = ['item_name', 'unit_price', 'subtotal']


@admin.register(Order)
class OrderAdmin(admin.ModelAdmin):
    list_display = ['id', 'customer', 'restaurant', 'order_type', 'status', 'total_amount', 'created_at']
    list_filter = ['status', 'order_type', 'restaurant']
    inlines = [OrderItemInline]