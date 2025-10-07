import 'dart:convert';
import 'dart:io';
import 'package:app/enum/activity_type_enum.dart';
import 'package:app/models/cm_site_model.dart';
import 'package:app/models/sqlite/raw_api_data_model.dart';
import 'package:app/services/service_locator.dart';
import '../../utils/logger.dart';

class CentralAssetAuditService {

  Future<bool> getDataFromApiAndSaveToSqlite({
    required String siteType,
    required String auditSchId,
    required String siteAuditSchId,
    required double latitude,
    required double longitude,
    required ActivityTypeEnum activityType,
    required String pvTicketId,
    required String siteCode,
    required String cluster,
    required String operator,
    required String raisedDt,
    required String dueDt,
    required String status,
  }) async {
    final sqliteData = await ServiceLocator().centralAssetAuditDataService.getRawApiData(siteAuditSchId);
    if(sqliteData != null && sqliteData.isDownloaded) {
      return true;
    }

    final apiData = await ServiceLocator().centralApiService.fetchData(
      siteType: siteType,
      auditSchId: auditSchId,
      siteAuditSchId: siteAuditSchId,
      activityType: activityType
    );
    if(apiData == null) {
      return false;
    }
    // Save to SQLite
    final isSaved = await _saveDataToSQLite(
        siteAuditSchId: siteAuditSchId,
        siteType: siteType,
        auditSchId: auditSchId,
        activityType: activityType,
        latitude: latitude,
        longitude: longitude,
        pvTicketId: pvTicketId,
        siteCode: siteCode,
        cluster: cluster,
        operator: operator,
        raisedDt: raisedDt,
        dueDt: dueDt,
        status: status,
        isDownloaded: false,
        apiData: apiData);

    return isSaved;
  }

  Future<RawApiDataModel?> getDataFromSqlite({
    required String siteAuditSchId,
  }) async {
    final sqliteData = await ServiceLocator().centralAssetAuditDataService.getRawApiData(siteAuditSchId);
    if(sqliteData != null) {
      return sqliteData;
    } else {
      return null;
    }
  }

