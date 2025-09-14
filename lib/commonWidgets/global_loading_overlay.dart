import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:async';
import '../bloc/global_loading_cubit.dart';
import '../constants/app_colors.dart';

class GlobalLoadingOverlay extends StatefulWidget {
  final Widget child;

  const GlobalLoadingOverlay({
    super.key,
    required this.child,
  });

  @override
  State<GlobalLoadingOverlay> createState() => _GlobalLoadingOverlayState();
}

class _GlobalLoadingOverlayState extends State<GlobalLoadingOverlay> {
  Timer? _debounceTimer;
  bool _isLoading = false;
  String _loadingMessage = 'Loading...';

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _handleLoadingState(GlobalLoadingState state) {
    _debounceTimer?.cancel();
    
    if (state is GlobalLoadingShow) {
      // Debounce showing loading to prevent rapid state changes
      _debounceTimer = Timer(const Duration(milliseconds: 50), () {
        if (mounted) {
          setState(() {
            _isLoading = true;
            _loadingMessage = state.message;
          });
        }
      });
    } else if (state is GlobalLoadingHide) {
      // Debounce hiding loading to prevent rapid state changes
      _debounceTimer = Timer(const Duration(milliseconds: 50), () {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<GlobalLoadingCubit, GlobalLoadingState>(
      listener: (context, state) {
        _handleLoadingState(state);
      },
      child: Stack(
        children: [
          widget.child,
          if (_isLoading) _buildLoadingOverlay(context, _loadingMessage),
        ],
      ),
    );
  }

  Widget _buildLoadingOverlay(BuildContext context, String message) {
    return Container(
      color: Colors.black.withOpacity(0.5),
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 40),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryGreen),
                strokeWidth: 3,
              ),
              const SizedBox(height: 16),
              Text(
                message,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
