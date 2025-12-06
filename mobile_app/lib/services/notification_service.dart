import 'package:firebase_messaging/firebase_messaging.dart';
import '../config/app_config.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  FirebaseMessaging? _messaging;
  bool _initialized = false;

  FirebaseMessaging get messaging {
    _messaging ??= FirebaseMessaging.instance;
    return _messaging!;
  }

  // Callback for handling notification taps
  Function(RemoteMessage)? onNotificationTap;

  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Request permission
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        print('User granted notification permission');
      } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
        print('User granted provisional notification permission');
      } else {
        print('User declined or has not accepted notification permission');
      }

      // Subscribe to topic
      await subscribeToTopic();

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Handle background message taps
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

      // Check if app was opened from a notification
      final initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) {
        _handleNotificationTap(initialMessage);
      }

      _initialized = true;
    } catch (e) {
      print('Error initializing notifications: $e');
    }
  }

  Future<void> subscribeToTopic() async {
    try {
      await messaging.subscribeToTopic(AppConfig.notificationTopic);
      print('Subscribed to topic: ${AppConfig.notificationTopic}');
    } catch (e) {
      print('Error subscribing to topic: $e');
    }
  }

  Future<void> unsubscribeFromTopic() async {
    try {
      await messaging.unsubscribeFromTopic(AppConfig.notificationTopic);
      print('Unsubscribed from topic: ${AppConfig.notificationTopic}');
    } catch (e) {
      print('Error unsubscribing from topic: $e');
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    print('Received foreground message: ${message.messageId}');
    print('Message data: ${message.data}');
    print('Message notification: ${message.notification?.title}');

    // Show local notification or in-app notification
    // In a real app, you might want to use flutter_local_notifications
    // For now, we'll just print and let the UI handle it via listeners
  }

  void _handleNotificationTap(RemoteMessage message) {
    print('Notification tapped: ${message.messageId}');
    if (onNotificationTap != null) {
      onNotificationTap!(message);
    }
  }

  Future<String?> getToken() async {
    try {
      return await messaging.getToken();
    } catch (e) {
      print('Error getting FCM token: $e');
      return null;
    }
  }

  void setNotificationTapHandler(Function(RemoteMessage) handler) {
    onNotificationTap = handler;
  }
}

// Top-level function for background message handling
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('Handling background message: ${message.messageId}');
  // Background message handling logic
}

