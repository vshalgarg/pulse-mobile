
import 'package:flutter/material.dart';

import '../../constants/app_sizes.dart';

class CustomBlackButton extends Container {
  CustomBlackButton({
    super.key,
    final String? title,
    final VoidCallback? onPressed,
    final double? fontSize,
    final bool spaceAtBottom = true,
    final double? bottomMargin,
  }) : super(
            decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                borderRadius: const BorderRadius.all(Radius.circular(AppSizes.ten))),
            margin: EdgeInsets.only(
              bottom: spaceAtBottom
                  ? Platform.isIOS
                      ? AppSizes.thirtyNine
                      : AppSizes.twenty
                  : bottomMargin ?? 0,
            ),
            padding: const EdgeInsets.symmetric(vertical: AppSizes.one),
            child: ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                // elevation: 0,
                backgroundColor: Colors.transparent,
                surfaceTintColor: Colors.transparent,
                shadowColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(vertical: AppSizes.ten),
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(AppSizes.ten))),
              ),
              child: Text(
                title ?? "",
                style: TextStyle(
                    fontSize: fontSize ?? AppSizes.twenty,
                    overflow: TextOverflow.ellipsis,
                    color: Colors.white,
                    fontWeight: FontWeight.w600),
              ),
            ));
}
