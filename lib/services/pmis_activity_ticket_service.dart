import 'package:flutter/foundation.dart';

import '../models/pmis_activity_ticket_model.dart';
import 'api_service.dart';

class PmisActivityTicketService {
  final ApiService _apiService;

  PmisActivityTicketService({required ApiService apiService})
      : _apiService = apiService;

  static const String _pathPrefix = 'pmis/api/v1/project-plan/activity-ticket';

  Future<ResponseResult<PmisActivityTicketDetail>> getActivityTicket({
    required int activityTicketId,
  }) async {
    try {
      final dio = _apiService.apiProvider.getClient();
      final response = await dio.get('$_pathPrefix/$activityTicketId');

      if (response.statusCode == 200) {
        final data = response.data;
        if (data is Map) {
          final ticket = PmisActivityTicketDetail.fromJson(
            Map<String, dynamic>.from(data as Map),
          );
          return ResponseResult.success(ticket, response.statusCode);
        }
        return ResponseResult.error(
          errorMessage: 'Unexpected response format',
          statusCode: response.statusCode,
        );
      }

      return ResponseResult.error(
        errorMessage: 'Request failed with status code: ${response.statusCode}',
        statusCode: response.statusCode,
      );
    } catch (e) {
      debugPrint('❌ PmisActivityTicketService.getActivityTicket: $e');
      return ResponseResult.error(
        errorMessage: 'Exception occurred: ${e.toString()}',
      );
    }
  }
}
