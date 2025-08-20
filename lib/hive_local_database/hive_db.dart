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
    var userCredential = HiveDB.getHiveBox(HiveConstant.userCreds);
    // await userCredential.put("isBiometricValue", false);
    await userCredential.delete(HiveConstant.userId);
    await userCredential.delete(HiveConstant.token);
    
    // Clear saved credentials if remember me is not enabled
    if (!getRememberMe) {
      await userCredential.delete(HiveConstant.username);
      await userCredential.delete(HiveConstant.password);
      await userCredential.delete(HiveConstant.rememberMe);
    }
  }

  // Clear all saved credentials including remember me data
  static Future<void> clearAllCredentials() async {
    var userCredential = HiveDB.getHiveBox(HiveConstant.userCreds);
    await userCredential.delete(HiveConstant.username);
    await userCredential.delete(HiveConstant.password);
    await userCredential.delete(HiveConstant.rememberMe);
    await userCredential.delete(HiveConstant.token);
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
