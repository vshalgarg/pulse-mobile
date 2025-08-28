import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/constants_strings.dart';
import '../screens/qrScannerScreen.dart';

class SerialNumberField extends StatelessWidget {
  final String label;
  final TextEditingController controller;

  const SerialNumberField({
    super.key,
    required this.label,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            text: label,
            style: const TextStyle(
              fontWeight: FontWeight.w400,
              fontFamily: fontFamilyMontserrat,
              fontSize: 16,
              color: AppColors.white,
            ),
            children: const [
              TextSpan(
                text: " *",
                style: TextStyle(
                  color: AppColors.errorColor,
                  fontSize: 14,
                  fontFamily: fontFamilyMontserrat,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 5),
        TextFormField(
          controller: controller,
          decoration: InputDecoration(
            hintText: "Serial Number",
            hintStyle: TextStyle(
              fontWeight: FontWeight.w400,
              fontFamily: fontFamilyMontserrat,
              fontSize: 16,
              color: AppColors.color555555,

            ),
            suffixIcon: IconButton(
              icon: const Icon(Icons.qr_code_scanner),
              onPressed: () async {
                try {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const QRScannerScreen()),
                  );
                  
                  // Debug print to see what's returned
                  print('QR Scanner result: $result (type: ${result.runtimeType})');
                  
                  if (result != null && result is String && result.isNotEmpty) {
                    controller.text = result;
                    print('Serial number set to: $result');
                  } else {
                    print('Invalid or empty result from QR scanner');
                  }
                } catch (e) {
                  print('Error in QR scanner: $e');
                  // Show error to user
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error scanning QR code: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(5),
              borderSide: BorderSide.none,
            ),
            filled: true,
            fillColor: Colors.white,
          ),
        ),
      ],
    );
  }
}
