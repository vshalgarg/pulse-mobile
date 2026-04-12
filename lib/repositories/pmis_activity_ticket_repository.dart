import '../models/pmis_activity_ticket_model.dart';
import '../services/api_service.dart';
import '../services/pmis_activity_ticket_service.dart';

class PmisActivityTicketRepository {
  final PmisActivityTicketService _pmisService;

  PmisActivityTicketRepository({
    required PmisActivityTicketService pmisService,
  }) : _pmisService = pmisService;

  Future<ResponseResult<PmisActivityTicketDetail>> getActivityTicket({
    required int activityTicketId,
  }) async {
    try {
      return await _pmisService.getActivityTicket(
        activityTicketId: activityTicketId,
      );
    } catch (e) {
      return ResponseResult.error(
        errorMessage: 'Exception occurred: ${e.toString()}',
      );
    }
  }

  /// Fetches the ticket then calls `DocumentById` for each attachment id
  /// (used from the activities list before opening the checker screen).
  Future<ResponseResult<PmisActivityTicketDetail>>
      getActivityTicketWithDocumentWarmup({
    required int activityTicketId,
  }) async {
    try {
      return await _pmisService.getActivityTicketWithDocumentWarmup(
        activityTicketId: activityTicketId,
      );
    } catch (e) {
      return ResponseResult.error(
        errorMessage: 'Exception occurred: ${e.toString()}',
      );
    }
  }

  Future<ResponseResult<Map<String, dynamic>?>> postActivityTicket({
    required Map<String, dynamic> payload,
  }) async {
    try {
      return await _pmisService.postActivityTicket(payload: payload);
    } catch (e) {
      return ResponseResult.error(
        errorMessage: 'Exception occurred: ${e.toString()}',
      );
    }
  }
}
