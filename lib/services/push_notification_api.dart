import 'dart:async';
import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive/hive.dart';

import '../constants/constants_methods.dart';
import '../hive_local_database/hive_constant.dart';
import '../hive_local_database/hive_db.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  kDebugPrint('Handling a background message ${message.messageId}');
}

class PushNotificationApi {
  final _firebaseMessaging = FirebaseMessaging.instance;
  var boxes = Hive.box(HiveConstant.userCreds);

  final AndroidNotificationChannel _androidChannel = const AndroidNotificationChannel(
    'high_importance_channel', // id
    'High Importance Notifications', // title
    description: 'This channel is used for important notifications.', // description
    importance: Importance.high,
  );

  final _localNotifications = FlutterLocalNotificationsPlugin();

  void handleMessage(RemoteMessage? message) {
    if (message == null) return;
    kDebugPrint("Message ${message.data}");
    final payload = jsonDecode(message.data["payload"]);
    if (payload["ActionId"] == 1) {
      // kDebugPrint("static Message ${message.data["payload"]["ActionId"]}");
      // navigatorKey.currentState?.pushNamed(orderHistory, arguments: false);
    }
  }

  Future initLocalNotifications() async {
    const iOS = DarwinInitializationSettings();
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android, iOS: iOS);

    await _localNotifications.initialize(
      settings,
      // onDidReceiveBackgroundNotificationResponse: (details) {
      //   kDebugPrint(details);
      //   final message = RemoteMessage.fromMap(jsonDecode(details.payload!));
      //   handleMessage(message);
      // },
      onDidReceiveNotificationResponse: (details) {
        final message = RemoteMessage.fromMap(jsonDecode(details.payload!));
        handleMessage(message);
      },
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_androidChannel);
  }

  Future initPushNotifications() async {
    await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    FirebaseMessaging.instance.getInitialMessage().then(handleMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(handleMessage);
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    FirebaseMessaging.onMessage.listen((message) {
      RemoteNotification? notification = message.notification;
      // if (notification == null) return;
      AndroidNotification? android = message.notification?.android;
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
            ),
          ),
          payload: jsonEncode(message.toMap()),
        );
      }
    });
  }

  Future<void> initNotifications() async {
    await _firebaseMessaging.requestPermission();
    final fcmToken = await _firebaseMessaging.getToken();
    boxes.put(HiveConstant.firebaseToken, fcmToken.toString());
    kDebugPrint("saved Firebase Token: ${HiveDB.getFireBaseToken}");
    initPushNotifications();
    initLocalNotifications();
  }
}
