import 'package:hive/hive.dart';

import 'hive_constant.dart';

class HiveDB {
  HiveDB._();

  static openAllHiveDbBoxes() async {
    await HiveDB.openHiveDB(HiveConstant.hasRegulaDB);
    await HiveDB.openHiveDB(HiveConstant.userCreds);
    await HiveDB.openHiveDB(HiveConstant.getConfiguration);
    await HiveDB.openHiveDB(HiveConstant.getContent);
    await HiveDB.openHiveDB(HiveConstant.assetAuditImages);
    await HiveDB.openHiveDB(HiveConstant.assetAuditFormData);
    await HiveDB.openHiveDB(HiveConstant.offlineTickets);
  }

  static registerHiveAdapter() {
    // add the hive adapter here
    // Hive.registerAdapter(getConfiguration.GetConfigurationModelAdapter());
    // Hive.registerAdapter(getContent.GetContentModelAdapter());
    // Hive.registerAdapter(getConfiguration.DataAdapter());
    // Hive.registerAdapter(getContent.DataAdapter());
  }

  static closeHiveDB() async {
    var hiveBox = await Hive.close();
  }

  static Future<Box> openHiveDB(String boxName) async {
    // method to create hive db
    Box hiveBox = await Hive.openBox(boxName);
    return hiveBox;
  }

  static Box getHiveBox(String boxName) {
    // method to open hive db
    Box hiveBox = Hive.box(boxName);
    return hiveBox;
  }

  //TODO: save password
  savePasswordInDb() {}

  getPasswordFromDb() {}

  //TODO: save email
  //TODO: get session
  getSessionFromDb() {}

  saveSessionInDb() {}

  // static getContentModel.Data? getContentDataFromLocalDb() {
  //   Box contentBox = Hive.box(HiveConstant.getContent);
  //   if (contentBox.isNotEmpty) {
  //     return contentBox.get("getContentData").data;
  //     // return contentBox.getAt(0)?.data;
  //   }
  //   return null;
  // }

  static Future<void> clearAllData() async {
    var userCredential = HiveDB.getHiveBox(HiveConstant.userCreds);
    // await userCredential.delete("sessionKey");
    // await userCredential.delete(HiveConstant.userId);
    await userCredential.clear();
    // await createSession();
  }

  static Future<void> logout() async {
    print("HiveDB: Starting logout process - clearing all authentication data");
    var userCredential = HiveDB.getHiveBox(HiveConstant.userCreds);
    
    // Clear all authentication-related data
    await userCredential.delete(HiveConstant.userId);
    await userCredential.delete(HiveConstant.token);
    await userCredential.delete(HiveConstant.tokenExpiry);
    await userCredential.delete(HiveConstant.firstName);
    await userCredential.delete(HiveConstant.email);
    
    // Clear saved credentials if remember me is not enabled
    if (!getRememberMe) {
      await userCredential.delete(HiveConstant.username);
      await userCredential.delete(HiveConstant.password);
      await userCredential.delete(HiveConstant.rememberMe);
    }
    
    print("HiveDB: Logout completed - all authentication data cleared");
  }

  // Clear all saved credentials including remember me data
  static Future<void> clearAllCredentials() async {
    print("HiveDB: Clearing all credentials including remember me data");
    var userCredential = HiveDB.getHiveBox(HiveConstant.userCreds);
    await userCredential.delete(HiveConstant.username);
    await userCredential.delete(HiveConstant.password);
    await userCredential.delete(HiveConstant.rememberMe);
    await userCredential.delete(HiveConstant.token);
    await userCredential.delete(HiveConstant.tokenExpiry);
    await userCredential.delete(HiveConstant.userId);
    await userCredential.delete(HiveConstant.firstName);
    await userCredential.delete(HiveConstant.email);
    print("HiveDB: All credentials cleared successfully");
  }

  static var userCredential = HiveDB.getHiveBox(HiveConstant.userCreds);

  // get userid
  static String? get getUserId => userCredential.get(HiveConstant.userId);

  //get firebaseToken
  static String? get getFireBaseToken => userCredential.get(HiveConstant.firebaseToken);

  // get email
  static String? get getEmail => userCredential.get(HiveConstant.email);

  // get token
  static String? get getToken => userCredential.get(HiveConstant.token);

  // save token
  static Future<void> saveToken(String token) async {
    await userCredential.put(HiveConstant.token, token);
  }

