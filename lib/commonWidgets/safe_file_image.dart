import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

/// Local file preview that won't crash the app when bytes are missing,
/// empty, or not a decodable image ([instantiateImageCodec] failure).
///
/// Uses [Image.memory] after reading bytes instead of [Image.file], so we never
/// hit [FileImage._loadAsync]'s `Bad state: ... is empty` when cache/camera files
/// are truncated or race with another writer.
///
/// Bytes are **cached** in state and only reloaded when the path changes or the
/// file's size / modification time changes — avoids flicker from re-reading on
/// every parent rebuild.
class SafeImageFile extends StatefulWidget {
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

  @override
  State<SafeImageFile> createState() => _SafeImageFileState();
}

class _SafeImageFileState extends State<SafeImageFile> {
  Uint8List? _bytes;
  Object? _loadError;

  String? _loadedPath;
  DateTime? _loadedModified;
  int? _loadedSize;

  @override
  void initState() {
    super.initState();
    _loadFromDisk(notify: false);
  }

  @override
  void didUpdateWidget(SafeImageFile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.file.path != widget.file.path) {
      _loadFromDisk(notify: true);
      return;
    }
    _reloadIfFileOnDiskChanged();
  }

  /// Cheap check: only re-read bytes when the file was actually replaced/updated.
  void _reloadIfFileOnDiskChanged() {
    final f = widget.file;
    try {
      if (!f.existsSync()) {
        if (_bytes != null || _loadError == null) {
          _loadFromDisk(notify: true);
        }
        return;
      }
      final stat = f.statSync();
      if (_loadedPath != f.path ||
          _loadedSize != stat.size ||
          _loadedModified != stat.modified) {
        _loadFromDisk(notify: true);
      }
    } catch (_) {
      _loadFromDisk(notify: true);
    }
  }

  void _loadFromDisk({required bool notify}) {
    final prevBytes = _bytes;
    final prevError = _loadError;

    void apply() {
      try {
        final f = widget.file;
        if (!f.existsSync()) {
          _bytes = null;
          _loadError = StateError('File missing');
          _loadedPath = f.path;
          _loadedModified = null;
          _loadedSize = null;
          return;
        }
        final stat = f.statSync();
        final bytes = f.readAsBytesSync();
        if (bytes.isEmpty) {
          _bytes = null;
          _loadError = StateError('Empty file');
        } else {
          _bytes = bytes;
          _loadError = null;
        }
        _loadedPath = f.path;
        _loadedModified = stat.modified;
        _loadedSize = stat.size;
      } catch (e) {
        _bytes = null;
        _loadError = e;
        _loadedPath = widget.file.path;
        _loadedModified = null;
        _loadedSize = null;
      }
    }

    apply();

    // Skip repaint if nothing actually changed (reduces flicker from redundant reloads).
    if (notify &&
        mounted &&
        prevError == _loadError &&
        _bytes != null &&
        prevBytes != null &&
        prevBytes.length == _bytes!.length &&
        _listEquals(prevBytes, _bytes!)) {
      return;
    }

    if (notify && mounted) {
      setState(() {});
    }
  }

  static bool _listEquals(Uint8List a, Uint8List b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  Widget _brokenIcon() {
    final double s = widget.width != null && widget.height != null
        ? (widget.width! < widget.height!
            ? widget.width! * 0.45
            : widget.height! * 0.45)
        : 24.0;
    return Icon(Icons.broken_image_outlined, size: s, color: Colors.grey);
  }

  Widget _error(
    BuildContext context,
    Object error,
    StackTrace? stackTrace,
  ) {
    if (widget.errorBuilder != null) {
      return widget.errorBuilder!(context, error, stackTrace);
    }
    return _brokenIcon();
  }

  @override
  Widget build(BuildContext context) {
    if (_loadError != null) {
      return _error(context, _loadError!, null);
    }
    final bytes = _bytes;
    if (bytes == null || bytes.isEmpty) {
      return _error(context, StateError('No image data'), null);
    }

    return Image.memory(
      bytes,
      fit: widget.fit,
      width: widget.width,
      height: widget.height,
      cacheWidth: widget.cacheWidth,
      cacheHeight: widget.cacheHeight,
      filterQuality: widget.filterQuality,
      alignment: widget.alignment,
      gaplessPlayback: true,
      errorBuilder: (ctx, err, st) => _error(ctx, err, st),
    );
  }
}
