import 'package:flutter/material.dart';
import 'package:pinput/pinput.dart';

import '../constants/app_colors.dart';
import '../constants/app_sizes.dart';

class PinInputTextFormFieldUpdateWidget extends StatelessWidget {
  final int pinLength;
  final bool? isMasked;
  final bool? autofocus;
  final FocusNode? focusNode;
  final Function(String?)? onSubmitted;
  final Function(String) onChanged;
  final Function(String?)? onCompleted;
  final String? Function(String?)? validator;
  final TextInputType keyboardType;
  final TextEditingController? controller;
  final Key? onKey;
  final double? verticalPadding;
  final double? horizontalPadding;
  final bool? isValidOtp;
  final void Function()? onTap;
  final bool enabled;

  const PinInputTextFormFieldUpdateWidget({
    this.focusNode,
    this.isMasked,
    this.autofocus,
    this.pinLength = 6,
    this.validator,
    required this.keyboardType,
    this.onSubmitted,
    required this.onChanged,
    this.onCompleted,
    this.controller,
    this.onKey,
    this.verticalPadding,
    this.horizontalPadding,
    this.isValidOtp,
    this.onTap,
    this.enabled = true,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: verticalPadding ?? AppSizes.eight,
        horizontal: horizontalPadding ?? AppSizes.ten,
      ),
      child: Pinput(
        enabled: enabled,
        length: pinLength,
        controller: controller,
        defaultPinTheme: defaultPinTheme,
        focusedPinTheme: focusedPinTheme,
        submittedPinTheme: !(isValidOtp ?? false) ? submittedPinTheme : errorPinTheme,
        keyboardType: keyboardType,
        hapticFeedbackType: HapticFeedbackType.lightImpact,
        obscuringCharacter: '*',
        obscureText: false,
        //obscureText: isMasked??false,
        //androidSmsAutofillMethod: AndroidSmsAutofillMethod.smsRetrieverApi,
        validator: validator,
        pinputAutovalidateMode: PinputAutovalidateMode.onSubmit,
        showCursor: true,
        onCompleted: onCompleted,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        disabledPinTheme: disabledPinTheme,
        onTap: onTap,
        separatorBuilder: (index) => const SizedBox(width: 20),

      ),
    );
  }
}

final defaultPinTheme = PinTheme(
  width: AppSizes.fifty,
  height: AppSizes.fifty,
  // padding: EdgeInsets.only(left: 10, right: 10),
  textStyle: const TextStyle(fontSize: AppSizes.twenty, color: AppColors.white, fontWeight: FontWeight.w600),
  decoration: BoxDecoration(
    // border: Border.all(color: Colors.blue),
    borderRadius: BorderRadius.circular(AppSizes.ten),
    color: AppColors.blue14

  ),
);

final disabledPinTheme = defaultPinTheme.copyDecorationWith(
  border: Border.all(color: AppColors.redColor),
  borderRadius: BorderRadius.circular(AppSizes.eight),
  // color: Colors.blue,
);

final focusedPinTheme = defaultPinTheme.copyDecorationWith(
  border: Border.all(color: Colors.blue),
  borderRadius: BorderRadius.circular(AppSizes.eight),
);

final errorPinTheme = defaultPinTheme.copyDecorationWith(
  border: Border.all(color: AppColors.redColor),
  borderRadius: BorderRadius.circular(AppSizes.eight),
);

final submittedPinTheme = defaultPinTheme.copyWith(
  decoration: defaultPinTheme.decoration!.copyWith(
    border: Border.all(color: Colors.blue),
    color: AppColors.blue14,
  ),
);
