import 'package:app/bloc/login_bloc/auth_cubit.dart';
import 'package:app/commonWidgets/custom_buttons/custom_rounded_button.dart';
import 'package:app/commonWidgets/global_loading_widget.dart';
import 'package:app/commonWidgets/text_form_field_widget.dart';
import 'package:app/constants/app_colors.dart';
import 'package:app/constants/app_images.dart';
import 'package:app/constants/constants_methods.dart';
import 'package:app/constants/constants_strings.dart';
import 'package:app/screens/pulse_dashboard.dart';
import 'package:app/services/local_storage_db.dart';
import 'package:app/screens/forgot_password_screen.dart';
import 'package:app/screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';

import '../commonWidgets/custom_buttons/custom_text_button.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool isVal = false;
  final formKey = GlobalKey<FormState>();
  final TextEditingController mobileController = TextEditingController();
  TextEditingController passwordController = TextEditingController();
  bool obscureText = true;

  @override
  void initState() {
    super.initState();
    mobileController.addListener(_onFormChanged);
    _loadSavedCredentials();
  }

  @override
  void dispose() {
    mobileController.removeListener(_onFormChanged);
    mobileController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  void _onFormChanged() {
    setState(() {});
  }

  void _loadSavedCredentials() {
    if (LocalStorageDB.getRememberMe) {
      final savedUsername = LocalStorageDB.getUsername;
      final savedPassword = LocalStorageDB.getPassword;

      if (savedUsername != null && savedPassword != null) {
        mobileController.text = savedUsername;
        passwordController.text = savedPassword;
        isVal = true;
        setState(() {});
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryBlue,
      body: BlocListener<AuthCubit, AuthState>(
        listener: (context, state) {
          if (state is AuthSuccess) {
            // showCustomToast(context, '');
            pushReplacementPage(context, PulseDashboard());
          } else if (state is AuthFailure) {
            showCustomToast(context, state.errorMessage);
          }
        },
        child: BlocBuilder<AuthCubit, AuthState>(
          builder: (context, state) {
            return GlobalLoadingWidget(
              isLoading: state is AuthLoading,
              child: Form(
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
                    SafeArea(
                      child: SingleChildScrollView(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight:
                                MediaQuery.of(context).size.height -
                                MediaQuery.of(context).padding.top -
                                MediaQuery.of(context).padding.bottom,
                          ),
                          child: IntrinsicHeight(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const SizedBox(height: 10),
                                  pulseContainer(),
                                  const SizedBox(height: 30),
                                  Text(
                                    "Empowering connectivity and energy — securely and sustainably.",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: AppColors.textWhite70,
                                      fontSize: 16,
                                      fontFamily: poppins,
                                      fontWeight: FontWeight.w400,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                  const SizedBox(height: 60),
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
                                    onPressed: state is AuthLoading
                                        ? () {}
                                        : _submitForm,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  String? _validateMobileNumber(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your mobile number';
    }
    if (value.length != 10 || !RegExp(r'^[0-9]+$').hasMatch(value)) {
      return 'Please enter valid mobile number';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your password';
    }

    return null;
  }

  void _submitForm() {
    if (formKey.currentState?.validate() ?? false) {
      context.read<AuthCubit>().login(
        username: mobileController.text.trim(),
        password: passwordController.text,
        rememberMe: isVal,
      );
    }
  }

  Widget pulseContainer() {
    return Image.asset(AppImages.pulseImg, width: 159, height: 55);
  }

  Widget mobileNumberField() {
    // Changed from emailField
    return Column(
      children: [
        Row(
          children: const [
            Text(
              "Login ID(Email/Mobile)", // Changed from "Email "
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
          controller: mobileController,
          hintText: "Login ID(Email/Mobile)",
          keyboardType: TextInputType.text,
          
          onChanged: (value) {
            setState(() {});
          },
         
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
            CustomTextButton(
              title: "Forgot Password?",
              onButtonPressed: () {
                pushPage(context, ForgotPasswordScreen());
              },
            ),
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
