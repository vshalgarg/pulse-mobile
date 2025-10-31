import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:app/utils/logger.dart';
import 'package:dio/dio.dart';

import '../models/cm_site_model.dart';
import '../services/api_service.dart';
import '../services/file_download_service.dart';

class CMRepository {
  final ApiService _apiService;

  CMRepository(this._apiService);

  Future<List<CMSite>> getCMSitesDropdown() async {
    try {
      Logger.debugLog('[CMRepository] Starting to fetch CM sites dropdown');
      
      final response = await _apiService.get<List<dynamic>>(
        path: '/api/v1/mobile/cm/CmSitesDropdown',
      );

      Logger.debugLog('[CMRepository] API response received - Success: ${response.isSuccess}');

      if (response.isSuccess && response.data != null) {
        // Check if data is a list
        if (response.data is List) {
          final List<dynamic> rawData = response.data!;
          Logger.debugLog('[CMRepository] Processing ${rawData.length} sites');
          
          final List<CMSite> sites = [];
          for (int i = 0; i < rawData.length; i++) {
            try {
              final siteJson = rawData[i];
              final site = CMSite.fromJson(siteJson);
              sites.add(site);
            } catch (e) {
              Logger.errorLog('[CMRepository] Error parsing site at index $i: $e');
              Logger.errorLog('[CMRepository] Problematic site data: ${rawData[i]}');
              // Continue with other sites instead of crashing
              continue;
            }
          }
          
          Logger.infoLog('[CMRepository] Successfully parsed ${sites.length} out of ${rawData.length} sites');
          return sites;
        } else {
          Logger.errorLog('[CMRepository] Expected List but got ${response.data.runtimeType}');
          throw Exception('Invalid response format: expected List but got ${response.data.runtimeType}');
        }
      } else {
        Logger.errorLog('[CMRepository] API call failed: - Success: ${response.isSuccess} - Error: ${response.errorMessage} - Status Code: ${response.statusCode}');
        throw Exception('Failed to load sites: ${response.errorMessage}');
      }
    } catch (e) {
      Logger.errorLog('[CMRepository] Exception in getCMSitesDropdown: $e');
      Logger.errorLog('[CMRepository] Stack trace: ${StackTrace.current}');
      throw Exception('Failed to load sites: $e');
    }
  }

