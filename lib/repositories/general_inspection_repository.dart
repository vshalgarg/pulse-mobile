import 'package:app/utils/logger.dart';

import '../models/gen_ins_checklist_model.dart';
import '../services/api_service.dart';

class GeneralInspectionRepository {
  final ApiService _apiService;

  GeneralInspectionRepository(this._apiService);

  Future<List<GenInsCheckListData>> getGenInsCheckListData(int siteDomainId) async {
    try {
      Logger.debugLog('[GeneralInspectionRepository] Starting to fetch general inspection checklist data');
      Logger.debugLog('[GeneralInspectionRepository] Site Domain ID: $siteDomainId');
      
      final response = await _apiService.get<Map<String, dynamic>>(
        path: '/api/v1/om-schedule/genInspection/checkListMst/$siteDomainId',
      );

      Logger.debugLog('[GeneralInspectionRepository] API response received - Success: ${response.isSuccess}');

      if (response.isSuccess && response.data != null) {
        final data = response.data!['data'];
        
        if (data is List) {
          final List<dynamic> rawData = data;
          Logger.debugLog('[GeneralInspectionRepository] Processing ${rawData.length} checklist items');
          
          final List<GenInsCheckListData> checklistItems = [];
          for (int i = 0; i < rawData.length; i++) {
            try {
              final itemJson = rawData[i];
              final item = GenInsCheckListData.fromJson(itemJson);
              checklistItems.add(item);
            } catch (e) {
              Logger.errorLog('[GeneralInspectionRepository] Error parsing checklist item at index $i: $e');
              Logger.errorLog('[GeneralInspectionRepository] Problematic item data: ${rawData[i]}');
              // Continue with other items instead of crashing
              continue;
            }
          }
          
          Logger.infoLog('[GeneralInspectionRepository] Successfully parsed ${checklistItems.length} out of ${rawData.length} checklist items');
          return checklistItems;
        } else {
          Logger.errorLog('[GeneralInspectionRepository] Expected List but got ${data.runtimeType}');
          throw Exception('Invalid response format: expected List but got ${data.runtimeType}');
        }
      } else {
        Logger.errorLog('[GeneralInspectionRepository] API call failed: - Success: ${response.isSuccess} - Error: ${response.errorMessage} - Status Code: ${response.statusCode}');
        throw Exception('Failed to load checklist data: ${response.errorMessage}');
      }
    } catch (e) {
      Logger.errorLog('[GeneralInspectionRepository] Exception in getGenInsCheckListData: $e');
      Logger.errorLog('[GeneralInspectionRepository] Stack trace: ${StackTrace.current}');
      throw Exception('Failed to load checklist data: $e');
    }
  }
}