  /// Download CM site data and save to SQLite
  Future<bool> downloadCMSiteData({
    required CMSite site,
  }) async {
    try {
      Logger.debugLog('Starting to download CM site data for site: ${site.siteName}');
      
      // Save to SQLite using the new CM site data service
      bool isSaved = await ServiceLocator().centralAssetAuditDataService.saveCMSiteData(
        siteId: site.siteId,
        entityId: site.entityId,
        siteCode: site.siteCode,
        siteName: site.siteName,
        clusterDistrictId: site.clusterDistrictId,
        clusterDistrictName: site.clusterDistrictName,
        circleStateId: site.circleStateId,
        circleStateName: site.circleStateName,
        clientId: site.clientId,
        clientName: site.clientName,
        oem: site.oem,
        oemId: site.oemId,
        self: site.self,
        selfId: site.selfId,
        activityType: 'correctiveMaintenance',
      );

      Logger.debugLog('✅ CM site data saved successfully to SQLite: $isSaved');
      return isSaved;
    } catch (e) {
      Logger.errorLog('❌ Error downloading CM site data: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>?> getActualDataFromSqlite({
    required String siteAuditSchId,
  }) async {
    final sqliteData = await ServiceLocator().centralAssetAuditDataService.getRawApiData(siteAuditSchId);
    if(sqliteData != null) {
      return sqliteData.apiData;
    } else {
      return null;
    }
  }

  Future<bool> downloadData({
    required String siteType,
    required String auditSchId,
    required String siteAuditSchId,
    required String pvTicketId,
    required String siteCode,
    required String cluster,
    required String operator,
    required String raisedDt,
    required String dueDt,
    required String status,
    required double latitude,
    required double longitude,
    required ActivityTypeEnum activityType
  }) async {

    final apiData = await ServiceLocator().centralApiService.fetchData(
      siteType: siteType,
      auditSchId: auditSchId,
      siteAuditSchId: siteAuditSchId,
      activityType: activityType
    );

    if(apiData == null) {
      return false;
    }
    // Save to SQLite
    final isSaved = await _saveDataToSQLite(
        siteAuditSchId: siteAuditSchId,
        siteType: siteType,
        auditSchId: auditSchId,
        pvTicketId: pvTicketId,
        siteCode: siteCode,
        cluster: cluster,
        operator: operator,
        raisedDt: raisedDt,
        dueDt: dueDt,
        status: status,
        activityType: activityType,

        isDownloaded: true,
        latitude: latitude,
        longitude: longitude,
        apiData: apiData);
    return isSaved;
  }

  /// Save asset audit data to SQLite
  Future<bool> _saveDataToSQLite(
  {
    required String siteType,
    required String auditSchId,
    required String siteAuditSchId,
    required String pvTicketId,
    required String siteCode,
    required String cluster,
    required String operator,
    required String raisedDt,
    required String dueDt,
    required String status,
    required Map<String, dynamic> apiData,
    required bool isDownloaded,
    required double latitude,
    required double longitude,
    required ActivityTypeEnum activityType,
  }) async {
    try {
      Logger.debugLog('💾 Starting to save asset audit data to SQLite');
      Logger.debugLog('💾 API data keys: ${apiData.keys.toList()}');

      // Process images and replace server IDs with unique IDs
      final processedApiData = await _processImagesInApiData(apiData, activityType, siteAuditSchId);

      // Save the processed API response
      bool isSaved = await ServiceLocator().centralAssetAuditDataService.saveRawApiData(
        siteAuditSchId: siteAuditSchId,
        siteType: siteType,
        auditSchId: auditSchId,
        pvTicketId: pvTicketId,
        siteCode: siteCode,
        cluster: cluster,
        operator: operator,
        raisedDt: raisedDt,
        dueDt: dueDt,
        status: status,
        isDownloaded: isDownloaded,
        activityType: activityType,
        latitude: latitude,
        longitude: longitude,
        apiData: processedApiData,
      );

      Logger.debugLog('✅ Raw API data saved successfully to SQLite');
      return isSaved;
    } catch (e) {
      Logger.errorLog('❌ Error saving asset audit data to SQLite: $e');
      return false;
    }
  }

  /// Process images in API data by downloading and replacing server IDs with unique IDs
  Future<Map<String, dynamic>> _processImagesInApiData(Map<String, dynamic> apiData, ActivityTypeEnum activityType, String siteAuditSchId) async {
    try {
      Logger.debugLog('Processing images in API data');
      
      // Create a deep copy of the API data to avoid modifying the original
      final processedData = Map<String, dynamic>.from(apiData);
      
      // Process the entire object recursively
      await _processObjectRecursively(processedData, activityType, siteAuditSchId);
      
      Logger.debugLog('Images processed successfully');
      return processedData;
    } catch (e) {
      Logger.errorLog('Error processing images in API data: $e');
      return apiData; // Return original data if processing fails
    }
  }

  /// Recursively process an object to find and replace image server IDs
  Future<void> _processObjectRecursively(dynamic obj, ActivityTypeEnum activityType, String siteAuditSchId) async {
    if (obj == null) return;
    
    if (obj is Map<String, dynamic>) {
      // Process each key-value pair in the map
      for (final entry in obj.entries) {
        final key = entry.key;
        final value = entry.value;
        
        // Check if this is a photo_id or maker_selfie_image_id field
        if ((key == 'photo_id' || key == 'maker_selfie_image_id' || key == 'ebAttachmentFileId') && value != null) {
          final serverId = value.toString();
          if (serverId.isNotEmpty) {
            Logger.debugLog('🖼️ Found $key: $serverId');
            
            // Download image and get unique ID
            final uniqueId = await _downloadImageAndGetUniqueId(serverId, activityType, siteAuditSchId);
            if (uniqueId != null) {
              // Replace server ID with unique ID
              obj[key] = uniqueId;
              Logger.debugLog('✅ Replaced $key $serverId with unique ID: $uniqueId');
            } else {
              Logger.errorLog('❌ Failed to download image for $key: $serverId');
            }
          }
        } else {
          // Recursively process nested objects
          await _processObjectRecursively(value, activityType, siteAuditSchId);
        }
      }
    } else if (obj is List) {
      // Process each item in the list
      for (final item in obj) {
        await _processObjectRecursively(item, activityType, siteAuditSchId);
      }
    }
  }

  /// Download image using server ID and return unique ID
  Future<String?> _downloadImageAndGetUniqueId(String serverId, ActivityTypeEnum activityType, String schId) async {
    try {
      Logger.debugLog('📥 Downloading image with server ID: $serverId');
      final uniqueId = await ServiceLocator().imageUploadService.downloadImageUsingServerId(serverId, activityType, schId);
      
      if (uniqueId != null) {
        Logger.debugLog('✅ Image downloaded successfully with unique ID: $uniqueId');
        return uniqueId;
      } else {
        Logger.errorLog('❌ Failed to download image with server ID: $serverId');
        return null;
      }
    } catch (e) {
      Logger.errorLog('❌ Error downloading image with server ID $serverId: $e');
      return null;
    }
  }

  /// Update asset audit data in SQLite
  Future<bool> updateDataInSqlite({
    required String siteAuditSchId,
    required Map<String, dynamic> updatedData,
  }) async {
    try {
      Logger.debugLog('🔄 Updating asset audit data for site $siteAuditSchId');
      Logger.debugLog('🔄 Updated data keys: ${updatedData.keys.toList()}');

      // Update the raw API data in SQLite
      await ServiceLocator().centralAssetAuditDataService.updateRawApiData(
        siteAuditSchId: siteAuditSchId,
        apiData: updatedData,
      );
      
      Logger.debugLog('✅ Asset audit data updated successfully');
      return true;
    } catch (e) {
      Logger.errorLog('❌ Error updating asset audit data: $e');
      return false;
    }
  }

  // ==================== IMAGE OPERATIONS ====================

  /// Get image as data URL
  Future<String?> getImageAsDataUrl(String imageId) async {
    try {
      final imageData = await ServiceLocator().imageUploadService.getImageUsingUniqueId(imageId);
      if(imageData != null) {
        return imageData; // Already a base64 string
      }
      return null;
    } catch (e) {
      Logger.errorLog('❌ Error getting image: $e');
      return null;
    }
  }

  /// Upload image
  Future<String?> uploadImage({
    required String siteAuditSchId,
    required File imageFile,
    required ActivityTypeEnum activityType,
    bool isSelfie = false,
  }) async {
    try {
      // Read file as bytes and convert to base64 string
      final imageBytes = await imageFile.readAsBytes();
      final imageData = base64Encode(imageBytes);

      // Upload using ImageUploadService
      return await ServiceLocator().imageUploadService.uploadImage(
          imageData,
          ActivityTypeEnum.assetAudit,
          isSelfie,
          siteAuditSchId
      );
    } catch (e) {
      Logger.errorLog('❌ Error uploading image: $e');
      return null;
    }
  }

  /// Clear all data
  Future<void> clearAllData() async {
    try {
      await ServiceLocator().imageUploadService.clearAllImages();
      await ServiceLocator().centralAssetAuditDataService.clearAllData();
      await ServiceLocator().pendingRequestService.clearAllData();
      Logger.debugLog('✅ All data cleared');
    } catch (e) {
      Logger.errorLog('❌ Error clearing all data: $e');
    }
  }

  /// Drop and recreate all databases with all tables
  Future<void> dropAndRecreateAllDatabases() async {

    try {
      Logger.debugLog('🗑️ Dropping and recreating all databases');
      
      // Drop and recreate both databases
      await Future.wait([
        ServiceLocator().centralAssetAuditDataService.dropAndRecreateDatabase(),
        ServiceLocator().pendingRequestService.dropAndRecreateDatabase(),
        ServiceLocator().imageUploadService.dropAndRecreateDatabase(),
      ]);
      
      Logger.debugLog('✅ All databases dropped and recreated successfully');
    } catch (e) {
      Logger.errorLog('❌ Error dropping and recreating databases: $e');
      rethrow;
    }
  }


  
}
