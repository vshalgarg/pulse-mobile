import 'package:app/repositories/asset_audit_repository.dart';
import 'package:app/services/api_provider.dart';
import 'package:app/services/api_service.dart';
import 'package:app/utils/logger.dart';

class AssetAuditFormPersistenceHelperSQLite {
  static AssetAuditRepository? _repository;
  
  static void initialize(ApiProvider apiProvider) {
    _repository = AssetAuditRepository(apiService: ApiService(apiProvider));
  }
  
  static AssetAuditRepository get _getRepository {
    if (_repository == null) {
      throw Exception('AssetAuditFormPersistenceHelperSQLite not initialized. Call initialize() first.');
    }
    return _repository!;
  }

  /// Save form data for a specific screen
  static Future<void> saveFormData({
    required String siteAuditSchId,
    required String screenName,
    required Map<String, dynamic> formData,
  }) async {
    try {
      final siteAuditSchIdInt = int.parse(siteAuditSchId);
      Logger.debugLog('Saving form data for site $siteAuditSchId, screen $screenName');
      await _getRepository.saveFormData(
        siteAuditSchId: siteAuditSchIdInt,
        screenName: screenName,
        formData: formData,
      );
      Logger.debugLog('✅ Form data saved successfully');
    } catch (e) {
      Logger.errorLog('❌ Error saving form data: $e');
    }
  }

  /// Load form data for a specific screen
  static Future<Map<String, dynamic>?> loadFormData({
    required String siteAuditSchId,
    required String screenName,
  }) async {
    try {
      final siteAuditSchIdInt = int.parse(siteAuditSchId);
      Logger.debugLog('Loading form data for site $siteAuditSchId, screen $screenName');
      final formData = await _getRepository.getFormData(
        siteAuditSchId: siteAuditSchIdInt,
        screenName: screenName,
      );
      if (formData != null) {
        Logger.debugLog('✅ Form data loaded successfully');
      } else {
        Logger.debugLog('No form data found');
      }
      return formData;
    } catch (e) {
      Logger.errorLog('❌ Error loading form data: $e');
      return null;
    }
  }

  /// Clear form data for a specific screen
  static Future<void> clearFormData({
    required String siteAuditSchId,
    required String screenName,
  }) async {
    try {
      final siteAuditSchIdInt = int.parse(siteAuditSchId);
      Logger.debugLog('Clearing form data for site $siteAuditSchId, screen $screenName');
      // For now, we'll save an empty map to clear the data
      await _getRepository.saveFormData(
        siteAuditSchId: siteAuditSchIdInt,
        screenName: screenName,
        formData: {},
      );
      Logger.debugLog('✅ Form data cleared successfully');
    } catch (e) {
      Logger.errorLog('❌ Error clearing form data: $e');
    }
  }

  /// Clear all form data for a site
  static Future<void> clearAllFormData(String siteAuditSchId) async {
    try {
      final siteAuditSchIdInt = int.parse(siteAuditSchId);
      Logger.debugLog('Clearing all form data for site $siteAuditSchId');
      await _getRepository.clearSiteData(siteAuditSchIdInt);
      Logger.debugLog('✅ All form data cleared successfully');
    } catch (e) {
      Logger.errorLog('❌ Error clearing all form data: $e');
    }
  }

  /// Get cached image data
  static Future<String?> getCachedImage(int imageId) async {
    try {
      Logger.debugLog('Getting cached image for ID: $imageId');
      final imageData = await _getRepository.getCachedImage(imageId);
      if (imageData != null) {
        Logger.debugLog('✅ Cached image found');
      } else {
        Logger.debugLog('No cached image found');
      }
      return imageData;
    } catch (e) {
      Logger.errorLog('❌ Error getting cached image: $e');
      return null;
    }
  }

  /// Check if image is cached
  static Future<bool> isImageCached(int imageId) async {
    try {
      return await _getRepository.isImageCached(imageId);
    } catch (e) {
      Logger.errorLog('❌ Error checking if image is cached: $e');
      return false;
    }
  }
}
