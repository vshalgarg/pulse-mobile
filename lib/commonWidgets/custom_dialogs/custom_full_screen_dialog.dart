import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_sizes.dart';
import '../../constants/constants_methods.dart';
import '../../constants/text_style.dart';
import '../custom_buttons/custom_button.dart';
import '../custom_buttons/custom_outline_button.dart';

class CustomFullScreenAlertDialog extends StatelessWidget {
  final String? title;
  final String? subTitle1;
  final bool? isSuccess;
  final String? buttonText1;
  final String? buttonText2;
  final VoidCallback? onButtonPressed1;
  final VoidCallback? onButtonPressed2;
  final String? navigationText;
  final bool isHavingAppBar;
  final bool hasCustomButtonSpace;

  const CustomFullScreenAlertDialog({
    Key? key,
    this.title,
    this.subTitle1,
    this.isSuccess = true,
    this.buttonText1,
    this.buttonText2,
    this.onButtonPressed1,
    this.onButtonPressed2,
    this.navigationText,
    this.isHavingAppBar = false,
    this.hasCustomButtonSpace = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () {
        return Future(() => false);
      },
      child: Scaffold(
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSizes.sixteen),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    // mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      getHeight(
                          getDeviceHeight(context) * 0.20 - (isHavingAppBar ? getDeviceHeight(context) * 0.10 : 0)),
                      SvgPicture.asset(
                        (isSuccess ?? false)
                            ? '${assetSvgPathIcons}success_icon.svg'
                            : '${assetSvgPathIcons}failure_icon.svg',
                      ),
                      getHeight(AppSizes.ten),
                      getHeight(AppSizes.ten),
                      Text(
                        title ?? '',
                        style: titleTextStyle(fontSize: AppSizes.twentyTwo, fontColor: AppColors.blackColor252525),
                        textAlign: TextAlign.center,
                      ),
                      getHeight(AppSizes.ten),
                      Text(
                        subTitle1 ?? '',
                        style: subTitleTextStyle(fontColor: AppColors.subTitleGray),
                        textAlign: TextAlign.center,
                      ),
                      getHeight(AppSizes.ten),
                    ],
                  ),
                ),
              ),
              getHeight(AppSizes.ten),
              if ((buttonText1?.length ?? 0) > 0)
                CustomButton2(
                  title: buttonText1 ?? "",
                  onPressed: onButtonPressed1,
                  fontSize: AppSizes.sixteen,
                  spaceAtBottom: hasCustomButtonSpace,
                ),
              hasCustomButtonSpace == false ? getHeight(AppSizes.ten) : getHeight(AppSizes.zero),
              if (((buttonText1?.length ?? 0) > 0) && ((buttonText2?.length ?? 0) > 0)) getHeight(AppSizes.ten),
              if ((buttonText2?.length ?? 0) > 0)
                CustomOutlineButton(
                  title: buttonText2 ?? "",
                  onPressed: onButtonPressed2,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
