import 'dart:convert';
import 'dart:io';
import 'package:app/constants/constants_strings.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:app/utils/image_compression_helper.dart';
import 'package:app/commonWidgets/selfie_camera_screen.dart';

import '../constants/app_colors.dart';

class ImageUploadField extends StatefulWidget {
  final String? label;
  final String? placeholder;
  final bool isRequired;
  final Function(File?) onImageSelected;
  final String? externalImageUrl; // Add external image URL parameter
  final bool isDisabled; // Add isDisabled parameter

  const ImageUploadField({
    super.key,
    this.label,
    this.placeholder,
    this.isRequired = false,
    required this.onImageSelected,
    this.externalImageUrl, // Add external image URL parameter
    this.isDisabled = false, // Default value is false
  });

  @override
  State<ImageUploadField> createState() => _ImageUploadFieldState();
}

class _ImageUploadFieldState extends State<ImageUploadField> {
  File? _selectedImage;
  Widget? _externalImageWidget;
  String? _lastExternalUrl;

  @override
  void initState() {
    super.initState();
    if (widget.externalImageUrl != null && widget.externalImageUrl!.isNotEmpty) {
      _selectedImage = null;
      _prepareExternalImageWidget(widget.externalImageUrl!);
    }
  }

  @override
  void didUpdateWidget(ImageUploadField oldWidget) {
    super.didUpdateWidget(oldWidget);
    final externalUrlChanged = widget.externalImageUrl != oldWidget.externalImageUrl;
    final hadExternalUrl = oldWidget.externalImageUrl != null && oldWidget.externalImageUrl!.isNotEmpty;
    final hasExternalUrl = widget.externalImageUrl != null && widget.externalImageUrl!.isNotEmpty;
    if (externalUrlChanged) {
      if (hasExternalUrl && !hadExternalUrl) {
        // External URL was added (new external image loaded)
        setState(() {
          _selectedImage = null;
        });
        _prepareExternalImageWidget(widget.externalImageUrl!);
      } else if (hasExternalUrl && hadExternalUrl) {
        // External URL changed (external image updated)
        setState(() {
          _selectedImage = null;
        });
        _prepareExternalImageWidget(widget.externalImageUrl!);
      } else if (!hasExternalUrl && hadExternalUrl) {
        // External URL was removed (external image cleared)
        // Don't clear selected image in this case - user might have selected a new image
        setState(() {
          _externalImageWidget = null;
          _lastExternalUrl = null;
        });
      }
    }
    // If external URL hasn't changed, don't clear selected image
    // This allows newly selected images to display even if external URL still exists
  }

  Future<void> _pickImage() async {
    // Check if label or placeholder contains "selfie" (case-insensitive)
    final label = widget.label?.toLowerCase() ?? '';
    final placeholder = widget.placeholder?.toLowerCase() ?? '';
    final isSelfie = label.contains('selfie') || placeholder.contains('selfie');
    
    File? pickedFile;
    
    if (isSelfie) {
      // Use custom camera screen for selfies to ensure front camera opens
      final result = await Navigator.push<File>(
        context,
        MaterialPageRoute(
          builder: (context) => const SelfieCameraScreen(),
        ),
      );
      
      if (result != null) {
        pickedFile = result;
      }
    } else {
      // Use image_picker for non-selfie photos
    final picker = ImagePicker();
      final pickedImage = await picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
      );
      
      if (pickedImage != null) {
        pickedFile = File(pickedImage.path);
      }
    }

