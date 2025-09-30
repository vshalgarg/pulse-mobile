import '../services/location_service.dart';

/// Helper class for testing location services
class LocationTestHelper {
  /// Test the location service and return results
  static Future<Map<String, dynamic>> testLocationService() async {
    try {
      print('🧪 Testing location service...');
      
      // Test location service availability
      final isServiceEnabled = await LocationService.isLocationServiceEnabled();
      if (!isServiceEnabled) {
        return {
          'success': false,
          'error': 'Location service is disabled',
          'method': 'service_check',
        };
      }
      
      // Test getting current location
      final location = await LocationService.getCurrentLocation();
      
      return {
        'success': true,
        'latitude': location.latitude,
        'longitude': location.longitude,
        'method': 'gps',
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      print('❌ Location test failed: $e');
      return {
        'success': false,
        'error': e.toString(),
        'method': 'error',
      };
    }
  }
}
