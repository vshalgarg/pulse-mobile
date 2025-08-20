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
    
    print("OtpVerificationCubit: Starting OTP verification process");
    emit(OtpVerificationLoading());
    
    final result = await authRepository.verifyOtp(
      emailId: emailId,
      otp: otp,
    );

    print("OtpVerificationCubit: Repository result - isSuccess: ${result.isSuccess}, data: ${result.data}");

    if (result.isSuccess && result.data != null) {
      print("OtpVerificationCubit: Emitting success state");
      emit(OtpVerificationSuccess(result.data!));
    } else {
      print("OtpVerificationCubit: Emitting failure state with error: ${result.errorMessage}");
      emit(OtpVerificationFailure(result.errorMessage ?? somethingWentWrong));
    }
  }

  // Resend OTP method
  Future<void> resendOtp({
    required String emailId,
  }) async {
    if (state is ResendOtpLoading) return;
    
    print("OtpVerificationCubit: Starting resend OTP process");
    emit(ResendOtpLoading());
    
    final result = await authRepository.resendOtp(
      emailId: emailId,
    );

    print("OtpVerificationCubit: Resend OTP result - isSuccess: ${result.isSuccess}, data: ${result.data}");

    if (result.isSuccess && result.data != null) {
      print("OtpVerificationCubit: Emitting resend success state");
      emit(ResendOtpSuccess(result.data!));
    } else {
      print("OtpVerificationCubit: Emitting resend failure state with error: ${result.errorMessage}");
      emit(ResendOtpFailure(result.errorMessage ?? somethingWentWrong));
    }
  }
}
