import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_sizes.dart';

class CustomTextFormFieldWidgetFocusNode extends StatelessWidget {
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
  final bool? autoFocus;
  final FocusNode? focusNode;
  final bool? focusEnabled;
  final AutovalidateMode? autoValidateMode;

  const CustomTextFormFieldWidgetFocusNode({
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
    this.focusNode,
    this.autoFocus,
    this.focusEnabled = false,
    this.autoValidateMode,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    TextStyle defaultStyle =
        const TextStyle(color: AppColors.privacyPolicyandTermsandConditionGray, fontSize: AppSizes.fourteen);
    return TextFormField(
      initialValue: initialValue,
      controller: controller,
      onEditingComplete: onEditingComplete,
      decoration: InputDecoration(
        hintText: hintText,
        label: RichText(
          text: TextSpan(
            style: defaultStyle,
            children: <TextSpan>[
              TextSpan(
                text: autoValidateMode != null ? labelText : hintText,
              ),
              TextSpan(
                text: autoValidateMode != null ? " *" : " ",
                style: const TextStyle(
                  fontSize: 14.0,
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
          borderSide: BorderSide(width: AppSizes.one, color: isValid ? AppColors.redColor : AppColors.reachBlackColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(
            width: AppSizes.one,
            color: isValid ? AppColors.redColor : AppColors.borderColor,
          ),
          borderRadius: BorderRadius.circular(
            AppSizes.ten,
          ),
        ),
        border: OutlineInputBorder(
          borderSide: BorderSide(
            width: AppSizes.one,
            color: isValid ? AppColors.redColor : AppColors.reachBlackColor,
          ),
          borderRadius: BorderRadius.circular(
            AppSizes.ten,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(
            width: AppSizes.one,
            color: isValid ? AppColors.redColor : AppColors.reachBlackColor,
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
      textInputAction: TextInputAction.done ?? textInputAction,
      onSaved: onSaved,
      onChanged: onChanged,
      onTap: onTap,
      obscureText: obscureText,
      maxLength: maxLength,
      readOnly: readOnly,
      maxLines: maxLines,
      enableSuggestions: true,
    );
  }
}
