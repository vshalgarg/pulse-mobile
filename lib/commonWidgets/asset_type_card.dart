import 'dart:convert';
import 'dart:io';

import 'package:app/constants/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:app/utils/image_compression_helper.dart';
import 'package:app/utils/logger.dart';

import '../constants/constants_strings.dart';
import '../screens/qrScannerScreen.dart';




class CustomInfoCard extends StatefulWidget {
  final String serialLabel;
  final String photoLabel;
  final String statusLabel;
  final String buttonLabel;
  final TextEditingController serialController;
  final VoidCallback? onSave;
  final Function(String?) onPhotoTap;
  final ValueChanged<bool> onStatusChanged;
  final ValueChanged<String>? onSerialChanged;
  final bool? initialStatus;
  final String? initialPhotoPath;
  final bool isEditable; // Controls if the text field and other inputs are editable
  final bool isStatusEditable; // Controls if the status radio buttons are editable
  final bool? backendStatus; // New parameter for backend status value
  final String? serialHintText; // New parameter for hint text
  final String? remarksLabel; // Optional remarks field label
  final String? remarksHintText; // Optional remarks field hint text
  final TextEditingController? remarksController; // Optional remarks controller
  final ValueChanged<String>? onRemarksChanged; // Optional remarks change callback
  final bool showSaveButton; // Controls whether to show the save button
  final bool isRemarksEditable; // Controls if the remarks field is editable

  const CustomInfoCard({
    super.key,
    required this.serialLabel,
    required this.photoLabel,
    required this.statusLabel,
    this.buttonLabel = "Save",
    required this.serialController,
     this.onSave,
    required this.onPhotoTap,
    required this.onStatusChanged,
    this.onSerialChanged,
    this.initialStatus,
    this.initialPhotoPath,
    required this.isEditable,
    this.isStatusEditable = true,
    this.backendStatus,
    this.serialHintText, // New parameter
    this.remarksLabel, // Optional remarks field
    this.remarksHintText, // Optional remarks hint
    this.remarksController, // Optional remarks controller
    this.onRemarksChanged, // Optional remarks callback
    this.showSaveButton = true, // Default to true for backward compatibility
    this.isRemarksEditable = false, // Default to true for backward compatibility
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
      // Check if it's a file path or photo ID/base64 data
      if (_isFilePath(widget.initialPhotoPath!)) {
        _selectedImage = File(widget.initialPhotoPath!);
      }
      // For photo IDs or base64 data, we'll handle them in the build method
    }
  }

  // Helper method to check if the path is a valid file path
  bool _isFilePath(String path) {
    // Check if it's a numeric string (photo ID) or base64 data
    if (int.tryParse(path) != null || path.startsWith('data:image')) {
      return false;
    }
    // Check if it's a valid file path
    return path.contains('/') || path.contains('\\') || path.endsWith('.jpg') || path.endsWith('.png') || path.endsWith('.jpeg');
  }

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
        Logger.imageLog('CustomInfoCard: Starting image compression...');
        // Compress the image to 2MB
        final compressedFile = await ImageCompressionHelper.compressImageTo2MB(originalFile);
        Logger.imageLog('CustomInfoCard: Compression completed, result: ${compressedFile != null ? "Success" : "Failed"}');
        
        // Close loading dialog
        if (mounted) {
          Navigator.of(context).pop();
        }

