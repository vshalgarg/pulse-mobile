import 'package:app/enum/activity_type_enum.dart';
import 'package:app/repositories/cm_repository.dart';
import 'package:app/repositories/sites.repository.dart';
import 'package:app/services/local_storage_db.dart';
import 'package:app/services/pdf_download_service.dart';
import '../api_service.dart';
import '../../utils/logger.dart';

class CentralApiService {
  final ApiService _apiService;

  CentralApiService({required ApiService apiService})
    : _apiService = apiService;

  Future<Map<String, dynamic>?> fetchData({
    required String siteType,
    required String auditSchId,
    required String siteAuditSchId,
    required ActivityTypeEnum activityType,
  }) async {
    final apiData = activityType == ActivityTypeEnum.assetAudit
        ? await fetchAssetAuditData(
            siteType: siteType,
            auditSchId: auditSchId,
            siteAuditSchId: siteAuditSchId,
          )
        : activityType == ActivityTypeEnum.preventiveMaintenance
        ? await fetchPmData(
            siteType: siteType,
            auditSchId: auditSchId,
            siteAuditSchId: siteAuditSchId,
          )
        : activityType == ActivityTypeEnum.energyReading
        ? await fetchEnergyReadingData(
            siteType: siteType,
            auditSchId: auditSchId,
            siteAuditSchId: siteAuditSchId,
          )
        : activityType == ActivityTypeEnum.siteVisit
        ? await fetchSiteVisitData(
            siteType: siteType,
            auditSchId: auditSchId,
            siteAuditSchId: siteAuditSchId,
          )
        : activityType == ActivityTypeEnum.generalInspection
        ? await fetchGeneralInspectionData(
            siteType: siteType,
            auditSchId: auditSchId,
            siteAuditSchId: siteAuditSchId,
          )
        : activityType == ActivityTypeEnum.correctiveMaintenance
        ? await CMRepository(
            _apiService,
          ).getCmTicketData(int.parse(siteAuditSchId))
        : null;
    return apiData;
  }

  /// Fetch complete asset audit data
  Future<Map<String, dynamic>?> fetchAssetAuditData({
    required String siteType,
    required String auditSchId,
    required String siteAuditSchId,
  }) async {
    try {
      Logger.debugLog('🌐 Fetching complete asset audit data from API');

      final response = await _apiService.get<Map<String, dynamic>>(
        path:
            '/api/v1/mobile/assetAudit/PageData/$siteType/$auditSchId/$siteAuditSchId',
      );

      if (response.isSuccess && response.data != null) {
        return response.data;
      } else {
        Logger.errorLog(
          '❌ Failed to fetch asset audit data: ${response.errorMessage}',
        );
        return null;
      }
    } catch (e) {
      Logger.errorLog('❌ Error fetching asset audit data: $e');
      return null;
    }
  }

  // Fetch compelte Energy Reading
  Future<Map<String, dynamic>?> fetchEnergyReadingData({
    required String siteType,
    required String auditSchId,
    required String siteAuditSchId,
  }) async {
    try {
      Logger.debugLog('🌐 Fetching complete ER data from API');

      final response = await _apiService.get<Map<String, dynamic>>(
        path:
            '/api/v1/mobile/EB/PageDataAndERData/$siteType/$auditSchId/$siteAuditSchId',
      );

      if (response.isSuccess && response.data != null) {
        final Map<String, dynamic> parsedData =
            response.data! as Map<String, dynamic>;

        Logger.debugLog('🌐 ER data fetched successfully: ${response.data}');
        return parsedData;
      } else {
        Logger.errorLog('❌ Failed to fetch ER data: ${response.errorMessage}');
        return null;
      }
    } catch (e) {
      Logger.errorLog('❌ Error fetching ER data: $e');
      return null;
    }
  }

  /// Fetch complete asset audit data

  /// Fetch complete pm data
  Future<Map<String, dynamic>?> fetchPmData({
    required String siteType,
    required String auditSchId,
    required String siteAuditSchId,
  }) async {
    try {
      Logger.debugLog('🌐 Fetching complete asset audit data from API');

      final response = await _apiService.get<Map<String, dynamic>>(
        path:
            '/api/v1/mobile/preventiveMaintainance/PageData/$siteType/$auditSchId/$siteAuditSchId',
      );

      if (response.isSuccess && response.data != null) {
        return response.data;
      } else {
        Logger.errorLog(
          '❌ Failed to fetch asset audit data: ${response.errorMessage}',
        );
        return null;
      }
    } catch (e) {
      Logger.errorLog('❌ Error fetching asset audit data: $e');
      return null;
    }
  }

