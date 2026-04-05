import 'package:flutter/foundation.dart';

import '../models/pmis_project_submodule_model.dart';
import 'api_service.dart';

class PmisSubModuleService {
  final ApiService _apiService;

  PmisSubModuleService({required ApiService apiService})
      : _apiService = apiService;

  static const String _path = 'pmis/api/v1/dashboard/project-submodule-list';

  Future<ResponseResult<List<PmisProjectSubModule>>> getProjectSubModuleList({
    required int projectId,
    required int siteId,
    required int moduleId,
  }) async {
    try {
      final dio = _apiService.apiProvider.getClient();
      final response = await dio.get(
        _path,
        queryParameters: <String, dynamic>{
          'projectId': projectId,
          'siteId': siteId,
          'moduleId': moduleId,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data is List<dynamic>) {
          final items = data
              .map(
                (e) => PmisProjectSubModule.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList();
          return ResponseResult.success(items, response.statusCode);
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
      debugPrint('❌ PmisSubModuleService.getProjectSubModuleList: $e');
      return ResponseResult.error(
        errorMessage: 'Exception occurred: ${e.toString()}',
      );
    }
  }
}
