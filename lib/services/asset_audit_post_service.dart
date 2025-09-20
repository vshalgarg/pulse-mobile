import 'dart:convert';

import 'package:app/models/location_model.dart';
import 'package:app/enum/activity_type_enum.dart';
import 'package:app/services/location_service.dart';
import 'package:app/services/service_locator.dart';
import 'package:app/utils.dart';
import 'package:app/utils/logger.dart';
import 'package:app/utils/data_transformation_helper.dart';
import 'package:app/utils/connectivity_helper.dart';

/// Service for posting asset audit data with photo ID replacement
/// This service handles replacing local unique_id photo IDs with server_id
/// and adding photo_taken_ts using the images table's created_at timestamp
class AssetAuditPostService {

  /// Post asset audit data with photo ID replacement
  /// This method replaces all photo_id values with server_id from images table
  /// and adds photo_taken_ts using the images table's created_at timestamp
  Future<void> postAssetAuditDataWithPhotoReplacement({
    required List<dynamic> requests,
    required ActivityTypeEnum activityType,
    required bool isLastPage,
  }) async {
    try {
      // Get current location with offline support
      LocationModel finalLocation;

      try {
        finalLocation = await LocationService.getCurrentLocation();
      } catch (e) {
        Logger.infoLog('Error getting location: $e');
        rethrow;
      }

      // Check internet connectivity
      final isConnected = await ConnectivityHelper.isConnected();
      Logger.infoLog("user is connected to internet: $isConnected");

      //create deep copy of requests so that actual data preserves
      List<dynamic> copiedRequests = jsonDecode(jsonEncode(requests));
      if(isConnected) {
        Logger.debugLog("User is connected to the internet, trying to post the data");
        try {
          await _processRequestsForImages(copiedRequests);
          Logger.debugLog("data after processing images: $copiedRequests");
        } catch(e){
          Logger.errorLog("smjh nhi aa rha $e");
        }
      } else {
        Logger.debugLog("User is not connected to the internet, saving data locally");
      }
      _updateMetadataInRequest(copiedRequests, finalLocation);
      _postRequestsIfConnectedOrSaveToSqlite(copiedRequests, isConnected, activityType, isLastPage);
    } catch (e) {
      Logger.errorLog(
        'AssetAuditPostService: Exception while posting data: $e',
      );
      rethrow;
    }
  }
  
  void _postRequestsIfConnectedOrSaveToSqlite(List<dynamic> requests, bool isConnected,
      ActivityTypeEnum activityType, bool isLastPage) async {
    String url = '/api/v1/mobile/';
    switch(activityType) {
      case ActivityTypeEnum.assetAudit : url += 'AssetAuditSiteResp';
        break;
      case ActivityTypeEnum.preventiveMaintenance : url += 'PmResponse';
        break;
      default: url += 'AssetAuditSiteResp';
      break;
    }
    url += '?status=${isLastPage ? 'COMPLETED' : 'IN-PROGRESS'}';
    if(isConnected) {
      try {
        await _postDataToApi(url, requests);
        return;
      } catch(e){}
    }
    Logger.infoLog("User is not connected to the internet, saving data in local db");
    bool isSaved = await ServiceLocator().pendingRequestService.savePendingRequest(
      requestId: 'asset_audit_${DateTime.now().millisecondsSinceEpoch}',
      url: url,
      headers: {},
      requestData: requests,
    );
    if(isSaved) {
      Logger.infoLog("Data saved to DB successfully");
    } else {
      throw Exception('Failed to save data to database');
    }
  }

  Future<void> _postDataToApi(String url, List<dynamic> requests) async {
    Logger.infoLog("User is connected to internet, posting data to API");
    final response = await ServiceLocator().apiService.post<List<dynamic>>(
      path: url,
      data: DataTransformationHelper.convertListToCamelCase(requests),
    );
    if (response.isSuccess && response.data != null) {
      Logger.infoLog("Data posted successfully");
    } else {
      throw Exception((response.errorMessage ?? 'Unknown error from server'));
    }
  }

  Future<void> syncRequestsWhenUserComesOnline(String url, List<dynamic> requests, String requestId) async {
    try {
      List<dynamic> copiedRequests = jsonDecode(jsonEncode(requests));
      await _processRequestsForImages(copiedRequests);
      await _postDataToApi(url, requests);
      await ServiceLocator().pendingRequestService.deleteRequest(requestId);
    } catch(e) {
      Logger.errorLog(e.toString());
    }
  }

  void _updateMetadataInRequest(List<dynamic> requests, LocationModel location) {
    final time = Utils.getCurrentDateTimeForAPICall();
    for(final request in requests) {
      request['localCreatedDt'] = time;
      request['localModifiedDt'] = time;
      request['longitude'] = location.longitude;
      request['latitude'] = location.latitude;
    }
  }

  Future<void> _processRequestsForImages(List<dynamic> requests) async {
    for(dynamic request in requests) {
      await _processRequestForImages(request);
    }
  }

  /// Process a single asset audit request
  /// Replaces photo_id with server_id and adds photo_taken_ts
  Future<dynamic> _processRequestForImages(dynamic request) async {
    Logger.infoLog("Processing request for images: $request" );
    try {
      // Check both snake_case and camelCase field names
      final photoId = request['photo_id'] ?? request['photoId'];

      // If no photo_id or photo_id is null/empty, return the request as-is
      if (photoId == null || photoId.toString().isEmpty) {
        return request;
      }

      // Check if photo_id is a unique_id (starts with LOCAL_IMAGE_ID_)
      if (photoId.toString().startsWith('LOCAL_IMAGE_ID_')) {
        // This is a unique_id, get the server_id using ImageUploadService

        final imageModel = await ServiceLocator().imageUploadService
            .getServerIdFromUniqueIdTryUploading(
              photoId.toString(),
            );
        if (imageModel != null) {
          final serverId = imageModel.serverId;
          final timestamp = Utils.getTmeFromMSForAPICall(imageModel.createdAt);
          request['photo_id'] = serverId;
          if (timestamp != null) {
            request['photo_taken_ts'] = timestamp;
          }
        } else {
          Logger.debugLog("FAILED to get server_id for LOCAL_IMAGE_ID: $photoId");
        }
      } else {
        // This is already a server_id, just add photo_taken_ts if not present
        if (request['photo_taken_ts'] == null ||
            request['photo_taken_ts'].toString().isEmpty) {
          final currentTime = Utils.getCurrentDateTimeForAPICall();
          request['photo_taken_ts'] = currentTime;
        }
        return request;
      }
    } catch (e) {
      Logger.errorLog("Error processing asset audit request: $e");
      return request;
    }
    Logger.infoLog("processAssetAuditRequest COMPLETED - returning: $request");
    return request;
  }
}
