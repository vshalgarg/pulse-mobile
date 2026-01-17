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

    emit(ResetPasswordLoading());
    
    final result = await authRepository.resetPassword(
      emailId: emailId,
      newPassword: newPassword,
    );

    if (result.isSuccess && result.data != null) {

      emit(ResetPasswordSuccess(result.data!));
    } else {

      emit(ResetPasswordFailure(result.errorMessage ?? somethingWentWrong));
    }
  }
}
