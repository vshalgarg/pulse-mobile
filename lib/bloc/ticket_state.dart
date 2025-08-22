import 'package:equatable/equatable.dart';
import '../models/ticket_model.dart';

abstract class TicketState extends Equatable {
  const TicketState();

  @override
  List<Object?> get props => [];
}

class TicketInitial extends TicketState {
  const TicketInitial();
}

class TicketLoading extends TicketState {
  const TicketLoading();
}

class TicketSuccess extends TicketState {
  final TicketResponse ticketResponse;
  final String activityType;
  final String ticketType;

  const TicketSuccess({
    required this.ticketResponse,
    required this.activityType,
    required this.ticketType,
  });

  @override
  List<Object?> get props => [ticketResponse, activityType, ticketType];
}

class TicketFailure extends TicketState {
  final String errorMessage;

  const TicketFailure({required this.errorMessage});

  @override
  List<Object?> get props => [errorMessage];
}

class TicketRefresh extends TicketState {
  const TicketRefresh();
}
