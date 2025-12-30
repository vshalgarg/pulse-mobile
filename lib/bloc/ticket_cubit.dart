import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/foundation.dart';
import '../models/ticket_model.dart';
import '../repositories/ticket_repository.dart';
import 'ticket_state.dart';

class TicketCubit extends Cubit<TicketState> {
  final TicketRepository _ticketRepository;

  TicketCubit({required TicketRepository ticketRepository})
      : _ticketRepository = ticketRepository,
        super(const TicketInitial());

  Future<void> getTickets({
    required String activityType,
    required String ticketType,
    int? pageSize,
    int? pageNo,
  }) async {
    try {
     
      
      emit(const TicketLoading());

      final filterParams = TicketFilterParams(
        activityType: activityType,
        type: ticketType,
        pageSize: pageSize,
        pageNo: pageNo,
      );

      final result = await _ticketRepository.getTickets(filterParams);

      if (result.isSuccess) {
        final ticketResponse = result.data as TicketResponse;
      
        emit(TicketSuccess(
          ticketResponse: ticketResponse,
          activityType: activityType,
          ticketType: ticketType,
        ));
      } else {
        debugPrint("🔍 TicketCubit: API call failed!");
        debugPrint("   Error: ${result.errorMessage}");
        emit(TicketFailure(errorMessage: result.errorMessage ?? 'Failed to fetch tickets'));
      }
    } catch (e) {
      debugPrint("🔍 TicketCubit: Exception occurred!");
      debugPrint("   Error: $e");
      emit(TicketFailure(errorMessage: e.toString()));
    }
  }

  Future<void> refreshTickets({
    required String activityType,
    required String ticketType,
    int? pageSize,
    int? pageNo,
  }) async {
    try {
      emit(const TicketRefresh());
      await getTickets(
        activityType: activityType,
        ticketType: ticketType,
        pageSize: pageSize,
        pageNo: pageNo,
      );
    } catch (e) {
      emit(TicketFailure(errorMessage: e.toString()));
    }
  }

  Future<void> loadMoreTickets({
    required String activityType,
    required String ticketType,
    required int currentPage,
    int? pageSize,
  }) async {
    try {
      final currentState = state;
      if (currentState is TicketSuccess) {
        final nextPage = currentPage + 1;
        final result = await _ticketRepository.getTickets(
          TicketFilterParams(
            activityType: activityType,
            type: ticketType,
            pageSize: pageSize,
            pageNo: nextPage,
          ),
        );

        if (result.isSuccess) {
          final newTicketResponse = result.data as TicketResponse;
          final updatedTickets = [
            ...currentState.ticketResponse.tickets,
            ...newTicketResponse.tickets,
          ];

          final updatedResponse = TicketResponse(
            pageNo: newTicketResponse.pageNo,
            pageSize: newTicketResponse.pageSize,
            totalRecords: newTicketResponse.totalRecords,
            tickets: updatedTickets,
          );

          emit(TicketSuccess(
            ticketResponse: updatedResponse,
            activityType: activityType,
            ticketType: ticketType,
          ));
        }
      }
    } catch (e) {
      emit(TicketFailure(errorMessage: e.toString()));
    }
  }

  void resetState() {
    emit(const TicketInitial());
  }
}
