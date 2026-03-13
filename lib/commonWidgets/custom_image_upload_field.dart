import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:app/constants/constants_strings.dart';
import 'package:app/constants/app_colors.dart';

import 'package:app/utils/image_compression_helper.dart';
import 'package:app/utils/CrashLogger.dart';
import 'package:app/utils/file_logger.dart';
import 'package:app/commonWidgets/selfie_camera_screen.dart';

class ImageUploadField extends StatefulWidget {
  final String? label;
  final String? placeholder;
  final bool isRequired;
  final bool isDisabled;
  final Function(File?) onImageSelected;
  final String? externalImageUrl;

  const ImageUploadField({
    super.key,
    this.label,
    this.placeholder,
    this.isRequired = false,
    this.isDisabled = false,
    required this.onImageSelected,
    this.externalImageUrl,
  });

  @override
  State<ImageUploadField> createState() => _ImageUploadFieldState();
}

class _ImageUploadFieldState extends State<ImageUploadField> {
  final ImagePicker _picker = ImagePicker();

  File? _selectedImage;
  Widget? _externalImageWidget;
  String? _lastExternalUrl;

  bool _isLoading = false;
  bool _isPickingImage = false;

  @override
  void initState() {
    super.initState();
    _prepareExternalImageWidget(widget.externalImageUrl);
  }

  @override
  void didUpdateWidget(ImageUploadField oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.externalImageUrl != oldWidget.externalImageUrl) {
      _prepareExternalImageWidget(widget.externalImageUrl);
    }
  }

  /// Prepare external image safely
  Future<void> _prepareExternalImageWidget(String? url) async {
    if (url == null || url.isEmpty || url == _lastExternalUrl) return;

    _lastExternalUrl = url;

    await Future<void>.delayed(Duration.zero);

    if (!mounted) return;

    setState(() {
      _externalImageWidget = _buildImageFromUrl(url);
    });
  }

  /// Camera picker with selfie support
  Future<void> _pickImage() async {
    if (_isPickingImage || widget.isDisabled) return;

    _isPickingImage = true;

    final label = widget.label?.toLowerCase() ?? '';
    final placeholder = widget.placeholder?.toLowerCase() ?? '';
    final isSelfie = label.contains('selfie') || placeholder.contains('selfie');

    File? pickedFile;

    try {
      if (!mounted) return;
      setState(() => _isLoading = true);

      if (isSelfie) {
        /// Use custom selfie screen (front camera)
        final result = await Navigator.push<File>(
          context,
          MaterialPageRoute(builder: (_) => const SelfieCameraScreen()),
        );

        if (result != null) pickedFile = result;
      } else {
        /// Standard camera
        final picked = await _picker.pickImage(
          source: ImageSource.camera,
          preferredCameraDevice: CameraDevice.rear,
          imageQuality: 60,
          maxWidth: 1280,
          maxHeight: 1280,
        );

        if (picked != null) {
          pickedFile = File(picked.path);
        }
      }

      if (pickedFile == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      /// Validate file
      if (!pickedFile.existsSync()) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      /// Compress image
      File finalFile = pickedFile;

      try {
        final compressed =
            await ImageCompressionHelper.compressImageTo2MB(pickedFile);

        if (compressed != null) {
          finalFile = compressed;
        }
      } catch (e, s) {
        await CrashLogger().logCrash(e, s);
        await FileLogger.error(
          'Image compression failed',
          data: {'error': e.toString()},
          stackTrace: s,
        );
      }

      if (!mounted) return;

      setState(() {
        _selectedImage = finalFile;
        _isLoading = false;
      });

      widget.onImageSelected(finalFile);
    } catch (e, s) {
      await CrashLogger().logCrash(e, s);

      await FileLogger.error(
        'Camera open failed',
        data: {'error': e.toString()},
        stackTrace: s,
      );

      if (mounted) {
        setState(() => _isLoading = false);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to open camera on this device'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      _isPickingImage = false;
    }
  }

  /// Placeholder
  Widget _buildPlaceholder() {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.camera_alt_outlined,
              size: 20, color: AppColors.color555555),
          const SizedBox(width: 6),
          Text(
            widget.placeholder ?? "Take Photo",
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              color: AppColors.color555555,
              fontFamily: fontFamilyMontserrat,
            ),
          ),
        ],
      ),
    );
  }

  /// Render image from URL/base64/path
  Widget _buildImageFromUrl(String url) {
    try {
      /// data:image/jpeg;base64
      if (url.startsWith('data:image')) {
        String normalized = url;

        if (normalized.startsWith('data:image/jpg')) {
          normalized =
              normalized.replaceFirst('data:image/jpg', 'data:image/jpeg');
        }

        final parts = normalized.split(',');
        if (parts.length < 2) return _buildPlaceholder();

        final bytes = base64Decode(parts[1]);

        return Image.memory(
          bytes,
          fit: BoxFit.cover,
          width: double.infinity,
          cacheWidth: 800,
          cacheHeight: 800,
          filterQuality: FilterQuality.low,
          errorBuilder: (_, __, ___) => _buildPlaceholder(),
        );
      }

      /// Local file path
      if (url.startsWith('/data/') ||
          url.contains('/data/user/') ||
          url.endsWith('.jpg') ||
          url.endsWith('.png')) {
        final file = File(url);

        if (file.existsSync()) {
          return Image.file(
            file,
            fit: BoxFit.cover,
            width: double.infinity,
            errorBuilder: (_, __, ___) => _buildPlaceholder(),
          );
        }
      }

      /// Raw base64
      final bytes = base64Decode(url);

      return Image.memory(
        bytes,
        fit: BoxFit.cover,
        width: double.infinity,
        cacheWidth: 800,
        cacheHeight: 800,
        filterQuality: FilterQuality.low,
        errorBuilder: (_, __, ___) => _buildPlaceholder(),
      );
    } catch (_) {
      return _buildPlaceholder();
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget child;

    if (_isLoading) {
      child = const Center(child: CircularProgressIndicator());
    } else if (_selectedImage != null) {
      child = ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.file(
          _selectedImage!,
          fit: BoxFit.cover,
          width: double.infinity,
          errorBuilder: (_, __, ___) => _buildPlaceholder(),
        ),
      );
    } else if (_externalImageWidget != null) {
      child = ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: _externalImageWidget!,
      );
    } else {
      child = _buildPlaceholder();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null)
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.label!,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontFamily: fontFamilyMontserrat,
                    fontSize: 16,
                    color: AppColors.white,
                  ),
                ),
              ),
              if (widget.isRequired)
                const Text(
                  " *",
                  style: TextStyle(color: Colors.red),
                ),
            ],
          ),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: widget.isDisabled ? null : _pickImage,
          child: Container(
            width: double.infinity,
            height: 150,
            decoration: BoxDecoration(
              color: widget.isDisabled ? Colors.grey.shade200 : Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.grey),
            ),
            child: child,
          ),
        ),
      ],
    );
  }
}