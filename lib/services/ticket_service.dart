import 'package:flutter/foundation.dart';
import '../models/ticket_model.dart';
import 'api_service.dart';

class TicketService {
  final ApiService _apiService;

  TicketService({required ApiService apiService}) : _apiService = apiService;

  /// Get tickets based on activity type and ticket type
  /// 
  /// [activityType] - AA (Asset Audit), PM (Preventive Maintenance), ER (Energy Reading)
  /// [ticketType] - ALL, IN_PROGRESS, COMPLETED, CLOSED, MISSED_DEADLINE
  /// [pageSize] - Number of records per page (optional, default = 50)
  /// [pageNo] - Page number (optional, default = 1)
  Future<ResponseResult<TicketResponse>> getTickets({
    required String activityType,
    required String ticketType,
    int? pageSize,
    int? pageNo,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'ActivityType': activityType,
        'type': ticketType,
      };

      if (pageSize != null) {
        queryParams['pageSize'] = pageSize;
      }
      if (pageNo != null) {
        queryParams['pageNo'] = pageNo;
      }

      // Make the API call directly using the underlying Dio client to avoid type casting issues
      final dio = _apiService.apiProvider.getClient();
      final response = await dio.get(
        '/api/v1/mobile/Ticket',
        queryParameters: queryParams,
      );

      if (response.statusCode == 200) {
        final responseData = response.data;

        // Handle different response structures
        if (responseData is Map<String, dynamic>) {
          // API returned the expected TicketResponse structure
          try {
            final ticketResponse = TicketResponse.fromJson(responseData);
            debugPrint("✅ Successfully parsed TicketResponse");
            return ResponseResult.success(ticketResponse, response.statusCode);
          } catch (e) {
            debugPrint("❌ Failed to parse TicketResponse: $e");
            return ResponseResult.error(
              errorMessage: 'Failed to parse TicketResponse: ${e.toString()}',
            );
          }
        } else if (responseData is List<dynamic>) {
          // API returned a list directly - wrap it in TicketResponse
          try {

            final tickets = (responseData as List<dynamic>)
                .map((ticket) {
                  debugPrint("   Parsing ticket: $ticket");
                  return Ticket.fromJson(ticket);
                })
                .toList();
            
            final ticketResponse = TicketResponse(
              pageNo: 1,
              pageSize: tickets.length,
              totalRecords: tickets.length,
              tickets: tickets,
            );
            
            debugPrint("✅ Successfully converted list to TicketResponse with ${tickets.length} tickets");
            return ResponseResult.success(ticketResponse, response.statusCode);
          } catch (e) {
            debugPrint("❌ Failed to parse ticket list: $e");
            debugPrint("   Stack trace: ${StackTrace.current}");
            return ResponseResult.error(
              errorMessage: 'Failed to parse ticket list: ${e.toString()}',
            );
          }
        } else {
          debugPrint("❌ Unexpected response format: ${responseData.runtimeType}");
          return ResponseResult.error(
            errorMessage: 'Unexpected response format: ${responseData.runtimeType}',
          );
        }
      } else {
        debugPrint("❌ API call failed with status: ${response.statusCode}");
        return ResponseResult.error(
          errorMessage: 'Request failed with status code: ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      debugPrint("❌ Exception in getTickets: $e");
      return ResponseResult.error(
        errorMessage: 'Exception occurred: ${e.toString()}',
      );
    }
  }

  /// Get tickets with filter parameters
  Future<ResponseResult<TicketResponse>> getTicketsWithFilter(TicketFilterParams params) async {
    return getTickets(
      activityType: params.activityType,
      ticketType: params.type,
      pageSize: params.pageSize,
      pageNo: params.pageNo,
    );
  }
}
