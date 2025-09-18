import 'dart:io';
import 'package:app/enum/activity_type_enum.dart';
import 'package:dio/dio.dart';
import '../api_service.dart';
import '../../utils/logger.dart';

class CentralApiService {
  final ApiService _apiService;

  CentralApiService({required ApiService apiService}) : _apiService = apiService;

  Future<Map<String, dynamic>?> fetchData({
    required String siteType,
    required String auditSchId,
    required String siteAuditSchId,
    required ActivityTypeEnum activityType
  }) async {
    final apiData = activityType == ActivityTypeEnum.assetAudit ?
      await fetchAssetAuditData(
        siteType: siteType,
        auditSchId: auditSchId,
        siteAuditSchId: siteAuditSchId,
      )
    : activityType == ActivityTypeEnum.preventiveMaintenance ?
      await fetchPmData(
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
        path: '/api/v1/mobile/assetAudit/PageData/$siteType/$auditSchId/$siteAuditSchId',
      );

      if (response.isSuccess && response.data != null) {
        return response.data;
      } else {
        Logger.errorLog('❌ Failed to fetch asset audit data: ${response.errorMessage}');
        return null;
      }
    } catch (e) {
      Logger.errorLog('❌ Error fetching asset audit data: $e');
      return null;
    }
  }

  /// Fetch complete pm data
  Future<Map<String, dynamic>?> fetchPmData({
    required String siteType,
    required String auditSchId,
    required String siteAuditSchId,
  }) async {
    try {
      Logger.debugLog('🌐 Fetching complete asset audit data from API');

      final response = await _apiService.get<Map<String, dynamic>>(
        path: '/api/v1/mobile/preventiveMaintainance/PageData/$siteType/$auditSchId/$siteAuditSchId',
      );

      if (response.isSuccess && response.data != null) {
        return response.data;
      } else {
        Logger.errorLog('❌ Failed to fetch asset audit data: ${response.errorMessage}');
        return null;
      }
    } catch (e) {
      Logger.errorLog('❌ Error fetching asset audit data: $e');
      return null;
    }
  }

}
