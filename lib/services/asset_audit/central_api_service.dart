import 'dart:io';
import 'package:dio/dio.dart';
import '../api_service.dart';
import '../../utils/logger.dart';

class CentralAssetAuditApiService {
  final ApiService _apiService;

  CentralAssetAuditApiService({required ApiService apiService}) : _apiService = apiService;

  // ==================== MAIN ASSET AUDIT DATA ====================

  /// Fetch complete asset audit data
  Future<Map<String, dynamic>?> fetchAssetAuditData({
    required String siteType,
    required String auditSchId,
    required String siteAuditSchId,
  }) async {
    try {
      Logger.debugLog('🌐 Fetching complete asset audit data from API');
      
      final response = await _apiService.get<Map<String, dynamic>>(
        path: '/api/v1/mobile/assetAudit/PageData/$siteType/$auditSchId/$siteAuditSchId',
      );

      if (response.isSuccess && response.data != null) {
        Logger.debugLog('✅ Asset audit data fetched successfully');
        Logger.debugLog('📊 API Response keys: ${response.data!.keys.toList()}');
        Logger.debugLog('📊 API Response categories: ${response.data!['categories']}');
        Logger.debugLog('📊 API Response SPV: ${response.data!['categories']?['SPV']}');
        return response.data;
      } else {
        Logger.errorLog('❌ Failed to fetch asset audit data: ${response.errorMessage}');
        return null;
      }
    } catch (e) {
      Logger.errorLog('❌ Error fetching asset audit data: $e');
      return null;
    }
  }

  // ==================== SCREEN-SPECIFIC DATA ====================
  // Note: Screen-specific data should be extracted from the main asset audit data
  // No separate API calls should be made during the flow
  // All data is fetched once at the start when selecting a ticket

  // ==================== IMAGE OPERATIONS ====================

  /// Fetch image from API
  Future<String?> fetchImage(int imageId) async {
    try {
      Logger.debugLog('🖼️ Fetching image $imageId from API');
      
      final response = await _apiService.get<Map<String, dynamic>>(
        path: '/api/v1/mobile/assetAudit/GetImage/$imageId',
      );

      if (response.isSuccess && response.data != null) {
        final imageData = response.data!['imageData'] as String?;
        if (imageData != null && imageData.isNotEmpty) {
          Logger.debugLog('✅ Image $imageId fetched successfully');
          return imageData;
        } else {
          Logger.errorLog('❌ Empty image data received for image $imageId');
          return null;
        }
      } else {
        Logger.errorLog('❌ Failed to fetch image $imageId: ${response.errorMessage}');
        return null;
      }
    } catch (e) {
      Logger.errorLog('❌ Error fetching image $imageId: $e');
      return null;
    }
  }

  /// Upload image
  Future<String?> uploadImage({
    required String siteType,
    required String auditSchId,
    required String siteAuditSchId,
    required String imagePath,
    required String serialNumber,
    required String screenType, // 'spv', 'pcu', 'inverter', etc.
  }) async {
    try {
      Logger.debugLog('📤 Uploading image for $screenType serial $serialNumber');
      Logger.debugLog('📤 Image path: $imagePath');

      // Create multipart file
      final file = File(imagePath);
      if (!await file.exists()) {
        Logger.errorLog('❌ Image file does not exist: $imagePath');
        return null;
      }

      final multipartFile = await MultipartFile.fromFile(
        file.path,
        filename: file.path.split('/').last,
      );

      // Create data map with form fields
      final dataMap = <String, dynamic>{
        'imgFile': multipartFile,
        'activityType': 'AA', // Required parameter for Asset Audit (AA = Asset Audit)
        'serialNumber': serialNumber,
        'screenType': screenType,
        'siteType': siteType,
        'auditSchId': auditSchId,
        'siteAuditSchId': siteAuditSchId,
      };

      Logger.debugLog('📤 Uploading with data keys: ${dataMap.keys}');

      final result = await _apiService.post<Map<String, dynamic>>(
        path: "api/v1/mobile/uploads",
        data: dataMap,
        useFormDataFormat: true,
      );

      if (result.isSuccess && result.data != null) {
        // Extract photo ID from response
        final photoId = result.data!['imgId']?.toString() ?? 
                       result.data!['photoId']?.toString() ??
                       result.data!['id']?.toString();
        
        if (photoId != null && photoId.isNotEmpty) {
          Logger.debugLog('✅ Image uploaded successfully with ID: $photoId');
          return photoId;
        } else {
          Logger.errorLog('❌ No photo ID returned in response: ${result.data}');
          return null;
        }
      } else {
        Logger.errorLog('❌ Failed to upload image: ${result.errorMessage}');
        return null;
      }
    } catch (e) {
      Logger.errorLog('❌ Error uploading image: $e');
      return null;
    }
  }

  // ==================== POST OPERATIONS ====================

