import 'package:app/hive_local_database/hive_db.dart';
import 'package:app/utils.dart';

class AuthService {
  static AuthService? _instance;
  static AuthService get instance => _instance ??= AuthService._internal();
  
  AuthService._internal();

  // Check if user is authenticated
  bool get isAuthenticated {
    final token = HiveDB.getToken;
    if (token == null || token.isEmpty) return false;
    
    return !Utils.isTokenExpired(token);
  }

  // Get current token
  String? get currentToken => HiveDB.getToken;

  // Get token expiration
  DateTime? get tokenExpiration => HiveDB.getTokenExpiry;

  // Check if token will expire soon (within 5 minutes)
  bool get isTokenExpiringSoon {
    final expiry = tokenExpiration;
    if (expiry == null) return true;
    
    final now = DateTime.now();
    final fiveMinutesFromNow = now.add(const Duration(minutes: 5));
    
    return expiry.isBefore(fiveMinutesFromNow);
  }

  // Logout user
  Future<void> logout() async {
    await HiveDB.logout();
  }

  // Clear all data
  Future<void> clearAllData() async {
    await HiveDB.clearAllData();
  }

  // Get headers with token
  Map<String, String> getAuthHeaders() {
    final token = currentToken;
    if (token != null && !Utils.isTokenExpired(token)) {
      return {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };
    }
    return {
      'Content-Type': 'application/json',
    };
  }

  // Validate token format
  bool isValidTokenFormat(String? token) {
    if (token == null || token.isEmpty) return false;
    
    // Basic JWT format validation (3 parts separated by dots)
    final parts = token.split('.');
    return parts.length == 3;
  }
}
