import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:app/constants/constants_strings.dart';
import 'package:app/constants/app_colors.dart';
import 'package:app/utils/image_compression_helper.dart';
import 'package:app/utils/CrashLogger.dart';
import 'package:app/utils/file_logger.dart';
import 'package:app/utils/toastbar.dart';
import 'package:app/services/service_locator.dart';
import 'package:app/commonWidgets/selfie_camera_screen.dart';
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

  @override
  void initState() {
    super.initState();
    _prepareExternalImageWidget(widget.externalImageUrl);
    _handleCameraRecovery();
  }

  /// -------------------- CAMERA PICK --------------------

  Future<void> _pickImage() async {
    if (_isPickingImage || widget.isDisabled) return;

    _isPickingImage = true;

    final label = widget.label?.toLowerCase() ?? '';
    final placeholder = widget.placeholder?.toLowerCase() ?? '';
    final isSelfie =
        label.contains('selfie') || placeholder.contains('selfie');

    File? pickedFile;

    try {
      setState(() => _isLoading = true);
      await LocalStorageService.setBool(_cameraInProgressKey, true);

      /// 📸 Camera
      if (isSelfie) {
        final result = await Navigator.push<File>(
          context,
          MaterialPageRoute(
            builder: (_) => const SelfieCameraScreen(),
          ),
        );

        if (result != null) pickedFile = result;
      } else {
        final picked = await _picker.pickImage(
          source: ImageSource.camera,
          preferredCameraDevice: CameraDevice.rear,

          /// 🔥 OPTIMIZED (NO NEED HEAVY COMPRESSION)
          imageQuality: 40,
          maxWidth: 800,
          maxHeight: 800,
        );

        if (picked != null) {
          pickedFile = File(picked.path);
        }
      }

      if (pickedFile == null || !pickedFile.existsSync()) {
        Toastbar.showErrorWithoutContext(
            'Camera closed without saving image.');
        return;
      }

      /// ✅ STEP 1: INSTANT PREVIEW (FAST UX)
      setState(() {
        _selectedImage = pickedFile;
        _isLoading = false;
      });

      /// 🔥 STEP 2: BACKGROUND PROCESSING
      _processImageInBackground(pickedFile);

    } catch (e, s) {
      await CrashLogger().logCrash(e, s);

      Toastbar.showErrorWithoutContext(
        "Unable to open camera",
      );

      if (mounted) setState(() => _isLoading = false);
    } finally {
      _isPickingImage = false;
      await LocalStorageService.setBool(_cameraInProgressKey, false);
    }
  }

  /// -------------------- BACKGROUND PROCESS --------------------

  Future<void> _processImageInBackground(File file) async {
    try {
      final fileSize = await file.length();

      File finalFile = file;

      /// Only compress if > 2MB
      if (fileSize > 2 * 1024 * 1024) {
        final compressed = await compute(_compressInIsolate, file.path);

        if (compressed != null && File(compressed).existsSync()) {
          finalFile = File(compressed);
        }
      }

      /// ✅ Send final file after processing
      widget.onImageSelected(finalFile);

    } catch (e, s) {
      await CrashLogger().logCrash(e, s);

      /// fallback
      widget.onImageSelected(file);
    }
  }

  /// Isolate function
  static Future<String?> _compressInIsolate(String path) async {
    try {
      final file = File(path);
      final compressed =
          await ImageCompressionHelper.compressImageTo2MB(file);
      return compressed?.path;
    } catch (_) {
      return null;
    }
  }

  /// -------------------- RECOVERY FIX --------------------

  Future<File?> _recoverLostImage() async {
    try {
      final lost = await _picker.retrieveLostData();
      if (lost.isEmpty) return null;

      final xFile = lost.file;
      if (xFile == null) return null;

      final file = File(xFile.path);
      if (!file.existsSync()) return null;

      /// ❌ NO COMPRESSION HERE
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

  /// -------------------- UI HELPERS --------------------

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

  /// -------------------- UI --------------------

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