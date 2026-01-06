import 'dart:convert';
import 'dart:io';
import 'package:app/constants/constants_strings.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:app/utils/image_compression_helper.dart';
import 'package:app/utils/logger.dart';
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

  @override
  void initState() {
    super.initState();
    Logger.imageLog('🖼️ initState called');
    print('🖼️ [ImageUploadField] initState called');
    Logger.imageLog('🖼️ initState: externalImageUrl: ${widget.externalImageUrl != null ? "NOT NULL (${widget.externalImageUrl!.length} chars)" : "NULL"}');
    print('🖼️ [ImageUploadField] initState: externalImageUrl: ${widget.externalImageUrl != null ? "NOT NULL (${widget.externalImageUrl!.length} chars)" : "NULL"}');
    // Clear selected image if external image URL is provided initially
    if (widget.externalImageUrl != null && widget.externalImageUrl!.isNotEmpty) {
      Logger.imageLog('🖼️ External image URL provided in initState, clearing selected image');
      print('🖼️ [ImageUploadField] External image URL provided in initState, clearing selected image');
      _selectedImage = null;
    }
  }

  @override
  void didUpdateWidget(ImageUploadField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only clear selected image when external image URL actually changes
    // This allows newly selected images to take priority over external URLs
    final externalUrlChanged = widget.externalImageUrl != oldWidget.externalImageUrl;
    final hadExternalUrl = oldWidget.externalImageUrl != null && oldWidget.externalImageUrl!.isNotEmpty;
    final hasExternalUrl = widget.externalImageUrl != null && widget.externalImageUrl!.isNotEmpty;
    
    Logger.imageLog('🖼️ didUpdateWidget called');
    print('🖼️ [ImageUploadField] didUpdateWidget called');
    Logger.imageLog('🖼️ Old externalImageUrl: ${oldWidget.externalImageUrl != null ? "NOT NULL (${oldWidget.externalImageUrl!.length} chars)" : "NULL"}');
    print('🖼️ [ImageUploadField] Old externalImageUrl: ${oldWidget.externalImageUrl != null ? "NOT NULL (${oldWidget.externalImageUrl!.length} chars)" : "NULL"}');
    Logger.imageLog('🖼️ New externalImageUrl: ${widget.externalImageUrl != null ? "NOT NULL (${widget.externalImageUrl!.length} chars)" : "NULL"}');
    print('🖼️ [ImageUploadField] New externalImageUrl: ${widget.externalImageUrl != null ? "NOT NULL (${widget.externalImageUrl!.length} chars)" : "NULL"}');
    Logger.imageLog('🖼️ External URL changed: $externalUrlChanged');
    print('🖼️ [ImageUploadField] External URL changed: $externalUrlChanged');
    
    // Only clear selected image if:
    // 1. External URL changed from null/empty to a value (new external image loaded)
    // 2. External URL changed from one value to another (external image updated)
    // Do NOT clear if external URL exists but hasn't changed (user selected new image)
    if (externalUrlChanged) {
      if (hasExternalUrl && !hadExternalUrl) {
        // External URL was added (new external image loaded)
        Logger.imageLog('🖼️ External image URL added, clearing selected image');
        print('🖼️ [ImageUploadField] External image URL added, clearing selected image');
        setState(() {
          _selectedImage = null;
        });
      } else if (hasExternalUrl && hadExternalUrl) {
        // External URL changed (external image updated)
        Logger.imageLog('🖼️ External image URL updated, clearing selected image');
        print('🖼️ [ImageUploadField] External image URL updated, clearing selected image');
        setState(() {
          _selectedImage = null;
        });
      } else if (!hasExternalUrl && hadExternalUrl) {
        // External URL was removed (external image cleared)
        Logger.imageLog('🖼️ External image URL removed');
        print('🖼️ [ImageUploadField] External image URL removed');
        // Don't clear selected image in this case - user might have selected a new image
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
    
    // Debug logging
    Logger.imageLog('📷 [ImageUploadField] Label: "${widget.label}", Placeholder: "${widget.placeholder}", IsSelfie: $isSelfie');
    print('📷 [ImageUploadField] Label: "${widget.label}", Placeholder: "${widget.placeholder}", IsSelfie: $isSelfie');
    
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
        Logger.imageLog('CustomImageUploadField: Starting image compression...');
        // Compress the image to 2MB
        final compressedFile = await ImageCompressionHelper.compressImageTo2MB(originalFile);
        Logger.imageLog('CustomImageUploadField: Compression completed, result: ${compressedFile != null ? "Success" : "Failed"}');
        
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
    Logger.imageLog('🖼️ Building image from URL, length: ${url.length}');
    print('🖼️ [ImageUploadField] _buildImageFromUrl called, length: ${url.length}');
    Logger.imageLog('🖼️ URL starts with: ${url.substring(0, url.length > 100 ? 100 : url.length)}');
    print('🖼️ [ImageUploadField] URL starts with: ${url.substring(0, url.length > 100 ? 100 : url.length)}');
    try {
      if (url.startsWith('data:image')) {
        // Handle base64 data URL - normalize jpg to jpeg
        String normalizedUrl = url;
        if (url.startsWith('data:image/jpg')) {
          normalizedUrl = url.replaceFirst('data:image/jpg', 'data:image/jpeg');
          Logger.imageLog('🖼️ Normalized jpg to jpeg');
          print('🖼️ [ImageUploadField] Normalized jpg to jpeg');
        }
        
        final parts = normalizedUrl.split(',');
        if (parts.length < 2) {
          Logger.errorLog('❌ Invalid data URL format - no comma found');
          print('🖼️ [ImageUploadField] ❌ Invalid data URL format - no comma found');
          return _buildPlaceholder();
        }
        final base64Data = parts[1];
        Logger.imageLog('🖼️ Decoding base64 data, length: ${base64Data.length}');
        print('🖼️ [ImageUploadField] Decoding base64 data, length: ${base64Data.length}');
        try {
        final bytes = base64Decode(base64Data);
          Logger.imageLog('✅ Base64 decoded successfully, bytes length: ${bytes.length}');
          print('🖼️ [ImageUploadField] ✅ Base64 decoded successfully, bytes length: ${bytes.length}');
        return Image.memory(
          bytes,
          fit: BoxFit.cover,
          width: double.infinity,
          errorBuilder: (context, error, stackTrace) {
              Logger.errorLog('❌ Error displaying base64 image: $error');
              print('🖼️ [ImageUploadField] ❌ Error displaying base64 image: $error');
              Logger.errorLog('❌ Stack trace: $stackTrace');
            return _buildPlaceholder();
          },
        );
        } catch (e) {
          Logger.errorLog('❌ Error decoding base64: $e');
          print('🖼️ [ImageUploadField] ❌ Error decoding base64: $e');
          return _buildPlaceholder();
        }
      } else if (url.contains('/data/user/') || url.contains('.jpg') || url.contains('.png')) {
        // Handle local file path
        Logger.imageLog('🖼️ Rendering local file image: $url');
        return _buildLocalImage(url);
      } else {
        // Handle raw base64 data (from API response)
        Logger.imageLog('🖼️ Rendering raw base64 image, data length: ${url.length}');
        try {
          final bytes = base64Decode(url);
          Logger.imageLog('✅ Raw base64 decoded successfully, bytes length: ${bytes.length}');
          return Image.memory(
            bytes,
            fit: BoxFit.cover,
            width: double.infinity,
            errorBuilder: (context, error, stackTrace) {
              Logger.errorLog('❌ Error displaying raw base64 image: $error');
              return _buildPlaceholder();
            },
          );
        } catch (e) {
          Logger.errorLog('❌ Error decoding raw base64 data: $e');
          return _buildPlaceholder();
        }
      }
    } catch (e, stackTrace) {
      Logger.errorLog('❌ Error in _buildImageFromUrl: $e');
      Logger.errorLog('❌ Stack trace: $stackTrace');
      return _buildPlaceholder();
    }
  }

  Widget _buildLocalImage(String filePath) {
    try {
      final file = File(filePath);
      if (file.existsSync()) {
        Logger.imageLog('Rendering local file image, exists: $filePath');
        return Image.file(
          file,
          fit: BoxFit.cover,
          width: double.infinity,
          errorBuilder: (context, error, stackTrace) {
            Logger.errorLog('Error displaying local file: $error');
            return _buildPlaceholder();
          },
        );
      } else {
        Logger.imageLog('Local file does not exist: $filePath');
        return _buildPlaceholder();
      }
    } catch (e) {
      Logger.errorLog('Error displaying local image: $e');
      return _buildPlaceholder();
    }
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
                  Logger.imageLog('🖼️ Building external image from URL');
                  print('🖼️ [ImageUploadField] Building external image from URL, length: ${widget.externalImageUrl!.length}');
                  print('🖼️ [ImageUploadField] externalImageUrl preview: ${widget.externalImageUrl!.substring(0, widget.externalImageUrl!.length > 100 ? 100 : widget.externalImageUrl!.length)}');
                  return _buildImageFromUrl(widget.externalImageUrl!);
                },
              ),
            )
                : Builder(
              builder: (context) {
                Logger.imageLog('📷 Showing placeholder - no image available');
                return _buildPlaceholder();
              },
            ),
          ),
        ),
      ],
    );
  }
}