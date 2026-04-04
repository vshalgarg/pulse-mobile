import '../models/pmis_project_site_model.dart';
import '../services/api_service.dart';
import '../services/pmis_site_service.dart';

class PmisSiteRepository {
  final PmisSiteService _pmisSiteService;

  PmisSiteRepository({required PmisSiteService pmisSiteService})
      : _pmisSiteService = pmisSiteService;

  Future<ResponseResult<List<PmisProjectSite>>> getProjectSiteList({
    required int projectId,
    required int stateId,
    required double latitude,
    required double longitude,
  }) async {
    try {
      return await _pmisSiteService.getProjectSiteList(
        projectId: projectId,
        stateId: stateId,
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
