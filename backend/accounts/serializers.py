from rest_framework import serializers
from django.contrib.auth import get_user_model

User = get_user_model()


class RegisterSerializer(serializers.ModelSerializer):
    """Legacy — kept only in case anything internal still references it.
    The customer app no longer uses this; see RegisterWithDetailsView."""
    password = serializers.CharField(write_only=True, min_length=8)

    class Meta:
        model = User
        fields = ['id', 'username', 'email', 'password', 'role', 'phone_number']

    def create(self, validated_data):
        user = User.objects.create_user(
            username=validated_data['username'],
            email=validated_data['email'],
            password=validated_data['password'],
            role=validated_data.get('role', User.Role.CUSTOMER),
            phone_number=validated_data.get('phone_number', ''),
        )
        return user


class UserSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = [
            'id', 'username', 'email', 'first_name', 'last_name',
            'role', 'phone_number', 'nic', 'address', 'profile_picture',
            'pin_enabled', 'created_at'
        ]
        # phone_number is intentionally read-only here — changing it must
        # go through ChangePhoneNumberView, which requires a verified OTP.
        # A plain PATCH to /me/ can freely update name/address/email/photo,
        # but any phone_number in that request body is silently ignored.
        read_only_fields = ['phone_number']