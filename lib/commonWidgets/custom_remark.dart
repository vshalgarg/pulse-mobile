import 'package:flutter/material.dart';

import '../constants/constants_strings.dart';
import '../constants/app_colors.dart';

class CustomRemarksField extends StatelessWidget {
  final String label;
  final String hintText;
  final TextEditingController controller;
  final int maxLines;
  final String? initialValue;

  const CustomRemarksField({
    super.key,
    required this.label,
    required this.hintText,
    required this.controller,
    this.initialValue,
    this.maxLines = 4,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: AppColors.white,
            fontFamily: fontFamilyMontserrat,
          ),
        ),
        const SizedBox(height: 5),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: const TextStyle(color: AppColors.color555555),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(5),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }
}
