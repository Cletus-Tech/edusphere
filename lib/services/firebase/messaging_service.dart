import 'package:firebase_messaging/firebase_messaging.dart';

/// Push notification setup. Kept minimal for Stage 1 — wires up
/// permission requests and the device token, ready for feature modules
/// (course reminders, community replies, exam alerts) to hook into
/// later without touching this file's structure.
class MessagingService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  /// Callback invoked whenever a push arrives while the app is in the
  /// foreground. Feature modules register a handler here (e.g. to show
  /// an in-app banner) instead of this service owning any UI.
  void Function(RemoteMessage message)? onForegroundMessage;

  Future<NotificationSettings> initialize() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    FirebaseMessaging.onMessage.listen((message) {
      onForegroundMessage?.call(message);
    });

    return settings;
  }

  Future<String?> getToken() => _messaging.getToken();
}

