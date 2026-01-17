//stateless widget
import 'package:flutter/material.dart';
import 'package:app/commonWidgets/custom_text_widget.dart';

import '../../constants/app_sizes.dart';

class CustomButtonWithoutBorderRadius extends StatelessWidget {
  final String? title;
  final VoidCallback? onPressed;
  final double? fontSize;
  final FontWeight? fontWeight;
  final double? borderRadius;
  final double? topBorderRadius;
  final bool spaceAtBottom;
  final double? bottomMargin;
  final Color? backGroundColor;
  final Color? borderColor;
  final Color? textColor;

  const CustomButtonWithoutBorderRadius({
    super.key,
    this.title,
    this.onPressed,
    this.topBorderRadius,
    this.borderRadius,
    this.fontSize,
    this.fontWeight,
    this.spaceAtBottom = true,
    this.bottomMargin,
    this.backGroundColor,
    this.borderColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
        style: ButtonStyle(
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            foregroundColor: MaterialStateProperty.all<Color>(Colors.white),
            surfaceTintColor: MaterialStateProperty.all<Color>(Colors.white),
            backgroundColor: MaterialStateProperty.all<Color>(backGroundColor ?? Colors.red),
            shape: MaterialStateProperty.all<RoundedRectangleBorder>(RoundedRectangleBorder(
                borderRadius: BorderRadius.only(
                    topRight: Radius.circular(topBorderRadius ?? 0),
                    topLeft: Radius.circular(topBorderRadius ?? 0),
                    bottomRight: Radius.circular(borderRadius ?? 0),
                    bottomLeft: Radius.circular(borderRadius ?? 0)),
                side: BorderSide(color: borderColor ?? backGroundColor ?? Colors.white)))),
        onPressed: onPressed,
        child: CustomTextWidget(title!,
            fontSize: fontSize ?? AppSizes.sixteen, fontWeight: fontWeight ?? FontWeight.w600, color: textColor));
  }
}
