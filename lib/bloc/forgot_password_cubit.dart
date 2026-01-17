import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../constants/constants_strings.dart';
import '../models/forgot_password_model.dart';
import '../repositories/auth_repository.dart';

part 'forgot_password_state.dart';

class ForgotPasswordCubit extends Cubit<ForgotPasswordState> {
  AuthRepository authRepository;

  ForgotPasswordCubit(this.authRepository) : super(ForgotPasswordInitial());

  // Forgot Password method
  Future<void> forgotPassword({
    required String email,
  }) async {
    if (state is ForgotPasswordLoading) return;

    emit(ForgotPasswordLoading());
    
    final result = await authRepository.forgotPassword(
      email: email,
    );

    if (result.isSuccess && result.data != null) {

      emit(ForgotPasswordSuccess(result.data!));
    } else {

      emit(ForgotPasswordFailure(result.errorMessage ?? somethingWentWrong));
    }
  }
}
