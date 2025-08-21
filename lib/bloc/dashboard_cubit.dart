import 'package:app/models/dashboard_model.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../constants/constants_strings.dart';
import '../repositories/dashboard_repository.dart';

part 'dashboard_state.dart';

class DashboardCubit extends Cubit<DashboardState> {
  DashboardRepository dashboardRepository;

  DashboardCubit(this.dashboardRepository) : super(DashboardInitial());

  // Get dashboard count
  Future<void> getDashboardCount() async {
    if (state is DashboardLoading) return;
    emit(DashboardLoading());
    final result = await dashboardRepository.getDashboardCount();
    if (result.isSuccess) {
      emit(DashboardSuccess(result.data!));
    } else {
      emit(DashboardFailure(result.errorMessage ?? somethingWentWrong));
    }
  }
}
