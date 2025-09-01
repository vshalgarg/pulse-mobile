import '../models/asset_audit_model.dart';
import '../models/asset_audit_post_model.dart';
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
      path: '/api/v1/mobile/assetAudit/PageData/$siteType/$auditSchId/$siteAuditSchId',
    );

    if (response.isSuccess && response.data != null) {
      return AssetAuditModel.fromJson(response.data!);
    } else {
      final errorMsg = response.errorMessage ?? 'Failed to load asset audit data';
      print('Asset Audit API Error: $errorMsg');
      print('Requested URL: /api/v1/mobile/assetAudit/PageData/$siteType/$auditSchId/$siteAuditSchId');
      print('Parameters: siteType=$siteType, auditSchId=$auditSchId, siteAuditSchId=$siteAuditSchId');
      
      // Check if it's a 404 error (no data found)
      if (errorMsg.contains('Asset not found') || errorMsg.contains('404')) {
        throw Exception('NO_SITE_AUDIT_SCHEDULE: No site audit schedule found for this ticket. Please contact your administrator to create the asset audit schedule before proceeding.');
      }
      
      throw Exception(errorMsg);
    }
  }

  /// Post asset audit data to the API
  /// This method is called when navigating between screens to save the current screen's data
  Future<List<AssetAuditPostResponse>> postAssetAuditData({
    required List<AssetAuditPostRequest> requests,
  }) async {
    try {
      print('AssetAuditRepository: Posting ${requests.length} asset audit items');
      
      final response = await _apiService.post<List<dynamic>>(
        path: '/api/v1/mobile/AssetAuditSiteResp',
        data: requests.map((request) => request.toJson()).toList(),
      );

      if (response.isSuccess && response.data != null) {
        final List<AssetAuditPostResponse> responses = (response.data! as List)
            .map((item) => AssetAuditPostResponse.fromJson(item as Map<String, dynamic>))
            .toList();
        
        print('AssetAuditRepository: Successfully posted ${responses.length} items');
        return responses;
      } else {
        final errorMsg = response.errorMessage ?? 'Failed to post asset audit data';
        print('Asset Audit POST API Error: $errorMsg');
        throw Exception(errorMsg);
      }
    } catch (e) {
      print('AssetAuditRepository: Exception while posting data: $e');
      rethrow;
    }
  }

  /// Post a single asset audit item
  Future<AssetAuditPostResponse> postSingleAssetAuditItem({
    required AssetAuditPostRequest request,
  }) async {
    try {
      print('AssetAuditRepository: Posting single asset audit item');
      
      final response = await _apiService.post<Map<String, dynamic>>(
        path: '/api/v1/mobile/AssetAuditSiteResp',
        data: [request.toJson()], // API expects a list
      );

      if (response.isSuccess && response.data != null) {
        final List<AssetAuditPostResponse> responses = (response.data! as List)
            .map((item) => AssetAuditPostResponse.fromJson(item as Map<String, dynamic>))
            .toList();
        
        if (responses.isNotEmpty) {
          print('AssetAuditRepository: Successfully posted single item');
          return responses.first;
        } else {
          throw Exception('No response data received');
        }
      } else {
        final errorMsg = response.errorMessage ?? 'Failed to post asset audit item';
        print('Asset Audit POST API Error: $errorMsg');
        throw Exception(errorMsg);
      }
    } catch (e) {
      print('AssetAuditRepository: Exception while posting single item: $e');
      rethrow;
    }
  }
}
