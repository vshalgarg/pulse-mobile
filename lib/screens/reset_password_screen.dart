import 'package:app/bloc/reset_password_cubit.dart';
import 'package:app/constants/constants_methods.dart';
import 'package:app/routes/routes.dart';
import 'package:app/screens/password_updated_Screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';

import '../commonWidgets/custom_buttons/custom_rounded_button.dart';
import '../commonWidgets/text_form_field_widget.dart';
import '../constants/app_colors.dart';
import '../constants/app_images.dart';
import '../constants/constants_strings.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String? email;
  
  const ResetPasswordScreen({super.key, this.email});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final formKey = GlobalKey<FormState>();
  final TextEditingController newPassController = TextEditingController();
  final TextEditingController confirmPassController = TextEditingController();

  bool obscureNewPass = true;
  bool obscureConfirmPass = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryBlue,
      body: BlocListener<ResetPasswordCubit, ResetPasswordState>(
        listener: (context, state) {
          if (state is ResetPasswordSuccess) {
            showCustomToast(context, 'Password reset successfully!');
            pushReplacementPage(context, const PasswordUpdatedScreen());
          } else if (state is ResetPasswordFailure) {
            showCustomToast(context, state.errorMessage);
          }
        },
        child: BlocBuilder<ResetPasswordCubit, ResetPasswordState>(
          builder: (context, state) {
            return Stack(
              children: [
                Form(
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
                      Center(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                "SET A NEW PASSWORD",
                                style: TextStyle(
                                  color: AppColors.textWhite,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: poppins,
                                ),
                              ),
                              const SizedBox(height: 10),
                              pulseContainer(),
                              const SizedBox(height: 20),
                              Text(
                                "Create a strong password to protect your NexGen account.",
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: AppColors.white,
                                  fontSize: 16,
                                  fontFamily: poppins,
                                  fontWeight: FontWeight.w100,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                              const SizedBox(height: 30),

                              // New Password
                              passwordField(
                                label: "New Password",
                                controller: newPassController,
                                obscureText: obscureNewPass,
                                onToggle: () {
                                  setState(() {
                                    obscureNewPass = !obscureNewPass;
                                  });
                                },
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return "Please enter your new password";
                                  }
                                  if (value.trim().length < 6) {
                                    return "Password must be at least 6 characters";
                                  }
                                  return null;
                                },
                              ),

                              const SizedBox(height: 20),

                              // Confirm Password
                              passwordField(
                                label: "Confirm Password",
                                controller: confirmPassController,
                                obscureText: obscureConfirmPass,
                                onToggle: () {
                                  setState(() {
                                    obscureConfirmPass = !obscureConfirmPass;
                                  });
                                },
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return "Please confirm your password";
                                  }
                                  if (value.trim() != newPassController.text.trim()) {
                                    return "Passwords do not match";
                                  }
                                  return null;
                                },
                              ),

                              const SizedBox(height: 30),

                              CustomButton(
                                text: "RESET PASSWORD",
                                color: AppColors.primaryGreen,
                                width: 200,
                                onPressed: state is ResetPasswordLoading ? () {} : _submitForm,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Loading overlay
                if (state is ResetPasswordLoading)
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

  void _submitForm() {
    if (formKey.currentState!.validate()) {
      context.read<ResetPasswordCubit>().resetPassword(
        emailId: widget.email ?? "",
        newPassword: newPassController.text.trim(),
      );
    }
  }

  Widget pulseContainer() {
    return SvgPicture.asset(AppImages.pulseImg, fit: BoxFit.cover);
  }

  Widget passwordField({
    required String label,
    required TextEditingController controller,
    required bool obscureText,
    required VoidCallback onToggle,
    required String? Function(String?) validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textWhite,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                fontFamily: fontFamilyInter,
              ),
            ),
            const Text(
              " *",
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
          controller: controller,
          hintText: "Enter $label",
          obscureText: obscureText,
          keyboardType: TextInputType.visiblePassword,
          onChanged: (value) {
            setState(() {});
          },
          suffixIcon: IconButton(
            icon: Icon(
              obscureText ? Icons.visibility_off : Icons.visibility,
              color: AppColors.greyColor,
            ),
            onPressed: onToggle,
          ),
          validator: validator,
        ),
      ],
    );
  }
}
