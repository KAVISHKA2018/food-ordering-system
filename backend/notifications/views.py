from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from rest_framework import status
from .models import DeviceToken
from .serializers import DeviceTokenSerializer


class RegisterDeviceView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        serializer = DeviceTokenSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        token = serializer.validated_data['token']
        platform = serializer.validated_data['platform']

        # A token belongs to one physical device — if it was previously tied
        # to a different account (e.g. someone logged out and a new user
        # logged in on the same phone), reassign it to the current user.
        DeviceToken.objects.update_or_create(
            token=token,
            defaults={'user': request.user, 'platform': platform},
        )
        return Response({'success': True}, status=status.HTTP_200_OK)


class UnregisterDeviceView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        token = request.data.get('token')
        if token:
            DeviceToken.objects.filter(token=token).delete()
        return Response({'success': True}, status=status.HTTP_200_OK)