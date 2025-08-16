import 'package:app/commonWidgets/custom_buttons/custom_rounded_button.dart';
import 'package:app/constants/constants_methods.dart';
import 'package:app/screens/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lottie/lottie.dart';

import '../constants/app_colors.dart';
import '../constants/app_images.dart';
import '../constants/constants_strings.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    
    // Start the animation after the first frame is rendered
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryBlue,
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              AppImages.welcomeBgPng,
              fit: BoxFit.cover,
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 30),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    height: 50,
                    margin: const EdgeInsets.only(bottom: 30),
                    child: Lottie.asset(
                      'assets/lottie/pulse.json',
                      controller: _controller,
                      onLoaded: (composition) {
                        _controller
                          ..duration = composition.duration
                          ..forward();
                      },
                      fit: BoxFit.contain,
                      repeat: true,
                      animate: true,
                    ),
                  ),
                ),
                const Text(
                  "Managing Telecom, Decommission,\nInstallation & Warehouses",
                  style: TextStyle(
                    color: AppColors.textColorWelcome,
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                    fontFamily: poppins,
                  ),
                  textAlign: TextAlign.center,
                ),
                getHeight(50),
                _buildTickRow("Capture & submit site data."),
                getHeight(13),
                _buildTickRow("Get real-time approvals."),
                getHeight(13),
                _buildTickRow("Ensure quality & efficiency."),

                getHeight(48),
                CustomButton(
                  text: "LOGIN",
                  color: AppColors.primaryGreen,
                  width: double.infinity,
                  onPressed: () {
                    pushPage(context, LoginScreen());
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTickRow(String text) {
    return Row(
      children: [
        SvgPicture.asset(AppImages.tickIcon),
        getWidth(10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: AppColors.white,
              fontSize: 20,
              fontWeight: FontWeight.w400,
              fontFamily: poppins,
            ),
          ),
        ),
      ],
    );
  }
}
