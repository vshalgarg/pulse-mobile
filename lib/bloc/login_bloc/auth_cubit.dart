import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../constants/constants_strings.dart';
import '../../services/local_storage_constants.dart';
import '../../services/local_storage_db.dart';
import '../../services/local_storage_service.dart';
import '../../models/auth_model.dart';
import '../../repositories/auth_repository.dart';
import '../../services/user_details_service.dart';
import '../../utils.dart';

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
    
    print("AuthCubit: Starting login process for username: $username");
    emit(AuthLoading());
    
    try {
      final result = await authRepository.login(
        username: username,
        password: password,
      );

      print("AuthCubit: Login result - isSuccess: ${result.isSuccess}, errorMessage: ${result.errorMessage}");

      if (result.isSuccess && result.data != null) {
        print("AuthCubit: Login successful, saving tokens to storage");
        // Save tokens to local storage
        await _saveTokensToStorage(result.data!);
        
        // Save user credentials if remember me is checked
        if (rememberMe) {
          await _saveUserCredentials(username, password);
        }
        
        // Fetch user details and save fullName
        print("AuthCubit: Fetching user details...");
        await _fetchAndSaveUserDetails();
        
        print("AuthCubit: Emitting AuthSuccess state");
        emit(AuthSuccess(result.data!));
      } else {
        print("AuthCubit: Login failed, emitting AuthFailure state");
        emit(AuthFailure(result.errorMessage ?? somethingWentWrong));
      }
    } catch (e) {
      print("AuthCubit: Login exception - $e");
      emit(AuthFailure('Login failed: $e'));
    }
  }

  // Save tokens to local storage
  Future<void> _saveTokensToStorage(AuthModel authData) async {
    try {
      // Save access token
      await LocalStorageDB.saveToken(authData.token);
      
      // Save token expiry if available
      if (authData.tokenExpiry != null) {
        await LocalStorageDB.saveTokenExpiry(authData.tokenExpiry!);
      }
      
      // Save user ID if available
      if (authData.userId != null) {
        await LocalStorageService.setString(LocalStorageConstants.userId, authData.userId!);
      }
      
      // Save user info if available
      if (authData.firstName != null) {
        await LocalStorageService.setString(LocalStorageConstants.firstName, authData.firstName!);
      }
      if (authData.email != null) {
        await LocalStorageService.setString(LocalStorageConstants.email, authData.email!);
      }
    } catch (e) {
      // Handle storage error
      emit(AuthFailure('Failed to save authentication token'));
    }
  }

  // Save user credentials for remember me functionality
  Future<void> _saveUserCredentials(String username, String password) async {
    try {
      await LocalStorageDB.saveUsername(username);
      await LocalStorageDB.savePassword(password);
      await LocalStorageDB.setRememberMe(true);
    } catch (e) {
      // Handle storage error
      emit(AuthFailure('Failed to save user credentials'));
    }
  }

  // Logout method
  Future<void> logout() async {
    try {
      print("AuthCubit: Starting logout process");
      
      // Clear user details
      await UserDetailsService.instance.clearUserDetails();
      
      // Clear authentication data
      await LocalStorageDB.logout();
      
      print("AuthCubit: Logout completed, emitting AuthInitial state");
      emit(AuthInitial());
    } catch (e) {
      print("AuthCubit: Logout failed - $e");
      emit(AuthFailure('Failed to logout'));
    }
  }

  // Check if user is logged in
  bool get isLoggedIn {
    final token = LocalStorageDB.getToken;
    print("AuthCubit: Checking if user is logged in - token: ${token != null ? '${token.substring(0, 20)}...' : 'null'}");
    
    if (token == null || token.isEmpty) {
      print("AuthCubit: No token found - user not logged in");
      return false;
    }
    
    // Check if token is expired
    if (Utils.isTokenExpired(token)) {
      print("AuthCubit: Token is expired - clearing token and logging out");
      // Clear expired token
      logout();
      return false;
    }
    
    print("AuthCubit: User is logged in with valid token");
    return true;
  }

  // Get stored token
  String? get getStoredToken => LocalStorageDB.getToken;

  // Auto login with stored credentials
  Future<void> autoLogin() async {
    if (state is AuthLoading) return;
    
    final username = LocalStorageDB.getUsername;
    final password = LocalStorageDB.getPassword;
    final rememberMe = LocalStorageDB.getRememberMe;
    
    // Only auto-login if remember me is enabled and credentials exist
    if (rememberMe && username != null && password != null) {
      emit(AuthLoading());
      
      final result = await authRepository.login(
        username: username,
        password: password,
      );

      if (result.isSuccess && result.data != null) {
        // Save tokens to local storage
        await _saveTokensToStorage(result.data!);
        
        // Fetch user details and save fullName
        print("AuthCubit: Auto-login - Fetching user details...");
        await _fetchAndSaveUserDetails();
        
        emit(AuthSuccess(result.data!));
      } else {
        // Auto-login failed, clear stored credentials
        await LocalStorageDB.clearAllCredentials();
        emit(AuthInitial());
      }
    } else {
      emit(AuthInitial());
    }
  }

  // Check token validity
  bool get isTokenValid {
    final token = LocalStorageDB.getToken;
    if (token == null || token.isEmpty) return false;
    
    return !Utils.isTokenExpired(token);
  }

  // Get token expiration time
  DateTime? get getTokenExpiration => LocalStorageDB.getTokenExpiry;

  // Get remember me status
  bool get getRememberMe => LocalStorageDB.getRememberMe;

  // Get stored username
  String? get getStoredUsername => LocalStorageDB.getUsername;

  // Fetch user details and save fullName
  Future<void> _fetchAndSaveUserDetails() async {
    try {
      final userDetails = await UserDetailsService.instance.getUserDetails();
      if (userDetails != null && userDetails.fullName != null) {
        print("AuthCubit: User details fetched successfully, fullName: ${userDetails.fullName}");
      } else {
        print("AuthCubit: Failed to fetch user details or fullName is null");
      }
    } catch (e) {
      print("AuthCubit: Error fetching user details: $e");
      // Don't fail the login if user details fetch fails
    }
  }

  // Get stored password
  String? get getStoredPassword => LocalStorageDB.getPassword;

  // Force clear all data (for manual logout)
  Future<void> forceClearAllData() async {
    try {
      print("AuthCubit: Force clearing all data");
      await LocalStorageDB.clearAllCredentials();
      print("AuthCubit: All data cleared, emitting AuthInitial state");
      emit(AuthInitial());
    } catch (e) {
      print("AuthCubit: Force clear failed - $e");
      emit(AuthFailure('Failed to clear data'));
    }
  }
}
