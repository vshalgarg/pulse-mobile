import '../models/pmis_project_model.dart';
import '../services/api_service.dart';
import '../services/pmis_service.dart';

class PmisRepository {
  final PmisService _pmisService;

  PmisRepository({required PmisService pmisService})
      : _pmisService = pmisService;

  Future<ResponseResult<List<PmisProject>>> getProjectList() async {
    try {
      return await _pmisService.getProjectList();
    } catch (e) {
      return ResponseResult.error(
        errorMessage: 'Exception occurred: ${e.toString()}',
      );
    }
  }
}
