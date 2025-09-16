import '../services/user_details_service.dart';
import '../services/local_storage_db.dart';
import '../services/local_storage_service.dart';

class DebugUserApi {
  /// Debug method to test the user details API and see what fields are returned
  static Future<void> debugUserDetailsApi() async {
    try {
      print('=== DEBUG USER API ===');
      
      // Check if user is authenticated
      final token = LocalStorageDB.getToken;
      if (token == null || token.isEmpty) {
        print('DEBUG: No token found, user not authenticated');
        return;
      }
      
      print('DEBUG: Token found: ${token.substring(0, 20)}...');
      
      // Force refresh user details to see API response
      print('DEBUG: Calling user details API...');
      final userDetails = await UserDetailsService.instance.refreshUserDetails();
      
      if (userDetails != null) {
        print('DEBUG: User details received:');
        print('  - fullName: ${userDetails.fullName}');
        print('  - firstName: ${userDetails.firstName}');
        print('  - lastName: ${userDetails.lastName}');
        print('  - email: ${userDetails.email}');
        print('  - userId: ${userDetails.userId}');
        print('  - role: ${userDetails.role}');
        print('  - department: ${userDetails.department}');
        print('  - designation: ${userDetails.designation}');
        
        // Check what's stored locally
        final storedFullName = LocalStorageDB.getFullName;
        print('DEBUG: Stored fullName in local storage: $storedFullName');
        
        if (userDetails.fullName == null || userDetails.fullName!.isEmpty) {
          print('DEBUG: WARNING - No fullName found in API response!');
          print('DEBUG: This means the API is using a different field name.');
          print('DEBUG: Please check the API response structure.');
        } else {
          print('DEBUG: SUCCESS - fullName found and stored: ${userDetails.fullName}');
        }
      } else {
        print('DEBUG: Failed to get user details from API');
      }
      
      print('=== END DEBUG USER API ===');
    } catch (e) {
      print('DEBUG: Error in debug method: $e');
    }
  }
  
  /// Test method to manually set a fullName for testing
  static Future<void> testSetFullName(String testName) async {
    try {
      await LocalStorageDB.saveFullName(testName);
      print('DEBUG: Test fullName set to: $testName');
      
      final retrievedName = LocalStorageDB.getFullName;
      print('DEBUG: Retrieved fullName: $retrievedName');
    } catch (e) {
      print('DEBUG: Error setting test fullName: $e');
    }
  }
  
  /// Clear all user data for testing
  static Future<void> clearUserData() async {
    try {
      await LocalStorageService.remove('fullName');
      print('DEBUG: User data cleared');
    } catch (e) {
      print('DEBUG: Error clearing user data: $e');
    }
  }
}
