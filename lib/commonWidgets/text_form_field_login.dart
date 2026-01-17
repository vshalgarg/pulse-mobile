import 'package:flutter/material.dart';
import 'package:app/constants/app_colors.dart';
import 'package:app/constants/app_sizes.dart';
import 'package:google_fonts/google_fonts.dart';

class TextFormFieldLoginWidget extends StatelessWidget {
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
  final bool? focusEnabled;

  const TextFormFieldLoginWidget({
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
    this.focusEnabled = false,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      autovalidateMode: AutovalidateMode.onUserInteraction,
      initialValue: initialValue,
      controller: controller,
      decoration: InputDecoration(
        counterText: "",
        filled: true,
        fillColor: AppColors.lightBg,
        labelText: labelText,
        hintText: hintText,
        labelStyle: TextStyle(
          color: AppColors.textFieldsTextColor,
          fontWeight: FontWeight.w600,
          fontSize: AppSizes.fourteen,
          fontFamily: GoogleFonts.lato().fontFamily,
        ),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSizes.eight),
            borderSide: const BorderSide(
              color: AppColors.textFormLightGreyColor,
              width: AppSizes.one,
            )),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.eight),
          borderSide: const BorderSide(
            color: AppColors.textFormLightGreyColor,
            width: AppSizes.one,
          ),
        ),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSizes.eight),
            borderSide: const BorderSide(
              color: AppColors.textFormLightGreyColor,
              width: AppSizes.one,
            )),
        suffixIcon: suffixIcon,
      ),
      style: Theme.of(context).textTheme.displayLarge,
      validator: validator,
      keyboardType: keyboardType,
      onSaved: onSaved,
      onChanged: onChanged,
      onTap: onTap,
      obscureText: obscureText,
      maxLength: maxLength,
      readOnly: readOnly,
      maxLines: maxLines,
    );
  }
}
