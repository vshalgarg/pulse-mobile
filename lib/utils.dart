import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher_string.dart';

import 'constants/app_colors.dart';
import 'constants/constants_methods.dart';
import 'models/device_info/device_info.dart';

import 'services/local_storage_db.dart';

class Utils {
  static String toDateTime(DateTime dateTime) {
    final date = DateFormat.yMMMEd().format(dateTime);
    final time = DateFormat.Hm().format(dateTime);
    return '$date $time';
  }

  static String toCustomDateFormat(DateTime dateTime, String dateFormat) {
    final date = DateFormat(dateFormat).format(dateTime);
    return date;
  }

  static String toDate(DateTime dateTime) {
    final date = DateFormat.yMMMEd().format(dateTime);
    return date;
  }

  static String toTime(DateTime dateTime) {
    final time = DateFormat.Hm().format(dateTime);
    return time;
  }

  static String toDateDDMMYYYY(DateTime dateTime) {
    final date = DateFormat.yMd().format(dateTime); //etc. DateFormat('dd-MM-yyyy').format(dateTime);
    return date;
  }

  /// Convert current date time to ISO 8601 format with timezone offset
  /// Returns format: 2025-09-12T15:25:00.000+00:00
  static String getCurrentDateTimeISO8601() {
    final now = DateTime.now();
    return now.toUtc().toIso8601String();
  }

  static String? getCurrentDateTimeFromMsISO8601(int? milliseconds) {
    if(milliseconds == null) return null;
    final now = DateTime.fromMillisecondsSinceEpoch(milliseconds);
    return now.toUtc().toIso8601String();
  }

  static String toDateYYYYMMDD(DateTime dateTime) {
    final dateFormatter = DateFormat("yyyy-MM-dd");
    final date = dateFormatter.format(dateTime); //etc. DateFormat('yyyy-MM-dd').format(dateTime);
    return date;
  }

  // get device information
  static Future<DeviceInfoModel?> getDeviceInfo() async {
    DeviceInfoModel deviceInfoModel = DeviceInfoModel();
    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
      // kDebugPrint('Running on $androidInfo'); // e.g. "Moto G (4)"
      kDebugPrint('Running on ${androidInfo.model}'); // e.g. "Moto G (4)"
      kDebugPrint('Device id ${androidInfo.id}');
      deviceInfoModel.deviceId = androidInfo.id;
      deviceInfoModel.deviceName = androidInfo.model;
      return deviceInfoModel;
    }
    if (Platform.isIOS) {
      IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
      // kDebugPrint('Running on $iosInfo');
      kDebugPrint('Running on ${iosInfo.utsname.machine}'); // e.g. "iPod7,1"
      kDebugPrint('UUID value ${iosInfo.identifierForVendor}');
      kDebugPrint(iosInfo.identifierForVendor);
      deviceInfoModel.deviceId = iosInfo.identifierForVendor;
      deviceInfoModel.deviceName = iosInfo.utsname.machine;
      return deviceInfoModel;
    }

