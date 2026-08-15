from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import OrderViewSet, TableSessionViewSet

router = DefaultRouter()
router.register('orders', OrderViewSet, basename='order')
router.register('table-sessions', TableSessionViewSet, basename='tablesession')

urlpatterns = [
    path('', include(router.urls)),
]