import 'package:app/bloc/login_bloc/auth_cubit.dart';
import 'package:app/constants/constants_methods.dart';
import 'package:app/screens/login_screen.dart';
import 'package:app/screens/pulse_dashboard.dart';
import 'package:app/screens/welcome_screen.dart';
import 'package:app/utils/toastbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lottie/lottie.dart';
import 'package:flutter/services.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    );

    _checkAuthenticationStatus();
  }

  void _checkAuthenticationStatus() async {
    // Wait for animation to complete
    await Future.delayed(const Duration(seconds: 3));

    if (!mounted || _hasNavigated) {

      return;
    }

    final authCubit = context.read<AuthCubit>();

    if (authCubit.isLoggedIn) {
      // User is already logged in, go to pulse dashboard

      _hasNavigated = true;
      pushAndRemoveUntilPage(context, const PulseDashboard());
    } else if (authCubit.getRememberMe) {
      // Try auto-login if remember me is enabled

      pushAndRemoveUntilPage(context, const LoginScreen());
      _hasNavigated = true;
    } else {
      // No stored credentials, go to welcome screen

      _hasNavigated = true;
      pushAndRemoveUntilPage(context, const WelcomeScreen());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: BlocListener<AuthCubit, AuthState>(
        listener: (context, state) {
          // Only navigate if we haven't already navigated
          if (_hasNavigated) return;

          // Debug logging

          if (state is AuthSuccess) {
            // Auto-login successful, navigate to pulse dashboard

            _hasNavigated = true;
            pushAndRemoveUntilPage(context, const PulseDashboard());
          } else if (state is AuthFailure) {
            // Auto-login failed, navigate to welcome

            _hasNavigated = true;
            pushAndRemoveUntilPage(context, const WelcomeScreen());
          } else if (state is AuthInitial) {
            // Initial state - this is normal after logout

            // Don't navigate here, let _checkAuthenticationStatus handle it
          }
        },
        child: Center(
          child: Lottie.asset(
            'assets/lottie/both.json',
            controller: _controller,
            onLoaded: (composition) {
              _controller
                ..duration = composition.duration
                ..forward();
            },
            width: 300,
            height: 300,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}
