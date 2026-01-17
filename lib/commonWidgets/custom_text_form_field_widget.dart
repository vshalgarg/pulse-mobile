import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants/app_colors.dart';
import '../constants/app_sizes.dart';

class CustomTextFormFieldWidget extends StatelessWidget {
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
  final int? minLines;
  final Widget? prefixIcon;
  final Color? prefixIconColor;
  final Color? suffixIconColor;
  final String? errorText;
  final String? hintText;
  final TextInputAction? textInputAction;
  final bool? autoFocus;
  final bool? showStar;
  final FocusNode? focusNode;
  final bool? focusEnabled;
  final AutovalidateMode? autovalidateMode;
  final bool? enabled;
  final bool? fillColor;
  final bool? enableBorder;
  final List<TextInputFormatter>? inputFormatters;

  const CustomTextFormFieldWidget({
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
    this.minLines = 1,
    this.maxLines = 1,
    this.prefixIcon,
    this.suffixIconColor,
    this.prefixIconColor,
    this.errorText,
    this.onEditingComplete,
    this.hintText,
    this.textInputAction,
    this.focusNode,
    this.showStar = true,
    this.autoFocus,
    this.focusEnabled = false,
    this.autovalidateMode,
    this.onFieldSubmitted,
    this.enabled = true,
    this.fillColor = false,
    this.enableBorder = false,
    this.inputFormatters,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    TextStyle defaultStyle = TextStyle(
        color: (autoFocus ?? false) ? Theme.of(context).primaryColor : AppColors.textGreyColor,
        fontWeight: (autoFocus ?? false) ? FontWeight.w500 : FontWeight.w400,
        fontSize: AppSizes.fourteen);
    return TextFormField(
      initialValue: initialValue,
      controller: controller,
      onEditingComplete: onEditingComplete,
      onFieldSubmitted: onFieldSubmitted,
      focusNode: focusNode,
      autovalidateMode: autovalidateMode,
      enabled: enabled,
      style: Theme.of(context).textTheme.displayLarge,
      decoration: InputDecoration(
        //labelText: labelText,
        hintText: hintText,
        label: RichText(
          text: TextSpan(
            style: defaultStyle,
            children: <TextSpan>[
              TextSpan(
                text: focusEnabled!
                    ? (autoFocus ?? false)
                        ? labelText
                        : hintText
                    : labelText,
              ),
              TextSpan(
                text: focusEnabled!
                    ? (autoFocus ?? false)
                        ? (showStar ?? false)
                            ? " *"
                            : ""
                        : " "
                    : " ",
                style: const TextStyle(
                  fontSize: 14.0,
                  color: Colors.red,
                ),
              ),
            ],
          ),
        ),
        filled: readOnly,
        fillColor: readOnly && (fillColor ?? false) ? AppColors.lightGray : AppColors.whiteColor,
        counterText: "",
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(
            AppSizes.ten,
          ),
          borderSide:
              BorderSide(width: AppSizes.one, color: isValid ? AppColors.redColor : Theme.of(context).primaryColor),
        ),
        disabledBorder: OutlineInputBorder(
          borderSide: BorderSide(
            width: AppSizes.one,
            color: isValid ? AppColors.redColor : AppColors.borderColor,
          ),
          borderRadius: BorderRadius.circular(
            AppSizes.ten,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(
            width: AppSizes.one,
            color: isValid
                ? AppColors.redColor
                : enableBorder!
                    ? Theme.of(context).primaryColor
                    : AppColors.borderColor,
          ),
          borderRadius: BorderRadius.circular(
            AppSizes.ten,
          ),
        ),
        border: OutlineInputBorder(
          borderSide: BorderSide(
            width: AppSizes.one,
            color: isValid
                ? AppColors.redColor
                : enableBorder!
                    ? Theme.of(context).primaryColor
                    : Theme.of(context).primaryColor,
          ),
          borderRadius: BorderRadius.circular(
            AppSizes.ten,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(
            width: AppSizes.one,
            color: isValid ? AppColors.redColor : Theme.of(context).primaryColor,
          ),
          borderRadius: BorderRadius.circular(
            AppSizes.ten,
          ),
        ),
        suffixIcon: suffixIcon,
        suffixIconColor: suffixIconColor ?? Theme.of(context).primaryColor,
        prefixIcon: prefixIcon,
        prefixIconColor: prefixIconColor ?? Theme.of(context).primaryColor,
        contentPadding: const EdgeInsets.fromLTRB(15, 15, 25, 15),
        errorText: errorText,
        errorStyle: const TextStyle(fontSize: AppSizes.fourteen),
      ),
      validator: validator,
      inputFormatters: inputFormatters,
      keyboardType: keyboardType,
      textInputAction: TextInputAction.done,
      onSaved: onSaved,
      onChanged: onChanged,
      onTap: onTap,
      obscureText: obscureText,
      maxLength: maxLength,
      readOnly: readOnly,
      minLines: minLines,
      maxLines: maxLines,
      enableSuggestions: true,
    );
  }
}
