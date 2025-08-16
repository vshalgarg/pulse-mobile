// import 'package:aligned_dialog/aligned_dialog.dart';
import 'package:flutter/material.dart';

import 'custom_dialogs/custom_dialog.dart';

class CustomShowCustomDialog {
  CustomShowCustomDialog._();

  static Future showCustomDialog({
    required BuildContext context,
    final bool showImage = true,
    final bool isDismissible = false,
    final String? title,
    final String? subTitle1,
    final String? subTitle2,
    final String? subTitle3,
    final String? greyTextStart,
    final String? greenText,
    final String? greyTextEnd,
    final String? buttonText1,
    final String? buttonText2,
    final VoidCallback? onNavigationText,
    final VoidCallback? onButtonPressed1,
    final VoidCallback? onButtonPressed2,
    final bool? isSuccess,
  }) {
    // return showAlignedDialog(
    //     context: context,
    //     builder: (context) {
    //       return AlertDialog(
    //         insetPadding: EdgeInsets.zero,
    //         title: Text("Alert!"),
    //         content: Text("Its an alert"),
    //       );
    //     },
    //     isGlobal: true,
    //     followerAnchor: Alignment.center,
    //     targetAnchor: Alignment.bottomLeft,
    //     barrierColor: Colors.transparent);
    return showDialog(
        context: context,
        barrierDismissible: isDismissible,
        builder: (context) {
          return CustomAlertDialog(
            showImage: showImage,
            title: title,
            subTitle1: subTitle1,
            subTitle2: subTitle2,
            subTitle3: subTitle3,
            greyTextStart: greyTextStart,
            greenText: greenText,
            greyTextEnd: greyTextEnd,
            buttonText1: buttonText1,
            buttonText2: buttonText2,
            onNavigateText: onNavigationText,
            onButtonPressed1: onButtonPressed1,
            onButtonPressed2: onButtonPressed2,
            isSuccess: isSuccess,
          );
        });
  }
}
