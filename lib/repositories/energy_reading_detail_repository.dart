import 'package:app/constants/constants_methods.dart';
import 'dart:io';
import 'package:dio/dio.dart';
// Added for base64Encode

import '../services/api_service.dart';

class EnergyReadingDetailRepository {
  final ApiService apiService;

  EnergyReadingDetailRepository(this.apiService);

  // Upload file API
  Future<ResponseResult<String?>> uploadFile({
    required File file,
    required String id,
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

      final dataMap = {
        'activityType': 'ER',
        'docId': '0',
      };

      final result = await apiService.post<Map<String, dynamic>>(
        path: "api/v1/common/UploadDocuments",
        data: dataMap,
        files: [multipartFile],
        useFormDataFormat: true,
      );
      
      if (result.isSuccess) {
        kDebugPrint("File uploaded successfully: ${result.data}");
        
        // Extract docId from response
        final docId = result.data?['docId']?.toString();
        
        if (docId != null && docId.isNotEmpty) {
          return ResponseResult.success(docId, result.statusCode);
        } else {
          return ResponseResult.success('0', result.statusCode);
        }
      } else {
        return ResponseResult.error(errorMessage: result.errorMessage);
      }
    } catch (e) {
      return const ResponseResult.error(
        errorMessage: 'We could not upload the file',
      );
    }
  }

  // Save energy reading detail data API
  Future<ResponseResult<Map<String, dynamic>?>> saveEnergyReadingDetailData({
    required List<Map<String, dynamic>> energyReadingData,
  }) async {
    try {
      // Send the array directly as the API expects an ArrayList
      final result = await apiService.post<List<dynamic>>(
        path: "api/v1/mobile/EbBillReading",
        data: energyReadingData,
        useFormDataFormat: false, // Send as JSON array
      );
      
      if (result.isSuccess) {
        kDebugPrint("Energy reading detail data saved successfully: ${result.data}");
        return ResponseResult.success(
          result.data != null ? {'data': result.data} : null,
          result.statusCode,
        );
      } else {
        return ResponseResult.error(errorMessage: result.errorMessage);
      }
    } catch (e) {
      return const ResponseResult.error(
        errorMessage: 'We could not save the energy reading detail data',
      );
    }
  }
}
