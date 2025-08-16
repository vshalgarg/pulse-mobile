import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/image_strings.dart';
import 'image_widgets/svg_image_widget.dart';

class CustomShareIcon extends StatelessWidget {
  final double size;
  final Color color;

  const CustomShareIcon({
    super.key,
    this.size = 20,
    this.color = AppColors.jeweleryIconColor,
  });

  @override
  Widget build(BuildContext context) {
    return CustomSvgImageWidget(
      imagePath: ImageStrings.shareIcon,
      height: size,
      width: size,
      color: color,
    );
  }
}
