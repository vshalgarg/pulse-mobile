import 'pages_pm_telecom_constants.dart';
import 'pages_pm_solar_constants.dart';

class PMConstants {

  // Telecom readonly fields map using enum values
  static const Map<String, List<String>> telecomReadonlyFieldsMap = {
    // PMTelecomPagesConstants.battery: [
    //   'Battery Make'
    // ],
    // PMTelecomPagesConstants.ccu: [
    //   'CCU Make'
    // ],
    // PMTelecomPagesConstants.dg: [
    //   'DG Make',
    // ],
    // PMTelecomPagesConstants.solar: [
    //   'Solar Make'
    // ],
  };

  // Telecom PM Page Order Configuration
  static const Map<String, String> telecomPageOrder = {
    PMTelecomPagesConstants.tower: 'Tower',
    PMTelecomPagesConstants.battery: 'Battery',
    PMTelecomPagesConstants.ccu: 'CCU',
    PMTelecomPagesConstants.solar: 'Solar',
    PMTelecomPagesConstants.electrical: 'Electrical',
    PMTelecomPagesConstants.seb: 'SEB',
    PMTelecomPagesConstants.dg: 'DG',
    PMTelecomPagesConstants.earthing: 'Earthing',
    PMTelecomPagesConstants.hygiene: 'Hygiene',
    PMTelecomPagesConstants.fireExtinguisher: 'Fire Extinguisher',
    PMTelecomPagesConstants.ct: 'CT',
  };

  // Solar readonly fields map using enum values
  static const Map<String, List<String>> solarReadonlyFieldsMap = {

  };

  // Solar PM Page Order Configuration
  static const Map<String, String> solarPageOrder = {
    PMSolarPagesConstants.SPV: 'SPV',
    PMSolarPagesConstants.CABLES: 'Cables',
    PMSolarPagesConstants.INVERTERS: 'Inverters',
    PMSolarPagesConstants.TRANSFORMER: 'Transformer',
    PMSolarPagesConstants.BOS: 'BOS (Balnace of system)',
    PMSolarPagesConstants.CIVIL_STRUCTURES: 'Civil & Structures',
    PMSolarPagesConstants.SAFETY_SYSTEMS: 'Safety Systems',
    PMSolarPagesConstants.PERFORMANCE: 'Performance Monitoring',
    PMSolarPagesConstants.EARTHING: 'Earthing',
    PMSolarPagesConstants.HYGIENE: 'Hygiene',
  };

  // Get telecom page order as a list
  static List<String> getTelecomPageOrder() {
    return telecomPageOrder.values.toList();
  }

  // Get telecom page order as enum list
  static List<String> getTelecomPageOrderEnums() {
    return telecomPageOrder.keys.toList();
  }

  // Get solar page order as a list
  static List<String> getSolarPageOrder() {
    return solarPageOrder.values.toList();
  }

  // Get solar page order as enum list
  static List<String> getSolarPageOrderEnums() {
    return solarPageOrder.keys.toList();
  }

  // Get data key for a telecom page
  static String getDataKeyForTelecomPage(String pageEnum) {
    return telecomPageOrder[pageEnum] ?? pageEnum;
  }

  // Get data key for a solar page
  static String getDataKeyForSolarPage(String pageEnum) {
    return solarPageOrder[pageEnum] ?? pageEnum;
  }

  // Get data key for a page by display name (backward compatibility)
  static String getDataKeyForPage(String pageDisplayName) {
    // Try to find in telecom pages first
    for (final entry in telecomPageOrder.entries) {
      if (entry.value == pageDisplayName) {
        return entry.key;
      }
    }
    // Try to find in solar pages
    for (final entry in solarPageOrder.entries) {
      if (entry.value == pageDisplayName) {
        return entry.key;
      }
    }
    return pageDisplayName;
  }

  // Get page order as a list (backward compatibility)
  static List<String> getPageOrder() {
    return getTelecomPageOrder();
  }

  // Get readonly fields for a telecom page using enum
  static List<String> getReadonlyFieldsForTelecomPage(String pageEnum) {
    return telecomReadonlyFieldsMap[pageEnum] ?? [];
  }

