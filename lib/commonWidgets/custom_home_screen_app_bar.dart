import 'package:flutter/material.dart';
import 'package:app/extensions/string_extension.dart';


import '../commonWidgets/custom_search_icon.dart';
import '../commonWidgets/custom_text_widget.dart';
import '../commonWidgets/notification_badge.dart';
import '../constants/app_colors.dart';
import '../constants/constants_methods.dart';
import '../constants/image_strings.dart';
import '../services/local_storage_db.dart';

class CustomHomeScreenAppBar extends AppBar {
  CustomHomeScreenAppBar({
    super.key,
    String? title,
    final BuildContext? context,
    final bool? showBackButton = true,
    final VoidCallback? onBackPressed,
    final List<Widget>? actionWidget,
    final bool? showIcons = false,
    final bool showUserInfo = true,
  }) : super(
          elevation: 0,
          title: Padding(
            padding: const EdgeInsets.all(1.0),
            child: Column(
              children: [
                // Removed ValueListenableBuilder - using SharedPreferences now
                Builder(
                  builder: (context) {
                    final String? profileImage = LocalStorageDB.getProfileImage;
                    final String? firstName = LocalStorageDB.getFirstName;
                    if (profileImage == null && firstName == null) {
                      // place holder
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const CircleAvatar(
                            backgroundColor: AppColors.transparentColor,
                            radius: 20,
                            backgroundImage: AssetImage(ImageStrings.profilePlaceholderIcon),
                          ),
                          getWidth(8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const CustomTextWidget(
                                "Hello",
                                color: AppColors.blackColor,
                                fontWeight: FontWeight.w400,
                                fontSize: 14.0,
                              ),
                              getHeight(5),
                              const CustomTextWidget(
                                "Guest",
                                color: AppColors.blackColor,
                                fontWeight: FontWeight.w600,
                                fontSize: 16.0,
                              ),
                            ],
                          ),
                          const Spacer(),
                        ],
                      );
                    }
                    // show data here
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          backgroundColor: AppColors.transparentColor,
                          radius: 20,
                          backgroundImage: profileImage != null
                              ? Image.network(
                                  profileImage,
                                  height: 40,
                                  width: 40,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return const Image(image: getPlaceholder);
                                  },
                                ).image
                              : const AssetImage(ImageStrings.profilePlaceholderIcon),
                        ),
                        getWidth(8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const CustomTextWidget(
                              "Welcome",
                              color: AppColors.blackColor,
                              fontWeight: FontWeight.w400,
                              fontSize: 14.0,
                            ),
                            //getHeight(2),
                            CustomTextWidget(
                              firstName?.capitalize() ?? "",
                              color: AppColors.blackColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 16.0,
                            ),
                          ],
                        ),
                        const Spacer(),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          centerTitle: false,
          toolbarHeight: 60.0,
          leading: showBackButton == false
              ? InkWell(
                  onTap: onBackPressed ??
                      () {
                        Navigator.of(context!).pop();
                      },
                  child: const Icon(
                    Icons.arrow_back_ios_new,
                    // color: AppColors.jeweleryIconColor,
                    size: 20,
                  ))
              : const SizedBox(),
          actions: [
            const CustomSearchIcon(size: 16),
            getWidth(22),
            const NotificationBadge(),
            getWidth(22),

            getWidth(22),
          ],
          leadingWidth: 0.0,
        );
}
