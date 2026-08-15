from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import RestaurantViewSet, CategoryViewSet, MenuItemViewSet, MenuItemVariantViewSet

router = DefaultRouter()
router.register('restaurants', RestaurantViewSet, basename='restaurant')
router.register('categories', CategoryViewSet, basename='category')
router.register('menu-items', MenuItemViewSet, basename='menuitem')
router.register('menu-item-variants', MenuItemVariantViewSet, basename='menuitemvariant')

urlpatterns = [
    path('', include(router.urls)),
]