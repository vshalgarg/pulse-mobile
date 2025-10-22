import 'dart:convert';
import 'dart:io';

import 'dart:typed_data';
import 'package:app/models/location_model.dart';
import 'package:app/enum/activity_type_enum.dart';
import 'package:app/repositories/auth_repository.dart';
import 'package:app/services/location_service.dart';
import 'package:app/services/service_locator.dart';
import 'package:app/utils.dart';
import 'package:app/utils/logger.dart';
import 'package:app/utils/data_transformation_helper.dart';
import 'package:app/utils/connectivity_helper.dart';
import 'package:app/utils/toastbar.dart';
import 'package:dio/dio.dart';

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
        print("Error getting location: $e");
        Toastbar.showErrorWithoutContext(
          "Please enable your location first to proceed further.",
        );

        rethrow;
      }
      // Check internet connectivity
      final isConnected = await ConnectivityHelper.isConnected();
      Logger.infoLog("user is connected to internet: $isConnected");

      //create deep copy of requests so that actual data preserves
      List<dynamic> copiedRequests = jsonDecode(jsonEncode(requests));
      if (isConnected) {
        Logger.debugLog(
          "User is connected to the internet, trying to post the data",
        );

        try {
          await _processRequestsForImages(copiedRequests);
          Logger.debugLog("data after processing images: $copiedRequests");
        } catch (e) {
          Logger.errorLog("error in processing images: $e");
        }
      } else {
        Logger.debugLog(
          "User is not connected to the internet, saving data locally",
        );
      }
      DataTransformationHelper.updateMetadataInRequest(
        copiedRequests,
        finalLocation,
      );
      _postRequestsIfConnectedOrSaveToSqlite(
        copiedRequests,
        isConnected,
        activityType,
        isLastPage,
      );
    } catch (e) {
      Logger.errorLog(
        'AssetAuditPostService: Exception while posting data: $e',
      );
      print("error in posting data: $e");
      rethrow;
    }
  }

  void _postRequestsIfConnectedOrSaveToSqlite(
    List<dynamic> requests,
    bool isConnected,
    ActivityTypeEnum activityType,
    bool isLastPage,
  ) async {
    String url = '/api/v1/mobile/';
    switch (activityType) {
      case ActivityTypeEnum.assetAudit:
        url += 'AssetAuditSiteResp';
        break;
      case ActivityTypeEnum.preventiveMaintenance:
        url += 'PmResponse';
        break;
      case ActivityTypeEnum.energyReading:
        url += 'EbBillReading';
        break;

      case ActivityTypeEnum.correctiveMaintenance:
        url += 'correctiveMaintenance';
        break;
      case ActivityTypeEnum.siteVisit:
        url = 'api/v1/om-schedule/siteVisitLog';
        break;
      case ActivityTypeEnum.generalInspection:
        url = 'api/v1/om-schedule/genInspection';
        break;
      default:
        throw Exception('Invalid activity type: $activityType');
    }

    if (activityType == ActivityTypeEnum.siteVisit || activityType == ActivityTypeEnum.generalInspection) {
      // These endpoints don't need the status parameter
      // URL is already set in the switch statement
    } else {
      url += '?status=${isLastPage ? 'COMPLETED' : 'IN-PROGRESS'}';
    }
    if (isConnected) {
      try {
        await _postDataToApi(url, requests);
        return;
      } catch (e) {
        Logger.errorLog("error in posting data: $e");
        print("error in posting data: $e");
      }
    }
    Logger.infoLog(
      "User is not connected to the internet, saving data in local db",
    );
    bool isSaved = await ServiceLocator().pendingRequestService
        .savePendingRequest(
          requestId: 'asset_audit_${DateTime.now().millisecondsSinceEpoch}',
          url: url,
          headers: {},
          jsonEncodedRequestData: jsonEncode(requests),
        );
    if (isSaved) {
      Logger.infoLog("Data saved to DB successfully");
      print("Data saved to DB successfully");

      Toastbar.showSuccessToastWithoutContext("Data saved to DB successfully");
    } else {
      print("Failed to save data to database");
      throw Exception('Failed to save data to database');
    }
  }

  Future<void> _postDataToApi(String url, List<dynamic> requests) async {
    Logger.infoLog("User is connected to internet, posting data to API");
    final response;
    if (url.contains("api/v1/mobile/uploadsSelfie")) {
      response = await _uploadSelfieWithoutCache(requests);
    } else if (url.contains("api/v1/om-schedule/siteVisitLog")) {
      // For site visit logs, send as single object instead of array
      response = await ServiceLocator().apiService.post<dynamic>(
        path: url,
        data: requests.isNotEmpty ? requests.first : {},
      );
    } else {
      response = await ServiceLocator().apiService.post<List<dynamic>>(
        path: url,
        data: DataTransformationHelper.convertListToCamelCase(requests),
      );
    }
    if (response != null && response.isSuccess && response.data != null) {
      Toastbar.showSuccessToastWithoutContext("Data posted successfully");
      Logger.infoLog("Data posted successfully");
    } else {
      throw Exception((response.errorMessage ?? 'Unknown error from server'));
    }
  }

  Future<dynamic> _uploadSelfieWithoutCache(List<dynamic> requests) async {
    try {
      Uint8List imageBytes;
      dynamic decodedRequest = requests.first;
      String imageData = decodedRequest['selfie'];
      if (imageData.startsWith('data:image/')) {
        // Remove data URL prefix
        final base64String = imageData.split(',')[1];
        imageBytes = base64Decode(base64String);
      } else {
        // Assume it's raw base64
        imageBytes = base64Decode(imageData);
      }

      // Create a temporary file for upload
      final tempDir = Directory.systemTemp;
      final tempFile = File(
        '${tempDir.path}/temp_image_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await tempFile.writeAsBytes(imageBytes);

      // Create multipart file
      final multipartFile = await MultipartFile.fromFile(
        tempFile.path,
        filename: 'image_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      decodedRequest['selfie'] = multipartFile;
      final response = await ServiceLocator().apiService
          .post<Map<String, dynamic>>(
            path: "api/v1/mobile/uploadsSelfie",
            data: decodedRequest,
            useFormDataFormat: true,
          );
      return response;
    } catch (e) {
      return null;
    }
  }

  Future<void> syncRequestsWhenUserComesOnline(
    String url,
    List<dynamic> requests,
    String requestId,
  ) async {
    try {
      List<dynamic> copiedRequests = jsonDecode(jsonEncode(requests));
      await _processRequestsForImages(copiedRequests);
      await _postDataToApi(url, copiedRequests);
      await ServiceLocator().pendingRequestService.deleteRequest(requestId);
    } catch (e) {
      Logger.errorLog(e.toString());
    }
  }

  Future<void> _processRequestsForImages(List<dynamic> requests) async {
    for (dynamic request in requests) {
      await _processRequestForImages(request);
    }
  }

  /// Replaces photo_id with server_id and adds photo_taken_ts
  Future<dynamic> _processRequestForImages(dynamic request) async {
    Logger.infoLog("Processing request for images: $request");

    try {
      // Check if request is a List, if so, process each item
      if (request is List) {
        for (int i = 0; i < request.length; i++) {
          request[i] = await _processSingleRequest(request[i]);
        }
        return request;
      }

      // Process single request
      return await _processSingleRequest(request);
    } catch (e) {
      Logger.errorLog("Error processing asset audit request: $e");
      return request;
    }
  }

  Future<dynamic> _processSingleRequest(dynamic request) async {
    try {
      // Check if request is a Map
      if (request is! Map) {
        return request; // Not a Map, return as-is
      }

      // Check both snake_case and camelCase field names
      String? photoId = "";

      if (request.containsKey("energyReadingId")) {
        photoId = request['ebAttachmentFileId'];
      } else if (request.containsKey("visitingPersonName")) {
        photoId = request['visitingPersonImageId'];
      } else {
        photoId = request['photo_id'] ?? request['photoId'];
      }

      print("photoId: $photoId");

      // If no photo_id or photo_id is null/empty, return the request as-is
      if (photoId == null || photoId.toString().isEmpty) {
        return request;
      }

      // Check if photo_id is a unique_id (starts with LOCAL_IMAGE_ID_)
      if (photoId.toString().startsWith('LOCAL_IMAGE_ID_')) {
        // This is a unique_id, get the server_id using ImageUploadService

        final imageModel = await ServiceLocator().imageUploadService
            .getServerIdFromUniqueIdTryUploading(photoId.toString());
        if (imageModel != null) {
          final serverId = imageModel.serverId;
          print("serverId: $serverId");
          final timestamp = Utils.getTmeFromMSForAPICall(imageModel.createdAt);

          if (request.containsKey("energyReadingId")) {
            request['ebAttachmentFileId'] = serverId;
          } else if (request.containsKey("visitingPersonName")) {
            request['visitingPersonImageId'] = serverId;
          } else {
            request['photo_id'] = serverId;
          }

          if (timestamp != null) {
            request['photo_taken_ts'] = timestamp;
          }
        } else {
          Logger.debugLog(
            "FAILED to get server_id for LOCAL_IMAGE_ID: $photoId",
          );
          print("FAILED to get server_id for LOCAL_IMAGE_ID: $photoId");
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
      Logger.errorLog("Error processing single request: $e");
      print("Error processing single request: $e");
      return request;
    }
    Logger.infoLog("processAssetAuditRequest COMPLETED - returning: $request");
    print("processAssetAuditRequest COMPLETED - returning: $request");
    return request;
  }
}
