import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';

class LocationPermissionService {
  /// Request location permissions and return the status
  static Future<Map<String, dynamic>> requestLocationPermissions() async {

    Map<String, dynamic> result = {
      'success': false,
      'fineLocation': false,
      'coarseLocation': false,
      'message': '',
    };
    
    try {
      // Check current permission status
      final fineLocationStatus = await Permission.locationWhenInUse.status;
      final coarseLocationStatus = await Permission.location.status;

      // Request fine location permission (most accurate)
      if (fineLocationStatus.isDenied) {

        final fineLocationResult = await Permission.locationWhenInUse.request();

        if (fineLocationResult.isGranted) {
          result['fineLocation'] = true;
        } else if (fineLocationResult.isPermanentlyDenied) {
          result['message'] = 'Fine location permission permanently denied. Please enable in settings.';
          return result;
        }
      } else if (fineLocationStatus.isGranted) {
        result['fineLocation'] = true;
      }
      
      // Request coarse location permission as fallback
      if (coarseLocationStatus.isDenied) {

        final coarseLocationResult = await Permission.location.request();

        if (coarseLocationResult.isGranted) {
          result['coarseLocation'] = true;
        } else if (coarseLocationResult.isPermanentlyDenied) {
          result['message'] = 'Coarse location permission permanently denied. Please enable in settings.';
          return result;
        }
      } else if (coarseLocationStatus.isGranted) {
        result['coarseLocation'] = true;
      }
      
      // Check if we have at least one location permission
      if (result['fineLocation'] || result['coarseLocation']) {
        result['success'] = true;
        result['message'] = 'Location permissions granted successfully';

      } else {
        result['message'] = 'Location permissions denied';

      }
      
    } catch (e) {
      result['message'] = 'Error requesting location permissions: $e';

    }
    
    return result;
  }
  
  /// Check if location permissions are granted
  static Future<bool> hasLocationPermissions() async {
    try {
      final fineLocationStatus = await Permission.locationWhenInUse.status;
      final coarseLocationStatus = await Permission.location.status;
      
      return fineLocationStatus.isGranted || coarseLocationStatus.isGranted;
    } catch (e) {

      return false;
    }
  }
  
  /// Check if location services are enabled
  static Future<bool> isLocationServiceEnabled() async {
    try {
      return await Geolocator.isLocationServiceEnabled();
    } catch (e) {

      return false;
    }
  }
  
  /// Open app settings for location permissions
  static Future<void> openLocationSettings() async {
    try {
      await openAppSettings();
    } catch (e) {

    }
  }
  
  /// Get detailed permission status
  static Future<Map<String, dynamic>> getPermissionStatus() async {
    try {
      final fineLocationStatus = await Permission.locationWhenInUse.status;
      final coarseLocationStatus = await Permission.location.status;
      final locationServiceEnabled = await Geolocator.isLocationServiceEnabled();
      
      return {
        'fineLocation': fineLocationStatus.toString(),
        'coarseLocation': coarseLocationStatus.toString(),
        'locationServiceEnabled': locationServiceEnabled,
        'hasAnyPermission': fineLocationStatus.isGranted || coarseLocationStatus.isGranted,
      };
    } catch (e) {

      return {
        'fineLocation': 'unknown',
        'coarseLocation': 'unknown',
        'locationServiceEnabled': false,
        'hasAnyPermission': false,
      };
    }
  }
}
