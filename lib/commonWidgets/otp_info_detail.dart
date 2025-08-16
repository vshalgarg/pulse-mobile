import 'package:flutter/cupertino.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_sizes.dart';
import '../constants/constants_methods.dart';
import 'custom_text_widget.dart';
import 'image_widgets/svg_image_widget.dart';

class OtpInfoDetail extends StatelessWidget {
  final String logo;
  final String? title;
  final String? subTitle;
  final String subTitleDetails;
  final bool? isTablet;

  const OtpInfoDetail({
    required this.logo,
     this.title,
     this.subTitle,
    required this.subTitleDetails,
    required this.isTablet,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        getHeight(
          (isTablet ?? false) ? AppSizes.zero : AppSizes.thirtyFive,
        ),
        CustomSvgImageWidget(
          imagePath: logo,
          semanticsLabel: 'otp Logo',
          height: 150,
          width: 150,
        ),
        getHeight(
          AppSizes.twenty,
        ),
        CustomTextWidget(
          title ?? '',
          fontSize: AppSizes.twentyTwo,
          fontWeight: FontWeight.w600,
          color: AppColors.reachBlackColor,
          textAlign: TextAlign.center,
        ),
        getHeight(
          AppSizes.twenty,
        ),
        CustomTextWidget(subTitle ?? '',
            fontSize: AppSizes.fourteen,
            fontWeight: FontWeight.w400,
            color: AppColors.reachBlackColor,
            textAlign: TextAlign.center),
        getHeight(AppSizes.five),
        CustomTextWidget(
          subTitleDetails,
          fontSize: AppSizes.fourteen,
          fontWeight: FontWeight.w400,
          color: AppColors.reachBlackColor,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
