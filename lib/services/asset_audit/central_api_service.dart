import 'package:app/enum/activity_type_enum.dart';
import 'package:app/constants/constants_strings.dart';
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
          : 'OnM/Asset_Audit.rptdesign';

      print('Report Path: $reportPath');

      // Get user ID from local storage
      final userId = LocalStorageDB.getUserId ?? '0';
      final token = LocalStorageDB.getToken;
      Logger.debugLog('Retrieved userId from storage: $userId');

      if (token == null) {
        Logger.errorLog('❌ No authentication token found');
        return null;
      }

      final reportUrl =
          'https://pulseapi.premiumfreshers.com//reports/generate?' +
          'reportPath=$reportPath&' +
          'rp_tenant=$userId&' +
          'rp_sch_id=$ticketSchId&' +
          'rp_login_userid=$userId';

      Logger.debugLog('Report URL: $reportUrl');

      final fileName = activityType == ActivityTypeEnum.preventiveMaintenance
          ? 'PM-Report-$ticketId'
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
}
