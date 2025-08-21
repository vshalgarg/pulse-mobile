import 'package:app/routes/routes.dart';
import 'package:app/screens/asset_audit_screen.dart';
import 'package:app/screens/corrective_maintenance_screen.dart';
import 'package:app/screens/energy_reading_screen.dart';
import 'package:app/screens/forgot_password_screen.dart';
import 'package:app/screens/home_screen.dart';
import 'package:app/screens/password_updated_Screen.dart';
import 'package:app/screens/preventive_maintainance_screen.dart';
import 'package:app/screens/reset_password_screen.dart';
import 'package:app/screens/splash_screen.dart';
import 'package:app/screens/ticket_screen.dart';
import 'package:flutter/material.dart';

import '../screens/login_screen.dart';
import '../screens/otp_verfication_screen.dart';
import '../screens/welcome_screen.dart';

// class RouteGenerator {
Route<dynamic> generateRoute(RouteSettings settings) {
  // handle deep link here
  if (settings.name!.contains("/goodMorning")) {
    // return MaterialPageRoute(builder: (context) => const DeepLinkExample());
  }

  // according to route name goto screen
  switch (settings.name) {
    case "/":
      return _push(const SplashScreen());
    case loginScreen:
      return _push(const LoginScreen());
    case welcomeScreen:
      return _push(const WelcomeScreen());
    case homeScreen:
      return _push(const HomeScreen());
    case forgotPasswordScreen:
      return _push(const ForgotPasswordScreen());
    case resetPasswordScreen:
      return _push(const ResetPasswordScreen());
    case passwordUpdateScreen:
      return _push(const PasswordUpdatedScreen());
    case otpVerificationScreen:
      return _push(const EnterVerificationCodeScreen());
    case assetAuditScreen:
      return _push(const AssetAuditScreen());
    case correctiveMaintenanceScreen:
      return _push(const CorrectiveMaintenanceScreen());
    case preventiveMaintenanceScreen:
      return _push(const PreventiveMaintenanceScreen());
    case energyReadingScreen:
      return _push(const EnergyReadingScreen());
    case ticketScreen:
      return _push(const TicketScreen(auditName: "", status: ""));

    default:
      return MaterialPageRoute(
        builder: (context) {
          return Scaffold(
            appBar: AppBar(
              title: const Text("ERROR"),
            ),
            body: const Center(
              child: Text("Page not found!"),
            ),
          );
        },
      );
  }
  // return MaterialPageRoute(builder: (context) => const LoginScreen());
}

PageRoute _push(
  Widget widget, {
  RouteSettings? settings,
  bool fullScreenDialog = false,
}) =>
    MaterialPageRoute(
      builder: (context) => widget,
      fullscreenDialog: fullScreenDialog,
    );
// }