  /// Download PDF report for a ticket
  Future<String?> downloadPdfReport({
    required String ticketId,
    required String ticketSchId,
    required ActivityTypeEnum activityType,
  }) async {
    try {
      Logger.debugLog('📄 Starting PDF download for ticket: $activityType');

      final reportPath = activityType == ActivityTypeEnum.preventiveMaintenance
          ? 'OnM/Preventive_Maintenance.rptdesign'
          : activityType == ActivityTypeEnum.assetAudit
          ? 'OnM/Asset_Audit.rptdesign'
          : activityType == ActivityTypeEnum.correctiveMaintenance
          ? 'OnM/Corrective_Maintenance.rptdesign' : activityType == ActivityTypeEnum.generalInspection ? 'OnM/gen_inspection.rptdesign'
          : 'OnM/Corrective_Maintenance.rptdesign';

      // Get user ID from local storage
      final userId = LocalStorageDB.getUserId ?? '0';
      final token = LocalStorageDB.getToken;
      Logger.debugLog('Retrieved userId from storage: $userId');

      if (token == null) {
        Logger.errorLog('❌ No authentication token found');
        return null;
      }

      // Use baseUrl from ApiService instead of hardcoded URL
      final baseUrl = _apiService.baseUrl;
      final reportUrl =
          '$baseUrl/reports/generate?'
          'reportPath=$reportPath&'
          'rp_tenant=$userId&'
          'rp_sch_id=$ticketSchId&'
          'rp_login_userid=$userId';

      Logger.debugLog('Report URL: $reportUrl');

      final fileName = activityType == ActivityTypeEnum.preventiveMaintenance
          ? 'PM-Report-$ticketId'
          : activityType == ActivityTypeEnum.correctiveMaintenance
          ? 'CM-Report-$ticketId'  
          : activityType == ActivityTypeEnum.generalInspection ? 'GI-Report-$ticketId'
          : 'AA-Report-$ticketId';

      // Download the PDF
      final filePath = await PdfDownloadService.downloadPdf(
        reportUrl: reportUrl,
        fileName: fileName,
        token: token,
      );

      if (filePath != null) {
        Logger.debugLog('✅ PDF downloaded successfully to: $filePath');
        return filePath;
      } else {
        Logger.errorLog('❌ Failed to download PDF');
        return null;
      }
    } catch (e) {
      Logger.errorLog('❌ Error downloading PDF: $e');
      return null;
    }
  }

  // fetch site visit data
  Future<Map<String, dynamic>?> fetchSiteVisitData({
    required String siteType,
    required String auditSchId,
    required String siteAuditSchId,
  }) async {
    try {
      Logger.debugLog('🌐 Fetching complete site visit data from API');

      final response = await _apiService.get<Map<String, dynamic>>(
        path: '/api/v1/om-schedule/siteVisitLog/$siteAuditSchId',
      );

      if (response.isSuccess && response.data != null) {
        final Map<String, dynamic> parsedData =
            response.data! as Map<String, dynamic>;

        Logger.debugLog(
          '🌐 Site Visit data fetched successfully: ${response.data}',
        );

        // Fetch organisation list and map orgId to organisationName
        try {
          
          final sitesRepository = SitesRepository(_apiService);
          final organisationList = await sitesRepository.getOrganisationList();
          
          // Include organisation list in the response so it's available to the screen
          parsedData['organisationList'] = organisationList;
          Logger.debugLog('✅ Organisation list fetched and included in response: ${organisationList.length} organisations');
          
          // If response has orgId, find the matching organisation name
          if (parsedData.containsKey('orgId') && parsedData['orgId'] != null) {
            final orgId = parsedData['orgId'];
            try {
              final matchingOrg = organisationList.firstWhere(
                (org) => org['org_id'] == orgId,
              );
              parsedData['organisationName'] = matchingOrg['org_name'];
              Logger.debugLog('✅ Mapped orgId $orgId to organisationName: ${matchingOrg['org_name']}');
            } catch (e) {
              Logger.debugLog('⚠️ Organisation with orgId $orgId not found in list');
            }
          }
        } catch (e) {
          Logger.errorLog('❌ Error fetching organisation list: $e');
          // Continue without organisation name mapping
        }

        return parsedData;
      } else {
        Logger.errorLog('❌ Failed to fetch ER data: ${response.errorMessage}');
        return null;
      }
    } catch (e) {
      Logger.errorLog('❌ Error fetching Site Visit data: $e');
      return null;
    }
  }

  // fetch general inspection data
  Future<Map<String, dynamic>?> fetchGeneralInspectionData({
    required String siteType,
    required String auditSchId,
    required String siteAuditSchId,
  }) async {
    try {

      final response = await _apiService.get<Map<String, dynamic>>(
        path: '/api/v1/om-schedule/genInspection/$siteAuditSchId',
      );

      if (response.isSuccess && response.data != null) {
        final Map<String, dynamic> parsedData =
            response.data! as Map<String, dynamic>;

        return parsedData;
      } else {
        Logger.errorLog('❌ Failed to fetch  data: ${response.errorMessage}');
        return null;
      }
    } catch (e) {
      Logger.errorLog('❌ Error fetching GI data: $e');
      return null;
    }
  }
}
