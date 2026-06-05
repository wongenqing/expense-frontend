import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// 1️⃣ Global navigator key — also add this to your MaterialApp in main.dart
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static const String _channelId = 'budget_alerts';
  static const String _channelName = 'Budget Alerts';
  static const String _channelDesc = 'Budget spending alerts';

  // 2️⃣ Track if app was launched via notification tap
  static bool launchedFromNotification = false;

  static Future<void> initialize() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');

    const initSettings = InitializationSettings(
      android: androidInit,
    );

    await _notifications.initialize(
      initSettings,

      // 3️⃣ Fires when user taps notification while app is open or in background
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        _handleNotificationTap(response.payload);
      },

      // 4️⃣ Fires when user taps notification from background (older Android)
      onDidReceiveBackgroundNotificationResponse: _backgroundNotificationHandler,
    );

    // 5️⃣ Handle cold start — app was fully terminated when notification was tapped
    final launchDetails = await _notifications
        .getNotificationAppLaunchDetails();

    if (launchDetails?.didNotificationLaunchApp == true) {
      launchedFromNotification = true; // BudgetPage will read this flag
    }

    await _notifications
    .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
    ?.requestNotificationsPermission();
  }

  // 6️⃣ Navigation handler — called on foreground/background tap
  static void _handleNotificationTap(String? payload) {
    navigatorKey.currentState?.pushNamedAndRemoveUntil(
      '/budget',
      (route) => route.isFirst, // keeps home page underneath in the stack
    );
  }

  static Future<void> showBudgetAlert({
    required String title,
    required String body,
    int? id,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );

    const details = NotificationDetails(android: androidDetails);

    await _notifications.show(
      id ?? 1001,
      title,
      body,
      details,
      // Optional: pass payload to identify which budget was tapped
      payload: 'budget_alert',
    );
  }
}

// 7️⃣ Must be a top-level function (outside any class) for background handling
@pragma('vm:entry-point')
void _backgroundNotificationHandler(NotificationResponse response) {
  // Navigation from here is not possible directly (different isolate),
  // so we just let the app open — initState cold-start check handles the rest
}