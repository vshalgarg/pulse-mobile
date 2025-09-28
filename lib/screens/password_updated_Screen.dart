import 'package:app/screens/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

import '../commonWidgets/custom_buttons/custom_rounded_button.dart';
import '../constants/app_colors.dart';
import '../constants/app_images.dart';
import '../constants/constants_methods.dart';
import '../constants/constants_strings.dart';

class PasswordUpdatedScreen extends StatefulWidget {
  const PasswordUpdatedScreen({super.key});

  @override
  State<PasswordUpdatedScreen> createState() => _PasswordUpdatedScreenState();
}

class _PasswordUpdatedScreenState extends State<PasswordUpdatedScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryBlue,
      body: Stack(
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
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                pulseContainer(),
                const SizedBox(height: 10),
                const Text(
                  "PASSWORD UPDATED SUCCESSFULLY!",
                  style: TextStyle(
                    color: AppColors.textWhite,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    fontFamily: poppins,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  "You can now log in with your new password.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.white,
                    fontSize: 16,
                    fontFamily: poppins,
                  ),
                ),
                const SizedBox(height: 30),
                CustomButton(
                  text: "GO TO LOGIN",
                  color: AppColors.blue,
                  width: 150,
                  onPressed: () {
                    pushReplacementPage(context, LoginScreen());
                    // if (formKey.currentState!.validate()) {
                    //   debugPrint("Email entered: ${emailController.text}");
                    // }else{
                    //   pushPage(context, ResetPasswordScreen());
                    // }
                  },
                ),

              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget pulseContainer() {
    return Image.asset(AppImages.pulseImg);
  }
}
