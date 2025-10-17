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
        print('UserDetailsService: ApiService not initialized');
        return null;
      }

      // Check if fullName is already stored locally
      // final storedFullName = LocalStorageDB.getFullName;
      // if (storedFullName != null && storedFullName.isNotEmpty) {
      //   print('UserDetailsService: FullName already stored locally: $storedFullName');
      //   return UserDetailsModel(fullName: storedFullName);
      // }

      // Check if user is authenticated
      final token = LocalStorageDB.getToken;
      if (token == null || token.isEmpty) {
        print('UserDetailsService: No token found, user not authenticated');
        return null;
      }

      print('UserDetailsService: Fetching user details from API...');

      // Call the user details API
      final response = await _apiService!.get<Map<String, dynamic>>(
        path: '/api/v1/admin/user-details',
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.isSuccess && response.data != null) {
        print(
          'UserDetailsService: API call successful, response: ${response.data}',
        );
        print(
          'UserDetailsService: Available fields in response: ${response.data!.keys.toList()}',
        );

        // Parse the response
        final userDetails = UserDetailsModel.fromJson(response.data!);

        // Debug: Check what name fields are available
        print('UserDetailsService: Parsed fullName: ${userDetails.fullName}');
        print('UserDetailsService: Parsed firstName: ${userDetails.firstName}');
        print('UserDetailsService: Parsed lastName: ${userDetails.lastName}');

        // Save fullName to local storage
        if (userDetails.fullName != null && userDetails.fullName!.isNotEmpty) {
          await LocalStorageDB.saveFullName(userDetails.fullName!);
          await LocalStorageDB.saveUserId(userDetails.userId!);
          print(
            'UserDetailsService: FullName saved to local storage: ${userDetails.fullName}',
          );

          // Get user profile picture if userImageName is available
          if (userDetails.userImageName != null &&
              userDetails.userImageName!.isNotEmpty) {
            await getUserProfilePic(
              userDetails.userId!,
              userDetails.userImageName!,
            );
          }
        } else {
          print('UserDetailsService: No fullName found in API response');
        }

        return userDetails;
      } else {
        print('UserDetailsService: API call failed: ${response.errorMessage}');
        return null;
      }
    } catch (e) {
      print('UserDetailsService: Error fetching user details: $e');
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
      print('UserDetailsService: User details cleared from local storage');
    } catch (e) {
      print('UserDetailsService: Error clearing user details: $e');
    }
  }

  /// Force refresh user details from API (ignores local storage)
  Future<UserDetailsModel?> refreshUserDetails() async {
    try {
      // Check if ApiService is initialized
      if (_apiService == null) {
        print('UserDetailsService: ApiService not initialized');
        return null;
      }

      // Check if user is authenticated
      final token = LocalStorageDB.getToken;
      if (token == null || token.isEmpty) {
        print('UserDetailsService: No token found, user not authenticated');
        return null;
      }

      print('UserDetailsService: Force refreshing user details from API...');

      // Call the user details API
      final response = await _apiService!.get<Map<String, dynamic>>(
        path: '/api/v1/admin/user-details',
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.isSuccess && response.data != null) {
        print(
          'UserDetailsService: API call successful, response: ${response.data}',
        );

        // Parse the response
        final userDetails = UserDetailsModel.fromJson(response.data!);

        // Save fullName to local storage
        if (userDetails.fullName != null && userDetails.fullName!.isNotEmpty) {
          await LocalStorageDB.saveFullName(userDetails.fullName!);
          print(
            'UserDetailsService: FullName saved to local storage: ${userDetails.fullName}',
          );
        }

        return userDetails;
      } else {
        print('UserDetailsService: API call failed: ${response.errorMessage}');
        return null;
      }
    } catch (e) {
      print('UserDetailsService: Error refreshing user details: $e');
      return null;
    }
  }

  /// Get user profile picture
  Future<String?> getUserProfilePic(String userId, String userImageName) async {
    try {
      // Check if ApiService is initialized
      if (_apiService == null) {
        print('UserDetailsService: ApiService not initialized');
        return null;
      }

      // Check if user is authenticated
      final token = LocalStorageDB.getToken;
      if (token == null || token.isEmpty) {
        print('UserDetailsService: No token found, user not authenticated');
        return null;
      }

      final response = await _apiService!.get(
        path: '/api/v1/admin/mobile/userProfile/$userId/$userImageName',
        headers: {'Authorization': 'Bearer $token'},
      );

      print('UserDetailsService: Response: ${response.data['userprofile']}');

      if (response.isSuccess && response.data != null) {
        await LocalStorageDB.saveUserProfile(response.data['userprofile']);
        print(
          'UserDetailsService: Profile picture fetched successfully, response.data: ${response.data}',
        );
        return response.data['userprofile'];
      } else {
        print(
          'UserDetailsService: Failed to fetch profile picture: ${response.errorMessage}',
        );
        return null;
      }
    } catch (e) {
      print('UserDetailsService: Error fetching user profile picture: $e');
      return null;
    }
  }

  /// Check if user details are stored locally
  bool get hasStoredUserDetails {
    final fullName = LocalStorageDB.getFullName;
    return fullName != null && fullName.isNotEmpty;
  }
}
