import '../services/service_locator.dart';
import '../models/cm_checklist_model.dart';
import '../services/api_service.dart';

class CMChecklistRepository {
  final ApiService _apiService;
  
  CMChecklistRepository(this._apiService);

  Future<CMChecklistResponse> getChecklistData(int entityId, String itemType) async {
    try {
      print('🔄 [ChecklistRepo] Fetching checklist data for entityId: $entityId, itemType: $itemType');
      
      final response = await _apiService.get<Map<String, dynamic>>(
        path: '/api/v1/mobile/correctiveMaintenance/checkListDtlForMobile/$entityId/$itemType',
      );

      print('🔍 [ChecklistRepo] Raw API Response:');
      print('   - Status Code: ${response.statusCode}');
      print('   - Is Success: ${response.isSuccess}');
      print('   - Error Message: ${response.errorMessage}');
      print('   - Data Type: ${response.data.runtimeType}');
      print('   - Data: ${response.data}');

      if (response.isSuccess && response.data != null) {
        print('✅ [ChecklistRepo] API response received successfully');
        print('📋 [ChecklistRepo] Response keys: ${response.data?.keys}');
        
        return CMChecklistResponse.fromJson(response.data!);
      } else {
        print('❌ [ChecklistRepo] API error: ${response.errorMessage}');
        throw Exception('Failed to load checklist data: ${response.errorMessage}');
      }
    } catch (e) {
      print('❌ [ChecklistRepo] Error: $e');
      print('❌ [ChecklistRepo] Error type: ${e.runtimeType}');
      rethrow;
    }
  }
}