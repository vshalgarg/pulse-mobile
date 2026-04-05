import 'package:flutter/foundation.dart';

import '../models/pmis_project_module_model.dart';
import 'api_service.dart';

class PmisModuleService {
  final ApiService _apiService;

  PmisModuleService({required ApiService apiService}) : _apiService = apiService;

  static const String _path = 'pmis/api/v1/dashboard/project-module-list';

  Future<ResponseResult<List<PmisProjectModule>>> getProjectModuleList({
    required int projectId,
    required int siteId,
  }) async {
    try {
      final dio = _apiService.apiProvider.getClient();
      final response = await dio.get(
        _path,
        queryParameters: <String, dynamic>{
          'projectId': projectId,
          'siteId': siteId,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data is List<dynamic>) {
          final modules = data
              .map(
                (e) => PmisProjectModule.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList();
          return ResponseResult.success(modules, response.statusCode);
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
      debugPrint('❌ PmisModuleService.getProjectModuleList: $e');
      return ResponseResult.error(
        errorMessage: 'Exception occurred: ${e.toString()}',
      );
    }
  }
}
