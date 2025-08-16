import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_sizes.dart';
import '../../constants/constants_methods.dart';
import '../../constants/image_strings.dart';
import '../../custom_buttons/custom_button_without_radious.dart';
import '../../enum/image_type_enum.dart';
import '../custom_buttons/custom_button.dart';
import '../custom_buttons/custom_text_button.dart';
import '../custom_text_widget.dart';
import '../image_widgets/custom_image_widget.dart';

class OnBoardingBottomSheet extends StatelessWidget {
  final String? title;
  final String? description;
  final bool? showVerticalButton;
  final bool? boxLogo;

  final String? btnText1;
  final String? btnText2;
  final VoidCallback? onPressedBtn1;
  final VoidCallback? onPressedBtn2;

  const OnBoardingBottomSheet(
      {Key? key,
      this.title,
      this.description,
      this.showVerticalButton = true,
      this.boxLogo = false,
      this.btnText1,
      this.btnText2,
      this.onPressedBtn1,
      this.onPressedBtn2})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Container(
        width: MediaQuery.of(context).size.width,
        constraints: const BoxConstraints(maxWidth: 1200, minWidth: 1200),
        color: AppColors.whiteColor,
        // padding: const EdgeInsets.symmetric(horizontal: AppSizes.twenty),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            getHeight(AppSizes.forty),
            CustomImageWidget(
              imagePath: boxLogo == true ? ImageStrings.orderDeleteIconPng : ImageStrings.logOutPng,
              width: boxLogo == true ? AppSizes.ninety : AppSizes.sixty,
              height: boxLogo == true ? AppSizes.ninety : AppSizes.sixty,
              imageType: ImageTypeEnum.asset,
            ),
            getHeight(AppSizes.twentyOne),
            CustomTextWidget(title ?? '', textAlign: TextAlign.center, fontSize: 19, fontWeight: FontWeight.w600),
            getHeight(AppSizes.fifteen),
            Text(
              description ?? '',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: AppSizes.fourteen, fontWeight: FontWeight.w400),
            ),
            getHeight(AppSizes.fifteen),
            (showVerticalButton ?? false) ? verticalButtonWidget() : horizontalButtonWidget(context),
          ],
        ),
      ),
    );
  }

  Widget horizontalButtonWidget(context) {
    return Row(
      children: [
        SizedBox(
          height: 60,
          width: MediaQuery.of(context).size.width / 2,
          // width: 182,
          child: CustomButtonWithoutBorderRadius(
            title: "No",
            fontSize: AppSizes.eighteen,
            backGroundColor: AppColors.loginHereTextColor,
            onPressed: onPressedBtn1,
          ),
        ),
        SizedBox(
          height: 60,
          width: MediaQuery.of(context).size.width / 2,
          // width: 189,
          child: CustomButtonWithoutBorderRadius(
            title: "Yes",
            fontSize: AppSizes.eighteen,
            textColor: Colors.black,
            backGroundColor: AppColors.primaryColor,
            onPressed: onPressedBtn2,
          ),
        ),
      ],
    );
  }

  Widget verticalButtonWidget() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        CustomButton2(
          title: btnText1 ?? 'Get Verified',
          onPressed: onPressedBtn1,
          fontSize: AppSizes.sixteen,
          spaceAtBottom: false,
        ),
        getHeight(AppSizes.ten),
        CustomTextButton(
          title: btnText2 ?? 'Skip to Dashboard',
          onButtonPressed: onPressedBtn2,
        ),
        getHeight(AppSizes.ten),
      ],
    );
  }
}
