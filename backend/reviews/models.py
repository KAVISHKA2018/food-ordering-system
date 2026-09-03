from django.db import models
from django.conf import settings
from django.core.validators import MinValueValidator, MaxValueValidator
from restaurants.models import Restaurant, MenuItem
from orders.models import Order, OrderItem


class Review(models.Model):
    customer = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='reviews'
    )
    restaurant = models.ForeignKey(
        Restaurant, on_delete=models.CASCADE, related_name='reviews'
    )
    order = models.OneToOneField(
        Order, on_delete=models.CASCADE, related_name='review'
    )
    rating = models.PositiveSmallIntegerField(
        validators=[MinValueValidator(1), MaxValueValidator(5)]
    )
    comment = models.TextField(blank=True)
    restaurant_reply = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f"{self.customer.username} rated {self.restaurant.name} {self.rating}★"


class FoodReview(models.Model):
    """A per-item rating, given as a second step after the overall order review.
    Affects that specific menu item's rating, not the restaurant's."""
    customer = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='food_reviews'
    )
    order_item = models.OneToOneField(
        OrderItem, on_delete=models.CASCADE, related_name='review'
    )
    menu_item = models.ForeignKey(
        MenuItem, on_delete=models.SET_NULL, null=True, related_name='food_reviews'
    )
    item_name = models.CharField(max_length=150)  # snapshot, survives menu item deletion
    rating = models.PositiveSmallIntegerField(
        validators=[MinValueValidator(1), MaxValueValidator(5)]
    )
    comment = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f"{self.customer.username} rated {self.item_name} {self.rating}★"