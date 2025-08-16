part of 'demo_bloc_cubit.dart';

abstract class DemoBlocState extends Equatable {
  const DemoBlocState();
}

class DemoBlocInitial extends DemoBlocState {
  @override
  List<Object> get props => [];
}

class DemoBlocLoading extends DemoBlocState {
  @override
  List<Object> get props => [];
}

class DemoBlocSuccess extends DemoBlocState {
  final AskModel askModel;

  const DemoBlocSuccess(this.askModel);

  @override
  List<Object> get props => [askModel];
}

class DemoBlocFailure extends DemoBlocState {
  final String msg;

  const DemoBlocFailure(this.msg);

  @override
  List<Object> get props => [msg];
}
