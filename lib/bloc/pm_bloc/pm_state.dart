import 'package:app/models/PmGetDataModel.dart';
import 'package:app/models/PmPostRequestModel.dart';
import 'package:equatable/equatable.dart';

abstract class PmState extends Equatable {
  const PmState();

  @override
  List<Object?> get props => [];
}

class PmGetInitial extends PmState {}

class PmGetLoading extends PmState {}

class PmGetLoaded extends PmState {
  final PmGetDataModel pmGetDataModel;

  const PmGetLoaded({required this.pmGetDataModel});

  @override
  List<Object?> get props => [pmGetDataModel];
}

class PmGetError extends PmState {
  final String message;

  const PmGetError({required this.message});

  @override
  List<Object?> get props => [message];
}

// States for POST operations
class PmPosting extends PmState {}

class PmPostSuccess extends PmState {
  final List<PmPostResponse> responses;

  const PmPostSuccess({required this.responses});

  @override
  List<Object?> get props => [responses];
}

class PmPostError extends PmState {
  final String message;

  const PmPostError({required this.message});

  @override
  List<Object?> get props => [message];
}
