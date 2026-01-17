import 'package:app/routes/routes.dart';
import 'package:app/screens/energy_reading/energy_reading_screen.dart';
import 'package:app/screens/forgot_password_screen.dart';
import 'package:app/screens/password_updated_Screen.dart';
import 'package:app/screens/pulse_dashboard.dart';
import 'package:app/screens/reset_password_screen.dart';
import 'package:app/screens/splash_screen.dart';
import 'package:app/screens/ticket_screen.dart';
import 'package:app/screens/sqlite_query_screen.dart';
import 'package:flutter/material.dart';

import '../screens/login_screen.dart';
import '../screens/otp_verfication_screen.dart';
import '../screens/welcome_screen.dart';

Route<dynamic> generateRoute(RouteSettings settings) {
  // handle deep link here
  if (settings.name!.contains("/goodMorning")) {
    // return _noSwipeRoute(const DeepLinkExample(), settings);
  }

  switch (settings.name) {
    case "/":
      return _noSwipeRoute(const SplashScreen(), settings);
    case loginScreen:
      return _noSwipeRoute(const LoginScreen(), settings);
    case welcomeScreen:
      return _noSwipeRoute(const WelcomeScreen(), settings);
    case homeScreen:
      return _noSwipeRoute(const PulseDashboard(), settings);
    // return _noSwipeRoute(const HomeScreen(), settings);

    case forgotPasswordScreen:
      return _noSwipeRoute(const ForgotPasswordScreen(), settings);
    case resetPasswordScreen:
      return _noSwipeRoute(const ResetPasswordScreen(), settings);
    case passwordUpdateScreen:
      return _noSwipeRoute(const PasswordUpdatedScreen(), settings);
    case otpVerificationScreen:
      return _noSwipeRoute(const EnterVerificationCodeScreen(), settings);
    case energyReadingScreen:
      return _noSwipeRoute(
        const EnergyReadingScreen(
          siteType: "",
          auditSchId: "",
          siteAuditSchId: "",
          siteId: "",
        ),
        settings,
      );
    case ticketScreen:
      return _noSwipeRoute(const TicketScreen(auditName: "", status: ""), settings);
    case sqliteQueryScreen:
      return _noSwipeRoute(const SQLiteQueryScreen(), settings);

    default:
      return _noSwipeRoute(
        Scaffold(
          appBar: AppBar(title: const Text("ERROR")),
          body: const Center(child: Text("Page not found!")),
        ),
        settings,
      );
  }
}

/// ✅ Custom route: no back-swipe on iOS, no transition animation
PageRoute _noSwipeRoute(Widget child, RouteSettings settings) {
  return PageRouteBuilder(
    settings: settings,
    pageBuilder: (_, __, ___) => child,
    transitionDuration: Duration.zero,
    reverseTransitionDuration: Duration.zero,
    transitionsBuilder: (_, __, ___, child) => child,
  );
}

void navigateBackOrToHome(
  BuildContext context, {
  BuildContext? targetContext,
}) {
  final navigator = Navigator.of(context);

  if (targetContext != null) {
    final targetRoute = ModalRoute.of(targetContext);
    if (targetRoute != null) {
      navigator.popUntil((route) => route == targetRoute);
      return;
    }
  }

  if (navigator.canPop()) {
    navigator.pop();
  } else {
    // Fallback to PulseDashboard if can't pop
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => PulseDashboard()),
      (route) => false,
    );
  }
}
