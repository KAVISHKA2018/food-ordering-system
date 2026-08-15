from django.contrib import admin
from .models import Order, OrderItem, TableSession, Payment


class OrderItemInline(admin.TabularInline):
    model = OrderItem
    extra = 0
    readonly_fields = ['item_name', 'variant_name', 'unit_price', 'subtotal']


@admin.register(Order)
class OrderAdmin(admin.ModelAdmin):
    list_display = ['id', 'customer', 'restaurant', 'order_type', 'status', 'table_session', 'total_amount', 'created_at']
    list_filter = ['status', 'order_type', 'restaurant']
    inlines = [OrderItemInline]


@admin.register(TableSession)
class TableSessionAdmin(admin.ModelAdmin):
    list_display = ['id', 'table_number', 'restaurant', 'customer', 'status', 'total_amount', 'created_at']
    list_filter = ['status', 'restaurant']


@admin.register(Payment)
class PaymentAdmin(admin.ModelAdmin):
    list_display = ['id', 'order', 'table_session', 'amount', 'method', 'status', 'paid_at']
    list_filter = ['method', 'status']