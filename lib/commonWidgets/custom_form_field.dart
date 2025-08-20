import 'package:app/constants/app_colors.dart';
import 'package:app/constants/constants_strings.dart';
import 'package:flutter/material.dart';

class CustomFormField extends StatelessWidget {
  final String label;
  final String? initialValue;
  final bool isRequired;
  final bool isEditable;
  final TextEditingController? controller;
  final Function(String)? onChanged;

  const CustomFormField({
    super.key,
    required this.label,
    this.initialValue,
    this.isRequired = false,
    this.isEditable = true,
    this.controller,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final TextEditingController textController =
        controller ?? TextEditingController(text: initialValue ?? "");

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label with optional *
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.white,
                fontFamily: fontFamilyMontserrat,
              ),
            ),
            if (isRequired)
              const Text(
                " *",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.errorColor,
                  fontFamily: fontFamilyMontserrat,
                ),
              ),
          ],
        ),
        const SizedBox(height: 5),

        // Input field
        TextFormField(
          controller: textController,
          readOnly: !isEditable,
          decoration: InputDecoration(
            filled: true,
            fillColor: isEditable ? Colors.white : AppColors.borderColorE0E0E0, // Grey when not editable
            contentPadding: const EdgeInsets.symmetric(
              vertical: 8,
              horizontal: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(5),
              borderSide: BorderSide.none,
            ),
          ),
          style: TextStyle(
            fontWeight: FontWeight.w400,
              fontFamily: fontFamilyMontserrat,
              fontSize: 16,
              color: AppColors.color555555
          ),
          validator: (value) {
            if (isRequired && (value == null || value.isEmpty)) {
              return "$label is required";
            }
            return null;
          },
          onFieldSubmitted: (value) {
            // Trigger validation
          },
          onChanged: onChanged,
        ),
      ],
    );
  }
}


// CustomFormField(
// label: "Circle",
// initialValue: "Haryana", // pre-filled
// isRequired: true,
// isEditable: false, // fixed value
// ),
