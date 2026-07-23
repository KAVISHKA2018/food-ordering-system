from django.contrib import admin
from .models import Reservation, PreOrderItem


class PreOrderItemInline(admin.TabularInline):
    model = PreOrderItem
    extra = 0
    readonly_fields = ['item_name', 'unit_price', 'subtotal']


@admin.register(Reservation)
class ReservationAdmin(admin.ModelAdmin):
    list_display = [
        'id', 'customer', 'restaurant', 'reservation_date',
        'reservation_time', 'party_size', 'status', 'pre_order_total'
    ]
    list_filter = ['status', 'restaurant', 'reservation_date']
    inlines = [PreOrderItemInline]