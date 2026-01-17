import '../services/local_storage_db.dart';
import '../services/user_details_service.dart';

class UserNameUtils {
  /// Get the user's display name (fullName if available, otherwise firstName, otherwise "User")
  static String getUserDisplayName() {
    // First try to get fullName from local storage
    final fullName = LocalStorageDB.getFullName;
    if (fullName != null && fullName.isNotEmpty) {
       final firstName = fullName.split(' ').first;
      return firstName;
    }

    // Fallback to firstName
    final firstName = LocalStorageDB.getFirstName;
    if (firstName != null && firstName.isNotEmpty) {
      return firstName;
    }

    // Default fallback
    return "User";
  }

  /// Get the user's full name from local storage
  static String? getFullName() {
    return LocalStorageDB.getFullName;
  }

  /// Get the user's first name from local storage
  static String? getFirstName() {
    return LocalStorageDB.getFirstName;
  }

  /// Check if user details are available
  static bool get hasUserDetails {
    final fullName = LocalStorageDB.getFullName;
    final firstName = LocalStorageDB.getFirstName;
    return (fullName != null && fullName.isNotEmpty) || 
           (firstName != null && firstName.isNotEmpty);
  }

  /// Force refresh user details from API
  static Future<String?> refreshUserDetails() async {
    try {
      final userDetails = await UserDetailsService.instance.refreshUserDetails();
      return userDetails?.fullName;
    } catch (e) {

      return null;
    }
  }

  /// Get user details with fallback logic
  static Future<String> getUserDisplayNameWithFallback() async {
    // First try to get from local storage
    String displayName = getUserDisplayName();
    
    // If we only have "User" as fallback, try to refresh from API
    if (displayName == "User") {
      final refreshedName = await refreshUserDetails();
      if (refreshedName != null && refreshedName.isNotEmpty) {
        return refreshedName;
      }
    }
    
    return displayName;
  }

  /// Get user display name with enhanced fallback logic
  static Future<String> getUserDisplayNameEnhanced() async {
    try {
      // First try to get from local storage
      final fullName = LocalStorageDB.getFullName;
      if (fullName != null && fullName.isNotEmpty && fullName != "User") {
        return fullName;
      }

      // Try to get firstName as fallback
      final firstName = LocalStorageDB.getFirstName;
      if (firstName != null && firstName.isNotEmpty && firstName != "User") {
        return firstName;
      }

      // If no local data, try to refresh from API
      final refreshedName = await refreshUserDetails();
      if (refreshedName != null && refreshedName.isNotEmpty) {
        return refreshedName;
      }

      // Final fallback
      return "User";
    } catch (e) {

      return "User";
    }
  }
}