  Future<Map<String, dynamic>> getChecklistData(int entityId) async {
    try {
      Logger.infoLog('[CMRepository] 🔄 Calling getChecklistData API for entityId: $entityId');
      
      final response = await _apiService.get<Map<String, dynamic>>(
        path: '/api/v1/mobile/correctiveMaintenance/checkListDtlForMobile/$entityId/ALL',
      );
      
      Logger.infoLog('[CMRepository] API Response - Success: ${response.isSuccess}, Has Data: ${response.data != null}');
      
      if (response.isSuccess && response.data != null) {
        final data = response.data?['data'] as Map<String, dynamic>;
        Logger.infoLog('[CMRepository] ✅ Checklist data received with ${data.keys.length} keys');
        return data;
      } else {
        Logger.errorLog('[CMRepository] ❌ Failed to load checklist: ${response.errorMessage}');
        throw Exception('Failed to load checklist data: ${response.errorMessage}');
      }
    } catch (e) {
      Logger.errorLog('[CMRepository] ❌ Exception in getChecklistData: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getCmTicketData(int cmTicketId) async {
    try {

      final response = await _apiService.get<Map<String, dynamic>>(
        path: '/api/v1/mobile/correctiveMaintenanceForMobile/$cmTicketId',
      );
      if (response.isSuccess && response.data != null) {
        return response.data?['data'] as Map<String, dynamic>;
      } else {
        throw Exception('Failed to load checklist data: ${response.errorMessage}');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Downloads document as binary data and saves to Downloads folder
  /// Returns the file path where the document was saved
  Future<String> downloadDocument(int id, String fileName) async {
    try {
      Logger.infoLog('[CMRepository] 🔄 Downloading document with ID: $id');
      
      // Use ApiService with ResponseType.bytes to get binary data
      final response = await _apiService.get<Uint8List>(
        path: '/api/v1/common/DocumentById/$id',
        responseType: ResponseType.bytes,
      );
      
      Logger.infoLog('[CMRepository] API Response - Success: ${response.isSuccess}, Status: ${response.statusCode}');
      
      if (!response.isSuccess || response.data == null) {
        Logger.errorLog('[CMRepository] ❌ Failed to load document: ${response.errorMessage}');
        Logger.errorLog('[CMRepository] Status code: ${response.statusCode}');
        throw Exception('Failed to load document: ${response.errorMessage}');
      }
      
      Logger.infoLog('[CMRepository] ✅ Document binary data received, size: ${(response.data as Uint8List).length} bytes');
      
      // Use common file download service
      final filePath = await FileDownloadService.downloadFileFromBytes(
        data: response.data as Uint8List,
        fileName: fileName,
        requirePermission: false, // Permission is already checked in screen
      );
      
      Logger.infoLog('[CMRepository] ✅ Document saved to: $filePath');
      return filePath;
    } catch (e) {
      Logger.errorLog('[CMRepository] ❌ Exception in downloadDocument: $e');
      Logger.errorLog('[CMRepository] Stack trace: ${StackTrace.current}');
      rethrow;
    }
  }

  /// Legacy method - kept for backward compatibility but now downloads directly
  /// This will be deprecated, use downloadDocument instead
  Future<Map<String, dynamic>> getDocuments(int id) async {
    try {
      Logger.infoLog('[CMRepository] 🔄 Calling getDocuments API for id: $id');
      
      // Try to get as bytes first (if API returns binary)
      final binaryResponse = await _apiService.get<Uint8List>(
        path: '/api/v1/common/DocumentById/$id',
        responseType: ResponseType.bytes,
      );
      
      Logger.infoLog('[CMRepository] API Response - Success: ${binaryResponse.isSuccess}, Status: ${binaryResponse.statusCode}');
      
      if (binaryResponse.isSuccess && binaryResponse.data != null) {
        Logger.infoLog('[CMRepository] ✅ Received binary data, converting to base64');
        
        // Convert binary to base64
        final base64Data = base64Encode(binaryResponse.data as Uint8List);
        
        // Try to extract filename from response headers if available
        String fileName = 'attachment_${DateTime.now().millisecondsSinceEpoch}';
        
        return {
          'documentData': base64Data,
          'fileName': fileName,
        };
      }
      
      // Fallback: Try as JSON (in case API returns JSON)
      final jsonResponse = await _apiService.get<Map<String, dynamic>>(
        path: '/api/v1/common/DocumentById/$id',
        responseType: ResponseType.json,
      );
      
      if (!jsonResponse.isSuccess || jsonResponse.data == null) {
        Logger.errorLog('[CMRepository] ❌ Failed to load document: ${jsonResponse.errorMessage}');
        throw Exception('Failed to load document: ${jsonResponse.errorMessage}');
      }
      
      Logger.infoLog('[CMRepository] ✅ Document data received as JSON');
      Logger.infoLog('[CMRepository] Response data type: ${jsonResponse.data.runtimeType}');
      
      if (jsonResponse.data is Map) {
        final data = jsonResponse.data as Map<String, dynamic>;
        if (data.containsKey('data')) {
          if (data['data'] is Map) {
            return data['data'] as Map<String, dynamic>;
          } else if (data['data'] is String) {
            return {'documentData': data['data']};
          }
        }
        return data;
      }
      
      throw Exception('Unexpected response format');
    } catch (e) {
      Logger.errorLog('[CMRepository] ❌ Exception in getDocuments: $e');
      Logger.errorLog('[CMRepository] Stack trace: ${StackTrace.current}');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> createCorrectiveMaintenance(Map<String, dynamic> requestData) async {
   
    print("vishal printing requestData: correctiveMaintenance $requestData");
    try {
      print("vishal printing requestData: correctiveMaintenance $requestData");
      final response = await _apiService.post<Map<String, dynamic>>(
        path: '/api/v1/mobile/correctiveMaintenance',
        data: requestData,
      );

      print("vishal printing response: correctiveMaintenance $response");
      if(response.isSuccess && response.data != null) {
        print("response from creating cm: $response");
        return response.data?['data'];
      } else {
       print("vishal printing error: correctiveMaintenance $response");
        throw Exception("Error while saving data");
      }
    } catch(e) {

      print("vishal printing error: correctiveMaintenance $e");

      Logger.errorLog("Exception while creating corrective maintenance $e");
      rethrow;
    }
  }

  Future<void> saveCustomerPhotoAndAttachments(int cmSiteReqId, File? customerPhoto,
      File? uploadedAttachment) async {

    print("vishal printing cmSiteReqId: $cmSiteReqId");

    try {
      final customerPhotoMultipartFile = customerPhoto == null ? null
        : await MultipartFile.fromFile(
        customerPhoto.path,
        filename: customerPhoto.path.split('/').last,
      );

      print("vishal printing customerPhotoMultipartFile: $customerPhotoMultipartFile");

      final uploadedAttachmentMultipartFile = uploadedAttachment == null ? null
          : await MultipartFile.fromFile(
        uploadedAttachment.path,
        filename: uploadedAttachment.path.split('/').last,
      );

      print("vishal printing uploadedAttachmentMultipartFile: $uploadedAttachmentMultipartFile");

      final response = await _apiService.post<Map<String, dynamic>>(
        path: 'api/v1/mobile/correctiveMaintenance/upload',
        data: {
          'customerPhoto': customerPhotoMultipartFile,
          'attachments': uploadedAttachmentMultipartFile,
          'cmId': cmSiteReqId,
        },
        useFormDataFormat: true,
      );

      print("vishal printing response: for upload $response");

      if(response.isSuccess && response.data != null) {
        print("response from uploading customer photo: $response");
        //return response.data?['data'];
      } else {
        print("vishal printing error: image Error while saving data");
        throw Exception("Error while saving data");
      }
    } catch(e) {
      print("vishal printing error: image Exception while uploading customer photo and attachments $e");
      Logger.errorLog("Exception while uploading customer photo and attachments $e");
      rethrow;
    }
  }

  Future<void> saveRemarks(int cmSiteReqId, String remark, String status, File attachment) async {
    try {
      final uploadedAttachmentMultipartFile = await MultipartFile.fromFile(
        attachment.path,
        filename: attachment.path.split('/').last,
      );

      final response = await _apiService.post<Map<String, dynamic>>(
        path: 'api/v1/mobile/cmRemarks/upload',
        data: {
          'cmRemarksFile': uploadedAttachmentMultipartFile,
          'cmId': cmSiteReqId,
          'cmRemark': remark,
          'cmStatus': status,
        },
        useFormDataFormat: true,
      );
      if(response.isSuccess && response.data != null) {
        Logger.debugLog("response from uploading customer photo: $response");
        //return response.data?['data'];
      } else {
        throw Exception("Error while saving data");
      }
    } catch(e) {
      Logger.errorLog("Exception while uploading customer photo and attachments $e");
      rethrow;
    }
  }
}