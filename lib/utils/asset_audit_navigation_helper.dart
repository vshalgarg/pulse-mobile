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
import 'package:app/screens/asset_audit/asset_audit_solar_v2/acdb_v2_screen.dart';
import 'package:app/screens/asset_audit/asset_audit_solar_v2/asset_audit_solar_v2_screen.dart';
import 'package:app/screens/asset_audit/asset_audit_solar_v2/boundary_v2_screen.dart';
import 'package:app/screens/asset_audit/asset_audit_solar_v2/dcdb_v2_screen.dart';
import 'package:app/screens/asset_audit/asset_audit_solar_v2/inverter_v2_screen.dart';
import 'package:app/screens/asset_audit/asset_audit_solar_v2/ltdb_v2_screen.dart';
import 'package:app/screens/asset_audit/asset_audit_solar_v2/mms_v2_screen.dart';
import 'package:app/screens/asset_audit/asset_audit_solar_v2/pcu_v2_screen.dart';
import 'package:app/screens/asset_audit/asset_audit_solar_v2/scada_v2_screen.dart';
import 'package:app/screens/asset_audit/asset_audit_solar_v2/surveillance_v2_screen.dart';
import 'package:app/screens/asset_audit/asset_audit_solar_v2/transformer_v2_screen.dart';
import 'package:app/screens/asset_audit/asset_audit_solar_v2/vcb_v2_screen.dart';
import 'package:app/screens/asset_audit/asset_audit_solar_v2/wms_v2_screen.dart';
import 'package:app/screens/asset_audit/asset_audit_solar_v2/spv_v2_screen.dart';
import 'package:app/screens/asset_audit/asset_audit_telecom/asset_audit_telecom_page_1.dart';

