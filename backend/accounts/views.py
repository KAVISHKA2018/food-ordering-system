from rest_framework import generics, status
from rest_framework.response import Response
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.views import APIView
from rest_framework_simplejwt.tokens import RefreshToken
from django.contrib.auth import get_user_model
from django.contrib.auth.hashers import make_password, check_password
from django.utils import timezone
from datetime import timedelta
import random

from .serializers import RegisterSerializer, UserSerializer
from .models import PhoneOTP

from rest_framework.parsers import MultiPartParser, FormParser, JSONParser

User = get_user_model()


class RegisterView(generics.CreateAPIView):
    """Legacy — kept for backward compatibility, unused by the current
    customer app flow (see RegisterWithDetailsView)."""
    queryset = User.objects.all()
    serializer_class = RegisterSerializer
    permission_classes = [AllowAny]

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user = serializer.save()

        refresh = RefreshToken.for_user(user)
        return Response({
            'user': UserSerializer(user).data,
            'refresh': str(refresh),
            'access': str(refresh.access_token),
        }, status=status.HTTP_201_CREATED)


class MeView(APIView):
    permission_classes = [IsAuthenticated]
    parser_classes = [MultiPartParser, FormParser, JSONParser]  # supports profile picture uploads

    def get(self, request):
        return Response(UserSerializer(request.user).data)

    def patch(self, request):
        serializer = UserSerializer(request.user, data=request.data, partial=True)
        serializer.is_valid(raise_exception=True)
        serializer.save()
        return Response(serializer.data)


# --- Phone OTP: used ONLY to verify a phone number during registration ---

def _generate_otp_code():
    return str(random.randint(1000, 9999))


class RequestOTPView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        phone_number = (request.data.get('phone_number') or '').strip()
        if not phone_number:
            return Response({"detail": "Phone number is required."}, status=status.HTTP_400_BAD_REQUEST)

        PhoneOTP.objects.filter(phone_number=phone_number, is_verified=False).delete()

        code = _generate_otp_code()
        PhoneOTP.objects.create(
            phone_number=phone_number,
            code=code,
            expires_at=timezone.now() + timedelta(minutes=5),
        )

        # MOCK DELIVERY: a real system would send this via an SMS gateway
        # (e.g. Twilio, Notify.lk). Returned directly here for dev/demo.
        return Response({
            "success": True,
            "message": "OTP generated (mock — no real SMS sent).",
            "debug_otp": code,
            "expires_in_seconds": 300,
        })


class VerifyOTPView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        phone_number = (request.data.get('phone_number') or '').strip()
        code = (request.data.get('code') or '').strip()

        if not phone_number or not code:
            return Response({"detail": "Phone number and code are required."}, status=status.HTTP_400_BAD_REQUEST)

        otp = PhoneOTP.objects.filter(
            phone_number=phone_number, code=code, is_verified=False
        ).order_by('-created_at').first()

        if not otp:
            return Response({"detail": "Invalid OTP code."}, status=status.HTTP_400_BAD_REQUEST)
        if otp.expires_at < timezone.now():
            return Response(
                {"detail": "This OTP code has expired. Please request a new one."},
                status=status.HTTP_400_BAD_REQUEST
            )

        otp.is_verified = True
        otp.verified_at = timezone.now()
        otp.save()

        return Response({"success": True})


# --- Registration: full details, phone verified via OTP above ---

