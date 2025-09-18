import 'package:app/models/asset_audit_post_model.dart';
import 'package:app/services/api_service.dart';
import 'package:app/services/image_upload_service.dart';
import 'package:app/enum/activity_type_enum.dart';
import 'package:app/utils.dart';
import 'package:app/utils/logger.dart';

/// Service for posting asset audit data with photo ID replacement
/// This service handles replacing local unique_id photo IDs with server_id
/// and adding photo_taken_ts using the images table's created_at timestamp
class AssetAuditPostService {
  final ApiService _apiService;
  final ImageUploadService _imageUploadService;

  AssetAuditPostService({
    required ApiService apiService,
    required ImageUploadService imageUploadService,
  }) : _apiService = apiService, _imageUploadService = imageUploadService;

  /// Post asset audit data with photo ID replacement
  /// This method replaces all photo_id values with server_id from images table
  /// and adds photo_taken_ts using the images table's created_at timestamp
  Future<void> postAssetAuditDataWithPhotoReplacement({
    required List<dynamic> requests,
  }) async {
    try {
      Logger.debugLog('📤 AssetAuditPostService: Processing ${requests.length} asset audit items');
      
      // Process each request to replace photo IDs and add timestamps
      final List<dynamic> processedRequests = [];

      for (int i = 0; i < requests.length; i++) {
        final processedRequest = await _processAssetAuditRequest(requests[i]);
          processedRequest['localCreatedDt'] =  Utils.getCurrentDateTimeForAPICall();
          processedRequest['localModifiedDt'] =  Utils.getCurrentDateTimeForAPICall();
          processedRequests.add(processedRequest);
      }
      
      Logger.debugLog('📤 AssetAuditPostService: Posting processed requests to API');
      
      // Post the processed requests to the API
      final response = await _apiService.post<List<dynamic>>(
        path: '/api/v1/mobile/AssetAuditSiteResp',
        data: processedRequests,
      );

      if (response.isSuccess && response.data != null) {
        Logger.infoLog("Data posted successfully");
      } else {
        final errorMsg = response.errorMessage ?? 'Failed to post asset audit data';
        Logger.errorLog('❌ Asset Audit POST API Error: $errorMsg');
      }
    } catch (e) {
      Logger.errorLog('❌ AssetAuditPostService: Exception while posting data: $e');
      rethrow;
    }
  }

  /// Process a single asset audit request
  /// Replaces photo_id with server_id and adds photo_taken_ts
  Future<dynamic> _processAssetAuditRequest(dynamic request) async {
    dynamic updatedRequest = {...request as Map<String, dynamic>};
    try {
      // If no photo_id, return the request as-is
      if (updatedRequest['photo_id'] == null) {
        Logger.debugLog('📝 No photo_id to process for request: ${updatedRequest['nexgen_serial_no']}');
        return updatedRequest;
      }

      final photoId = request['photo_id'];
      Logger.debugLog('🔍 Processing photo_id: $photoId for serial: ${updatedRequest['nexgen_serial_no']}');

      // Check if photo_id is a unique_id (starts with LOCAL_IMAGE_ID_)
      if (photoId.toString().startsWith('LOCAL_IMAGE_ID_')) {
        // This is a unique_id, get the server_id using ImageUploadService
        final serverIdWithCreatedTime = await _imageUploadService.getServerIdAndCreatedTime(
          photoId.toString(),
          ActivityTypeEnum.assetAudit,
          updatedRequest['site_audit_sch_id'].toString(),
        );
        
        if (serverIdWithCreatedTime.isNotEmpty) {
          updatedRequest['photo_id'] = serverIdWithCreatedTime.first;
          updatedRequest['photo_taken_ts'] = serverIdWithCreatedTime.elementAt(1);
          
          Logger.debugLog('✅ Replaced unique_id $photoId with server_id ${serverIdWithCreatedTime.first}');
          Logger.debugLog('📅 Photo taken timestamp: ${serverIdWithCreatedTime.elementAt(1)}');
        } else {
          Logger.debugLog('⚠️ No server_id found for unique_id: $photoId');
        }
      } else {
        // This is already a server_id, just add photo_taken_ts if not present
        if (updatedRequest['photo_taken_ts'] == null || updatedRequest['photo_taken_ts'].toString().isEmpty) {
          final currentTime = Utils.getCurrentDateTimeForAPICall();
          updatedRequest['photo_taken_ts'] = currentTime;
          Logger.debugLog('📅 Added current timestamp for server_id: $photoId');
        }
        return updatedRequest;
      }
    } catch (e) {
      Logger.errorLog('❌ Error processing asset audit request: $e');
      return request;
    }
    return updatedRequest;
  }

}
