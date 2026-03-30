import 'package:flutter/foundation.dart';

import '../models/pmis_project_model.dart';
import 'api_service.dart';

class PmisService {
  final ApiService _apiService;

  PmisService({required ApiService apiService}) : _apiService = apiService;

  /// Relative to [ApiProvider.baseUrl] (e.g. `.../api/`). A leading `/` would
  /// strip the `/api` segment and hit the wrong host path (HTML → JSON parse error).
  static const String _projectListPath =
      'pmis/api/v1/dashboard/project-list';

  Future<ResponseResult<List<PmisProject>>> getProjectList() async {
    try {
      final dio = _apiService.apiProvider.getClient();
      final response = await dio.get(_projectListPath);

      if (response.statusCode == 200) {
        final data = response.data;
        if (data is List<dynamic>) {
          final projects = data
              .map(
                (e) => PmisProject.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList();
          return ResponseResult.success(projects, response.statusCode);
        }
        debugPrint('❌ PMIS project-list: unexpected body type ${data.runtimeType}');
        return ResponseResult.error(
          errorMessage: 'Unexpected response format',
          statusCode: response.statusCode,
        );
      }
      return ResponseResult.error(
        errorMessage:
            'Request failed with status code: ${response.statusCode}',
        statusCode: response.statusCode,
      );
    } catch (e) {
      debugPrint('❌ PmisService.getProjectList: $e');
      return ResponseResult.error(
        errorMessage: 'Exception occurred: ${e.toString()}',
      );
    }
  }
}
