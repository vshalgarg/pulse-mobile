import 'package:app/models/PmGetDataModel.dart';
import 'package:app/models/PmPostRequestModel.dart';

import '../services/api_service.dart';

class PmRepository {
  final ApiService _apiService;

  PmRepository({required ApiService apiService})
      : _apiService = apiService;

  Future<PmGetDataModel> getAssetAuditData({
    required String siteType,
    required String auditSchId,
    required String siteAuditSchId,
  }) async {
    final apiPath = '/api/v1/mobile/preventiveMaintainance/PageData/$siteType/$auditSchId/$siteAuditSchId';
    print("🔍 DEBUG: PmRepository API call:");
    print("🔍 Full URL path: $apiPath");
    print("🔍 siteType: $siteType");
    print("🔍 auditSchId: $auditSchId");
    print("🔍 siteAuditSchId: $siteAuditSchId");
    
    final response = await _apiService.get<dynamic>(
      path: apiPath,
    );

    if (response.isSuccess && response.data != null) {
      print("🔍 DEBUG: API response successful");
      print("🔍 Response data keys: ${response.data!.keys.toList()}");
      if (response.data!['responseData'] != null) {
        print("🔍 ResponseData keys: ${(response.data!['responseData'] as Map<String, dynamic>).keys.toList()}");
      }
      return PmGetDataModel.fromJson(response.data!);
    } else {
      print("🔍 DEBUG: API response failed");
      print("🔍 Error message: ${response.errorMessage}");
      final errorMsg = response.errorMessage ?? 'Failed to load pm data';
      if (errorMsg.contains('pm not found') || errorMsg.contains('404')) {
        throw Exception('NO_SITE_PM_SCHEDULE: No site pm schedule found for this ticket. Please contact your administrator to create the asset audit schedule before proceeding.');
      }
      throw Exception(errorMsg);
    }
  }

  /// Post asset audit data to the API
  /// This method is called when navigating between screens to save the current screen's data
  // Future<List<AssetAuditPostResponse>> postAssetAuditData({
  //   required List<AssetAuditPostRequest> requests,
  // }) async {
  //   try {
  //     print('AssetAuditRepository: Posting ${requests.length} asset audit items');
  //
  //     final response = await _apiService.post<List<dynamic>>(
  //       path: '/api/v1/mobile/AssetAuditSiteResp',
  //       data: requests.map((request) => request.toJson()).toList(),
  //     );
  //
  //     if (response.isSuccess && response.data != null) {
  //       final List<AssetAuditPostResponse> responses = (response.data! as List)
  //           .map((item) => AssetAuditPostResponse.fromJson(item as Map<String, dynamic>))
  //           .toList();
  //
  //       print('AssetAuditRepository: Successfully posted ${responses.length} items');
  //       return responses;
  //     } else {
  //       final errorMsg = response.errorMessage ?? 'Failed to post asset audit data';
  //       print('Asset Audit POST API Error: $errorMsg');
  //       throw Exception(errorMsg);
  //     }
  //   } catch (e) {
  //     print('AssetAuditRepository: Exception while posting data: $e');
  //     rethrow;
  //   }
  // }

  // /// Post a single asset audit item
  // Future<AssetAuditPostResponse> postSingleAssetAuditItem({
  //   required AssetAuditPostRequest request,
  // }) async {
  //   try {
  //     print('AssetAuditRepository: Posting single asset audit item');
  //
  //     final response = await _apiService.post<Map<String, dynamic>>(
  //       path: '/api/v1/mobile/AssetAuditSiteResp',
  //       data: [request.toJson()], // API expects a list
  //     );
  //
  //     if (response.isSuccess && response.data != null) {
  //       final List<AssetAuditPostResponse> responses = (response.data! as List)
  //           .map((item) => AssetAuditPostResponse.fromJson(item as Map<String, dynamic>))
  //           .toList();
  //
  //       if (responses.isNotEmpty) {
  //         print('AssetAuditRepository: Successfully posted single item');
  //         return responses.first;
  //       } else {
  //         throw Exception('No response data received');
  //       }
  //     } else {
  //       final errorMsg = response.errorMessage ?? 'Failed to post asset audit item';
  //       print('Asset Audit POST API Error: $errorMsg');
  //       throw Exception(errorMsg);
  //     }
  //   } catch (e) {
  //     print('AssetAuditRepository: Exception while posting single item: $e');
  //     rethrow;
  //   }
  // }

  Future<List<PmPostResponse>> postPmData({
    required List<PmPostRequest> requests,
  }) async {
    try {
      final response = await _apiService.post<List<dynamic>>(
        path: '/api/v1/mobile/PmResponse',
        data: requests.map((request) => request.toJson()).toList(),
      );

      if (response.isSuccess && response.data != null) {
        final List<PmPostResponse> responses = (response.data! as List)
            .map((item) => PmPostResponse.fromJson(item as Map<String, dynamic>))
            .toList();

        return responses;
      } else {
        final errorMsg = response.errorMessage ?? 'Failed to post PM data';
        throw Exception(errorMsg);
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<PmPostResponse> postSinglePmItem({
    required PmPostRequest request,
  }) async {
    try {
      final response = await _apiService.post<List<dynamic>>(
        path: '/api/v1/mobile/PmResponse',
        data: [request.toJson()],
      );

      if (response.isSuccess && response.data != null) {
        final List<PmPostResponse> responses = (response.data! as List)
            .map((item) => PmPostResponse.fromJson(item as Map<String, dynamic>))
            .toList();

        if (responses.isNotEmpty) {
          return responses.first;
        } else {
          throw Exception('No response data received');
        }
      } else {
        final errorMsg = response.errorMessage ?? 'Failed to post PM item';
        throw Exception(errorMsg);
      }
    } catch (e) {
      rethrow;
    }
  }
}
