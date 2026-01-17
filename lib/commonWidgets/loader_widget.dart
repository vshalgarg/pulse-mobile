import 'package:flutter/material.dart';
import 'package:app/constants/app_colors.dart';

class LoaderWidget {
  static OverlayEntry? _overlayEntry;
  static bool _isShowing = false;

  /// Show loader overlay
  static void showLoader(BuildContext context) {
    if (_isShowing) return;

    _isShowing = true;
    _overlayEntry = OverlayEntry(
      builder: (context) => const _LoaderOverlay(),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  /// Hide loader overlay
  static void hideLoader() {
    if (!_isShowing || _overlayEntry == null) return;

    _overlayEntry!.remove();
    _overlayEntry = null;
    _isShowing = false;
  }

  /// Check if loader is currently showing
  static bool get isShowing => _isShowing;
}

class _LoaderOverlay extends StatelessWidget {
  const _LoaderOverlay();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withOpacity(0.5),
      child: Center(
        child: Container(
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
          child: const SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryGreen),
            ),
          ),
        ),
      ),
    );
  }
}

/// Alternative loader widget for inline usage
class InlineLoader extends StatelessWidget {
  final double? size;
  final Color? color;

  const InlineLoader({
    super.key,
    this.size,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: size ?? 40,
        height: size ?? 40,
        child: CircularProgressIndicator(
          strokeWidth: 3,
          valueColor: AlwaysStoppedAnimation<Color>(
            color ?? AppColors.primaryGreen,
          ),
        ),
      ),
    );
  }
}

/// Full screen loader widget
class FullScreenLoader extends StatelessWidget {
  final Widget? child;

  const FullScreenLoader({
    super.key,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 50,
              height: 50,
              child: CircularProgressIndicator(
                strokeWidth: 4,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryGreen),
              ),
            ),
            if (child != null) ...[
              const SizedBox(height: 24),
              child!,
            ],
          ],
        ),
      ),
    );
  }
}
