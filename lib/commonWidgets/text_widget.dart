import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../provider/theme_provider.dart';

class TextWidget extends StatelessWidget {
  final String title;
  final Color? color;
  final double? fontSize;
  final FontStyle fontStyle;
  final FontWeight fontWeight;
  final TextDecoration decoration;
  final TextAlign textAlign;
  final TextOverflow textOverflow;

  const TextWidget(this.title,
      {super.key,
      this.color,
      this.fontSize,
      this.fontStyle = FontStyle.normal,
      this.fontWeight = FontWeight.normal,
      this.decoration = TextDecoration.none,
      this.textAlign = TextAlign.start,
      this.textOverflow = TextOverflow.visible});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      textAlign: textAlign,
      overflow: textOverflow,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: Provider.of<ThemeProvider>(context).isDarkMode ? Colors.white : color,
          fontSize: fontSize,
          fontStyle: fontStyle,
          fontWeight: fontWeight,
          decoration: decoration,
          fontFamily: GoogleFonts.poppins().fontFamily),
    );
  }
}