  // get token expiry
  static DateTime? get getTokenExpiry {
    final expiryString = userCredential.get(HiveConstant.tokenExpiry);
    if (expiryString != null) {
      try {
        return DateTime.parse(expiryString);
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  // save token expiry
  static Future<void> saveTokenExpiry(DateTime expiry) async {
    await userCredential.put(HiveConstant.tokenExpiry, expiry.toIso8601String());
  }

  // save username
  static Future<void> saveUsername(String username) async {
    await userCredential.put(HiveConstant.username, username);
  }

  // save password
  static Future<void> savePassword(String password) async {
    await userCredential.put(HiveConstant.password, password);
  }

  // set remember me status
  static Future<void> setRememberMe(bool rememberMe) async {
    await userCredential.put(HiveConstant.rememberMe, rememberMe);
  }

  // get username
  static String? get getUsername => userCredential.get(HiveConstant.username);

  // get password
  static String? get getPassword => userCredential.get(HiveConstant.password);

  // get remember me status
  static bool get getRememberMe => userCredential.get(HiveConstant.rememberMe) ?? false;

  // get cart count
  static String? get getCartCount => userCredential.get(HiveConstant.cartCount);

  static Future<void> setCartCount(int? cartCount) async {
    await HiveDB.getHiveBox(HiveConstant.userCreds).put(HiveConstant.cartCount, cartCount ?? 0);
  }

  // Energy Reading Form Data Methods
  static Future<void> saveEnergyReadingFormData(Map<String, dynamic> formData) async {
    await userCredential.put(HiveConstant.energyReadingFormData, formData);
  }

  static Map<String, dynamic>? get getEnergyReadingFormData {
    try {
      final data = userCredential.get(HiveConstant.energyReadingFormData);
      if (data != null) {
        return Map<String, dynamic>.from(data);
      }
      return null;
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
    await userCredential.put(HiveConstant.energyReadingAuditSchId, auditSchId);
    await userCredential.put(HiveConstant.energyReadingSiteAuditSchId, siteAuditSchId);
    await userCredential.put(HiveConstant.energyReadingSiteId, siteId);
  }

  static String? get getEnergyReadingAuditSchId => 
      userCredential.get(HiveConstant.energyReadingAuditSchId);
  
  static String? get getEnergyReadingSiteAuditSchId => 
      userCredential.get(HiveConstant.energyReadingSiteAuditSchId);
  
  static String? get getEnergyReadingSiteId => 
      userCredential.get(HiveConstant.energyReadingSiteId);

  static Future<void> clearEnergyReadingData() async {
    await userCredential.delete(HiveConstant.energyReadingFormData);
    await userCredential.delete(HiveConstant.energyReadingAuditSchId);
    await userCredential.delete(HiveConstant.energyReadingSiteAuditSchId);
    await userCredential.delete(HiveConstant.energyReadingSiteId);
  }

  // Clear corrupted energy reading form data
  static Future<void> clearCorruptedEnergyReadingData() async {
    await userCredential.delete(HiveConstant.energyReadingFormData);
  }

  // get profile image
  static String? get getProfileImage => userCredential.get(HiveConstant.profileImage, defaultValue: null);

  // get first name
  static String? get getFirstName => userCredential.get(HiveConstant.firstName, defaultValue: null);

  // get session key
  static String? get appSessionKey => userCredential.get('sessionKey');

  //
  static Map<String, String> getHeadersWithToken() {
    return {
      "Authorization": 'Bearer ${HiveDB.getToken}',
    };
  }

  static Map<String, String> getHeaders() {
    return {};
  }

  // Asset Audit Image Management Methods
  static Future<void> saveAssetAuditSelfie({
    required String siteAuditSchId,
    required String imageId,
    required String imageData,
  }) async {
    final box = HiveDB.getHiveBox(HiveConstant.assetAuditImages);
    final key = '${HiveConstant.assetAuditSelfieKey}$siteAuditSchId';
    await box.put(key, {
      'imageId': imageId,
      'imageData': imageData,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
    print('HiveDB: Saved selfie for site $siteAuditSchId with image ID $imageId');
  }

  static Map<String, dynamic>? getAssetAuditSelfie(String siteAuditSchId) {
    final box = HiveDB.getHiveBox(HiveConstant.assetAuditImages);
    final key = '${HiveConstant.assetAuditSelfieKey}$siteAuditSchId';
    final data = box.get(key);
    if (data != null) {
      print('HiveDB: Retrieved selfie for site $siteAuditSchId: $data');
      // Cast the Hive data to the expected type
      return Map<String, dynamic>.from(data);
    }
    return null;
  }

  static Future<void> updateAssetAuditSelfie({
    required String siteAuditSchId,
    required String newImageId,
    required String newImageData,
  }) async {
    final box = HiveDB.getHiveBox(HiveConstant.assetAuditImages);
    final key = '${HiveConstant.assetAuditSelfieKey}$siteAuditSchId';
    await box.put(key, {
      'imageId': newImageId,
      'imageData': newImageData,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
    print('HiveDB: Updated selfie for site $siteAuditSchId with new image ID $newImageId');
  }

  static Future<void> clearAssetAuditSelfie(String siteAuditSchId) async {
    final box = HiveDB.getHiveBox(HiveConstant.assetAuditImages);
    final key = '${HiveConstant.assetAuditSelfieKey}$siteAuditSchId';
    await box.delete(key);
    print('HiveDB: Cleared selfie for site $siteAuditSchId');
  }

  // Asset Audit Form Data Persistence Methods
  static Future<void> saveAssetAuditFormData({
    required String siteAuditSchId,
    required String screenName,
    required Map<String, dynamic> formData,
  }) async {
    try {
      // Ensure the box is opened
      await HiveDB.openHiveDB(HiveConstant.assetAuditFormData);
      final box = HiveDB.getHiveBox(HiveConstant.assetAuditFormData);
      final key = '${HiveConstant.assetAuditFormDataKey}${siteAuditSchId}_$screenName';
      await box.put(key, {
        'formData': formData,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'screenName': screenName,
        'siteAuditSchId': siteAuditSchId,
      });
      print('HiveDB: Saved form data for screen $screenName, site $siteAuditSchId');
    } catch (e) {
      print('HiveDB: Error saving form data: $e');
      // Try to open the box again and retry
      try {
        await HiveDB.openHiveDB(HiveConstant.assetAuditFormData);
        final box = HiveDB.getHiveBox(HiveConstant.assetAuditFormData);
        final key = '${HiveConstant.assetAuditFormDataKey}${siteAuditSchId}_$screenName';
        await box.put(key, {
          'formData': formData,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'screenName': screenName,
          'siteAuditSchId': siteAuditSchId,
        });
        print('HiveDB: Retry successful - Saved form data for screen $screenName, site $siteAuditSchId');
      } catch (retryError) {
        print('HiveDB: Retry failed - Error saving form data: $retryError');
      }
    }
  }

  static Map<String, dynamic>? getAssetAuditFormData({
    required String siteAuditSchId,
    required String screenName,
  }) {
    try {
      final box = HiveDB.getHiveBox(HiveConstant.assetAuditFormData);
      final key = '${HiveConstant.assetAuditFormDataKey}${siteAuditSchId}_$screenName';
      final data = box.get(key);
      if (data != null) {
        print('HiveDB: Retrieved form data for screen $screenName, site $siteAuditSchId');
        return Map<String, dynamic>.from(data);
      }
      return null;
    } catch (e) {
      print('HiveDB: Error getting form data: $e');
      return null;
    }
  }

  static Future<void> updateAssetAuditFormData({
    required String siteAuditSchId,
    required String screenName,
    required Map<String, dynamic> newFormData,
  }) async {
    try {
      // Ensure the box is opened
      await HiveDB.openHiveDB(HiveConstant.assetAuditFormData);
      final box = HiveDB.getHiveBox(HiveConstant.assetAuditFormData);
      final key = '${HiveConstant.assetAuditFormDataKey}${siteAuditSchId}_$screenName';
      await box.put(key, {
        'formData': newFormData,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'screenName': screenName,
        'siteAuditSchId': siteAuditSchId,
      });
      print('HiveDB: Updated form data for screen $screenName, site $siteAuditSchId');
    } catch (e) {
      print('HiveDB: Error updating form data: $e');
      // Try to open the box again and retry
      try {
        await HiveDB.openHiveDB(HiveConstant.assetAuditFormData);
        final box = HiveDB.getHiveBox(HiveConstant.assetAuditFormData);
        final key = '${HiveConstant.assetAuditFormDataKey}${siteAuditSchId}_$screenName';
        await box.put(key, {
          'formData': newFormData,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'screenName': screenName,
          'siteAuditSchId': siteAuditSchId,
        });
        print('HiveDB: Retry successful - Updated form data for screen $screenName, site $siteAuditSchId');
      } catch (retryError) {
        print('HiveDB: Retry failed - Error updating form data: $retryError');
      }
    }
  }

  static Future<void> clearAssetAuditFormData({
    required String siteAuditSchId,
    required String screenName,
  }) async {
    final box = HiveDB.getHiveBox(HiveConstant.assetAuditFormData);
    final key = '${HiveConstant.assetAuditFormDataKey}${siteAuditSchId}_$screenName';
    await box.delete(key);
    print('HiveDB: Cleared form data for screen $screenName, site $siteAuditSchId');
  }

  static Future<void> clearAllAssetAuditFormData(String siteAuditSchId) async {
    final box = HiveDB.getHiveBox(HiveConstant.assetAuditFormData);
    final keys = box.keys.where((key) => key.toString().startsWith('${HiveConstant.assetAuditFormDataKey}$siteAuditSchId'));
    for (final key in keys) {
      await box.delete(key);
    }
    print('HiveDB: Cleared all form data for site $siteAuditSchId');
  }

  // Offline Ticket Management Methods
  static Future<void> saveOfflineTicket({
    required String siteAuditSchId,
    required Map<String, dynamic> completeTicketData,
  }) async {
    try {
      await HiveDB.openHiveDB(HiveConstant.offlineTickets);
      final box = HiveDB.getHiveBox(HiveConstant.offlineTickets);
      final key = '${HiveConstant.offlineTicketKey}$siteAuditSchId';
      await box.put(key, {
        'completeTicketData': completeTicketData,
        'downloadedAt': DateTime.now().millisecondsSinceEpoch,
        'siteAuditSchId': siteAuditSchId,
      });
      print('HiveDB: Saved offline ticket for site $siteAuditSchId');
    } catch (e) {
      print('HiveDB: Error saving offline ticket: $e');
    }
  }

  static Map<String, dynamic>? getOfflineTicket(String siteAuditSchId) {
    try {
      final box = HiveDB.getHiveBox(HiveConstant.offlineTickets);
      final key = '${HiveConstant.offlineTicketKey}$siteAuditSchId';
      final data = box.get(key);
      if (data != null) {
        print('HiveDB: Retrieved offline ticket for site $siteAuditSchId');
        return Map<String, dynamic>.from(data);
      }
      return null;
    } catch (e) {
      print('HiveDB: Error retrieving offline ticket: $e');
      return null;
    }
  }

  static Future<void> updateOfflineTicket({
    required String siteAuditSchId,
    required Map<String, dynamic> updatedTicketData,
  }) async {
    try {
      await HiveDB.openHiveDB(HiveConstant.offlineTickets);
      final box = HiveDB.getHiveBox(HiveConstant.offlineTickets);
      final key = '${HiveConstant.offlineTicketKey}$siteAuditSchId';
      await box.put(key, {
        'completeTicketData': updatedTicketData,
        'downloadedAt': DateTime.now().millisecondsSinceEpoch,
        'siteAuditSchId': siteAuditSchId,
        'lastUpdated': DateTime.now().millisecondsSinceEpoch,
      });
      print('HiveDB: Updated offline ticket for site $siteAuditSchId');
    } catch (e) {
      print('HiveDB: Error updating offline ticket: $e');
    }
  }

  static Future<void> deleteOfflineTicket(String siteAuditSchId) async {
    try {
      final box = HiveDB.getHiveBox(HiveConstant.offlineTickets);
      final key = '${HiveConstant.offlineTicketKey}$siteAuditSchId';
      await box.delete(key);
      print('HiveDB: Deleted offline ticket for site $siteAuditSchId');
    } catch (e) {
      print('HiveDB: Error deleting offline ticket: $e');
    }
  }

  static List<Map<String, dynamic>> getAllOfflineTickets() {
    try {
      final box = HiveDB.getHiveBox(HiveConstant.offlineTickets);
      final List<Map<String, dynamic>> tickets = [];
      for (final key in box.keys) {
        if (key.toString().startsWith(HiveConstant.offlineTicketKey)) {
          final data = box.get(key);
          if (data != null) {
            tickets.add(Map<String, dynamic>.from(data));
          }
        }
      }
      print('HiveDB: Retrieved ${tickets.length} offline tickets');
      return tickets;
    } catch (e) {
      print('HiveDB: Error retrieving all offline tickets: $e');
      return [];
    }
  }

  static bool isTicketDownloaded(String siteAuditSchId) {
    try {
      final box = HiveDB.getHiveBox(HiveConstant.offlineTickets);
      final key = '${HiveConstant.offlineTicketKey}$siteAuditSchId';
      return box.containsKey(key);
    } catch (e) {
      print('HiveDB: Error checking if ticket is downloaded: $e');
      return false;
    }
  }
//
}
