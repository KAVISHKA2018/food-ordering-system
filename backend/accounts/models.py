from django.contrib.auth.models import AbstractUser
from django.db import models


class User(AbstractUser):
    class Role(models.TextChoices):
        CUSTOMER = 'CUSTOMER', 'Customer'
        RESTAURANT_ADMIN = 'RESTAURANT_ADMIN', 'Restaurant Admin'
        DELIVERY_STAFF = 'DELIVERY_STAFF', 'Delivery Staff'
        SYSTEM_ADMIN = 'SYSTEM_ADMIN', 'System Admin'

    role = models.CharField(
        max_length=20,
        choices=Role.choices,
        default=Role.CUSTOMER,
    )
    # --- Delivery staff only ---
    delivery_restaurant = models.ForeignKey(
        'restaurants.Restaurant', on_delete=models.SET_NULL, null=True, blank=True,
        related_name='delivery_staff'
    )
    delivery_approved = models.BooleanField(default=False)
    phone_number = models.CharField(max_length=15, blank=True, null=True)
    profile_picture = models.ImageField(
        upload_to='profile_pictures/', blank=True, null=True
    )
    nic = models.CharField(max_length=20, blank=True)
    address = models.CharField(max_length=255, blank=True)
    pin_enabled = models.BooleanField(default=False)
    pin_code = models.CharField(max_length=128, blank=True)  # hashed, separate from main password
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"{self.username} ({self.role})"


class PhoneOTP(models.Model):
    phone_number = models.CharField(max_length=20)
    code = models.CharField(max_length=6)
    is_verified = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)
    expires_at = models.DateTimeField()
    verified_at = models.DateTimeField(null=True, blank=True)

    def __str__(self):
        return f"{self.phone_number} — {self.code} ({'verified' if self.is_verified else 'pending'})"