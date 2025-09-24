import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'constants_strings.dart';
import 'image_strings.dart';
import 'package:fluttertoast/fluttertoast.dart';

import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../commonWidgets/custom_text_widget.dart';
import '../provider/theme_provider.dart';
import 'app_colors.dart';

const kDivider = Divider(color: Colors.grey);
const kAssetPath = "images/";
const assetSvgPathIcons = "assets/images/svg_image/liquor_icons/";
const assetImagePathIcons = "assets/images/";
const assetLottieAnimation = "assets/lottie/";
//const emailPattern = r'(^[a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\.[a-zA-Z0-9-.]+$)';
const emailPattern =
    r'^(([^<>()[\]\\.,;:\s@\"]+(\.[^<>()[\]\\.,;:\s@\"]+)*)|(\".+\"))@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\])|(([a-zA-Z\-0-9]+\.)+[a-zA-Z]{2,3}))$';

const passwordPattern =
    r'^(?=.*?[A-Z])(?=.*?[a-z])(?=.*?[0-9])(?=.*?[!@#$%×[;/^&*()=+,.?":{}|<>_~`-]).{8,}$';
const passwordSecondPattern =
    r'^(?=.*[A-Z])(?=.*[!@#$%^&*()_+])[A-Za-z\d!@#$%^&*()_+]{6,}$';
final kNumericExp = RegExp('(?=.*?[0-9])');
final kSpecialCharReg = RegExp(r'[!@#$%×;/^&*()=+,.?":{}|<>_~`-]');
final kLowerExp = RegExp('(?=.*?[a-z])');
final kUpperExp = RegExp('(?=.*?[A-Z])');

const whiteColor = Colors.white;
const redColor = Colors.red;
const transparentColor = Colors.transparent;

const double kFontSize10 = 10;
const double kFontSize12 = 12;
const double kFontSize14 = 14;
const double kFontSize16 = 16;
const double kFontSize18 = 18;
const double kFontSize20 = 20;
const double kFontSize22 = 22;
const double kFontSize24 = 24;
const double kFontSize26 = 26;
const double kFontSize30 = 30;
const double kFontSize40 = 40;

Widget getHeight(double height) => SizedBox(height: height);

Widget getWidth(double width) => SizedBox(width: width);

getDeviceHeight(BuildContext context) => MediaQuery.of(context).size.height;

getDeviceWidth(BuildContext context) => MediaQuery.of(context).size.width;

kTextStyle({
  Color color = Colors.black,
  double fontSize = kFontSize14,
  FontStyle fontStyle = FontStyle.normal,
  FontWeight fontWeight = FontWeight.normal,
  String fontFamily = fontFamilyLato,
  TextDecoration decoration = TextDecoration.none,
  BuildContext? context,
}) {
  return TextStyle(
    color: color,
    fontSize: fontSize,
    fontStyle: fontStyle,
    fontWeight: fontWeight,
    decoration: decoration,
    fontFamily: fontFamily,
  );
}

kRoundedShape([double radius = 10]) =>
    RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius));

const kCircularProgressIndicator = Center(child: CircularProgressIndicator());

void showCustomToast(BuildContext context, String message) {
  FToast().init(context);
  FToast().showToast(
    child: callToast(message),
    gravity: ToastGravity.CENTER,
    toastDuration: const Duration(seconds: 2),
  );
}

Widget callToast(String message) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(25.0),
      color: AppColors.primaryGreen,
    ),
    child: CustomTextWidget(message, color: Colors.white),
  );
}

const getPlaceholder = AssetImage(ImageStrings.placeholder);

/// page push
// page push
Future pushPage(BuildContext context, Widget widgetName) {
  return Navigator.push(
    context,
    MaterialPageRoute(builder: (context) => widgetName),
  );
}

Future pushNamedPage(
  BuildContext context,
  String routeName, {
  Object? arguments,
}) {
  return Navigator.pushNamed(context, routeName, arguments: arguments);
}

Future pushNamedAndRemoveUntil(
  BuildContext context,
  String newRouteName, {
  Object? arguments,
}) {
  return Navigator.pushNamedAndRemoveUntil(
    context,
    newRouteName,
    arguments: arguments,
    (route) => false,
  );
}

Future pushReplacementNamedPage(BuildContext context, String routeName) {
  return Navigator.pushReplacementNamed(context, routeName);
}

Future pushReplacementPage(BuildContext context, Widget widgetName) {
  return Navigator.pushReplacement(
    context,
    MaterialPageRoute(builder: (context) => widgetName),
  );
}

Future pushAndRemoveUntilPage(BuildContext context, Widget widgetName) {
  return Navigator.pushAndRemoveUntil(
    context,
    MaterialPageRoute(builder: (context) => widgetName),
    (route) => false,
  );
}

// check dark theme is on/off
bool isDarkModeOn(BuildContext context) {
  // for change color according to theme
  return Provider.of<ThemeProvider>(context, listen: false).isDarkMode;
}

// showProgressDialog(BuildContext context) => LoadingProgress.start(context);
//
// hideProgressDialog(BuildContext context) => LoadingProgress.stop(context);

// get device information
Future<void> getDeviceInfo() async {
  DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
  if (Platform.isAndroid) {
    AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
    print('Running on ${androidInfo.model}'); // e.g. "Moto G (4)"
    print(androidInfo.id);
  }
  if (Platform.isIOS) {
    IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
    print('Running on ${iosInfo.utsname.machine}'); // e.g. "iPod7,1"
    print(iosInfo.identifierForVendor);
  }
}

Future<void> launchUrl(String url) async {
  if (!await launchUrlString(url)) {
    // throw 'Could not launch $_url';
  }
}

void showSnackBar(
  BuildContext context,
  String msg, {
  Color backgroundColor = AppColors.themeColorMustard,
}) {
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: CustomTextWidget(msg, color: AppColors.whiteColor),
      backgroundColor: backgroundColor,
      // margin: const EdgeInsets.only(bottom: 100),
      // behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 1),
    ),
  );
}

splashGradientDecoration({
  BorderRadiusGeometry? borderRadius,
  BuildContext? context,
}) {
  return BoxDecoration(
    gradient: LinearGradient(
      colors: [
        Theme.of(context!).primaryColor.withOpacity(0.5),
        Theme.of(context).primaryColor,
      ],
      begin: Alignment.bottomLeft,
      end: Alignment.topRight,
    ),
    borderRadius: borderRadius,
  );
}

void kDebugPrint(dynamic data) => debugPrint(data.toString());
