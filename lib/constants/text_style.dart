import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_sizes.dart';

titleTextStyle({double? fontSize, Color? fontColor}) {
  return TextStyle(
      fontSize: fontSize ?? AppSizes.twentyFour,
      fontWeight: FontWeight.w600,
      color: fontColor ?? AppColors.blackColor,
      letterSpacing: .4);
}

subTitleTextStyle({double? fontSize, Color? fontColor}) {
  return TextStyle(
    fontSize: fontSize ?? AppSizes.fourteen,
    fontWeight: FontWeight.w400,
    color: fontColor ?? AppColors.reachBlackColor,
  );
}
