import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_sizes.dart';

class DisabledTextFormFieldWidget extends StatelessWidget {
  final String? initialValue;
  final TextEditingController? controller;
  final InputBorder? inputBorder;
  final String? labelText;
  final String? Function(String?)? validator;
  final void Function()? onEditingComplete;
  final TextInputType? keyboardType;
  final Function(String?)? onSaved;
  final Function(String)? onChanged;
  final void Function()? onTap;
  final String? Function(String?)? onFieldSubmitted;
  final bool obscureText;
  final int? maxLength;
  final bool readOnly;
  final bool isValid;
  final Widget? suffixIcon;
  final int? maxLines;
  final Widget? prefixIcon;
  final Color? prefixIconColor;
  final Color? suffixIconColor;
  final String? errorText;
  final String? hintText;
  final TextInputAction? textInputAction;
  final bool enabledBorderColor;

  const DisabledTextFormFieldWidget({
    this.inputBorder,
    this.initialValue,
    this.controller,
    this.labelText,
    this.validator,
    this.keyboardType,
    this.onSaved,
    this.onChanged,
    this.onTap,
    this.obscureText = false,
    this.maxLength,
    this.readOnly = false,
    this.isValid = false,
    this.suffixIcon,
    this.maxLines = 1,
    this.prefixIcon,
    this.suffixIconColor,
    this.prefixIconColor,
    this.errorText,
    this.onEditingComplete,
    this.hintText,
    this.textInputAction,
    this.onFieldSubmitted,
    this.enabledBorderColor = false,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    TextStyle defaultStyle =
        const TextStyle(color: AppColors.reachBlackColor, fontWeight: FontWeight.w500, fontSize: AppSizes.fourteen);
    return IgnorePointer(
      child: TextFormField(
        initialValue: initialValue,
        controller: controller,
        onEditingComplete: onEditingComplete,
        onFieldSubmitted: onFieldSubmitted,
        decoration: InputDecoration(
          //labelText: labelText,
          hintText: hintText,
          label: RichText(
            text: TextSpan(
              style: defaultStyle,
              children: <TextSpan>[
                TextSpan(
                  text: labelText,
                ),
                const TextSpan(
                  text: " *",
                  style: TextStyle(
                    fontSize: AppSizes.fourteen,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(
              AppSizes.ten,
            ),
            borderSide: const BorderSide(width: AppSizes.one, color: AppColors.borderColor),
          ),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(
              width: AppSizes.one,
              color: enabledBorderColor ? AppColors.reachBlackColor : AppColors.borderColor,
            ),
            borderRadius: BorderRadius.circular(
              AppSizes.ten,
            ),
          ),
          border: OutlineInputBorder(
            borderSide: const BorderSide(
              width: AppSizes.one,
              color: AppColors.borderColor,
            ),
            borderRadius: BorderRadius.circular(
              AppSizes.ten,
            ),
          ),
          suffixIcon: suffixIcon,
          suffixIconColor: suffixIconColor,
          prefixIcon: prefixIcon,
          prefixIconColor: prefixIconColor,
          contentPadding: const EdgeInsets.fromLTRB(15, 15, 25, 15),
          errorText: errorText,
          errorStyle: const TextStyle(fontSize: AppSizes.fourteen),
        ),
        validator: validator,
        keyboardType: keyboardType,
        textInputAction: TextInputAction.done,
        onSaved: onSaved,
        onChanged: onChanged,
        style: const TextStyle(
          color: AppColors.greyColor,
          fontSize: AppSizes.fourteen,
          fontWeight: FontWeight.w400,
        ),
        onTap: onTap,
        obscureText: obscureText,
        maxLength: maxLength,
        readOnly: readOnly,
        maxLines: maxLines,
        enableSuggestions: true,
      ),
    );
  }
}
