import '../services/location_service.dart';
import '../services/offline_location_service.dart';

class LocationTestHelper {
  /// Test location service and return detailed results
  static Future<Map<String, dynamic>> testLocationService() async {
    print('=== Starting Location Service Test ===');
    
    Map<String, dynamic> results = {
      'success': false,
      'latitude': null,
      'longitude': null,
      'error': null,
      'method': 'unknown',
    };
    
    try {
      // Test offline location service directly
      print('1. Testing OfflineLocationService directly...');
      final offlineLocation = await OfflineLocationService.getCurrentLocationOffline();
      print('OfflineLocationService result: $offlineLocation');
      
      if (offlineLocation?['latitude'] != null && offlineLocation?['longitude'] != null) {
        results['success'] = true;
        results['latitude'] = offlineLocation?['latitude'];
        results['longitude'] = offlineLocation?['longitude'];
        results['method'] = 'offline_service';
        print('✅ Location test successful via OfflineLocationService');
        return results;
      }
      
      // Test location service wrapper
      print('2. Testing LocationService wrapper...');
      final locationServiceResult = await LocationService.getCurrentLocationOffline();
      print('LocationService result: $locationServiceResult');
      
      if (locationServiceResult?['latitude'] != null && locationServiceResult?['longitude'] != null) {
        results['success'] = true;
        results['latitude'] = locationServiceResult?['latitude'];
        results['longitude'] = locationServiceResult?['longitude'];
        results['method'] = 'location_service';
        print('✅ Location test successful via LocationService');
        return results;
      }
      
      results['error'] = 'Both location services returned null values';
      print('❌ Both location services returned null values');
      
    } catch (e) {
      results['error'] = e.toString();
      print('❌ Error testing location service: $e');
    }
    
    print('=== End Location Service Test ===');
    return results;
  }
  
  /// Test with mock EARTHING data to see if location gets included
  static Future<void> testEarthingWithLocation() async {
    print('=== Testing EARTHING with Location ===');
    
    try {
      // Test location service first
      final location = await LocationService.getCurrentLocationOffline();
      print('Location for EARTHING test: $location');
      
      // Test with mock EARTHING data
      final mockFormData = {
        'EARTHING_1': 'OK',
        'EARTHING_2': 'NOT_OK',
        'EARTHING_10': 'Not OK - To be corrected',
      };
      
      print('Mock EARTHING form data: $mockFormData');
      print('Location data: Lat=${location?['latitude']}, Lng=${location?['longitude']}');
      
      // Simulate what PmFormHelper would do
      final latitude = location?['latitude'] ?? '';
      final longitude = location?['longitude'] ?? '';
      
      print('Processed location: Lat=$latitude, Lng=$longitude');
      
      if (latitude.isNotEmpty && longitude.isNotEmpty) {
        print('✅ Location data is valid for EARTHING submission');
      } else {
        print('❌ Location data is invalid for EARTHING submission');
      }
      
    } catch (e) {
      print('❌ Error testing EARTHING with location: $e');
    }
    
    print('=== End EARTHING Location Test ===');
  }
}
