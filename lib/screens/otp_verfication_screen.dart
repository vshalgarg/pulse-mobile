import 'dart:async';

import 'package:app/bloc/otp_verification_cubit.dart';
import 'package:app/constants/app_images.dart';
import 'package:app/screens/forgot_password_screen.dart';
import 'package:app/screens/reset_password_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';

import '../../../constants/app_colors.dart';
import '../../../constants/app_sizes.dart';

import '../../commonWidgets/pin_input_text_form_field_update.dart';

import '../../constants/constants_methods.dart';
import '../../constants/constants_strings.dart';
import '../commonWidgets/custom_buttons/custom_rounded_button.dart';
import '../commonWidgets/custom_buttons/custom_text_button.dart';
import 'login_screen.dart';
import 'package:app/commonWidgets/safe_svg_picture.dart';

Timer? _globalResendTimer;
int _globalRemainingSeconds = 60;
bool _globalTimerRunning = false;
DateTime? _globalTimerStartTime;

class EnterVerificationCodeScreen extends StatefulWidget {
  final String? email;

  const EnterVerificationCodeScreen({super.key, this.email});

  @override
  State<EnterVerificationCodeScreen> createState() =>
      _EnterVerificationCodeScreenState();
}

class _EnterVerificationCodeScreenState
    extends State<EnterVerificationCodeScreen> {
  final TextEditingController pinTextEditingController =
      TextEditingController();

  bool isOtpCodeValid = false;
  bool _isResendCode = false;
  bool _showErrorText = false;
  bool _showResendOtpWidget = false;
  String _errorMessage = '';
  Timer? _maskingTimer;

  @override
  void initState() {
    super.initState();
    isOtpCodeValid = false;
    _ensureTimerState();

    Timer.periodic(const Duration(seconds: 10), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      // Only check if timer should be running but isn't
      if (_isResendCode && _globalTimerRunning && _globalResendTimer == null) {
        // _logTimerState('Health Check - Timer Issue Detected');
        _ensureTimerState();
      }
    });
  }

  // void _logTimerState(String context) {
  // }

  void _resetTimerState() {
    _globalResendTimer?.cancel();
    _globalTimerRunning = false;
    // _timerStartedThisSession = false; // This flag is no longer needed
    setState(() {
      _isResendCode = false;
      _globalRemainingSeconds = 0;
    });
  }

  void _stopTimer() {
    _globalResendTimer?.cancel();
    _globalTimerRunning = false;
    setState(() {
      _isResendCode = false;
      _globalRemainingSeconds = 0;
    });
  }

  void _ensureTimerState() {
    // If timer should be running but isn't, restart it
    if (_isResendCode &&
        _globalResendTimer == null &&
        _globalTimerRunning &&
        _globalTimerStartTime != null) {
      final currentTime = DateTime.now();
      final elapsedSeconds = currentTime
          .difference(_globalTimerStartTime!)
          .inSeconds;

      if (elapsedSeconds < 60) {
        _globalRemainingSeconds = 60 - elapsedSeconds;

        _startTimer();
      } else {
        // Timer should have finished

        _resetTimerState();
      }
    }
  }

  @override
  void dispose() {
    _globalResendTimer?.cancel();
    _maskingTimer?.cancel();
    _globalTimerRunning = false;
    super.dispose();
  }

  void updateValue(bool isVisible) {
    isOtpCodeValid = isVisible;
  }

  void _showError(String message) {
    setState(() {
      _showErrorText = true;
      _errorMessage = message;
    });
  }

  void _hideError() {
    setState(() {
      _showErrorText = false;
      _errorMessage = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryBlue,
      body: BlocListener<OtpVerificationCubit, OtpVerificationState>(
        listener: (context, state) {
          if (state is OtpVerificationSuccess) {
            _hideError();
            showCustomToast(context, 'OTP verified successfully!');
            pushPage(context, ResetPasswordScreen(email: widget.email));
          } else if (state is OtpVerificationFailure) {
            _showError(state.errorMessage);
            showCustomToast(context, state.errorMessage);
          } else if (state is ResendOtpSuccess) {
            showCustomToast(context, state.forgotPasswordModel.message);
            pinTextEditingController.clear();
            _hideError();
            _startTimer();
            // _logTimerState('After API Success');
          } else if (state is ResendOtpFailure) {
            showCustomToast(context, state.errorMessage);
            // _logTimerState('API Failure');

          }
        },
        child: BlocBuilder<OtpVerificationCubit, OtpVerificationState>(
          builder: (context, state) {
            return Stack(
              children: [
                // Background
                Positioned.fill(
                  child: SafeSvgPicture.asset(
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
                              "We've sent a 6-digit OTP to your registered email.",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppColors.white,
                                fontSize: 16,
                                fontFamily: fontFamilyInter,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              widget.email ?? "John@gmail.com",
                              // Use passed email or fallback
                              style: const TextStyle(
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
                            const SizedBox(height: 15),
                            _buildView(context),
                            const SizedBox(height: 30),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                // Loading overlay
                if (state is OtpVerificationLoading)
                  Container(
                    color: Colors.black.withOpacity(0.3),
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primaryGreen,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildView(BuildContext context) {
    return Column(
      children: [
        _buildPinInputTextFormFieldExample(context),
        // Error text widget
        if (_showErrorText) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.errorColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.errorColor.withOpacity(0.3)),
            ),
            child: Text(
              _errorMessage,
              style: const TextStyle(
                color: AppColors.errorColor,
                fontSize: 14,
                fontWeight: FontWeight.w500,
                fontFamily: fontFamilyInter,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
        const SizedBox(height: 20),
        _buildButton(),
        const SizedBox(height: 20),
        resendOtpWidget(),
      ],
    );
  }

  Widget pulseContainer() {
    return Image.asset(AppImages.pulseImg);
  }

  Widget alreadyRemember() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          "Not your email ?",
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
            pushReplacementPage(context, const ForgotPasswordScreen());
          },
        ),
        // const Text(
        //   ")",
        //   style: TextStyle(
        //     color: AppColors.textWhite,
        //     fontSize: 16,
        //     fontWeight: FontWeight.w700,
        //     fontFamily: fontFamilyInter,
        //   ),
        // ),
      ],
    );
  }

  //Let's get started
  Widget _buildButton() => Builder(
    builder: (context) =>
        BlocBuilder<OtpVerificationCubit, OtpVerificationState>(
          builder: (context, state) {
            return CustomButton(
              text: "VERIFY OTP",
              color: AppColors.primaryGreen,
              width: 150,
              onPressed: state is OtpVerificationLoading
                  ? () {}
                  : () async {
                      final otp = pinTextEditingController.text.trim();

                      _hideError();

                      if (otp.isEmpty) {
                        _showError('Please enter the OTP code');
                      } else if (otp.length < 6) {
                        _showError('Please enter a valid 6-digit OTP');
                      } else {
                        // Call the OTP verification API
                        context.read<OtpVerificationCubit>().verifyOtp(
                          emailId: widget.email ?? "",
                          otp: otp,
                        );
                      }
                    },
            );
          },
        ),
  );

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
                pinTextEditingController.clear();
                _hideError();
                context.read<OtpVerificationCubit>().resendOtp(
                  emailId: widget.email ?? "",
                );
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
            if (_isResendCode)
              Text(
                ' (${(_globalRemainingSeconds ~/ 60).toString()}:${(_globalRemainingSeconds % 60).toString().padLeft(2, '0')})',
                style: const TextStyle(
                  color: AppColors.greyColor,
                  fontSize: AppSizes.sixteen,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
      ),
    ],
  );

  void _startTimer() {
    _globalResendTimer?.cancel();

    // Set initial state
    _globalTimerStartTime = DateTime.now();
    _globalRemainingSeconds = 60;
    _globalTimerRunning = true;

    setState(() {
      _isResendCode = true;
    });

    // Start new timer with simple countdown
    _globalResendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || !_globalTimerRunning) {
        timer.cancel();
        return;
      }

      _globalRemainingSeconds--;

      if (_globalRemainingSeconds <= 0) {
        _globalTimerRunning = false;
        timer.cancel();

        if (mounted) {
          setState(() {
            _isResendCode = false;
            _globalRemainingSeconds = 0;
          });
        }
      } else {
        // Update UI every second
        if (mounted) {
          setState(() {
            // Force UI update
          });
        }
      }
    });
  }

  //Create a pin code text input field common widget
  _buildPinInputTextFormFieldExample(BuildContext context) {
    return PinInputTextFormFieldUpdateWidget(
      enabled: true,
      isMasked: false,
      pinLength: 6,
      verticalPadding: 0,
      isValidOtp: !_showErrorText,
      onChanged: (pin) {
        if (!mounted) return;
        if (_showErrorText) {
          _hideError();
        }
        kDebugPrint('onChanged execute. pin:$pin');
      },
      keyboardType: TextInputType.number,
      onSubmitted: (pin) {
        kDebugPrint('onSubmitted pin:$pin');
      },
      controller: pinTextEditingController,
      validator: (pin) {
        if (pin!.isEmpty) {
          return 'OTP code is empty.';
        } else if (pin.length < 6) {
          return 'Please enter a valid 6-digit OTP.';
        }
        return null;
      },
      onCompleted: (pin) {
        kDebugPrint('onCompleted pin:$pin');
      },
      onTap: () async {
        if (!mounted) return;
        await Future.delayed(const Duration(milliseconds: 800));
        kDebugPrint("clicked on password field");
      },
    );
  }
}
