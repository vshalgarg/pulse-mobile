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
import 'package:app/screens/asset_audit/asset_audit_telecom/asset_audit_telecom_page_1.dart';

// Telecom screen imports
import 'package:app/screens/asset_audit/asset_audit_telecom/site_info_screen.dart';
import 'package:app/screens/asset_audit/asset_audit_telecom/ccu_screen.dart';
import 'package:app/screens/asset_audit/asset_audit_telecom/battery_screen.dart';
import 'package:app/screens/asset_audit/asset_audit_telecom/extinguisher_screen.dart';
import 'package:app/screens/asset_audit/asset_audit_telecom/solar_plates.dart';
import 'package:app/screens/asset_audit/asset_audit_telecom/survelliance_screen.dart';
import 'package:app/screens/asset_audit/asset_audit_telecom/fencing_screen.dart';
import 'package:app/screens/asset_audit/asset_audit_telecom/dg_screen.dart';
import 'package:app/screens/asset_audit/asset_audit_telecom/smps_screen.dart';
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
  // ===== SOLAR NAVIGATION METHODS (NEW) =====
  
  // Define the order of all solar screens
  static const List<String> _solarScreenOrder = [
    'SPV',
    'DCDB',
    'MMS',
    'PCU',
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

  // Define the order of all telecom screens
  static const List<String> _telecomScreenOrder = [
    'Site Info',
    'CCU',
    'Battery',
    'Fire Extinguisher',
    'Solar Plates',
    'CCTV',
    'Fencing',
    'DG',
    'SMPS'
  ];

  /// Get the next available screen based on data availability (SOLAR)
  static String? getNextAvailableScreen(AssetAuditModel? assetAuditData, String currentScreen) {
    if (assetAuditData == null) return null;
    
    final currentIndex = _solarScreenOrder.indexOf(currentScreen);
    
    if (currentIndex < 0 || currentIndex >= _solarScreenOrder.length - 1) return null;
    String screenName = _solarScreenOrder[currentIndex + 1];
    if(assetAuditData == null || assetAuditData.responseData == null || assetAuditData.responseData.categories == null
      || assetAuditData.responseData.categories.isEmpty || assetAuditData.responseData.categories[screenName] == null) {
      return getNextAvailableScreen(assetAuditData, screenName);
    }

    // Return the immediate next screen in the flow
    return screenName;
  }

  /// Get the previous available screen based on data availability (SOLAR)
  static String? getPreviousAvailableScreen(AssetAuditModel? assetAuditData, String currentScreen) {
    if (assetAuditData == null) return null;
    
    final currentIndex = _solarScreenOrder.indexOf(currentScreen);
    
    if (currentIndex <= 0) return null; // First screen or not found

    String screenName = _solarScreenOrder[currentIndex - 1];
    if(assetAuditData == null || assetAuditData.responseData == null || assetAuditData.responseData.categories == null
        || assetAuditData.responseData.categories.isEmpty || assetAuditData.responseData.categories[screenName] == null) {
      return getPreviousAvailableScreen(assetAuditData, screenName);
    }

    // Return the immediate next screen in the flow
    return screenName;
  }

  // ===== TELECOM NAVIGATION METHODS =====
  
  /// Get the next available screen based on data availability (TELECOM)
  static String? getNextAvailableTelecomScreen(AssetAuditModel? assetAuditData, String currentScreen) {
    if (assetAuditData == null) return null;
    
    final currentIndex = _telecomScreenOrder.indexOf(currentScreen);
    
    if (currentIndex < 0 || currentIndex >= _telecomScreenOrder.length - 1) return null;
    String screenName = _telecomScreenOrder[currentIndex + 1];
    
    // Check if the screen has data using the telecom data structure
    CategoryData? categoryData = getCategoryData(assetAuditData, screenName);
    if (categoryData == null || (categoryData.assets.isEmpty && categoryData.subCategories!.isEmpty && categoryData.remarks.isEmpty)) {
      return getNextAvailableTelecomScreen(assetAuditData, screenName);
    }

    // Return the immediate next screen in the flow
    return screenName;
  }

  /// Get the previous available screen based on data availability (TELECOM)
  static String? getPreviousAvailableTelecomScreen(AssetAuditModel? assetAuditData, String currentScreen) {
    if (assetAuditData == null) return null;
    
    final currentIndex = _telecomScreenOrder.indexOf(currentScreen);
    
    if (currentIndex <= 0) return null; // First screen or not found

    String screenName = _telecomScreenOrder[currentIndex - 1];
    if(currentIndex-1 == 0) {
      return screenName;
    }
    // Check if the screen has data using the telecom data structure
    CategoryData? categoryData = getCategoryData(assetAuditData, screenName);
    if (categoryData == null || (categoryData.assets.isEmpty && categoryData.subCategories!.isEmpty && categoryData.remarks.isEmpty)) {
      return getPreviousAvailableTelecomScreen(assetAuditData, screenName);
    }

    // Return the immediate next screen in the flow
    return screenName;
  }

  /// Get the previous screen name for back button text (SOLAR)
  static String getSolarPreviousScreenName(String currentScreen) {
    final currentIndex = _solarScreenOrder.indexOf(currentScreen);
    
    if (currentIndex <= 0) {
      return "General"; // First screen goes back to main screen
    }
    
    return _solarScreenOrder[currentIndex - 1];
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
      case 'PCU':
        pushPage(context, PCUScreen(
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
        print('Unknown screen for solar: $screenName');
        break;
    }
  }

  /// Navigate to the next screen based on screen name
  static void navigateToNextTelecomScreen(
      BuildContext context,
      String screenName,
      String siteType,
      String auditSchId,
      String siteAuditSchId,
      AssetAuditModel? assetAuditData,
      ) {
    switch (screenName) {
      case 'Site Info':
        pushPage(context, AssetAuditTelecomScreen(
          siteType: "Telecom",
          auditSchId: auditSchId,
          siteAuditSchId: siteAuditSchId,
        ));
        break;
      case 'CCU':
        pushPage(context, CCUScreen(
          ccuData: getCategoryData(assetAuditData, 'CCU'),
          assetAuditData: assetAuditData,
          siteType: siteType,
          auditSchId: auditSchId,
          siteAuditSchId: siteAuditSchId,
        ));
        break;
      case 'Battery':
        pushPage(context, BatteryScreen(
          batteryData: getCategoryData(assetAuditData, 'Battery'),
          assetAuditData: assetAuditData,
          siteType: siteType,
          auditSchId: auditSchId,
          siteAuditSchId: siteAuditSchId,
        ));
        break;
      case 'Fire Extinguisher':
        pushPage(context, ExtinguisherScreen(
          extinguisherData: getCategoryData(assetAuditData, 'Fire Extinguisher'),
          assetAuditData: assetAuditData,
          siteType: siteType,
          auditSchId: auditSchId,
          siteAuditSchId: siteAuditSchId,
        ));
        break;
      case 'Solar Plates':
        pushPage(context, SolarPlatesScreen(
          solarPlatesData: getCategoryData(assetAuditData, 'Solar Plates'),
          assetAuditData: assetAuditData,
          siteType: siteType,
          auditSchId: auditSchId,
          siteAuditSchId: siteAuditSchId,
        ));
        break;
      case 'CCTV':
        pushPage(context, SurveillianceScreen(
          cctvData: getCategoryData(assetAuditData, 'CCTV'),
          assetAuditData: assetAuditData,
        ));
        break;
      case 'Fencing':
        pushPage(context, FencingScreen(
          fencingData: getCategoryData(assetAuditData, 'Fencing'),
          assetAuditData: assetAuditData,
        ));
        break;
      case 'DG':
        pushPage(context, DgScreen(
          dgData: getCategoryData(assetAuditData, 'DG'),
          assetAuditData: assetAuditData,
        ));
        break;
      case 'SMPS':
        pushPage(context, SMPSScreen(
          smpsData: getCategoryData(assetAuditData, 'SMPS'),
          assetAuditData: assetAuditData,
        ));
        break;
      default:
        print('Unknown screen for telecom: $screenName');
        break;
    }
  }
}