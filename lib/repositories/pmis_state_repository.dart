import '../models/pmis_project_state_model.dart';
import '../services/api_service.dart';
import '../services/pmis_state_service.dart';

class PmisStateRepository {
  final PmisStateService _pmisStateService;

  PmisStateRepository({required PmisStateService pmisStateService})
      : _pmisStateService = pmisStateService;

  Future<ResponseResult<List<PmisProjectState>>> getProjectStateList({
    required int projectId,
  }) async {
    try {
      return await _pmisStateService.getProjectStateList(
        projectId: projectId,
      );
    } catch (e) {
      return ResponseResult.error(
        errorMessage: 'Exception occurred: ${e.toString()}',
      );
    }
  }
}
