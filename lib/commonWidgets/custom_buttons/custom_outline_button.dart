import 'dart:io';

import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_sizes.dart';

class CustomOutlineButton extends StatelessWidget {
  final String? title;
  final VoidCallback? onPressed;
  final double? fontSize;
  final bool? showShadow;
  final bool spaceAtBottom;
  final double? bottomMargin;
  final double? horizontalPadding;
  final double? padding;

  const CustomOutlineButton(
      {super.key,
      this.title,
      this.onPressed,
      this.fontSize,
      this.showShadow = false,
      this.spaceAtBottom = true,
      this.bottomMargin,
      this.horizontalPadding,
      this.padding});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
          color: AppColors.whiteColor,
          border: Border.all(color: AppColors.blackColor.withOpacity(0.2)),
          borderRadius: const BorderRadius.all(Radius.circular(AppSizes.ten))),
      margin: EdgeInsets.only(
        bottom: spaceAtBottom
            ? Platform.isIOS
                ? AppSizes.thirtyNine
                : AppSizes.twenty
            : bottomMargin ?? 0,
      ),
      // padding: const EdgeInsets.symmetric(vertical: AppSizes.one),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          surfaceTintColor: AppColors.whiteColor,
          elevation: (showShadow ?? false) ? 0 : 0,
          backgroundColor: AppColors.whiteColor,
          disabledForegroundColor: AppColors.whiteColor,
          shadowColor: AppColors.whiteColor,
          padding:
              EdgeInsets.symmetric(vertical: padding ?? AppSizes.ten, horizontal: horizontalPadding ?? AppSizes.zero),
          shape: const RoundedRectangleBorder(
              // side:
              //     BorderSide(color: AppColors.blackColor.withOpacity(0.2)),
              borderRadius: BorderRadius.all(Radius.circular(AppSizes.ten))),
        ),
        child: Text(
          title ?? "",
          style: TextStyle(
              fontSize: fontSize ?? AppSizes.sixteen,
              overflow: TextOverflow.ellipsis,
              color: Theme.of(context).primaryColor,
              fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

//
// class CustomOutlineButton extends Container {
//   CustomOutlineButton(
//       {super.key,
//       final String? title,
//       final VoidCallback? onPressed,
//       final double? fontSize,
//       final bool? showShadow = false,
//       final bool spaceAtBottom = true,
//       final double? bottomMargin,
//       final double? horizontalPadding,
//       final double? padding})
//       : super(
//           decoration: BoxDecoration(
//               color: AppColors.whiteColor,
//               border: Border.all(color: AppColors.blackColor.withOpacity(0.2)),
//               borderRadius: const BorderRadius.all(Radius.circular(AppSizes.ten))),
//           margin: EdgeInsets.only(
//             bottom: spaceAtBottom
//                 ? Platform.isIOS
//                     ? AppSizes.thirtyNine
//                     : AppSizes.twenty
//                 : bottomMargin ?? 0,
//           ),
//           // padding: const EdgeInsets.symmetric(vertical: AppSizes.one),
//           child: ElevatedButton(
//             onPressed: onPressed,
//             style: ElevatedButton.styleFrom(
//               surfaceTintColor: AppColors.whiteColor,
//               elevation: (showShadow ?? false) ? 0 : 0,
//               backgroundColor: AppColors.whiteColor,
//               disabledForegroundColor: AppColors.whiteColor,
//               shadowColor: AppColors.whiteColor,
//               padding: EdgeInsets.symmetric(
//                   vertical: padding ?? AppSizes.ten, horizontal: horizontalPadding ?? AppSizes.zero),
//               shape: const RoundedRectangleBorder(
//                   // side:
//                   //     BorderSide(color: AppColors.blackColor.withOpacity(0.2)),
//                   borderRadius: BorderRadius.all(Radius.circular(AppSizes.ten))),
//             ),
//             child: Text(
//               title ?? "",
//               style: TextStyle(
//                   fontSize: fontSize ?? AppSizes.sixteen,
//                   overflow: TextOverflow.ellipsis,
//                   color: Theme.of(context).primaryColor,
//                   fontWeight: FontWeight.w600),
//             ),
//           ),
//         );
// }
