import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../constants/constants_methods.dart';
import '../constants/constants_strings.dart';
import '../services/google_repository.dart';

class LogoutWidget extends StatelessWidget {
  const LogoutWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () async {
        GoogleSignInAccount? user = await GoogleRepository().logout();
        if (!context.mounted) return;
        if (user == null) {
          showCustomToast(context, "Logout");
          // pushNamedAndRemoveUntil(context, loginScreen);
        } else {
          showCustomToast(context, errorString);
        }
      },
      icon: const Icon(Icons.logout),
    );
  }
}
