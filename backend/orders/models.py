from django.db import models
from django.conf import settings
from restaurants.models import Restaurant, MenuItem


class Order(models.Model):
    class OrderType(models.TextChoices):
        DINE_IN = 'DINE_IN', 'Dine In'
        TAKEAWAY = 'TAKEAWAY', 'Takeaway'
        DELIVERY = 'DELIVERY', 'Delivery'

    class Status(models.TextChoices):
        PENDING = 'PENDING', 'Pending'
        CONFIRMED = 'CONFIRMED', 'Confirmed'
        PREPARING = 'PREPARING', 'Preparing'
        READY = 'READY', 'Ready'
        OUT_FOR_DELIVERY = 'OUT_FOR_DELIVERY', 'Out for Delivery'
        COMPLETED = 'COMPLETED', 'Completed'
        CANCELLED = 'CANCELLED', 'Cancelled'

    customer = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='orders'
    )
    restaurant = models.ForeignKey(
        Restaurant,
        on_delete=models.CASCADE,
        related_name='orders'
    )
    order_type = models.CharField(max_length=20, choices=OrderType.choices)
    status = models.CharField(max_length=20, choices=Status.choices, default=Status.PENDING)
    delivery_address = models.CharField(max_length=255, blank=True)
    total_amount = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    notes = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"Order #{self.id} - {self.customer.username} - {self.restaurant.name}"


class OrderItem(models.Model):
    order = models.ForeignKey(
        Order,
        on_delete=models.CASCADE,
        related_name='items'
    )
    menu_item = models.ForeignKey(
        MenuItem,
        on_delete=models.SET_NULL,
        null=True,
        related_name='order_items'
    )
    item_name = models.CharField(max_length=150)  # snapshot, in case menu item is later deleted/renamed
    quantity = models.PositiveIntegerField(default=1)
    unit_price = models.DecimalField(max_digits=10, decimal_places=2)
    subtotal = models.DecimalField(max_digits=10, decimal_places=2)

    def save(self, *args, **kwargs):
        self.subtotal = self.unit_price * self.quantity
        super().save(*args, **kwargs)

    def __str__(self):
        return f"{self.quantity}x {self.item_name}"