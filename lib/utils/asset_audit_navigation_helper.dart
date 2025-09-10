import 'package:app/screens/asset_audit/asset_audit_solar/spv_screen.dart';
import 'package:app/screens/asset_audit/asset_audit_solar/mms_screen.dart';
import 'package:app/screens/asset_audit/asset_audit_solar/dcba_screen.dart';
import 'package:app/screens/asset_audit/asset_audit_solar/pcu_screen.dart';
import 'package:app/screens/asset_audit/asset_audit_solar/acdb_screen.dart';
import 'package:app/screens/asset_audit/asset_audit_solar/ltdb_screen.dart';
import 'package:app/screens/asset_audit/asset_audit_solar/transformer_screen.dart';
import 'package:app/screens/asset_audit/asset_audit_solar/vcb_screen.dart';
import 'package:app/screens/asset_audit/asset_audit_solar/wms_screen.dart';
import 'package:app/screens/asset_audit/asset_audit_solar/scada_screen.dart';
import 'package:app/screens/asset_audit/asset_audit_solar/fire_extinguisher_screen.dart';
import 'package:app/screens/asset_audit/asset_audit_solar/solar_survelliance_screen.dart';
import 'package:app/screens/asset_audit/asset_audit_solar/boundary_screen.dart';
import 'package:app/models/asset_audit_model.dart';
import 'package:flutter/material.dart';
import 'package:app/constants/constants_methods.dart';

class AssetAuditNavigationHelper {
  // ===== TELECOM NAVIGATION METHODS (ORIGINAL) =====
  
  static CategoryData? getCategoryData(AssetAuditModel? assetAuditData, String categoryName) {
    if (assetAuditData == null) return null;
    
    switch (categoryName.toLowerCase()) {
      case 'ccu':
        return assetAuditData.responseData.ccu;
      case 'battery':
        return assetAuditData.responseData.battery;
      case 'smps':
        return assetAuditData.responseData.smps;
      case 'dg':
        return assetAuditData.responseData.dg;
      case 'cctv':
        return assetAuditData.responseData.cctv;
      case 'fencing':
        return assetAuditData.responseData.fencing;
      case 'fire extinguisher':
        return assetAuditData.responseData.fireExtinguisher;
      case 'solar plates':
        return assetAuditData.responseData.solarPlates;
      default:
        return assetAuditData.responseData.categories[categoryName];
    }
  }

  static String getNextScreenName(String currentScreen) {
    switch (currentScreen.toLowerCase()) {
      case 'site info':
        return 'CCU';
      case 'ccu':
        return 'Battery';
      case 'battery':
        return 'Extinguisher';
      case 'extinguisher':
        return 'Solar Plates';
      case 'solar plates':
        return 'CCTV';
      case 'cctv':
        return 'Fencing';
      case 'fencing':
        return 'DG';
      case 'dg':
        return 'SMPS (Submit)'; // Final screen
      default:
        return '';
    }
  }

  static String getPreviousScreenName(String currentScreen) {
    switch (currentScreen.toLowerCase()) {
      case 'ccu':
        return 'Site Info';
      case 'battery':
        return 'CCU';
      case 'extinguisher':
        return 'Battery';
      case 'solar plates':
        return 'Extinguisher';
      case 'cctv':
        return 'Solar Plates';
      case 'fencing':
        return 'CCTV';
      case 'dg':
        return 'Fencing';
      case 'smps':
        return 'DG';
      default:
        return '';
    }
  }

  // ===== SOLAR NAVIGATION METHODS (NEW) =====
  
  // Define the order of all solar screens
  static const List<String> _solarScreenOrder = [
    'SPV',
    'MMS', 
    'Invertor',
    'ACDB',
    'LTDB',
    'Transformer',
    'VCB',
    'WMS',
    'SCADA',
    'Fire Extinguisher',
    'CCTV',
    'Boundary'
  ];

  /// Get the next available screen based on data availability (SOLAR)
  static String? getNextAvailableScreen(AssetAuditModel? assetAuditData, String currentScreen) {
    if (assetAuditData == null) return null;
    
    final currentIndex = _solarScreenOrder.indexOf(currentScreen);
    
    if (currentIndex == -1 || currentIndex >= _solarScreenOrder.length - 1) return null;
    
    // Return the immediate next screen in the flow
    return _solarScreenOrder[currentIndex + 1];
  }

  /// Get the previous available screen based on data availability (SOLAR)
  static String? getPreviousAvailableScreen(AssetAuditModel? assetAuditData, String currentScreen) {
    if (assetAuditData == null) return null;
    
    final currentIndex = _solarScreenOrder.indexOf(currentScreen);
    
    if (currentIndex <= 0) return null; // First screen or not found
    
    // Return the immediate previous screen in the flow
    return _solarScreenOrder[currentIndex - 1];
  }

