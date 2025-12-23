import 'dart:convert';
import 'dart:io';
import 'package:app/enum/activity_type_enum.dart';
import 'package:app/models/all_site_model.dart';
import 'package:app/models/sqlite/raw_api_data_model.dart';
import 'package:app/services/service_locator.dart';
import 'package:app/services/local_storage_db.dart';
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
    final sqliteData = await ServiceLocator().centralAssetAuditDataService
        .getRawApiData(siteAuditSchId);
    if (sqliteData != null && sqliteData.isDownloaded) {
      return true;
    }

    final apiData = await ServiceLocator().centralApiService.fetchData(
      siteType: siteType,
      auditSchId: auditSchId,
      siteAuditSchId: siteAuditSchId,
      activityType: activityType,
    );
    if (apiData == null) {
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
      apiData: apiData,
    );

    return isSaved;
  }

  Future<RawApiDataModel?> getDataFromSqlite({
    required String siteAuditSchId,
  }) async {
    final sqliteData = await ServiceLocator().centralAssetAuditDataService
        .getRawApiData(siteAuditSchId);
    if (sqliteData != null) {
      return sqliteData;
    } else {
      return null;
    }
  }

  /// Download CM site data and save to SQLite
  Future<bool> downloadCMSiteData({
    required AllSiteModel site,
    required String siteType,
  }) async {
    try {
      Logger.debugLog(
        'Starting to download CM site data for site: ${site.siteName}',
      );

      // Save to SQLite using the new CM site data service
      bool isSaved = await ServiceLocator().centralAssetAuditDataService
          .saveCMSiteData(
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
            activityType: siteType,
            infraDistrictEngineerName: site.infraEngineerName,
            infraDistrictEngineerContactNo: site.infraEngineerPhone,
            ownerName: site.ownerName,
            ownerContactNo: site.ownerPhone,
          );

      Logger.debugLog('✅ CM site data saved successfully to SQLite: $isSaved');
      return isSaved;
    } catch (e) {
      Logger.errorLog('❌ Error downloading CM site data: $e');
      return false;
    }
  }

  /// Download Site Visit site data and save to SQLite
  Future<bool> downloadSVSiteData({
    required AllSiteModel site,
  }) async {
    try {
      Logger.debugLog(
        'Starting to download Site Visit site data for site: ${site.siteName}',
      );

      // Save to SQLite using the site data service
      bool isSaved = await ServiceLocator().centralAssetAuditDataService
          .saveCMSiteData(
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
            activityType: ActivityTypeEnum.siteVisit.value,
            infraDistrictEngineerName: site.infraEngineerName,
            infraDistrictEngineerContactNo: site.infraEngineerPhone,
            ownerName: site.ownerName,
            ownerContactNo: site.ownerPhone,
          );

      // Note: Sites downloaded from "All Sites" should NOT be saved to raw_api_data table
      // as they are not tickets. They should only appear in sv_sites_data table.
      // The raw_api_data table is reserved for actual tickets downloaded from the Tickets screen.

      Logger.debugLog('✅ Site Visit site data saved successfully to SQLite: $isSaved');
      return isSaved;
    } catch (e) {
      Logger.errorLog('❌ Error downloading Site Visit site data: $e');
      return false;
    }
  }

  /// Download General Inspection site data and save to SQLite
  Future<bool> downloadGISiteData({
    required AllSiteModel site,
  }) async {
    try {
      Logger.debugLog(
        'Starting to download General Inspection site data for site: ${site.siteName}',
      );

      // Save to SQLite using the site data service
      bool isSaved = await ServiceLocator().centralAssetAuditDataService
          .saveCMSiteData(
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
            activityType: ActivityTypeEnum.generalInspection.value,
            infraDistrictEngineerName: site.infraEngineerName,
            infraDistrictEngineerContactNo: site.infraEngineerPhone,
            ownerName: site.ownerName,
            ownerContactNo: site.ownerPhone,
          );

      Logger.debugLog('✅ General Inspection site data saved successfully to SQLite: $isSaved');
      return isSaved;
    } catch (e) {
      Logger.errorLog('❌ Error downloading General Inspection site data: $e');
      return false;
    }
  }

  /// Download General Inspection checklist data and save to SQLite
  Future<bool> downloadGIChecklist({
    required int siteId,
    required String siteCode,
    required String siteName,
    required int siteDomainId,
  }) async {
    try {
      Logger.debugLog(
        'Starting to download General Inspection checklist data for site: $siteName',
      );

      // Get checklist data from API
      final checklistData = await ServiceLocator().generalInspectionRepository
          .getGenInsCheckListData(siteDomainId);

      // Save to SQLite using the central data service
      bool isSaved = await ServiceLocator().centralAssetAuditDataService
          .saveGenInsCheckListData(
            siteId: siteId,
            siteCode: siteCode,
            siteName: siteName,
            checklistData: checklistData,
            activityType: 'generalInspection',
          );

      Logger.debugLog(
        '✅ General Inspection checklist data saved successfully to SQLite: $isSaved',
      );
      return isSaved;
    } catch (e) {
      Logger.errorLog(
        '❌ Error downloading General Inspection checklist data: $e',
      );
      return false;
    }
  }

  /// Download incident site data and save to SQLite
  Future<bool> downloadIncidentSiteData({
    required AllSiteModel site,
  }) async {
    try {
      Logger.debugLog(
        'Starting to download incident site data for site: ${site.siteName}',
      );

      // Save to SQLite using the site data service
      bool isSaved = await ServiceLocator().centralAssetAuditDataService
          .saveCMSiteData(
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
            activityType: ActivityTypeEnum.incident.value,
            infraDistrictEngineerName: site.infraEngineerName,
            infraDistrictEngineerContactNo: site.infraEngineerPhone,
            ownerName: site.ownerName,
            ownerContactNo: site.ownerPhone,
          );

      Logger.debugLog('✅ Incident site data saved successfully to SQLite: $isSaved');
      return isSaved;
    } catch (e) {
      Logger.errorLog('❌ Error downloading incident site data: $e');
      return false;
    }
  }

  /// Download incident checklist data and save to SQLite
  Future<bool> downloadIncidentChecklist({
    required int siteId,
    required String siteCode,
    required String siteName,
  }) async {
    try {
      print('Downloading incident checklist data');
      Logger.debugLog(
        'Starting to download incident checklist data for site: $siteName',
      );

      // Get checklist data from API
      final checklistData = await ServiceLocator().incidentRepository
          .getIncidentChecklist();

      print('Incident checklist data: $checklistData');

      // Save to SQLite using the central data service
      bool isSaved = await ServiceLocator().centralAssetAuditDataService
          .saveIncidentChecklistData(
            siteId: siteId,
            siteCode: siteCode,
            siteName: siteName,
            checklistData: checklistData,
            activityType: 'incident',
          );

      print('Incident checklist data saved: $isSaved');

      Logger.debugLog(
        '✅ Incident checklist data saved successfully to SQLite: $isSaved',
      );
      return isSaved;
    } catch (e, stackTrace) {
      Logger.errorLog('❌ Error downloading incident checklist data: $e');
      Logger.errorLog('❌ Stack trace: $stackTrace');
      print('❌ Error downloading incident checklist data: $e');
      print('❌ Stack trace: $stackTrace');
      return false;
    }
  }

  /// Download CM checklist data and save to SQLite
  Future<bool> downloadCMChecklist({
    required int siteId,
    required int entityId,
    required String siteCode,
    required String siteName,
  }) async {
    try {
      Logger.debugLog(
        'Starting to download CM checklist data for site: $siteName',
      );

      // Get checklist data from API
      final checklistDataRaw = await ServiceLocator().cmRepository
          .getChecklistData(entityId);

      // Convert to the expected format
      final Map<String, List<Map<String, dynamic>>> checklistData = {};
      checklistDataRaw.forEach((key, value) {
        if (value is List) {
          checklistData[key] = List<Map<String, dynamic>>.from(
            value.map((item) => Map<String, dynamic>.from(item)),
          );
        }
      });

      // Save to SQLite using the central data service
      bool isSaved = await ServiceLocator().centralAssetAuditDataService
          .saveCMChecklistData(
            siteId: siteId,
            entityId: entityId,
            siteCode: siteCode,
            siteName: siteName,
            checklistData: checklistData,
            activityType: 'correctiveMaintenance',
          );

      Logger.debugLog(
        '✅ CM checklist data saved successfully to SQLite: $isSaved',
      );
      return isSaved;
    } catch (e) {
      Logger.errorLog('❌ Error downloading CM checklist data: $e');
      return false;
    }
  }

  /// Download CM site data with checklist data
  Future<bool> downloadCMSiteDataWithChecklist({
    required AllSiteModel site,
    required Map<String, dynamic> checklistData,
  }) async {
    try {
      Logger.debugLog(
        'Starting to download CM site data with checklist for site: ${site.siteName}',
      );

      // Save to SQLite using the new CM site data with checklist service
      bool isSaved = await ServiceLocator().centralAssetAuditDataService
          .saveCMSiteDataWithChecklist(
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
            checklistData: checklistData,
            infraDistrictEngineerName: site.infraEngineerName,
            infraDistrictEngineerContactNo: site.infraEngineerPhone,
            ownerName: site.ownerName,
            ownerContactNo: site.ownerPhone,
          );

      Logger.debugLog(
        '✅ CM site data with checklist saved successfully to SQLite: $isSaved',
      );
      return isSaved;
    } catch (e) {
      Logger.errorLog('❌ Error downloading CM site data with checklist: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>?> getActualDataFromSqlite({
    required String siteAuditSchId,
  }) async {
    final sqliteData = await ServiceLocator().centralAssetAuditDataService
        .getRawApiData(siteAuditSchId);
    if (sqliteData != null) {
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
    required ActivityTypeEnum activityType,
  }) async {
    final apiData = await ServiceLocator().centralApiService.fetchData(
      siteType: siteType,
      auditSchId: auditSchId,
      siteAuditSchId: siteAuditSchId,
      activityType: activityType,
    );

    if (apiData == null) {
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
      apiData: apiData,
    );

    // For General Inspection, also download checklist data
    if (isSaved && activityType == ActivityTypeEnum.generalInspection) {
      try {
        final ticketSchId = int.tryParse(siteAuditSchId) ?? 0;
        final giChecklistDownloaded = await downloadGIChecklist(
          siteId: ticketSchId,
          siteCode: siteCode,
          siteName: cluster,
          siteDomainId: 1, // Default site domain ID for GI
        );

        if (giChecklistDownloaded) {
          Logger.debugLog('✅ GI checklist data downloaded successfully');
        } else {
          Logger.errorLog('❌ Failed to download GI checklist data');
        }
      } catch (e) {
        Logger.errorLog('❌ Error downloading GI checklist: $e');
      }
    }

    return isSaved;
  }

  /// Save asset audit data to SQLite
  Future<bool> _saveDataToSQLite({
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
      final processedApiData = await _processImagesInApiData(
        apiData,
        activityType,
        siteAuditSchId,
      );

      // Save the processed API response
      bool isSaved = await ServiceLocator().centralAssetAuditDataService
          .saveRawApiData(
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
  Future<Map<String, dynamic>> _processImagesInApiData(
    Map<String, dynamic> apiData,
    ActivityTypeEnum activityType,
    String siteAuditSchId,
  ) async {
    try {
      Logger.debugLog('Processing images in API data');

      // Create a deep copy of the API data to avoid modifying the original
      final processedData = Map<String, dynamic>.from(apiData);

      // Process the entire object recursively
      await _processObjectRecursively(
        processedData,
        activityType,
        siteAuditSchId,
      );

      Logger.debugLog('Images processed successfully');
      return processedData;
    } catch (e) {
      Logger.errorLog('Error processing images in API data: $e');
      return apiData; // Return original data if processing fails
    }
  }

  /// Recursively process an object to find and replace image server IDs
  Future<void> _processObjectRecursively(
    dynamic obj,
    ActivityTypeEnum activityType,
    String siteAuditSchId,
  ) async {
    if (obj == null) return;

    if (obj is Map<String, dynamic>) {
      // Process each key-value pair in the map
      for (final entry in obj.entries) {
        final key = entry.key;
        final value = entry.value;

        // Check if this is a photo_id or maker_selfie_image_id field
        if ((key == 'photo_id' ||
                key == 'maker_selfie_image_id' ||
                key == 'ebAttachmentFileId' ||
                key == 'visitingPersonImageId' ||
                key == 'visiting_person_image_id' ||
                key == 'officialIdImageId' ||
                key == 'official_id_image_id' ||
                key == 'aadharCardImageId' ||
                key == 'aadhar_card_image_id' ||
                key == 'leavingStatusImageId' ||
                key == 'leaving_status_image_id' ||
                key == 'respPhotoId') &&
            value != null) {
          final serverId = value.toString();
          if (serverId.isNotEmpty) {
            Logger.debugLog('🖼️ Found $key: $serverId');

            // Download image and get unique ID
            final uniqueId = await _downloadImageAndGetUniqueId(
              serverId,
              activityType,
              siteAuditSchId,
            );
            if (uniqueId != null) {
              // Replace server ID with unique ID
              obj[key] = uniqueId;
              Logger.debugLog(
                '✅ Replaced $key $serverId with unique ID: $uniqueId',
              );
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
  Future<String?> _downloadImageAndGetUniqueId(
    String serverId,
    ActivityTypeEnum activityType,
    String schId,
  ) async {
    try {
      Logger.debugLog('📥 Downloading image with server ID: $serverId');
      final uniqueId = await ServiceLocator().imageUploadService
          .downloadImageUsingServerId(serverId, activityType, schId);

      if (uniqueId != null) {
        Logger.debugLog(
          '✅ Image downloaded successfully with unique ID: $uniqueId',
        );
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
      final imageData = await ServiceLocator().imageUploadService
          .getImageUsingUniqueId(imageId);
      if (imageData != null) {
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
        siteAuditSchId,
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
      
      // Clear offline tickets from LocalStorage
      await _clearAllOfflineTickets();
      
      Logger.debugLog('✅ All data cleared');
    } catch (e) {
      Logger.errorLog('❌ Error clearing all data: $e');
    }
  }

  /// Clear all offline tickets from LocalStorage
  Future<void> _clearAllOfflineTickets() async {
    try {
      final offlineTickets = LocalStorageDB.getAllOfflineTickets();
      for (final ticket in offlineTickets) {
        final siteAuditSchId = ticket['siteAuditSchId']?.toString();
        if (siteAuditSchId != null) {
          await LocalStorageDB.deleteOfflineTicket(siteAuditSchId);
        }
      }
      Logger.debugLog('✅ All offline tickets cleared from LocalStorage');
    } catch (e) {
      Logger.errorLog('❌ Error clearing offline tickets: $e');
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
