import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../constants/constants_methods.dart';

class CustomSvgImageWithColorWidget extends StatelessWidget {
  final String imagePath;
  final double? height;
  final double? width;
  final BoxFit? boxFit;
  final Color? color;
  final BlendMode? blendMode;
  final String? semanticsLabel;
  final Alignment? alignment;

  const CustomSvgImageWithColorWidget({
    Key? key,
    required this.imagePath,
    this.height,
    this.width,
    this.boxFit,
    this.color,
    this.blendMode,
    this.semanticsLabel,
    this.alignment,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      '$assetSvgPathIcons$imagePath',
      height: height,
      width: width,
      fit: boxFit ?? BoxFit.contain,
      semanticsLabel: semanticsLabel ?? "",
      alignment: alignment ?? Alignment.center,
      colorFilter: ColorFilter.mode(color ?? Theme.of(context).primaryColor, BlendMode.srcIn),
    );
  }
}
