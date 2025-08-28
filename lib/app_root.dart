import 'dart:ui';

import 'package:app/bloc/forgot_password_cubit.dart';
import 'package:app/bloc/login_bloc/auth_cubit.dart';
import 'package:app/bloc/otp_verification_cubit.dart';
import 'package:app/bloc/reset_password_cubit.dart';
import 'package:app/bloc/demo_bloc_cubit.dart';
import 'package:app/bloc/dashboard_cubit.dart';
import 'package:app/bloc/ticket_cubit.dart';
import 'package:app/bloc/asset_audit_cubit.dart';
import 'package:app/bloc/energy_reading_cubit.dart';
import 'package:app/bloc/energy_reading_detail_cubit.dart';
import 'package:app/bloc/selfie_upload_cubit.dart';
import 'package:app/provider/locale_provider.dart';
import 'package:app/provider/theme_provider.dart';
import 'package:app/repositories/auth_repository.dart';
import 'package:app/repositories/demo_repository.dart';
import 'package:app/repositories/dashboard_repository.dart';
import 'package:app/repositories/asset_audit_repository.dart';
import 'package:app/repositories/energy_reading_repository.dart';
import 'package:app/routes/route_generator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';

import 'app_config.dart';
import 'l10n/l10n.dart';

GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class AppRoot extends StatelessWidget {
  final AppConfig config;

  const AppRoot({
    super.key,
    required this.config,
  });

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (context) => DemoBlocCubit(config.askRepository)),
        BlocProvider(create: (context) => AuthCubit(config.authRepository)),
        BlocProvider(create: (context) => ForgotPasswordCubit(config.authRepository)),
        BlocProvider(create: (context) => OtpVerificationCubit(config.authRepository)),
        BlocProvider(create: (context) => ResetPasswordCubit(config.authRepository)),
        BlocProvider(create: (context) => DashboardCubit(config.dashboardRepository)),
        BlocProvider(create: (context) => TicketCubit(ticketRepository: config.ticketRepository)),
        BlocProvider(create: (context) => AssetAuditCubit(repository: config.assetAuditRepository)),
        BlocProvider(create: (context) => EnergyReadingCubit(config.energyReadingRepository)),
        BlocProvider(create: (context) => EnergyReadingDetailCubit(config.energyReadingDetailRepository)),
        BlocProvider(create: (context) => SelfieUploadCubit(config.selfieUploadRepository)),
      ],
      child: MultiProvider(
        providers: [
          Provider<AppConfig>.value(value: config),
          ChangeNotifierProvider(create: (context) => LocaleProvider()),
          ChangeNotifierProvider(create: (context) => ThemeProvider()),
          // ChangeNotifierProvider(create: (context) => ProviderDemoProvider(config.cartItemService)),
        ],
        builder: (context, child) {
          final localeProvider = Provider.of<LocaleProvider>(context);
          final themeProvider = Provider.of<ThemeProvider>(context);
          return initMaterialApp(localeProvider, themeProvider);
        },
        // child: initMaterialApp(),
      ),
    );
  }

  Widget initMaterialApp([LocaleProvider? localeProvider, ThemeProvider? themeProvider]) {
    return GestureDetector(
      onTap: () {
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: MaterialApp(
        title: 'Nexgen',
        scrollBehavior: const MaterialScrollBehavior().copyWith(dragDevices: {
          PointerDeviceKind.mouse,
          PointerDeviceKind.touch,
          PointerDeviceKind.stylus,
          PointerDeviceKind.unknown
        }),
        localizationsDelegates: const [
          // AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: L10n.all,
        locale: localeProvider!.locale,
        debugShowCheckedModeBanner: false,
        navigatorKey: navigatorKey,
        builder: FToastBuilder(),
        themeMode: ThemeMode.system,
        theme: MyThemes.lightThemeMustard,
        // home: const CartScreen(),
        // initialRoute: homeScreen,
        onGenerateRoute: (settings) => generateRoute(settings),
      ),
    );
  }
}
