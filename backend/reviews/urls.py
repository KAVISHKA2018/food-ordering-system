from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import ReviewViewSet, FoodReviewViewSet

router = DefaultRouter()
router.register('reviews', ReviewViewSet, basename='review')
router.register('food-reviews', FoodReviewViewSet, basename='foodreview')

urlpatterns = [
    path('', include(router.urls)),
]