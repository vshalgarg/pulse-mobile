import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/constants_strings.dart';

class CustomFormFieldV2 extends StatelessWidget {
  final String? label;
  final String? hintText;
  final TextEditingController? controller;
  final Function(String)? onChanged;
  final int? maxLines;
  final bool isRequired;
  final TextInputType? keyboardType;

  const CustomFormFieldV2({
    super.key,
    this.label,
    this.hintText,
    this.controller,
    this.onChanged,
    this.maxLines,
    this.isRequired = false,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label with required asterisk
        if (label != null) ...[
          Row(
            children: [
              Text(
                label!,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: AppColors.color555555,
                  fontFamily: fontFamilyMontserrat,
                ),
              ),
              if (isRequired)
                const Text(
                  " *",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.red,
                    fontFamily: fontFamilyMontserrat,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
        ],
        
        // Input field
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType ?? TextInputType.text,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              vertical: 12,
              horizontal: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            hintText: hintText,
            hintStyle: TextStyle(
              fontWeight: FontWeight.w400,
              fontFamily: fontFamilyMontserrat,
              fontSize: 16,
              color: AppColors.color555555.withOpacity(0.6),
            ),
          ),
          style: TextStyle(
            fontWeight: FontWeight.w400,
            fontFamily: fontFamilyMontserrat,
            fontSize: 16,
            color: AppColors.color555555,
          ),
          onChanged: onChanged,
        ),
      ],
    );
  }
}
