import 'package:app/bloc/login_bloc/auth_cubit.dart';
import 'package:app/constants/constants_methods.dart';
import 'package:app/screens/home_screen.dart';
import 'package:app/screens/welcome_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lottie/lottie.dart';
import 'package:flutter/services.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

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
    
    final authCubit = context.read<AuthCubit>();
    
    if (authCubit.isLoggedIn) {
      // User is already logged in, go to home screen
      pushReplacementPage(context, const HomeScreen());
    } else if (authCubit.getRememberMe) {
      // Try auto-login if remember me is enabled
      await authCubit.autoLogin();
      
      // Check if auto-login was successful
      if (authCubit.isLoggedIn) {
        pushReplacementPage(context, const HomeScreen());
      } else {
        pushReplacementPage(context, const WelcomeScreen());
      }
    } else {
      // No stored credentials, go to welcome screen
      pushReplacementPage(context, const WelcomeScreen());
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
          if (state is AuthSuccess) {
            // Auto-login successful, navigate to home
            pushReplacementPage(context, const HomeScreen());
          } else if (state is AuthFailure) {
            // Auto-login failed, navigate to welcome
            pushReplacementPage(context, const WelcomeScreen());
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
