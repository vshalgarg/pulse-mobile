import 'dart:io';
import 'package:dio/dio.dart';
import '../models/asset_audit_photo_upload_model.dart';
import '../services/api_service.dart';

class AssetAuditPhotoUploadRepository {
  final ApiService apiService;

  AssetAuditPhotoUploadRepository(this.apiService);

  Future<ResponseResult<AssetAuditPhotoUploadResponse?>> uploadPhoto({
    required File file,
    String? imgId,
    String? schId,
  }) async {
    try {
      // Create multipart file
      final multipartFile = await MultipartFile.fromFile(
        file.path,
        filename: file.path.split('/').last,
      );

      // Create data map with form fields
      final dataMap = <String, dynamic>{
        'imgFile': multipartFile,
        'activityType': 'AA', // Required parameter for Asset Audit (AA = Asset Audit)
      };

      // Add optional fields if provided
      if (imgId != null && imgId.isNotEmpty) {
        dataMap['imgId'] = imgId;
      }
      if (schId != null && schId.isNotEmpty) {
        dataMap['schId'] = schId;
      }
      
      print('AssetAuditPhotoUploadRepository: Final data map keys: ${dataMap.keys}');

      print('AssetAuditPhotoUploadRepository: Uploading photo with data: ${dataMap.keys}');
      final result = await apiService.post<Map<String, dynamic>>(
        path: "api/v1/mobile/uploads",
        data: dataMap,
        useFormDataFormat: true,
      );
      
      if (result.isSuccess) {
        print('AssetAuditPhotoUploadRepository: Upload successful, response: ${result.data}');
        final response = AssetAuditPhotoUploadResponse.fromJson(result.data!);
        return ResponseResult.success(response, result.statusCode);
      } else {
        print('AssetAuditPhotoUploadRepository: Upload failed: ${result.errorMessage}');
        return ResponseResult.error(errorMessage: result.errorMessage);
      }
    } catch (e) {
      print('AssetAuditPhotoUploadRepository: Exception during upload: $e');
      return const ResponseResult.error(
        errorMessage: 'We could not upload the photo',
      );
    }
  }
}
