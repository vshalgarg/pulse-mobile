import 'package:flutter/material.dart';
import '../../../constants/app_colors.dart';

class SerialNumberMismatchDialog extends StatelessWidget {
  const SerialNumberMismatchDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: AppColors.errorColor,
            size: 24,
          ),
          const SizedBox(width: 8),
          const Text('Serial Number Mismatch'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'The entered serial number does not match the expected values.',
            style: TextStyle(fontSize: 16, color: AppColors.black),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: Text(
            'OK',
            style: TextStyle(
              color: AppColors.primaryGreen,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  /// Static method to show the dialog
  static void show(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => SerialNumberMismatchDialog(),
    );
  }
}
