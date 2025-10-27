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
      print('⚠️ _checkAuthenticationStatus: Not mounted or already navigated');
      return;
    }

    final authCubit = context.read<AuthCubit>();

    print('🔍 SplashScreen: Checking authentication status');
    print('   isLoggedIn: ${authCubit.isLoggedIn}');
    print('   rememberMe: ${authCubit.getRememberMe}');
    print('   currentState: ${authCubit.state}');

    if (authCubit.isLoggedIn) {
      // User is already logged in, go to pulse dashboard
      print('✅ User is logged in, navigating to PulseDashboard');
      _hasNavigated = true;
      pushAndRemoveUntilPage(context, const PulseDashboard());
    } else if (authCubit.getRememberMe) {
      // Try auto-login if remember me is enabled
      print('🔄 Remember me is enabled, attempting auto-login');
      pushAndRemoveUntilPage(context, const LoginScreen());
      _hasNavigated = true;
    } else {
      // No stored credentials, go to welcome screen
      print('ℹ️ No credentials stored, navigating to WelcomeScreen');
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
          print(
            '🔔 SplashScreen BlocListener: state=$state, hasNavigated=$_hasNavigated',
          );

          if (state is AuthSuccess) {
            // Auto-login successful, navigate to pulse dashboard
            print('✅ AuthSuccess detected, navigating to PulseDashboard');
            _hasNavigated = true;
            pushAndRemoveUntilPage(context, const PulseDashboard());
          } else if (state is AuthFailure) {
            // Auto-login failed, navigate to welcome
            print('❌ AuthFailure detected, navigating to WelcomeScreen');
            _hasNavigated = true;
            pushAndRemoveUntilPage(context, const WelcomeScreen());
          } else if (state is AuthInitial) {
            // Initial state - this is normal after logout
            print('ℹ️ AuthInitial detected - user logged out');
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
