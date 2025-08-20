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
    
    print("ForgotPasswordCubit: Starting forgot password process");
    emit(ForgotPasswordLoading());
    
    final result = await authRepository.forgotPassword(
      email: email,
    );

    print("ForgotPasswordCubit: Repository result - isSuccess: ${result.isSuccess}, data: ${result.data}");

    if (result.isSuccess && result.data != null) {
      print("ForgotPasswordCubit: Emitting success state");
      emit(ForgotPasswordSuccess(result.data!));
    } else {
      print("ForgotPasswordCubit: Emitting failure state with error: ${result.errorMessage}");
      emit(ForgotPasswordFailure(result.errorMessage ?? somethingWentWrong));
    }
  }
}
