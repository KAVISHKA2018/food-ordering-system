import os
import firebase_admin
from firebase_admin import credentials, messaging
from django.conf import settings

if not firebase_admin._apps:
    cred_path = os.path.join(settings.BASE_DIR, 'firebase-service-account.json')
    cred = credentials.Certificate(cred_path)
    firebase_admin.initialize_app(cred)


def send_push_notification(user, title, body, data=None):
    """Sends a push notification to every device the user is logged in on.
    Silently does nothing if the user has no registered devices, and
    cleans up any tokens Firebase reports as invalid (e.g. app uninstalled)."""
    from .models import DeviceToken

    tokens = list(DeviceToken.objects.filter(user=user).values_list('token', flat=True))
    if not tokens:
        return

    message = messaging.MulticastMessage(
        notification=messaging.Notification(title=title, body=body),
        data={k: str(v) for k, v in (data or {}).items()},
        tokens=tokens,
    )

    try:
        response = messaging.send_each_for_multicast(message)
        for idx, resp in enumerate(response.responses):
            if not resp.success:
                DeviceToken.objects.filter(token=tokens[idx]).delete()
    except Exception as e:
        print(f"FCM send error: {e}")