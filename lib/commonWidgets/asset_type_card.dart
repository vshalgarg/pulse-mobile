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
  final bool isEditable; // Controls if the text field and other inputs are editable
  final bool isStatusEditable; // Controls if the status radio buttons are editable
  final bool? backendStatus; // New parameter for backend status value

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
    required this.isEditable,
    this.isStatusEditable = true,
    this.backendStatus,
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
    // Initialize with backend status if not editable, otherwise use initial status
    if (!widget.isStatusEditable && widget.backendStatus != null) {
      selectedStatus = widget.backendStatus;
    } else {
      selectedStatus = widget.initialStatus;
    }
    
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
          // Read-only indicator
          if (!widget.isEditable)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.8),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                "Read Only",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  fontFamily: fontFamilyMontserrat,
                ),
              ),
            ),
          
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
            enabled: widget.isEditable,
            onChanged: widget.isEditable ? (value) {
              if (widget.onSerialChanged != null) {
                widget.onSerialChanged!(value);
              }
            } : null,
            decoration: InputDecoration(
              hintText: widget.serialLabel,
              hintStyle: TextStyle(
                fontWeight: FontWeight.w400,
                fontFamily: fontFamilyMontserrat,
                fontSize: 16,
                color: AppColors.color555555,
              ),
              suffixIcon: widget.isEditable ? IconButton(
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
              ) : null, // Hide QR scanner icon if not editable
              filled: true,
              fillColor: widget.isEditable ? Colors.white : Colors.grey.shade200,
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
              // Radio buttons section - more compact
              Row(
                children: [
                  Row(
                    children: [
                      Radio<bool>(
                        value: true,
                        groupValue: selectedStatus,
                        onChanged: widget.isStatusEditable ? (val) {
                          setState(() {
                            selectedStatus = val;
                          });
                          widget.onStatusChanged(val!);
                        } : null, // Disable radio button if not editable
                        activeColor: const Color(0xFF5678BA),
                        fillColor: MaterialStateProperty.resolveWith<Color>((states) {
                          if (states.contains(MaterialState.selected)) {
                            return const Color(0xFF5678BA);
                          }
                          return Colors.white;
                        }),
                      ),
                      const SizedBox(width: 4), // Reduced spacing
                      Text(
                        "Ok",
                        style: TextStyle(
                          color: widget.isStatusEditable ? AppColors.white : AppColors.white.withOpacity(0.6),
                          fontSize: 16,
                          fontFamily: fontFamilyMontserrat,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 20), // Reduced spacing between radio groups
                  Row(
                    children: [
                      Radio<bool>(
                        value: false,
                        groupValue: selectedStatus,
                        onChanged: widget.isStatusEditable ? (val) {
                          setState(() {
                            selectedStatus = val;
                          });
                          widget.onStatusChanged(val!);
                        } : null, // Disable radio button if not editable
                        activeColor: const Color(0xFF5678BA),
                        fillColor: MaterialStateProperty.resolveWith<Color>((states) {
                          if (states.contains(MaterialState.selected)) {
                            return const Color(0xFF5678BA);
                          }
                          return Colors.white;
                        }),
                      ),
                      const SizedBox(width: 4), // Reduced spacing
                      Text(
                        "Not Ok",
                        style: TextStyle(
                          color: widget.isStatusEditable ? AppColors.white : AppColors.white.withOpacity(0.6),
                          fontSize: 16,
                          fontFamily: fontFamilyMontserrat,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              
              const Spacer(), // This will push the save button to the right
              
              // Save button
              ElevatedButton(
                onPressed: widget.isEditable ? widget.onSave : null, // Disable button if not editable
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.isEditable ? const Color(0xFFDBE2F0) : Colors.grey.shade400,
                  foregroundColor: widget.isEditable ? const Color(0xFF2D426E) : Colors.grey.shade600,
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
