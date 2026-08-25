from django.db import models
from django.conf import settings
from restaurants.models import Restaurant, MenuItem

class Reservation(models.Model):
    class Status(models.TextChoices):
        PENDING = 'PENDING', 'Pending'
        CONFIRMED = 'CONFIRMED', 'Confirmed'
        SEATED = 'SEATED', 'Seated'
        COMPLETED = 'COMPLETED', 'Completed'
        CANCELLED = 'CANCELLED', 'Cancelled'
        NO_SHOW = 'NO_SHOW', 'No Show'

    customer = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='reservations'
    )
    restaurant = models.ForeignKey(
        Restaurant,
        on_delete=models.CASCADE,
        related_name='reservations'
    )
    reservation_date = models.DateField()
    reservation_time = models.TimeField()
    party_size = models.PositiveIntegerField()
    status = models.CharField(max_length=20, choices=Status.choices, default=Status.PENDING)
    table_number = models.CharField(max_length=20, blank=True)
    table_session = models.ForeignKey(
        'orders.TableSession',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='reservations'
    )
    special_requests = models.TextField(blank=True)
    pre_order_total = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['reservation_date', 'reservation_time']

    def __str__(self):
        return f"Reservation #{self.id} - {self.customer.username} - {self.restaurant.name}"

class PreOrderItem(models.Model):
    reservation = models.ForeignKey(
        Reservation,
        on_delete=models.CASCADE,
        related_name='pre_order_items'
    )
    menu_item = models.ForeignKey(
        MenuItem,
        on_delete=models.SET_NULL,
        null=True,
        related_name='pre_order_items'
    )
    variant = models.ForeignKey(
        'restaurants.MenuItemVariant',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='pre_order_items'
    )
    item_name = models.CharField(max_length=150)
    variant_name = models.CharField(max_length=50, blank=True)
    quantity = models.PositiveIntegerField(default=1)
    unit_price = models.DecimalField(max_digits=10, decimal_places=2)
    subtotal = models.DecimalField(max_digits=10, decimal_places=2)

    def save(self, *args, **kwargs):
        self.subtotal = self.unit_price * self.quantity
        super().save(*args, **kwargs)

    def __str__(self):
        label = f" ({self.variant_name})" if self.variant_name else ""
        return f"{self.quantity}x {self.item_name}{label}"