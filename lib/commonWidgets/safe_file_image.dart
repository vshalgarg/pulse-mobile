import 'dart:io';

import 'package:flutter/material.dart';

/// Local file preview that won't crash the app when bytes are missing,
/// empty, or not a decodable image ([instantiateImageCodec] failure).
class SafeImageFile extends StatelessWidget {
  const SafeImageFile({
    super.key,
    required this.file,
    this.fit,
    this.width,
    this.height,
    this.cacheWidth,
    this.cacheHeight,
    this.filterQuality = FilterQuality.low,
    this.alignment = Alignment.center,
    this.errorBuilder,
  });

  final File file;
  final BoxFit? fit;
  final double? width;
  final double? height;
  final int? cacheWidth;
  final int? cacheHeight;
  final FilterQuality filterQuality;
  final Alignment alignment;

  /// If null, a small broken-image icon is shown.
  final ImageErrorWidgetBuilder? errorBuilder;

  Widget _brokenIcon() {
    final double s = width != null && height != null
        ? (width! < height! ? width! * 0.45 : height! * 0.45)
        : 24.0;
    return Icon(Icons.broken_image_outlined, size: s, color: Colors.grey);
  }

  Widget _error(BuildContext context, Object error, StackTrace? stackTrace) {
    if (errorBuilder != null) {
      return errorBuilder!(context, error, stackTrace);
    }
    return _brokenIcon();
  }

  @override
  Widget build(BuildContext context) {
    try {
      if (!file.existsSync()) {
        return _error(context, StateError('File missing'), null);
      }
      if (file.lengthSync() == 0) {
        return _error(context, StateError('Empty file'), null);
      }
    } catch (e) {
      return _error(context, e, StackTrace.current);
    }

    return Image.file(
      file,
      fit: fit,
      width: width,
      height: height,
      cacheWidth: cacheWidth,
      cacheHeight: cacheHeight,
      filterQuality: filterQuality,
      alignment: alignment,
      errorBuilder: (ctx, err, st) => _error(ctx, err, st),
    );
  }
}
