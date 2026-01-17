import 'dart:ui';

import 'package:app/bloc/forgot_password_cubit.dart';
import 'package:flutter/gestures.dart';
import 'package:app/bloc/login_bloc/auth_cubit.dart';
import 'package:app/bloc/otp_verification_cubit.dart';
import 'package:app/bloc/reset_password_cubit.dart';
import 'package:app/bloc/demo_bloc_cubit.dart';
import 'package:app/bloc/dashboard_cubit.dart';
import 'package:app/bloc/ticket_cubit.dart';

import 'package:app/bloc/selfie_upload_cubit.dart';
import 'package:app/provider/locale_provider.dart';
import 'package:app/provider/theme_provider.dart';
import 'package:app/routes/route_generator.dart';
import 'package:app/commonWidgets/global_loading_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';

import 'app_config.dart';
import 'bloc/asset_audit_photo_upload_cubit.dart';
import 'bloc/audit_schedule_status_cubit.dart';
import 'repositories/audit_schedule_repository.dart';
import 'l10n/l10n.dart';
import 'services/service_locator.dart';
import 'utils/logger.dart';

GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Custom scroll behavior for better keyboard handling
class CustomScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.stylus,
  };
}

class AppRoot extends StatefulWidget {
  final AppConfig config;

  const AppRoot({
    super.key,
    required this.config,
  });

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Logger.debugLog('🔄 AppRoot: WidgetsBindingObserver registered');
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    Logger.debugLog('🔄 AppRoot: WidgetsBindingObserver removed');
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    switch (state) {
      case AppLifecycleState.resumed:
        Logger.debugLog('🟢 App resumed (foreground)');
        // Databases will be automatically reopened on next access due to .isOpen check
        break;
        
      case AppLifecycleState.inactive:
        Logger.debugLog('🟡 App inactive');
        break;
        
      case AppLifecycleState.paused:
        Logger.debugLog('🟠 App paused (background)');
        _closeDatabasesOnBackground();
        break;
        
      case AppLifecycleState.detached:
        Logger.debugLog('🔴 App detached');
        break;
        
      case AppLifecycleState.hidden:
        Logger.debugLog('⚫ App hidden');
        break;
    }
  }

  /// Close databases when app goes to background to prevent stale connections
  void _closeDatabasesOnBackground() {
    try {
      Logger.debugLog('📊 Closing databases due to app going to background...');
      
      // Close all service databases
      // Note: We don't await these as they should complete quickly
      // and we don't want to block the lifecycle event
      ServiceLocator().imageUploadService.close();
      ServiceLocator().centralAssetAuditDataService.close();
      ServiceLocator().pendingRequestService.close();
      
      Logger.debugLog('✅ Database close initiated for all services');
    } catch (e) {
      Logger.errorLog('❌ Error closing databases on background: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: widget.config.globalLoadingCubit),
        BlocProvider(create: (context) => DemoBlocCubit(widget.config.askRepository)),
        BlocProvider(create: (context) => AuthCubit(widget.config.authRepository)),
        BlocProvider(create: (context) => ForgotPasswordCubit(widget.config.authRepository)),
        BlocProvider(create: (context) => OtpVerificationCubit(widget.config.authRepository)),
        BlocProvider(create: (context) => ResetPasswordCubit(widget.config.authRepository)),
        BlocProvider(create: (context) => DashboardCubit(widget.config.dashboardRepository)),
        BlocProvider(create: (context) => TicketCubit(ticketRepository: widget.config.ticketRepository)),
        
        BlocProvider(create: (context) => SelfieUploadCubit(widget.config.selfieUploadRepository)),
        BlocProvider(create: (context) => AssetAuditPhotoUploadCubit(widget.config.assetAuditPhotoUploadRepository)),
        BlocProvider(create: (context) => AuditScheduleStatusCubit(widget.config.auditScheduleRepository)),
      ],
      child: MultiProvider(
        providers: [
          Provider<AppConfig>.value(value: widget.config),
          Provider<AuditScheduleRepository>.value(value: widget.config.auditScheduleRepository),
          ChangeNotifierProvider(create: (context) => LocaleProvider()),
          ChangeNotifierProvider(create: (context) => ThemeProvider()),
        ],
        builder: (context, child) {
          final localeProvider = Provider.of<LocaleProvider>(context);
          final themeProvider = Provider.of<ThemeProvider>(context);
          return initMaterialApp(localeProvider, themeProvider);
        },
      ),
    );
  }

  Widget initMaterialApp([LocaleProvider? localeProvider, ThemeProvider? themeProvider]) {
    return GestureDetector(
      onTap: () {
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: WillPopScope(
        onWillPop: () async => false, // Disable Android back button
        child: MaterialApp(
          title: 'Nexgen',
          navigatorKey: navigatorKey,
          debugShowCheckedModeBanner: false,
          scrollBehavior: CustomScrollBehavior(),
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: L10n.all,
          locale: localeProvider!.locale,
          builder: (context, child) {
            return FToastBuilder()(
              context,
              GlobalLoadingOverlay(child: child!),
            );
          },
          themeMode: ThemeMode.system,
          theme: MyThemes.lightThemeMustard,
          onGenerateRoute: generateRoute, // 🚀 uses _noSwipeRoute inside
        ),
      ),
    );
  }
}
