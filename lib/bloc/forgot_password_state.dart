part of 'forgot_password_cubit.dart';

abstract class ForgotPasswordState extends Equatable {
  const ForgotPasswordState();

  @override
  List<Object?> get props => [];
}

class ForgotPasswordInitial extends ForgotPasswordState {}

class ForgotPasswordLoading extends ForgotPasswordState {}

class ForgotPasswordSuccess extends ForgotPasswordState {
  final ForgotPasswordModel forgotPasswordModel;

  const ForgotPasswordSuccess(this.forgotPasswordModel);

  @override
  List<Object?> get props => [forgotPasswordModel];
}

class ForgotPasswordFailure extends ForgotPasswordState {
  final String errorMessage;

  const ForgotPasswordFailure(this.errorMessage);

  @override
  List<Object?> get props => [errorMessage];
}
