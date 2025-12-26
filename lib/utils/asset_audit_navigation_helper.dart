// Old solar screen imports removed - using v2 screens now
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
// Old telecom screen imports removed - using v2 screens now
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
import 'package:app/screens/asset_audit/asset_audit_telecom_v2/electrical_screen.dart';
import 'package:app/routes/route_generator.dart';
import 'package:flutter/material.dart';
import 'package:app/constants/constants_methods.dart';

class AssetAuditNavigationHelper {
  // ===== TELECOM NAVIGATION METHODS (ORIGINAL) =====

  static CategoryData? getCategoryData(
    AssetAuditModel? assetAuditData,
    String categoryName,
  ) {
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
    'Solar',
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
    'Boundary',
  ];

  static String dataValueForPage(String page, String type) {
    if (type == 'SOLAR') {
      return _dataValueForSolarPage(page);
    } else if (type == 'TELECOM') {
      return _dataValueForTelecomPage(page);
    }
    return page;
  }

  static String _dataValueForSolarPage(String page) {
    switch (page) {
      case 'GENERAL':
        return 'pageHeader';
      case 'Surveillance':
        return 'CCTV';
      default:
        return page;
    }
  }

  static String _dataValueForTelecomPage(String page) {
    switch (page) {
      case 'GENERAL':
        return 'pageHeader';
      case 'Site Info':
        return 'pageHeader';
      case 'Solar Plates':
        return 'Solar';
      case 'Fencing':
        return 'Boundary';
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
    'SMPS',
    'Electrical',
  ];

  static String? _getNextAvailableScreenNameV2(
    Map<String, dynamic>? assetAuditData,
    String currentScreen,
    List<String> screenOrder,
    String type,
  ) {
    if (assetAuditData == null) return null;

    final currentIndex = screenOrder.indexOf(currentScreen);

    if (currentIndex < 0 || currentIndex >= screenOrder.length - 1) return null;
    String screenName = screenOrder[currentIndex + 1];
    String dataValueForScrnName = dataValueForPage(screenName, type);
    if ((assetAuditData['responseData'] == null ||
            assetAuditData['responseData'][dataValueForScrnName] == null) &&
        (assetAuditData[dataValueForScrnName] == null)) {
      return _getNextAvailableScreenNameV2(
        assetAuditData,
        screenName,
        screenOrder,
        type,
      );
    }

    // Return the immediate next screen in the flow
    return screenName;
  }

  static String? _getPreviousAvailableScreenNameV2(
    Map<String, dynamic>? assetAuditData,
    String currentScreen,
    List<String> screenOrder,
    String type,
  ) {
    if (assetAuditData == null) return null;

    final currentIndex = screenOrder.indexOf(currentScreen);

    if (currentIndex <= 0) return null;
    String screenName = screenOrder[currentIndex - 1];
    String dataValueForScrnName = dataValueForPage(screenName, type);
    if ((assetAuditData['responseData'] == null ||
            assetAuditData['responseData'][dataValueForScrnName] == null) &&
        (assetAuditData[dataValueForScrnName] == null)) {
      return _getPreviousAvailableScreenNameV2(
        assetAuditData,
        screenName,
        screenOrder,
        type,
      );
    }

    // Return the immediate next screen in the flow
    return screenName;
  }

  static String getSolarNextScreenName(
    Map<String, dynamic>? assetAuditData,
    String currentScreen,
  ) {
    return _getNextAvailableScreenNameV2(
          assetAuditData,
          currentScreen,
          _solarScreenOrder,
          'SOLAR',
        ) ??
        'SUBMIT';
  }

  static String getSolarPreviousScreenName(
    Map<String, dynamic>? assetAuditData,
    String currentScreen,
  ) {
    return _getPreviousAvailableScreenNameV2(
          assetAuditData,
          currentScreen,
          _solarScreenOrder,
          'SOLAR',
        ) ??
        'BACK';
  }

  static void navigateToNextSolarScreen(
    BuildContext context,
    Map<String, dynamic>? assetAuditData,
    String currentScreenName,
    String siteAuditSchId,
    String siteType,
    String auditSchId,
    BuildContext parentContext,
  ) {
    String? nextScreenName = _getNextAvailableScreenNameV2(
      assetAuditData,
      currentScreenName,
      _solarScreenOrder,
      'SOLAR',
    );
    if (nextScreenName == null) {
      navigateBackOrToHome(
        context,
        targetContext: parentContext,
      );
    } else {
      _navigateToSolarScreen(
        context,
        siteAuditSchId,
        siteType,
        auditSchId,
        nextScreenName,
        parentContext,
      );
    }
  }

  static void navigateToPreviousSolarScreen(
    BuildContext context,
    Map<String, dynamic>? assetAuditData,
    String currentScreenName,
    String siteAuditSchId,
    String siteType,
    String auditSchId,
    BuildContext parentContext,
  ) {
    String? previousScreenName = _getPreviousAvailableScreenNameV2(
      assetAuditData,
      currentScreenName,
      _solarScreenOrder,
      'SOLAR',
    );
    if (previousScreenName == null) {
      navigateBackOrToHome(
        context,
        targetContext: parentContext,
      );
    } else {
      _navigateToSolarScreen(
        context,
        siteAuditSchId,
        siteType,
        auditSchId,
        previousScreenName,
        parentContext,
      );
    }
  }

  static void _navigateToSolarScreen(
    BuildContext context,
    String siteAuditSchId,
    String siteType,
    String auditSchId,
    String screenToNavigateOn,
    BuildContext parentContext,
  ) {
    switch (screenToNavigateOn) {
      case 'GENERAL':
        pushPage(
          context,
          AssetAuditSolarV2Screen(
            siteAuditSchId: siteAuditSchId,
            siteType: siteType,
            auditSchId: auditSchId,
            parentContext: parentContext,
          ),
        );
        break;
      case 'Solar':
        pushPage(
          context,
          SPVV2Screen(
            siteAuditSchId: siteAuditSchId,
            siteType: siteType,
            auditSchId: auditSchId,
            parentContext: parentContext,
          ),
        );
        break;
      case 'DCDB':
        pushPage(
          context,
          DCDBV2Screen(
            siteAuditSchId: siteAuditSchId,
            siteType: siteType,
            auditSchId: auditSchId,
            parentContext: parentContext,
          ),
        );
        break;
      case 'MMS':
        pushPage(
          context,
          MMSV2Screen(
            siteAuditSchId: siteAuditSchId,
            siteType: siteType,
            auditSchId: auditSchId,
            parentContext: parentContext,
          ),
        );
        break;
      case 'Invertor':
        pushPage(
          context,
          InverterV2Screen(
            siteAuditSchId: siteAuditSchId,
            siteType: siteType,
            auditSchId: auditSchId,
            parentContext: parentContext,
          ),
        );
        break;
      case 'PCU':
        pushPage(
          context,
          PcuV2Screen(
            siteAuditSchId: siteAuditSchId,
            siteType: siteType,
            auditSchId: auditSchId,
            parentContext: parentContext,
          ),
        );
        break;
      case 'ACDB':
        pushPage(
          context,
          ACDBV2Screen(
            siteAuditSchId: siteAuditSchId,
            siteType: siteType,
            auditSchId: auditSchId,
            parentContext: parentContext,
          ),
        );
        break;
      case 'LTDB':
        pushPage(
          context,
          LTDBV2Screen(
            siteAuditSchId: siteAuditSchId,
            siteType: siteType,
            auditSchId: auditSchId,
            parentContext: parentContext,
          ),
        );
        break;
      case 'Transformer':
        pushPage(
          context,
          TransformerV2Screen(
            siteAuditSchId: siteAuditSchId,
            siteType: siteType,
            auditSchId: auditSchId,
            parentContext: parentContext,
          ),
        );
        break;
      case 'VCB':
        pushPage(
          context,
          VCBV2Screen(
            siteAuditSchId: siteAuditSchId,
            siteType: siteType,
            auditSchId: auditSchId,
            parentContext: parentContext,
          ),
        );
        break;
      case 'WMS':
        pushPage(
          context,
          WMSV2Screen(
            siteAuditSchId: siteAuditSchId,
            siteType: siteType,
            auditSchId: auditSchId,
            parentContext: parentContext,
          ),
        );
        break;
      case 'SCADA':
        pushPage(
          context,
          SCADAV2Screen(
            siteAuditSchId: siteAuditSchId,
            siteType: siteType,
            auditSchId: auditSchId,
            parentContext: parentContext,
          ),
        );
        break;
      case 'Fire Extinguisher':
        pushPage(
          context,
          FireExtinguisherV2Screen(
            siteAuditSchId: siteAuditSchId,
            siteType: siteType,
            auditSchId: auditSchId,
            parentContext: parentContext,
          ),
        );
        break;
      case 'Surveillance':
        pushPage(
          context,
          SurveillanceV2Screen(
            siteAuditSchId: siteAuditSchId,
            siteType: siteType,
            auditSchId: auditSchId,
            parentContext: parentContext,
          ),
        );
        break;
      case 'Boundary':
        pushPage(
          context,
          BoundaryV2Screen(
            siteAuditSchId: siteAuditSchId,
            siteType: siteType,
            auditSchId: auditSchId,
            parentContext: parentContext,
          ),
        );
        break;
      default:
        break;
    }
  }

  static String getTelecomNextScreenName(
    Map<String, dynamic>? assetAuditData,
    String currentScreen,
  ) {
    return _getNextAvailableScreenNameV2(
          assetAuditData,
          currentScreen,
          _telecomScreenOrder,
          'TELECOM',
        ) ??
        'SUBMIT';
  }

  static String getTelecomPreviousScreenName(
    Map<String, dynamic>? assetAuditData,
    String currentScreen,
  ) {
    return _getPreviousAvailableScreenNameV2(
          assetAuditData,
          currentScreen,
          _telecomScreenOrder,
          'TELECOM',
        ) ??
        'BACK';
  }

  static void navigateToNextTelecomScreen(
    BuildContext context,
    Map<String, dynamic>? assetAuditData,
    String currentScreenName,
    String siteAuditSchId,
    String siteType,
    String auditSchId,
    BuildContext parentContext,
  ) {
    String? nextScreenName = _getNextAvailableScreenNameV2(
      assetAuditData,
      currentScreenName,
      _telecomScreenOrder,
      'TELECOM',
    );
    if (nextScreenName == null) {
      navigateBackOrToHome(
        context,
        targetContext: parentContext,
      );
    } else {
      _navigateToTelecomScreen(
        context,
        siteAuditSchId,
        siteType,
        auditSchId,
        nextScreenName,
        parentContext,
      );
    }
  }

  static void navigateToPreviousTelecomScreen(
    BuildContext context,
    Map<String, dynamic>? assetAuditData,
    String currentScreenName,
    String siteAuditSchId,
    String siteType,
    String auditSchId,
    BuildContext parentContext,
  ) {
    String? previousScreenName = _getPreviousAvailableScreenNameV2(
      assetAuditData,
      currentScreenName,
      _telecomScreenOrder,
      'TELECOM',
    );
    if (previousScreenName == null) {
      navigateBackOrToHome(
        context,
        targetContext: parentContext,
      );
    } else {
      _navigateToTelecomScreen(
        context,
        siteAuditSchId,
        siteType,
        auditSchId,
        previousScreenName,
        parentContext,
      );
    }
  }

  static void _navigateToTelecomScreen(
    BuildContext context,
    String siteAuditSchId,
    String siteType,
    String auditSchId,
    String screenToNavigateOn,
    BuildContext parentContext,
  ) {
    switch (screenToNavigateOn) {
      case 'GENERAL':
        pushPage(
          context,
          AssetAuditTelecomV2Screen(
            siteAuditSchId: siteAuditSchId,
            siteType: siteType,
            auditSchId: auditSchId,
            parentContext: parentContext,
          ),
        );
        break;
      case 'Site Info':
        pushPage(
          context,
          SiteInfoV2Screen(
            siteAuditSchId: siteAuditSchId,
            siteType: siteType,
            auditSchId: auditSchId,
            parentContext: parentContext,
          ),
        );
        break;
      case 'CCU':
        pushPage(
          context,
          CCUV2Screen(
            siteAuditSchId: siteAuditSchId,
            siteType: siteType,
            auditSchId: auditSchId,
            parentContext: parentContext,
          ),
        );
        break;
      case 'Battery':
        pushPage(
          context,
          BatteryV2Screen(
            siteAuditSchId: siteAuditSchId,
            siteType: siteType,
            auditSchId: auditSchId,
            parentContext: parentContext,
          ),
        );
        break;
      case 'Fire Extinguisher':
        pushPage(
          context,
          FireExtinguisherTelecomV2Screen(
            siteAuditSchId: siteAuditSchId,
            siteType: siteType,
            auditSchId: auditSchId,
            parentContext: parentContext,
          ),
        );
        break;
      case 'Solar Plates':
        pushPage(
          context,
          SolarPlateV2Screen(
            siteAuditSchId: siteAuditSchId,
            siteType: siteType,
            auditSchId: auditSchId,
            parentContext: parentContext,
          ),
        );
        break;
      case 'CCTV':
        pushPage(
          context,
          CCTVV2Screen(
            siteAuditSchId: siteAuditSchId,
            siteType: siteType,
            auditSchId: auditSchId,
            parentContext: parentContext,
          ),
        );
        break;
      case 'Fencing':
        pushPage(
          context,
          BoundaryTelecomV2Screen(
            siteAuditSchId: siteAuditSchId,
            siteType: siteType,
            auditSchId: auditSchId,
            parentContext: parentContext,
          ),
        );
        break;
      case 'DG':
        pushPage(
          context,
          DGV2Screen(
            siteAuditSchId: siteAuditSchId,
            siteType: siteType,
            auditSchId: auditSchId,
            parentContext: parentContext,
          ),
        );
        break;
      case 'SMPS':
        pushPage(
          context,
          SMPSV2Screen(
            siteAuditSchId: siteAuditSchId,
            siteType: siteType,
            auditSchId: auditSchId,
            parentContext: parentContext,
          ),
        );
        break;
      case 'Electrical':
        pushPage(
          context,
          ElectricalScreen(
            siteAuditSchId: siteAuditSchId,
            siteType: siteType,
            auditSchId: auditSchId,
            parentContext: parentContext,
          ),
        );
        break;
      default:
        break;
    }
  }

  static void navigateToHomeScreen(
    BuildContext context, {
    BuildContext? targetContext,
  }) {
    navigateBackOrToHome(
      context,
      targetContext: targetContext,
    );
  }

  /// Get the next available screen based on data availability (SOLAR)
  static String? getNextAvailableScreen(
    AssetAuditModel? assetAuditData,
    String currentScreen,
  ) {
    if (assetAuditData == null) return null;

    final currentIndex = _solarScreenOrder.indexOf(currentScreen);

    if (currentIndex < 0 || currentIndex >= _solarScreenOrder.length - 1)
      return null;
    String screenName = _solarScreenOrder[currentIndex + 1];
    final categories = assetAuditData.responseData.categories;
    if (categories.isEmpty ||
        categories[screenName] == null) {
      return getNextAvailableScreen(assetAuditData, screenName);
    }

    // Return the immediate next screen in the flow
    return screenName;
  }

  static void navigateToFirstAssetAuditScreen({
    required String siteType,
    required String auditSchId,
    required String siteAuditSchId,
    required BuildContext context,
  }) {
    final parentContext = context;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => siteType == 'Telecom'
            ? AssetAuditTelecomV2Screen(
                siteType: siteType,
                auditSchId: auditSchId,
                siteAuditSchId: siteAuditSchId,
                parentContext: parentContext,
              )
            : AssetAuditSolarV2Screen(
                siteType: siteType,
                auditSchId: auditSchId,
                siteAuditSchId: siteAuditSchId,
                parentContext: parentContext,
              ),
      ),
    );
  }
}
