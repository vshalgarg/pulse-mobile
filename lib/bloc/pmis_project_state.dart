import 'package:equatable/equatable.dart';

import '../models/pmis_project_model.dart';

abstract class PmisProjectState extends Equatable {
  const PmisProjectState();

  @override
  List<Object?> get props => [];
}

class PmisProjectInitial extends PmisProjectState {
  const PmisProjectInitial();
}

class PmisProjectLoading extends PmisProjectState {
  const PmisProjectLoading();
}

class PmisProjectSuccess extends PmisProjectState {
  final List<PmisProject> projects;

  const PmisProjectSuccess({required this.projects});

  @override
  List<Object?> get props => [projects];
}

class PmisProjectFailure extends PmisProjectState {
  final String errorMessage;

  const PmisProjectFailure({required this.errorMessage});

  @override
  List<Object?> get props => [errorMessage];
}
