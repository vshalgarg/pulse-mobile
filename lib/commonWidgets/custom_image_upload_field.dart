import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import 'package:app/constants/constants_strings.dart';
import 'package:app/constants/app_colors.dart';

import 'package:app/utils/image_compression_helper.dart';
import 'package:app/utils/CrashLogger.dart';
import 'package:app/utils/toastbar.dart';
import 'package:app/commonWidgets/safe_file_image.dart';
import 'package:app/services/local_storage_service.dart';

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

  static const String _cameraInProgressKey =
      'image_upload_field_camera_in_progress';

  File? _selectedImage;
  Widget? _externalImageWidget;
  String? _lastExternalUrl;

  bool _isLoading = false;
  bool _isPickingImage = false;

  static const int maxBase64Length = 5000000;

  /// 🔥 BACKGROUND COMPRESSION (ISOLATE)
  static Future<String?> _compressInBackground(String path) async {
    try {
      final file = File(path);
      final result =
          await ImageCompressionHelper.compressImageTo2MB(file);
      return result?.path;
    } catch (_) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _prepareExternalImageWidget(widget.externalImageUrl);
    _handleCameraRecovery();
  }

  @override
  void didUpdateWidget(ImageUploadField oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.externalImageUrl != oldWidget.externalImageUrl) {
      _prepareExternalImageWidget(widget.externalImageUrl);
    }
  }

  /// 🔥 SAFE RECOVERY (NO COMPRESSION)
  Future<File?> _recoverLostImage() async {
    if (_selectedImage != null) return null;

    try {
      final lost = await _picker.retrieveLostData();
      if (lost.isEmpty) return null;

      final xFile = lost.file;
      if (xFile == null) return null;

      final file = File(xFile.path);
      if (!file.existsSync()) return null;

      if (!mounted) return null;

      setState(() {
        _selectedImage = file;
        _isLoading = false;
      });

      widget.onImageSelected(file);
      return file;
    } catch (e, s) {
      await CrashLogger().logCrash(e, s);
    }

    return null;
  }

  Future<void> _handleCameraRecovery() async {
    final wasCameraInProgress =
        LocalStorageService.getBool(_cameraInProgressKey) == true;

    final recovered = await _recoverLostImage();

    if (wasCameraInProgress) {
      await LocalStorageService.setBool(_cameraInProgressKey, false);

      if (recovered == null && mounted) {
        Toastbar.showErrorWithoutContext(
          'Low Resources. Please try again.',
        );
      }
    }
  }

  /// 🔥 CAMERA PICK (ULTIMATE SAFE FLOW)
  Future<void> _pickImage() async {
    if (_isPickingImage || widget.isDisabled) return;

    _isPickingImage = true;

    File? pickedFile;

    try {
      setState(() => _isLoading = true);
      await LocalStorageService.setBool(_cameraInProgressKey, true);

      final picked = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,

        /// 🔥 SAFE CONFIG
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 40,
      );

      if (picked != null) {
        pickedFile = File(picked.path);
      }

      if (pickedFile == null || !pickedFile.existsSync()) {
        Toastbar.showErrorWithoutContext(
            'Camera closed without saving image.');
        return;
      }

      /// ✅ STEP 1: INSTANT PREVIEW
      setState(() {
        _selectedImage = pickedFile;
        _isLoading = false;
      });

      /// ✅ STEP 2: INSTANT CALLBACK (NO WAIT)
      widget.onImageSelected(pickedFile);

      /// ✅ STEP 3: BACKGROUND COMPRESSION (NON-BLOCKING)
      final size = await pickedFile.length();
      const twoMb = 2 * 1024 * 1024;

      if (size > twoMb) {
        compute(_compressInBackground, pickedFile.path)
            .then((compressedPath) {
          if (compressedPath != null) {
            final compressedFile = File(compressedPath);

            /// 🔥 Optional: update with compressed file
            widget.onImageSelected(compressedFile);
          }
        });
      }

      await LocalStorageService.setBool(_cameraInProgressKey, false);
    } catch (e, s) {
      await CrashLogger().logCrash(e, s);

      Toastbar.showErrorWithoutContext(
        "Unable to open camera",
      );

      if (mounted) setState(() => _isLoading = false);
    } finally {
      _isPickingImage = false;

      if (mounted && _isLoading) {
        setState(() => _isLoading = false);
      }

      await LocalStorageService.setBool(_cameraInProgressKey, false);
    }
  }

  /// UI Helpers

  Future<void> _prepareExternalImageWidget(String? url) async {
    if (url == null || url.isEmpty || url == _lastExternalUrl) return;

    _lastExternalUrl = url;

    await Future<void>.delayed(Duration.zero);

    if (!mounted) return;

    setState(() {
      _externalImageWidget = _buildImageFromUrl(url);
    });
  }

  Widget _buildPlaceholder() {
    return const Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.camera_alt_outlined,
              size: 20, color: AppColors.color555555),
          SizedBox(width: 6),
          Text(
            "Take Photo",
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: AppColors.color555555,
              fontFamily: fontFamilyMontserrat,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageFromUrl(String url) {
    try {
      if (url.length > maxBase64Length) {
        return _buildPlaceholder();
      }

      if (url.startsWith('data:image')) {
        final bytes = base64Decode(url.split(',')[1]);

        return Image.memory(
          bytes,
          fit: BoxFit.cover,
          cacheWidth: 600,
          filterQuality: FilterQuality.low,
        );
      }

      final bytes = base64Decode(url);

      return Image.memory(
        bytes,
        fit: BoxFit.cover,
        cacheWidth: 600,
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
      child = SafeImageFile(
        file: _selectedImage!,
        fit: BoxFit.cover,
        width: double.infinity,
        cacheWidth: 600,
        errorBuilder: (context, error, stackTrace) =>
            _buildPlaceholder(),
      );
    } else if (_externalImageWidget != null) {
      child = _externalImageWidget!;
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
                const Text(" *", style: TextStyle(color: Colors.red)),
            ],
          ),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: (widget.isDisabled || _isLoading || _isPickingImage)
              ? null
              : _pickImage,
          child: Container(
            width: double.infinity,
            height: 150,
            decoration: BoxDecoration(
              color: widget.isDisabled
                  ? Colors.grey.shade200
                  : Colors.white,
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