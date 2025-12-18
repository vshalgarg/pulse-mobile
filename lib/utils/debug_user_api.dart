import '../services/user_details_service.dart';
import '../services/local_storage_db.dart';
import '../services/local_storage_service.dart';

class DebugUserApi {
  /// Debug method to test the user details API and see what fields are returned
  static Future<void> debugUserDetailsApi() async {
    try {

      // Check if user is authenticated
      final token = LocalStorageDB.getToken;
      if (token == null || token.isEmpty) {

        return;
      }

      // Force refresh user details to see API response

      final userDetails = await UserDetailsService.instance.refreshUserDetails();
      
      if (userDetails != null) {

        // Check what's stored locally
        final storedFullName = LocalStorageDB.getFullName;

        if (userDetails.fullName == null || userDetails.fullName!.isEmpty) {

        } else {

        }
      } else {

      }

    } catch (e) {

    }
  }
  
  /// Test method to manually set a fullName for testing
  static Future<void> testSetFullName(String testName) async {
    try {
      await LocalStorageDB.saveFullName(testName);

      final retrievedName = LocalStorageDB.getFullName;

    } catch (e) {

    }
  }
  
  /// Clear all user data for testing
  static Future<void> clearUserData() async {
    try {
      await LocalStorageService.remove('fullName');

    } catch (e) {

    }
  }
}
