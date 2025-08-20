part of 'otp_verification_cubit.dart';

abstract class OtpVerificationState extends Equatable {
  const OtpVerificationState();

  @override
  List<Object?> get props => [];
}

class OtpVerificationInitial extends OtpVerificationState {}

class OtpVerificationLoading extends OtpVerificationState {}

class OtpVerificationSuccess extends OtpVerificationState {
  final OtpVerificationModel otpVerificationModel;

  const OtpVerificationSuccess(this.otpVerificationModel);

  @override
  List<Object?> get props => [otpVerificationModel];
}

class OtpVerificationFailure extends OtpVerificationState {
  final String errorMessage;

  const OtpVerificationFailure(this.errorMessage);

  @override
  List<Object?> get props => [errorMessage];
}

class ResendOtpLoading extends OtpVerificationState {}

class ResendOtpSuccess extends OtpVerificationState {
  final ForgotPasswordModel forgotPasswordModel;

  const ResendOtpSuccess(this.forgotPasswordModel);

  @override
  List<Object?> get props => [forgotPasswordModel];
}

class ResendOtpFailure extends OtpVerificationState {
  final String errorMessage;

  const ResendOtpFailure(this.errorMessage);

  @override
  List<Object?> get props => [errorMessage];
}
