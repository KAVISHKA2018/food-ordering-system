from django.contrib import admin
from .models import Promotion


@admin.register(Promotion)
class PromotionAdmin(admin.ModelAdmin):
    list_display = ['title', 'restaurant', 'discount_type', 'discount_value', 'code', 'is_active', 'start_date', 'end_date', 'used_count']
    list_filter = ['restaurant', 'is_active', 'discount_type']
    search_fields = ['title', 'code']