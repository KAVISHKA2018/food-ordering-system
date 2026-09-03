from django.db import models
from django.utils import timezone
from restaurants.models import Restaurant


class Promotion(models.Model):
    class DiscountType(models.TextChoices):
        PERCENTAGE = 'PERCENTAGE', 'Percentage'
        FIXED = 'FIXED', 'Fixed Amount'

    restaurant = models.ForeignKey(
        Restaurant, on_delete=models.CASCADE, related_name='promotions'
    )
    title = models.CharField(max_length=100)
    description = models.TextField(blank=True)
    image = models.ImageField(upload_to='promotions/', blank=True, null=True)
    code = models.CharField(
        max_length=30, blank=True,
        help_text="Leave blank to auto-apply this offer to every qualifying order. "
                   "Fill in to require the customer to enter this code."
    )
    discount_type = models.CharField(max_length=10, choices=DiscountType.choices, default=DiscountType.PERCENTAGE)
    discount_value = models.DecimalField(max_digits=10, decimal_places=2)
    min_order_amount = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    start_date = models.DateField()
    end_date = models.DateField()
    max_uses = models.PositiveIntegerField(null=True, blank=True, help_text="Leave blank for unlimited uses.")
    used_count = models.PositiveIntegerField(default=0)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.title} — {self.restaurant.name}"

    def is_valid_now(self):
        today = timezone.now().date()
        if not self.is_active:
            return False
        if not (self.start_date <= today <= self.end_date):
            return False
        if self.max_uses is not None and self.used_count >= self.max_uses:
            return False
        return True

    def calculate_discount(self, subtotal):
        if subtotal < self.min_order_amount:
            return 0
        if self.discount_type == self.DiscountType.PERCENTAGE:
            return round(subtotal * self.discount_value / 100, 2)
        return min(self.discount_value, subtotal)