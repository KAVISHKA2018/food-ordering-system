from django.urls import path
from .views import RecommendationsForMeView, RestaurantRecommendationsView, OrderAgainView

urlpatterns = [
    path('recommendations/for-me/', RecommendationsForMeView.as_view(), name='recommendations-for-me'),
    path('recommendations/order-again/', OrderAgainView.as_view(), name='recommendations-order-again'),
    path('recommendations/restaurant/<int:restaurant_id>/', RestaurantRecommendationsView.as_view(), name='recommendations-restaurant'),
]