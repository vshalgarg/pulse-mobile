part of 'global_loading_cubit.dart';

abstract class GlobalLoadingState extends Equatable {
  const GlobalLoadingState();

  @override
  List<Object?> get props => [];
}

class GlobalLoadingInitial extends GlobalLoadingState {}

class GlobalLoadingShow extends GlobalLoadingState {
  final String message;

  const GlobalLoadingShow({required this.message});

  @override
  List<Object?> get props => [message];
}

class GlobalLoadingHide extends GlobalLoadingState {}
