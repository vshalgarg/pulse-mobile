import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../constants/constants_strings.dart';
import '../models/reset_password_model.dart';
import '../repositories/auth_repository.dart';

part 'reset_password_state.dart';

class ResetPasswordCubit extends Cubit<ResetPasswordState> {
  AuthRepository authRepository;

  ResetPasswordCubit(this.authRepository) : super(ResetPasswordInitial());

  // Reset Password method
  Future<void> resetPassword({
    required String emailId,
    required String newPassword,
  }) async {
    if (state is ResetPasswordLoading) return;
    
    print("ResetPasswordCubit: Starting reset password process");
    emit(ResetPasswordLoading());
    
    final result = await authRepository.resetPassword(
      emailId: emailId,
      newPassword: newPassword,
    );

    print("ResetPasswordCubit: Repository result - isSuccess: ${result.isSuccess}, data: ${result.data}");

    if (result.isSuccess && result.data != null) {
      print("ResetPasswordCubit: Emitting success state");
      emit(ResetPasswordSuccess(result.data!));
    } else {
      print("ResetPasswordCubit: Emitting failure state with error: ${result.errorMessage}");
      emit(ResetPasswordFailure(result.errorMessage ?? somethingWentWrong));
    }
  }
}
