import 'dart:io';
import 'package:dio/dio.dart';
import '../models/selfie_upload_model.dart';
import '../services/api_service.dart';

class SelfieUploadRepository {
  final ApiService apiService;

  SelfieUploadRepository(this.apiService);

  Future<ResponseResult<SelfieUploadResponse?>> uploadSelfie({
    required File file,
    required String imgId,
    required String schId,
  }) async {
    try {
      // Create multipart file
      final multipartFile = await MultipartFile.fromFile(
        file.path,
        filename: file.path.split('/').last,
      );

      // Create data map with form fields including schId and imgId
      final dataMap = {
        'selfie': multipartFile,
        'imgId': imgId,
        'SchId': schId,
      };

      final result = await apiService.post<Map<String, dynamic>>(
        path: "api/v1/mobile/uploadsSelfie",
        data: dataMap,
        useFormDataFormat: true,
      );
      
      if (result.isSuccess) {
        final response = SelfieUploadResponse.fromJson(result.data!);
        return ResponseResult.success(response, result.statusCode);
      } else {
        return ResponseResult.error(errorMessage: result.errorMessage);
      }
    } catch (e) {
      return const ResponseResult.error(
        errorMessage: 'We could not upload the selfie',
      );
    }
  }
}
