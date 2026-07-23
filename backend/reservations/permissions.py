from rest_framework import permissions


class IsReservationOwnerOrRestaurantStaff(permissions.BasePermission):
    """
    Customers can view/manage only their own reservations.
    Restaurant admins can view/manage reservations for their restaurant.
    """
    def has_object_permission(self, request, view, obj):
        user = request.user
        if obj.customer == user:
            return True
        if obj.restaurant.owner == user:
            return True
        return False