import 'package:app/constants/app_colors.dart';
import 'package:app/constants/constants_strings.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CustomFormField extends StatelessWidget {
  final String? label;
  final String? initialValue;
  final String? hintText;
  final bool isRequired;
  final bool isEditable;
  final TextEditingController? controller;
  final Function(String)? onChanged;
  final String? Function(String?)? validator;
  final List<TextInputFormatter>? inputFormatters;
  final TextInputType? keyboardType;
  final int? maxDecimalDigits;

  const CustomFormField({
    super.key,
    this.label,
    this.initialValue,
    this.hintText,
    this.isRequired = false,
    this.isEditable = true,
    this.controller,
    this.onChanged,
    this.validator,
    this.inputFormatters,
    this.keyboardType,
    this.maxDecimalDigits,
  });

  TextInputFormatter? _getDecimalInputFormatter() {
    if (keyboardType == TextInputType.numberWithOptions(decimal: true) &&
        maxDecimalDigits != null) {
      return FilteringTextInputFormatter.allow(
        RegExp(r'^\d*\.?\d{0,' + maxDecimalDigits.toString() + r'}$'),
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final TextEditingController textController =
        controller ?? TextEditingController(text: initialValue ?? "");

    // Update controller text when initialValue changes
    if (controller == null && initialValue != null) {
      textController.text = initialValue!;
    }

    final List<TextInputFormatter> finalInputFormatters = [
      if (inputFormatters != null) ...inputFormatters!,
      if (_getDecimalInputFormatter() != null) _getDecimalInputFormatter()!,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label with optional *
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

        // Input field
        TextFormField(
          controller: textController,
          readOnly: !isEditable,
          keyboardType: keyboardType ?? TextInputType.text,
          inputFormatters: inputFormatters,
          decoration: InputDecoration(
            filled: true,
            fillColor: isEditable
                ? Colors.white
                : AppColors.borderColorE0E0E0, // Grey when not editable
            contentPadding: const EdgeInsets.symmetric(
              vertical: 8,
              horizontal: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(5),
              borderSide: BorderSide.none,
            ),
            hintText: hintText, // Show hint text if provided
            hintStyle: TextStyle(
              fontWeight: FontWeight.w400,
              fontFamily: fontFamilyMontserrat,
              fontSize: 16,
              color: AppColors.color555555.withOpacity(
                0.6,
              ), // Slightly transparent for hint
            ),
          ),
          style: TextStyle(
            fontWeight: FontWeight.w400,
            fontFamily: fontFamilyMontserrat,
            fontSize: 16,
            color: AppColors.color555555,
          ),
          validator:
              validator ??
              (value) {
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