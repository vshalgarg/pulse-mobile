import '../models/asset_audit_model.dart';
import '../services/api_service.dart';

class AssetAuditRepository {
  final ApiService _apiService;

  AssetAuditRepository({required ApiService apiService})
      : _apiService = apiService;

  Future<AssetAuditModel> getAssetAuditData({
    required String siteType,
    required String auditSchId,
    required String siteAuditSchId,
  }) async {
    final response = await _apiService.get<dynamic>(
      path: '/api/v1/mobile/EB/PageData/$siteType/$auditSchId/$siteAuditSchId',
    );

    if (response.isSuccess && response.data != null) {
      // The API returns a direct array of page header objects
      return AssetAuditModel.fromJson(response.data!);
    } else {
      throw Exception(response.errorMessage ?? 'Failed to load asset audit data');
    }
  }
}
