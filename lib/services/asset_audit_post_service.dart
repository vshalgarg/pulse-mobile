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

      Toastbar.showSuccessToastWithoutContext("Data saved to DB successfully");
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
        url.contains("api/v1/om-schedule/genInspection")) {
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

      // Special handling for CM requests
      if (url.contains('/correctiveMaintenance')) {
        await _syncCMRequestWhenOnline(copiedRequests, requestId);
        return;
      } else if (url.contains('/cmRemarks/upload')) {
        // Handle remarks upload separately
        await _syncCMRemarksRequestWhenOnline(copiedRequests, requestId);
        return;
      } else {
        await _processRequestsForImages(copiedRequests);
        await _postDataToApi(url, copiedRequests);
        await ServiceLocator().pendingRequestService.deleteRequest(requestId);
      }
    } catch (e) {
      Logger.errorLog(e.toString());
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

      final request = requests.first;
      Logger.infoLog("Processing CM request: ${request.keys}");

      // Convert keys to camelCase
      final processedData = DataTransformationHelper.convertKeysToCamelCase(
        request,
      );

      // Extract image IDs before removing them from the request
      final customerPhotoId = processedData['customer_photo_id'] ?? processedData['customerPhotoId'];
      final customerAttachmentId = processedData['customer_attachment_id'] ?? processedData['customerAttachmentId'];
      
      // Extract original file info for customer attachment (to preserve filename)
      final customerOriginalFilePath = processedData['customer_original_file_path'];
      final customerOriginalFileName = processedData['customer_original_file_name'];
      
      // Extract attachment name if present, or use original filename
      final customerAttachmentName = processedData['customer_attachmen_name'] ?? 
                                     processedData['customer_attachment_name'] ??
                                     customerOriginalFileName;

      Logger.infoLog("Extracted image IDs - customerPhotoId: $customerPhotoId, customerAttachmentId: $customerAttachmentId");
      Logger.infoLog("Extracted attachment name - customerAttachmentName: $customerAttachmentName");

      // Remove image IDs and file info from the request data before creating CM ticket
      processedData.remove('customer_photo_id');
      processedData.remove('customerPhotoId');
      processedData.remove('customer_attachment_id');
      processedData.remove('customerAttachmentId');
      processedData.remove('customer_original_file_path');
      processedData.remove('customer_original_file_name');
      processedData.remove('customer_attachmen_name');
      processedData.remove('customer_attachment_name');
      
      // Preserve attachment name in request data if we have it (for API to store the correct name)
      if (customerAttachmentName != null && customerAttachmentName.toString().trim().isNotEmpty) {
        processedData['customer_attachmen_name'] = customerAttachmentName.toString().trim();
        processedData['customer_attachment_name'] = customerAttachmentName.toString().trim();
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
        Logger.infoLog("customerPhotoId: $customerPhotoId, customerAttachmentId: $customerAttachmentId");
        await _uploadCMImagesAndAttachments(
          customerPhotoId,
          customerAttachmentId,
          cmSiteReqId,
          customerOriginalFilePath: customerOriginalFilePath,
          customerOriginalFileName: customerOriginalFileName,
        );

        // Check for and sync remarks if present
        final cmRemark = processedData['cmRemark'] ?? processedData['cm_remark'] ?? '';
        final cmStatus = processedData['cmStatus'] ?? processedData['cm_status'] ?? '';
        final cmAttachmentId = processedData['cmRemarksFile'] ?? 
                               processedData['cm_remarks_file'] ??
                               processedData['cmAttachmentId'] ?? 
                               processedData['cm_attachment_id'];
        
        if ((cmRemark.toString().trim().isNotEmpty || cmStatus.toString().trim().isNotEmpty) && 
            cmAttachmentId != null && cmAttachmentId.toString().trim().isNotEmpty) {
          
          Logger.infoLog("Syncing CM remarks with attachment ID: $cmAttachmentId");
          
          // Get attachment file - try original file first, then reconstruct from ImageUploadService
          File? attachmentFile;
          String? attachmentFileName; // Store the filename to pass to saveRemarks
          
          // Check if original file path is stored (preserves extension and filename)
          // Handle both camelCase and snake_case
          final originalFilePath = processedData['originalFilePath'] ?? processedData['original_file_path'];
          final originalFileName = processedData['originalFileName'] ?? processedData['original_file_name'];
          
          if (originalFilePath != null && originalFilePath.toString().trim().isNotEmpty) {
            final originalFile = File(originalFilePath.toString());
            if (await originalFile.exists()) {
              Logger.infoLog("Using original file: $originalFilePath");
              attachmentFile = originalFile;
              // Use original filename if available, otherwise use file path
              attachmentFileName = originalFileName?.toString().trim() ?? originalFile.path.split('/').last;
            } else {
              Logger.infoLog("Original file not found, will reconstruct from ImageUploadService");
            }
          }
          
          // If original file not available, reconstruct from ImageUploadService
          if (attachmentFile == null) {
            Logger.infoLog("Retrieving attachment data from ImageUploadService...");
            final attachmentData = await ServiceLocator().imageUploadService
                .getImageUsingUniqueId(cmAttachmentId.toString());
            
            if (attachmentData != null) {
              Logger.infoLog("Attachment data retrieved, converting to File...");
              
              // Decode base64 and write to file first to detect file type
              final bytes = base64Decode(attachmentData);
              
              // Use original filename if available, otherwise detect from binary data
              String fileName;
              if (originalFileName != null && originalFileName.toString().trim().isNotEmpty) {
                // Sanitize filename to remove invalid characters but preserve name and extension
                final originalName = originalFileName.toString().trim();
                // Remove invalid path characters but keep the name structure
                fileName = originalName.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
                
                // If original filename doesn't have extension, detect from binary data
                if (!fileName.contains('.')) {
                  final detectedExt = _detectFileExtensionFromBytes(bytes);
                  if (detectedExt != null) {
                    fileName = '$fileName$detectedExt';
                    Logger.infoLog("Added detected extension $detectedExt to filename: $fileName");
                  }
                }
                Logger.infoLog("Using original filename: $fileName");
              } else {
                // Detect file type from binary data
                final detectedExt = _detectFileExtensionFromBytes(bytes);
                final fileExtension = detectedExt ?? '.pdf'; // Default to PDF if can't detect
                fileName = 'cm_remarks_${DateTime.now().millisecondsSinceEpoch}$fileExtension';
                Logger.infoLog("Original filename not available, detected type: $fileExtension, using generated name: $fileName");
              }
              
              // Create temporary file with correct filename
              final tempDir = Directory.systemTemp;
              final tempFile = File('${tempDir.path}/$fileName');
              
              await tempFile.writeAsBytes(bytes);
              
              attachmentFile = tempFile;
              attachmentFileName = fileName; // Store filename for passing to saveRemarks
              Logger.infoLog("Remarks attachment File created with filename: $fileName");
            } else {
              Logger.errorLog("Failed to retrieve attachment data for ID: $cmAttachmentId");
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
        Logger.errorLog("Response does not contain cmSiteReqId, response keys: ${response.keys}");
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
  }) async {
    try {
      Logger.infoLog("_uploadCMImagesAndAttachments called with cmSiteReqId: $cmSiteReqId");
      Logger.infoLog("customerPhotoId: $customerPhotoId, customerAttachmentId: $customerAttachmentId");
      
      File? customerPhoto;
      File? attachment;

      // Check for customer photo ID
      if (customerPhotoId != null && customerPhotoId is String) {
        Logger.infoLog("Retrieving customer photo with ID: $customerPhotoId");
        // Get image data from ImageUploadService
        final imageData = await ServiceLocator().imageUploadService
            .getImageUsingUniqueId(customerPhotoId);
        if (imageData != null) {
          Logger.infoLog("Image data retrieved for customer photo, converting to File...");
          customerPhoto = await Utils.buildImageFromBytesData(imageData);
          Logger.infoLog("Customer photo File created successfully");
        } else {
          Logger.errorLog("Failed to retrieve image data for customer photo ID: $customerPhotoId");
        }
      }

      // Check for attachment ID
      if (customerAttachmentId != null && customerAttachmentId is String) {
        Logger.infoLog("Retrieving attachment with ID: $customerAttachmentId");
        
        // Try to use original file first if available
        if (customerOriginalFilePath != null && customerOriginalFilePath.toString().trim().isNotEmpty) {
          final originalFile = File(customerOriginalFilePath.toString());
          if (await originalFile.exists()) {
            Logger.infoLog("Using original customer attachment file: $customerOriginalFilePath");
            attachment = originalFile;
          } else {
            Logger.infoLog("Original customer attachment file not found, will reconstruct from ImageUploadService");
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
            if (customerOriginalFileName != null && customerOriginalFileName.toString().trim().isNotEmpty) {
              // Sanitize filename to remove invalid characters but preserve name and extension
              final originalName = customerOriginalFileName.toString().trim();
              fileName = originalName.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
              Logger.infoLog("Using original customer attachment filename: $fileName");
            } else {
              // Fallback: generate filename with proper extension
              String fileExtension = '.pdf'; // Default for documents
              fileName = 'customer_attachment_${DateTime.now().millisecondsSinceEpoch}$fileExtension';
              Logger.infoLog("Original customer attachment filename not available, using generated name: $fileName");
            }
            
            // Create temporary file with original filename
            final tempDir = Directory.systemTemp;
            final tempFile = File('${tempDir.path}/$fileName');
            
            // Decode base64 and write to file
            final bytes = base64Decode(attachmentData);
            await tempFile.writeAsBytes(bytes);
            
            attachment = tempFile;
            Logger.infoLog("Customer attachment File created with filename: $fileName");
          } else {
            Logger.errorLog("Failed to retrieve image data for attachment ID: $customerAttachmentId");
          }
        }
      }

      // Upload if files exist
      if (customerPhoto != null || attachment != null) {
        Logger.infoLog("Uploading CM images with cmSiteReqId: $cmSiteReqId");
        Logger.infoLog("customerPhoto: ${customerPhoto != null ? 'exists' : 'null'}, attachment: ${attachment != null ? 'exists' : 'null'}");
        await ServiceLocator().cmRepository.saveCustomerPhotoAndAttachments(
          cmSiteReqId,
          customerPhoto,
          attachment,
        );
        Logger.infoLog("CM images uploaded successfully");
      } else {
        Logger.infoLog("No images to upload for CM - both are null");
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
      dynamic attachmentId = request['cmRemarksFile'] ?? 
                             request['cm_remarks_file'] ??
                             request['cmAttachmentId'] ?? 
                             request['cm_attachment_id'];
      
      // Extract original file info - handle both camelCase and snake_case
      final originalFilePath = request['originalFilePath'] ?? request['original_file_path'];
      final originalFileName = request['originalFileName'] ?? request['original_file_name'];

      Logger.infoLog("Extracted CM remarks data - cmId: $cmId, cmRemark: $cmRemark, cmStatus: $cmStatus, attachmentId: $attachmentId");
      Logger.infoLog("Extracted original file info - originalFilePath: $originalFilePath, originalFileName: $originalFileName");

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
        if (originalFilePath != null && originalFilePath.toString().trim().isNotEmpty) {
          final originalFile = File(originalFilePath.toString());
          if (await originalFile.exists()) {
            Logger.infoLog("Using original remarks file: $originalFilePath");
            attachmentFile = originalFile;
            // Use original filename if available, otherwise use file path
            attachmentFileName = originalFileName?.toString().trim() ?? originalFile.path.split('/').last;
          } else {
            Logger.infoLog("Original remarks file not found, will reconstruct from ImageUploadService");
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
            if (originalFileName != null && originalFileName.toString().trim().isNotEmpty) {
              // Sanitize filename to remove invalid characters but preserve name and extension
              final originalName = originalFileName.toString().trim();
              fileName = originalName.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
              
              // If original filename doesn't have extension, detect from binary data
              if (!fileName.contains('.')) {
                final detectedExt = _detectFileExtensionFromBytes(bytes);
                if (detectedExt != null) {
                  fileName = '$fileName$detectedExt';
                  Logger.infoLog("Added detected extension $detectedExt to filename: $fileName");
                }
              }
              Logger.infoLog("Using original filename: $fileName");
            } else {
              // Detect file type from binary data
              final detectedExt = _detectFileExtensionFromBytes(bytes);
              final fileExtension = detectedExt ?? '.pdf'; // Default to PDF if can't detect
              fileName = 'cm_remarks_${DateTime.now().millisecondsSinceEpoch}$fileExtension';
              Logger.infoLog("Original filename not available, detected type: $fileExtension, using generated name: $fileName");
            }
            
            // Create temporary file with correct filename
            final tempDir = Directory.systemTemp;
            final tempFile = File('${tempDir.path}/$fileName');
            
            await tempFile.writeAsBytes(bytes);
            
            attachmentFile = tempFile;
            attachmentFileName = fileName; // Store filename for passing to saveRemarks
            Logger.infoLog("Remarks attachment File created with filename: $fileName");
          } else {
            Logger.errorLog("Failed to retrieve attachment data for ID: $attachmentId");
            throw Exception("Failed to retrieve attachment file for ID: $attachmentId");
          }
        }
      }

      // Validate that we have either remark text or attachment
      if (cmRemark.toString().trim().isEmpty && attachmentFile == null) {
        Logger.errorLog("CM remarks request missing both remark text and attachment");
        throw Exception("CM remarks request must have either remark text or attachment");
      }

      // Call saveRemarks from repository
      if (attachmentFile != null) {
        Logger.infoLog("Uploading CM remarks with cmSiteReqId: $cmSiteReqId, filename: $attachmentFileName");
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
        Logger.infoLog("CM remarks has text but no attachment - saveRemarks requires a file");
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
    if (data.length >= 3 && data[0] == 0xFF && data[1] == 0xD8 && data[2] == 0xFF) {
      return '.jpg';
    }
    
    // PNG: 89 50 4E 47
    if (data.length >= 4 && data[0] == 0x89 && data[1] == 0x50 && data[2] == 0x4E && data[3] == 0x47) {
      return '.png';
    }
    
    // PDF: 25 50 44 46 (starts with "%PDF")
    if (data.length >= 4 && data[0] == 0x25 && data[1] == 0x50 && data[2] == 0x44 && data[3] == 0x46) {
      return '.pdf';
    }
    
    // DOCX: 50 4B 03 04 (ZIP file format, which DOCX uses)
    if (data.length >= 4 && data[0] == 0x50 && data[1] == 0x4B && data[2] == 0x03 && data[3] == 0x04) {
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
    if (data.length >= 4 && data[0] == 0xD0 && data[1] == 0xCF && data[2] == 0x11 && data[3] == 0xE0) {
      return '.doc';
    }
    
    // GIF: 47 49 46 38
    if (data.length >= 4 && data[0] == 0x47 && data[1] == 0x49 && data[2] == 0x46 && data[3] == 0x38) {
      return '.gif';
    }
    
    // WebP: Check for RIFF...WEBP
    if (data.length >= 12 && 
        data[0] == 0x52 && data[1] == 0x49 && data[2] == 0x46 && data[3] == 0x46 &&
        data[8] == 0x57 && data[9] == 0x45 && data[10] == 0x42 && data[11] == 0x50) {
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

      // First, process nested objects/arrays recursively
      if (request.containsKey("giId")) {
        await _processNestedObjects(request);
      }
      // Check both snake_case and camelCase field names
      String? photoId = "";

      if (request.containsKey("energyReadingId")) {
        photoId = request['ebAttachmentFileId'];
      } else if (request.containsKey("visitingPersonName") ||
          request.containsKey("visitingPersonId")) {
        photoId = request['visitingPersonImageId'];
      } else if (request.containsKey("gispId")) {
        photoId = request['respPhotoId'];
      } else {
        photoId = request['photo_id'] ?? request['photoId'];
      }

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

          final timestamp = Utils.getTmeFromMSForAPICall(imageModel.createdAt);

          if (request.containsKey("energyReadingId")) {
            request['ebAttachmentFileId'] = serverId;
          } else if (request.containsKey("visitingPersonName") ||
              request.containsKey("visitingPersonId")) {
            request['visitingPersonImageId'] = serverId;
          } else if (request.containsKey("gispId")) {
            request['respPhotoId'] = serverId;
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
}
