import '../models/pmis_project_submodule_model.dart';
import '../services/api_service.dart';
import '../services/pmis_submodule_service.dart';

class PmisSubModuleRepository {
  final PmisSubModuleService _pmisSubModuleService;

  PmisSubModuleRepository({required PmisSubModuleService pmisSubModuleService})
      : _pmisSubModuleService = pmisSubModuleService;

  Future<ResponseResult<List<PmisProjectSubModule>>> getProjectSubModuleList({
    required int projectId,
    required int siteId,
    required int moduleId,
  }) async {
    try {
      return await _pmisSubModuleService.getProjectSubModuleList(
        projectId: projectId,
        siteId: siteId,
        moduleId: moduleId,
      );
    } catch (e) {
      return ResponseResult.error(
        errorMessage: 'Exception occurred: ${e.toString()}',
      );
    }
  }
}
