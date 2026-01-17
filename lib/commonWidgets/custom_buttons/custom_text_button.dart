import 'package:app/constants/constants_strings.dart';
import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_sizes.dart';

class CustomTextButton extends StatelessWidget {
  final String? title;
  final VoidCallback? onButtonPressed;
  final bool? decoration;
  final EdgeInsetsGeometry? padding;

  const CustomTextButton({super.key,this.padding,  this.title, this.decoration, this.onButtonPressed});

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onButtonPressed,
      child: Text(
        title ?? '',
        style: TextStyle(
            color:AppColors.forgotColor,
            fontSize: AppSizes.fourteen,
            decoration: decoration == true ? TextDecoration.underline : TextDecoration.none,
            decorationColor: AppColors.forgotColor,
            fontFamily: fontFamilyInter,
            fontWeight: FontWeight.w400),
      ),
    );
  }
}

