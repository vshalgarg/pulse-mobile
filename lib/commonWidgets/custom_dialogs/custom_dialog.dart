
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:app/commonWidgets/custom_buttons/custom_outline_button.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_sizes.dart';
import '../../constants/text_style.dart';
import '../custom_buttons/custom_button.dart';
import '../ink_well_widget.dart';

class CustomAlertDialog extends StatelessWidget {
  final bool showImage;
  final String? title;
  final String? subTitle1;
  final String? subTitle2;
  final String? subTitle3;
  final String? greyTextStart;
  final String? greenText;
  final String? greyTextStart1;
  final String? greenText1;
  final String? greyTextEnd;
  final String? greyTextEnd1;
  final String? buttonText1;
  final String? buttonText2;
  final VoidCallback? onNavigateText;
  final GestureRecognizer? onNavigateText1;
  final VoidCallback? onButtonPressed1;
  final VoidCallback? onButtonPressed2;
  final bool? isSuccess;

  const CustomAlertDialog({
    Key? key,
    this.showImage = true,
    this.title,
    this.subTitle1,
    this.subTitle2,
    this.subTitle3,
    this.greyTextStart,
    this.greenText,
    this.greyTextStart1,
    this.greenText1,
    this.greyTextEnd,
    this.greyTextEnd1,
    this.buttonText1,
    this.buttonText2,
    this.onNavigateText,
    this.onNavigateText1,
    this.onButtonPressed1,
    this.onButtonPressed2,
    this.isSuccess,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
        onWillPop: () {
          return Future(() => false);
        },
        child: Scaffold(
          backgroundColor: AppColors.transparentColor,
          body: Dialog(
            elevation: 0,
            alignment: Alignment.center,
            backgroundColor: AppColors.whiteColor,
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(AppSizes.twenty))),
            child: Padding(
              padding: EdgeInsets.only(
                  top: Platform.isIOS ? AppSizes.fifteen : AppSizes.thirteen,
                  bottom: Platform.isIOS ? AppSizes.twentyFive : AppSizes.twentyThree,
                  left: AppSizes.ten,
                  right: AppSizes.ten),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (showImage) verticalMargin,
                  if (showImage)
                    // SvgImageWidget(
                    //   //imagePath: 'pop_up_icon.svg',
                    //   imagePath: (isSuccess ?? false) ? 'success_icon.svg' : 'pop_up_icon.svg',
                    //   height: 150,
                    //   width: 150,
                    // ),
                    verticalMargin,
                  Text(
                    title ?? '',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: titleTextStyle(),
                    textAlign: TextAlign.center,
                  ),
                  verticalMargin,
                  if ((subTitle1?.length ?? 0) > 0)
                    Text(
                      subTitle1 ?? '',
                      style: subTitleTextStyle(),
                      textAlign: TextAlign.center,
                    ),
                  verticalMargin,
                  if ((subTitle2?.length ?? 0) > 0)
                    Column(
                      children: [
                        Text(
                          subTitle2 ?? '',
                          style: subTitleTextStyle(fontColor: AppColors.greyColor),
                          textAlign: TextAlign.center,
                        ),
                        verticalMargin,
                      ],
                    ),
                  if ((subTitle3?.length ?? 0) > 0)
                    Column(
                      children: [
                        Text(
                          subTitle3 ?? '',
                          style: subTitleTextStyle(fontColor: AppColors.greyColor),
                          textAlign: TextAlign.center,
                        ),
                        verticalMargin,
                      ],
                    ),
                  if ((greyTextStart1?.length ?? 0) > 0)
                    richTextWidgetCall(
                      greyTextStart: greyTextStart1,
                      greenText: greenText1,
                      greyTextEnd: greyTextEnd1,
                    ),
                  verticalMargin,
                  Row(
                    children: [
                      if ((buttonText1?.length ?? 0) > 0)
                        Expanded(
                          child: CustomOutlineButton(
                            title: buttonText1 ?? "",
                            spaceAtBottom: false,
                            onPressed: onButtonPressed1,
                          ),
                        ),
                      if (((buttonText1?.length ?? 0) > 0) && ((buttonText2?.length ?? 0) > 0)) horizontalMargin,
                      if ((buttonText2?.length ?? 0) > 0)
                        Expanded(
                          child: CustomButton2(
                            title: buttonText2 ?? "",
                            onPressed: onButtonPressed2,
                            spaceAtBottom: false,
                            fontSize: AppSizes.sixteen,
                          ),
                        )
                    ],
                  ),
                  if ((greyTextStart?.length ?? 0) > 0) verticalMargin,
                  if ((greyTextStart?.length ?? 0) > 0)
                    InkWellWidget(
                      onClicked: onNavigateText,
                      child: richTextWidget(
                        greyTextStart: greyTextStart,
                        greenText: greenText,
                        greyTextEnd: greyTextEnd,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ));
  }

  titleTextWidget() {}

  descriptionTextWidget() {}

  richTextWidget({
    String? greyTextStart,
    String? greenText,
    String? greyTextEnd,
  }) {
    return RichText(
      softWrap: true,
      textScaleFactor: 1,
      text: TextSpan(
        text: greyTextStart ?? '',
        style: const TextStyle(fontSize: AppSizes.fourteen, fontWeight: FontWeight.w400, color: AppColors.greyColor),
        children: <TextSpan>[
          TextSpan(
            text: greenText ?? '',
            style: const TextStyle(
                fontSize: AppSizes.fourteen, fontWeight: FontWeight.w700, color: AppColors.darkGreenColor),
          ),
          TextSpan(
              text: greyTextEnd ?? '',
              style: const TextStyle(
                  fontSize: AppSizes.fourteen, fontWeight: FontWeight.w400, color: AppColors.greyColor)),
        ],
      ),
    );
  }

  richTextWidgetCall({
    String? greyTextStart,
    String? greenText,
    String? greyTextEnd,
  }) {
    return RichText(
      softWrap: true,
      textScaleFactor: 1,
      textAlign: TextAlign.center,
      text: TextSpan(
        text: greyTextStart ?? '',
        style: TextStyle(
            height: 1.5,
            fontSize: AppSizes.fourteen,
            fontFamily: GoogleFonts.poppins().fontFamily,
            fontWeight: FontWeight.w400,
            color: AppColors.greyColor),
        children: <TextSpan>[
          TextSpan(
              text: greenText ?? '',
              style: TextStyle(
                  fontSize: AppSizes.fourteen,
                  fontWeight: FontWeight.w700,
                  fontFamily: GoogleFonts.poppins().fontFamily,
                  color: AppColors.darkGreenColor,
                  decoration: TextDecoration.underline),
              recognizer: onNavigateText1),
          TextSpan(
              text: greyTextEnd ?? '',
              style: const TextStyle(
                  fontSize: AppSizes.fourteen, fontWeight: FontWeight.w400, color: AppColors.greyColor)),
        ],
      ),
    );
  }

  final verticalMargin = const SizedBox(
    height: AppSizes.ten,
  );

  final horizontalMargin = const SizedBox(
    width: AppSizes.ten,
  );
}
