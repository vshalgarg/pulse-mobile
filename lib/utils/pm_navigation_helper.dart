import 'package:flutter/material.dart';
import '../constants/pm_constants.dart';

class PMNavigationHelper {
  // Get the order of all PM screens from PMConstants based on page type
  static List<String> _getPmScreenOrder(Map<String, dynamic>? pmData) {
    // Determine if this is a solar or telecom PM based on the data structure
    final isSolarPM = _isSolarPM(pmData);
    
    if (isSolarPM) {
      final solarPages = PMConstants.getSolarPageOrder();
      return ['Site Info', ...solarPages];
    } else {
      final telecomPages = PMConstants.getTelecomPageOrder();
      return ['Site Info', ...telecomPages];
    }
  }

  // Determine if this is a solar PM based on data structure
  static bool _isSolarPM(Map<String, dynamic>? pmData) {
    if (pmData == null) return false;
    
    final responseData = pmData['responseData'] as Map<String, dynamic>? ?? {};
    
    // Debug logging

    // Check for solar-specific page keys (these are the actual API response keys)
    final solarKeys = ['SPV', 'Cables', 'Inverters', 'Transformer', 'BOS', 'Civil & Structures', 'Safety Systems', 'Performance', 'Earthing', 'Hygiene'];
    final hasSolarKeys = solarKeys.any((key) => responseData.containsKey(key));
    
    // Check for telecom-specific page keys (these are the actual API response keys)
    final telecomKeys = ['Tower', 'Battery', 'CCU', 'Solar', 'Electrical', 'SEB', 'DG', 'Fire Extinguisher', 'CT'];
    final hasTelecomKeys = telecomKeys.any((key) => responseData.containsKey(key));

    // If we have solar keys but no telecom keys, it's solar
    if (hasSolarKeys && !hasTelecomKeys) {

      return true;
    }
    
    // If we have telecom keys but no solar keys, it's telecom
    if (hasTelecomKeys && !hasSolarKeys) {

      return false;
    }
    
    // If we have both or neither, check the site type from pageHeader
    final pageHeader = pmData['pageHeader'] as List?;
    if (pageHeader != null && pageHeader.isNotEmpty) {
      final firstHeader = pageHeader.first as Map<String, dynamic>?;
      final siteTypeName = firstHeader?['site_type_name']?.toString().toLowerCase();

      if (siteTypeName != null) {
        if (siteTypeName.contains('solar') || siteTypeName.contains('spv') || siteTypeName.contains('pv')) {

          return true;
        }
      }
    }
    
    // Default to telecom for backward compatibility

    return false;
  }

  /// Get the next available screen name based on available data
  static String? getNextAvailableScreenName(Map<String, dynamic>? pmData, String currentScreen) {
    if (pmData == null) return null;

    final pmScreenOrder = _getPmScreenOrder(pmData);
    final currentIndex = pmScreenOrder.indexOf(currentScreen);
    if (currentIndex < 0 || currentIndex >= pmScreenOrder.length - 1) return null;

    // Find next available screen
    for (int i = currentIndex + 1; i < pmScreenOrder.length; i++) {
      final screenName = pmScreenOrder[i];
      if (_isScreenDataAvailable(pmData, screenName)) {
        return screenName;
      }
    }

    return null; // No more screens available
  }

  /// Get the previous available screen name based on available data
  static String? getPreviousAvailableScreenName(Map<String, dynamic>? pmData, String currentScreen) {
    if (pmData == null) return null;

    final pmScreenOrder = _getPmScreenOrder(pmData);
    final currentIndex = pmScreenOrder.indexOf(currentScreen);
    if (currentIndex <= 0) return null;

    // Find previous available screen
    for (int i = currentIndex - 1; i >= 0; i--) {
      final screenName = pmScreenOrder[i];
      if (_isScreenDataAvailable(pmData, screenName)) {
        return screenName;
      }
    }

    return null; // No previous screens available
  }

  /// Check if screen data is available
  static bool _isScreenDataAvailable(Map<String, dynamic> pmData, String screenName) {
    if (screenName == 'Site Info') {
      // Site Info is always available if pmData has pageHeader
      final hasSiteInfo = pmData['pageHeader'] != null && 
                         pmData['pageHeader'] is List && 
                         (pmData['pageHeader'] as List).isNotEmpty;

      return hasSiteInfo;
    }

    final responseData = pmData['responseData'] as Map<String, dynamic>? ?? {};
    final dataKey = PMConstants.getDataKeyForPage(screenName);
    final hasData = responseData.containsKey(dataKey) && 
                   responseData[dataKey] is List && 
                   (responseData[dataKey] as List).isNotEmpty;
    
    return hasData;
  }

  /// Get next screen name for display (returns 'Submit' if no next screen)
  static String getNextScreenName(Map<String, dynamic>? pmData, String currentScreen) {
    return getNextAvailableScreenName(pmData, currentScreen) ?? 'Submit';
  }

  /// Get previous screen name for display (returns 'Back' if no previous screen)
  static String getPreviousScreenName(Map<String, dynamic>? pmData, String currentScreen) {
    return getPreviousAvailableScreenName(pmData, currentScreen) ?? 'Back';
  }

  /// Get all available screens in order
  static List<String> getAvailableScreens(Map<String, dynamic>? pmData) {
    if (pmData == null) return ['Site Info'];

    final pmScreenOrder = _getPmScreenOrder(pmData);
    final availableScreens = pmScreenOrder.where((screen) => _isScreenDataAvailable(pmData, screen)).toList();
    
    // Debug logging

    // If no screens are available, but we have pageHeader, at least show Site Info
    if (availableScreens.isEmpty) {
      final pageHeader = pmData['pageHeader'] as List?;
      if (pageHeader != null && pageHeader.isNotEmpty) {

        return ['Site Info'];
      }
    }
    
    return availableScreens;
  }

  /// Get screen display name (for button text)
  static String getScreenDisplayName(String screenName) {
    if (screenName == 'Site Info') {
      return 'Site Info';
    }
    
    // For telecom pages, return the display name as is
    // since they're already in the correct format from PMConstants
    return screenName;
  }

  /// Navigate to next screen
  static void navigateToNextScreen(BuildContext context, Map<String, dynamic>? pmData, String currentScreen) {
    final nextScreen = getNextAvailableScreenName(pmData, currentScreen);
    if (nextScreen == null) {
      // No more screens, navigate to home or show completion
      Navigator.of(context).pop();
    } else {
      // Navigation will be handled by the parent widget
      // This is just a placeholder for future navigation logic
    }
  }

  /// Navigate to previous screen
  static void navigateToPreviousScreen(BuildContext context, Map<String, dynamic>? pmData, String currentScreen) {
    final previousScreen = getPreviousAvailableScreenName(pmData, currentScreen);
    if (previousScreen == null) {
      // No previous screens, navigate to home
      Navigator.of(context).pop();
    } else {
      // Navigation will be handled by the parent widget
      // This is just a placeholder for future navigation logic
    }
  }
}
