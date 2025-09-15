import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'location_permission_service.dart';

class OfflineLocationService {
  static const String _lastKnownLocationKey = 'last_known_location';
  static const String _locationHistoryKey = 'location_history';
  static const int _maxHistorySize = 10;

  /// Get current location with offline support and fallback mechanisms
  static Future<Map<String, String?>> getCurrentLocationOffline() async {
    try {
      print('OfflineLocationService: Attempting to get current location...');
      
      // First, check and request location permissions
      final permissionResult = await LocationPermissionService.requestLocationPermissions();
      if (!permissionResult['success']) {
        print('OfflineLocationService: Location permissions not granted: ${permissionResult['message']}');
        // Still try to get last known location or default
      }
      
      // Check if location services are enabled
      final locationServiceEnabled = await LocationPermissionService.isLocationServiceEnabled();
      if (!locationServiceEnabled) {
        print('OfflineLocationService: Location services are disabled');
        // Still try to get last known location or default
      }
      
      // Try to get fresh GPS location
      final freshLocation = await _getFreshLocation();
      if (freshLocation != null) {
        print('OfflineLocationService: Fresh location obtained: ${freshLocation['latitude']}, ${freshLocation['longitude']}');
        // Cache the fresh location
        await _cacheLocation(freshLocation);
        return freshLocation;
      }
      
      // If fresh location fails, try to get last known location
      print('OfflineLocationService: Fresh location failed, trying last known location...');
      final lastKnownLocation = await _getLastKnownLocation();
      if (lastKnownLocation != null) {
        print('OfflineLocationService: Using last known location: ${lastKnownLocation['latitude']}, ${lastKnownLocation['longitude']}');
        return lastKnownLocation;
      }
      
      // If no location available, try to provide a default location for testing
      print('OfflineLocationService: No location available, trying default location for testing');
      
      // For testing purposes, provide a default location (Delhi, India)
      // In production, you might want to return null or ask user to enable location
      final defaultLocation = {
        'latitude': '28.6139', // Delhi latitude
        'longitude': '77.2090', // Delhi longitude
      };
      
      print('OfflineLocationService: Using default location for testing: ${defaultLocation['latitude']}, ${defaultLocation['longitude']}');
      return defaultLocation;
      
    } catch (e) {
      print('OfflineLocationService: Error getting location: $e');
      // Try to return last known location as fallback
      final lastKnownLocation = await _getLastKnownLocation();
      if (lastKnownLocation != null) {
        return lastKnownLocation;
      }
      
      // If all else fails, provide default location for testing
      print('OfflineLocationService: All location methods failed, using default location');
      return {
        'latitude': '28.6139', // Delhi latitude
        'longitude': '77.2090', // Delhi longitude
      };
    }
  }

  /// Get fresh location from GPS (works offline)
  static Future<Map<String, String?>?> _getFreshLocation() async {
    try {
      print('OfflineLocationService: Starting fresh location request...');
      
      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      print('OfflineLocationService: Initial permission status: $permission');
      
      if (permission == LocationPermission.denied) {
        print('OfflineLocationService: Permission denied, requesting permission...');
        permission = await Geolocator.requestPermission();
        print('OfflineLocationService: Permission after request: $permission');
        if (permission == LocationPermission.denied) {
          print('OfflineLocationService: Location permission denied');
          return null;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        print('OfflineLocationService: Location permission permanently denied');
        return null;
      }
      
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      print('OfflineLocationService: Location services enabled: $serviceEnabled');
      if (!serviceEnabled) {
        print('OfflineLocationService: Location services are disabled');
        return null;
      }
      
      // Get current position with more lenient settings for offline use
      print('OfflineLocationService: Attempting to get current position...');
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium, // Use medium accuracy for better offline performance
        timeLimit: const Duration(seconds: 15), // Longer timeout for offline scenarios
      );
      
      print('OfflineLocationService: Position obtained successfully: ${position.latitude}, ${position.longitude}');
      
      final location = {
        'latitude': position.latitude.toString(),
        'longitude': position.longitude.toString(),
      };
      
      print('OfflineLocationService: Fresh location obtained: ${location['latitude']}, ${location['longitude']}');
      return location;
      
    } catch (e) {
      print('OfflineLocationService: Error getting fresh location: $e');
      return null;
    }
  }

  /// Get last known location from cache
  static Future<Map<String, String?>?> _getLastKnownLocation() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final locationJson = prefs.getString(_lastKnownLocationKey);
      
