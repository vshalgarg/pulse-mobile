import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class OfflineLocationService {
  static const String _lastKnownLocationKey = 'last_known_location';
  static const String _locationHistoryKey = 'location_history';
  static const int _maxHistorySize = 10;

  /// Get current location with fallback to cache/history
  static Future<Map<String, String>?> getCurrentLocationOffline({
    Duration timeout = const Duration(seconds: 15),
  }) async {
    
    try {
      // Try fresh GPS
      final freshLocation = await _getFreshLocation(timeout: timeout);
      
      if (freshLocation != null) {
        await _cacheLocation(freshLocation);
       
        return freshLocation;
      }

      // Fallback: last known cached location
      final lastKnownLocation = await _getLastKnownLocation();
     
      if (lastKnownLocation != null) {
       
        return lastKnownLocation;
      }

      // Fallback: location history (oldest available)
      final history = await getLocationHistory();
      
      if (history.isNotEmpty) {
       
        return history.first;
      }

      // Nothing available - return null instead of static coordinates
     
      return null;
    } catch (_) {
      return await _getLastKnownLocation();
    }
  }

  /// Get fresh location from GPS
  static Future<Map<String, String>?> _getFreshLocation({
    Duration timeout = const Duration(seconds: 15),
  }) async {
    print('🌍 OfflineLocationService._getFreshLocation() - Starting...');
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      print('🌍 OfflineLocationService._getFreshLocation() - Permission: $permission');

      if (permission == LocationPermission.denied) {
        print('🌍 OfflineLocationService._getFreshLocation() - Requesting permission...');
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print('🌍 OfflineLocationService._getFreshLocation() - Permission denied');
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        print('🌍 OfflineLocationService._getFreshLocation() - Permission denied forever');
        return null;
      }

      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      print('🌍 OfflineLocationService._getFreshLocation() - Service enabled: $serviceEnabled');
      if (!serviceEnabled) {
        print('🌍 OfflineLocationService._getFreshLocation() - Location service disabled');
        return null;
      }

      print('🌍 OfflineLocationService._getFreshLocation() - Getting GPS position...');
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: timeout,
      );

      print('🌍 OfflineLocationService._getFreshLocation() - GPS position: ${position.latitude}, ${position.longitude}');
      final result = {
        'latitude': position.latitude.toString(),
        'longitude': position.longitude.toString(),
      };
      print('🌍 OfflineLocationService._getFreshLocation() - Returning: $result');
      return result;
    } catch (e) {
      print('🌍 OfflineLocationService._getFreshLocation() - Error: $e');
      return null;
    }
  }

  /// Get last known cached location
  static Future<Map<String, String>?> _getLastKnownLocation() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final locationJson = prefs.getString(_lastKnownLocationKey);

      if (locationJson != null) {
        return Map<String, String>.from(json.decode(locationJson));
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Cache location for offline use
  static Future<void> _cacheLocation(Map<String, String> location) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastKnownLocationKey, json.encode(location));
      await _addToLocationHistory(location);
    } catch (_) {}
  }

  /// Add location to history
  static Future<void> _addToLocationHistory(Map<String, String> location) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getString(_locationHistoryKey);

      List<Map<String, String>> history = [];
      if (historyJson != null) {
        history = (json.decode(historyJson) as List)
            .map((item) => Map<String, String>.from(item))
            .toList();
      }

      history.insert(0, location);
      if (history.length > _maxHistorySize) {
        history = history.take(_maxHistorySize).toList();
      }

      await prefs.setString(_locationHistoryKey, json.encode(history));
    } catch (_) {}
  }

  /// Get location history
  static Future<List<Map<String, String>>> getLocationHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getString(_locationHistoryKey);

      if (historyJson != null) {
        return (json.decode(historyJson) as List)
            .map((item) => Map<String, String>.from(item))
            .toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Clear location cache
  static Future<void> clearLocationCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lastKnownLocationKey);
    await prefs.remove(_locationHistoryKey);
  }

  /// Retry mechanism
  static Future<Map<String, String>?> getLocationWithRetry({
    int maxRetries = 3,
    Duration delay = const Duration(seconds: 2),
  }) async {
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      final location = await getCurrentLocationOffline();
      if (location != null) return location;

      if (attempt < maxRetries) {
        await Future.delayed(delay);
      }
    }
    return null;
  }

  /// Check availability
  static Future<bool> isLocationServiceAvailable() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return false;
      }
      return await Geolocator.isLocationServiceEnabled();
    } catch (_) {
      return false;
    }
  }
}
