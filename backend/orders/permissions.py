from rest_framework import permissions


class IsOrderOwnerOrRestaurantStaff(permissions.BasePermission):
    """
    Customers can view/manage only their own orders.
    Restaurant admins can view/manage orders belonging to their restaurant.
    """
    def has_object_permission(self, request, view, obj):
        user = request.user
        if obj.customer == user:
            return True
        if obj.restaurant.owner == user:
            return True
        return False