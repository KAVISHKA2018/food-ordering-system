from rest_framework import permissions


class IsOwnerOrReadOnly(permissions.BasePermission):
    """
    Anyone can view (GET). Only the restaurant's owner can edit/delete.
    """
    def has_object_permission(self, request, view, obj):
        if request.method in permissions.SAFE_METHODS:
            return True
        return obj.owner == request.user


class CanCreateRestaurant(permissions.BasePermission):
    """
    Only System Admins (or Django superusers) can create new restaurants.
    Restaurant Admins can no longer self-register a restaurant — a System
    Admin sets them up (typically via Django admin) and assigns ownership.
    """
    def has_permission(self, request, view):
        if request.method in permissions.SAFE_METHODS:
            return True
        if view.action == 'create':
            return request.user.is_authenticated and (
                request.user.role == 'SYSTEM_ADMIN' or request.user.is_superuser
            )
        return True


class IsRestaurantOwnerOfItem(permissions.BasePermission):
    """
    For Category and MenuItem objects: only the admin who owns the
    parent restaurant can edit/delete. Everyone can still view (GET).
    """
    def has_object_permission(self, request, view, obj):
        if request.method in permissions.SAFE_METHODS:
            return True
        return obj.restaurant.owner == request.user