import 'package:app/enum/activity_type_enum.dart';
import 'package:app/models/pmis_activity_ticket_model.dart';
import 'package:app/models/pmis_project_activity_model.dart';
import 'package:app/repositories/pmis_activity_ticket_repository.dart';
import 'package:app/services/service_locator.dart';

/// PMIS activity ticket offline storage uses the same stack as Site Visit ticket
/// download: `raw_api_data` + `ImageUploadService` `LOCAL_IMAGE_ID_*` for media.
class PmisActivityTicketOfflineDownloadResult {
  final bool success;
  final String? errorMessage;
  /// SQLite `raw_api_data.site_audit_sch_id` (= activity ticket id string).
  final String siteAuditSchId;

  const PmisActivityTicketOfflineDownloadResult({
    required this.success,
    this.errorMessage,
    required this.siteAuditSchId,
  });
}

class PmisActivityTicketOfflineService {
  PmisActivityTicketOfflineService._();
  static const String _manualDownloadFlagKey = '_manualOfflineDownloaded';

  static Future<PmisActivityTicketOfflineDownloadResult> downloadCompleteTicket({
    required PmisActivityTicketRepository repository,
    required PmisProjectActivity activity,
  }) async {
    final atId = activity.atId;
    if (atId == null) {
      return const PmisActivityTicketOfflineDownloadResult(
        success: false,
        errorMessage: 'Activity ticket id missing',
        siteAuditSchId: '',
      );
    }

    final rawRes = await repository.getActivityTicketRawBody(
      activityTicketId: atId,
    );
    if (!rawRes.isSuccess || rawRes.data == null) {
      return PmisActivityTicketOfflineDownloadResult(
        success: false,
        errorMessage: rawRes.errorMessage ?? 'Failed to load activity ticket',
        siteAuditSchId: atId.toString(),
      );
    }

    final ok = await ServiceLocator().centralAssetAuditService
        .downloadAndSavePmisActivityTicketOffline(
      ticketJsonBody: rawRes.data!,
      activityTicketId: atId,
      siteName: activity.siteName,
      moduleName: activity.moduleName,
      subModuleName: activity.subModuleName,
      activityName: activity.activityName,
      state: activity.state,
      activityStatus: activity.activityStatus ?? activity.currentStatus,
      approvalStatus: activity.approvalStatus ?? '',
      plannedStartDt: activity.plannedStartDt,
      plannedEndDt: activity.plannedEndDt,
      actualStartDt: activity.actualStartDt,
      actualEndDt: activity.actualEndDt,
      latitude: activity.latitude ?? 0,
      longitude: activity.longitude ?? 0,
    );

    if (ok) {
      // Mark this row as user-triggered manual offline download.
      final dataService = ServiceLocator().centralAssetAuditDataService;
      final existing = await dataService.getRawApiData(atId.toString());
      if (existing != null) {
        final updatedApi = Map<String, dynamic>.from(existing.apiData)
          ..[_manualDownloadFlagKey] = true;
        await dataService.updateRawApiData(
          siteAuditSchId: atId.toString(),
          apiData: updatedApi,
        );
      }
    }

    return PmisActivityTicketOfflineDownloadResult(
      success: ok,
      errorMessage: ok ? null : 'Failed to save offline bundle',
      siteAuditSchId: atId.toString(),
    );
  }

  static Future<PmisActivityTicketDetail?> loadOfflineDetail(int atId) async {
    final data = await ServiceLocator().centralAssetAuditService
        .getDataFromSqlite(siteAuditSchId: atId.toString());
    if (data == null || !data.isDownloaded) return null;
    if (data.activityType != ActivityTypeEnum.activityTicket) return null;
    try {
      final map = Map<String, dynamic>.from(data.apiData);
      return PmisActivityTicketDetail.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  static Future<bool> isTicketDownloadedForOffline(int atId) async {
    final data = await ServiceLocator().centralAssetAuditService
        .getDataFromSqlite(siteAuditSchId: atId.toString());
    final isManualDownload =
        data?.apiData[_manualDownloadFlagKey] == true;
    return data != null &&
        isManualDownload &&
        data.activityType == ActivityTypeEnum.activityTicket;
  }
}
