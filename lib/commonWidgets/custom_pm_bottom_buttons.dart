import 'package:app/commonWidgets/loader_widget.dart';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/constants_methods.dart';
import 'custom_buttons/arrow_botton.dart';

class CustomPMBottomButtons extends StatelessWidget {
  final String leftButtonText;
  final String rightButtonText;
  final VoidCallback onLeftButtonPressed;
  final VoidCallback onRightButtonPressed;
  final bool isLoading;
  final String? errorMessage;

  const CustomPMBottomButtons({
    super.key,
    required this.leftButtonText,
    required this.rightButtonText,
    required this.onLeftButtonPressed,
    required this.onRightButtonPressed,
    this.isLoading = false,
    this.errorMessage,
  });

  @override
  Widget build(BuildContext context) {
    // Don't show buttons if loading or has error
    if (isLoading || errorMessage != null) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(color: Colors.transparent),
      child: Row(
        children: [
          Expanded(
            child: ArrowButton(
              text: leftButtonText,
              isLeftArrow: true,
              backgroundColor: AppColors.buttonColorBackBg,
              textColor: AppColors.buttonColorTextBg,
              onPressed: onLeftButtonPressed,
            ),
          ),
          getWidth(14),
          Expanded(
            child: ArrowButton(
              text: rightButtonText,
              isLeftArrow: false,
              backgroundColor: AppColors.buttonColorBg,
              textColor: AppColors.buttonColorSite,

              onPressed: () async {
                LoaderWidget.showLoader(context);
                try {
                  onRightButtonPressed();
                } finally {
                  LoaderWidget.hideLoader();
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
