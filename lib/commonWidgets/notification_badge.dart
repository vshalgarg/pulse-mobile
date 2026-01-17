import 'package:badges/badges.dart' as badges;
import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_sizes.dart';
import '../constants/image_strings.dart';
import 'custom_text_widget.dart';
import 'image_widgets/svg_image_widget.dart';
import 'ink_well_widget.dart';

class NotificationBadge extends StatelessWidget {
  final bool showBadge;
  final String badgeCount;

  const NotificationBadge({super.key, this.showBadge = false, this.badgeCount = "0"});

  @override
  Widget build(BuildContext context) {
    return badges.Badge(
      showBadge: showBadge,
      position: badges.BadgePosition.topEnd(top: -10, end: -8),
      badgeStyle: const badges.BadgeStyle(
        badgeColor: AppColors.notificationDotColor,
        borderSide: BorderSide(color: AppColors.lightAppBarColor, width: 0),
        // padding: EdgeInsets.only(right: 5, left: 4)
      ),
      badgeContent: CustomTextWidget(
        badgeCount,
        fontSize: AppSizes.eight,
        fontWeight: FontWeight.w500,
        color: AppColors.whiteColor,
      ),
      child: InkWellWidget(
        onClicked: () {
          // pushNamedPage(context, notificationsScreen);
        },
        child: const CustomSvgImageWidget(
          imagePath: ImageStrings.jeweleryBell,
          height: 18,
          width: 17,
        ),
      ),
      // Icon(
      //   Icons.notifications,
      //   color: AppColors.baseColorsDarkAccent,
      //   size: 32,
      // ),
    );
  }
}
