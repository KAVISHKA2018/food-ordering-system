from django.urls import path
from rest_framework_simplejwt.views import TokenObtainPairView, TokenRefreshView
from .views import (
    RegisterView, MeView, RequestOTPView, VerifyOTPView,
    RegisterWithDetailsView, LoginWithPasswordView,
    EnablePinView, DisablePinView, LoginWithPINView,
    ChangePhoneNumberView,
    CreateDeliveryStaffView, MyDeliveryStaffView, ToggleDeliveryStaffActiveView,
)

urlpatterns = [
    path('register/', RegisterView.as_view(), name='register'),
    path('login/', TokenObtainPairView.as_view(), name='login'),
    path('token/refresh/', TokenRefreshView.as_view(), name='token_refresh'),
    path('me/', MeView.as_view(), name='me'),

    path('request-otp/', RequestOTPView.as_view(), name='request-otp'),
    path('verify-otp/', VerifyOTPView.as_view(), name='verify-otp'),
    path('register-with-details/', RegisterWithDetailsView.as_view(), name='register-with-details'),
    path('login-with-password/', LoginWithPasswordView.as_view(), name='login-with-password'),

    path('enable-pin/', EnablePinView.as_view(), name='enable-pin'),
    path('disable-pin/', DisablePinView.as_view(), name='disable-pin'),
    path('login-with-pin/', LoginWithPINView.as_view(), name='login-with-pin'),

    path('change-phone-number/', ChangePhoneNumberView.as_view(), name='change-phone-number'),

    path('delivery-staff/create/', CreateDeliveryStaffView.as_view(), name='delivery-staff-create'),
    path('delivery-staff/mine/', MyDeliveryStaffView.as_view(), name='delivery-staff-mine'),
    path('delivery-staff/<int:staff_id>/toggle-active/', ToggleDeliveryStaffActiveView.as_view(), name='delivery-staff-toggle-active'),
]