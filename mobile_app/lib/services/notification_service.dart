import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../config/api_config.dart';
import 'api_service.dart';

/// Must be a top-level function (not inside a class) — this is how Firebase
/// invokes it when a notification arrives while the app is fully closed
/// or in the background.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  // Nothing else needed here — Android shows the system notification
  // automatically using the payload's "notification" block.
}

class NotificationService {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const _channel = AndroidNotificationChannel(
    'high_importance_channel',
    'General Notifications',
    description: 'Order, payment, and reservation updates',
    importance: Importance.high,
  );

  static Future<void> init() async {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    await _localNotifications.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: (response) {
        if (response.payload != null) {
          _handleNotificationData(jsonDecode(response.payload!));
        }
      },
    );

    // App open (foreground) — Android does NOT show a system notification
    // automatically in this state, so we show one ourselves.
    FirebaseMessaging.onMessage.listen((message) {
      final notification = message.notification;
      if (notification != null) {
        _localNotifications.show(
          notification.hashCode,
          notification.title,
          notification.body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              _channel.id,
              _channel.name,
              channelDescription: _channel.description,
              importance: Importance.high,
              priority: Priority.high,
            ),
          ),
          payload: jsonEncode(message.data),
        );
      }
    });

    // App was backgrounded, user taps the system notification to reopen it.
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _handleNotificationData(message.data);
    });

    // App was fully closed, user taps the system notification to launch it.
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationData(initialMessage.data);
    }

    FirebaseMessaging.instance.onTokenRefresh.listen((_) {
      registerCurrentDevice();
    });
  }

  static void _handleNotificationData(Map<String, dynamic> data) {
    final type = data['type'];
    final context = navigatorKey.currentContext;
    if (context == null) return;

    // Simple routing: open the relevant history screen. Deep-linking to a
    // single order/reservation's detail view can be added later if needed.
    if (type == 'order' || type == 'table_session') {
      Navigator.pushNamed(context, '/orders');
    } else if (type == 'reservation') {
      Navigator.pushNamed(context, '/reservations');
    }
  }

  static Future<void> registerCurrentDevice() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;
      await ApiService.post(
        ApiConfig.registerDevice,
        {'token': token, 'platform': 'ANDROID'},
        auth: true,
      );
    } catch (_) {
      // Non-fatal — notifications just won't arrive on this device.
    }
  }

  static Future<void> unregisterCurrentDevice() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;
      await ApiService.post(
        ApiConfig.unregisterDevice,
        {'token': token},
        auth: true,
      );
    } catch (_) {
      // Non-fatal
    }
  }
}