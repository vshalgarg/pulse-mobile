import 'dart:convert';
import 'dart:io';
import 'package:app/constants/constants_strings.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:app/utils/image_compression_helper.dart';
import 'package:app/utils/logger.dart';

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

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.camera);

    if (pickedFile != null) {
      final originalFile = File(pickedFile.path);
      
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
              fontWeight: FontWeight.w400,
              color: AppColors.color555555,
              fontFamily: fontFamilyMontserrat,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageFromUrl(String url) {
    Logger.imageLog('Building image from URL');
    try {
      if (url.startsWith('data:image')) {
        // Handle base64 data URL
        final base64Data = url.split(',')[1];
        final bytes = base64Decode(base64Data);
        Logger.imageLog('Rendering base64 image, data length: ${bytes.length}');
        return Image.memory(
          bytes,
          fit: BoxFit.cover,
          width: double.infinity,
          errorBuilder: (context, error, stackTrace) {
            Logger.errorLog('Error displaying base64 image: $error');
            return _buildPlaceholder();
          },
        );
      } else if (url.contains('/data/user/') || url.contains('.jpg') || url.contains('.png')) {
        // Handle local file path
        Logger.imageLog('Rendering local file image: $url');
        return _buildLocalImage(url);
      } else {
        // Handle raw base64 data (from API response)
        Logger.imageLog('Rendering raw base64 image, data length: ${url.length}');
        try {
          final bytes = base64Decode(url);
          return Image.memory(
            bytes,
            fit: BoxFit.cover,
            width: double.infinity,
            errorBuilder: (context, error, stackTrace) {
              Logger.errorLog('Error displaying raw base64 image: $error');
              return _buildPlaceholder();
            },
          );
        } catch (e) {
          Logger.errorLog('Error decoding raw base64 data: $e');
          return _buildPlaceholder();
        }
      }
    } catch (e) {
      Logger.errorLog('Error in _buildImageFromUrl: $e');
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
            children: [
              Expanded(
                child: Text(
                  widget.label ?? '',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    color: Colors.white,
                    fontFamily: fontFamilyMontserrat,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ),
              if (widget.isRequired)
                const Text(
                  " *",
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.red,
                  ),
                ),
            ],
          ),
        ],
        const SizedBox(height: 6),

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