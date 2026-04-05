import '../models/pmis_project_module_model.dart';
import '../services/api_service.dart';
import '../services/pmis_module_service.dart';

class PmisModuleRepository {
  final PmisModuleService _pmisModuleService;

  PmisModuleRepository({required PmisModuleService pmisModuleService})
      : _pmisModuleService = pmisModuleService;

  Future<ResponseResult<List<PmisProjectModule>>> getProjectModuleList({
    required int projectId,
    required int siteId,
  }) async {
    try {
      return await _pmisModuleService.getProjectModuleList(
        projectId: projectId,
        siteId: siteId,
      );
    } catch (e) {
      return ResponseResult.error(
        errorMessage: 'Exception occurred: ${e.toString()}',
      );
    }
  }
}
