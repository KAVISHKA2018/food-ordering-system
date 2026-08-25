from rest_framework import serializers
from .models import DeviceToken


class DeviceTokenSerializer(serializers.Serializer):
    token = serializers.CharField()
    platform = serializers.ChoiceField(choices=DeviceToken.Platform.choices, default=DeviceToken.Platform.ANDROID)