import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';

class DeviceMemoryHelper {
  static Future<bool> isLowRamDevice() async {
    try {
      if (!Platform.isAndroid) return false;

      final info = await DeviceInfoPlugin().androidInfo;

      // totalRam available on most devices (in bytes)
      final totalRam = info.systemFeatures.contains('android.hardware.ram.low');

      return totalRam;
    } catch (_) {
      return false;
    }
  }

  static Future<Map<String, dynamic>> getDeviceSnapshot() async {
    try {
      final info = await DeviceInfoPlugin().androidInfo;
      return {
        "model": info.model,
        "brand": info.brand,
        "android": info.version.release,
        "sdk": info.version.sdkInt,
        "hardware": info.hardware,
        "board": info.board,
        "manufacturer": info.manufacturer,
      };
    } catch (_) {
      return {};
    }
  }
}