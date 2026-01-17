import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../constants/constants_strings.dart';
import '../models/forgot_password_model.dart';
import '../models/otp_verification_model.dart';
import '../repositories/auth_repository.dart';

part 'otp_verification_state.dart';

class OtpVerificationCubit extends Cubit<OtpVerificationState> {
  AuthRepository authRepository;

  OtpVerificationCubit(this.authRepository) : super(OtpVerificationInitial());

  // Verify OTP method
  Future<void> verifyOtp({
    required String emailId,
    required String otp,
  }) async {
    if (state is OtpVerificationLoading) return;

    emit(OtpVerificationLoading());
    
    final result = await authRepository.verifyOtp(
      emailId: emailId,
      otp: otp,
    );

    if (result.isSuccess && result.data != null) {

      emit(OtpVerificationSuccess(result.data!));
    } else {

      emit(OtpVerificationFailure(result.errorMessage ?? somethingWentWrong));
    }
  }

  // Resend OTP method
  Future<void> resendOtp({
    required String emailId,
  }) async {
    if (state is ResendOtpLoading) return;

    emit(ResendOtpLoading());
    
    final result = await authRepository.resendOtp(
      emailId: emailId,
    );

    if (result.isSuccess && result.data != null) {

      emit(ResendOtpSuccess(result.data!));
    } else {

      emit(ResendOtpFailure(result.errorMessage ?? somethingWentWrong));
    }
  }
}
