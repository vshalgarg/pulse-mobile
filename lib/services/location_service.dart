import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';
import 'offline_location_service.dart';

class LocationService {
  /// Get user's current location with offline support
  static Future<Map<String, String?>> getCurrentLocationOffline() async {
    return await OfflineLocationService.getCurrentLocationOffline();
  }

  /// Get user's current location
  static Future<Position?> getCurrentLocation() async {
    try {
      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print('Location permission denied');
          return null;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        print('Location permission permanently denied');
        return null;
      }
      
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('Location services are disabled');
        return null;
      }
      
      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      
      print('Current location: ${position.latitude}, ${position.longitude}');
      return position;
      
    } catch (e) {
      print('Error getting current location: $e');
      return null;
    }
  }
  
  /// Open Google Maps with directions from current location to destination
  static Future<void> openGoogleMapsDirections({
    required double destinationLat,
    required double destinationLng,
    String? destinationName,
    required BuildContext context,
  }) async {
    try {
      // Show loading message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Getting your current location...'),
          duration: Duration(seconds: 2),
        ),
      );
      
      // Get current location
      Position? currentPosition = await getCurrentLocation();
      
      if (currentPosition == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not get your current location. Please check location permissions.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      // Build Google Maps URL
      String url;
      if (destinationName != null) {
        // With destination name
        url = 'https://www.google.com/maps/dir/?api=1&origin=${currentPosition.latitude},${currentPosition.longitude}&destination=${destinationLat},${destinationLng}&destination_place_id=${Uri.encodeComponent(destinationName)}&travelmode=driving';
      } else {
        // Just coordinates
        url = 'https://www.google.com/maps/dir/?api=1&origin=${currentPosition.latitude},${currentPosition.longitude}&destination=${destinationLat},${destinationLng}&travelmode=driving';
      }
      
      print('Opening Google Maps URL: $url');
      
      // Launch URL
      final Uri uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Opening Google Maps with directions...'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open Google Maps. Please install Google Maps app.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      
    } catch (e) {
      print('Error opening Google Maps: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error opening directions: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  /// Open Google Maps with directions from current location to destination (simplified)
  static Future<void> openDirectionsToSite({
    required double siteLat,
    required double siteLng,
    String? siteName,
    required BuildContext context,
  }) async {
    await openGoogleMapsDirections(
      destinationLat: siteLat,
      destinationLng: siteLng,
      destinationName: siteName,
      context: context,
    );
  }
}
