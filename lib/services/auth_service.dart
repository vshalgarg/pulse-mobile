import '../hive_local_database/hive_db.dart';

class AuthService {
  static AuthService? _instance;
  static AuthService get instance => _instance ??= AuthService._internal();

  AuthService._internal();

  // Check if user is authenticated
  bool get isAuthenticated {
    final token = HiveDB.getToken;
    return token != null && token.isNotEmpty;
  }

  // Get current token
  String? get currentToken => HiveDB.getToken;

  // Save token
  Future<void> saveToken(String token) async {
    await HiveDB.saveToken(token);
  }

  // Clear token (logout)
  Future<void> clearToken() async {
    await HiveDB.logout();
  }

  // Get authorization header
  String? get authorizationHeader {
    final token = currentToken;
    return token != null ? 'Bearer $token' : null;
  }

  // Remember me functionality
  bool get isRememberMeEnabled => HiveDB.getRememberMe;
  
  String? get savedUsername => HiveDB.getUsername;
  
  String? get savedPassword => HiveDB.getPassword;

  // Save user credentials for remember me
  Future<void> saveUserCredentials(String username, String password) async {
    await HiveDB.saveUsername(username);
    await HiveDB.savePassword(password);
    await HiveDB.setRememberMe(true);
  }

  // Clear all saved credentials
  Future<void> clearAllCredentials() async {
    await HiveDB.clearAllCredentials();
  }
}
