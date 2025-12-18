import '../models/user_details_model.dart';
import 'local_storage_db.dart';
import 'local_storage_service.dart';
import 'api_service.dart';
import 'package:dio/dio.dart';

class UserDetailsService {
  static UserDetailsService? _instance;
  static UserDetailsService get instance =>
      _instance ??= UserDetailsService._internal();

  UserDetailsService._internal();

  ApiService? _apiService;

  // Initialize with ApiService
  void initialize(ApiService apiService) {
    _apiService = apiService;
  }

  /// Get user details from API and save to local storage
  /// This method will only call the API if fullName is not already stored locally
  Future<UserDetailsModel?> getUserDetails() async {
    try {
      // Check if ApiService is initialized
      if (_apiService == null) {

        return null;
      }

      // Check if fullName is already stored locally
      // final storedFullName = LocalStorageDB.getFullName;
      // if (storedFullName != null && storedFullName.isNotEmpty) {
      //   return UserDetailsModel(fullName: storedFullName);
      // }

      // Check if user is authenticated
      final token = LocalStorageDB.getToken;
      if (token == null || token.isEmpty) {

        return null;
      }

      // Call the user details API
      final response = await _apiService!.get<Map<String, dynamic>>(
        path: '/api/v1/admin/user-details',
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.isSuccess && response.data != null) {

        // Parse the response
        final userDetails = UserDetailsModel.fromJson(response.data!);

        // Debug: Check what name fields are available

        // Save fullName to local storage
        if (userDetails.fullName != null && userDetails.fullName!.isNotEmpty) {
          await LocalStorageDB.saveFullName(userDetails.fullName!);
          await LocalStorageDB.saveUserId(userDetails.userId!);

          // Get user profile picture if userImageName is available
          if (userDetails.userImageName != null &&
              userDetails.userImageName!.isNotEmpty) {
            await getUserProfilePic(
              userDetails.userId!,
              userDetails.userImageName!,
            );
          }
        } else {

        }

        return userDetails;
      } else {

        return null;
      }
    } catch (e) {

      return null;
    }
  }

  /// Get stored fullName from local storage
  String? getStoredFullName() {
    return LocalStorageDB.getFullName;
  }

  /// Clear stored user details (called during logout)
  Future<void> clearUserDetails() async {
    try {
      await LocalStorageService.remove('fullName');

    } catch (e) {

    }
  }

  /// Force refresh user details from API (ignores local storage)
  Future<UserDetailsModel?> refreshUserDetails() async {
    try {
      // Check if ApiService is initialized
      if (_apiService == null) {

        return null;
      }

      // Check if user is authenticated
      final token = LocalStorageDB.getToken;
      if (token == null || token.isEmpty) {

        return null;
      }

      // Call the user details API
      final response = await _apiService!.get<Map<String, dynamic>>(
        path: '/api/v1/admin/user-details',
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.isSuccess && response.data != null) {

        // Parse the response
        final userDetails = UserDetailsModel.fromJson(response.data!);

        // Save fullName to local storage
        if (userDetails.fullName != null && userDetails.fullName!.isNotEmpty) {
          await LocalStorageDB.saveFullName(userDetails.fullName!);

        }

        return userDetails;
      } else {

        return null;
      }
    } catch (e) {

      return null;
    }
  }

  /// Get user profile picture
  Future<String?> getUserProfilePic(String userId, String userImageName) async {
    try {
      // Check if ApiService is initialized
      if (_apiService == null) {

        return null;
      }

      // Check if user is authenticated
      final token = LocalStorageDB.getToken;
      if (token == null || token.isEmpty) {

        return null;
      }

      final response = await _apiService!.get(
        path: '/api/v1/admin/mobile/userProfile/$userId/$userImageName',
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.isSuccess && response.data != null) {
        await LocalStorageDB.saveUserProfile(response.data['userprofile']);

        return response.data['userprofile'];
      } else {

        return null;
      }
    } catch (e) {

      return null;
    }
  }

  /// Check if user details are stored locally
  bool get hasStoredUserDetails {
    final fullName = LocalStorageDB.getFullName;
    return fullName != null && fullName.isNotEmpty;
  }
}
