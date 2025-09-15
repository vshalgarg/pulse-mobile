import 'package:app/enum/pm_ticket_type_enum.dart';
import 'package:app/routes/routes.dart';
import 'package:app/screens/asset_audit/asset_audit_telecom/battery_screen.dart';
import 'package:app/screens/asset_audit/asset_audit_telecom/ccu_screen.dart';
import 'package:app/screens/asset_audit/asset_audit_telecom/extinguisher_screen.dart';
import 'package:app/screens/asset_audit/asset_audit_telecom/site_info_screen.dart';
import 'package:app/screens/asset_audit_screen.dart';
import 'package:app/screens/energy_reading/energy_reading_screen.dart';
import 'package:app/screens/forgot_password_screen.dart';
import 'package:app/screens/home_screen.dart';
import 'package:app/screens/password_updated_Screen.dart';
import 'package:app/screens/preventive_maintainance/pm_pages/pm_page_1.dart';
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
    // case correctiveMaintenanceScreen:
    //   return _push(const CorrectiveMaintenanceScreen());
    case pmScreen1:
      final args = settings.arguments as Map<String, dynamic>?;
      return _push(PmScreen1(
        ticketType: PmTicketTypeEnum.fromString(args?['siteType']),
        auditSchId: args?['auditSchId'] ?? '',
        siteAuditSchId: args?['siteAuditSchId'] ?? '',
        siteId: args?['siteId'],
      ));
    case energyReadingScreen:
      return _push(const EnergyReadingScreen(
        siteType: "",
        auditSchId: "",
        siteAuditSchId: "",
        siteId: "",
      ));
    case siteInfoScreen:
      return _push(const SiteInfoScreen(
        siteName: "",
        siteTypeName: "",
        indoorOutdoor: "",
        ebNonEb: "",
        op1Name: "",
        op2Name: "",
        siteType: "",
        auditSchId: "",
        siteAuditSchId: "",
      ));
    case ccuScreen:
      return _push(const CCUScreen(
        siteType: "",
        auditSchId: "",
        siteAuditSchId: "",
      ));
    case batteryScreen:
      return _push(const BatteryScreen(
        siteType: "",
        auditSchId: "",
        siteAuditSchId: "",
      ));
    case extinguisherScreen:
      final args = settings.arguments as Map<String, dynamic>?;
      return _push(ExtinguisherScreen(
        extinguisherData: args?['extinguisherData'],
        assetAuditData: args?['assetAuditData'],
        showSuccessMessage: args?['showSuccessMessage'] ?? false,
        siteType: args?['siteType'] ?? "",
        auditSchId: args?['auditSchId'] ?? "",
        siteAuditSchId: args?['siteAuditSchId'] ?? "",
      ));
    case solarPlateScreen:
      // SolarPlatesScreen should only be accessed through asset audit flow with proper data
      // This route is kept for backward compatibility but will show an error
      return _push(
        Scaffold(
          appBar: AppBar(title: const Text("Error")),
          body: const Center(
            child: Text(
              "Solar Plates screen should be accessed through the asset audit flow with proper data.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
          ),
        ),
      );
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
