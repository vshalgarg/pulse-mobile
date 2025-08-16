import 'package:flutter/material.dart';

import '../../constants/constants_strings.dart';

class CustomButton extends StatelessWidget {
  final String text;
  final Color color;
  final VoidCallback onPressed;
  final Color textColor;
  final double height;
  final double fontSize;
  final double? width; // optional width

  const CustomButton({
    Key? key,
    required this.text,
    required this.color,
    required this.onPressed,
    this.textColor = Colors.white,
    this.height = 50,
    this.fontSize = 16,
    this.width, // can be null for full width
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: width ?? double.infinity, // full width if not provided
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(50),
          ),
          elevation: 0,
        ),
        onPressed: onPressed,
        child: Text(
          text,
          style: TextStyle(
            color: textColor,
            fontSize: fontSize,
            fontWeight: FontWeight.w500,
            fontFamily: fontFamilyInter
          ),
        ),
      ),
    );
  }
}
