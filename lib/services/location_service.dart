import 'package:app/constants/exception_constants.dart';
import 'package:app/models/location_model.dart';
import 'package:app/utils/logger.dart';
import 'package:app/utils/toastbar.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';

class LocationService {
  
  /// Get user's current location
  /// Note: If location services are disabled, calling getCurrentPosition() will
  /// automatically trigger Android's system dialog to enable location services.
  static Future<LocationModel> getCurrentLocation() async {
    try {
      LocationPermission permission;

      // Check permission first
      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception(ExceptionConstants.UNABLE_TO_GET_LOCATION);
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception(ExceptionConstants.UNABLE_TO_GET_LOCATION);
      }

      // Get location - if location services are disabled, Android will automatically
      // show a system dialog asking to enable location services
      // The user can tap "TURN ON" in the system dialog to enable location directly
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      Logger.infoLog("user's location fetched: $position");
      return LocationModel(latitude: position.latitude, longitude: position.longitude);
    } catch (e) {
      throw Exception(e);
    }
  }
  
  /// Open Google Maps with directions from current location to destination
  static Future<void> _openGoogleMapsDirections({
    required double destinationLat,
    required double destinationLng,
    String? destinationName,
    required BuildContext context,
  }) async {
    try {
      Logger.infoLog("Getting user's location");
      Toastbar.showInfoToastbar('Getting your current location...', context);
      // Get current location
      LocationModel currentPosition = await getCurrentLocation();
      if (!context.mounted) return;
      // Build Google Maps URL
      String url;
      if (destinationName != null) {
        // With destination name
        url = 'https://www.google.com/maps/dir/?api=1&origin=${currentPosition.latitude},${currentPosition.longitude}&destination=${destinationLat},${destinationLng}&destination_place_id=${Uri.encodeComponent(destinationName)}&travelmode=driving';
      } else {
        // Just coordinates
        url = 'https://www.google.com/maps/dir/?api=1&origin=${currentPosition.latitude},${currentPosition.longitude}&destination=${destinationLat},${destinationLng}&travelmode=driving';
      }
      
      Logger.infoLog('Opening Google Maps URL: $url');
      
      // Launch URL
      final Uri uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        if (!context.mounted) return;
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (!context.mounted) return;
        Toastbar.showSuccessToastbar("Redirecting to google maps", context);
      } else {
        if (!context.mounted) return;
        Toastbar.showErrorToastbar('Could not open Google Maps. Please install Google Maps app.', context);
      }
    } catch (e) {
      Logger.errorLog('Error opening Google Maps: $e');
      if (!context.mounted) return;
      Toastbar.showErrorToastbar(e.toString(), context);
    }
  }
  
  /// Open Google Maps with directions from current location to destination (simplified)
  static Future<void> openDirectionsToSite({
    required double siteLat,
    required double siteLng,
    String? siteName,
    required BuildContext context,
  }) async {
    await _openGoogleMapsDirections(
      destinationLat: siteLat,
      destinationLng: siteLng,
      destinationName: siteName,
      context: context,
    );
  }
}
