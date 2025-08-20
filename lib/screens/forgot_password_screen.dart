import 'package:app/bloc/forgot_password_cubit.dart';
import 'package:app/commonWidgets/custom_buttons/custom_rounded_button.dart';
import 'package:app/commonWidgets/custom_form_appbar.dart';
import 'package:app/commonWidgets/custom_text_widget.dart';
import 'package:app/commonWidgets/text_form_field_widget.dart';
import 'package:app/constants/app_colors.dart';
import 'package:app/constants/app_images.dart';
import 'package:app/constants/app_sizes.dart';
import 'package:app/constants/constants_methods.dart';
import 'package:app/constants/constants_strings.dart';
import 'package:app/routes/routes.dart';
import 'package:app/screens/otp_verfication_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';

import '../commonWidgets/custom_buttons/custom_text_button.dart';
import 'login_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final formKey = GlobalKey<FormState>();
  final TextEditingController emailController = TextEditingController();
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryBlue,
      body: BlocListener<ForgotPasswordCubit, ForgotPasswordState>(
        listener: (context, state) {
          if (state is ForgotPasswordSuccess) {
            showCustomToast(context, 'OTP sent successfully!');
            // Navigate to OTP verification screen with email
            pushPage(context, EnterVerificationCodeScreen(
              email: emailController.text.trim(),
            ));
          } else if (state is ForgotPasswordFailure) {
            showCustomToast(context, state.errorMessage);
          }
        },
        child: BlocBuilder<ForgotPasswordCubit, ForgotPasswordState>(
          builder: (context, state) {
            return Form(
              key: formKey,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: SvgPicture.asset(
                      AppImages.loginBackground,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                    ),
                  ),
                  // Content
                  Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          pulseContainer(),
                          const SizedBox(height: 10),
                          const Text(
                            "FORGOT YOUR PASSWORD?",
                            style: TextStyle(
                              color: AppColors.textWhite,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              fontFamily: poppins,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            "Enter your email address and we'll send you an OTP to reset your password.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.white,
                              fontSize: 16,
                              fontFamily: poppins,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                          const SizedBox(height: 30),
                          emailField(),
                          const SizedBox(height: 10),
                          alreadyRemember(),
                          const SizedBox(height: 30),
                          CustomButton(
                            text: "SEND OTP",
                            color: AppColors.blue,
                            width: 150,
                            onPressed: state is ForgotPasswordLoading ? () {} : _submitForm,
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Loading overlay
                  if (state is ForgotPasswordLoading)
                    Container(
                      color: Colors.black.withOpacity(0.3),
                      child: const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primaryGreen,
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _submitForm() {
    if (formKey.currentState?.validate() ?? false) {
      context.read<ForgotPasswordCubit>().forgotPassword(
        email: emailController.text.trim(),
      );
    }
  }

  Widget pulseContainer() {
    return SvgPicture.asset(AppImages.pulseImg, fit: BoxFit.cover);
  }

  Widget emailField() {
    return Column(
      children: [
        Row(
          children: const [
            Text(
              "Email",
              style: TextStyle(
                color: AppColors.textWhite,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                fontFamily: fontFamilyInter,
              ),
            ),
            Text(
              "*",
              style: TextStyle(
                color: Colors.red,
                fontSize: 14,
                fontWeight: FontWeight.w500,
                fontFamily: fontFamilyInter,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TextFormFieldWidget(
          controller: emailController,
          hintText: "Enter your email address",
          keyboardType: TextInputType.emailAddress,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return "Please enter your email address";
            }
            final emailRegex = RegExp(emailPattern);
            if (!emailRegex.hasMatch(value.trim())) {
              return "Please enter a valid email";
            }
            return null;
          },
          onChanged: (value) {
            setState(() {});
          },
        ),
      ],
    );
  }

  Widget alreadyRemember(){
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          "Already remembered it ?",
          style: TextStyle(
            color: AppColors.textWhite,
            fontSize: 16,
            fontWeight: FontWeight.w700,
            fontFamily: fontFamilyInter,
          ),
        ),
        CustomTextButton(
          title: "Go back to login",
          decoration: true,
          onButtonPressed: () {
            pushPage(context, const LoginScreen());
          }
        ),
      ],
    );
  }
}
