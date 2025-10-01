import 'dart:io';

import 'package:app/utils/data_transformation_helper.dart';
import 'package:app/utils/logger.dart';
import 'package:dio/dio.dart';

import '../models/cm_site_model.dart';
import '../services/api_service.dart';

class CMRepository {
  final ApiService _apiService;

  CMRepository(this._apiService);

  Future<List<CMSite>> getCMSitesDropdown() async {
    try {
      final response = await _apiService.get<List<dynamic>>(
        path: '/api/v1/mobile/cm/CmSitesDropdown',
      );

      if (response.isSuccess && response.data != null) {

        // Check if data is a list
        if (response.data is List) {
          final List<dynamic> rawData = response.data!;
          final sites = rawData.map((siteJson) {
            try {
              final site = CMSite.fromJson(siteJson);
              return site;
            } catch (e) {
              Logger.errorLog('[CMRepository] Error parsing site $siteJson: $e');
              rethrow;
            }
          }).toList();
          Logger.infoLog('[CMRepository] Site names: ${sites.map((s) => s.siteName).toList()}');
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
      Logger.errorLog('[CMRepository] Stack trace: ${StackTrace.current}');
      throw Exception('Failed to load sites: $e');
    }
  }

  Future<Map<String, dynamic>> getChecklistData(int entityId) async {
    try {

      final response = await _apiService.get<Map<String, dynamic>>(
        path: '/api/v1/mobile/correctiveMaintenance/checkListDtlForMobile/$entityId/ALL',
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

  Future<Map<String, dynamic>> createCorrectiveMaintenance(Map<String, dynamic> requestData) async {
    try {
      final response = await _apiService.post<Map<String, dynamic>>(
        path: '/api/v1/mobile/correctiveMaintenance',
        data: requestData,
      );
      if(response.isSuccess && response.data != null) {
        Logger.debugLog("response from creating cm: $response");
        return response.data?['data'];
      } else {
        throw Exception("Error while saving data");
      }
    } catch(e) {
      Logger.errorLog("Exception while creating corrective maintenance $e");
      rethrow;
    }
  }

  Future<void> saveCustomerPhotoAndAttachments(int cmSiteReqId, File? customerPhoto,
      File? uploadedAttachment) async {
    try {
      final customerPhotoMultipartFile = customerPhoto == null ? null
        : await MultipartFile.fromFile(
        customerPhoto.path,
        filename: customerPhoto.path.split('/').last,
      );

      final uploadedAttachmentMultipartFile = uploadedAttachment == null ? null
          : await MultipartFile.fromFile(
        uploadedAttachment.path,
        filename: uploadedAttachment.path.split('/').last,
      );

      final response = await _apiService.post<Map<String, dynamic>>(
        path: 'api/v1/mobile/correctiveMaintenance/upload',
        data: {
          'customerPhoto': customerPhotoMultipartFile,
          'attachments': uploadedAttachmentMultipartFile,
          'cmId': cmSiteReqId,
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

  Future<void> saveRemarks(int cmSiteReqId, String remark, String status, File attachment) async {
    try {
      final uploadedAttachmentMultipartFile = await MultipartFile.fromFile(
        attachment.path,
        filename: attachment.path.split('/').last,
      );

      final response = await _apiService.post<Map<String, dynamic>>(
        path: 'api/v1/mobile/correctiveMaintenance/upload',
        data: {
          'cmRemarksFile': uploadedAttachmentMultipartFile,
          'cmId': cmSiteReqId,
          'cmRemark': remark,
          'cmStatus': status,
          'cmRemarksId': 0,
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