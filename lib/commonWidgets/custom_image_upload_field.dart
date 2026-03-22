import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:app/constants/constants_strings.dart';
import 'package:app/constants/app_colors.dart';

import 'package:app/utils/image_compression_helper.dart';
import 'package:app/utils/CrashLogger.dart';
import 'package:app/utils/file_logger.dart';
import 'package:app/utils/toastbar.dart';
import 'package:app/services/service_locator.dart';
import 'package:app/commonWidgets/selfie_camera_screen.dart';
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

  static const String _cameraInProgressKey = 'image_upload_field_camera_in_progress';

  File? _selectedImage;
  Widget? _externalImageWidget;
  String? _lastExternalUrl;

  bool _isLoading = false;
  bool _isPickingImage = false;

  /// Prevent base64 memory crash
  static const int maxBase64Length = 5000000;

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

  /// Recover camera result on Android if activity was killed/recreated.
  /// This happens on some devices after confirming a photo in the system camera.
  Future<File?> _recoverLostImage() async {
    if (_selectedImage != null) return null;

    try {
      final lost = await _picker.retrieveLostData();
      if (lost.isEmpty) return null;

      final xFile = lost.file;
      if (xFile == null) return null;

      final file = File(xFile.path);
      if (!file.existsSync()) return null;

      File finalFile = file;
      try {
        final compressed = await ImageCompressionHelper.compressImageTo2MB(file);
        if (compressed != null) {
          finalFile = compressed;
        }
      } catch (e, s) {
        await CrashLogger().logCrash(e, s);
      }

      if (!mounted) return null;
      setState(() {
        _selectedImage = finalFile;
        _isLoading = false;
      });

      widget.onImageSelected(finalFile);
      return finalFile;
    } catch (e, s) {
      await CrashLogger().logCrash(
        e,
        s,
        reason: 'ImageUploadField._recoverLostImage',
        context: {
          'label': widget.label ?? '',
          'placeholder': widget.placeholder ?? '',
        },
      );
    }

    return null;
  }

  Future<void> _handleCameraRecovery() async {
    // If the app was killed while the system camera was open, show a friendly message on next launch.
    final wasCameraInProgress = LocalStorageService.getBool(_cameraInProgressKey) == true;

    final recovered = await _recoverLostImage();

    if (wasCameraInProgress) {
      await LocalStorageService.setBool(_cameraInProgressKey, false);

      // If we couldn't recover a file, it likely means the camera closed/crashed or Android
      // killed the activity before delivering the result.
      if (recovered == null && mounted) {
        Toastbar.showErrorWithoutContext(
          'Camera closed unexpectedly. Please try again.',
        );
      }
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

  /// Camera picker
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
      await LocalStorageService.setBool(_cameraInProgressKey, true);

      if (isSelfie) {
        /// Front camera selfie
        final result = await Navigator.push<File>(
          context,
          MaterialPageRoute(
            builder: (_) => const SelfieCameraScreen(),
          ),
        );

        if (result != null) pickedFile = result;
      } else {
        /// Normal camera
        final picked = await _picker.pickImage(
          source: ImageSource.camera,
          preferredCameraDevice: CameraDevice.rear,
          imageQuality: 55,
          maxWidth: 1024,
          maxHeight: 1024,
        );

        if (picked != null) {
          pickedFile = File(picked.path);
        }
      }

      if (pickedFile == null) {
        await LocalStorageService.setBool(_cameraInProgressKey, false);
        Toastbar.showErrorWithoutContext('Camera closed without saving image.');
        return;
      }

      if (!pickedFile.existsSync()) {
        await LocalStorageService.setBool(_cameraInProgressKey, false);
        Toastbar.showErrorWithoutContext('Unable to read captured image. Please try again.');
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
      }

      if (!mounted) return;

      setState(() {
        _selectedImage = finalFile;
        _isLoading = false;
      });

      widget.onImageSelected(finalFile);
      await LocalStorageService.setBool(_cameraInProgressKey, false);
    } catch (e, s) {
      await CrashLogger().logCrash(
        e,
        s,
        reason: 'ImageUploadField._pickImage',
        context: {
          'feature': 'camera',
          'camera_flow': isSelfie ? 'selfie' : 'rear',
          'action': 'pick_image',
          'isSelfie': isSelfie,
          'label': widget.label ?? '',
          'placeholder': widget.placeholder ?? '',
        },
      );

      await FileLogger.error(
        'Camera open failed',
        data: {'error': e.toString()},
        stackTrace: s,
      );

      final api = ServiceLocator().apiService;
      api.sendCameraCrashLogs(
        'Camera open failed in ImageUploadField: ${e.toString()}',
      );

      Toastbar.showErrorWithoutContext(
        "Unable to open camera on this device",
      );

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } finally {
      _isPickingImage = false;
      if (mounted) {
        setState(() => _isLoading = false);
      }
      await LocalStorageService.setBool(_cameraInProgressKey, false);
    }
  }

  /// Placeholder
  Widget _buildPlaceholder() {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
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

  /// Render image safely
  Widget _buildImageFromUrl(String url) {
    try {
      /// Prevent large base64 crash
      if (url.length > maxBase64Length) {
        return _buildPlaceholder();
      }

      /// data:image/jpeg;base64
      if (url.startsWith('data:image')) {
        final parts = url.split(',');

        if (parts.length < 2) return _buildPlaceholder();

        final bytes = base64Decode(parts[1]);

        return Image.memory(
          bytes,
          fit: BoxFit.cover,
          width: double.infinity,
          cacheWidth: 600,
          cacheHeight: 600,
          filterQuality: FilterQuality.low,
        );
      }

      /// Local file path
      if (url.startsWith('/data/') || url.contains('/storage/')) {
        final file = File(url);

        if (file.existsSync()) {
          return Image.file(
            file,
            fit: BoxFit.cover,
            width: double.infinity,
            cacheWidth: 600,
          );
        }
      }

      /// Raw base64
      final bytes = base64Decode(url);

      return Image.memory(
        bytes,
        fit: BoxFit.cover,
        width: double.infinity,
        cacheWidth: 600,
        cacheHeight: 600,
        filterQuality: FilterQuality.low,
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
      child = Image.file(
        _selectedImage!,
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