import 'dart:io';
import 'package:app/constants/constants_strings.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../constants/app_colors.dart';

class ImageUploadField extends StatefulWidget {
  final String label;
  final String placeholder;
  final bool isRequired;
  final Function(File?) onImageSelected;
  final String? externalImageUrl; // Add external image URL parameter

  const ImageUploadField({
    super.key,
    required this.label,
    required this.placeholder,
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
            widget.placeholder,
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

  @override
  Widget build(BuildContext context) {
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
                fontFamily: fontFamilyMontserrat
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
                        child: Image.network(
                          widget.externalImageUrl!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          errorBuilder: (context, error, stackTrace) {
                            return _buildPlaceholder();
                          },
                        ),
                      )
                    : _buildPlaceholder(),
          ),
        ),
      ],
    );
  }
}
