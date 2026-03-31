import 'package:flutter/foundation.dart';

import '../models/pmis_project_state_model.dart';
import 'api_service.dart';

class PmisStateService {
  final ApiService _apiService;

  PmisStateService({required ApiService apiService}) : _apiService = apiService;

  static const String _path = 'pmis/api/v1/dashboard/project-state-list';

  Future<ResponseResult<List<PmisProjectState>>> getProjectStateList({
    required int projectId,
  }) async {
    try {
      final dio = _apiService.apiProvider.getClient();
      final response = await dio.get(
        _path,
        queryParameters: <String, dynamic>{
          'projectId': projectId,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data is List<dynamic>) {
          final states = data
              .map(
                (e) => PmisProjectState.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList();
          return ResponseResult.success(states, response.statusCode);
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
      debugPrint('❌ PmisStateService.getProjectStateList: $e');
      return ResponseResult.error(
        errorMessage: 'Exception occurred: ${e.toString()}',
      );
    }
  }
}
