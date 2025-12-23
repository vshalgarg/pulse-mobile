import 'package:app/models/incident_ticket_request_model.dart';
import 'package:app/utils/logger.dart';

import '../services/api_service.dart';

class IncidentRepository {
  final ApiService _apiService;

  IncidentRepository(this._apiService);

  Future<Map<String, List<Map<String, dynamic>>>> getIncidentChecklist() async {
    try {
      Logger.debugLog('[IncidentRepository] Starting to fetch incident checklist data');
      
      final response = await _apiService.get<Map<String, dynamic>>(
        path: '/api/v1/om-schedule/incidentTicket/checkList',
      );

      Logger.debugLog('[IncidentRepository] API response received - Success: ${response.isSuccess}');

      if (response.isSuccess && response.data != null) {
        final data = response.data!['data'];
        
        if (data is Map<String, dynamic>) {
          final Map<String, dynamic> rawData = data;
          Logger.debugLog('[IncidentRepository] Processing ${rawData.length} incident item types');
          
          final Map<String, List<Map<String, dynamic>>> checklistData = {};
          
          for (final entry in rawData.entries) {
            final itemType = entry.key;
            final items = entry.value;
            try {
              if (items is List) {
                final List<Map<String, dynamic>> parsedItems = [];
                for (int i = 0; i < items.length; i++) {
                  try {
                    final itemJson = items[i];
                    if (itemJson is Map<String, dynamic>) {
                      parsedItems.add(Map<String, dynamic>.from(itemJson));
                    } else {
                      Logger.errorLog('[IncidentRepository] Item at index $i for type "$itemType" is not a Map, got ${itemJson.runtimeType}');
                    }
                  } catch (e) {
                    Logger.errorLog('[IncidentRepository] Error parsing checklist item at index $i for type "$itemType": $e');
                    Logger.errorLog('[IncidentRepository] Problematic item data: ${items[i]}');
                    // Continue with other items instead of crashing
                    continue;
                  }
                }
                checklistData[itemType] = parsedItems;
                Logger.debugLog('[IncidentRepository] Successfully parsed ${parsedItems.length} items for type "$itemType"');
              } else {
                Logger.errorLog('[IncidentRepository] Items for type "$itemType" is not a List, got ${items.runtimeType}');
              }
            } catch (e) {
              Logger.errorLog('[IncidentRepository] Error processing item type "$itemType": $e');
              // Continue with other item types instead of crashing
            }
          }
          
          final totalItems = checklistData.values.fold<int>(0, (sum, list) => sum + list.length);
          Logger.infoLog('[IncidentRepository] Successfully parsed $totalItems checklist items across ${checklistData.length} item types');
          return checklistData;
        } else {
          Logger.errorLog('[IncidentRepository] Expected Map but got ${data.runtimeType}');
          throw Exception('Invalid response format: expected Map but got ${data.runtimeType}');
        }
      } else {
        Logger.errorLog('[IncidentRepository] API call failed: - Success: ${response.isSuccess} - Error: ${response.errorMessage} - Status Code: ${response.statusCode}');
        throw Exception('Failed to load checklist data: ${response.errorMessage}');
      }
    } catch (e) {
      Logger.errorLog('[IncidentRepository] Exception in getIncidentChecklist: $e');
      Logger.errorLog('[IncidentRepository] Stack trace: ${StackTrace.current}');
      throw Exception('Failed to load checklist data: $e');
    }
  }

  Future<Map<String, dynamic>> postIncidentTicket({
    required IncidentTicketRequest request,
  }) async {
    try {
      Logger.debugLog('[IncidentRepository] Starting to post incident ticket');
      Logger.debugLog('[IncidentRepository] Request data: ${request.toJson()}');

      final response = await _apiService.post<Map<String, dynamic>>(
        path: '/api/v1/om-schedule/incidentTicket',
        data: request.toJson(),
      );

      Logger.debugLog(
        '[IncidentRepository] API response received - Success: ${response.isSuccess}',
      );

      if (response.isSuccess && response.data != null) {
        Logger.infoLog(
          '[IncidentRepository] Successfully posted incident ticket',
        );
        return response.data!;
      } else {
        Logger.errorLog(
          '[IncidentRepository] API call failed: - Success: ${response.isSuccess} - Error: ${response.errorMessage} - Status Code: ${response.statusCode}',
        );
        throw Exception(
          'Failed to post incident ticket: ${response.errorMessage}',
        );
      }
    } catch (e) {
      Logger.errorLog('[IncidentRepository] Exception in postIncidentTicket: $e');
      Logger.errorLog(
        '[IncidentRepository] Stack trace: ${StackTrace.current}',
      );
      throw Exception('Failed to post incident ticket: $e');
    }
  }
}

