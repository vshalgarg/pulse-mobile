import 'package:google_sign_in/google_sign_in.dart';

class GoogleRepository {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    // Optional clientId
    // clientId: '479882132969-9i9aqik3jfjd7qhci1nqf0bm2g71rm1u.apps.googleusercontent.com',
    scopes: <String>[
      'email',
      // 'https://www.googleapis.com/auth/contacts.readonly',
      // 'https://www.googleapis.com/auth/admob.readonly',
      // 'https://www.googleapis.com/auth/admob.report'
    ],
  );

  Future<GoogleSignInAccount?> login() => _googleSignIn.signIn();

  Future<GoogleSignInAccount?> logout() => _googleSignIn.signOut();

  Future<bool> isAlreadyLoggedIn() => _googleSignIn.isSignedIn();
}
