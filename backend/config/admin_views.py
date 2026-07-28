from django.contrib.admin.views.decorators import staff_member_required
from django.shortcuts import render
from django.db.models import Count, Sum
from accounts.models import User
from restaurants.models import Restaurant, MenuItem
from orders.models import Order
from reservations.models import Reservation


@staff_member_required
def admin_dashboard(request):
    user_counts = User.objects.values('role').annotate(count=Count('id'))
    total_restaurants = Restaurant.objects.filter(is_active=True).count()
    total_menu_items = MenuItem.objects.count()

    order_counts = Order.objects.values('status').annotate(count=Count('id'))
    total_orders = Order.objects.count()
    total_revenue = Order.objects.filter(status='COMPLETED').aggregate(
        total=Sum('total_amount')
    )['total'] or 0

    reservation_counts = Reservation.objects.values('status').annotate(count=Count('id'))
    total_reservations = Reservation.objects.count()

    recent_orders = Order.objects.select_related('customer', 'restaurant').order_by('-created_at')[:10]
    recent_reservations = Reservation.objects.select_related('customer', 'restaurant').order_by('-created_at')[:10]

    context = {
        'title': 'System Dashboard',
        'user_counts': user_counts,
        'total_restaurants': total_restaurants,
        'total_menu_items': total_menu_items,
        'order_counts': order_counts,
        'total_orders': total_orders,
        'total_revenue': total_revenue,
        'reservation_counts': reservation_counts,
        'total_reservations': total_reservations,
        'recent_orders': recent_orders,
        'recent_reservations': recent_reservations,
    }
    return render(request, 'admin/dashboard.html', context)