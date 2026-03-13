import 'dart:convert';
import 'dart:io';

import 'dart:typed_data';
import 'package:app/models/location_model.dart';
import 'package:app/enum/activity_type_enum.dart';
import 'package:app/services/location_service.dart';
import 'package:app/services/service_locator.dart';
import 'package:app/utils.dart';
import 'package:app/utils/logger.dart';
import 'package:app/utils/data_transformation_helper.dart';
import 'package:app/utils/connectivity_helper.dart';
import 'package:app/utils/toastbar.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';

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
    // Prevent posting empty arrays to avoid server errors
    if (requests.isEmpty) {
      Logger.errorLog(
        '❌ AssetAuditPostService: Attempted to post empty array, aborting to prevent server error',
      );
      Logger.errorLog(
        '❌ This indicates a bug in the calling code - empty arrays should be filtered before calling this service',
      );
      return;
    }

    try {
      // Get current location with offline support
      LocationModel finalLocation;

      try {
        finalLocation = await LocationService.getCurrentLocation();
      } catch (e) {
        Logger.infoLog('Error getting location: $e');

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
      case ActivityTypeEnum.incident:
        url = 'api/v1/om-schedule/incident';
        break;
      case ActivityTypeEnum.assetUpload:
        url += 'AssetAuditSiteResp';
        break;
    }

    if (activityType == ActivityTypeEnum.siteVisit ||
        activityType == ActivityTypeEnum.generalInspection) {
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

      Toastbar.showSuccessToastWithoutContext(
        "Data submission failed. Don’t worry—your data has been saved on this device and can be synced when you’re back online.",
      );
    } else {
      throw Exception('Failed to save data to database');
    }
  }

  Future<void> _postDataToApi(String url, List<dynamic> requests) async {
    Logger.infoLog("User is connected to internet, posting data to API");
    final response;
    if (url.contains("api/v1/mobile/uploadsSelfie")) {
      response = await _uploadSelfieWithoutCache(requests);
    } else if (url.contains("api/v1/om-schedule/siteVisitLog") ||
        url.contains("api/v1/om-schedule/genInspection") ||
        url.contains("api/v1/om-schedule/incidentTicket") ||
        url.contains("api/v1/mobile/assetUpload") ||
        url.contains("/assetUpload")) {
      // These endpoints expect a single object, not an array
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
      Toastbar.showErrorWithoutContext(
        "Data posted failed for url",
      );
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

      // Special handling for CM requests
      if (url.contains('/correctiveMaintenance')) {
        await _syncCMRequestWhenOnline(copiedRequests, requestId);
        return;
      } else if (url.contains('/cmRemarks/upload')) {
        // Handle remarks upload separately
        await _syncCMRemarksRequestWhenOnline(copiedRequests, requestId);
        return;
      } else if (url.contains('/incidentTicket')) {
        // Special handling for incident tickets - expects single object, not array
        await _syncIncidentTicketRequestWhenOnline(copiedRequests, requestId);
        return;
      } else if (url.contains('api/v1/mobile/assetUpload') || url.contains('assetUpload')) {
        // Special handling for asset upload - expects single object, not array
        await _syncAssetUploadRequestWhenOnline(copiedRequests, requestId);
        return;
      } else {
        await _processRequestsForImages(copiedRequests);
        await _postDataToApi(url, copiedRequests);
        await ServiceLocator().pendingRequestService.deleteRequest(requestId);
      }
    } catch (e) {
      Logger.errorLog(e.toString());
      rethrow;
    }
  }

  Future<void> _syncIncidentTicketRequestWhenOnline(
    List<dynamic> requests,
    String requestId,
  ) async {
    try {
      Logger.infoLog("Syncing incident ticket request when online");

      if (requests.isEmpty) {
        Logger.errorLog("Incident ticket requests list is empty!");
        return;
      }

      final request = requests.first;
      Logger.infoLog("Processing incident ticket request: ${request.keys}");

      // Process images in the request (convert LOCAL_IMAGE_ID to server ID)
      // This will update the request object in place
      await _processRequestsForImages([request]);

      Logger.infoLog("Processed incident ticket data after image processing");

      // Post to API - send as single object (not array)
      final response = await ServiceLocator().apiService.post<dynamic>(
        path: '/api/v1/om-schedule/incidentTicket',
        data: request, // Send single object, not array
      );

      if (response.isSuccess && response.data != null) {
        Logger.infoLog("Incident ticket synced successfully: ${response.data}");
        Toastbar.showSuccessToastWithoutContext(
          "Incident ticket synced successfully",
        );

        // Delete from pending requests on success
        await ServiceLocator().pendingRequestService.deleteRequest(requestId);
      } else {
        throw Exception(response.errorMessage ?? 'Unknown error from server');
      }
    } catch (e) {
      Logger.errorLog("Error syncing incident ticket request: $e");
      rethrow;
    }
  }

  Future<void> _syncAssetUploadRequestWhenOnline(
    List<dynamic> requests,
    String requestId,
  ) async {
    try {
      Logger.infoLog("Syncing asset upload request when online");

      if (requests.isEmpty) {
        Logger.errorLog("Asset upload requests list is empty!");
        return;
      }

      final request = requests.first as Map<String, dynamic>;
      Logger.infoLog("Processing asset upload request: ${request.keys}");

      // Process makerSelfieImageId - replace LOCAL_IMAGE_ID with server ID
      final makerSelfieImageId = request['makerSelfieImageId'];
      if (makerSelfieImageId != null &&
          makerSelfieImageId.toString().startsWith('LOCAL_IMAGE_ID_')) {
        Logger.debugLog(
          '🔄 Processing makerSelfieImageId: $makerSelfieImageId',
        );

        final imageModel = await ServiceLocator().imageUploadService
            .getServerIdFromUniqueIdTryUploading(makerSelfieImageId.toString());

        if (imageModel != null && imageModel.serverId != null) {
          final serverId = int.tryParse(imageModel.serverId.toString()) ?? 0;
          request['makerSelfieImageId'] = serverId;
          Logger.debugLog(
            '✅ makerSelfieImageId replaced with server ID: $serverId',
          );
        } else {
          Logger.errorLog(
            '❌ Failed to upload selfie image: $makerSelfieImageId',
          );
          request['makerSelfieImageId'] = null;
        }
      }

      // Process assetUploadItems[].assetUploadItemImages[].photoId
      final assetUploadItems = request['assetUploadItems'] as List<dynamic>?;
      if (assetUploadItems != null) {
        for (final item in assetUploadItems) {
          if (item is Map<String, dynamic>) {
            final assetUploadItemImages =
                item['assetUploadItemImages'] as List<dynamic>?;
            if (assetUploadItemImages != null) {
              for (final image in assetUploadItemImages) {
                if (image is Map<String, dynamic>) {
                  final photoId = image['photoId'];
                  if (photoId != null &&
                      photoId.toString().startsWith('LOCAL_IMAGE_ID_')) {
                    Logger.debugLog(
                      '🔄 Processing asset image photoId: $photoId',
                    );

                    final imageModel = await ServiceLocator().imageUploadService
                        .getServerIdFromUniqueIdTryUploading(
                          photoId.toString(),
                        );

                    if (imageModel != null && imageModel.serverId != null) {
                      final serverId =
                          int.tryParse(imageModel.serverId.toString()) ?? 0;
                      image['photoId'] = serverId;
                      Logger.debugLog(
                        '✅ Asset image photoId replaced with server ID: $serverId',
                      );
                    } else {
                      Logger.errorLog(
                        '❌ Failed to upload asset image: $photoId',
                      );
                      image['photoId'] = null;
                    }
                  }
                }
              }
            }
          }
        }
      }

      // Post to API - send as single object (not array)
      final response = await ServiceLocator().apiService.post<dynamic>(
        path: 'api/v1/mobile/assetUpload',
        data: request, // Send single object, not array
      );

      if (response.isSuccess && response.data != null) {
        Logger.infoLog("Asset upload synced successfully: ${response.data}");
        Toastbar.showSuccessToastWithoutContext(
          "Asset upload synced successfully",
        );

        // Delete from pending requests on success
        await ServiceLocator().pendingRequestService.deleteRequest(requestId);
      } else {

        Toastbar.showErrorWithoutContext(
          "Asset upload failed: ${response.errorMessage}",
        );
        throw Exception(response.errorMessage ?? 'Unknown error from server');
        
      }
    } catch (e) {
      Logger.errorLog("Error syncing asset upload request: $e");
      Toastbar.showErrorWithoutContext(
        "Asset upload failed: ${e.toString()}",
      );
      rethrow;
    }
  }

  Future<void> _syncCMRequestWhenOnline(
    List<dynamic> requests,
    String requestId,
  ) async {
    try {
      Logger.infoLog("Syncing CM request when online");

      if (requests.isEmpty) {
        Logger.errorLog("CM requests list is empty!");
        return;
      }

      final request = requests.first as Map<String, dynamic>;
      Logger.infoLog("Processing CM request: ${request.keys}");

      // Convert to camelCase first (creates a deep copy), then process images on that copy.
      // We must replace LOCAL_IMAGE_ID on the same object we send, else the copy still has old values.
      final processedData = DataTransformationHelper.convertKeysToCamelCase(
        request,
      );

      // Upload all LOCAL_IMAGE_ID photos and replace with server IDs in processedData (the payload we send).
      await _processCMRequestForImages(processedData);

      // Extract image IDs before removing them from the request
      final customerPhotoId =
          processedData['customer_photo_id'] ??
          processedData['customerPhotoId'];
      final customerAttachmentId =
          processedData['customer_attachment_id'] ??
          processedData['customerAttachmentId'];
      final fsrAttachmentId =
          processedData['fsr_attachment_id'] ??
          processedData['fsrAttachmentId'];

      // Extract original file info for customer attachment (to preserve filename)
      // Support both snake_case (raw stored) and camelCase (after convertKeysToCamelCase)
      final customerOriginalFilePath =
          processedData['customer_original_file_path'] ??
          processedData['customerOriginalFilePath'];
      final customerOriginalFileName =
          processedData['customer_original_file_name'] ??
          processedData['customerOriginalFileName'];

      // Extract FSR attachment file info
      final fsrOriginalFilePath =
          processedData['fsr_original_file_path'] ??
          processedData['fsrOriginalFilePath'];
      final fsrOriginalFileName =
          processedData['fsr_original_file_name'] ??
          processedData['fsrOriginalFileName'] ??
          processedData['fsrAttachmentName'] ??
          processedData['fsr_attachment_name'];

      // Extract attachment name if present, or use original filename
      final customerAttachmentName =
          processedData['customer_attachmen_name'] ??
          processedData['customer_attachment_name'] ??
          customerOriginalFileName;

      Logger.infoLog(
        "Extracted image IDs - customerPhotoId: $customerPhotoId, customerAttachmentId: $customerAttachmentId, fsrAttachmentId: $fsrAttachmentId",
      );
      Logger.infoLog(
        "Extracted attachment names - customerAttachmentName: $customerAttachmentName, fsrAttachmentName: $fsrOriginalFileName",
      );

      // Remove image IDs and file info from the request data before creating CM ticket
      processedData.remove('customer_photo_id');
      processedData.remove('customerPhotoId');
      processedData.remove('customer_attachment_id');
      processedData.remove('customerAttachmentId');
      processedData.remove('customer_original_file_path');
      processedData.remove('customer_original_file_name');
      processedData.remove('customer_attachmen_name');
      processedData.remove('customer_attachment_name');
      processedData.remove('fsr_attachment_id');
      processedData.remove('fsrAttachmentId');
      processedData.remove('fsr_original_file_path');
      processedData.remove('fsr_original_file_name');
      processedData.remove('fsr_attachment_name');
      processedData.remove('fsrAttachmentName');

      // Preserve attachment name in request data if we have it (for API to store the correct name)
      if (customerAttachmentName != null &&
          customerAttachmentName.toString().trim().isNotEmpty) {
        processedData['customer_attachmen_name'] = customerAttachmentName
            .toString()
            .trim();
        processedData['customer_attachment_name'] = customerAttachmentName
            .toString()
            .trim();
      }

      // Create CM ticket using the repository
      final response = await ServiceLocator().cmRepository
          .createCorrectiveMaintenance(processedData);

      Logger.infoLog("CM ticket creation response received: ${response.keys}");

      if (response.containsKey('cmSiteReqId')) {
        final cmSiteReqId = response['cmSiteReqId'] as int;

        Logger.infoLog("CM ticket created with ID: $cmSiteReqId");

        // Upload customer photo and attachments using the extracted IDs
        Logger.infoLog("About to call _uploadCMImagesAndAttachments...");
        Logger.infoLog(
          "customerPhotoId: $customerPhotoId, customerAttachmentId: $customerAttachmentId, fsrAttachmentId: $fsrAttachmentId",
        );
        await _uploadCMImagesAndAttachments(
          customerPhotoId,
          customerAttachmentId,
          cmSiteReqId,
          customerOriginalFilePath: customerOriginalFilePath,
          customerOriginalFileName: customerOriginalFileName,
          fsrAttachmentId: fsrAttachmentId,
          fsrOriginalFilePath: fsrOriginalFilePath,
          fsrOriginalFileName: fsrOriginalFileName,
        );

        // Check for and sync remarks if present
        final cmRemark =
            processedData['cmRemark'] ?? processedData['cm_remark'] ?? '';
        final cmStatus =
            processedData['cmStatus'] ?? processedData['cm_status'] ?? '';
        final cmAttachmentId =
            processedData['cmRemarksFile'] ??
            processedData['cm_remarks_file'] ??
            processedData['cmAttachmentId'] ??
            processedData['cm_attachment_id'];

        if ((cmRemark.toString().trim().isNotEmpty ||
                cmStatus.toString().trim().isNotEmpty) &&
            cmAttachmentId != null &&
            cmAttachmentId.toString().trim().isNotEmpty) {
          Logger.infoLog(
            "Syncing CM remarks with attachment ID: $cmAttachmentId",
          );

          // Get attachment file - try original file first, then reconstruct from ImageUploadService
          File? attachmentFile;
          String?
          attachmentFileName; // Store the filename to pass to saveRemarks

          // Check if original file path is stored (preserves extension and filename)
          // Handle both camelCase and snake_case
          final originalFilePath =
              processedData['originalFilePath'] ??
              processedData['original_file_path'];
          final originalFileName =
              processedData['originalFileName'] ??
              processedData['original_file_name'];

          if (originalFilePath != null &&
              originalFilePath.toString().trim().isNotEmpty) {
            final originalFile = File(originalFilePath.toString());
            if (await originalFile.exists()) {
              Logger.infoLog("Using original file: $originalFilePath");
              attachmentFile = originalFile;
              // Use original filename if available, otherwise use file path
              attachmentFileName =
                  originalFileName?.toString().trim() ??
                  originalFile.path.split('/').last;
            } else {
              Logger.infoLog(
                "Original file not found, will reconstruct from ImageUploadService",
              );
            }
          }

          // If original file not available, reconstruct from ImageUploadService
          if (attachmentFile == null) {
            Logger.infoLog(
              "Retrieving attachment data from ImageUploadService...",
            );
            final attachmentData = await ServiceLocator().imageUploadService
                .getImageUsingUniqueId(cmAttachmentId.toString());

            if (attachmentData != null) {
              Logger.infoLog(
                "Attachment data retrieved, converting to File...",
              );

              // Decode base64 and write to file first to detect file type
              final bytes = base64Decode(attachmentData);

              // Use original filename if available, otherwise detect from binary data
              String fileName;
              if (originalFileName != null &&
                  originalFileName.toString().trim().isNotEmpty) {
                // Sanitize filename to remove invalid characters but preserve name and extension
                final originalName = originalFileName.toString().trim();
                // Remove invalid path characters but keep the name structure
                fileName = originalName.replaceAll(
                  RegExp(r'[<>:"/\\|?*]'),
                  '_',
                );

                // If original filename doesn't have extension, detect from binary data
                if (!fileName.contains('.')) {
                  final detectedExt = _detectFileExtensionFromBytes(bytes);
                  if (detectedExt != null) {
                    fileName = '$fileName$detectedExt';
                    Logger.infoLog(
                      "Added detected extension $detectedExt to filename: $fileName",
                    );
                  }
                }
                Logger.infoLog("Using original filename: $fileName");
              } else {
                // Detect file type from binary data
                final detectedExt = _detectFileExtensionFromBytes(bytes);
                final fileExtension =
                    detectedExt ?? '.pdf'; // Default to PDF if can't detect
                fileName =
                    'cm_remarks_${DateTime.now().millisecondsSinceEpoch}$fileExtension';
                Logger.infoLog(
                  "Original filename not available, detected type: $fileExtension, using generated name: $fileName",
                );
              }

              // Create temporary file with correct filename
              final tempDir = Directory.systemTemp;
              final tempFile = File('${tempDir.path}/$fileName');

              await tempFile.writeAsBytes(bytes);

              attachmentFile = tempFile;
              attachmentFileName =
                  fileName; // Store filename for passing to saveRemarks
              Logger.infoLog(
                "Remarks attachment File created with filename: $fileName",
              );
            } else {
              Logger.errorLog(
                "Failed to retrieve attachment data for ID: $cmAttachmentId",
              );
            }
          }

          if (attachmentFile != null) {
            Logger.infoLog("Remarks attachment File ready, uploading...");

            // Call saveRemarks from repository
            await ServiceLocator().cmRepository.saveRemarks(
              cmSiteReqId,
              cmRemark.toString().trim(),
              cmStatus.toString().trim(),
              attachmentFile,
              originalFileName: attachmentFileName,
            );
            Logger.infoLog("CM remarks uploaded successfully");
          } else {
            Logger.errorLog("Failed to create File for remarks attachment");
          }
        }

        Logger.infoLog("_uploadCMImagesAndAttachments completed");

        // Delete the pending request
        await ServiceLocator().pendingRequestService.deleteRequest(requestId);
        Logger.infoLog("CM sync completed successfully");
      } else {
        Logger.errorLog(
          "Response does not contain cmSiteReqId, response keys: ${response.keys}",
        );
        throw Exception("Failed to create CM ticket");
      }
    } catch (e) {
      Logger.errorLog("Error syncing CM request: $e");
      Logger.errorLog("Stack trace: ${StackTrace.current}");
      rethrow;
    }
  }

  Future<void> _uploadCMImagesAndAttachments(
    dynamic customerPhotoId,
    dynamic customerAttachmentId,
    int cmSiteReqId, {
    dynamic customerOriginalFilePath,
    dynamic customerOriginalFileName,
    dynamic fsrAttachmentId,
    dynamic fsrOriginalFilePath,
    dynamic fsrOriginalFileName,
  }) async {
    try {
      Logger.infoLog(
        "_uploadCMImagesAndAttachments called with cmSiteReqId: $cmSiteReqId",
      );
      Logger.infoLog(
        "customerPhotoId: $customerPhotoId, customerAttachmentId: $customerAttachmentId, fsrAttachmentId: $fsrAttachmentId",
      );

      File? customerPhoto;
      File? attachment;
      File? fsrAttachment;

      // Check for customer photo ID
      if (customerPhotoId != null && customerPhotoId is String) {
        Logger.infoLog("Retrieving customer photo with ID: $customerPhotoId");
        // Get image data from ImageUploadService
        final imageData = await ServiceLocator().imageUploadService
            .getImageUsingUniqueId(customerPhotoId);
        if (imageData != null) {
          Logger.infoLog(
            "Image data retrieved for customer photo, converting to File...",
          );
          customerPhoto = await Utils.buildImageFromBytesData(imageData);
          Logger.infoLog("Customer photo File created successfully");
        } else {
          Logger.errorLog(
            "Failed to retrieve image data for customer photo ID: $customerPhotoId",
          );
        }
      }

      // Check for attachment ID
      if (customerAttachmentId != null && customerAttachmentId is String) {
        Logger.infoLog("Retrieving attachment with ID: $customerAttachmentId");

        // Try to use original file first if available
        if (customerOriginalFilePath != null &&
            customerOriginalFilePath.toString().trim().isNotEmpty) {
          final originalFile = File(customerOriginalFilePath.toString());
          if (await originalFile.exists()) {
            Logger.infoLog(
              "Using original customer attachment file: $customerOriginalFilePath",
            );
            attachment = originalFile;
          } else {
            Logger.infoLog(
              "Original customer attachment file not found, will reconstruct from ImageUploadService",
            );
          }
        }

        // If original file not available, reconstruct from ImageUploadService
        if (attachment == null) {
          final attachmentData = await ServiceLocator().imageUploadService
              .getImageUsingUniqueId(customerAttachmentId);
          if (attachmentData != null) {
            Logger.infoLog("Attachment data retrieved, converting to File...");

            // Use original filename if available, otherwise generate one
            String fileName;
            if (customerOriginalFileName != null &&
                customerOriginalFileName.toString().trim().isNotEmpty) {
              // Sanitize filename to remove invalid characters but preserve name and extension
              final originalName = customerOriginalFileName.toString().trim();
              fileName = originalName.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
              Logger.infoLog(
                "Using original customer attachment filename: $fileName",
              );
            } else {
              // Fallback: generate filename with proper extension
              String fileExtension = '.pdf'; // Default for documents
              fileName =
                  'customer_attachment_${DateTime.now().millisecondsSinceEpoch}$fileExtension';
              Logger.infoLog(
                "Original customer attachment filename not available, using generated name: $fileName",
              );
            }

            // Create temporary file with original filename
            final tempDir = Directory.systemTemp;
            final tempFile = File('${tempDir.path}/$fileName');

            // Decode base64 and write to file
            final bytes = base64Decode(attachmentData);
            await tempFile.writeAsBytes(bytes);

            attachment = tempFile;
            Logger.infoLog(
              "Customer attachment File created with filename: $fileName",
            );
          } else {
            Logger.errorLog(
              "Failed to retrieve image data for attachment ID: $customerAttachmentId",
            );
          }
        }
      }

      // Check for FSR attachment ID
      if (fsrAttachmentId != null && fsrAttachmentId is String) {
        Logger.infoLog("Retrieving FSR attachment with ID: $fsrAttachmentId");

        // Try to use original file first if available
        if (fsrOriginalFilePath != null &&
            fsrOriginalFilePath.toString().trim().isNotEmpty) {
          final originalFile = File(fsrOriginalFilePath.toString());
          if (await originalFile.exists()) {
            Logger.infoLog(
              "Using original FSR attachment file: $fsrOriginalFilePath",
            );
            fsrAttachment = originalFile;
          } else {
            Logger.infoLog(
              "Original FSR attachment file not found, will reconstruct from ImageUploadService",
            );
          }
        }

        // If original file not available, reconstruct from ImageUploadService
        if (fsrAttachment == null) {
          final attachmentData = await ServiceLocator().imageUploadService
              .getImageUsingUniqueId(fsrAttachmentId);
          if (attachmentData != null) {
            Logger.infoLog(
              "FSR attachment data retrieved, converting to File...",
            );

            // Use original filename if available, otherwise generate one
            String fileName;
            if (fsrOriginalFileName != null &&
                fsrOriginalFileName.toString().trim().isNotEmpty) {
              // Sanitize filename to remove invalid characters but preserve name and extension
              final originalName = fsrOriginalFileName.toString().trim();
              fileName = originalName.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
              Logger.infoLog(
                "Using original FSR attachment filename: $fileName",
              );
            } else {
              // Fallback: generate filename with proper extension
              String fileExtension = '.pdf'; // Default for documents
              fileName =
                  'fsr_attachment_${DateTime.now().millisecondsSinceEpoch}$fileExtension';
              Logger.infoLog(
                "Original FSR attachment filename not available, using generated name: $fileName",
              );
            }

            // Create temporary file with original filename
            final tempDir = Directory.systemTemp;
            final tempFile = File('${tempDir.path}/$fileName');

            // Decode base64 and write to file
            final bytes = base64Decode(attachmentData);
            await tempFile.writeAsBytes(bytes);

            fsrAttachment = tempFile;
            Logger.infoLog(
              "FSR attachment File created with filename: $fileName",
            );
          } else {
            Logger.errorLog(
              "Failed to retrieve image data for FSR attachment ID: $fsrAttachmentId",
            );
          }
        }
      }

      // Upload if files exist
      if (customerPhoto != null ||
          attachment != null ||
          fsrAttachment != null) {
        Logger.infoLog("Uploading CM images with cmSiteReqId: $cmSiteReqId");
        Logger.infoLog(
          "customerPhoto: ${customerPhoto != null ? 'exists' : 'null'}, attachment: ${attachment != null ? 'exists' : 'null'}, fsrAttachment: ${fsrAttachment != null ? 'exists' : 'null'}",
        );
        await ServiceLocator().cmRepository.saveCustomerPhotoAndAttachments(
          cmSiteReqId,
          customerPhoto,
          attachment,
          fsrAttachment,
        );
        Logger.infoLog("CM images uploaded successfully");
      } else {
        Logger.infoLog("No images to upload for CM - all are null");
      }
    } catch (e) {
      Logger.errorLog("Error uploading CM images: $e");
      Logger.errorLog("Stack trace: ${StackTrace.current}");
      // Don't throw - images might not be critical
    }
  }

  /// Syncs CM remarks request when user comes online
  /// Handles the /api/v1/mobile/cmRemarks/upload endpoint separately
  Future<void> _syncCMRemarksRequestWhenOnline(
    List<dynamic> requests,
    String requestId,
  ) async {
    try {
      Logger.infoLog("Syncing CM remarks request when online");

      if (requests.isEmpty) {
        Logger.errorLog("CM remarks requests list is empty!");
        return;
      }

      // Get the first request (remarks are saved as single object)
      final request = requests.first;
      Logger.infoLog("Processing CM remarks request: ${request.keys}");

      // Extract required fields - handle both camelCase and snake_case
      final cmId = request['cmId'] ?? request['cm_id'];
      final cmRemark = request['cmRemark'] ?? request['cm_remark'] ?? '';
      final cmStatus = request['cmStatus'] ?? request['cm_status'] ?? '';

      // Extract attachment ID - can be cmRemarksFile or cmAttachmentId
      dynamic attachmentId =
          request['cmRemarksFile'] ??
          request['cm_remarks_file'] ??
          request['cmAttachmentId'] ??
          request['cm_attachment_id'];

      // Extract original file info - handle both camelCase and snake_case
      final originalFilePath =
          request['originalFilePath'] ?? request['original_file_path'];
      final originalFileName =
          request['originalFileName'] ?? request['original_file_name'];

      Logger.infoLog(
        "Extracted CM remarks data - cmId: $cmId, cmRemark: $cmRemark, cmStatus: $cmStatus, attachmentId: $attachmentId",
      );
      Logger.infoLog(
        "Extracted original file info - originalFilePath: $originalFilePath, originalFileName: $originalFileName",
      );

      if (cmId == null) {
        Logger.errorLog("CM remarks request missing cmId");
        throw Exception("CM remarks request missing cmId");
      }

      // Convert cmId to int if it's a string
      int cmSiteReqId;
      if (cmId is int) {
        cmSiteReqId = cmId;
      } else if (cmId is String) {
        cmSiteReqId = int.parse(cmId);
      } else {
        throw Exception("Invalid cmId format: $cmId");
      }

      // Get attachment file if attachment ID is provided
      File? attachmentFile;
      String? attachmentFileName; // Store the filename to pass to saveRemarks
      if (attachmentId != null && attachmentId.toString().trim().isNotEmpty) {
        Logger.infoLog("Retrieving remarks attachment with ID: $attachmentId");

        // Try to use original file first if available
        if (originalFilePath != null &&
            originalFilePath.toString().trim().isNotEmpty) {
          final originalFile = File(originalFilePath.toString());
          if (await originalFile.exists()) {
            Logger.infoLog("Using original remarks file: $originalFilePath");
            attachmentFile = originalFile;
            // Use original filename if available, otherwise use file path
            attachmentFileName =
                originalFileName?.toString().trim() ??
                originalFile.path.split('/').last;
          } else {
            Logger.infoLog(
              "Original remarks file not found, will reconstruct from ImageUploadService",
            );
          }
        }

        // If original file not available, reconstruct from ImageUploadService
        if (attachmentFile == null) {
          final attachmentData = await ServiceLocator().imageUploadService
              .getImageUsingUniqueId(attachmentId.toString());

          if (attachmentData != null) {
            Logger.infoLog("Attachment data retrieved, converting to File...");

            // Decode base64 and write to file first to detect file type
            final bytes = base64Decode(attachmentData);

            // Use original filename if available, otherwise detect from binary data
            String fileName;
            if (originalFileName != null &&
                originalFileName.toString().trim().isNotEmpty) {
              // Sanitize filename to remove invalid characters but preserve name and extension
              final originalName = originalFileName.toString().trim();
              fileName = originalName.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');

              // If original filename doesn't have extension, detect from binary data
              if (!fileName.contains('.')) {
                final detectedExt = _detectFileExtensionFromBytes(bytes);
                if (detectedExt != null) {
                  fileName = '$fileName$detectedExt';
                  Logger.infoLog(
                    "Added detected extension $detectedExt to filename: $fileName",
                  );
                }
              }
              Logger.infoLog("Using original filename: $fileName");
            } else {
              // Detect file type from binary data
              final detectedExt = _detectFileExtensionFromBytes(bytes);
              final fileExtension =
                  detectedExt ?? '.pdf'; // Default to PDF if can't detect
              fileName =
                  'cm_remarks_${DateTime.now().millisecondsSinceEpoch}$fileExtension';
              Logger.infoLog(
                "Original filename not available, detected type: $fileExtension, using generated name: $fileName",
              );
            }

            // Create temporary file with correct filename
            final tempDir = Directory.systemTemp;
            final tempFile = File('${tempDir.path}/$fileName');

            await tempFile.writeAsBytes(bytes);

            attachmentFile = tempFile;
            attachmentFileName =
                fileName; // Store filename for passing to saveRemarks
            Logger.infoLog(
              "Remarks attachment File created with filename: $fileName",
            );
          } else {
            Logger.errorLog(
              "Failed to retrieve attachment data for ID: $attachmentId",
            );
            throw Exception(
              "Failed to retrieve attachment file for ID: $attachmentId",
            );
          }
        }
      }

      // Validate that we have either remark text or attachment
      if (cmRemark.toString().trim().isEmpty && attachmentFile == null) {
        Logger.errorLog(
          "CM remarks request missing both remark text and attachment",
        );
        throw Exception(
          "CM remarks request must have either remark text or attachment",
        );
      }

      // Call saveRemarks from repository
      if (attachmentFile != null) {
        Logger.infoLog(
          "Uploading CM remarks with cmSiteReqId: $cmSiteReqId, filename: $attachmentFileName",
        );
        await ServiceLocator().cmRepository.saveRemarks(
          cmSiteReqId,
          cmRemark.toString().trim(),
          cmStatus.toString().trim(),
          attachmentFile,
          originalFileName: attachmentFileName,
        );
        Logger.infoLog("CM remarks uploaded successfully");
      } else {
        // If no attachment but we have remark text, we still need to upload
        // But saveRemarks requires a file. We might need to create an empty file or handle differently
        Logger.infoLog(
          "CM remarks has text but no attachment - saveRemarks requires a file",
        );
        Logger.infoLog("Skipping remarks upload - attachment required by API");
      }

      // Delete the pending request on success
      await ServiceLocator().pendingRequestService.deleteRequest(requestId);
      Logger.infoLog("CM remarks sync completed successfully");
    } catch (e) {
      Logger.errorLog("Error syncing CM remarks request: $e");
      Logger.errorLog("Stack trace: ${StackTrace.current}");
      rethrow;
    }
  }

  /// Detect file extension from binary data using magic bytes
  /// Similar to the method in cm_repository.dart
  String? _detectFileExtensionFromBytes(Uint8List data) {
    if (data.length < 4) return null;

    // Check magic bytes for common file types
    // JPEG: FF D8 FF
    if (data.length >= 3 &&
        data[0] == 0xFF &&
        data[1] == 0xD8 &&
        data[2] == 0xFF) {
      return '.jpg';
    }

    // PNG: 89 50 4E 47
    if (data.length >= 4 &&
        data[0] == 0x89 &&
        data[1] == 0x50 &&
        data[2] == 0x4E &&
        data[3] == 0x47) {
      return '.png';
    }

    // PDF: 25 50 44 46 (starts with "%PDF")
    if (data.length >= 4 &&
        data[0] == 0x25 &&
        data[1] == 0x50 &&
        data[2] == 0x44 &&
        data[3] == 0x46) {
      return '.pdf';
    }

    // DOCX: 50 4B 03 04 (ZIP file format, which DOCX uses)
    if (data.length >= 4 &&
        data[0] == 0x50 &&
        data[1] == 0x4B &&
        data[2] == 0x03 &&
        data[3] == 0x04) {
      try {
        final dataString = String.fromCharCodes(data.take(1000));
        if (dataString.contains('word/') || dataString.contains('xl/')) {
          return dataString.contains('word/') ? '.docx' : '.xlsx';
        }
        return '.zip';
      } catch (e) {
        return '.docx';
      }
    }

    // DOC (older Word format): D0 CF 11 E0
    if (data.length >= 4 &&
        data[0] == 0xD0 &&
        data[1] == 0xCF &&
        data[2] == 0x11 &&
        data[3] == 0xE0) {
      return '.doc';
    }

    // GIF: 47 49 46 38
    if (data.length >= 4 &&
        data[0] == 0x47 &&
        data[1] == 0x49 &&
        data[2] == 0x46 &&
        data[3] == 0x38) {
      return '.gif';
    }

    // WebP: Check for RIFF...WEBP
    if (data.length >= 12 &&
        data[0] == 0x52 &&
        data[1] == 0x49 &&
        data[2] == 0x46 &&
        data[3] == 0x46 &&
        data[8] == 0x57 &&
        data[9] == 0x45 &&
        data[10] == 0x42 &&
        data[11] == 0x50) {
      return '.webp';
    }

    return null; // Could not detect
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

      // add code here to check for IMAGE CONTAIED IN PM reyqest IN "response_images": [
      //   {
      //     "photo_id": "LOCAL_IMAGE..",
      //     "pclsri_id": 16,
      //     "photo_taken_ts": "2025-12-31T15:03:52.399"
      //   },
      //   {
      //     "photo_id": "LOCAL_IMAGE..",
      //     "pclsri_id": 21,
      //     "photo_taken_ts": "2025-12-31T16:18:36.428"
      //   }
      // ],

      // First, process nested objects/arrays recursively
      if (request.containsKey("giId")) {
        await _processNestedObjects(request);
      }
      // Process site visit image fields (officialIdImageId, aadharCardImageId, leavingStatusImageId)
      if (request.containsKey("visitingPersonName") ||
          request.containsKey("visitingPersonId") ||
          request.containsKey("svlId")) {
        // This is a site visit request - process all image fields
        // Pass the original request object so changes are reflected
        await _processSiteVisitImageFields(request);
      }

      // Check both snake_case and camelCase field names
      dynamic photoId;

      // Handle response_images array (for PM and similar requests)
      if (request.containsKey("response_images") ||
          request.containsKey("asset_upload_item_images")) {
        final responseImages = request['response_images'];
        if (responseImages != null && responseImages is List) {
          // Process each image in the response_images array
          for (int i = 0; i < responseImages.length; i++) {
            final responseImage = responseImages[i];
            if (responseImage is Map<String, dynamic>) {
              final currentPhotoId =
                  responseImage['photo_id'] ?? responseImage['photoId'];

              // Only process LOCAL_IMAGE_ID entries (skip already uploaded server IDs)
              if (currentPhotoId != null &&
                  currentPhotoId.toString().startsWith('LOCAL_IMAGE_ID_')) {
                // This is a unique_id, get the server_id using ImageUploadService
                final imageModel = await ServiceLocator().imageUploadService
                    .getServerIdFromUniqueIdTryUploading(
                      currentPhotoId.toString(),
                    );

                if (imageModel != null) {
                  final serverId = imageModel.serverId;
                  final timestamp = Utils.getTmeFromMSForAPICall(
                    imageModel.createdAt,
                  );

                  // Update the photo_id in this specific response_images item
                  responseImage['photo_id'] = serverId;
                  // Also update camelCase version if it exists
                  if (responseImage.containsKey('photoId')) {
                    responseImage['photoId'] = serverId;
                  }

                  // Update timestamp if available
                  if (timestamp != null) {
                    responseImage['photo_taken_ts'] = timestamp;
                  }

                  Logger.debugLog(
                    "✅ Uploaded LOCAL_IMAGE_ID $currentPhotoId -> server_id $serverId in response_images[$i]",
                  );
                } else {
                  Logger.debugLog(
                    "❌ FAILED to get server_id for LOCAL_IMAGE_ID: $currentPhotoId in response_images[$i]",
                  );
                }
              } else {
                // Already a server ID (numeric), skip upload
                Logger.debugLog(
                  "⏭️ Skipping response_images[$i] - already has server_id: $currentPhotoId",
                );
              }
            }
          }
          // Update the request with the modified response_images array
          request['response_images'] = responseImages;
          // Also update camelCase version for backward compatibility
          request['responseImages'] = responseImages;
        }
        // After processing response_images, return early (don't process single photo_id)
        return request;
      }

      // Handle single photo_id fields (for other request types)
      if (request.containsKey("energyReadingId")) {
        photoId = request['ebAttachmentFileId'];
      } else if (request.containsKey("visitingPersonName") ||
          request.containsKey("visitingPersonId")) {
        photoId = request['visitingPersonImageId'];
      } else if (request.containsKey("gispId")) {
        photoId = request['respPhotoId'];
      } else if (request.containsKey("incidentImgId")) {
        photoId = request['incidentImgId'];
      } else {
        photoId = request['photo_id'] ?? request['photoId'];
      }

      // If no photo_id or photo_id is null/empty/0, return the request as-is
      if (photoId == null ||
          photoId.toString().isEmpty ||
          photoId == 0 ||
          photoId == "0") {
        return request;
      }

      // Check if photo_id is a unique_id (contains LOCAL_IMAGE_ID - do not send to API)
      final photoIdStr = photoId.toString();
      if (photoIdStr.contains('LOCAL_IMAGE_ID')) {
        // Only try upload for full format LOCAL_IMAGE_ID_*; otherwise set 0 so we never send local id
        if (photoIdStr.startsWith('LOCAL_IMAGE_ID_')) {
          final imageModel = await ServiceLocator().imageUploadService
              .getServerIdFromUniqueIdTryUploading(photoIdStr);
          if (imageModel != null ) {
            final serverId = imageModel.serverId;
            final timestamp = Utils.getTmeFromMSForAPICall(imageModel.createdAt);

            if (request.containsKey("energyReadingId")) {
              request['ebAttachmentFileId'] = serverId;
            } else if (request.containsKey("visitingPersonName") ||
                request.containsKey("visitingPersonId") ||
                request.containsKey("svlId")) {
              request['visitingPersonImageId'] = serverId;
            } else if (request.containsKey("gispId")) {
              request['respPhotoId'] = serverId;
            } else if (request.containsKey("incidentImgId")) {
              request['incidentImgId'] = serverId;
            } else {
              request['photo_id'] = serverId;
            }

            if (timestamp != null) {
              request['photo_taken_ts'] = timestamp;
            }
          } else {
            Logger.debugLog(
              "FAILED to get server_id for LOCAL_IMAGE_ID: $photoId - setting to 0 so we do not send local id",
            );
            if (request.containsKey("visitingPersonName") ||
                request.containsKey("visitingPersonId") ||
                request.containsKey("svlId")) {
              request['visitingPersonImageId'] = null;
            } else if (request.containsKey("energyReadingId")) {
              request['ebAttachmentFileId'] = null;
            } else if (request.containsKey("gispId")) {
              request['respPhotoId'] = null;
            } else if (request.containsKey("incidentImgId")) {
              request['incidentImgId'] = null;
            } else {
              request['photo_id'] = null;
            }
          }
        } else {
          Logger.debugLog(
            "photo_id contains LOCAL_IMAGE_ID but not replaceable: $photoIdStr - setting to 0",
          );
          if (request.containsKey("visitingPersonName") ||
              request.containsKey("visitingPersonId") ||
              request.containsKey("svlId")) {
            request['visitingPersonImageId'] = null;
          } else if (request.containsKey("energyReadingId")) {
            request['ebAttachmentFileId'] = null;
          } else if (request.containsKey("gispId")) {
            request['respPhotoId'] = null;
          } else if (request.containsKey("incidentImgId")) {
            request['incidentImgId'] = null;
          } else {
            request['photo_id'] = null;
          }
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

      return request;
    }
    Logger.infoLog("processAssetAuditRequest COMPLETED - returning: $request");

    return request;
  }

  /// Recursively process nested objects and arrays for image IDs
  Future<void> _processNestedObjects(dynamic obj) async {
    if (obj is Map<String, dynamic>) {
      // Process each value in the map
      for (String key in obj.keys) {
        final value = obj[key];

        if (value is List) {
          // Process each item in the list
          for (int i = 0; i < value.length; i++) {
            if (value[i] is Map<String, dynamic>) {
              // Recursively process nested objects
              await _processNestedObjects(value[i]);
              // Also process this object for image IDs
              await _processImageIdInObject(value[i]);
            }
          }
        } else if (value is Map<String, dynamic>) {
          // Recursively process nested maps
          await _processNestedObjects(value);
        }
      }
    }
  }

  /// Process CM request: upload all LOCAL_IMAGE_ID and replace with server IDs
  /// (top-level photo fields + nested checklist/impacted item response_images).
  /// Customer photo, customer attachment, and FSR attachment are NOT processed here:
  /// they are left as string IDs (e.g. LOCAL_IMAGE_ID_xxx) so that after creating the
  /// CM ticket, _uploadCMImagesAndAttachments can look them up and upload via /upload API.
  Future<void> _processCMRequestForImages(Map<String, dynamic> request) async {
    final imageUploadService = ServiceLocator().imageUploadService;

    // 1) Top-level image fields that are sent in the JSON body (replace with server ID).
    // Exclude customer_photo_id, customer_attachment_id, fsr_attachment_id - those are
    // uploaded separately via correctiveMaintenance/upload using the string ID to look up file data.
    final topLevelFields = [
      'identification_img_id',
      'identificationImgId',
      'timestamp_img_id',
      'timestampImgId',
    ];
    for (final key in topLevelFields) {
      if (!request.containsKey(key)) continue;
      final value = request[key];
      if (value == null ||
          value.toString().trim().isEmpty ||
          !value.toString().startsWith('LOCAL_IMAGE_ID_')) {
        continue;
      }
      final imageModel = await imageUploadService
          .getServerIdFromUniqueIdTryUploading(value.toString());
      if (imageModel != null && imageModel.serverId != null) {
        request[key] = imageModel.serverId is int
            ? imageModel.serverId
            : int.tryParse(imageModel.serverId.toString());
        Logger.debugLog('✅ CM sync: $key replaced with server ID');
      } else {
        Logger.errorLog('❌ CM sync: failed to upload $key: $value');
        request[key] = null;
      }
    }

    // 2) Nested checklist: process cmCheckListSiteRespImagesList and response_images per item
    List<dynamic>? checklistList;
    // Support all key variants we use in offline/online flows
    if (request['cmCheckListSiteRespList'] is List) {
      checklistList = request['cmCheckListSiteRespList'] as List<dynamic>;
    } else if (request['cm_check_list_site_resp_list'] is List) {
      checklistList = request['cm_check_list_site_resp_list'] as List<dynamic>;
    } else if (request['checkListSiteRespList'] is List) {
      checklistList = request['checkListSiteRespList'] as List<dynamic>;
    } else if (request['check_list_site_resp_list'] is List) {
      checklistList = request['check_list_site_resp_list'] as List<dynamic>;
    }

    if (checklistList != null) {
      for (final item in checklistList) {
        if (item is! Map<String, dynamic>) continue;
        await _processCMChecklistItemImages(item, imageUploadService);
        final impactedList = item['cm_impacted_item_list'] ??
            item['cmImpactedItemList'] as List<dynamic>?;
        if (impactedList != null) {
          for (final child in impactedList) {
            if (child is Map<String, dynamic>) {
              await _processCMChecklistItemImages(child, imageUploadService);
            }
          }
        }
      }
    }
  }

  /// Process all image lists in a checklist/impacted item: cmCheckListSiteRespImagesList and response_images.
  Future<void> _processCMChecklistItemImages(
    Map<String, dynamic> obj,
    dynamic imageUploadService,
  ) async {
    // API payload uses cmCheckListSiteRespImagesList (list of { photoId, cclsriId, photoTakenTs, ... })
    final imagesList = obj['cm_check_list_site_resp_images_list'] ??
        obj['cmCheckListSiteRespImagesList'] as List<dynamic>?;
    if (imagesList != null) {
      await _processCMPhotoIdList(imagesList, imageUploadService, 'cmCheckListSiteRespImagesList');
    }
    // Legacy / alternate key: response_images (list of { photo_id / photoId })
    await _processCMResponseImagesInMap(obj, imageUploadService);
  }

  /// Process a list of maps that have photoId or photo_id (e.g. cmCheckListSiteRespImagesList).
  Future<void> _processCMPhotoIdList(
    List<dynamic> list,
    dynamic imageUploadService,
    String contextLabel,
  ) async {
    for (int i = 0; i < list.length; i++) {
      final entry = list[i];
      if (entry is! Map<String, dynamic>) continue;
      final photoId = entry['photo_id'] ?? entry['photoId'];
      if (photoId == null ||
          !photoId.toString().startsWith('LOCAL_IMAGE_ID_')) {
        continue;
      }
      final imageModel = await imageUploadService
          .getServerIdFromUniqueIdTryUploading(photoId.toString());
      if (imageModel != null && imageModel.serverId != null) {
        final serverId = imageModel.serverId is int
            ? imageModel.serverId
            : int.tryParse(imageModel.serverId.toString());
        entry['photo_id'] = serverId;
        entry['photoId'] = serverId;
        // Format photoTakenTs as dd/MM/yyyy as required by backend
        if (imageModel.createdAt != null) {
          final dt = DateTime.fromMillisecondsSinceEpoch(imageModel.createdAt!);
          final ts = DateFormat('dd/MM/yyyy').format(dt);
          entry['photo_taken_ts'] = ts;
          entry['photoTakenTs'] = ts;
        }
        Logger.debugLog('✅ CM sync: $contextLabel[$i] photoId replaced with server ID');
      } else {
        Logger.errorLog('❌ CM sync: failed to upload $contextLabel[$i]: $photoId');
        entry['photo_id'] = null;
        entry['photoId'] = null;
      }
    }
  }

  /// Process response_images / responseImages in a single map (checklist or impacted item).
  Future<void> _processCMResponseImagesInMap(
    Map<String, dynamic> obj,
    dynamic imageUploadService,
  ) async {
    final list = obj['response_images'] ?? obj['responseImages'];
    if (list == null || list is! List) return;
    for (int i = 0; i < list.length; i++) {
      final entry = list[i];
      if (entry is! Map<String, dynamic>) continue;
      final photoId = entry['photo_id'] ?? entry['photoId'];
      if (photoId == null ||
          !photoId.toString().startsWith('LOCAL_IMAGE_ID_')) {
        continue;
      }
      final imageModel = await imageUploadService
          .getServerIdFromUniqueIdTryUploading(photoId.toString());
      if (imageModel != null && imageModel.serverId != null) {
        final serverId = imageModel.serverId is int
            ? imageModel.serverId
            : int.tryParse(imageModel.serverId.toString());
        entry['photo_id'] = serverId;
        entry['photoId'] = serverId;
        // Format photoTakenTs as dd/MM/yyyy as required by backend
        if (imageModel.createdAt != null) {
          final dt = DateTime.fromMillisecondsSinceEpoch(imageModel.createdAt!);
          final ts = DateFormat('dd/MM/yyyy').format(dt);
          entry['photo_taken_ts'] = ts;
        }
        Logger.debugLog('✅ CM sync: response_images[$i] replaced with server ID');
      } else {
        Logger.errorLog('❌ CM sync: failed to upload response_images[$i]: $photoId');
        entry['photo_id'] = null;
        entry['photoId'] = null;
      }
    }
  }

  /// Process image ID in a specific object
  Future<void> _processImageIdInObject(Map<String, dynamic> obj) async {
    try {
      // Check for respPhotoId (General Inspection checklist items)
      if (obj.containsKey('respPhotoId')) {
        final photoId = obj['respPhotoId']?.toString();
        if (photoId != null &&
            photoId.isNotEmpty &&
            photoId.startsWith('LOCAL_IMAGE_ID_')) {
          final imageModel = await ServiceLocator().imageUploadService
              .getServerIdFromUniqueIdTryUploading(photoId);

          if (imageModel != null) {
            final serverId = imageModel.serverId;

            obj['respPhotoId'] = serverId;

            final timestamp = Utils.getTmeFromMSForAPICall(
              imageModel.createdAt,
            );
            if (timestamp != null) {
              obj['photo_taken_ts'] = timestamp;
            }
          } else {
            Logger.debugLog(
              "FAILED to get server_id for respPhotoId: $photoId",
            );
          }
        }
      }

      // Check for other photo ID fields
      if (obj.containsKey('photo_id')) {
        final photoId = obj['photo_id']?.toString();
        if (photoId != null &&
            photoId.isNotEmpty &&
            photoId.startsWith('LOCAL_IMAGE_ID_')) {
          final imageModel = await ServiceLocator().imageUploadService
              .getServerIdFromUniqueIdTryUploading(photoId);

          if (imageModel != null) {
            final serverId = imageModel.serverId;

            obj['photo_id'] = serverId;

            final timestamp = Utils.getTmeFromMSForAPICall(
              imageModel.createdAt,
            );
            if (timestamp != null) {
              obj['photo_taken_ts'] = timestamp;
            }
          } else {
            Logger.debugLog("FAILED to get server_id for photo_id: $photoId");
          }
        }
      }
    } catch (e) {
      Logger.errorLog("Error processing image ID in object: $e");
    }
  }

  /// Process site visit specific image fields (officialIdImageId, aadharCardImageId, leavingStatusImageId)
  /// Modifies the request object in place
  Future<void> _processSiteVisitImageFields(
    Map<dynamic, dynamic> request,
  ) async {
    try {
      Logger.debugLog('🔄 Processing site visit image fields...');

      // List of site visit image fields to process
      final imageFields = [
        'officialIdImageId',
        'aadharCardImageId',
        'leavingStatusImageId',
      ];

      for (final fieldName in imageFields) {
        if (request.containsKey(fieldName)) {
          final imageId = request[fieldName];

          Logger.debugLog('📸 Found $fieldName: $imageId');

          // Skip if null, empty, or 0
          if (imageId == null ||
              imageId.toString().isEmpty ||
              imageId == 0 ||
              imageId == '0') {
            Logger.debugLog('⏭️ Skipping $fieldName (null/empty/0)');
            continue;
          }

          // Check if it's a LOCAL_IMAGE_ID - never send to API
          final imageIdStr = imageId.toString();
          if (imageIdStr.contains('LOCAL_IMAGE_ID')) {
            if (imageIdStr.startsWith('LOCAL_IMAGE_ID_')) {
              Logger.debugLog('🔄 Processing $fieldName: $imageId');

              final imageModel = await ServiceLocator().imageUploadService
                  .getServerIdFromUniqueIdTryUploading(imageIdStr);

              if (imageModel != null && imageModel.serverId != null) {
                final serverId =
                    int.tryParse(imageModel.serverId.toString()) ?? 0;
                request[fieldName] = serverId;
                Logger.debugLog(
                  '✅ $fieldName replaced with server ID: $serverId (was: $imageId)',
                );
              } else {
                Logger.errorLog(
                  '❌ Failed to upload image for $fieldName: $imageId - setting to 0',
                );
                request[fieldName] = 0;
              }
            } else {
              Logger.debugLog(
                '⚠️ $fieldName contains LOCAL_IMAGE_ID but not replaceable - setting to 0',
              );
              request[fieldName] = 0;
            }
          } else {
            // Already a server ID, ensure it's an integer
            final serverId = int.tryParse(imageIdStr) ?? 0;
            request[fieldName] = serverId;
            Logger.debugLog('✅ $fieldName already has server ID: $serverId');
          }
        } else {
          Logger.debugLog('⚠️ Field $fieldName not found in request');
        }
      }

      Logger.debugLog('✅ Site visit image fields processing completed');
    } catch (e) {
      Logger.errorLog("❌ Error processing site visit image fields: $e");
      Logger.errorLog("❌ Stack trace: ${StackTrace.current}");
    }
  }
}
