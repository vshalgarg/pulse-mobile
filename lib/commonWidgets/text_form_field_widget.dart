import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:app/constants/app_colors.dart';
import 'package:app/constants/app_sizes.dart';
import 'package:app/constants/constants_strings.dart';

class TextFormFieldWidget extends StatefulWidget {
  final String? initialValue;
  final TextEditingController? controller;
  final String? labelText;
  final String? hintText;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final Function(String?)? onSaved;
  final Function(String)? onChanged;
  final void Function()? onTap;
  final bool obscureText;
  final int? maxLength;
  final bool readOnly;
  final Widget? suffixIcon;
  final int? maxLines;
  final int? minLines;
  final double? contentPadding;
  final TextStyle? hintTextStyle;
  final bool? alignLabelWithHint;
  final Color borderColor;
  final bool fieldEnabled;
  final List<TextInputFormatter>? inputFormatters;
  final bool showBorder;

  const TextFormFieldWidget({
    this.initialValue,
    this.controller,
    this.labelText,
    this.hintText,
    this.validator,
    this.keyboardType,
    this.onSaved,
    this.onChanged,
    this.onTap,
    this.obscureText = false,
    this.maxLength,
    this.readOnly = false,
    this.suffixIcon,
    this.maxLines = 1,
    this.contentPadding,
    this.hintTextStyle,
    this.minLines = 1,
    this.alignLabelWithHint = false,
    this.borderColor = AppColors.blue,
    this.fieldEnabled = true,
    this.inputFormatters,
    this.showBorder = true,
    Key? key,
  }) : super(key: key);

  @override
  _TextFormFieldWidgetState createState() => _TextFormFieldWidgetState();
}

class _TextFormFieldWidgetState extends State<TextFormFieldWidget> {
  bool _isFocused = false;
  
  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (hasFocus) {
        setState(() {
          _isFocused = hasFocus;
        });
      },
      child: TextFormField(
        inputFormatters: widget.inputFormatters,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        enabled: widget.fieldEnabled,
        textAlignVertical: TextAlignVertical.center,
        minLines: widget.minLines,
        initialValue: widget.initialValue,
        controller: widget.controller,
        decoration: InputDecoration(
          counter: const Offstage(),
          labelText: widget.labelText,
          hintText: widget.hintText,
          fillColor: Colors.white,
          filled: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 15,
            vertical: 12,
          ),
          alignLabelWithHint: widget.alignLabelWithHint,
          hintStyle: const TextStyle(
            color: Color(0xFFB8B8B8),
            fontWeight: FontWeight.w400,
            fontSize: 18, // Increased from 16 to 18
            fontFamily: fontFamilyInter,
          ),
          labelStyle: TextStyle(
            color: _isFocused ? AppColors.primaryBlue : const Color(0xFF72777A),
            fontWeight: FontWeight.w400,
            fontSize: 16, // Increased from 14 to 16
            fontFamily: fontFamilyInter,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: widget.showBorder 
                ? const BorderSide(color: Color(0xFFE0E0E0))
                : BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: widget.showBorder 
                ? const BorderSide(color: Color(0xFFE0E0E0))
                : BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(
              color: AppColors.textBlueAccent, // Blue border when focused
              width: 1.5,
            ),
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.errorColor),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(
              color: AppColors.errorColor,
              width: 1.5,
            ),
          ),
          errorStyle: const TextStyle(
            color: AppColors.errorColor,
            fontSize: 14,
            fontWeight: FontWeight.w400,
            fontFamily: fontFamilyInter,
          ),
          suffixIcon: widget.suffixIcon,
        ),
        style: const TextStyle(
          fontSize: 18, // Increased from 16 to 18
          fontWeight: FontWeight.w400,
          color: Color(0xFF72777A),
          fontFamily: fontFamilyInter,
        ),
        validator: widget.validator,
        keyboardType: widget.keyboardType,
        onSaved: widget.onSaved,
        onChanged: widget.onChanged,
        onTap: widget.onTap,
        obscureText: widget.obscureText,
        maxLength: widget.maxLength,
        readOnly: widget.readOnly,
        maxLines: widget.maxLines,
      ),
    );
  }
}
