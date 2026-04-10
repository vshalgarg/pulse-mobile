import 'dart:io';
import 'package:app/constants/constants_methods.dart';
import 'package:app/models/energy_reading_model.dart';
import 'package:app/services/upload_dcouments.dart';

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
        errorMessage: 'We could not load energy reading data',
      );
    }
  }

  // Upload file API
  Future<ResponseResult<String?>> uploadFile({
    required File file,
    required String id,
    String activityType = 'ER',
  }) async {
    final uploadService = UploadDcoumentsService(apiService: apiService);
    return uploadService.uploadFile(
      file: file,
      id: id,
      activityType: activityType,
    );
  }

  // Save energy reading data API
  Future<ResponseResult<Map<String, dynamic>?>> saveEnergyReadingData({
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
        kDebugPrint("Energy reading data saved successfully: ${result.data}");
        return ResponseResult.success(
          result.data != null ? {'data': result.data} : null,
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
