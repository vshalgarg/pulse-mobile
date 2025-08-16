import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';

class FacebookRepository {
  // Future<LoginResult?> login() async {
  //   // by default we request the email and the public profile
  //   final LoginResult result = await FacebookAuth.instance.login();
  //
  //   if (result.status == LoginStatus.success) {
  //     // you are logged
  //     final AccessToken accessToken = result.accessToken!;
  //
  //     return result;
  //   } else {
  //     print(result.status);
  //     print(result.message);
  //     return null;
  //   }
  // }

  // login permissions: ['public_profile', 'email', 'pages_show_list', 'pages_messaging', 'pages_manage_metadata'],
  Future<LoginResult> login() => FacebookAuth.instance.login();

  Future<AccessToken?> loggedIn() => FacebookAuth.instance.accessToken;

  Future<void> logout() => FacebookAuth.instance.logOut();
}
