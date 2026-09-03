from rest_framework import permissions


class IsRestaurantOwnerOfPromotion(permissions.BasePermission):
    def has_permission(self, request, view):
        if request.method in permissions.SAFE_METHODS:
            return True
        return request.user.is_authenticated and request.user.role == 'RESTAURANT_ADMIN'

    def has_object_permission(self, request, view, obj):
        if request.method in permissions.SAFE_METHODS:
            return True
        return obj.restaurant.owner == request.user