from django.db import models
from django.conf import settings
from restaurants.models import Restaurant, MenuItem, MenuItemVariant


class TableSession(models.Model):
    class Status(models.TextChoices):
        OPEN = 'OPEN', 'Open'
        PAID = 'PAID', 'Paid'
        CLOSED = 'CLOSED', 'Closed'

    restaurant = models.ForeignKey(
        Restaurant, on_delete=models.CASCADE, related_name='table_sessions'
    )
    customer = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='table_sessions'
    )
    table_number = models.CharField(max_length=20)
    status = models.CharField(max_length=10, choices=Status.choices, default=Status.OPEN)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    @property
    def total_amount(self):
        return self.orders.aggregate(total=models.Sum('total_amount'))['total'] or 0

    def __str__(self):
        return f"Table {self.table_number} — {self.restaurant.name} ({self.status})"


class Order(models.Model):
    class OrderType(models.TextChoices):
        DINE_IN = 'DINE_IN', 'Dine In'
        TAKEAWAY = 'TAKEAWAY', 'Takeaway'
        DELIVERY = 'DELIVERY', 'Delivery'

    class Status(models.TextChoices):
        AWAITING_PAYMENT = 'AWAITING_PAYMENT', 'Awaiting Payment'
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
    table_session = models.ForeignKey(
        TableSession,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
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
    variant = models.ForeignKey(
        MenuItemVariant,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='order_items'
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


class Payment(models.Model):
    class Method(models.TextChoices):
        MOCK = 'MOCK', 'Mock Payment'
        CASH = 'CASH', 'Cash'
        CARD = 'CARD', 'Card'

    class Status(models.TextChoices):
        PENDING = 'PENDING', 'Pending'
        COMPLETED = 'COMPLETED', 'Completed'
        FAILED = 'FAILED', 'Failed'

    order = models.ForeignKey(
        Order, on_delete=models.CASCADE, null=True, blank=True, related_name='payments'
    )
    table_session = models.ForeignKey(
        TableSession, on_delete=models.CASCADE, null=True, blank=True, related_name='payments'
    )
    amount = models.DecimalField(max_digits=10, decimal_places=2)
    method = models.CharField(max_length=10, choices=Method.choices, default=Method.MOCK)
    status = models.CharField(max_length=10, choices=Status.choices, default=Status.PENDING)
    created_at = models.DateTimeField(auto_now_add=True)
    paid_at = models.DateTimeField(null=True, blank=True)

    def __str__(self):
        target = f"Order #{self.order_id}" if self.order_id else f"Table Session #{self.table_session_id}"
        return f"Payment for {target} — Rs.{self.amount} ({self.status})"