import 'package:app/services/local_storage_db.dart';

import '../services/local_storage_constants.dart';

/// Helper class for managing form data persistence across asset audit screens
class AssetAuditFormPersistenceHelper {
  static const Map<String, String> _screenNames = {
    'telecom_page_1': 'Telecom Page 1',
    'fencing_screen': 'Fencing Screen',
    'smps_screen': 'SMPS Screen',
    'battery_screen': 'Battery Screen',
    'extinguisher_screen': 'Extinguisher Screen',
    'ccu_screen': 'CCU Screen',
    'surveillance_screen': 'Surveillance Screen',
    'dg_screen': 'DG Screen',
    'solar_plates_screen': 'Solar Plates Screen',
  };

  /// Save form data to Hive for a specific screen and ticket
  static Future<void> saveFormData({
    required String siteAuditSchId,
    required String screenName,
    required Map<String, dynamic> formData,
  }) async {
    if (formData.isEmpty) {
      print('=== Form Persistence: No data to save ===');
      return;
    }

    print('=== Form Persistence: Saving data for $screenName ===');
    print('Site Audit Sch ID: $siteAuditSchId');
    print('Data keys: ${formData.keys.toList()}');

    // Ensure Hive box is ready before saving
    await ensureHiveBoxReady();

    await LocalStorageDB.saveAssetAuditFormData(
      siteAuditSchId: siteAuditSchId,
      screenName: screenName,
      formData: formData,
    );

    print('=== Form Persistence: Data saved successfully ===');
  }

  /// Load saved form data from Hive for a specific screen and ticket
  static Future<Map<String, dynamic>?> loadFormData({
    required String siteAuditSchId,
    required String screenName,
  }) async {
    print('=== Form Persistence: Loading data for $screenName ===');
    print('Site Audit Sch ID: $siteAuditSchId');

    // Ensure Hive box is ready before loading
    await ensureHiveBoxReady();

    final savedData = LocalStorageDB.getAssetAuditFormData(
      siteAuditSchId: siteAuditSchId,
      screenName: screenName,
    );

    if (savedData != null && savedData['formData'] != null) {
      final formData = Map<String, dynamic>.from(savedData['formData'] as Map);
      print('=== Form Persistence: Found saved data ===');
      print('Data keys: ${formData.keys.toList()}');
      print('Timestamp: ${savedData['timestamp']}');
      return formData;
    } else {
      print('=== Form Persistence: No saved data found ===');
      return null;
    }
  }

  /// Update existing form data in Hive
  static Future<void> updateFormData({
    required String siteAuditSchId,
    required String screenName,
    required Map<String, dynamic> newFormData,
  }) async {
    print('=== Form Persistence: Updating data for $screenName ===');

    // Ensure Hive box is ready before updating
    await ensureHiveBoxReady();

    await LocalStorageDB.updateAssetAuditFormData(
      siteAuditSchId: siteAuditSchId,
      screenName: screenName,
      newFormData: newFormData,
    );

    print('=== Form Persistence: Data updated successfully ===');
  }

  /// Clear saved form data for a specific screen
  static Future<void> clearFormData({
    required String siteAuditSchId,
    required String screenName,
  }) async {
    print('=== Form Persistence: Clearing data for $screenName ===');

    // Ensure Hive box is ready before clearing
    await ensureHiveBoxReady();

    await LocalStorageDB.clearAssetAuditFormData(
      siteAuditSchId: siteAuditSchId,
      screenName: screenName,
    );

    print('=== Form Persistence: Data cleared successfully ===');
  }

  /// Clear all form data for a specific ticket
  static Future<void> clearAllFormData(String siteAuditSchId) async {
    print('=== Form Persistence: Clearing all data for ticket ===');
    print('Site Audit Sch ID: $siteAuditSchId');

    // Ensure Hive box is ready before clearing
    await ensureHiveBoxReady();

    await LocalStorageDB.clearAllAssetAuditFormData(siteAuditSchId);

    print('=== Form Persistence: All data cleared successfully ===');
  }

  /// Get screen display name from internal name
  static String getScreenDisplayName(String screenName) {
    return _screenNames[screenName] ?? screenName;
  }

  /// Check if form data exists for a specific screen
  static Future<bool> hasFormData({
    required String siteAuditSchId,
    required String screenName,
  }) async {
    // Ensure Hive box is ready before checking
    await ensureHiveBoxReady();
    
    final savedData = LocalStorageDB.getAssetAuditFormData(
      siteAuditSchId: siteAuditSchId,
      screenName: screenName,
    );
    return savedData != null && savedData['formData'] != null;
  }

  /// Get timestamp of last saved form data
  static Future<DateTime?> getLastSavedTimestamp({
    required String siteAuditSchId,
    required String screenName,
  }) async {
    // Ensure Hive box is ready before getting timestamp
    await ensureHiveBoxReady();
    
    final savedData = LocalStorageDB.getAssetAuditFormData(
      siteAuditSchId: siteAuditSchId,
      screenName: screenName,
    );
    
    if (savedData != null && savedData['timestamp'] != null) {
      return DateTime.fromMillisecondsSinceEpoch(savedData['timestamp']);
    }
    return null;
  }

  /// Ensure Hive box is ready before operations
  static Future<void> ensureHiveBoxReady() async {
    try {
      // No need to open Hive box - using SharedPreferences now
      print('=== Form Persistence: Hive box is ready ===');
    } catch (e) {
      print('=== Form Persistence: Error ensuring Hive box ready: $e ===');
    }
  }
}
