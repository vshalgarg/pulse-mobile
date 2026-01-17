import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/image_strings.dart';
import 'image_widgets/svg_image_widget.dart';

class CustomSearchIcon extends StatelessWidget {
  final double size;
  final Color color;

  const CustomSearchIcon({
    super.key,
    this.size = 20,
    this.color = AppColors.jeweleryIconColor,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        // pushNamedPage(context, searchProductsScreen);
      },
      child: CustomSvgImageWidget(
        imagePath: ImageStrings.jeweleryMagnifyingGlass,
        height: size,
        width: size,
        color: color,
      ),
    );
  }
}
