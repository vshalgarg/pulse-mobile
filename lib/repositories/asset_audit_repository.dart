import '../models/asset_audit_model.dart';
import '../models/asset_audit_post_model.dart';
import '../services/api_service.dart';
import '../database/asset_audit_database.dart';
import '../services/image_cache_service.dart';
import '../utils/logger.dart';

class AssetAuditRepository {
  final ApiService _apiService;
  final AssetAuditDatabase _database = AssetAuditDatabase();
  final ImageCacheService _imageCacheService = ImageCacheService();

  AssetAuditRepository({required ApiService apiService})
      : _apiService = apiService;

  Future<AssetAuditModel> getAssetAuditData({
    required String siteType,
    required String auditSchId,
    required String siteAuditSchId,
  }) async {
    final int siteAuditSchIdInt = int.parse(siteAuditSchId);
    
    Logger.debugLog('=== AssetAuditRepository: getAssetAuditData called ===');
    Logger.debugLog('Parameters: siteType=$siteType, auditSchId=$auditSchId, siteAuditSchId=$siteAuditSchId');
    
    // First, try to get data from SQLite database
    Logger.debugLog('🔍 Checking SQLite database for site $siteAuditSchIdInt');
    final cachedData = await _database.getAssetAuditData(siteAuditSchIdInt);
    if (cachedData != null) {
      Logger.debugLog('✅ Found cached data in SQLite, returning cached data');
      Logger.debugLog('Cached data - Page headers: ${cachedData.pageHeader.length}');
      Logger.debugLog('Cached data - Categories: ${cachedData.responseData.categories.length}');
      return cachedData;
    } else {
      Logger.debugLog('❌ No cached data found in SQLite for site $siteAuditSchIdInt');
    }
    
    Logger.debugLog('❌ No cached data found, fetching from API');
    
    // If no cached data, fetch from API
    final response = await _apiService.get<dynamic>(
      path: '/api/v1/mobile/assetAudit/PageData/$siteType/$auditSchId/$siteAuditSchId',
    );

    if (response.isSuccess && response.data != null) {
      Logger.debugLog('✅ API response successful, parsing data');
      final assetAuditData = AssetAuditModel.fromJson(response.data!);
      
      // Save to SQLite database
      Logger.debugLog('💾 Saving data to SQLite database');

      return assetAuditData;
    } else {
      final errorMsg = response.errorMessage ?? 'Failed to load asset audit data';
      Logger.errorLog('❌ Asset Audit API Error: $errorMsg');
      Logger.errorLog('Requested URL: /api/v1/mobile/assetAudit/PageData/$siteType/$auditSchId/$siteAuditSchId');
      Logger.errorLog('Parameters: siteType=$siteType, auditSchId=$auditSchId, siteAuditSchId=$siteAuditSchId');
      
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
      
      final requestsJsonList = await Future.wait(requests.map((request) => request.toJson()));
      final response = await _apiService.post<List<dynamic>>(
        path: '/api/v1/mobile/AssetAuditSiteResp',
        data: requestsJsonList,
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

  /// Save form data for a specific screen
  Future<void> saveFormData({
    required int siteAuditSchId,
    required String screenName,
    required Map<String, dynamic> formData,
  }) async {
    Logger.debugLog('Saving form data for site $siteAuditSchId, screen $screenName');
    await _database.saveFormData(siteAuditSchId, screenName, formData);
  }

  /// Get form data for a specific screen
  Future<Map<String, dynamic>?> getFormData({
    required int siteAuditSchId,
    required String screenName,
  }) async {
    Logger.debugLog('Getting form data for site $siteAuditSchId, screen $screenName');
    return await _database.getFormData(siteAuditSchId, screenName);
  }

  /// Get cached image data
  Future<String?> getCachedImage(int imageId) async {
    return await _imageCacheService.getCachedImage(imageId);
  }

  /// Check if image is cached
  Future<bool> isImageCached(int imageId) async {
    return await _imageCacheService.isImageCached(imageId);
  }

  /// Clear all data for a specific site
  Future<void> clearSiteData(int siteAuditSchId) async {
    Logger.debugLog('Clearing all data for site $siteAuditSchId');
    await _database.clearAssetAuditData(siteAuditSchId);
  }

  /// Clear all cached data
  Future<void> clearAllData() async {
    Logger.debugLog('Clearing all cached data');
    await _database.clearAllData();
  }
}
