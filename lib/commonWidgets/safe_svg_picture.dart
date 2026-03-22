import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Wraps [SvgPicture.asset] with an [errorBuilder] so invalid/corrupt SVG data
/// does not crash the app (vector_graphics "Bad state: Invalid SVG data").
class SafeSvgPicture extends StatelessWidget {
  const SafeSvgPicture.asset(
    this.assetName, {
    super.key,
    this.matchTextDirection = false,
    this.bundle,
    this.package,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.alignment = Alignment.center,
    this.allowDrawingOutsideViewBox = false,
    this.placeholderBuilder,
    this.semanticsLabel,
    this.excludeFromSemantics = false,
    this.clipBehavior = Clip.hardEdge,
    this.theme,
    this.colorMapper,
    this.colorFilter,
  });

  final String assetName;
  final bool matchTextDirection;
  final AssetBundle? bundle;
  final String? package;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Alignment alignment;
  final bool allowDrawingOutsideViewBox;
  final Widget Function(BuildContext)? placeholderBuilder;
  final String? semanticsLabel;
  final bool excludeFromSemantics;
  final Clip clipBehavior;
  final SvgTheme? theme;
  final ColorMapper? colorMapper;
  final ui.ColorFilter? colorFilter;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      assetName,
      matchTextDirection: matchTextDirection,
      bundle: bundle,
      package: package,
      width: width,
      height: height,
      fit: fit,
      alignment: alignment,
      allowDrawingOutsideViewBox: allowDrawingOutsideViewBox,
      placeholderBuilder: placeholderBuilder,
      semanticsLabel: semanticsLabel,
      excludeFromSemantics: excludeFromSemantics,
      clipBehavior: clipBehavior,
      theme: theme,
      colorMapper: colorMapper,
      colorFilter: colorFilter,
      errorBuilder: (ctx, error, stackTrace) {
        if (kDebugMode) {
          debugPrint('SafeSvgPicture: failed "$assetName": $error');
        }
        return _SvgDecodeFallback(width: width, height: height);
      },
    );
  }
}

/// Approximates the app background gradient from [assets/images/Home.svg].
class _SvgDecodeFallback extends StatelessWidget {
  const _SvgDecodeFallback({this.width, this.height});

  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    const decoration = BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF2C2D4D),
          Color(0xFF375D65),
          Color(0xFF4BBB94),
        ],
        stops: [0.0, 0.087, 1.0],
      ),
    );

    final w = width;
    final h = height;
    if (w != null && h != null) {
      return DecoratedBox(
        decoration: decoration,
        child: SizedBox(width: w, height: h),
      );
    }
    return const DecoratedBox(
      decoration: decoration,
      child: SizedBox.expand(),
    );
  }
}