        if (compressedFile != null) {
          setState(() {
            _selectedImage = compressedFile;
          });
          // Call the callback with the compressed file path
          widget.onPhotoTap(_selectedImage!.path);
        } else {
          // If compression fails, use original file
          setState(() {
            _selectedImage = originalFile;
          });
          widget.onPhotoTap(_selectedImage!.path);
          
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
        widget.onPhotoTap(_selectedImage!.path);
        
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

  void _deleteImage() {
    setState(() {
      _selectedImage = null;
    });
    widget.onPhotoTap(null);
  }

  // Check if we should show an image
  bool _shouldShowImage() {
    return _selectedImage != null || 
           (widget.initialPhotoPath != null && !_isFilePath(widget.initialPhotoPath!));
  }

  // Build the appropriate image widget based on the image type
  Widget _buildImageWidget() {
    if (_selectedImage != null) {
      // File image
      return Image.file(
        _selectedImage!,
        fit: BoxFit.cover,
        width: double.infinity,
        errorBuilder: (context, error, stackTrace) {
          return _buildErrorWidget('Failed to load image');
        },
      );
    } else if (widget.initialPhotoPath != null) {
      if (widget.initialPhotoPath!.startsWith('data:image')) {
        // Base64 image data - validate format first
        try {
          if (!widget.initialPhotoPath!.contains(',')) {
            return _buildErrorWidget('Invalid image format');
          }
          
          final parts = widget.initialPhotoPath!.split(',');
          if (parts.length != 2 || parts[1].isEmpty) {
            return _buildErrorWidget('Invalid image data');
          }
          
          final base64Data = parts[1];
          final bytes = base64Decode(base64Data);
          
          return Image.memory(
            bytes,
            fit: BoxFit.cover,
            width: double.infinity,
            errorBuilder: (context, error, stackTrace) {
              return _buildErrorWidget('Image display error');
            },
          );
        } catch (e) {
          return _buildErrorWidget('Image decode error');
        }
      } else if (int.tryParse(widget.initialPhotoPath!) != null) {
        // Photo ID - show placeholder without loading indicator
        return Container(
          color: Colors.grey.shade300,
          child: const Center(
            child: Icon(
              Icons.image,
              color: Colors.grey,
              size: 48,
            ),
          ),
        );
      }
    }
    
    // Fallback
    return _buildErrorWidget('Unsupported image type');
  }

  // Helper method to build error widget
  Widget _buildErrorWidget(String message) {
    return Container(
      color: Colors.grey.shade300,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, color: Colors.red, size: 24),
            const SizedBox(height: 4),
            Text(
              message,
              style: const TextStyle(
                color: Colors.red,
                fontSize: 12,
                fontFamily: fontFamilyMontserrat,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
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
              hintText: widget.serialHintText ?? widget.serialLabel,
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
              ) : null,
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
              child: _shouldShowImage()
                  ? Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(5),
                          child: _buildImageWidget(),
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
                    )
                  : Center(
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
                    ),
            ),
          ),
          const SizedBox(height: 16),

          if (widget.remarksLabel != null) ...[
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Label with optional *
                Row(
                  children: [
                    Text(
                    widget.remarksLabel!,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                        fontFamily: fontFamilyMontserrat,
                      ),
                    ),
                    // if (isRequired)
                      const Text(
                        " *",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.errorColor,
                          fontFamily: fontFamilyMontserrat,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 5),

                // Input field
                TextFormField(
                  controller: widget.remarksController,
                  readOnly: !widget.isRemarksEditable,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: widget.isRemarksEditable ? Colors.white : AppColors.borderColorE0E0E0, // Grey when not editable
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 16,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(5),
                      borderSide: BorderSide.none,
                    ),
                    hintText: widget.remarksHintText ?? widget.remarksLabel, // Show hint text if provided
                    hintStyle: TextStyle(
                      fontWeight: FontWeight.w400,
                      fontFamily: fontFamilyMontserrat,
                      fontSize: 16,
                      color: AppColors.color555555.withOpacity(0.6), // Slightly transparent for hint
                    ),
                  ),
                  style: TextStyle(
                    fontWeight: FontWeight.w400,
                      fontFamily: fontFamilyMontserrat,
                      fontSize: 16,
                      color: AppColors.color555555
                  ),
                  validator: (value) {
                    // Remarks is optional, so no validation required
                    return null;
                  },
                  onFieldSubmitted: (value) {
                    // Trigger validation
                  },
                  onChanged: widget.onRemarksChanged,
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],

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
                  const SizedBox(width: 20),
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
              
              // Only show Spacer and Save button if showSaveButton is true
              if (widget.showSaveButton) ...[
                const Spacer(),
                
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
            ],
          ),
        ],
      ),
    );
  }
}
