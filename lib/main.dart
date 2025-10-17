import 'dart:async';
import 'dart:io';

import 'package:app/constants/constants_methods.dart';
import 'package:app/services/push_notification_api.dart';
import 'package:app/services/location_permission_service.dart';
import 'package:app_links/app_links.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'app_config.dart';
import 'app_root.dart';
import 'bloc/global_bloc_observer.dart';
import 'bloc/global_loading_cubit.dart';
import 'firebase_options.dart';
import 'services/local_storage_db.dart';
import 'database/asset_audit_database.dart';
import 'services/app_initialization_service.dart';
import 'utils.dart';
import 'utils/file_logger.dart';
import 'services/log_push_service.dart';
import 'services/log_push_config.dart';

// Global config variable
AppConfig? globalConfig;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Force portrait orientation
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  // System UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  // Load environment, local storage, DB, location permissions
  await init();

  // Initialize Firebase
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      print('✅ Firebase initialized successfully');
    } else {
      print('✅ Firebase already initialized');
    }
  } catch (e) {
    print('❌ Firebase initialization error: $e');
    // Continue without Firebase if initialization fails
  }
  // Setup Crashlytics only if Firebase is available
  try {
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  } catch (e) {
    print('⚠️ Crashlytics setup failed: $e');
  }

  // Initialize push notifications only if Firebase is available
  try {
    if (Firebase.apps.isNotEmpty) {
      await PushNotificationApi().initNotifications();
      print('✅ Push notifications initialized successfully');
    } else {
      print('⚠️ Skipping push notifications - Firebase not available');
    }
  } catch (e) {
    print('❌ Push notification initialization error: $e');
  }

  // Initialize app configuration
  final _baseUrl = dotenv.env['BASE_URL_DEV'];
  final globalLoadingCubit = GlobalLoadingCubit();
  globalConfig = AppConfig(baseUrl: _baseUrl!, loadingCubit: globalLoadingCubit);

  // Initialize file logger
  await FileLogger.initialize();
  await FileLogger.info('App starting up');

  // Initialize all app services
  print('🔧 Initializing all services...');
  await FileLogger.info('Initializing all services');
  final success = await AppInitializationService.initializeApp(globalConfig!.apiService);
  if (!success) {
    await FileLogger.error('Failed to initialize app services');
    throw Exception('Failed to initialize app services');
  }
  print('✅ All services initialized successfully');
  await FileLogger.info('All services initialized successfully');

  // Start log push service if enabled
  if (LogPushConfig.autoStartOnAppLaunch) {
    await LogPushService.startLogPushing(globalConfig!.apiService);
    await FileLogger.info('Log push service started');
  }

  // HTTP overrides
  HttpOverrides.global = MyHttpOverrides();

  // Bloc observer
  Bloc.observer = GlobalBlocObserver();

  // Check token status
  _checkTokenStatus();

  // Run app
  runApp(AppRoot(
    config: globalConfig!,
  ));
}

Future<void> init() async {
  // Load .env file
  await dotenv.load(fileName: ".env");

  // Initialize local storage
  await LocalStorageDB.init();

  // Initialize SQLite database
  await AssetAuditDatabase().database;

  // Initialize location permissions
  await _initializeLocationPermissions();
}

late AppLinks _appLinks;

// Deep links handling
Future<void> initDeepLinks() async {
  _appLinks = AppLinks();

  final appLink = await _appLinks.getInitialLink();
  if (appLink != null) {
    kDebugPrint('getInitialAppLink: $appLink');
    openAppLink(appLink);
  }

  _appLinks.uriLinkStream.listen((uri) {
    kDebugPrint('onAppLink: $uri');
    openAppLink(uri);
  });
}

void openAppLink(Uri uri) {
  navigatorKey.currentState?.pushNamed(uri.fragment);
}

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
  }
}

// Location permissions
Future<void> _initializeLocationPermissions() async {
  try {
    print('Initializing location permissions...');
    final permissionResult = await LocationPermissionService.requestLocationPermissions();
    if (permissionResult['success']) {
      print('Location permissions initialized successfully');
    } else {
      print('Location permissions initialization failed: ${permissionResult['message']}');
    }
  } catch (e) {
    print('Error initializing location permissions: $e');
  }
}

// Check token status on startup
void _checkTokenStatus() async {
  final token = LocalStorageDB.getToken;
  if (token != null) {
    if (Utils.isTokenExpired(token)) {
      print('Token is expired on app startup');
      await LocalStorageDB.logout();
    } else {
      print('Token is valid on app startup');
    }
  } else {
    print('No token found on app startup');
  }
}
