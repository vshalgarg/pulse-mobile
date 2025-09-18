
import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_sizes.dart';
import '../../constants/gradient_color.dart';

class CustomButton2 extends StatelessWidget {
  final String? title;
  final VoidCallback? onPressed;
  final double? fontSize;
  final bool spaceAtBottom;
  final double? bottomMargin;
  final bool isDisabled;

  const CustomButton2({
    super.key,
    this.title,
    this.onPressed,
    this.fontSize,
    this.spaceAtBottom = true,
    this.bottomMargin,
    this.isDisabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: !isDisabled
          ? const BoxDecoration(
              color: AppColors.createProfileButtonDisabelBackgroundColor,
              borderRadius: BorderRadius.all(Radius.circular(AppSizes.ten)),
            )
          : buttonGradientDecoration(context: context),
      margin: EdgeInsets.only(
        bottom: spaceAtBottom
            ? Platform.isIOS
                ? AppSizes.thirtyNine
                : AppSizes.twenty
            : bottomMargin ?? 0,
      ),
      padding: const EdgeInsets.symmetric(vertical: AppSizes.one),
      child: ElevatedButton(
        onPressed: !isDisabled ? null : onPressed,
        style: ElevatedButton.styleFrom(
          surfaceTintColor: AppColors.createProfileButtonDisabelBackgroundColor,
          elevation: 0,
          backgroundColor: !isDisabled ? AppColors.createProfileButtonDisabelBackgroundColor : Colors.transparent,
          disabledBackgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.all(AppSizes.ten),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSizes.ten)),
        ),
        child: Text(
          title ?? "",
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
              fontSize: fontSize ?? AppSizes.sixteen,
              color: !isDisabled ? AppColors.textGreyColor : Colors.white,
              fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
//
// class CustomButton2 extends Container {
//   CustomButton2({
//     super.key,
//     final String? title,
//     final VoidCallback? onPressed,
//     final double? fontSize,
//     final bool spaceAtBottom = true,
//     final double? bottomMargin,
//     final bool isDisabled = true,
//   }) : super(
//           decoration: !isDisabled
//               ? const BoxDecoration(
//                   color: AppColors.createProfileButtonDisabelBackgroundColor,
//                   borderRadius: BorderRadius.all(Radius.circular(AppSizes.ten)),
//                 )
//               : buttonGradientDecoration(context: ),
//           margin: EdgeInsets.only(
//             bottom: spaceAtBottom
//                 ? Platform.isIOS
//                     ? AppSizes.thirtyNine
//                     : AppSizes.twenty
//                 : bottomMargin ?? 0,
//           ),
//           padding: const EdgeInsets.symmetric(vertical: AppSizes.one),
//           child: ElevatedButton(
//             onPressed: !isDisabled ? null : onPressed,
//             style: ElevatedButton.styleFrom(
//               surfaceTintColor: AppColors.createProfileButtonDisabelBackgroundColor,
//               elevation: 0,
//               backgroundColor: !isDisabled ? AppColors.createProfileButtonDisabelBackgroundColor : Colors.transparent,
//               disabledBackgroundColor: Colors.transparent,
//               shadowColor: Colors.transparent,
//               padding: const EdgeInsets.all(AppSizes.ten),
//               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSizes.ten)),
//             ),
//             child: Text(
//               title ?? "",
//               overflow: TextOverflow.ellipsis,
//               style: TextStyle(
//                   fontSize: fontSize ?? AppSizes.sixteen,
//                   color: !isDisabled ? AppColors.textGreyColor : Colors.white,
//                   fontWeight: FontWeight.w600),
//             ),
//           ),
//         );
// }
