part of 'reset_password_cubit.dart';

abstract class ResetPasswordState extends Equatable {
  const ResetPasswordState();

  @override
  List<Object?> get props => [];
}

class ResetPasswordInitial extends ResetPasswordState {}

class ResetPasswordLoading extends ResetPasswordState {}

class ResetPasswordSuccess extends ResetPasswordState {
  final ResetPasswordModel resetPasswordModel;

  const ResetPasswordSuccess(this.resetPasswordModel);

  @override
  List<Object?> get props => [resetPasswordModel];
}

class ResetPasswordFailure extends ResetPasswordState {
  final String errorMessage;

  const ResetPasswordFailure(this.errorMessage);

  @override
  List<Object?> get props => [errorMessage];
}