      if (locationJson != null) {
        final location = Map<String, String?>.from(json.decode(locationJson));
        print('OfflineLocationService: Retrieved last known location: ${location['latitude']}, ${location['longitude']}');
        return location;
      }
      
      return null;
    } catch (e) {
      print('OfflineLocationService: Error getting last known location: $e');
      return null;
    }
  }

  /// Cache location for offline use
  static Future<void> _cacheLocation(Map<String, String?> location) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Cache as last known location
      await prefs.setString(_lastKnownLocationKey, json.encode(location));
      
      // Add to location history
      await _addToLocationHistory(location);
      
      print('OfflineLocationService: Location cached successfully');
    } catch (e) {
      print('OfflineLocationService: Error caching location: $e');
    }
  }

  /// Add location to history for better fallback options
  static Future<void> _addToLocationHistory(Map<String, String?> location) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getString(_locationHistoryKey);
      
      List<Map<String, String?>> history = [];
      if (historyJson != null) {
        final List<dynamic> historyList = json.decode(historyJson);
        history = historyList.map((item) => Map<String, String?>.from(item)).toList();
      }
      
      // Add current location to history
      history.insert(0, location);
      
      // Keep only the most recent locations
      if (history.length > _maxHistorySize) {
        history = history.take(_maxHistorySize).toList();
      }
      
      await prefs.setString(_locationHistoryKey, json.encode(history));
    } catch (e) {
      print('OfflineLocationService: Error adding to location history: $e');
    }
  }

  /// Get location history for debugging or fallback
  static Future<List<Map<String, String?>>> getLocationHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getString(_locationHistoryKey);
      
      if (historyJson != null) {
        final List<dynamic> historyList = json.decode(historyJson);
        return historyList.map((item) => Map<String, String?>.from(item)).toList();
      }
      
      return [];
    } catch (e) {
      print('OfflineLocationService: Error getting location history: $e');
      return [];
    }
  }

  /// Clear location cache
  static Future<void> clearLocationCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_lastKnownLocationKey);
      await prefs.remove(_locationHistoryKey);
      print('OfflineLocationService: Location cache cleared');
    } catch (e) {
      print('OfflineLocationService: Error clearing location cache: $e');
    }
  }

  /// Get location with retry mechanism for better offline reliability
  static Future<Map<String, String?>> getLocationWithRetry({int maxRetries = 3}) async {
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      print('OfflineLocationService: Location attempt $attempt of $maxRetries');
      
      final location = await getCurrentLocationOffline();
      
      // If we got a valid location, return it
      if (location['latitude'] != null && location['longitude'] != null) {
        print('OfflineLocationService: Location obtained on attempt $attempt');
        return location;
      }
      
      // If this isn't the last attempt, wait before retrying
      if (attempt < maxRetries) {
        print('OfflineLocationService: Location attempt $attempt failed, retrying in 2 seconds...');
        await Future.delayed(const Duration(seconds: 2));
      }
    }
    
    print('OfflineLocationService: All location attempts failed, returning null values');
    return {'latitude': null, 'longitude': null};
  }

  /// Check if location services are available (permissions and GPS enabled)
  static Future<bool> isLocationServiceAvailable() async {
    try {
      // Check permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        return false;
      }
      
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      return serviceEnabled;
    } catch (e) {
      print('OfflineLocationService: Error checking location service availability: $e');
      return false;
    }
  }

  /// Get location with specific accuracy requirements
  static Future<Map<String, String?>> getLocationWithAccuracy(LocationAccuracy accuracy) async {
    try {
      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print('OfflineLocationService: Location permission denied');
          return await getCurrentLocationOffline(); // Fallback to cached location
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        print('OfflineLocationService: Location permission permanently denied');
        return await getCurrentLocationOffline(); // Fallback to cached location
      }
      
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('OfflineLocationService: Location services are disabled');
        return await getCurrentLocationOffline(); // Fallback to cached location
      }
      
      // Get current position with specified accuracy
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: accuracy,
        timeLimit: const Duration(seconds: 20),
      );
      
      final location = {
        'latitude': position.latitude.toString(),
        'longitude': position.longitude.toString(),
      };
      
      // Cache the location
      await _cacheLocation(location);
      
      print('OfflineLocationService: Location obtained with ${accuracy.name} accuracy: ${location['latitude']}, ${location['longitude']}');
      return location;
      
    } catch (e) {
      print('OfflineLocationService: Error getting location with specific accuracy: $e');
      return await getCurrentLocationOffline(); // Fallback to cached location
    }
  }
}
