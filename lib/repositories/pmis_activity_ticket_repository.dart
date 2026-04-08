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
}
