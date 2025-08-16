import 'package:app/screens/login_screen.dart';
import 'package:app/screens/otp_verfication_screen.dart';
import 'package:app/screens/reset_password_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

import '../commonWidgets/custom_buttons/custom_rounded_button.dart';
import '../commonWidgets/custom_buttons/custom_text_button.dart';
import '../commonWidgets/text_form_field_widget.dart';
import '../constants/app_colors.dart';
import '../constants/app_images.dart';
import '../constants/constants_methods.dart';
import '../constants/constants_strings.dart';

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
      body: Form(
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
                      "FORGOT YOU PASSWORD?",
                      style: TextStyle(
                        color: AppColors.textWhite,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        fontFamily: poppins,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      "Create a strong password to protect your NexGen account.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.white,
                        fontSize: 16,
                        fontFamily: poppins,
                        // fontWeight: FontWeight.w100,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 30),
                    mobileNumberField(),
                    const SizedBox(height: 10),
                    alreadyRemember(),
                    const SizedBox(height: 30),
                    CustomButton(
                      text: "SEND OTP",
                      color: AppColors.blue,
                      width: 150,
                      onPressed: () {
                        if (formKey.currentState!.validate()) {
                          debugPrint("Email entered: ${emailController.text}");
                        }else{
                          pushPage(context, EnterVerificationCodeScreen());
                        }
                      },
                    ),

                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  Widget pulseContainer() {
    return SvgPicture.asset(AppImages.pulseImg, fit: BoxFit.cover);
  }

  Widget mobileNumberField() {
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
    return  Row(
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
        CustomTextButton(title: "Go back to login",
            decoration:  true,
            onButtonPressed: () {
          pushPage(context, const LoginScreen());
        }),
      ],
    );
  }
}
