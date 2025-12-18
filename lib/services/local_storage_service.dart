import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class LocalStorageService {
  LocalStorageService._();
  static final LocalStorageService _instance = LocalStorageService._();
  static LocalStorageService get instance => _instance;

  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // Generic methods for storing and retrieving data
  static Future<bool> setString(String key, String value) async {
    return await _prefs?.setString(key, value) ?? false;
  }

  static String? getString(String key) {
    return _prefs?.getString(key);
  }

  static Future<bool> setInt(String key, int value) async {
    return await _prefs?.setInt(key, value) ?? false;
  }

  static int? getInt(String key) {
    return _prefs?.getInt(key);
  }

  static Future<bool> setBool(String key, bool value) async {
    return await _prefs?.setBool(key, value) ?? false;
  }

  static bool? getBool(String key) {
    return _prefs?.getBool(key);
  }

  static Future<bool> setDouble(String key, double value) async {
    return await _prefs?.setDouble(key, value) ?? false;
  }

  static double? getDouble(String key) {
    return _prefs?.getDouble(key);
  }

  static Future<bool> setStringList(String key, List<String> value) async {
    return await _prefs?.setStringList(key, value) ?? false;
  }

  static List<String>? getStringList(String key) {
    return _prefs?.getStringList(key);
  }

  // JSON methods for complex objects
  static Future<bool> setJson(String key, Map<String, dynamic> value) async {
    return await _prefs?.setString(key, jsonEncode(value)) ?? false;
  }

  static Map<String, dynamic>? getJson(String key) {
    final String? jsonString = _prefs?.getString(key);
    if (jsonString != null) {
      try {
        return Map<String, dynamic>.from(jsonDecode(jsonString));
      } catch (e) {

        return null;
      }
    }
    return null;
  }

  // List of JSON objects
  static Future<bool> setJsonList(String key, List<Map<String, dynamic>> value) async {
    return await _prefs?.setString(key, jsonEncode(value)) ?? false;
  }

  static List<Map<String, dynamic>>? getJsonList(String key) {
    final String? jsonString = _prefs?.getString(key);
    if (jsonString != null) {
      try {
        final List<dynamic> decoded = jsonDecode(jsonString);
        return decoded.map((item) => Map<String, dynamic>.from(item)).toList();
      } catch (e) {

        return null;
      }
    }
    return null;
  }

  // Remove specific key
  static Future<bool> remove(String key) async {
    return await _prefs?.remove(key) ?? false;
  }

  // Clear all data
  static Future<bool> clear() async {
    return await _prefs?.clear() ?? false;
  }

  // Check if key exists
  static bool containsKey(String key) {
    return _prefs?.containsKey(key) ?? false;
  }

  // Get all keys
  static Set<String> getKeys() {
    return _prefs?.getKeys() ?? <String>{};
  }
}
