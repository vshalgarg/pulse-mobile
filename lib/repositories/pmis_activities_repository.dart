import '../models/pmis_project_activity_model.dart';
import '../services/api_service.dart';
import '../services/pmis_activities_service.dart';

class PmisActivitiesRepository {
  final PmisActivitiesService _pmisService;

  PmisActivitiesRepository({required PmisActivitiesService pmisService})
      : _pmisService = pmisService;

  Future<ResponseResult<List<PmisProjectActivity>>> getProjectActivityList({
    required int id,
    required double latitude,
    required double longitude,
  }) async {
    try {
      return await _pmisService.getProjectActivityList(
        id: id,
        latitude: latitude,
        longitude: longitude,
      );
    } catch (e) {
      return ResponseResult.error(
        errorMessage: 'Exception occurred: ${e.toString()}',
      );
    }
  }
}

