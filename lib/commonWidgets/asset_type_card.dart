import 'dart:io';

import 'package:app/commonWidgets/qr_screen_form_field.dart';
import 'package:app/constants/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../constants/constants_strings.dart';
import '../models/form_fields_model.dart';
import '../screens/qrScannerScreen.dart';
import 'custom_file_upload.dart';
import 'custom_form_field.dart';
import 'custom_radio_options.dart';




class CustomInfoCard extends StatefulWidget {
  final String serialLabel;
  final String photoLabel;
  final String statusLabel;
  final String buttonLabel;
  final TextEditingController serialController;
  final VoidCallback onSave;
  final Function(String?) onPhotoTap;
  final ValueChanged<bool> onStatusChanged;
  final ValueChanged<String>? onSerialChanged;
  final bool? initialStatus;
  final String? initialPhotoPath;

  const CustomInfoCard({
    super.key,
    required this.serialLabel,
    required this.photoLabel,
    required this.statusLabel,
    this.buttonLabel = "Save",
    required this.serialController,
    required this.onSave,
    required this.onPhotoTap,
    required this.onStatusChanged,
    this.onSerialChanged,
    this.initialStatus,
    this.initialPhotoPath,
  });

  @override
  State<CustomInfoCard> createState() => _CustomInfoCardState();
}

class _CustomInfoCardState extends State<CustomInfoCard> {
  bool? selectedStatus;
  File? _selectedImage;

  @override
  void initState() {
    super.initState();
    // Initialize with provided values if editing
    selectedStatus = widget.initialStatus;
    if (widget.initialPhotoPath != null) {
      _selectedImage = File(widget.initialPhotoPath!);
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.camera);

    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
      // Call the callback with the file path
      widget.onPhotoTap(_selectedImage!.path);
    }
  }

  void _deleteImage() {
    setState(() {
      _selectedImage = null;
    });
    // Call the callback to notify parent that image was deleted
    widget.onPhotoTap(null);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.green7,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Serial Number field
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: widget.serialLabel,
                  style: const TextStyle(
                    fontWeight: FontWeight.w400,
                    fontFamily: fontFamilyMontserrat,
                    fontSize: 16,
                    color: AppColors.white,
                  ),
                ),
                const TextSpan(
                  text: " *",
                  style: TextStyle(
                    fontWeight: FontWeight.w400,
                    fontFamily: fontFamilyMontserrat,
                    fontSize: 16,
                    color: AppColors.errorColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: widget.serialController,
            onChanged: (value) {
              if (widget.onSerialChanged != null) {
                widget.onSerialChanged!(value);
              }
            },
            decoration: InputDecoration(
              hintText: widget.serialLabel,
              hintStyle: TextStyle(
                fontWeight: FontWeight.w400,
                fontFamily: fontFamilyMontserrat,
                fontSize: 16,
                color: AppColors.color555555,
              ),
              suffixIcon: IconButton(
                icon: const Icon(Icons.qr_code_scanner),
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const QRScannerScreen()),
                  );
                  if (result != null && result is String) {
                    widget.serialController.text = result;
                    if (widget.onSerialChanged != null) {
                      widget.onSerialChanged!(result);
                    }
                  }
                },
              ),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(5),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 16),

                     // Photo Picker
           RichText(
             text: TextSpan(
               children: [
                 TextSpan(
                   text: widget.photoLabel,
                   style: const TextStyle(
                     fontWeight: FontWeight.w400,
                     fontFamily: fontFamilyMontserrat,
                     fontSize: 16,
                     color: AppColors.white,
                   ),
                 ),
                 const TextSpan(
                   text: " *",
                   style: TextStyle(
                     fontWeight: FontWeight.w400,
                     fontFamily: fontFamilyMontserrat,
                     fontSize: 16,
                     color: AppColors.errorColor,
                   ),
                 ),
               ],
             ),
           ),
          const SizedBox(height: 6),
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
              child: _selectedImage == null
                  ? Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.camera_alt_outlined, size: 20, color: AppColors.color555555),
                          const SizedBox(width: 6),
                          Text(
                            widget.photoLabel,
                            style: const TextStyle(
                              fontWeight: FontWeight.w400,
                              color: AppColors.color555555,
                              fontFamily: fontFamilyMontserrat,
                            ),
                          ),
                        ],
                      ),
                    )
                  : Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(5),
                          child: Image.file(
                            _selectedImage!,
                            fit: BoxFit.contain,
                            width: double.infinity,
                          ),
                        ),
                        // Delete button
                        Positioned(
                          top: 8,
                          right: 8,
                          child: GestureDetector(
                            onTap: _deleteImage,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.8),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 16),

          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: widget.statusLabel,
                  style: const TextStyle(
                    fontWeight: FontWeight.w400,
                    fontFamily: fontFamilyMontserrat,
                    fontSize: 16,
                    color: AppColors.white,
                  ),
                ),
                const TextSpan(
                  text: " *",
                  style: TextStyle(
                    fontWeight: FontWeight.w400,
                    fontFamily: fontFamilyMontserrat,
                    fontSize: 16,
                    color: AppColors.errorColor,
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [

              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Radio<bool>(
                            value: true,
                            groupValue: selectedStatus,
                            onChanged: (val) {
                              setState(() {
                                selectedStatus = val;
                              });
                              widget.onStatusChanged(val!);
                            },
                            activeColor: const Color(0xFF5678BA),
                            fillColor: MaterialStateProperty.resolveWith<Color>((states) {
                              if (states.contains(MaterialState.selected)) {
                                return const Color(0xFF5678BA);
                              }
                              return Colors.white;
                            }),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            "Ok",
                            style: TextStyle(
                              color: AppColors.white,
                              fontSize: 16,
                              fontFamily: fontFamilyMontserrat,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Row(
                        children: [
                          Radio<bool>(
                            value: false,
                            groupValue: selectedStatus,
                            onChanged: (val) {
                              setState(() {
                                selectedStatus = val;
                              });
                              widget.onStatusChanged(val!);
                            },
                            activeColor: const Color(0xFF5678BA),
                            fillColor: MaterialStateProperty.resolveWith<Color>((states) {
                              if (states.contains(MaterialState.selected)) {
                                return const Color(0xFF5678BA);
                              }
                              return Colors.white;
                            }),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            "Not Ok",
                            style: TextStyle(
                              color: AppColors.white,
                              fontSize: 16,
                              fontFamily: fontFamilyMontserrat,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(width: 50),
              
              // Save button in same row
              ElevatedButton(
                onPressed: widget.onSave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDBE2F0),
                  foregroundColor: const Color(0xFF2D426E),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
                child: Text(widget.buttonLabel),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