// Telecom screen imports
import 'package:app/screens/asset_audit/asset_audit_telecom/ccu_screen.dart';
import 'package:app/screens/asset_audit/asset_audit_telecom/battery_screen.dart';
import 'package:app/screens/asset_audit/asset_audit_telecom/extinguisher_screen.dart';
import 'package:app/screens/asset_audit/asset_audit_telecom/solar_plates.dart';
import 'package:app/screens/asset_audit/asset_audit_telecom/survelliance_screen.dart';
import 'package:app/screens/asset_audit/asset_audit_telecom/fencing_screen.dart';
import 'package:app/screens/asset_audit/asset_audit_telecom/dg_screen.dart';
import 'package:app/screens/asset_audit/asset_audit_telecom/smps_screen.dart';
import 'package:app/models/asset_audit_model.dart';
import 'package:app/screens/asset_audit/asset_audit_solar_v2/fire_extinguisher_v2_screen.dart';
import 'package:app/screens/asset_audit/asset_audit_telecom_v2/asset_audit_telecom_v2_screen.dart';
import 'package:app/screens/asset_audit/asset_audit_telecom_v2/battery_v2_screen.dart';
import 'package:app/screens/asset_audit/asset_audit_telecom_v2/boundary_telecom_v2_screen.dart';
import 'package:app/screens/asset_audit/asset_audit_telecom_v2/cctv_v2_screen.dart';
import 'package:app/screens/asset_audit/asset_audit_telecom_v2/ccu_v2_screen.dart';
import 'package:app/screens/asset_audit/asset_audit_telecom_v2/dg_v2_screen.dart';
import 'package:app/screens/asset_audit/asset_audit_telecom_v2/fire_extinguisher_telecom_v2_screen.dart';
import 'package:app/screens/asset_audit/asset_audit_telecom_v2/site_info_v2_screen.dart';
import 'package:app/screens/asset_audit/asset_audit_telecom_v2/smps_v2_screen.dart';
import 'package:app/screens/asset_audit/asset_audit_telecom_v2/solar_plate_v2_screen.dart';
import 'package:app/screens/home_screen.dart';
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
    'GENERAL',
    'SPV',
    'MMS',
    'DCDB',
    'PCU',
    'Invertor',
    'ACDB',
    'LTDB',
    'Transformer',
    'VCB',
    'WMS',
    'SCADA',
    'Fire Extinguisher',
    'Surveillance',
    'Boundary'
  ];

  static String dataValueForPage(String page, String type) {
    if(type == 'SOLAR') {
      return _dataValueForSolarPage(page);
    } else if(type == 'TELECOM') {
      return _dataValueForTelecomPage(page);
    }
    return page;
  }
  static String _dataValueForSolarPage(String page) {
    switch (page) {
      case 'GENERAL' : return 'pageHeader';
      case 'Surveillance': return 'CCTV';
      default:
        return page;
    }
  }

  static String _dataValueForTelecomPage(String page) {
    switch (page) {
      case 'GENERAL' : return 'pageHeader';
      case 'Site Info' : return 'pageHeader';
      default:
        return page;
    }
  }

  // Define the order of all telecom screens
  static const List<String> _telecomScreenOrder = [
    'GENERAL',
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

  static String? _getNextAvailableScreenNameV2(Map<String, dynamic>? assetAuditData, String currentScreen, List<String> screenOrder, String type) {
    if (assetAuditData == null) return null;

    final currentIndex = screenOrder.indexOf(currentScreen);

    if (currentIndex < 0 || currentIndex >= screenOrder.length - 1) return null;
    String screenName = screenOrder[currentIndex + 1];
    String dataValueForScrnName = dataValueForPage(screenName, type);
    if((assetAuditData['responseData'] == null
        || assetAuditData['responseData'][dataValueForScrnName] == null) && (assetAuditData[dataValueForScrnName] == null)) {
        return _getNextAvailableScreenNameV2(assetAuditData, screenName, screenOrder, type);
    }

    // Return the immediate next screen in the flow
    return screenName;
  }

  static String? _getPreviousAvailableScreenNameV2(Map<String, dynamic>? assetAuditData, String currentScreen, List<String> screenOrder, String type) {
    if (assetAuditData == null) return null;

    final currentIndex = screenOrder.indexOf(currentScreen);

    if (currentIndex <= 0 ) return null;
    String screenName = screenOrder[currentIndex - 1];
    String dataValueForScrnName = dataValueForPage(screenName, type);
    if((assetAuditData['responseData'] == null
        || assetAuditData['responseData'][dataValueForScrnName] == null) && (assetAuditData[dataValueForScrnName] == null)) {
      return _getPreviousAvailableScreenNameV2(assetAuditData, screenName, screenOrder, type);
    }

    // Return the immediate next screen in the flow
    return screenName;
  }

  static String getSolarNextScreenName(Map<String, dynamic>? assetAuditData, String currentScreen) {
    return _getNextAvailableScreenNameV2(assetAuditData, currentScreen, _solarScreenOrder, 'SOLAR')
    ?? 'SUBMIT';
  }

  static String getSolarPreviousScreenName(Map<String, dynamic>? assetAuditData, String currentScreen) {
    return _getPreviousAvailableScreenNameV2(assetAuditData, currentScreen, _solarScreenOrder, 'SOLAR')
    ?? 'BACK';
  }

  static void navigateToNextSolarScreen(BuildContext context, Map<String, dynamic>? assetAuditData, String currentScreenName, String siteAuditSchId, String siteType, String auditSchId) {
    String? nextScreenName = _getNextAvailableScreenNameV2(assetAuditData, currentScreenName, _solarScreenOrder, 'SOLAR');
    if(nextScreenName == null) {
      navigateToHomeScreen(context);
    } else {
      _navigateToSolarScreen(context, siteAuditSchId, siteType, auditSchId, nextScreenName);
    }
  }

  static void navigateToPreviousSolarScreen(BuildContext context, Map<String, dynamic>? assetAuditData, String currentScreenName, String siteAuditSchId, String siteType, String auditSchId) {
    String? previousScreenName = _getPreviousAvailableScreenNameV2(assetAuditData, currentScreenName, _solarScreenOrder, 'SOLAR');
    if(previousScreenName == null) {
      navigateToHomeScreen(context);
    } else {
       _navigateToSolarScreen(context, siteAuditSchId, siteType, auditSchId, previousScreenName);
    }
  }

  static void _navigateToSolarScreen(BuildContext context, String siteAuditSchId, String siteType, String auditSchId, String screenToNavigateOn) {
    switch(screenToNavigateOn) {
      case 'GENERAL' : pushPage(context, AssetAuditSolarV2Screen(
        siteAuditSchId: siteAuditSchId,
        siteType: siteType,
        auditSchId: auditSchId,
      ));
      case 'SPV' : pushPage(context, SPVV2Screen(
        siteAuditSchId: siteAuditSchId,
        siteType: siteType,
        auditSchId: auditSchId,
      ));
      break;
      case 'DCDB' : pushPage(context, DCDBV2Screen(
        siteAuditSchId: siteAuditSchId,
        siteType: siteType,
        auditSchId: auditSchId,
      ));
      break;
      case 'MMS' : pushPage(context, MMSV2Screen(
        siteAuditSchId: siteAuditSchId,
        siteType: siteType,
        auditSchId: auditSchId,
      ));
      break;
      case 'Invertor' : pushPage(context, InverterV2Screen(
        siteAuditSchId: siteAuditSchId,
        siteType: siteType,
        auditSchId: auditSchId,
      ));
      case 'PCU' : pushPage(context, PcuV2Screen(
        siteAuditSchId: siteAuditSchId,
        siteType: siteType,
        auditSchId: auditSchId,
      ));
      break;
      case 'ACDB' : pushPage(context, ACDBV2Screen(
        siteAuditSchId: siteAuditSchId,
        siteType: siteType,
        auditSchId: auditSchId,
      ));
      break;
      case 'LTDB' : pushPage(context, LTDBV2Screen(
        siteAuditSchId: siteAuditSchId,
        siteType: siteType,
        auditSchId: auditSchId,
      ));
      break;
      case 'Transformer' : pushPage(context, TransformerV2Screen(
        siteAuditSchId: siteAuditSchId,
        siteType: siteType,
        auditSchId: auditSchId,
      ));
      break;
      case 'VCB' : pushPage(context, VCBV2Screen(
        siteAuditSchId: siteAuditSchId,
        siteType: siteType,
        auditSchId: auditSchId,
      ));
      break;
      case 'WMS' : pushPage(context, WMSV2Screen(
        siteAuditSchId: siteAuditSchId,
        siteType: siteType,
        auditSchId: auditSchId,
      ));
      break;
      case 'SCADA' : pushPage(context, SCADAV2Screen(
        siteAuditSchId: siteAuditSchId,
        siteType: siteType,
        auditSchId: auditSchId,
      ));
      break;
      case 'Fire Extinguisher' : pushPage(context, FireExtinguisherV2Screen(
        siteAuditSchId: siteAuditSchId,
        siteType: siteType,
        auditSchId: auditSchId,
      ));
      break;
      case 'Surveillance' : pushPage(context, SurveillanceV2Screen(
        siteAuditSchId: siteAuditSchId,
        siteType: siteType,
        auditSchId: auditSchId,
      ));
      break;
      case 'Boundary' : pushPage(context, BoundaryV2Screen(
        siteAuditSchId: siteAuditSchId,
        siteType: siteType,
        auditSchId: auditSchId,
      ));
      default: break;
    }
  }

  static String getTelecomNextScreenName(Map<String, dynamic>? assetAuditData, String currentScreen) {
    return _getNextAvailableScreenNameV2(assetAuditData, currentScreen, _telecomScreenOrder, 'TELECOM')
        ?? 'SUBMIT';
  }

  static String getTelecomPreviousScreenName(Map<String, dynamic>? assetAuditData, String currentScreen) {
    return _getPreviousAvailableScreenNameV2(assetAuditData, currentScreen, _telecomScreenOrder, 'TELECOM')
        ?? 'BACK';
  }

  static void navigateToNextTelecomScreen(BuildContext context, Map<String, dynamic>? assetAuditData, String currentScreenName, String siteAuditSchId, String siteType, String auditSchId) {
    String? nextScreenName = _getNextAvailableScreenNameV2(assetAuditData, currentScreenName, _telecomScreenOrder, 'TELECOM');
    if(nextScreenName == null) {
      navigateToHomeScreen(context);
    } else {
      _navigateToTelecomScreen(context, siteAuditSchId, siteType, auditSchId, nextScreenName);
    }
  }

  static void navigateToPreviousTelecomScreen(BuildContext context, Map<String, dynamic>? assetAuditData, String currentScreenName, String siteAuditSchId, String siteType, String auditSchId) {
    String? previousScreenName = _getPreviousAvailableScreenNameV2(assetAuditData, currentScreenName, _telecomScreenOrder, 'TELECOM');
    if(previousScreenName == null) {
      navigateToHomeScreen(context);
    } else {
      _navigateToTelecomScreen(context, siteAuditSchId, siteType, auditSchId, previousScreenName);
    }
  }

  static void _navigateToTelecomScreen(BuildContext context, String siteAuditSchId, String siteType, String auditSchId, String screenToNavigateOn) {
    switch(screenToNavigateOn) {
      case 'GENERAL' : pushPage(context, AssetAuditTelecomV2Screen(
        siteAuditSchId: siteAuditSchId,
        siteType: siteType,
        auditSchId: auditSchId,
      ));
      break;
      case 'Site Info' : pushPage(context, SiteInfoV2Screen(
        siteAuditSchId: siteAuditSchId,
        siteType: siteType,
        auditSchId: auditSchId,
      ));
      break;
      case 'CCU' : pushPage(context, CCUV2Screen(
        siteAuditSchId: siteAuditSchId,
        siteType: siteType,
        auditSchId: auditSchId,
      ));
      break;
      case 'Battery' : pushPage(context, BatteryV2Screen(
        siteAuditSchId: siteAuditSchId,
        siteType: siteType,
        auditSchId: auditSchId,
      ));
      break;
      case 'Fire Extinguisher' : pushPage(context, FireExtinguisherTelecomV2Screen(
        siteAuditSchId: siteAuditSchId,
        siteType: siteType,
        auditSchId: auditSchId,
      ));
      break;
      case 'Solar Plates' : pushPage(context, SolarPlateV2Screen(
        siteAuditSchId: siteAuditSchId,
        siteType: siteType,
        auditSchId: auditSchId,
      ));
      break;
      case 'CCTV' : pushPage(context, CCTVV2Screen(
        siteAuditSchId: siteAuditSchId,
        siteType: siteType,
        auditSchId: auditSchId,
      ));
      break;
      case 'Boundary' : pushPage(context, BoundaryTelecomV2Screen(
        siteAuditSchId: siteAuditSchId,
        siteType: siteType,
        auditSchId: auditSchId,
      ));
      break;
      case 'DG' : pushPage(context, DGV2Screen(
        siteAuditSchId: siteAuditSchId,
        siteType: siteType,
        auditSchId: auditSchId,
      ));
      break;
      case 'SMPS' : pushPage(context, SMPSV2Screen(
        siteAuditSchId: siteAuditSchId,
        siteType: siteType,
        auditSchId: auditSchId,
      ));
      break;
      default: break;
    }
  }

  static void navigateToHomeScreen(BuildContext context) {
    Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => HomeScreen()));
  }

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

  /// Navigate to the next screen based on screen name
  static void navigateToNextScreen(
      BuildContext context,
      String screenName,
      String siteType,
      String auditSchId,
      String siteAuditSchId,
      AssetAuditModel? assetAuditData
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
  static void navigateToNextTelecomScreenDeprecated(
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