class RegisterWithDetailsView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        data = request.data
        first_name = (data.get('first_name') or '').strip()
        last_name = (data.get('last_name') or '').strip()
        nic = (data.get('nic') or '').strip()
        address = (data.get('address') or '').strip()
        phone_number = (data.get('phone_number') or '').strip()
        username = (data.get('username') or '').strip()
        password = data.get('password') or ''
        confirm_password = data.get('confirm_password') or ''

        errors = {}
        if not first_name:
            errors['first_name'] = 'First name is required.'
        if not phone_number:
            errors['phone_number'] = 'Contact number is required.'
        if not username:
            errors['username'] = 'Username is required.'
        elif User.objects.filter(username=username).exists():
            errors['username'] = 'This username is already taken.'
        if not password or len(password) < 6:
            errors['password'] = 'Password must be at least 6 characters.'
        if password != confirm_password:
            errors['confirm_password'] = 'Passwords do not match.'
        if phone_number and User.objects.filter(phone_number=phone_number).exists():
            errors['phone_number'] = 'This phone number is already registered.'

        if errors:
            return Response(errors, status=status.HTTP_400_BAD_REQUEST)

        recent_cutoff = timezone.now() - timedelta(minutes=15)
        verified_otp = PhoneOTP.objects.filter(
            phone_number=phone_number, is_verified=True, verified_at__gte=recent_cutoff
        ).order_by('-verified_at').first()

        if not verified_otp:
            return Response(
                {"detail": "Please verify your phone number before completing registration."},
                status=status.HTTP_400_BAD_REQUEST
            )

        user = User.objects.create(
            username=username,
            first_name=first_name,
            last_name=last_name,
            nic=nic,
            address=address,
            phone_number=phone_number,
            role=User.Role.CUSTOMER,
        )
        user.set_password(password)
        user.save()

        refresh = RefreshToken.for_user(user)
        return Response({
            "user": UserSerializer(user).data,
            "access": str(refresh.access_token),
            "refresh": str(refresh),
        }, status=status.HTTP_201_CREATED)


# --- Login: username OR phone number + password (default login) ---

class LoginWithPasswordView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        identifier = (request.data.get('identifier') or '').strip()
        password = request.data.get('password') or ''

        if not identifier or not password:
            return Response(
                {"detail": "Username/phone number and password are required."},
                status=status.HTTP_400_BAD_REQUEST
            )

        user = User.objects.filter(username=identifier).first() or \
            User.objects.filter(phone_number=identifier).first()

        if not user or not user.check_password(password):
            return Response(
                {"detail": "Incorrect username/phone number or password."},
                status=status.HTTP_400_BAD_REQUEST
            )

        refresh = RefreshToken.for_user(user)
        return Response({
            "user": UserSerializer(user).data,
            "access": str(refresh.access_token),
            "refresh": str(refresh),
        })


# --- Optional PIN login, enabled by the customer from Settings ---

class EnablePinView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        pin = (request.data.get('pin') or '').strip()
        if not pin or len(pin) != 4 or not pin.isdigit():
            return Response({"detail": "A 4-digit PIN is required."}, status=status.HTTP_400_BAD_REQUEST)

        user = request.user
        user.pin_code = make_password(pin)
        user.pin_enabled = True
        user.save()
        return Response(UserSerializer(user).data)


class DisablePinView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        user = request.user
        user.pin_code = ''
        user.pin_enabled = False
        user.save()
        return Response(UserSerializer(user).data)


class LoginWithPINView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        phone_number = (request.data.get('phone_number') or '').strip()
        pin = (request.data.get('pin') or '').strip()

        if not phone_number or not pin:
            return Response({"detail": "Phone number and PIN are required."}, status=status.HTTP_400_BAD_REQUEST)

        user = User.objects.filter(phone_number=phone_number).first()
        if not user or not user.pin_enabled or not user.pin_code or not check_password(pin, user.pin_code):
            return Response({"detail": "Incorrect PIN."}, status=status.HTTP_400_BAD_REQUEST)

        refresh = RefreshToken.for_user(user)
        return Response({
            "user": UserSerializer(user).data,
            "access": str(refresh.access_token),
            "refresh": str(refresh),
        })

# --- Change phone number: requires a recently-verified OTP for the NEW
# number (via the same RequestOTPView/VerifyOTPView used at registration) ---

class ChangePhoneNumberView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        new_phone = (request.data.get('phone_number') or '').strip()
        if not new_phone:
            return Response({"detail": "Phone number is required."}, status=status.HTTP_400_BAD_REQUEST)

        if User.objects.filter(phone_number=new_phone).exclude(id=request.user.id).exists():
            return Response(
                {"detail": "This phone number is already registered to another account."},
                status=status.HTTP_400_BAD_REQUEST
            )

        recent_cutoff = timezone.now() - timedelta(minutes=15)
        verified_otp = PhoneOTP.objects.filter(
            phone_number=new_phone, is_verified=True, verified_at__gte=recent_cutoff
        ).order_by('-verified_at').first()

        if not verified_otp:
            return Response(
                {"detail": "Please verify this phone number with the OTP code first."},
                status=status.HTTP_400_BAD_REQUEST
            )

        user = request.user
        user.phone_number = new_phone
        user.save()
        return Response(UserSerializer(user).data)