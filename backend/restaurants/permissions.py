from rest_framework import permissions


class IsOwnerOrReadOnly(permissions.BasePermission):
    """
    Anyone can view (GET). Only the restaurant's owner can edit/delete.
    """
    def has_object_permission(self, request, view, obj):
        if request.method in permissions.SAFE_METHODS:
            return True
        return obj.owner == request.user


class IsRestaurantAdmin(permissions.BasePermission):
    """
    Only users with role RESTAURANT_ADMIN can create restaurants/menu items.
    """
    def has_permission(self, request, view):
        if request.method in permissions.SAFE_METHODS:
            return True
        return (
            request.user.is_authenticated and
            request.user.role == 'RESTAURANT_ADMIN'
        )


class IsRestaurantOwnerOfItem(permissions.BasePermission):
    """
    For Category and MenuItem objects: only the admin who owns the
    parent restaurant can edit/delete. Everyone can still view (GET).
    """
    def has_object_permission(self, request, view, obj):
        if request.method in permissions.SAFE_METHODS:
            return True
        # obj is a Category or MenuItem — both have .restaurant
        return obj.restaurant.owner == request.user