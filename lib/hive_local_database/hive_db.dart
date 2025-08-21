import 'package:hive/hive.dart';

import 'hive_constant.dart';

class HiveDB {
  HiveDB._();

  static openAllHiveDbBoxes() async {
    await HiveDB.openHiveDB(HiveConstant.hasRegulaDB);
    await HiveDB.openHiveDB(HiveConstant.userCreds);
    await HiveDB.openHiveDB(HiveConstant.getConfiguration);
    await HiveDB.openHiveDB(HiveConstant.getContent);
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

  // save cart count
  static Future<void> setCartCount(num? cartCount) async =>
      await HiveDB.getHiveBox(HiveConstant.userCreds).put(HiveConstant.cartCount, cartCount ?? 0);

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
//
}