    return null;
  }

  static Future<DateTime?> pickDateTime(DateTime initialDate, BuildContext context,
      {required bool pickDate, DateTime? firstDate, DateTime? lastDate}) async {
    if (pickDate) {
      final date = await showDatePicker(
          context: context,
          initialDate: initialDate,
          firstDate: firstDate ?? DateTime.now(),
          lastDate: lastDate ?? DateTime(2100),
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: ColorScheme.light(
                  // header background color
                  onPrimary: Colors.white,
                  primary: Theme.of(context).primaryColor, // header background color
                  onSurface: AppColors.blackColor, // header text color// body text color
                ),
              ),
              child: child!,
            );
          });

      if (date == null) return null;
      final time = Duration(hours: initialDate.hour, minutes: initialDate.minute, seconds: initialDate.second);
      return date.add(time);
    } else {
      final timeofDay = await showTimePicker(
          context: context,
          initialTime: TimeOfDay.fromDateTime(initialDate),
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: ColorScheme.light(
                  onPrimary: Colors.white, // header background color
                  primary: Theme.of(context).primaryColor, // header background color
                  onSurface: AppColors.blackColor, // header text color// body text color
                ),
              ),
              child: child!,
            );
          });

      if (timeofDay == null) return null;
      final date = DateTime(initialDate.year, initialDate.month, initialDate.day);
      final time = Duration(hours: timeofDay.hour, minutes: timeofDay.minute);
      return date.add(time);
    }
  }

  // pick image from Camera or Gallery- ImageSource.camera or ImageSource.gallery
  static Future<File?> pickImage(ImageSource source) async {
    try {
      final image = await ImagePicker().pickImage(source: source, imageQuality: 80);

      if (image == null) return null;

      final tempImage = File(image.path);
      return tempImage;
    } on PlatformException catch (e) {
      debugPrint(e.message);
      return null;
    }
  }

  // select single file from device
  static Future<File?> pickSingleFile({FileType fileType = FileType.any, List<String>? extensions}) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: fileType,
      allowedExtensions: extensions,
    );

    if (result != null) {
      File file = File(result.files.single.path!);
      return file;
    }
    // User canceled the picker
    return null;
  }

  // select multiple files from device
  static Future<List<File>?> pickMultipleFile({FileType fileType = FileType.any}) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: fileType,
      allowMultiple: true,
      // allowedExtensions: ['jpg', 'pdf', 'doc'],
    );

    if (result != null) {
      List<File> files = result.paths.map((path) => File(path!)).toList();
      return files;
    }
    // User canceled the picker
    return null;
  }

  static String maskEmail(String input, [int minFill = 4, String fillChar = '*']) {
    final emailMaskRegExp = RegExp('^(.)(.*?)([^@]?)(?=@[^@]+\$)');
    return input.replaceFirstMapped(emailMaskRegExp, (m) {
      var start = m.group(1);
      var middle = fillChar * max(minFill, m.group(2)!.length);
      var end = m.groupCount >= 3 ? m.group(3) : start;
      return 'email: ${start!}$middle${end!}';
    });
  }

  // get device information
  // static Future<DeviceInfoModel?> getDeviceInfo() async {
  //   DeviceInfoModel deviceInfoModel = DeviceInfoModel();
  //   DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
  //   if (Platform.isAndroid) {
  //     AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
  //     // kDebugPrint('Running on $androidInfo'); // e.g. "Moto G (4)"
  //     kDebugPrint('Running on ${androidInfo.model}'); // e.g. "Moto G (4)"
  //     kDebugPrint('Device id ${androidInfo.id}');
  //     deviceInfoModel.deviceId = androidInfo.id;
  //     deviceInfoModel.deviceName = androidInfo.model;
  //     return deviceInfoModel;
  //   }
  //   if (Platform.isIOS) {
  //     IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
  //     // kDebugPrint('Running on $iosInfo');
  //     kDebugPrint('Running on ${iosInfo.utsname.machine}'); // e.g. "iPod7,1"
  //     kDebugPrint('UUID value ${iosInfo.identifierForVendor}');
  //     kDebugPrint(iosInfo.identifierForVendor);
  //     deviceInfoModel.deviceId = iosInfo.identifierForVendor;
  //     deviceInfoModel.deviceName = iosInfo.utsname.machine;
  //     return deviceInfoModel;
  //   }
  //
  //   return null;
  // }

