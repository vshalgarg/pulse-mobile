import 'local_storage_service.dart';
import 'local_storage_constants.dart';

class LocalStorageDB {
  LocalStorageDB._();

  static Future<void> init() async {
    await LocalStorageService.init();
  }

  // User Credentials Management
  static String? get getUserId =>
      LocalStorageService.getString(LocalStorageConstants.userId);

  static String? get getFireBaseToken =>
      LocalStorageService.getString(LocalStorageConstants.firebaseToken);

  static String? get getEmail =>
      LocalStorageService.getString(LocalStorageConstants.email);

  static String? get getToken =>
      LocalStorageService.getString(LocalStorageConstants.token);

  static Future<void> saveToken(String token) async {
    await LocalStorageService.setString(LocalStorageConstants.token, token);
  }

  static DateTime? get getTokenExpiry {
    final expiryString = LocalStorageService.getString(
      LocalStorageConstants.tokenExpiry,
    );
    if (expiryString != null) {
      try {
        return DateTime.parse(expiryString);
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  static Future<void> saveTokenExpiry(DateTime expiry) async {
    await LocalStorageService.setString(
      LocalStorageConstants.tokenExpiry,
      expiry.toIso8601String(),
    );
  }

  static Future<void> saveUsername(String username) async {
    await LocalStorageService.setString(
      LocalStorageConstants.username,
      username,
    );
  }

  static Future<void> savePassword(String password) async {
    await LocalStorageService.setString(
      LocalStorageConstants.password,
      password,
    );
  }

  static Future<void> setRememberMe(bool rememberMe) async {
    await LocalStorageService.setBool(
      LocalStorageConstants.rememberMe,
      rememberMe,
    );
  }

  static String? get getUsername =>
      LocalStorageService.getString(LocalStorageConstants.username);

  static String? get getPassword =>
      LocalStorageService.getString(LocalStorageConstants.password);

  static bool get getRememberMe =>
      LocalStorageService.getBool(LocalStorageConstants.rememberMe) ?? false;

  static String? get getCartCount =>
      LocalStorageService.getString(LocalStorageConstants.cartCount);

  static Future<void> setCartCount(int? cartCount) async {
    await LocalStorageService.setInt(
      LocalStorageConstants.cartCount,
      cartCount ?? 0,
    );
  }

  // Profile Management
  static String? get getProfileImage =>
      LocalStorageService.getString(LocalStorageConstants.profileImage);

  static String? get getFirstName =>
      LocalStorageService.getString(LocalStorageConstants.firstName);

  static Future<void> saveFullName(String fullName) async {
    await LocalStorageService.setString(
      LocalStorageConstants.fullName,
      fullName,
    );
  }

  static Future<void> saveUserId(String user_id) async {
    await LocalStorageService.setString(LocalStorageConstants.userId, user_id);
  }

  static String? get getFullName =>
      LocalStorageService.getString(LocalStorageConstants.fullName);

  static String? get appSessionKey =>
      LocalStorageService.getString('sessionKey');

  // Energy Reading Form Data Methods
  static Future<void> saveEnergyReadingFormData(
    Map<String, dynamic> formData,
  ) async {
    await LocalStorageService.setJson(
      LocalStorageConstants.energyReadingFormData,
      formData,
    );
  }

  static Map<String, dynamic>? get getEnergyReadingFormData {
    try {
      return LocalStorageService.getJson(
        LocalStorageConstants.energyReadingFormData,
      );
    } catch (e) {
      print('Error loading energy reading form data: $e');
      clearCorruptedEnergyReadingData();
      return null;
    }
  }

  static Future<void> saveEnergyReadingIds({
    required String auditSchId,
    required String siteAuditSchId,
    required String siteId,
  }) async {
    await LocalStorageService.setString(
      LocalStorageConstants.energyReadingAuditSchId,
      auditSchId,
    );
    await LocalStorageService.setString(
      LocalStorageConstants.energyReadingSiteAuditSchId,
      siteAuditSchId,
    );
    await LocalStorageService.setString(
      LocalStorageConstants.energyReadingSiteId,
      siteId,
    );
  }

  static String? get getEnergyReadingAuditSchId =>
      LocalStorageService.getString(
        LocalStorageConstants.energyReadingAuditSchId,
      );

  static String? get getEnergyReadingSiteAuditSchId =>
      LocalStorageService.getString(
        LocalStorageConstants.energyReadingSiteAuditSchId,
      );

  static String? get getEnergyReadingSiteId =>
      LocalStorageService.getString(LocalStorageConstants.energyReadingSiteId);

  static Future<void> clearEnergyReadingData() async {
    await LocalStorageService.remove(
      LocalStorageConstants.energyReadingFormData,
    );
    await LocalStorageService.remove(
      LocalStorageConstants.energyReadingAuditSchId,
    );
    await LocalStorageService.remove(
      LocalStorageConstants.energyReadingSiteAuditSchId,
    );
    await LocalStorageService.remove(LocalStorageConstants.energyReadingSiteId);
  }

  static Future<void> clearCorruptedEnergyReadingData() async {
    await LocalStorageService.remove(
      LocalStorageConstants.energyReadingFormData,
    );
  }

  // Asset Audit Image Management Methods
  static Future<void> saveAssetAuditSelfie({
    required String siteAuditSchId,
    required String imageId,
    required String imageData,
  }) async {
    final key = '${LocalStorageConstants.assetAuditSelfieKey}$siteAuditSchId';
    await LocalStorageService.setJson(key, {
      'imageId': imageId,
      'imageData': imageData,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
    print(
      'LocalStorageDB: Saved selfie for site $siteAuditSchId with image ID $imageId',
    );
  }

  static Map<String, dynamic>? getAssetAuditSelfie(String siteAuditSchId) {
    final key = '${LocalStorageConstants.assetAuditSelfieKey}$siteAuditSchId';
    final data = LocalStorageService.getJson(key);
    if (data != null) {
      print('LocalStorageDB: Retrieved selfie for site $siteAuditSchId');
      return data;
    }
    return null;
  }

  static Future<void> updateAssetAuditSelfie({
    required String siteAuditSchId,
    required String newImageId,
    required String newImageData,
  }) async {
    final key = '${LocalStorageConstants.assetAuditSelfieKey}$siteAuditSchId';
    await LocalStorageService.setJson(key, {
      'imageId': newImageId,
      'imageData': newImageData,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
    print(
      'LocalStorageDB: Updated selfie for site $siteAuditSchId with new image ID $newImageId',
    );
  }

  static Future<void> clearAssetAuditSelfie(String siteAuditSchId) async {
    final key = '${LocalStorageConstants.assetAuditSelfieKey}$siteAuditSchId';
    await LocalStorageService.remove(key);
    print('LocalStorageDB: Cleared selfie for site $siteAuditSchId');
  }

  // Asset Audit Form Data Persistence Methods
  static Future<void> saveAssetAuditFormData({
    required String siteAuditSchId,
    required String screenName,
    required Map<String, dynamic> formData,
  }) async {
    try {
      final key =
          '${LocalStorageConstants.assetAuditFormDataKey}${siteAuditSchId}_$screenName';
      await LocalStorageService.setJson(key, {
        'formData': formData,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'screenName': screenName,
        'siteAuditSchId': siteAuditSchId,
      });
      print(
        'LocalStorageDB: Saved form data for screen $screenName, site $siteAuditSchId',
      );
    } catch (e) {
      print('LocalStorageDB: Error saving form data: $e');
    }
  }

  static Map<String, dynamic>? getAssetAuditFormData({
    required String siteAuditSchId,
    required String screenName,
  }) {
    try {
      final key =
          '${LocalStorageConstants.assetAuditFormDataKey}${siteAuditSchId}_$screenName';
      final data = LocalStorageService.getJson(key);
      if (data != null) {
        print(
          'LocalStorageDB: Retrieved form data for screen $screenName, site $siteAuditSchId',
        );
        return data;
      }
      return null;
    } catch (e) {
      print('LocalStorageDB: Error getting form data: $e');
      return null;
    }
  }

  static Future<void> updateAssetAuditFormData({
    required String siteAuditSchId,
    required String screenName,
    required Map<String, dynamic> newFormData,
  }) async {
    try {
      final key =
          '${LocalStorageConstants.assetAuditFormDataKey}${siteAuditSchId}_$screenName';
      await LocalStorageService.setJson(key, {
        'formData': newFormData,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'screenName': screenName,
        'siteAuditSchId': siteAuditSchId,
      });
      print(
        'LocalStorageDB: Updated form data for screen $screenName, site $siteAuditSchId',
      );
    } catch (e) {
      print('LocalStorageDB: Error updating form data: $e');
    }
  }

  static Future<void> clearAssetAuditFormData({
    required String siteAuditSchId,
    required String screenName,
  }) async {
    final key =
        '${LocalStorageConstants.assetAuditFormDataKey}${siteAuditSchId}_$screenName';
    await LocalStorageService.remove(key);
    print(
      'LocalStorageDB: Cleared form data for screen $screenName, site $siteAuditSchId',
    );
  }

  static Future<void> clearAllAssetAuditFormData(String siteAuditSchId) async {
    final keys = LocalStorageService.getKeys();
    final prefix =
        '${LocalStorageConstants.assetAuditFormDataKey}$siteAuditSchId';
    for (final key in keys) {
      if (key.startsWith(prefix)) {
        await LocalStorageService.remove(key);
      }
    }
    print('LocalStorageDB: Cleared all form data for site $siteAuditSchId');
  }

  // Offline Ticket Management Methods
  static Future<void> saveOfflineTicket({
    required String siteAuditSchId,
    required Map<String, dynamic> completeTicketData,
  }) async {
    try {
      final key = '${LocalStorageConstants.offlineTicketKey}$siteAuditSchId';
      await LocalStorageService.setJson(key, {
        'completeTicketData': completeTicketData,
        'downloadedAt': DateTime.now().millisecondsSinceEpoch,
        'siteAuditSchId': siteAuditSchId,
      });
      print('LocalStorageDB: Saved offline ticket for site $siteAuditSchId');
    } catch (e) {
      print('LocalStorageDB: Error saving offline ticket: $e');
    }
  }

  static Map<String, dynamic>? getOfflineTicket(String siteAuditSchId) {
    try {
      final key = '${LocalStorageConstants.offlineTicketKey}$siteAuditSchId';
      final data = LocalStorageService.getJson(key);
      if (data != null) {
        print(
          'LocalStorageDB: Retrieved offline ticket for site $siteAuditSchId',
        );
        return data;
      }
      return null;
    } catch (e) {
      print('LocalStorageDB: Error retrieving offline ticket: $e');
      return null;
    }
  }

  static Future<void> updateOfflineTicket({
    required String siteAuditSchId,
    required Map<String, dynamic> updatedTicketData,
  }) async {
    try {
      final key = '${LocalStorageConstants.offlineTicketKey}$siteAuditSchId';
      await LocalStorageService.setJson(key, {
        'completeTicketData': updatedTicketData,
        'downloadedAt': DateTime.now().millisecondsSinceEpoch,
        'siteAuditSchId': siteAuditSchId,
        'lastUpdated': DateTime.now().millisecondsSinceEpoch,
      });
      print('LocalStorageDB: Updated offline ticket for site $siteAuditSchId');
    } catch (e) {
      print('LocalStorageDB: Error updating offline ticket: $e');
    }
  }

  static Future<void> deleteOfflineTicket(String siteAuditSchId) async {
    try {
      final key = '${LocalStorageConstants.offlineTicketKey}$siteAuditSchId';
      await LocalStorageService.remove(key);
      print('LocalStorageDB: Deleted offline ticket for site $siteAuditSchId');
    } catch (e) {
      print('LocalStorageDB: Error deleting offline ticket: $e');
    }
  }

  static List<Map<String, dynamic>> getAllOfflineTickets() {
    try {
      final keys = LocalStorageService.getKeys();
      final List<Map<String, dynamic>> tickets = [];
      for (final key in keys) {
        if (key.startsWith(LocalStorageConstants.offlineTicketKey)) {
          final data = LocalStorageService.getJson(key);
          if (data != null) {
            tickets.add(data);
          }
        }
      }
      print('LocalStorageDB: Retrieved ${tickets.length} offline tickets');
      return tickets;
    } catch (e) {
      print('LocalStorageDB: Error retrieving all offline tickets: $e');
      return [];
    }
  }

  static bool isTicketDownloaded(String siteAuditSchId) {
    try {
      final key = '${LocalStorageConstants.offlineTicketKey}$siteAuditSchId';
      return LocalStorageService.containsKey(key);
    } catch (e) {
      print('LocalStorageDB: Error checking if ticket is downloaded: $e');
      return false;
    }
  }

  // Clear all data
  static Future<void> clearAllData() async {
    await LocalStorageService.clear();
  }

  // Logout functionality
  static Future<void> logout() async {
    print(
      "LocalStorageDB: Starting logout process - clearing all authentication data",
    );

    // Clear all authentication-related data
    await LocalStorageService.remove(LocalStorageConstants.userId);
    await LocalStorageService.remove(LocalStorageConstants.token);
    await LocalStorageService.remove(LocalStorageConstants.tokenExpiry);
    await LocalStorageService.remove(LocalStorageConstants.firstName);
    await LocalStorageService.remove(LocalStorageConstants.fullName);
    await LocalStorageService.remove(LocalStorageConstants.email);

    // Clear saved credentials if remember me is not enabled
    if (!getRememberMe) {
      await LocalStorageService.remove(LocalStorageConstants.username);
      await LocalStorageService.remove(LocalStorageConstants.password);
      await LocalStorageService.remove(LocalStorageConstants.rememberMe);
    }

    print("LocalStorageDB: Logout completed - all authentication data cleared");
  }

  // Clear all saved credentials including remember me data
  static Future<void> clearAllCredentials() async {
    print(
      "LocalStorageDB: Clearing all credentials including remember me data",
    );
    await LocalStorageService.remove(LocalStorageConstants.username);
    await LocalStorageService.remove(LocalStorageConstants.password);
    await LocalStorageService.remove(LocalStorageConstants.rememberMe);
    await LocalStorageService.remove(LocalStorageConstants.token);
    await LocalStorageService.remove(LocalStorageConstants.tokenExpiry);
    await LocalStorageService.remove(LocalStorageConstants.userId);
    await LocalStorageService.remove(LocalStorageConstants.firstName);
    await LocalStorageService.remove(LocalStorageConstants.email);


    
    print("LocalStorageDB: All credentials cleared successfully");
  }

  // Headers methods
  static Map<String, String> getHeadersWithToken() {
    return {"Authorization": 'Bearer ${LocalStorageDB.getToken}'};
  }

  static Map<String, String> getHeaders() {
    return {};
  }
}
