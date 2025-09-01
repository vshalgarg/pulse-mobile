import '../../../models/asset_audit_model.dart';

class AssetAuditNavigationHelper {
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
}
