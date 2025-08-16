import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../constants/app_sizes.dart';
import '../constants/constants_strings.dart';
import '../provider/theme_provider.dart';

class CustomRichTextWidget extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color color;
  final Color subColor;
  final double fontSize1;
  final double fontSize2;
  final FontStyle fontStyle;
  final FontWeight fontWeight1;
  final FontWeight fontWeight2;
  final TextDecoration decoration;
  final TextDecoration subDecoration;
  final TapGestureRecognizer? recognizer;

  const CustomRichTextWidget(this.title, this.subtitle,
      {super.key,
      this.color = Colors.grey,
      this.subColor = Colors.grey,
      this.fontSize1 = AppSizes.fourteen,
      this.fontSize2 = AppSizes.fourteen,
      this.fontStyle = FontStyle.normal,
      this.fontWeight1 = FontWeight.normal,
      this.fontWeight2 = FontWeight.normal,
      this.decoration = TextDecoration.none,
      this.subDecoration = TextDecoration.none,
      this.recognizer});

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        text: title,
        style: TextStyle(
          color: Provider.of<ThemeProvider>(context).isDarkMode ? Colors.white : color,
          fontSize: fontSize1,
          fontStyle: fontStyle,
          fontWeight: fontWeight1,
          decoration: decoration,
          fontFamily: fontFamilyLato,
        ),
        children: [
          TextSpan(
              text: subtitle,
              style: TextStyle(
                color: Provider.of<ThemeProvider>(context).isDarkMode ? Colors.white : subColor,
                fontSize: fontSize2,
                fontStyle: fontStyle,
                fontWeight: fontWeight2,
                decoration: subDecoration,
                fontFamily: fontFamilyLato,
              ),
              recognizer: recognizer),
        ],
      ),
    );
  }
}
