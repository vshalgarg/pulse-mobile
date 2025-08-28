import 'package:app/constants/constants_methods.dart';
import 'package:app/models/energy_reading_model.dart';
import 'dart:io';
import 'package:dio/dio.dart';

import '../services/api_service.dart';

class EnergyReadingRepository {
  final ApiService apiService;

  EnergyReadingRepository(this.apiService);

  Future<ResponseResult<EnergyReadingResponse?>> getEnergyReadingData({
    required String siteType,
    required String auditSchId,
    required String siteAuditSchId,
  }) async {
    try {
      final result = await apiService.get<List<dynamic>>(
        path: "api/v1/mobile/EB/PageData/$siteType/$auditSchId/$siteAuditSchId",
      );
      
      if (result.isSuccess) {
        kDebugPrint("Energy reading data: ${result.data}");
        return ResponseResult.success(
          EnergyReadingResponse.fromJson(result.data ?? []),
          result.statusCode,
        );
      } else {
        return ResponseResult.error(errorMessage: result.errorMessage);
      }
    } catch (e) {
      return const ResponseResult.error(
        errorMessage: 'We could not process your request',
      );
    }
  }

  // Upload file API
  Future<ResponseResult<String?>> uploadFile({
    required File file,
    required String id,
  }) async {
    try {
      // Create multipart file
      final multipartFile = await MultipartFile.fromFile(
        file.path,
        filename: file.path.split('/').last,
      );

      final result = await apiService.post<Map<String, dynamic>>(
        path: "api/v1/common/downLoadFile",
        data: {'id': id},
        files: [multipartFile],
        useFormDataFormat: true,
      );
      
      if (result.isSuccess) {
        kDebugPrint("File uploaded successfully: ${result.data}");
        return ResponseResult.success(
          result.data?['fileId']?.toString() ?? result.data?.toString(),
          result.statusCode,
        );
      } else {
        return ResponseResult.error(errorMessage: result.errorMessage);
      }
    } catch (e) {
      return const ResponseResult.error(
        errorMessage: 'We could not upload the file',
      );
    }
  }

  // Save energy reading data API
  Future<ResponseResult<Map<String, dynamic>?>> saveEnergyReadingData({
    required List<Map<String, dynamic>> energyReadingData,
  }) async {
    try {
      // Convert list to map for API service compatibility
      final dataMap = {'data': energyReadingData};
      
      final result = await apiService.post<Map<String, dynamic>>(
        path: "api/v1/mobile/EbBillReading",
        data: dataMap,
      );
      
      if (result.isSuccess) {
        kDebugPrint("Energy reading data saved successfully: ${result.data}");
        return ResponseResult.success(
          result.data,
          result.statusCode,
        );
      } else {
        return ResponseResult.error(errorMessage: result.errorMessage);
      }
    } catch (e) {
      return const ResponseResult.error(
        errorMessage: 'We could not save the energy reading data',
      );
    }
  }
}
