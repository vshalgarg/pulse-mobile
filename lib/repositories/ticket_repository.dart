import '../models/ticket_model.dart';
import '../services/api_service.dart';
import '../services/ticket_service.dart';

class TicketRepository {
  final TicketService _ticketService;

  TicketRepository({required TicketService ticketService}) : _ticketService = ticketService;

  Future<ResponseResult<TicketResponse>> getTickets(TicketFilterParams params) async {
    try {
      return await _ticketService.getTicketsWithFilter(params);
    } catch (e) {
      return ResponseResult.error(
        errorMessage: 'Exception occurred: ${e.toString()}',
      );
    }
  }
}
