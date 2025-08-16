import 'package:flutter/material.dart';

import 'custom_dialog.dart';

Future<bool?> showAlertDialog(BuildContext context,
    {VoidCallback? onButtonPressed1, VoidCallback? onButtonPressed2}) async {
  bool? alertBool = await showDialog<bool>(
      context: context,
      builder: (context) {
        return CustomAlertDialog(
            title: 'Are you sure?',
            subTitle1: 'Are you sure wants to go back?',
            buttonText1: 'No',
            buttonText2: 'Yes',
            onButtonPressed1: () {
              onButtonPressed1;
              Navigator.pop(context, false);
            },
            onButtonPressed2: () {
              onButtonPressed2;
              Navigator.pop(context, true);
            });
      });

  return alertBool;
}

showAlertDialog2(BuildContext context, {VoidCallback? onButtonPressed1, VoidCallback? onButtonPressed2}) {
  return showDialog(
      context: context,
      builder: (context) {
        return CustomAlertDialog(
            title: 'Are you sure?',
            subTitle1: 'Are you sure wants to go back?',
            buttonText1: 'No',
            buttonText2: 'Yes',
            onButtonPressed1: () {
              Navigator.pop(context);
              onButtonPressed1;
            },
            onButtonPressed2: () {
              Navigator.pop(context);
              onButtonPressed2 ?? Navigator.pop(context);
            });
      });
}

Future<bool?> showAlertDialog3(BuildContext context,
    {VoidCallback? onButtonPressed1, VoidCallback? onButtonPressed2}) async {
  bool? alertBool = await showDialog<bool>(
      context: context,
      builder: (context) {
        return CustomAlertDialog(
          title: 'Are you sure?',
          subTitle1: 'Are you sure wants to go back?',
          buttonText1: 'No',
          buttonText2: 'Yes',
          onButtonPressed1: () => Navigator.pop(context, false),
          onButtonPressed2: onButtonPressed2,
        );
      });

  return alertBool;
}

Future<bool?> showAlertDialog4(BuildContext context,
    {VoidCallback? onButtonPressed1, VoidCallback? onButtonPressed2}) async {
  bool? alertBool = await showDialog<bool>(
      context: context,
      builder: (context) {
        return CustomAlertDialog(
          title: 'Are you sure?',
          subTitle1: 'Are you sure wants to go back?',
          buttonText1: 'No',
          buttonText2: 'Yes',
          onButtonPressed1: () => Navigator.pop(context, false),
          onButtonPressed2: onButtonPressed2,
        );
      });

  return alertBool;
}
