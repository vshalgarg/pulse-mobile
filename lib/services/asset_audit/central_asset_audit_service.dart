import 'dart:convert';
import 'dart:io';
import 'package:app/enum/activity_type_enum.dart';
import 'package:app/models/all_site_model.dart';
import 'package:app/models/cm_site_model.dart';
import 'package:app/models/pmis_activity_ticket_model.dart';
import 'package:app/models/sqlite/raw_api_data_model.dart';
import 'package:app/services/service_locator.dart';
import 'package:app/services/local_storage_db.dart';
import 'package:app/repositories/asset_upload_respository.dart';
import '../../utils/logger.dart';
import '../../utils/image_compression_helper.dart';
import '../../utils/map_api_field_reader.dart';

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

  /// Download CM site data and save to SQLite.
  /// [entityIdOverride] When set (e.g. for CM), use as entity_id so offline open from My Tickets finds checklist.
  Future<bool> downloadCMSiteData({
    required AllSiteModel site,
    required String siteType,
    int? entityIdOverride,
  }) async {
    try {
      Logger.debugLog(
        'Starting to download CM site data for site: ${site.siteName}',
      );

      final entityId = entityIdOverride ?? site.entityId;

      // Save to SQLite using the new CM site data service
      bool isSaved = await ServiceLocator().centralAssetAuditDataService
          .saveCMSiteData(
            siteId: site.siteId,
            entityId: entityId,
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
            clusterInchargeName: site.clusterInchargeName,
            clusterInchargeContactNo: site.clusterInchargeContactNo,
            latitude: site.latitude,
            longitude: site.longitude,
          );

      Logger.debugLog('✅ CM site data saved successfully to SQLite: $isSaved');
      return isSaved;
    } catch (e) {
      Logger.errorLog('❌ Error downloading CM site data: $e');
      return false;
    }
  }

  /// Download Site Visit site data and save to SQLite.
  /// Stores the same data as in online mode (site from list + organisationList) to raw_api_data
  /// so the organisation dropdown works when opening from My Tickets in offline mode.
  /// Does NOT call /api/v1/om-schedule/siteVisitLog — only fetches organisation list.
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
            clusterInchargeName: site.clusterInchargeName,
            clusterInchargeContactNo: site.clusterInchargeContactNo,
            latitude: site.latitude,
            longitude: site.longitude,
          );

      // Build payload with same data as online mode (site from list + organisationList).
      // Do NOT call siteVisitLog API — only fetch organisation list.
      final Map<String, dynamic> apiData = {
        'siteId': site.siteId,
        'siteCode': site.siteCode,
        'siteName': site.siteName,
        'cluster': site.clusterDistrictName,
        'circle': site.circleStateName,
        'client': site.clientName,
        'infraDistrictEngineerName': site.infraEngineerName,
        'infraDistrictEngineerContactNo': site.infraEngineerPhone,
        'ownerName': site.ownerName,
        'ownerContactNo': site.ownerPhone,
        'orgId': site.orgId,
        'organisationName': site.organisationName,
      };

      try {
        final organisationList = await ServiceLocator()
            .sitesRepository
            .getOrganisationList();
        if (organisationList.isNotEmpty) {
          apiData['organisationList'] = organisationList;
          Logger.debugLog(
            '✅ Organisation list fetched and added to payload (${organisationList.length} items)',
          );
        }
      } catch (e) {
        Logger.debugLog('⚠️ Could not fetch organisation list: $e');
      }

      if (apiData.isNotEmpty) {
        try {
          final lat = site.latitude != null
              ? double.tryParse(site.latitude!) ?? 0.0
              : 0.0;
          final lng = site.longitude != null
              ? double.tryParse(site.longitude!) ?? 0.0
              : 0.0;
          await ServiceLocator().centralAssetAuditDataService.saveRawApiData(
            siteAuditSchId: site.siteId.toString(),
            siteType: site.siteDomainName ?? 'Solar',
            auditSchId: '',
            pvTicketId: site.siteCode,
            siteCode: site.siteCode,
            cluster: site.clusterDistrictName,
            operator: site.clientName ?? '',
            raisedDt: '',
            dueDt: '',
            status: 'Site',
            isDownloaded: true,
            activityType: ActivityTypeEnum.siteVisit,
            latitude: lat,
            longitude: lng,
            apiData: apiData,
          );
          Logger.debugLog(
            '✅ Site Visit API data (with organisationList) saved to raw_api_data',
          );
        } catch (e) {
          Logger.debugLog(
            '⚠️ Could not save Site Visit data to raw_api_data: $e',
          );
        }
      }

      Logger.debugLog(
          '✅ Site Visit site data saved successfully to SQLite: $isSaved');
      return isSaved;
    } catch (e) {
      Logger.errorLog('❌ Error downloading Site Visit site data: $e');
      return false;
    }
  }

  /// Download Asset Upload site data and save to SQLite
  Future<bool> downloadAssetUploadSiteData({
    required AllSiteModel site,
  }) async {
    try {
      Logger.debugLog(
        'Starting to download Asset Upload site data for site: ${site.siteName}',
      );

      // Save basic site data to SQLite using the site data service
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
            activityType: ActivityTypeEnum.assetUpload.value,
            infraDistrictEngineerName: site.infraEngineerName,
            infraDistrictEngineerContactNo: site.infraEngineerPhone,
            ownerName: site.ownerName,
            ownerContactNo: site.ownerPhone,
            clusterInchargeName: site.clusterInchargeName,
            clusterInchargeContactNo: site.clusterInchargeContactNo,
            latitude: site.latitude,
            longitude: site.longitude,
          );

      if (!isSaved) {
        Logger.errorLog('❌ Failed to save basic site data');
        return false;
      }

      // Also fetch and save Asset Upload API data to raw_api_data table
      // This is needed so the data can be retrieved when clicking on tickets in My Tickets
      try {
        Logger.debugLog('📥 Fetching Asset Upload API data for site ${site.siteId}');
        final repository = AssetUploadRepository(ServiceLocator().apiService);
        final result = await repository.getUploadedAssets(siteId: site.siteId);
        
        if (result.isSuccess && result.data != null) {
          // Parse response structure - check if data is wrapped or direct
          Map<String, dynamic>? responseData;
          if (result.data!.containsKey('data')) {
            responseData = result.data!['data'] as Map<String, dynamic>?;
            Logger.debugLog('📦 Found data wrapper, extracting inner data');
          } else {
            responseData = result.data;
            Logger.debugLog('📦 Using data directly (no wrapper)');
          }

          if (responseData != null) {
            // Process images in API data (download and replace server IDs with unique IDs)
            Logger.debugLog('🖼️ Processing images in Asset Upload API data...');
            final processedApiData = await processImagesInApiData(
              responseData,
              ActivityTypeEnum.assetUpload,
              site.siteId.toString(),
            );

            // Ensure total_asset_cnt is set for My Tickets display
            final au = processedApiData['assetUpload'] ?? processedApiData['asset_upload'];
            final items = (au is Map ? (au['asset_upload_item'] ?? au['assetUploadItem']) : null) as List? ?? [];
            if (processedApiData['total_asset_cnt'] == null) {
              processedApiData['total_asset_cnt'] = items.length;
            }
            processedApiData['site_id'] = site.siteId;

            // Save to raw_api_data table so it can be retrieved later
            final apiDataSaved = await ServiceLocator()
                .centralAssetAuditDataService
                .saveRawApiData(
                  siteAuditSchId: site.siteId.toString(),
                  siteType: site.siteDomainName ?? 'Solar',
                  auditSchId: '',
                  pvTicketId: '',
                  siteCode: site.siteCode,
                  cluster: site.clusterDistrictName,
                  operator: site.clientName ?? '',
                  raisedDt: '',
                  dueDt: '',
                  status: '',
                  isDownloaded: true,
                  activityType: ActivityTypeEnum.assetUpload,
                  latitude: site.latitude != null ? double.tryParse(site.latitude!) ?? 0 : 0,
                  longitude: site.longitude != null ? double.tryParse(site.longitude!) ?? 0 : 0,
                  apiData: processedApiData,
                );
            
            if (apiDataSaved) {
              Logger.debugLog('✅ Asset Upload API data saved to raw_api_data table');
            } else {
              Logger.errorLog('⚠️ Failed to save Asset Upload API data to raw_api_data table');
            }
          } else {
            Logger.errorLog('⚠️ Asset Upload API response data is null');
          }
        } else {
          Logger.debugLog('⚠️ Failed to fetch Asset Upload API data: ${result.errorMessage}');
          // Continue anyway - basic site data was saved successfully
        }
      } catch (e) {
        Logger.errorLog('❌ Error fetching/saving Asset Upload API data: $e');
        // Continue anyway - basic site data was saved successfully
      }

      Logger.debugLog('✅ Asset Upload site data saved successfully to SQLite');
      return isSaved;
    } catch (e) {
      Logger.errorLog('❌ Error downloading Asset Upload site data: $e');
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
            clusterInchargeName: site.clusterInchargeName,
            clusterInchargeContactNo: site.clusterInchargeContactNo,
            latitude: site.latitude,
            longitude: site.longitude,
            installedAssetDetails: site.installedAssetDetails,
            lastPMDate: site.lastPMDate,
            lastCMDate: site.lastCMDate,
            lastAADate: site.lastAADate,
            lastPMSiteAuditSchId: site.lastPMSiteAuditSchId,
            lastPMAuditSchId: site.lastPMAuditSchId,
            lastCMSiteReqId: site.lastCMSiteReqId,
            lastAASiteAuditSchId: site.lastAASiteAuditSchId,
            lastAAAuditSchId: site.lastAAAuditSchId,
            offlineSiteSnapshotJson: jsonEncode(site.toJson()),
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
            clusterInchargeName: site.clusterInchargeName,
            clusterInchargeContactNo: site.clusterInchargeContactNo,
            latitude: site.latitude,
            longitude: site.longitude,
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
     
      Logger.debugLog(
        'Starting to download incident checklist data for site: $siteName',
      );

      // Get checklist data from API
      final checklistData = await ServiceLocator().incidentRepository
          .getIncidentChecklist();

 

      // Save to SQLite using the central data service
      bool isSaved = await ServiceLocator().centralAssetAuditDataService
          .saveIncidentChecklistData(
            siteId: siteId,
            siteCode: siteCode,
            siteName: siteName,
            checklistData: checklistData,
            activityType: 'incident',
          );

      

      Logger.debugLog(
        '✅ Incident checklist data saved successfully to SQLite: $isSaved',
      );
      return isSaved;
    } catch (e, stackTrace) {
      Logger.errorLog('❌ Error downloading incident checklist data: $e');
      Logger.errorLog('❌ Stack trace: $stackTrace');
      
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

      // Get checklist data from API (returns { checkListDetails: { DG: [...], ... }, siteDeployedItems: {...} })
      final checklistDataRaw = await ServiceLocator().cmRepository
          .getChecklistData(entityId);

      final Map<String, List<Map<String, dynamic>>> checklistData = {};
      final checkListDetails = checklistDataRaw['checkListDetails'] as Map<String, dynamic>?;
      if (checkListDetails != null) {
        checkListDetails.forEach((key, value) {
          if (value is List) {
            checklistData[key] = List<Map<String, dynamic>>.from(
              value.map((item) => Map<String, dynamic>.from(item)),
            );
          }
        });
      }

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

    var dataToSave = apiData;
    if (activityType == ActivityTypeEnum.correctiveMaintenance) {
      dataToSave = await _enrichCmTicketApiDataWithSiteContacts(
        apiData,
        siteAuditSchId: siteAuditSchId,
      );
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
      apiData: dataToSave,
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

    // For Incident, also download checklist data
    if (isSaved && activityType == ActivityTypeEnum.incident) {
      try {
        final ticketSchId = int.tryParse(siteAuditSchId) ?? 0;
        final incidentChecklistDownloaded = await downloadIncidentChecklist(
          siteId: ticketSchId,
          siteCode: siteCode,
          siteName: cluster,
        );

        if (incidentChecklistDownloaded) {
          Logger.debugLog('✅ Incident checklist data downloaded successfully');
        } else {
          Logger.errorLog('❌ Failed to download Incident checklist data');
        }
      } catch (e) {
        Logger.errorLog('❌ Error downloading Incident checklist: $e');
      }
    }

    // For CM tickets, also download checklist master so offline edit/view can merge responses.
    if (isSaved && activityType == ActivityTypeEnum.correctiveMaintenance) {
      try {
        final flat = mergeNestedSiteMapsIntoIncidentTicket(
          unwrapTicketDataMap(dataToSave),
        );
        final siteId = resolveCmPhysicalSiteId(flat);
        final entityId = _readIntFromApiData(flat, [
              'entityId',
              'entity_id',
              'cmSiteReqId',
              'cm_site_req_id',
            ]) ??
            int.tryParse(siteAuditSchId) ??
            0;
        if (siteId > 0 && entityId > 0) {
          final cmChecklistDownloaded = await downloadCMChecklist(
            siteId: siteId,
            entityId: entityId,
            siteCode: siteCode,
            siteName: cluster,
          );
          if (cmChecklistDownloaded) {
            Logger.debugLog('✅ CM checklist data downloaded successfully');
          } else {
            Logger.errorLog('❌ Failed to download CM checklist data');
          }
        }
      } catch (e) {
        Logger.errorLog('❌ Error downloading CM checklist: $e');
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
      final processedApiData = await processImagesInApiData(
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
  /// This is a public method that can be called from other parts of the app
  Future<Map<String, dynamic>> processImagesInApiData(
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

        // Special handling for response_images array (PM data structure)
        if ((key == 'response_images' ||
                key == 'responseImages' ||
                key == 'cmCheckListSiteRespImagesList' ||
                key == 'cm_check_list_site_resp_images_list' ||
                key == 'CmCheckListSiteRespImagesList') &&
            value is List) {
          Logger.debugLog('🖼️ Found $key array, processing ${value.length} images');
          for (var i = 0; i < value.length; i++) {
            final imageItem = value[i];
            if (imageItem is Map<String, dynamic>) {
              final photoId = imageItem['photo_id'] ?? imageItem['photoId'];
              if (photoId != null) {
                final serverId = photoId.toString();
                if (serverId.isNotEmpty &&
                    serverId != "0" &&
                    serverId != "null" &&
                    !serverId.startsWith('LOCAL_IMAGE_ID')) {
                  Logger.debugLog('🖼️ Found photo id in $key[$i]: $serverId');

                  final uniqueId = await _downloadImageAndGetUniqueId(
                    serverId,
                    activityType,
                    siteAuditSchId,
                  );
                  if (uniqueId != null) {
                    imageItem['photo_id'] = uniqueId;
                    imageItem['photoId'] = uniqueId;
                    Logger.debugLog(
                      '✅ Replaced $key[$i] photo id $serverId with unique ID: $uniqueId',
                    );
                  } else {
                    Logger.errorLog('❌ Failed to download image for $key[$i]: $serverId');
                  }
                }
              }
            }
          }
        }
        // Special handling for asset_upload_item_images array (Asset Upload data structure)
        else if ((key == 'asset_upload_item_images' || key == 'assetUploadItemImages') && value is List) {
          Logger.debugLog('🖼️ Found asset_upload_item_images array, processing ${value.length} images');
          for (var i = 0; i < value.length; i++) {
            final imageItem = value[i];
            if (imageItem is Map<String, dynamic>) {
              final photoId = imageItem['photo_id'] ?? imageItem['photoId'];
              if (photoId != null) {
                final serverId = photoId.toString();
                // Skip if serverId is empty, "0", "null", or contains "LOCAL_IMAGE_ID"
                if (serverId.isNotEmpty && 
                    serverId != "0" && 
                    serverId != "null" &&
                    !serverId.contains("LOCAL_IMAGE_ID")) {
                  Logger.debugLog('🖼️ Found photo_id in asset_upload_item_images[$i]: $serverId');

                  // Download image and get unique ID
                  final uniqueId = await _downloadImageAndGetUniqueId(
                    serverId,
                    activityType,
                    siteAuditSchId,
                  );
                  if (uniqueId != null) {
                    // Replace server ID with unique ID in the asset_upload_item_images array
                    imageItem['photo_id'] = uniqueId;
                    imageItem['photoId'] = uniqueId;
                    Logger.debugLog(
                      '✅ Replaced asset_upload_item_images[$i] photo_id $serverId with unique ID: $uniqueId',
                    );
                  } else {
                    Logger.errorLog('❌ Failed to download image for asset_upload_item_images[$i]: $serverId');
                  }
                }
              }
            }
          }
        }
        // Check if this is a photo_id or maker_selfie_image_id field
        else if ((key == 'photo_id' ||
                key == 'photoId' ||
                key == 'maker_selfie_image_id' ||
                key == 'makerSelfieImageId' ||
                key == 'ebAttachmentFileId' ||
                key == 'visitingPersonImageId' ||
                key == 'visiting_person_image_id' ||
                key == 'officialIdImageId' ||
                key == 'official_id_image_id' ||
                key == 'aadharCardImageId' ||
                key == 'aadhar_card_image_id' ||
                key == 'leavingStatusImageId' ||
                key == 'leaving_status_image_id' ||
                key == 'respPhotoId' ||
                key == 'incidentImgId' ||
                key == 'identificationImgId' ||
                key == 'identification_img_id' ||
                key == 'timestampImgId' ||
                key == 'timestamp_img_id' ||
                key == 'fsrAttachmentId' ||
                key == 'fsr_attachment_id' ||
                key == 'customerPhotoId' ||
                key == 'customer_photo_id') &&
            value != null) {
          final serverId = value.toString();
          if (serverId.isNotEmpty &&
              serverId != "0" &&
              serverId != "null" &&
              !serverId.startsWith('LOCAL_IMAGE_ID')) {
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

  /// Reads ticket/workflow status from saved asset audit JSON
  /// (`pageHeader[0].status`). Used to keep `raw_api_data.status` in sync for My Tickets.
  static String? statusFromAssetAuditApiData(Map<String, dynamic> data) {
    try {
      final ph = data['pageHeader'];
      if (ph is! List || ph.isEmpty) return null;
      final first = ph.first;
      if (first is! Map) return null;
      final s = first['status']?.toString().trim();
      if (s == null || s.isEmpty || s.toUpperCase() == 'N/A') return null;
      return s;
    } catch (_) {
      return null;
    }
  }

  /// Reads incident ticket status from cached GET payload (`data.status` or root `status`).
  static String? statusFromIncidentApiData(Map<String, dynamic> data) {
    try {
      final inner = data['data'];
      if (inner is Map) {
        final s = inner['status']?.toString().trim();
        if (s != null && s.isNotEmpty && s.toUpperCase() != 'N/A') {
          return s;
        }
      }
      final top = data['status']?.toString().trim();
      if (top != null && top.isNotEmpty && top.toUpperCase() != 'N/A') {
        return top;
      }
    } catch (_) {}
    return null;
  }

  /// After incident POST (online or offline sync), updates [raw_api_data] `status` and
  /// nested `api_data.data.status` so My Tickets matches the detail screen.
  Future<void> syncIncidentTicketLocalRow({
    required int incidentTicketId,
    required String status,
  }) async {
    if (incidentTicketId <= 0) return;
    final siteAuditSchId = incidentTicketId.toString();
    final trimmed = status.trim();
    if (trimmed.isEmpty) return;

    try {
      final dataService = ServiceLocator().centralAssetAuditDataService;
      await dataService.updateRawApiDataStatus(
        siteAuditSchId: siteAuditSchId,
        status: trimmed,
      );
      final raw = await dataService.getRawApiData(siteAuditSchId);
      if (raw == null) return;

      final api = Map<String, dynamic>.from(raw.apiData);
      final inner = api['data'];
      if (inner is Map) {
        final m = Map<String, dynamic>.from(inner);
        m['status'] = trimmed;
        api['data'] = m;
      } else {
        api['status'] = trimmed;
      }
      await dataService.updateRawApiData(
        siteAuditSchId: siteAuditSchId,
        apiData: api,
      );
      Logger.debugLog(
        '✅ Incident local cache: status=$trimmed for site_audit_sch_id=$siteAuditSchId',
      );
    } catch (e) {
      Logger.errorLog('❌ syncIncidentTicketLocalRow: $e');
    }
  }

  /// Merges the offline pending POST body into stored GET-shaped `api_data` so reopening
  /// from My Tickets shows remarks, checklist, image id, etc. before sync.
  /// Does not update the `raw_api_data.status` column ([syncIncidentTicketLocalRow] does after sync).
  Future<void> mergeIncidentPendingPayloadIntoStoredApiData({
    required int incidentTicketId,
    required Map<String, dynamic> pendingRequestMap,
  }) async {
    if (incidentTicketId <= 0) return;
    final siteAuditSchId = incidentTicketId.toString();

    try {
      final dataService = ServiceLocator().centralAssetAuditDataService;
      final raw = await dataService.getRawApiData(siteAuditSchId);
      if (raw == null) {
        Logger.debugLog(
          'mergeIncidentPendingPayload: no raw row for $siteAuditSchId',
        );
        return;
      }

      final api = Map<String, dynamic>.from(raw.apiData);
      final inner = api['data'];
      final Map<String, dynamic> dataMap = inner is Map
          ? Map<String, dynamic>.from(inner)
          : <String, dynamic>{};

      pendingRequestMap.forEach((key, value) {
        if (value == null) return;
        dataMap[key] = value;
      });

      api['data'] = dataMap;
      await dataService.updateRawApiData(
        siteAuditSchId: siteAuditSchId,
        apiData: api,
      );
      Logger.debugLog(
        '✅ Merged incident offline draft into api_data for $siteAuditSchId',
      );
    } catch (e) {
      Logger.errorLog('❌ mergeIncidentPendingPayloadIntoStoredApiData: $e');
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

      final updated = await ServiceLocator().centralAssetAuditDataService
          .updateRawApiData(
        siteAuditSchId: siteAuditSchId,
        apiData: updatedData,
      );

      if (updated) {
        final status = statusFromAssetAuditApiData(updatedData);
        if (status != null) {
          await ServiceLocator().centralAssetAuditDataService
              .updateRawApiDataStatus(
            siteAuditSchId: siteAuditSchId,
            status: status,
          );
          Logger.debugLog(
            '✅ Synced raw_api_data.status ($status) for My Tickets',
          );
        }
      }

      if (updated) {
        Logger.debugLog('✅ Asset audit data updated successfully');
      }
      return updated;
    } catch (e) {
      Logger.errorLog('❌ Error updating asset audit data: $e');
      return false;
    }
  }

  // ==================== IMAGE OPERATIONS ====================

  /// Get image as data URL
  Future<String?> getImageAsDataUrl(String imageId) async {
    try {
      Logger.debugLog('🖼️ getImageAsDataUrl called with imageId: $imageId');
      final imageData = await ServiceLocator().imageUploadService
          .getImageUsingUniqueId(imageId);
      if (imageData != null) {
        Logger.debugLog('🖼️ getImageAsDataUrl: Found image data, length: ${imageData.length}');
        return imageData; // Already a base64 string
      }
      Logger.debugLog('🖼️ getImageAsDataUrl: No image data found for imageId: $imageId');
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
      // Avoid loading multi‑100MB files into a single base64 string (Dart OOM).
      // Compress first when large; native pickImage limits also reduce size at source.
      File fileToRead = imageFile;
      final fileLen = await imageFile.length();
      if (fileLen > 3 * 1024 * 1024) {
        final compressed =
            await ImageCompressionHelper.compressImageTo2MB(imageFile);
        if (compressed != null) {
          fileToRead = compressed;
        }
      }
      // Upload using persisted file path to reduce runtime memory pressure.
      return await ServiceLocator().imageUploadService.uploadImageFromFilePath(
        fileToRead.path,
        activityType,
        isSelfie,
        siteAuditSchId,
      );
    } catch (e) {
      Logger.errorLog('❌ Error uploading image: $e');
      return null;
    }
  }

  /// Deep-copy PMIS activity ticket JSON, download each document via
  /// [ImageUploadService.downloadPmisDocumentByServerId], replace server ids with
  /// `LOCAL_IMAGE_ID_*` (same offline pattern as [processImagesInApiData] for SV).
  Future<Map<String, dynamic>> processPmisActivityTicketDocuments(
    Map<String, dynamic> apiData,
    String siteAuditSchId,
  ) async {
    final processed = Map<String, dynamic>.from(
      jsonDecode(jsonEncode(apiData)) as Map,
    );
    await _processPmisTicketJsonForDocuments(processed, siteAuditSchId);
    return processed;
  }

  Future<void> _replacePmisAttachmentId(
    Map<String, dynamic> att,
    String schId,
  ) async {
    final sid = pmisAttachmentIdString(att);
    if (sid == null) return;
    if (sid.contains('LOCAL_IMAGE_ID')) return;
    final id = int.tryParse(sid);
    if (id == null || id <= 0) return;

    final unique = await ServiceLocator().imageUploadService
        .downloadPmisDocumentByServerId(
      sid,
      ActivityTypeEnum.activityTicket,
      schId,
    );
    if (unique != null) {
      att['pmisOfflineServerDocumentId'] = sid;
      att['attachmentId'] = unique;
    }
  }

  Future<void> _processPmisFieldValueMap(
    Map<String, dynamic> fieldMap,
    String schId,
  ) async {
    final type =
        (fieldMap['subActivityDataType'] ?? '').toString().trim().toUpperCase();
    if (type != 'IMAGE' && type != 'VIDEO' && type != 'PDF') return;

    final atts = fieldMap['attachments'];
    if (atts is List) {
      for (var i = 0; i < atts.length; i++) {
        final e = atts[i];
        if (e is! Map) continue;
        final m = Map<String, dynamic>.from(e);
        await _replacePmisAttachmentId(m, schId);
        atts[i] = m;
      }
    }

    final vt = fieldMap['valText']?.toString().trim() ?? '';
    if (vt.isNotEmpty) {
      final parts = vt.split(',');
      final out = <String>[];
      for (final p in parts) {
        final trimmed = p.trim();
        if (trimmed.isEmpty) continue;
        if (trimmed.contains('LOCAL_IMAGE_ID')) {
          out.add(trimmed);
          continue;
        }
        final nid = int.tryParse(trimmed);
        if (nid != null && nid > 0) {
          final unique = await ServiceLocator().imageUploadService
              .downloadPmisDocumentByServerId(
            trimmed,
            ActivityTypeEnum.activityTicket,
            schId,
          );
          out.add(unique ?? trimmed);
        } else {
          out.add(trimmed);
        }
      }
      fieldMap['valText'] = out.join(',');
    }
  }

  Future<void> _processPmisTicketJsonForDocuments(
    Map<String, dynamic> body,
    String schId,
  ) async {
    final tvs = body['ticketFieldValues'];
    if (tvs is List) {
      for (var i = 0; i < tvs.length; i++) {
        final e = tvs[i];
        if (e is! Map) continue;
        final m = Map<String, dynamic>.from(e);
        await _processPmisFieldValueMap(m, schId);
        tvs[i] = m;
      }
    }

    final oldData = body['oldData'];
    if (oldData is List) {
      for (final item in oldData) {
        if (item is! Map) continue;
        final inner = item['ticketFieldValues'];
        if (inner is List) {
          for (var j = 0; j < inner.length; j++) {
            final e = inner[j];
            if (e is! Map) continue;
            final m = Map<String, dynamic>.from(e);
            await _processPmisFieldValueMap(m, schId);
            inner[j] = m;
          }
        }
      }
    } else if (oldData is Map) {
      final inner = oldData['ticketFieldValues'];
      if (inner is List) {
        for (var j = 0; j < inner.length; j++) {
          final e = inner[j];
          if (e is! Map) continue;
          final m = Map<String, dynamic>.from(e);
          await _processPmisFieldValueMap(m, schId);
          inner[j] = m;
        }
      }
    }

    final topAtt = body['ticketAttachments'];
    if (topAtt is List) {
      for (var i = 0; i < topAtt.length; i++) {
        final e = topAtt[i];
        if (e is! Map) continue;
        final m = Map<String, dynamic>.from(e);
        await _replacePmisAttachmentId(m, schId);
        topAtt[i] = m;
      }
    }
  }

  /// Saves PMIS activity ticket to [raw_api_data] with [ActivityTypeEnum.activityTicket]
  /// (`AI`), keyed by [activityTicketId] — same offline model as SV ticket download.
  Future<bool> downloadAndSavePmisActivityTicketOffline({
    required Map<String, dynamic> ticketJsonBody,
    required int activityTicketId,
    required String siteName,
    required String moduleName,
    required String subModuleName,
    required String activityName,
    required String state,
    required String activityStatus,
    required String approvalStatus,
    String? plannedStartDt,
    String? plannedEndDt,
    String? actualStartDt,
    String? actualEndDt,
    required double latitude,
    required double longitude,
    String siteType = 'Solar',
  }) async {
    try {
      final schId = activityTicketId.toString();
      final enrichedBody = Map<String, dynamic>.from(ticketJsonBody);
      enrichedBody['at_id'] = enrichedBody['at_id'] ?? activityTicketId;
      enrichedBody['site_name'] = enrichedBody['site_name'] ?? siteName;
      enrichedBody['module_name'] = enrichedBody['module_name'] ?? moduleName;
      enrichedBody['sub_module_name'] =
          enrichedBody['sub_module_name'] ?? subModuleName;
      enrichedBody['activity_name'] = enrichedBody['activity_name'] ?? activityName;
      enrichedBody['state'] = enrichedBody['state'] ?? state;
      enrichedBody['activity_status'] =
          enrichedBody['activity_status'] ?? activityStatus;
      enrichedBody['approval_status'] =
          enrichedBody['approval_status'] ?? approvalStatus;
      enrichedBody['planned_start_dt'] =
          enrichedBody['planned_start_dt'] ?? plannedStartDt;
      enrichedBody['planned_end_dt'] = enrichedBody['planned_end_dt'] ?? plannedEndDt;
      enrichedBody['actual_start_dt'] = enrichedBody['actual_start_dt'] ?? actualStartDt;
      enrichedBody['actual_end_dt'] = enrichedBody['actual_end_dt'] ?? actualEndDt;
      enrichedBody['latitude'] = enrichedBody['latitude'] ?? latitude;
      enrichedBody['longitude'] = enrichedBody['longitude'] ?? longitude;

      final processed =
          await processPmisActivityTicketDocuments(enrichedBody, schId);
      return await ServiceLocator().centralAssetAuditDataService.saveRawApiData(
        siteAuditSchId: schId,
        siteType: siteType,
        auditSchId: '',
        pvTicketId: 'PMIS-$activityTicketId',
        siteCode: siteName,
        cluster: siteName,
        operator: moduleName,
        raisedDt: '',
        dueDt: '',
        status: activityStatus,
        activityType: ActivityTypeEnum.activityTicket,
        isDownloaded: true,
        latitude: latitude,
        longitude: longitude,
        apiData: processed,
      );
    } catch (e, st) {
      Logger.errorLog('❌ downloadAndSavePmisActivityTicketOffline: $e\n$st');
      return false;
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

  int? _readIntFromApiData(
    Map<String, dynamic> apiData,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = apiData[key];
      if (value is int) return value;
      if (value != null) {
        final parsed = int.tryParse(value.toString());
        if (parsed != null) return parsed;
      }
    }
    return null;
  }

  /// Embeds infra/cluster contacts into CM ticket JSON and saves [cm_sites_data]
  /// so downloaded tickets show contacts offline.
  Future<Map<String, dynamic>> _enrichCmTicketApiDataWithSiteContacts(
    Map<String, dynamic> apiData, {
    required String siteAuditSchId,
  }) async {
    try {
      final flat = mergeNestedSiteMapsIntoIncidentTicket(
        unwrapTicketDataMap(apiData),
      );
      final physicalSiteId = resolveCmPhysicalSiteId(flat);
      if (physicalSiteId <= 0) return apiData;

      Map<String, dynamic> enriched = flat;
      if (cmTicketPayloadMissingSiteContacts(flat)) {
        final sites = await ServiceLocator().cmRepository.getCMSitesDropdown();
        for (final site in sites) {
          if (site.siteId != physicalSiteId) continue;
          enriched = overlayCmSiteContactFields(
            base: flat,
            infraName: site.infraEngineerName,
            infraPhone: site.infraEngineerContactNo,
            clusterInchargeName: site.clusterInchargeName,
            clusterInchargeContact: site.clusterInchargeContactNo,
          );
          await _persistCmSiteContactsRow(
            ticketFlat: flat,
            site: site,
            siteAuditSchId: siteAuditSchId,
            enriched: enriched,
          );
          break;
        }
      } else {
        await _persistCmSiteContactsRow(
          ticketFlat: flat,
          site: null,
          siteAuditSchId: siteAuditSchId,
          enriched: enriched,
        );
      }

      if (apiData.containsKey('data') && apiData['data'] is Map) {
        return {...apiData, 'data': enriched};
      }
      return enriched;
    } catch (e) {
      Logger.errorLog('❌ Error enriching CM ticket with site contacts: $e');
      return apiData;
    }
  }

  Future<void> _persistCmSiteContactsRow({
    required Map<String, dynamic> ticketFlat,
    required CMSite? site,
    required String siteAuditSchId,
    required Map<String, dynamic> enriched,
  }) async {
    final physicalSiteId = resolveCmPhysicalSiteId(ticketFlat);
    if (physicalSiteId <= 0) return;

    final entityId = _readIntFromApiData(ticketFlat, [
          'entityId',
          'entity_id',
          'cmSiteReqId',
          'cm_site_req_id',
        ]) ??
        int.tryParse(siteAuditSchId) ??
        0;

    await ServiceLocator().centralAssetAuditDataService.saveCMSiteData(
      siteId: physicalSiteId,
      entityId: entityId,
      siteCode: readMapString(ticketFlat, ['siteCode', 'site_code']) ??
          (site?.siteCode?.toString() ?? ''),
      siteName: readMapString(ticketFlat, ['siteName', 'site_name']) ??
          (site?.siteName?.toString() ?? ''),
      clusterDistrictId: _readIntFromApiData(ticketFlat, [
        'clusterDistrictId',
        'cluster_district_id',
      ]),
      clusterDistrictName: readMapString(ticketFlat, [
            'clusterDistrictName',
            'cluster_district_name',
            'cluster',
          ]) ??
          site?.clusterDistrictName?.toString(),
      circleStateId: _readIntFromApiData(ticketFlat, [
        'circleStateId',
        'circle_state_id',
      ]),
      circleStateName: readMapString(ticketFlat, [
            'circleStateName',
            'circle_state_name',
            'circle',
          ]) ??
          site?.circleStateName?.toString(),
      clientId: _readIntFromApiData(ticketFlat, ['clientId', 'client_id']),
      clientName: readMapString(ticketFlat, ['clientName', 'client_name', 'client']),
      oem: readMapString(ticketFlat, ['oem']) ?? site?.oem?.toString(),
      oemId: _readIntFromApiData(ticketFlat, ['oemId', 'oem_id']) ?? site?.oemId,
      self: readMapString(ticketFlat, ['self', 'assignedToName', 'assigned_to_name']) ??
          site?.self?.toString(),
      selfId: _readIntFromApiData(ticketFlat, ['selfId', 'self_id', 'assignedTo', 'assigned_to']) ??
          site?.selfId,
      activityType: ActivityTypeEnum.correctiveMaintenance.value,
      infraDistrictEngineerName: readMapString(enriched, [
        'infraDistrictEngineerName',
        'infra_district_engineer_name',
        'infraEngineerName',
        'infra_engineer_name',
      ]),
      infraDistrictEngineerContactNo: readMapString(enriched, [
        'infraDistrictEngineerContactNo',
        'infra_district_engineer_contact_no',
        'infraEngineerContactNo',
        'infra_engineer_contact_no',
      ]),
      clusterInchargeName: readMapString(enriched, [
        'clusterInchargeName',
        'cluster_incharge_name',
      ]),
      clusterInchargeContactNo: readMapString(enriched, [
        'clusterInchargeContactNo',
        'cluster_incharge_contact_no',
      ]),
    );
  }
}
