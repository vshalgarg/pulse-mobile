import 'dart:io';

import 'package:app/constants/constants_methods.dart';
import 'package:dio/dio.dart';

import 'api_service.dart';

/// Service wrapper for `api/v1/common/UploadDocuments`.
///
/// NOTE: Filename intentionally matches requested path: `upload_dcouments.dart`.
class UploadDcoumentsService {
  final ApiService _apiService;

  UploadDcoumentsService({required ApiService apiService})
      : _apiService = apiService;

  Future<ResponseResult<String?>> uploadFile({
    required File file,
    required String id,
    required String activityType,
  }) async {
    try {
      if (!await file.exists()) {
        return const ResponseResult.error(
          errorMessage: 'Selected file not found',
        );
      }

      final multipartFile = await MultipartFile.fromFile(
        file.path,
        filename: file.path.split('/').last,
      );

      final dataMap = <String, dynamic>{
        'activityType': activityType,
        'docId': id.isEmpty ? '0' : id,
      };

      final result = await _apiService.post<Map<String, dynamic>>(
        path: 'api/v1/common/UploadDocuments',
        data: dataMap,
        files: [multipartFile],
        useFormDataFormat: true,
      );

      if (!result.isSuccess) {
        return ResponseResult.error(errorMessage: result.errorMessage);
      }

      kDebugPrint('File uploaded successfully: ${result.data}');
      final docId = result.data?['docId']?.toString();
      return ResponseResult.success(
        (docId != null && docId.isNotEmpty) ? docId : '0',
        result.statusCode,
      );
    } catch (_) {
      return const ResponseResult.error(
        errorMessage: 'We could not upload the file',
      );
    }
  }
}