  /// Get the previous screen name for back button text (SOLAR)
  static String getSolarPreviousScreenName(String currentScreen) {
    final currentIndex = _solarScreenOrder.indexOf(currentScreen);
    
    if (currentIndex <= 0) {
      return "General"; // First screen goes back to main screen
    }
    
    return _solarScreenOrder[currentIndex - 1];
  }

  /// Check if current screen is the first screen in the flow
  static bool isFirstScreen(String currentScreen) {
    return _solarScreenOrder.indexOf(currentScreen) == 0;
  }

  /// Navigate to the next screen based on screen name
  static void navigateToNextScreen(
    BuildContext context, 
    String screenName, 
    String siteType,
    String auditSchId,
    String siteAuditSchId,
    AssetAuditModel? assetAuditData,
  ) {
    switch (screenName) {
      case 'SPV':
        pushPage(context, SPVScreen(
          siteType: siteType,
          auditSchId: auditSchId,
          siteAuditSchId: siteAuditSchId,
          assetAuditData: assetAuditData,
        ));
        break;
      case 'MMS':
        pushPage(context, MMSScreen(
          siteType: siteType,
          auditSchId: auditSchId,
          siteAuditSchId: siteAuditSchId,
          assetAuditData: assetAuditData,
        ));
        break;
      case 'DCDB':
        pushPage(context, DCBAScreen(
          siteType: siteType,
          auditSchId: auditSchId,
          siteAuditSchId: siteAuditSchId,
          assetAuditData: assetAuditData,
        ));
        break;
      case 'Invertor':
        pushPage(context, PCUScreen(
          siteType: siteType,
          auditSchId: auditSchId,
          siteAuditSchId: siteAuditSchId,
          assetAuditData: assetAuditData,
        ));
        break;
      case 'ACDB':
        pushPage(context, ACDBScreen(
          siteType: siteType,
          auditSchId: auditSchId,
          siteAuditSchId: siteAuditSchId,
          assetAuditData: assetAuditData,
        ));
        break;
      case 'LTDB':
        pushPage(context, LTDBScreen(
          siteType: siteType,
          auditSchId: auditSchId,
          siteAuditSchId: siteAuditSchId,
          assetAuditData: assetAuditData,
        ));
        break;
      case 'Transformer':
        pushPage(context, TransformerScreen(
          siteType: siteType,
          auditSchId: auditSchId,
          siteAuditSchId: siteAuditSchId,
          assetAuditData: assetAuditData,
        ));
        break;
      case 'VCB':
        pushPage(context, VCBScreen(
          siteType: siteType,
          auditSchId: auditSchId,
          siteAuditSchId: siteAuditSchId,
          assetAuditData: assetAuditData,
        ));
        break;
      case 'WMS':
        pushPage(context, WMSScreen(
          siteType: siteType,
          auditSchId: auditSchId,
          siteAuditSchId: siteAuditSchId,
          assetAuditData: assetAuditData,
        ));
        break;
            case 'SCADA':
              pushPage(context, SCADAScreen(
                siteType: siteType,
                auditSchId: auditSchId,
                siteAuditSchId: siteAuditSchId,
                assetAuditData: assetAuditData,
              ));
              break;
      case 'Fire Extinguisher':
        pushPage(context, FireExtinguisherScreen(
          siteType: siteType,
          auditSchId: auditSchId,
          siteAuditSchId: siteAuditSchId,
          assetAuditData: assetAuditData,
        ));
        break;
      case 'CCTV':
        pushPage(context, SolarSurveillanceScreen(
          siteType: siteType,
          auditSchId: auditSchId,
          siteAuditSchId: siteAuditSchId,
          assetAuditData: assetAuditData,
        ));
        break;
      case 'Boundary':
        pushPage(context, BoundaryScreen(
          siteType: siteType,
          auditSchId: auditSchId,
          siteAuditSchId: siteAuditSchId,
          assetAuditData: assetAuditData,
        ));
        break;
      default:
        print('Unknown screen: $screenName');
        break;
    }
  }

  /// Check if a screen has data available
  static bool hasScreenData(AssetAuditModel? assetAuditData, String screenName) {
    if (assetAuditData == null) return false;
    
    final categories = assetAuditData.responseData.categories;
    if (!categories.containsKey(screenName)) return false;
    
    final categoryData = categories[screenName];
    return categoryData != null && categoryData.assets.isNotEmpty;
  }

  /// Get all available screens with data (SOLAR)
  static List<String> getAvailableScreens(AssetAuditModel? assetAuditData) {
    if (assetAuditData == null) return [];
    
    final categories = assetAuditData.responseData.categories;
    final availableScreens = <String>[];
    
    for (String screenName in _solarScreenOrder) {
      if (categories.containsKey(screenName)) {
        final categoryData = categories[screenName];
        if (categoryData != null && categoryData.assets.isNotEmpty) {
          availableScreens.add(screenName);
        }
      }
    }
    
    return availableScreens;
  }
}