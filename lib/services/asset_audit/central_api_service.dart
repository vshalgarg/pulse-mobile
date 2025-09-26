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

      final response = await _apiService.get<List<dynamic>>(
        path:
            '/api/v1/mobile/EB/PageData/$siteType/$auditSchId/$siteAuditSchId',
      );

      if (response.isSuccess && response.data != null) {
        final Map<String, dynamic> parsedData =
          response.data!.first as Map<String, dynamic>;
      

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
      Logger.debugLog('📄 Starting PDF download for ticket: $ticketId');

      // Only allow PDF download for preventive maintenance
      if (activityType != ActivityTypeEnum.preventiveMaintenance) {
        Logger.errorLog('❌ PDF report not available for activity type: $activityType');
        return null;
      }

      // Get user ID from local storage
      final userId = LocalStorageDB.getUserId ?? '0';
      Logger.debugLog('Retrieved userId from storage: $userId');

      // Build report URL
      final reportUrl =
          '$reportBaseUrl/run?' +
          '__report=./birt_reports/OnM/Preventive_Maintenance.rptdesign&' +
          'rp_login_userid=$userId&' +
          'rp_tenant=$userId&' +
          'rp_sch_id=$ticketSchId&' +
          '__format=pdf';

      Logger.debugLog('Report URL: $reportUrl');

      final fileName = 'PM-Report-$ticketId';

      // Download the PDF
      final filePath = await PdfDownloadService.downloadPdf(
        reportUrl: reportUrl,
        fileName: fileName,
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
