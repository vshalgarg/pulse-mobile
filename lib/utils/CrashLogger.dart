import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

class CrashLogger {
  static final CrashLogger _instance = CrashLogger._internal();
  factory CrashLogger() => _instance;
  CrashLogger._internal();
  String _currentScreen = 'unknown';

  Future<void> setCurrentScreen(String? screenName) async {
    final resolved = (screenName == null || screenName.trim().isEmpty)
        ? 'unknown'
        : screenName.trim();
    _currentScreen = resolved;
    try {
      if (Firebase.apps.isNotEmpty) {
        await FirebaseCrashlytics.instance.setCustomKey('screen', resolved);
      }
    } catch (_) {}
  }

  Future<void> logCrash(
    dynamic error,
    StackTrace? stack, {
    String? reason,
    Map<String, dynamic>? context,
    bool fatal = false,
  }) async {
    final resolvedStack = stack ?? StackTrace.current;
    final deviceInfo = await _getDeviceInfo();
    final appInfo = await _getAppInfo();

    final crashData = {
      "time": DateTime.now().toIso8601String(),
      "error": error.toString(),
      "stack": resolvedStack.toString(),
      "reason": reason,
      "context": context,
      "fatal": fatal,
      "device": deviceInfo,
      "app": appInfo,
    };

    await _saveToFile(crashData);
    await _sendToCrashlytics(
      error: error,
      stack: resolvedStack,
      reason: reason,
      context: context,
      fatal: fatal,
    );
  }

  Future<void> _sendToCrashlytics({
    required dynamic error,
    required StackTrace stack,
    String? reason,
    Map<String, dynamic>? context,
    required bool fatal,
  }) async {
    try {
      if (Firebase.apps.isEmpty) return;
      await _setCrashlyticsKeys(
        reason: reason,
        context: context,
      );

      final contextLines = <String>[];
      if (context != null) {
        context.forEach((key, value) {
          contextLines.add('$key=$value');
        });
      }

      await FirebaseCrashlytics.instance.recordError(
        error,
        stack,
        reason: reason,
        information: contextLines,
        fatal: fatal,
      );
    } catch (_) {}
  }

  Future<void> _setCrashlyticsKeys({
    String? reason,
    Map<String, dynamic>? context,
  }) async {
    try {
      final deviceInfo = await _getDeviceInfo();
      final appInfo = await _getAppInfo();

      if (reason != null && reason.isNotEmpty) {
        await FirebaseCrashlytics.instance.setCustomKey('reason', reason);
      }

      await FirebaseCrashlytics.instance.setCustomKey(
        'platform',
        (deviceInfo['platform'] ?? 'unknown').toString(),
      );
      await FirebaseCrashlytics.instance.setCustomKey(
        'device_model',
        (deviceInfo['model'] ?? 'unknown').toString(),
      );
      await FirebaseCrashlytics.instance.setCustomKey(
        'app_version',
        (appInfo['version'] ?? 'unknown').toString(),
      );
      await FirebaseCrashlytics.instance.setCustomKey(
        'app_build',
        (appInfo['buildNumber'] ?? 'unknown').toString(),
      );
      await FirebaseCrashlytics.instance.setCustomKey('screen', _currentScreen);

      if (context != null) {
        for (final entry in context.entries) {
          final key = _sanitizeKey(entry.key);
          if (key.isEmpty) continue;
          await FirebaseCrashlytics.instance.setCustomKey(
            key,
            entry.value?.toString() ?? 'null',
          );
        }
      }
    } catch (_) {}
  }

  String _sanitizeKey(String raw) {
    final key = raw
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9_]'), '_')
        .replaceAll(RegExp(r'_+'), '_');
    if (key.isEmpty) return '';
    return key.length > 40 ? key.substring(0, 40) : key;
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
