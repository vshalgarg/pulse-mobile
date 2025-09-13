import 'dart:io';
import 'dart:convert';
import 'package:app/constants/constants_strings.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../constants/app_colors.dart';


class ImageUploadField extends StatefulWidget {
  final String label;
  final String? placeholder;
  final bool isRequired;
  final Function(File?) onImageSelected;
  final String? externalImageUrl; // Add external image URL parameter

  const ImageUploadField({
    super.key,
    required this.label,
    this.placeholder,
    this.isRequired = false,
    required this.onImageSelected,
    this.externalImageUrl, // Add external image URL parameter
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
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
      widget.onImageSelected(_selectedImage);
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
    print('Building image from URL');
    try {
      if (url.startsWith('data:image')) {
        // Handle base64 data URL
        final base64Data = url.split(',')[1];
        final bytes = base64Decode(base64Data);
        print('Rendering base64 image, data length: ${bytes.length}');
        return Image.memory(
          bytes,
          fit: BoxFit.cover,
          width: double.infinity,
          errorBuilder: (context, error, stackTrace) {
            print('Error displaying base64 image: $error');
            return _buildPlaceholder();
          },
        );
      } else if (url.contains('/data/user/') || url.contains('.jpg') || url.contains('.png')) {
        // Handle local file path
        print('Rendering local file image: $url');
        return _buildLocalImage(url);
      } else {
        // Handle network URL
        print('Rendering network image: $url');
        return Image.network(
          url,
          fit: BoxFit.cover,
          width: double.infinity,
          errorBuilder: (context, error, stackTrace) {
            print('Error displaying network image: $error');
            return _buildPlaceholder();
          },
        );
      }
    } catch (e) {
      print('Error in _buildImageFromUrl: $e');
      return _buildPlaceholder();
    }
  }

  Widget _buildLocalImage(String filePath) {
    try {
      final file = File(filePath);
      if (file.existsSync()) {
        print('Rendering local file image, exists: $filePath');
        return Image.file(
          file,
          fit: BoxFit.cover,
          width: double.infinity,
          errorBuilder: (context, error, stackTrace) {
            print('Error displaying local file: $error');
            return _buildPlaceholder();
          },
        );
      } else {
        print('Local file does not exist: $filePath');
        return _buildPlaceholder();
      }
    } catch (e) {
      print('Error displaying local image: $e');
      return _buildPlaceholder();
    }
  }

  @override
  Widget build(BuildContext context) {
    print('ImageUploadField build, selectedImage: ${_selectedImage?.path}');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label with required mark
        Row(
          children: [
            Text(
              widget.label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w400,
                color: Colors.white,
                fontFamily: fontFamilyMontserrat,
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
        const SizedBox(height: 6),

        // Upload box
        GestureDetector(
          onTap: _pickImage,
          child: Container(
            width: double.infinity,
            height: 150,
            decoration: BoxDecoration(
              color: Colors.white,
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
              child: _buildImageFromUrl(widget.externalImageUrl!),
            )
                : _buildPlaceholder(),
          ),
        ),
      ],
    );
  }
}