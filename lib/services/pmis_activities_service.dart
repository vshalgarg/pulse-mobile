import 'dart:core';

import 'package:flutter/foundation.dart';

import '../models/pmis_project_activity_model.dart';
import 'api_service.dart';

class PmisActivitiesService {
  final ApiService _apiService;

  PmisActivitiesService({required ApiService apiService})
      : _apiService = apiService;

  static const String _path = 'pmis/api/v1/dashboard/project-activity-list';
  static const String _subModuleActivitiesPath =
      'pmis/api/v1/dashboard/project-submodule-activiy-list';

  Future<ResponseResult<List<PmisProjectActivity>>> getProjectActivityList({
    required int id,
    required double latitude,
    required double longitude,
    String? searchText,
  }) async {
    try {
      final dio = _apiService.apiProvider.getClient();

      final response = await dio.get(
        _path,
        queryParameters: <String, dynamic>{
          'projectId': id,
          'latitude': latitude,
          'longitude': longitude,
          'searchText': searchText ?? '',
        },
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data is List<dynamic>) {
          final activities = data
              .map((e) => PmisProjectActivity.fromJson(
                    Map<String, dynamic>.from(e as Map),
                  ))
              .toList();
          return ResponseResult.success(activities, response.statusCode);
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
      debugPrint('❌ PmisActivitiesService.getProjectActivityList: $e');
      return ResponseResult.error(
        errorMessage: 'Exception occurred: ${e.toString()}',
      );
    }
  }

  Future<ResponseResult<List<PmisProjectActivity>>> getSubModuleActivties({
    required int siteId,
    required int subModuleId,
    required double latitude,
    required double longitude,
  }) async {
    try {
      final dio = _apiService.apiProvider.getClient();

      final response = await dio.get(
        _subModuleActivitiesPath,
        queryParameters: <String, dynamic>{
          'siteId': siteId,
          'subModuleId': subModuleId,
          'latitude': latitude,
          'longitude': longitude,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data is List<dynamic>) {
          final activities = data
              .map((e) => PmisProjectActivity.fromJson(
                    Map<String, dynamic>.from(e as Map),
                  ))
              .toList();
          return ResponseResult.success(activities, response.statusCode);
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
      debugPrint('❌ PmisActivitiesService.getSubModuleActivties: $e');
      return ResponseResult.error(
        errorMessage: 'Exception occurred: ${e.toString()}',
      );
    }
  }
}

