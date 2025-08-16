import 'package:flutter/material.dart';

import '/constants/app_colors.dart';
import 'app_sizes.dart';

gradientColorBackground() {
  return BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [AppColors.whiteColor, AppColors.lightAppBarColor],
      ),
      boxShadow: [
        BoxShadow(
          offset: Offset(0, 1),
          color: AppColors.chipsBorderColor.withOpacity(0.7),
          blurRadius: 5,
        ),
      ],
      border: Border.all(color: AppColors.productsBackgroundColor),
      borderRadius: const BorderRadius.all(Radius.circular(AppSizes.ten)));
}

// categories small card gradient added
categoriesSmallCardGradient() {
  return const BoxDecoration(
    gradient: LinearGradient(
      colors: [
        Colors.white,
        Color(0xfffeede3),
        Color(0xfffdf1e0),
        Colors.white,
        Color(0xfffff0f4),
      ],
    ),
  );
}

buttonGradientDecoration({double borderRadius = 30, BuildContext? context}) {
  return BoxDecoration(
    gradient: LinearGradient(
      colors: [
        Theme.of(context!).primaryColor,
        Theme.of(context).primaryColor.withOpacity(0.7),
        // AppColors.greenGradient1,
        // AppColors.greenGradient5,
      ],
    ),
    boxShadow: greyBoxShadow(),
    borderRadius: BorderRadius.all(Radius.circular(borderRadius)),
  );
}

boxShadow() {
  return [
    const BoxShadow(
      offset: Offset(0, 0),
      color: Color.fromRGBO(135, 135, 135, 0.15),
      blurRadius: 5,
      spreadRadius: 2,
    )
  ];
}

greyBoxShadow() {
  return [
    const BoxShadow(
      color: AppColors.lightGreyColor,
      offset: Offset(0, 5),
      blurRadius: 20,
    ),
  ];
}

lightGreenBoxShadow() {
  return [
    BoxShadow(
      color: AppColors.shadowGreyColor2.withOpacity(.5),
      offset: const Offset(0, 7),
      blurRadius: 20,
    ),
  ];
}

pinkGradientDecoration({double borderRadius = 4}) {
  return BoxDecoration(
    gradient: const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        AppColors.purpleGradient1,
        AppColors.pinkGradient1,
      ],
    ),
    borderRadius: BorderRadius.all(Radius.circular(borderRadius)),
  );
}
