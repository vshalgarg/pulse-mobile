import '../services/location_service.dart';
import '../services/offline_location_service.dart';

class TestLocationDebug {
  /// Test the location service to see what's happening
  static Future<void> testLocationService() async {
    print('=== Testing Location Service ===');
    
    try {
      // Test offline location service directly
      print('1. Testing OfflineLocationService directly...');
      final offlineLocation = await OfflineLocationService.getCurrentLocationOffline();
      print('OfflineLocationService result: $offlineLocation');
      
      // Test location service wrapper
      print('2. Testing LocationService wrapper...');
      final locationServiceResult = await LocationService.getCurrentLocationOffline();
      print('LocationService result: $locationServiceResult');
      
      // Check if location data is valid
      final lat = offlineLocation['latitude'];
      final lng = offlineLocation['longitude'];
      
      if (lat != null && lng != null && lat.isNotEmpty && lng.isNotEmpty) {
        print('✅ Location data is valid: Lat=$lat, Lng=$lng');
      } else {
        print('❌ Location data is invalid or empty: Lat=$lat, Lng=$lng');
      }
      
    } catch (e) {
      print('❌ Error testing location service: $e');
    }
    
    print('=== End Location Test ===');
  }
  
  /// Test PM form helper with mock data
  static Future<void> testPmFormHelperWithLocation() async {
    print('=== Testing PM Form Helper with Location ===');
    
    try {
      // Test location service first
      final location = await LocationService.getCurrentLocationOffline();
      print('Location for PM test: $location');
      
      // Test with mock EARTHING data
      final mockFormData = {
        'EARTHING_1': 'OK',
        'EARTHING_2': 'NOT_OK',
      };
      
      print('Mock form data: $mockFormData');
      print('Location data: Lat=${location['latitude']}, Lng=${location['longitude']}');
      
    } catch (e) {
      print('❌ Error testing PM form helper: $e');
    }
    
    print('=== End PM Form Helper Test ===');
  }
}
