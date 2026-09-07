from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import (
    OrderViewSet, TableSessionViewSet,
    CreateCheckoutSessionView, StripeWebhookView, StripeReturnView, StripeCancelView,
    PaymentStatusView,
)

router = DefaultRouter()
router.register('orders', OrderViewSet, basename='order')
router.register('table-sessions', TableSessionViewSet, basename='tablesession')

urlpatterns = [
    path('', include(router.urls)),
    path('payments/<int:payment_id>/create-checkout-session/', CreateCheckoutSessionView.as_view(), name='create-checkout-session'),
    path('stripe-webhook/', StripeWebhookView.as_view(), name='stripe-webhook'),
    path('stripe-return/', StripeReturnView.as_view(), name='stripe-return'),
    path('stripe-cancel/', StripeCancelView.as_view(), name='stripe-cancel'),
    path('payments/<int:payment_id>/status/', PaymentStatusView.as_view(), name='payment-status'),
]