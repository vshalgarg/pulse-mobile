import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants/constants_strings.dart';
import '../provider/theme_provider.dart';

class CustomTextWidget extends StatelessWidget {
  final String title;
  final Color? color;
  final double? fontSize;
  final FontStyle fontStyle;
  final FontWeight fontWeight;
  final TextDecoration decoration;
  final TextAlign? textAlign;
  final TextOverflow textOverflow;
  final int? maxLines;
  final String? fontFamily;
  final double? height;

  const CustomTextWidget(
    this.title, {
    super.key,
    this.color,
    this.fontSize,
    this.maxLines,
    this.fontStyle = FontStyle.normal,
    this.fontWeight = FontWeight.normal,
    this.decoration = TextDecoration.none,
    this.textAlign,
    this.textOverflow = TextOverflow.visible,
    this.fontFamily,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      maxLines: maxLines,
      textAlign: textAlign,
      overflow: textOverflow,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: Provider.of<ThemeProvider>(context).isDarkMode ? Colors.white : color,
          fontSize: fontSize,
          fontStyle: fontStyle,
          fontWeight: fontWeight,
          decoration: decoration,
          fontFamily: fontFamily ?? fontFamilyLato,
          height: height),
    );
  }
}
