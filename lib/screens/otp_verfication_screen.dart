import 'dart:async';

import 'package:app/constants/app_images.dart';
import 'package:app/routes/routes.dart';
import 'package:app/screens/forgot_password_screen.dart';
import 'package:app/screens/reset_password_screen.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

import '../../../constants/app_colors.dart';
import '../../../constants/app_sizes.dart';

import '../../commonWidgets/custom_text_widget.dart';
import '../../commonWidgets/pin_input_text_form_field_update.dart';

import '../../commonWidgets/timer.dart';
import '../../constants/constants_methods.dart';
import '../../constants/constants_strings.dart';
import '../commonWidgets/custom_buttons/custom_rounded_button.dart';
import '../commonWidgets/custom_buttons/custom_text_button.dart';
import 'login_screen.dart';

class EnterVerificationCodeScreen extends StatefulWidget {
  const EnterVerificationCodeScreen({super.key});

  @override
  State<EnterVerificationCodeScreen> createState() =>
      _EnterVerificationCodeScreenState();
}

class _EnterVerificationCodeScreenState
    extends State<EnterVerificationCodeScreen> {
  //Pin input field validation
  static const int _pinLength = 6;

  //Count timer start using seconds
  int levelClock = 90;
  GlobalKey otpCriteriakey = GlobalKey();
  ScrollController scrollController = ScrollController();
  bool _isFreeze = false;
  bool isOtpCodeValid = false;
  String currentText = "";
  String timerValue = "";
  String? otpCode = "123456";
  String? otpErrorMsg;
  final _formKey = GlobalKey<FormState>();
  late final args;
  bool isValidOtpCode = false;
  bool _isResendCode = false;
  bool _showResendOtpWidget = true;



  String purpose = '';

  TextEditingController pinTextEditingController = TextEditingController();

  Timer? _maskingTimer;
  bool _isMasked = false;

  @override
  void initState() {
    super.initState();
    isOtpCodeValid = false;
  }

  void startMaskingTimer() {
    const maskingDelay = Duration(milliseconds: 800);
    _maskingTimer = Timer(maskingDelay, () {
      setState(() {
        _isMasked = true;
      });
    });
  }

  void updateValue(bool isVisible) {
    isOtpCodeValid = isVisible;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryBlue,
      body: Stack(
        children: [
          // Background
          Positioned.fill(
            child: SvgPicture.asset(
              AppImages.loginBackground,
              fit: BoxFit.cover,
            ),
          ),
          SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: MediaQuery.of(context).size.height,
              ),
              child: IntrinsicHeight(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      getHeight(100),
                      const Text(
                        "VERIFY YOUR OTP",
                        style: TextStyle(
                          color: AppColors.textWhite,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          fontFamily: poppins,
                        ),
                      ),
                      const SizedBox(height: 10),
                      pulseContainer(),
                      const SizedBox(height: 10),
                      Text(
                        "No worries. We'll help you reset it and get back online.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.white,
                          fontSize: 16,
                          fontFamily: poppins,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(height: 60),
                      Text(
                        "We’ve sent a 6-digit OTP to your registered email.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.white,
                          fontSize: 16,
                          fontFamily: fontFamilyInter,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        "John@gmail.com",
                        style: TextStyle(
                          color: AppColors.textWhite,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          fontFamily: fontFamilyInter,
                        ),
                      ),
                      const SizedBox(height: 10),
                      alreadyRemember(),
                      const SizedBox(height: 10),
                      Text(
                        "Please enter it below to continue resetting your password.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.white,
                          fontSize: 16,
                          fontFamily: fontFamilyInter,
                        ),
                      ),
                      _buildView(context),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildView(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        // mainAxisAlignment: MainAxisAlignment.start,
        children: [otpWidgetScreenView(true)],
      ),
    );
  }

  otpWidgetScreenView(bool? isTablet) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        getHeight(AppSizes.forty),
        _buildPinInputTextFormFieldExample(context),
        getHeight(AppSizes.thirty),
        _showResendOtpWidget ? resendOtpWidget() : resendOtp(),
        getHeight(AppSizes.forty),
        _buildButton(),
      ],
    );
  }




  Widget pulseContainer() {
    return SvgPicture.asset(AppImages.pulseImg, fit: BoxFit.cover);
  }

  Widget alreadyRemember() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          "( Not your email ?",
          style: TextStyle(
            color: AppColors.textWhite,
            fontSize: 16,
            fontWeight: FontWeight.w700,
            fontFamily: fontFamilyInter,
          ),
        ),
        CustomTextButton(
          title: "Change email",
          padding: EdgeInsets.symmetric(horizontal: 2),
          decoration: false,
          onButtonPressed: () {
            pushPage(context, const ForgotPasswordScreen());
          },
        ),
        const Text(
          ")",
          style: TextStyle(
            color: AppColors.textWhite,
            fontSize: 16,
            fontWeight: FontWeight.w700,
            fontFamily: fontFamilyInter,
          ),
        ),
      ],
    );
  }

  //Let's get started
  Widget _buildButton() => Builder(
    builder: (context) =>
        CustomButton(
          text: "VERIFY OTP",
          color: AppColors.primaryGreen,
          width: 150,
          onPressed: () async {
            pushReplacementPage(context, ResetPasswordScreen());
          },
        ),
  );

  Widget _buildCancelButton() => Builder(
    builder: (context) => CustomButton(
      // title: 'Cancel',
      fontSize: AppSizes.sixteen,
      // isDisabled: true,
      onPressed: () async {
        Navigator.pop(context);
        if (isOtpCodeValid) {
          showSnackBar(context, "OTP Verified Successfully");
          Navigator.pop(context);
        }
      },
      text: 'Cancel',
      color: AppColors.appBarTextColor,
    ),
  );

  //Count Down Timer start
  Widget _countdownTimerStart() {
    return Countdown(
      duration: Duration(seconds: levelClock),
      onFinish: (timer) {
        timer.cancel();
        setState(() {
          _isResendCode = false; // Allow resend after timer finishes
        });
      },
      builder: (BuildContext ctx, Duration remaining) {
        return Text(
          ' (${remaining.inMinutes.remainder(60).toString()}:${remaining.inSeconds.remainder(60).toString().padLeft(2, '0')})',
          style: const TextStyle(
            color: AppColors.greyColor,
            fontSize: AppSizes.sixteen,
            fontWeight: FontWeight.w600,
          ),
        );
      },
    );
  }

  Widget resendOtpWidget() => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      GestureDetector(
        onTap: () {
          pushPage(context, const LoginScreen());
        },
        child: Text(
          "Back to Login",
          style: kTextStyle(
            context: context,
            color: AppColors.forgotColor,
            fontSize: AppSizes.sixteen,
            fontWeight: FontWeight.w400,
            fontFamily: fontFamilyInter,
          ),
        ),
      ),
      const SizedBox(width: 20),
      GestureDetector(
        onTap: !_isResendCode
            ? () {
          setState(() {
            _showResendOtpWidget = false;
            _startTimer();
          });
        }
            : null,
        child: Row(
          children: [
            Text(
              "Resend OTP",
              style: kTextStyle(
                context: context,
                color: _isResendCode
                    ? AppColors.greyColor
                    : AppColors.forgotColor,
                fontSize: AppSizes.sixteen,
                fontWeight: FontWeight.w400,
                fontFamily: fontFamilyInter,
              ),
            ),
            if (_isResendCode) _countdownTimerStart(),
          ],
        ),
      ),
    ],
  );

  Widget resendOtp() => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      GestureDetector(
        onTap: () {
          pushPage(context, const LoginScreen());
        },
        child: Text(
          "Back to Login",
          style: kTextStyle(
            context: context,
            color: AppColors.forgotColor,
            fontSize: AppSizes.sixteen,
            fontWeight: FontWeight.w400,
            fontFamily: fontFamilyInter,
          ),
        ),
      ),
      const SizedBox(width: 20),
      GestureDetector(
        onTap: !_isResendCode
            ? () {
          setState(() {
            _isResendCode = true;
            _startTimer();
          });
          pinTextEditingController.clear();
        }
            : null,
        child: Row(
          children: [
            Text(
              "Resend OTP",
              style: kTextStyle(
                context: context,
                color: _isResendCode
                    ? AppColors.greyColor
                    : AppColors.forgotColor,
                fontSize: AppSizes.sixteen,
                fontWeight: FontWeight.w400,
                fontFamily: fontFamilyInter,
              ),
            ),
            if (_isResendCode) _countdownTimerStart(),
          ],
        ),
      ),
    ],
  );


  //Invalid code visibility hide/show
  Widget _invalidCode() {
    return Visibility(
      visible: (currentText.length <= 5) ? false : !isOtpCodeValid,
      child: CustomTextWidget(
        (otpErrorMsg ?? ''),
        fontSize: AppSizes.fourteen,
        fontWeight: FontWeight.bold,
        color: AppColors.errorColor,
        textAlign: TextAlign.center,
      ),
    );
  }

  void _startTimer() {
    setState(() {
      _isResendCode = true; // Timer starts
    });
  }

  //Create a pin code text input field common widget
  _buildPinInputTextFormFieldExample(BuildContext context) {
    return PinInputTextFormFieldUpdateWidget(
      enabled: !_isFreeze,
      isMasked: _isMasked,
      key: otpCriteriakey,
      pinLength: _pinLength,
      verticalPadding: 0,
      isValidOtp: (currentText.length <= 5) ? false : !isOtpCodeValid,
      onChanged: (pin) {
        /// for masking functionality
        // int index =0;
        // kDebugPrint("index $index");
        // setState(() {
        //   _isMasked = false;
        // });
        // if (!_isMasked)  {
        //   kDebugPrint("index ${index++}");
        //   // Reset the timer every time a new character is entered
        //   kDebugPrint('timer cancel pin:$pin  ${_maskingTimer?.isActive}');
        //   _maskingTimer?.cancel();
        //    startMaskingTimer();
        //   kDebugPrint('timer start. pin:$pin  ${_maskingTimer?.isActive}');
        // }
        if (!mounted) return;
        currentText = pin;
        kDebugPrint('onChanged execute. pin:$pin');
      },
      keyboardType: TextInputType.number,
      onSubmitted: (pin) {
        kDebugPrint('onSubmitted pin:$pin');
      },
      controller: pinTextEditingController,
      validator: (pin) {
        if (pin!.isEmpty) {
          isOtpCodeValid = false;
          return 'OTP code is empty.';
        } else if (pin.length < _pinLength) {
          isOtpCodeValid = false;
          return ' Invalid or expired OTP.';
        } else if (pin != otpCode) {
          isOtpCodeValid = false;
          return ' Invalid or expired OTP.';
        } else {
          isOtpCodeValid = true;
          return ' Invalid or expired OTP.';
        }
        return null;
      },
      onCompleted: (pin) {
        if (_formKey.currentState!.validate()) {
          _formKey.currentState!.save();
          // showSnackBar(context, 'onSubmit pin:$pin');
        }
      },
      onTap: () async {
        // keyboardSubscription.onData((data) async {
        //   if (data) {}
        // });
        if (!mounted) return;
        await Future.delayed(const Duration(milliseconds: 800));
        kDebugPrint("clicked on password field");
        if (!mounted) return;
        RenderBox box =
            otpCriteriakey.currentContext!.findRenderObject() as RenderBox;
        final size = box.size;
        Offset position = box.localToGlobal(
          Offset.zero,
        ); //this is global position
        double y = position.dy; //this is y - I think it's what you want
        if (scrollController.hasClients) {
          if (getDeviceWidth(context) > 335) {
            scrollController.animateTo(
              size.height,
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeInOut,
            );
          } else {
            scrollController.animateTo(
              getDeviceHeight(context) / 2,
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeInOut,
            );
          }
        }
      },
    );
  }
}
