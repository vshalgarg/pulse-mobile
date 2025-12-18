import 'package:app/utils/uppercase_text_formatter.dart';
import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/constants_strings.dart';
import '../screens/qrScannerScreen.dart';

class SerialNumberField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final Function(String)? onQRScanned;

  const SerialNumberField({
    super.key,
    required this.label,
    required this.controller,
    this.onQRScanned,
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
          inputFormatters: [UpperCaseTextFormatter()],
          onChanged: (value) {

          },
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
                  
                  if (result != null && result is String && result.isNotEmpty) {
                    controller.text = result;

                    // Call the callback to notify parent that QR was scanned
                    onQRScanned?.call(result);
                  } else {

                  }
                } catch (e) {

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
