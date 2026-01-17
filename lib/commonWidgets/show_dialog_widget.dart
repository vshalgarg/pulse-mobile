import 'package:app/constants/constants_methods.dart';
import 'package:flutter/material.dart';

class ShowDialogWidget {
  ShowDialogWidget._();

  static start(BuildContext context) async {
    return await showDialog(
      barrierDismissible: false,
      context: context,
      // barrierColor: Colors.transparent,
      builder: (context) {
        return kCircularProgressIndicator;
      },
    );
  }

  static void stop(BuildContext context) async {
    return Navigator.pop(context);
  }
}
