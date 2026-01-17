import 'package:flutter/material.dart';

import '../constants/constants_strings.dart';
import '../constants/app_colors.dart';

class CustomRemarksField extends StatelessWidget {
  final String? label;
  final String hintText;
  final TextEditingController controller;
  final int maxLines;
  final String? initialValue;
  final bool isDisabled;
  final bool isRequired;

  const CustomRemarksField({
    super.key,
    this.label,
    required this.hintText,
    required this.controller,
    this.initialValue,
    this.maxLines = 4,
    this.isDisabled = false,
    this.isRequired = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label
        if (label != null) ...[
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: label ?? '',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                    fontFamily: fontFamilyMontserrat,
                  ),
                ),
                if (isRequired)
                  const TextSpan(
                    text: " *",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.red,
                      fontFamily: fontFamilyMontserrat,
                    ),
                  ),
              ],
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
        ],
        const SizedBox(height: 5),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          readOnly: isDisabled,
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
