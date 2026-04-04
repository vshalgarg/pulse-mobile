import 'package:flutter/foundation.dart';

import '../models/pmis_project_site_model.dart';
import 'api_service.dart';

class PmisSiteService {
  final ApiService _apiService;

  PmisSiteService({required ApiService apiService}) : _apiService = apiService;

  static const String _path = 'pmis/api/v1/dashboard/project-site-list';

  Future<ResponseResult<List<PmisProjectSite>>> getProjectSiteList({
    required int projectId,
    required int stateId,
    required double latitude,
    required double longitude,
  }) async {
    try {
      final dio = _apiService.apiProvider.getClient();
      final response = await dio.get(
        _path,
        queryParameters: <String, dynamic>{
          'projectId': projectId,
          'stateId': stateId,
          'latitude': latitude,
          'longitude': longitude,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data is List<dynamic>) {
          final sites = data
              .map(
                (e) => PmisProjectSite.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList();
          return ResponseResult.success(sites, response.statusCode);
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
      debugPrint('❌ PmisSiteService.getProjectSiteList: $e');
      return ResponseResult.error(
        errorMessage: 'Exception occurred: ${e.toString()}',
      );
    }
  }
}
