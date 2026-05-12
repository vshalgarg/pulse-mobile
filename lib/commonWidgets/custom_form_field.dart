import 'package:app/constants/app_colors.dart';
import 'package:app/constants/constants_strings.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum InputType {
  text,
  number,
  email,
  phone,
  multiline,
}

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
  final InputType? inputType;
  final int? maxLength;
  final Color? textColor;

  /// Border radius for the white input container (default `5`).
  final double? inputBorderRadius;

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
    this.inputType,
    this.maxLength,
    this.textColor,
    this.inputBorderRadius,
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

  TextInputType _getKeyboardType() {
    if (keyboardType != null) return keyboardType!;
    
    switch (inputType) {
      case InputType.number:
        return TextInputType.number;
      case InputType.email:
        return TextInputType.emailAddress;
      case InputType.phone:
        return TextInputType.phone;
      case InputType.multiline:
        return TextInputType.multiline;
      case InputType.text:
      case null:
      default:
        return TextInputType.text;
    }
  }

  List<TextInputFormatter> _getInputFormatters() {
    List<TextInputFormatter> formatters = [];
    
    // Add existing input formatters
    if (inputFormatters != null) {
      formatters.addAll(inputFormatters!);
    }
    
    // Add decimal formatter if needed
    if (_getDecimalInputFormatter() != null) {
      formatters.add(_getDecimalInputFormatter()!);
    }
    
    // Add input type specific formatters
    switch (inputType) {
      case InputType.number:
        formatters.add(FilteringTextInputFormatter.digitsOnly);
        break;
      case InputType.phone:
        formatters.add(FilteringTextInputFormatter.digitsOnly);
        break;
      case InputType.email:
        // No specific formatter for email, let the keyboard handle it
        break;
      case InputType.multiline:
      case InputType.text:
      case null:
      default:
        // No additional formatters
        break;
    }
    
    return formatters;
  }

  @override
  Widget build(BuildContext context) {
    final TextEditingController textController =
        controller ?? TextEditingController(text: initialValue ?? "");

    // Update controller text when initialValue changes
    if (controller == null && initialValue != null) {
      textController.text = initialValue!;
    }

    final List<TextInputFormatter> finalInputFormatters = _getInputFormatters();
    final radius = inputBorderRadius ?? 5;
    final fieldBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(radius),
      borderSide: BorderSide.none,
    );

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
          keyboardType: _getKeyboardType(),
          inputFormatters: finalInputFormatters,
          maxLength: maxLength,
          maxLines: inputType == InputType.multiline ? null : 1,
          decoration: InputDecoration(
            filled: true,
            fillColor: isEditable
                ? Colors.white
                : AppColors.borderColorE0E0E0, // Grey when not editable
            contentPadding: const EdgeInsets.symmetric(
              vertical: 8,
              horizontal: 16,
            ),
            border: fieldBorder,
            enabledBorder: fieldBorder,
            focusedBorder: fieldBorder,
            errorBorder: fieldBorder.copyWith(
              borderSide: const BorderSide(color: Colors.red, width: 1),
            ),
            focusedErrorBorder: fieldBorder.copyWith(
              borderSide: const BorderSide(color: Colors.red, width: 1),
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
            color: textColor ?? AppColors.color555555,
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