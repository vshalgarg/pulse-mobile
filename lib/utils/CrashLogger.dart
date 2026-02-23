import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

class CrashLogger {
  static final CrashLogger _instance = CrashLogger._internal();
  factory CrashLogger() => _instance;
  CrashLogger._internal();

  Future<void> logCrash(dynamic error, StackTrace? stack) async {
    final deviceInfo = await _getDeviceInfo();
    final appInfo = await _getAppInfo();

    final crashData = {
      "time": DateTime.now().toIso8601String(),
      "error": error.toString(),
      "stack": stack.toString(),
      "device": deviceInfo,
      "app": appInfo,
    };

    await _saveToFile(crashData);
  }

  Future<Map<String, dynamic>> _getDeviceInfo() async {
    try {
      final plugin = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final info = await plugin.androidInfo;
        return {
          "platform": "Android",
          "model": info.model,
          "brand": info.brand,
          "device": info.device,
          "version": info.version.release,
        };
      }
      if (Platform.isIOS) {
        final info = await plugin.iosInfo;
        return {
          "platform": "iOS",
          "model": info.model,
          "name": info.name,
          "systemVersion": info.systemVersion,
        };
      }
    } catch (e) {
      return {"error": e.toString()};
    }
    return {"platform": "unknown"};
  }

  Future<Map<String, dynamic>> _getAppInfo() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return {
        "appName": info.appName,
        "version": info.version,
        "buildNumber": info.buildNumber,
        "packageName": info.packageName,
      };
    } catch (e) {
      return {"error": e.toString()};
    }
  }

  Future<void> _saveToFile(Map<String, dynamic> crashData) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final crashDir = Directory('${dir.path}/crashes');
      if (!await crashDir.exists()) {
        await crashDir.create(recursive: true);
      }
      final name = DateTime.now().toIso8601String().replaceAll(RegExp(r'[:\-.]'), '_');
      final file = File('${crashDir.path}/crash_$name.json');
      await file.writeAsString(const JsonEncoder.withIndent('  ').convert(crashData));
    } catch (_) {}
  }
}