  /// Post form data for any screen
  Future<bool> postFormData({
    required String siteType,
    required String auditSchId,
    required String siteAuditSchId,
    required String screenType,
    required Map<String, dynamic> formData,
  }) async {
    try {
      Logger.debugLog('📤 Posting $screenType form data to API');
      
      final response = await _apiService.post<Map<String, dynamic>>(
        path: '/api/v1/mobile/assetAudit/Post${screenType.toUpperCase()}Data/$siteType/$auditSchId/$siteAuditSchId',
        data: formData,
      );

      if (response.isSuccess) {
        Logger.debugLog('✅ $screenType form data posted successfully');
        return true;
      } else {
        Logger.errorLog('❌ Failed to post $screenType form data: ${response.errorMessage}');
        return false;
      }
    } catch (e) {
      Logger.errorLog('❌ Error posting $screenType form data: $e');
      return false;
    }
  }

  /// Post complete data for any screen
  Future<bool> postCompleteData({
    required String siteType,
    required String auditSchId,
    required String siteAuditSchId,
    required String screenType,
    required List<Map<String, dynamic>> items,
  }) async {
    try {
      Logger.debugLog('📤 Posting complete $screenType data to API');
      
      final response = await _apiService.post<Map<String, dynamic>>(
        path: '/api/v1/mobile/assetAudit/PostComplete${screenType.toUpperCase()}Data/$siteType/$auditSchId/$siteAuditSchId',
        data: {
          'items': items,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      if (response.isSuccess) {
        Logger.debugLog('✅ Complete $screenType data posted successfully');
        return true;
      } else {
        Logger.errorLog('❌ Failed to post complete $screenType data: ${response.errorMessage}');
        return false;
      }
    } catch (e) {
      Logger.errorLog('❌ Error posting complete $screenType data: $e');
      return false;
    }
  }

  // ==================== SPECIFIC SCREEN POSTS ====================

  /// Post SPV data
  Future<bool> postSPVData({
    required String siteType,
    required String auditSchId,
    required String siteAuditSchId,
    required Map<String, dynamic> formData,
  }) async {
    return await postFormData(
      siteType: siteType,
      auditSchId: auditSchId,
      siteAuditSchId: siteAuditSchId,
      screenType: 'spv',
      formData: formData,
    );
  }

  /// Post PCU data
  Future<bool> postPCUData({
    required String siteType,
    required String auditSchId,
    required String siteAuditSchId,
    required Map<String, dynamic> formData,
  }) async {
    return await postFormData(
      siteType: siteType,
      auditSchId: auditSchId,
      siteAuditSchId: siteAuditSchId,
      screenType: 'pcu',
      formData: formData,
    );
  }

  /// Post Inverter data
  Future<bool> postInverterData({
    required String siteType,
    required String auditSchId,
    required String siteAuditSchId,
    required Map<String, dynamic> formData,
  }) async {
    return await postFormData(
      siteType: siteType,
      auditSchId: auditSchId,
      siteAuditSchId: siteAuditSchId,
      screenType: 'inverter',
      formData: formData,
    );
  }

  // ==================== BULK OPERATIONS ====================

  /// Post all asset audit data at once
  Future<bool> postAllAssetAuditData({
    required String siteType,
    required String auditSchId,
    required String siteAuditSchId,
    required Map<String, dynamic> completeData,
  }) async {
    try {
      Logger.debugLog('📤 Posting all asset audit data to API');
      
      final response = await _apiService.post<Map<String, dynamic>>(
        path: '/api/v1/mobile/assetAudit/PostAllData/$siteType/$auditSchId/$siteAuditSchId',
        data: completeData,
      );

      if (response.isSuccess) {
        Logger.debugLog('✅ All asset audit data posted successfully');
        return true;
      } else {
        Logger.errorLog('❌ Failed to post all asset audit data: ${response.errorMessage}');
        return false;
      }
    } catch (e) {
      Logger.errorLog('❌ Error posting all asset audit data: $e');
      return false;
    }
  }

  /// Sync all offline data
  Future<bool> syncOfflineData({
    required String siteType,
    required String auditSchId,
    required String siteAuditSchId,
    required Map<String, dynamic> offlineData,
  }) async {
    try {
      Logger.debugLog('🔄 Syncing offline data to API');
      
      final response = await _apiService.post<Map<String, dynamic>>(
        path: '/api/v1/mobile/assetAudit/SyncOfflineData/$siteType/$auditSchId/$siteAuditSchId',
        data: {
          'offlineData': offlineData,
          'syncTimestamp': DateTime.now().toIso8601String(),
        },
      );

      if (response.isSuccess) {
        Logger.debugLog('✅ Offline data synced successfully');
        return true;
      } else {
        Logger.errorLog('❌ Failed to sync offline data: ${response.errorMessage}');
        return false;
      }
    } catch (e) {
      Logger.errorLog('❌ Error syncing offline data: $e');
      return false;
    }
  }
}
