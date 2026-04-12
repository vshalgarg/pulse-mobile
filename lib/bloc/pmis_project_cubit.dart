import 'package:flutter_bloc/flutter_bloc.dart';

import '../repositories/pmis_repository.dart';
import 'pmis_project_state.dart';

class PmisProjectCubit extends Cubit<PmisProjectState> {
  final PmisRepository _pmisRepository;

  PmisProjectCubit({required PmisRepository pmisRepository})
      : _pmisRepository = pmisRepository,
        super(const PmisProjectInitial());

  Future<void> loadProjects({String? activityType}) async {
    emit(const PmisProjectLoading());
    final result = await _pmisRepository.getProjectList(
      activityType: activityType,
    );
    if (result.isSuccess && result.data != null) {
      emit(PmisProjectSuccess(projects: result.data!));
    } else {
      emit(PmisProjectFailure(
        errorMessage: result.errorMessage ?? 'Failed to load projects',
      ));
    }
  }
}
