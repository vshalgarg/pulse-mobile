import 'package:app/commonWidgets/custom_buttons/custom_text_button.dart';
import 'package:app/constants/constants_methods.dart';
import 'package:app/constants/constants_strings.dart';
import 'package:app/screens/forgot_password_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import '../commonWidgets/custom_buttons/custom_rounded_button.dart';
import '../commonWidgets/text_form_field_widget.dart';
import '../constants/app_colors.dart';
import '../constants/app_images.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool isVal = false;
  final formKey = GlobalKey<FormState>();
  final TextEditingController phoneController = TextEditingController();
  TextEditingController passwordController = TextEditingController();
  bool obscureText = true;

  @override
  void dispose() {
    phoneController.dispose();
    passwordController.dispose();
    super.dispose();
  }

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
                    const Text(
                      "LOGIN TO",
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
                      "Empowering energy and connectivity — securely and sustainably.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textWhite70,
                        fontSize: 16,
                        fontFamily: poppins,
                        fontWeight: FontWeight.w400,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 30),
                    mobileNumberField(),
                    const SizedBox(height: 10),
                    passwordField(),
                    const SizedBox(height: 20),
                    checkboxText(),
                    const SizedBox(height: 40),
                    CustomButton(
                      text: "LOGIN",
                      color: AppColors.primaryGreen,
                      width: 200,
                      onPressed: _submitForm,
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

  String? _validatePhoneNumber(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your phone number';
    }
    if (value.length != 10 || !RegExp(r'^[0-9]+$').hasMatch(value)) {
      return 'Please enter a valid 10-digit phone number';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your password';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters long';
    }
    return null;
  }

  void _submitForm() {
    if (formKey.currentState?.validate() ?? false) {
      print('Phone: ${phoneController.text}');
      print('Remember me: $isVal');
      // Add your login logic here
    }
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
              "Mobile No ",
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
        const SizedBox(height: 15),
        TextFormFieldWidget(
          controller: phoneController,
          hintText: "Enter your phone number",
          keyboardType: TextInputType.phone,
          validator: _validatePhoneNumber,
          onChanged: (value) {
            setState(() {});
          },
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(10),
          ],
        ),
      ],
    );
  }

  Widget passwordField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: const [
                Text(
                  "Password ",
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
            CustomTextButton(title: "Forgot Password?", onButtonPressed: () {
              pushPage(context, ForgotPasswordScreen());
            }),
          ],
        ),
        TextFormFieldWidget(
          controller: passwordController,
          hintText: "Enter your password",
          obscureText: obscureText,
          validator: _validatePassword,
          onChanged: (value) {
            setState(() {});
          },
          suffixIcon: IconButton(
            icon: Icon(
              obscureText ? Icons.visibility_off : Icons.visibility,
              color: AppColors.greyColor,
            ),
            onPressed: () {
              setState(() {
                obscureText = !obscureText;
              });
            },
          ),
        ),
      ],
    );
  }

  Widget checkboxText() {
    return Row(
      children: [
        Theme(
          data: ThemeData(unselectedWidgetColor: AppColors.white),
          child: Checkbox(
            value: isVal,
            onChanged: (value) {
              isVal = !isVal;
              setState(() {});
            },
            // shape: RoundedRectangleBorder(
            //   borderRadius: BorderRadius.circular(5),
            // ),
            activeColor: AppColors.checkboxActive,
            checkColor: AppColors.checkboxCheck,
          ),
        ),
        const Text(
          "Remember me on this device.",
          style: TextStyle(
            color: AppColors.textWhite,
            fontFamily: fontFamilyInter,
            fontWeight: FontWeight.w400,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}