    if (pickedFile != null) {
      final originalFile = pickedFile;
      
      // Show loading indicator while compressing
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(
            color: AppColors.primaryGreen,
          ),
        ),
      );

      try {
        // Compress the image to 2MB
        final compressedFile = await ImageCompressionHelper.compressImageTo2MB(originalFile);
        
        // Close loading dialog
        if (mounted) {
          Navigator.of(context).pop();
        }

        if (compressedFile != null) {
          setState(() {
            _selectedImage = compressedFile;
          });
          widget.onImageSelected(_selectedImage);
        } else {
          // If compression fails, use original file
          setState(() {
            _selectedImage = originalFile;
          });
          widget.onImageSelected(_selectedImage);
          
          // Show warning that compression failed
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Image compression failed, using original image'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      } catch (e) {
        // Close loading dialog
        if (mounted) {
          Navigator.of(context).pop();
        }
        
        // If compression fails, use original file
        setState(() {
          _selectedImage = originalFile;
        });
        widget.onImageSelected(_selectedImage);
        
        // Show error message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error compressing image: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Widget _buildPlaceholder() {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.camera_alt_outlined, size: 20, color: AppColors.color555555),
          const SizedBox(width: 6),
          Text(
            widget.placeholder ?? '',
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

  Widget _buildImageFromUrl(String url) {
    try {
      if (url.startsWith('data:image')) {
        // Handle base64 data URL - normalize jpg to jpeg
        String normalizedUrl = url;
        if (url.startsWith('data:image/jpg')) {
          normalizedUrl = url.replaceFirst('data:image/jpg', 'data:image/jpeg');
        }
        
        final parts = normalizedUrl.split(',');
        if (parts.length < 2) {
          return _buildPlaceholder();
        }
        final base64Data = parts[1];
        try {
        final bytes = base64Decode(base64Data);
        return Image.memory(
          bytes,
          fit: BoxFit.cover,
          width: double.infinity,
          errorBuilder: (context, error, _) {
            return _buildPlaceholder();
          },
        );
        } catch (e) {
          return _buildPlaceholder();
        }
      } else if (url.contains('/data/user/') || url.contains('.jpg') || url.contains('.png')) {
        // Handle local file path
        return _buildLocalImage(url);
      } else {
        // Handle raw base64 data (from API response)
        try {
          final bytes = base64Decode(url);
          return Image.memory(
            bytes,
            fit: BoxFit.cover,
            width: double.infinity,
            errorBuilder: (context, error, _) {
              return _buildPlaceholder();
            },
          );
        } catch (e) {
          return _buildPlaceholder();
        }
      }
    } catch (e) {
      return _buildPlaceholder();
    }
  }

  Widget _buildLocalImage(String filePath) {
    try {
      final file = File(filePath);
      if (file.existsSync()) {
        return Image.file(
          file,
          fit: BoxFit.cover,
          width: double.infinity,
          errorBuilder: (context, error, _) {
            return _buildPlaceholder();
          },
        );
      } else {
        return _buildPlaceholder();
      }
    } catch (e) {
      return _buildPlaceholder();
    }
  }

  Future<void> _prepareExternalImageWidget(String url) async {
    if (url.isEmpty || url == _lastExternalUrl) return;
    _lastExternalUrl = url;
    // Decode on a future microtask to avoid blocking the current frame
    await Future<void>.delayed(Duration.zero);
    final widgetFromUrl = _buildImageFromUrl(url);
    if (!mounted) return;
    setState(() {
      _externalImageWidget = widgetFromUrl;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label with required mark
        if(widget.label != null) ...[
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  widget.label!,
                  style: TextStyle(
                    color: AppColors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    fontFamily: fontFamilyMontserrat,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if(widget.isRequired)
                Text(
                  ' *',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.red,
                    fontFamily: fontFamilyMontserrat,
                  ),
                ),
            ],
          ),
        ],
        const SizedBox(height: 5),

        // Upload box
        GestureDetector(
          onTap: widget.isDisabled ? null : _pickImage,
          child: Container(
            width: double.infinity,
            height: 150,
            decoration: BoxDecoration(
              color: widget.isDisabled ? Colors.grey.shade200 : Colors.white,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: Colors.grey.shade400),
            ),
            child: _selectedImage != null
                ? ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: Image.file(
                _selectedImage!,
                fit: BoxFit.cover,
                width: double.infinity,
              ),
            )
                : widget.externalImageUrl != null && widget.externalImageUrl!.isNotEmpty
                ? ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: Builder(
                builder: (context) {
                  _prepareExternalImageWidget(widget.externalImageUrl!);
                  return _externalImageWidget ?? _buildPlaceholder();
                },
              ),
            )
                : Builder(
              builder: (context) {
                return _buildPlaceholder();
              },
            ),
          ),
        ),
      ],
    );
  }
}