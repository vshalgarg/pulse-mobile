import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_sizes.dart';

class CustomHorizontalDivider extends Container {
  CustomHorizontalDivider({super.key, Color color = AppColors.greyDividerColor, double height = AppSizes.one})
      : super(height: height, width: double.infinity, color: color);
}
