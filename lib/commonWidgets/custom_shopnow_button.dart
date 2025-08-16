import 'dart:io';

import 'package:flutter/material.dart';
import 'package:app/constants/app_sizes.dart';

import '../../constants/app_colors.dart';

class CustomShopNowButton extends StatelessWidget {
  final String? title;
  final VoidCallback? onPressed;
  final double? fontSize;
  final bool spaceAtBottom;
  final double? bottomMargin;
  final bool isDisabled;
  final double? width;
  final double? height;
  final Color? buttonBackgroundColor;
  final Color? textColor;
  final double horizontalPadding;
  final double verticalPadding;

  const CustomShopNowButton({
    super.key,
    this.title,
    this.onPressed,
    this.fontSize,
    this.spaceAtBottom = true,
    this.bottomMargin,
    this.isDisabled = true,
    this.width,
    this.height,
    this.buttonBackgroundColor,
    this.textColor,
    this.horizontalPadding = 0,
    this.verticalPadding = AppSizes.four,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(
        bottom: spaceAtBottom
            ? Platform.isIOS
                ? AppSizes.thirtyNine
                : AppSizes.twenty
            : bottomMargin ?? 0,
      ),
      child: ElevatedButton(
        onPressed: !isDisabled ? null : onPressed,
        style: ElevatedButton.styleFrom(
          surfaceTintColor: AppColors.createProfileButtonDisabelBackgroundColor,
          elevation: 0,
          backgroundColor:
              !isDisabled ? AppColors.createProfileButtonDisabelBackgroundColor : Theme.of(context).primaryColor,
          disabledBackgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: EdgeInsets.symmetric(vertical: verticalPadding, horizontal: horizontalPadding),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSizes.ten)),
        ),
        child: Text(
          "Shop Now",
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
              fontSize: fontSize ?? AppSizes.twelve,
              color: !isDisabled ? AppColors.textGreyColor : Colors.white,
              fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