// Email Call Function
  static Future<void> makeEmailCall(BuildContext context, String email) async {
    final Uri params = Uri(
      scheme: 'mailto',
      path: email,
    );
    String url = params.toString();
    if (await canLaunchUrlString(url)) {
      await launchUrlString(url);
      Navigator.pop(context);
    } else {
      throw 'Could not launch $url';
    }
  }

  // Phone dialer Call Function
  // static Future<void> makePhoneCall(BuildContext context, String contactNumber) async {
  //   Uri url = Uri(scheme: "tel", path: contactNumber);
  //   kDebugPrint("PhoneNumber $contactNumber");
  //   if (await canLaunchUrl(url)) {
  //     await launchUrl(url);
  //     Navigator.pop(context);
  //   } else {
  //     throw 'Could not launch $url';
  //   }
  // }

  static Future<void> launchUrlInDevice(String url) async {
    if (!await launchUrlString(url)) {
      // throw 'Could not launch $_url';
    }
  }

  // detect language by text string
  static bool detectLanguage({required String string}) {
    // String? languageCodes;

    // final RegExp persian = RegExp(r'^[\u0600-\u06FF]+');
    final RegExp english = RegExp(r'^[a-zA-Z]+');
    // final RegExp arabic = RegExp(r'^[\u0621-\u064A]+');
    // final RegExp chinese = RegExp(r'^[\u4E00-\u9FFF]+');
    // final RegExp japanese = RegExp(r'^[\u3040-\u30FF]+');
    // final RegExp korean = RegExp(r'^[\uAC00-\uD7AF]+');
    // final RegExp ukrainian = RegExp(r'^[\u0400-\u04FF\u0500-\u052F]+');
    // final RegExp russian = RegExp(r'^[\u0400-\u04FF]+');
    // final RegExp italian = RegExp(r'^[\u00C0-\u017F]+');
    // final RegExp french = RegExp(r'^[\u00C0-\u017F]+');
    // final RegExp spanish = RegExp(r'[\u00C0-\u024F\u1E00-\u1EFF\u2C60-\u2C7F\uA720-\uA7FF\u1D00-\u1D7F]+');

    // if (persian.hasMatch(string)) languageCodes = 'fa';
    if (english.hasMatch(string)) return true; //languageCodes = 'en';
    // if (arabic.hasMatch(string)) languageCodes = 'ar';
    // if (chinese.hasMatch(string)) languageCodes = 'zh';
    // if (japanese.hasMatch(string)) languageCodes = 'ja';
    // if (korean.hasMatch(string)) languageCodes = 'ko';
    // if (russian.hasMatch(string)) languageCodes = 'ru';
    // if (ukrainian.hasMatch(string)) languageCodes = 'uk';
    // if (italian.hasMatch(string)) languageCodes = 'it';
    // if (french.hasMatch(string)) languageCodes = 'fr';
    // if (spanish.hasMatch(string)) languageCodes = 'es';

    return false;
  }

  static Future<String?> networkImageToBase64(String imageUrl) async {
    try {
      http.Response response = await http.get(Uri.parse(imageUrl));
      final bytes = response.bodyBytes;
      return (bytes != null ? base64Encode(bytes) : null);
    } on Exception catch (e) {
      return null;
    }
  }

  static String getBase64ImageWithoutDataPrefix(String data) => data.split(',').last;

  static DateTime get getCurrentTime => DateTime.now();

  static dynamic getTimeWithTandZ(DateTime time, {bool asString = true}) {
    final date = time.toString().split(" ");
    final changeDateFormat = '${date[0]}T${date[1]}Z';
    if (asString) {
      return changeDateFormat;
    } else {
      return DateTime.parse(changeDateFormat);
    }
  }

  // Check if JWT token is expired
  static bool isTokenExpired(String? token) {
    if (token == null || token.isEmpty) return true;
    
    try {
      final parts = token.split('.');
      if (parts.length != 3) return true;
      
      final payload = parts[1];
      final normalized = base64Url.normalize(payload);
      final resp = utf8.decode(base64Url.decode(normalized));
      final payloadMap = json.decode(resp);
      
      final exp = payloadMap['exp'];
      if (exp == null) return true;
      
      final expiry = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
      final now = DateTime.now();
      
      return now.isAfter(expiry);
    } catch (e) {
      print('Error checking token expiration: $e');
      return true;
    }
  }

  // Check if current stored token is expired
  static bool isCurrentTokenExpired() {
    final token = LocalStorageDB.getToken;
    return isTokenExpired(token);
  }

  // Get token expiration time
  static DateTime? getTokenExpiration(String? token) {
    if (token == null || token.isEmpty) return null;
    
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      
      final payload = parts[1];
      final normalized = base64Url.normalize(payload);
      final resp = utf8.decode(base64Url.decode(normalized));
      final payloadMap = json.decode(resp);
      
      final exp = payloadMap['exp'];
      if (exp == null) return null;
      
      return DateTime.fromMillisecondsSinceEpoch(exp * 1000);
    } catch (e) {
      print('Error getting token expiration: $e');
      return null;
    }
  }
}
