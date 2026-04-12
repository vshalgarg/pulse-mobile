import '../models/pmis_project_model.dart';
import '../services/api_service.dart';
import '../services/pmis_service.dart';

class PmisRepository {
  final PmisService _pmisService;

  PmisRepository({required PmisService pmisService})
      : _pmisService = pmisService;

  Future<ResponseResult<List<PmisProject>>> getProjectList({
    String? activityType,
  }) async {
    try {
      return await _pmisService.getProjectList(activityType: activityType);
    } catch (e) {
      return ResponseResult.error(
        errorMessage: 'Exception occurred: ${e.toString()}',
      );
    }
  }
}
