import 'dart:convert';
import 'dart:async';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../services/local_storage_constants.dart';
import '../services/local_storage_db.dart';
import '../services/local_storage_service.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Uncomment if using Firebase services in background
  // await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  print('📩 Handling a background message: ${message.messageId}');
  // You can process message.data here if needed
}

class PushNotificationApi {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  final AndroidNotificationChannel _androidChannel = const AndroidNotificationChannel(
    'high_importance_channel', // id
    'High Importance Notifications', // title
    description: 'This channel is used for important notifications.', // description
    importance: Importance.high,
  );

  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  // Handle notification payload
  void handleMessage(RemoteMessage? message) {
    if (message == null) return;

    print('📬 Message data: ${message.data}');
    final payload = message.data;

    if (payload['ActionId'] == 1) {
      // Example: Navigate to order history
      // navigatorKey.currentState?.pushNamed(orderHistory, arguments: false);
    }
  }

  // Initialize local notifications
  Future<void> initLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const settings = InitializationSettings(android: androidSettings, iOS: iosSettings);

    await _localNotifications.initialize(
      settings,
      onDidReceiveNotificationResponse: (details) {
        if (details.payload == null) return;
        final payload = jsonDecode(details.payload!);
        handleMessage(RemoteMessage(data: payload));
      },
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_androidChannel);
  }

  // Initialize Firebase push notifications
  Future<void> initPushNotifications() async {
    await _firebaseMessaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // Handle app launched from terminated state
    final initialMessage = await _firebaseMessaging.getInitialMessage();
    handleMessage(initialMessage);

    // Handle when app is in background and opened via notification
    FirebaseMessaging.onMessageOpenedApp.listen(handleMessage);

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      RemoteNotification? notification = message.notification;
      AndroidNotification? android = notification?.android;

      if (notification != null && android != null && !kIsWeb) {
        _localNotifications.show(
          notification.hashCode,
          notification.title,
          notification.body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              _androidChannel.id,
              _androidChannel.name,
              channelDescription: _androidChannel.description,
              icon: '@mipmap/ic_launcher',
              importance: Importance.high,
              priority: Priority.high,
              playSound: true,
            ),
          ),
          payload: jsonEncode(message.data),
        );
      }
    });

    // Register background handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

  // Full initialization
  Future<void> initNotifications() async {
    // Request permission (iOS & Android 13+)
    final settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      print('❌ Notification permission denied');
    } else {
      print('✅ Notification permission granted');
    }

    // Get FCM token
    final fcmToken = await _firebaseMessaging.getToken();
    if (fcmToken != null) {
      await LocalStorageService.setString(LocalStorageConstants.firebaseToken, fcmToken);
      print('📱 Saved Firebase Token: ${LocalStorageDB.getFireBaseToken}');
    }

    // Initialize local and push notifications
    await initLocalNotifications();
    await initPushNotifications();
  }
}