  // Get readonly fields for a solar page using enum
  static List<String> getReadonlyFieldsForSolarPage(String pageEnum) {
    return solarReadonlyFieldsMap[pageEnum] ?? [];
  }

  // Get readonly fields for a specific PM section (backward compatibility)
  static List<String> getReadonlyFieldsForSection(String sectionName) {
    // Try exact match first in telecom pages
    if (telecomReadonlyFieldsMap.containsKey(sectionName)) {
      return telecomReadonlyFieldsMap[sectionName]!;
    }
    
    // Try exact match in solar pages
    if (solarReadonlyFieldsMap.containsKey(sectionName)) {
      return solarReadonlyFieldsMap[sectionName]!;
    }
    
    // Try case-insensitive match in telecom pages
    final lowerSectionName = sectionName.toLowerCase();
    for (final entry in telecomReadonlyFieldsMap.entries) {
      if (entry.key.toLowerCase() == lowerSectionName) {
        return entry.value;
      }
    }
    
    // Try case-insensitive match in solar pages
    for (final entry in solarReadonlyFieldsMap.entries) {
      if (entry.key.toLowerCase() == lowerSectionName) {
        return entry.value;
      }
    }
    
    return [];
  }

  // Get all available section names
  static List<String> getAllSectionNames() {
    return [...telecomReadonlyFieldsMap.keys, ...solarReadonlyFieldsMap.keys];
  }

  // Check if a page is a telecom page
  static bool isTelecomPage(String pageDisplayName) {
    return telecomPageOrder.values.contains(pageDisplayName);
  }

  // Check if a page is a solar page
  static bool isSolarPage(String pageDisplayName) {
    return solarPageOrder.values.contains(pageDisplayName);
  }

  // Get telecom page enum from display name
  static String? getTelecomPageEnum(String pageDisplayName) {
    for (final entry in telecomPageOrder.entries) {
      if (entry.value == pageDisplayName) {
        return entry.key;
      }
    }
    return null;
  }

  // Get display name from telecom page enum
  static String getTelecomPageDisplayName(String pageEnum) {
    return telecomPageOrder[pageEnum] ?? pageEnum;
  }

  // Get solar page enum from display name
  static String? getSolarPageEnum(String pageDisplayName) {
    for (final entry in solarPageOrder.entries) {
      if (entry.value == pageDisplayName) {
        return entry.key;
      }
    }
    return null;
  }

  // Get display name from solar page enum
  static String getSolarPageDisplayName(String pageEnum) {
    return solarPageOrder[pageEnum] ?? pageEnum;
  }

  // Get all telecom section names from enum
  static List<String> getTelecomSectionNames() {
    return telecomReadonlyFieldsMap.keys.toList();
  }

  // Get all solar section names from enum
  static List<String> getSolarSectionNames() {
    return solarReadonlyFieldsMap.keys.toList();
  }

  // Get all additional section names (not in telecom enum)
  static List<String> getAdditionalSectionNames() {
    return [...telecomReadonlyFieldsMap.keys, ...solarReadonlyFieldsMap.keys];
  }

  // Check if a section has readonly fields defined
  static bool hasReadonlyFields(String sectionName) {
    return telecomReadonlyFieldsMap.containsKey(sectionName) || 
           solarReadonlyFieldsMap.containsKey(sectionName);
  }

  // Check if a telecom page has readonly fields defined
  static bool hasTelecomReadonlyFields(String pageEnum) {
    return telecomReadonlyFieldsMap.containsKey(pageEnum);
  }

  // Check if a solar page has readonly fields defined
  static bool hasSolarReadonlyFields(String pageEnum) {
    return solarReadonlyFieldsMap.containsKey(pageEnum);
  }

  // Get readonly fields count for a section
  static int getReadonlyFieldsCount(String sectionName) {
    return getReadonlyFieldsForSection(sectionName).length;
  }

  // Get readonly fields count for a telecom page
  static int getTelecomReadonlyFieldsCount(String pageEnum) {
    return getReadonlyFieldsForTelecomPage(pageEnum).length;
  }

  // Get readonly fields count for a solar page
  static int getSolarReadonlyFieldsCount(String pageEnum) {
    return getReadonlyFieldsForSolarPage(pageEnum).length;
  }

}
