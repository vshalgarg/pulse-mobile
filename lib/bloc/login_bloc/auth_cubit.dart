import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../constants/constants_strings.dart';
import '../../hive_local_database/hive_db.dart';
import '../../models/auth_model.dart';
import '../../repositories/auth_repository.dart';

part 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  AuthRepository authRepository;

  AuthCubit(this.authRepository) : super(AuthInitial());

  // Login method
  Future<void> login({
    required String username,
    required String password,
    bool rememberMe = false, // Added rememberMe parameter
  }) async {
    if (state is AuthLoading) return;
    
    emit(AuthLoading());
    
    final result = await authRepository.login(
      username: username,
      password: password,
    );

    if (result.isSuccess && result.data != null) {
      // Save tokens to local storage
      await _saveTokensToStorage(result.data!);
      
      // Save user credentials if remember me is checked
      if (rememberMe) {
        await _saveUserCredentials(username, password);
      }
      
      emit(AuthSuccess(result.data!));
    } else {
      emit(AuthFailure(result.errorMessage ?? somethingWentWrong));
    }
  }

  // Save tokens to local storage
  Future<void> _saveTokensToStorage(AuthModel authData) async {
    try {
      // Save access token
      await HiveDB.saveToken(authData.token);
    } catch (e) {
      // Handle storage error
      emit(AuthFailure('Failed to save authentication token'));
    }
  }

  // Save user credentials for remember me functionality
  Future<void> _saveUserCredentials(String username, String password) async {
    try {
      await HiveDB.saveUsername(username);
      await HiveDB.savePassword(password);
      await HiveDB.setRememberMe(true);
    } catch (e) {
      // Handle storage error
      emit(AuthFailure('Failed to save user credentials'));
    }
  }

  // Logout method
  Future<void> logout() async {
    try {
      await HiveDB.logout();
      emit(AuthInitial());
    } catch (e) {
      emit(AuthFailure('Failed to logout'));
    }
  }

  // Check if user is logged in
  bool get isLoggedIn {
    final token = HiveDB.getToken;
    return token != null && token.isNotEmpty;
  }

  // Get stored token
  String? get getStoredToken => HiveDB.getToken;
}
