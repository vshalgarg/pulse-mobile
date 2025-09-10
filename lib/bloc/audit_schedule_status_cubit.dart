import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:app/repositories/audit_schedule_repository.dart';

// States
abstract class AuditScheduleStatusState {}

class AuditScheduleStatusInitial extends AuditScheduleStatusState {}

class AuditScheduleStatusLoading extends AuditScheduleStatusState {}

class AuditScheduleStatusSuccess extends AuditScheduleStatusState {
  final String message;

  AuditScheduleStatusSuccess({required this.message});
}

class AuditScheduleStatusError extends AuditScheduleStatusState {
  final String error;

  AuditScheduleStatusError({required this.error});
}

class AuditScheduleStatusCubit extends Cubit<AuditScheduleStatusState> {
  final AuditScheduleRepository _repository;

  AuditScheduleStatusCubit(this._repository)
      : super(AuditScheduleStatusInitial());

  Future<void> updateStatus({
    required String status,
    required String siteAuditSchId,
  }) async {
    try {
      emit(AuditScheduleStatusLoading());

      final response = await _repository.updateAuditScheduleStatus(
        status: status,
        siteAuditSchId: siteAuditSchId,
      );

      emit(AuditScheduleStatusSuccess(message: response.message));
    } catch (e) {
      emit(AuditScheduleStatusError(error: e.toString()));
    }
  }

  void reset() => emit(AuditScheduleStatusInitial());
}

