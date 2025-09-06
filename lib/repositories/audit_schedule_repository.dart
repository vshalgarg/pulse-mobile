import 'dart:io';
import 'package:dio/dio.dart';
import 'package:app/models/UpdateAuditScheduleStatusModel.dart';

import '../services/api_service.dart';

class AuditScheduleRepository {
  final ApiService _apiService;

  AuditScheduleRepository(this._apiService);

  Future<UpdateAuditScheduleStatusResponse> updateAuditScheduleStatus({
    required String status,
    required String siteAuditSchId,
  }) async {
    try {
      final response = await _apiService.post(
        path: '/api/v1/om-schedule/update-audit-schedule-status',
        queryParameters: {
          'status': status,
          'siteAuditSchId': siteAuditSchId,
        },
      );

      if (response.statusCode == 200) {
        return UpdateAuditScheduleStatusResponse.fromJson(response.data);
      } else {
        throw Exception(
          'Failed to update audit schedule status: ${response.statusCode}',
        );
      }
    } on DioException catch (e) {
      if (e.response != null) {
        throw Exception(
          'API Error: ${e.response?.statusCode} - ${e.response?.data}',
        );
      } else {
        throw Exception('Network Error: ${e.message ?? e.toString()}');
      }
    } catch (e) {
      throw Exception('Unexpected error: $e');
    }
  }
}

