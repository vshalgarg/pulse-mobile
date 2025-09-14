import 'dart:convert';
import 'dart:io';

import 'package:app/constants/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:app/utils/image_compression_helper.dart';
import 'package:app/utils/logger.dart';

import '../constants/constants_strings.dart';
import '../screens/qrScannerScreen.dart';

/// Validation rule types for different field validations
enum ValidationRule {
  required,
  minLength,
  maxLength,
  email,
  numeric,
  alphanumeric,
  serialNumber,
  custom,
}

/// Validation result containing error message and validity status
class ValidationResult {
  final bool isValid;
  final String? errorMessage;
  
  const ValidationResult({required this.isValid, this.errorMessage});
  
  const ValidationResult.valid() : isValid = true, errorMessage = null;
  const ValidationResult.invalid(String message) : isValid = false, errorMessage = message;
}

/// Validation configuration for a field
class ValidationConfig {
  final ValidationRule rule;
  final String? customErrorMessage;
  final int? minLength;
  final int? maxLength;
  final String? customPattern;
  final bool Function(String)? customValidator;
  
  const ValidationConfig({
    required this.rule,
    this.customErrorMessage,
    this.minLength,
    this.maxLength,
    this.customPattern,
    this.customValidator,
  });
  
  /// Validate the input value
  ValidationResult validate(String? value) {
    if (value == null || value.isEmpty) {
      if (rule == ValidationRule.required) {
        return ValidationResult.invalid(customErrorMessage ?? 'This field is required');
      }
      return const ValidationResult.valid();
    }
    
    switch (rule) {
      case ValidationRule.required:
        return value.trim().isEmpty 
            ? ValidationResult.invalid(customErrorMessage ?? 'This field is required')
            : const ValidationResult.valid();
            
      case ValidationRule.minLength:
        if (minLength != null && value.length < minLength!) {
          return ValidationResult.invalid(
            customErrorMessage ?? 'Minimum length is $minLength characters'
          );
        }
        return const ValidationResult.valid();
        
      case ValidationRule.maxLength:
        if (maxLength != null && value.length > maxLength!) {
          return ValidationResult.invalid(
            customErrorMessage ?? 'Maximum length is $maxLength characters'
          );
        }
        return const ValidationResult.valid();
        
      case ValidationRule.email:
        final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
        return emailRegex.hasMatch(value)
            ? const ValidationResult.valid()
            : ValidationResult.invalid(customErrorMessage ?? 'Please enter a valid email');
            
      case ValidationRule.numeric:
        final numericRegex = RegExp(r'^\d+$');
        return numericRegex.hasMatch(value)
            ? const ValidationResult.valid()
            : ValidationResult.invalid(customErrorMessage ?? 'Please enter only numbers');
            
      case ValidationRule.alphanumeric:
        final alphanumericRegex = RegExp(r'^[a-zA-Z0-9]+$');
        return alphanumericRegex.hasMatch(value)
            ? const ValidationResult.valid()
            : ValidationResult.invalid(customErrorMessage ?? 'Please enter only letters and numbers');
            
      case ValidationRule.serialNumber:
        final serialRegex = RegExp(r'^[A-Za-z0-9\-_]+$');
        return serialRegex.hasMatch(value)
            ? const ValidationResult.valid()
            : ValidationResult.invalid(customErrorMessage ?? 'Please enter a valid serial number');
            
      case ValidationRule.custom:
        if (customValidator != null) {
          return customValidator!(value)
              ? const ValidationResult.valid()
              : ValidationResult.invalid(customErrorMessage ?? 'Invalid input');
        }
        return const ValidationResult.valid();
    }
  }
}

/// A highly reusable asset audit component that includes:
/// - Text field with QR scanner
/// - Image picker with compression
/// - Status selection (OK/Not OK)
/// - Optional remarks field
/// - Save functionality
/// - Table display of saved items
/// - Built-in validation system
/// - Configurable properties for different use cases
class ReusableAssetAuditComponent extends StatefulWidget {
  // Required properties
  final String componentId; // Unique identifier for this component instance
  final String serialLabel;
  final String photoLabel;
  final String statusLabel;
  final TextEditingController serialController;
  final VoidCallback? onSave;
  final Function(String?) onPhotoTap;
  final ValueChanged<bool> onStatusChanged;
  final List<Map<String, dynamic>> savedItems; // List of saved items to display in table
  final Function(Map<String, dynamic>) onItemDeleted; // Callback when item is deleted from table

  // Optional properties with defaults
  final String buttonLabel;
  final ValueChanged<String>? onSerialChanged;
  final bool? initialStatus;
  final String? initialPhotoPath;
  final bool isEditable;
  final bool isStatusEditable;
  final bool? backendStatus;
  final String? serialHintText;
  final String? remarksLabel;
  final String? remarksHintText;
  final TextEditingController? remarksController;
  final ValueChanged<String>? onRemarksChanged;
  final bool showSaveButton;
  final bool isRemarksEditable;
  final bool showTable; // Whether to show the saved items table
  final String tableTitle; // Title for the saved items table
  final List<String> tableColumns; // Column headers for the table
  final Function(Map<String, dynamic>) onItemSelected; // Callback when item is selected from table
  final bool enableQRScanner; // Whether to enable QR scanner functionality
  final bool enableImageCompression; // Whether to compress images
  final double imageHeight; // Height of the image picker area
  final Color backgroundColor; // Background color of the component
  final Color borderColor; // Border color of the component
  final EdgeInsets padding; // Padding inside the component
  final EdgeInsets margin; // Margin around the component
  
  // Validation properties
  final ValidationConfig? serialValidation; // Validation rules for serial number field
  final ValidationConfig? remarksValidation; // Validation rules for remarks field
  final bool requirePhoto; // Whether photo is required
  final bool requireStatus; // Whether status selection is required
  final bool validateOnChange; // Whether to validate fields on change
  final bool validateOnSave; // Whether to validate all fields before saving
  final VoidCallback? onValidationFailed; // Callback when validation fails
  final VoidCallback? onValidationPassed; // Callback when validation passes

  const ReusableAssetAuditComponent({
    super.key,
    required this.componentId,
    required this.serialLabel,
    required this.photoLabel,
    required this.statusLabel,
    required this.serialController,
    required this.savedItems,
    required this.onItemDeleted,
    this.onSave,
    required this.onPhotoTap,
    required this.onStatusChanged,
    this.buttonLabel = "Save",
    this.onSerialChanged,
    this.initialStatus,
    this.initialPhotoPath,
    this.isEditable = true,
    this.isStatusEditable = true,
    this.backendStatus,
    this.serialHintText,
    this.remarksLabel,
    this.remarksHintText,
    this.remarksController,
    this.onRemarksChanged,
    this.showSaveButton = true,
    this.isRemarksEditable = false,
    this.showTable = true,
    this.tableTitle = "Saved Items",
    this.tableColumns = const ["Serial Number", "Status", "Photo", "Remarks", "Actions"],
    this.onItemSelected,
    this.enableQRScanner = true,
    this.enableImageCompression = true,
    this.imageHeight = 150.0,
    this.backgroundColor = AppColors.green7,
    this.borderColor = Colors.grey,
    this.padding = const EdgeInsets.all(16),
    this.margin = const EdgeInsets.symmetric(vertical: 10),
    
    // Validation defaults
    this.serialValidation,
    this.remarksValidation,
    this.requirePhoto = false,
    this.requireStatus = false,
    this.validateOnChange = false,
    this.validateOnSave = true,
    this.onValidationFailed,
    this.onValidationPassed,
  });

  @override
  State<ReusableAssetAuditComponent> createState() => _ReusableAssetAuditComponentState();
}

class _ReusableAssetAuditComponentState extends State<ReusableAssetAuditComponent> {
  bool? selectedStatus;
  File? _selectedImage;
  
  // Validation state
  String? _serialError;
  String? _remarksError;
  String? _photoError;
  String? _statusError;
  bool _hasValidated = false;

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
    }
  }

  // Validation methods
  void _validateSerial(String? value) {
    if (widget.serialValidation != null) {
      final result = widget.serialValidation!.validate(value);
      setState(() {
        _serialError = result.isValid ? null : result.errorMessage;
      });
    }
  }

  void _validateRemarks(String? value) {
    if (widget.remarksValidation != null) {
      final result = widget.remarksValidation!.validate(value);
      setState(() {
        _remarksError = result.isValid ? null : result.errorMessage;
      });
    }
  }

  void _validatePhoto() {
    setState(() {
      if (widget.requirePhoto && _selectedImage == null && widget.initialPhotoPath == null) {
        _photoError = 'Photo is required';
      } else {
        _photoError = null;
      }
    });
  }

  void _validateStatus() {
    setState(() {
      if (widget.requireStatus && selectedStatus == null) {
        _statusError = 'Status selection is required';
      } else {
        _statusError = null;
      }
    });
  }

  bool _validateAllFields() {
    _hasValidated = true;
    
    // Validate serial number
    _validateSerial(widget.serialController.text);
    
    // Validate remarks if controller exists
    if (widget.remarksController != null) {
      _validateRemarks(widget.remarksController!.text);
    }
    
    // Validate photo
    _validatePhoto();
    
    // Validate status
    _validateStatus();
    
    // Check if all validations pass
    final hasErrors = _serialError != null || 
                     _remarksError != null || 
                     _photoError != null || 
                     _statusError != null;
    
    if (hasErrors) {
      widget.onValidationFailed?.call();
      return false;
    } else {
      widget.onValidationPassed?.call();
      return true;
    }
  }

  void _clearValidationErrors() {
    setState(() {
      _serialError = null;
      _remarksError = null;
      _photoError = null;
      _statusError = null;
      _hasValidated = false;
    });
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
    if (!widget.isEditable) return;
    
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.camera);

    if (pickedFile != null) {
      final originalFile = File(pickedFile.path);
      
      // Show loading indicator while compressing (if compression is enabled)
      if (widget.enableImageCompression) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(
              color: AppColors.primaryGreen,
            ),
          ),
        );
      }

      try {
        File? finalFile;
        
        if (widget.enableImageCompression) {
          Logger.imageLog('ReusableAssetAuditComponent: Starting image compression...');
          finalFile = await ImageCompressionHelper.compressImageTo2MB(originalFile);
          Logger.imageLog('ReusableAssetAuditComponent: Compression completed, result: ${finalFile != null ? "Success" : "Failed"}');
          
          // Close loading dialog
          if (mounted && widget.enableImageCompression) {
            Navigator.of(context).pop();
          }
        } else {
          finalFile = originalFile;
        }

        if (finalFile != null) {
          setState(() {
            _selectedImage = finalFile;
          });
          widget.onPhotoTap(_selectedImage!.path);
          // Validate photo if validation is enabled
          if (widget.validateOnChange) {
            _validatePhoto();
          }
        } else if (widget.enableImageCompression) {
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
        // Close loading dialog if compression was enabled
        if (mounted && widget.enableImageCompression) {
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
              content: Text('Error processing image: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _deleteImage() {
    if (!widget.isEditable) return;
    
    setState(() {
      _selectedImage = null;
    });
    widget.onPhotoTap(null);
    // Validate photo if validation is enabled
    if (widget.validateOnChange) {
      _validatePhoto();
    }
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
        height: widget.imageHeight,
        errorBuilder: (context, error, stackTrace) {
          return _buildErrorWidget('Failed to load image');
        },
      );
    } else if (widget.initialPhotoPath != null) {
      if (widget.initialPhotoPath!.startsWith('data:image')) {
        // Base64 image data
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
            height: widget.imageHeight,
            errorBuilder: (context, error, stackTrace) {
              return _buildErrorWidget('Image display error');
            },
          );
        } catch (e) {
          return _buildErrorWidget('Image decode error');
        }
      } else if (int.tryParse(widget.initialPhotoPath!) != null) {
        // Photo ID - show placeholder
        return Container(
          height: widget.imageHeight,
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
      height: widget.imageHeight,
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

  // Build the saved items table
  Widget _buildSavedItemsTable() {
    if (!widget.showTable || widget.savedItems.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.tableTitle,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              fontFamily: fontFamilyMontserrat,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: widget.tableColumns.map((column) => DataColumn(
                  label: Text(
                    column,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontFamily: fontFamilyMontserrat,
                    ),
                  ),
                )).toList(),
                rows: widget.savedItems.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;
                  
                  return DataRow(
                    cells: [
                      DataCell(Text(item['serialNumber'] ?? '')),
                      DataCell(Text(item['status'] == true ? 'OK' : 'Not OK')),
                      DataCell(
                        item['photo'] != null 
                          ? Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.grey),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: _buildTableImageWidget(item['photo']),
                              ),
                            )
                          : const Icon(Icons.image_not_supported, size: 20),
                      ),
                      DataCell(Text(item['remarks'] ?? '')),
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (widget.onItemSelected != null)
                              IconButton(
                                icon: const Icon(Icons.edit, size: 16),
                                onPressed: () => widget.onItemSelected!(item),
                                tooltip: 'Edit',
                              ),
                            IconButton(
                              icon: const Icon(Icons.delete, size: 16, color: Colors.red),
                              onPressed: () => widget.onItemDeleted(item),
                              tooltip: 'Delete',
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Build image widget for table display
  Widget _buildTableImageWidget(String? photoPath) {
    if (photoPath == null || photoPath.isEmpty) {
      return const Icon(Icons.image_not_supported, size: 20);
    }

    if (photoPath.startsWith('data:image')) {
      try {
        final parts = photoPath.split(',');
        if (parts.length == 2) {
          final base64Data = parts[1];
          final bytes = base64Decode(base64Data);
          return Image.memory(
            bytes,
            fit: BoxFit.cover,
            width: 40,
            height: 40,
            errorBuilder: (context, error, stackTrace) {
              return const Icon(Icons.error, size: 20, color: Colors.red);
            },
          );
        }
      } catch (e) {
        return const Icon(Icons.error, size: 20, color: Colors.red);
      }
    } else if (_isFilePath(photoPath)) {
      return Image.file(
        File(photoPath),
        fit: BoxFit.cover,
        width: 40,
        height: 40,
        errorBuilder: (context, error, stackTrace) {
          return const Icon(Icons.error, size: 20, color: Colors.red);
        },
      );
    }

    return const Icon(Icons.image_not_supported, size: 20);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: widget.margin,
      padding: widget.padding,
      decoration: BoxDecoration(
        color: widget.backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: widget.borderColor),
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
          _buildLabelWithRequired(widget.serialLabel),
          const SizedBox(height: 6),
          TextFormField(
            controller: widget.serialController,
            enabled: widget.isEditable,
            onChanged: widget.isEditable ? (value) {
              if (widget.onSerialChanged != null) {
                widget.onSerialChanged!(value);
              }
              // Validate on change if enabled
              if (widget.validateOnChange) {
                _validateSerial(value);
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
              suffixIcon: widget.isEditable && widget.enableQRScanner ? IconButton(
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
          // Serial number error display
          if (_serialError != null && _hasValidated)
            _buildFieldErrorWidget(_serialError!),
          const SizedBox(height: 16),

          // Photo Picker
          _buildLabelWithRequired(widget.photoLabel),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: widget.isEditable ? _pickImage : null,
            child: Container(
              width: double.infinity,
              height: widget.imageHeight,
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
                        if (widget.isEditable)
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
          // Photo error display
          if (_photoError != null && _hasValidated)
            _buildFieldErrorWidget(_photoError!),
          const SizedBox(height: 16),

          // Optional Remarks field
          if (widget.remarksLabel != null) ...[
            _buildLabelWithRequired(widget.remarksLabel!),
            const SizedBox(height: 5),
            TextFormField(
              controller: widget.remarksController,
              readOnly: !widget.isRemarksEditable,
              decoration: InputDecoration(
                filled: true,
                fillColor: widget.isRemarksEditable ? Colors.white : AppColors.borderColorE0E0E0,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 16,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(5),
                  borderSide: BorderSide.none,
                ),
                hintText: widget.remarksHintText ?? widget.remarksLabel,
                hintStyle: TextStyle(
                  fontWeight: FontWeight.w400,
                  fontFamily: fontFamilyMontserrat,
                  fontSize: 16,
                  color: AppColors.color555555.withOpacity(0.6),
                ),
              ),
              style: const TextStyle(
                fontWeight: FontWeight.w400,
                fontFamily: fontFamilyMontserrat,
                fontSize: 16,
                color: AppColors.color555555,
              ),
              onChanged: (value) {
                if (widget.onRemarksChanged != null) {
                  widget.onRemarksChanged!(value);
                }
                // Validate on change if enabled
                if (widget.validateOnChange) {
                  _validateRemarks(value);
                }
              },
            ),
            // Remarks error display
            if (_remarksError != null && _hasValidated)
              _buildFieldErrorWidget(_remarksError!),
            const SizedBox(height: 16),
          ],

          // Status selection
          _buildLabelWithRequired(widget.statusLabel),
          Row(
            children: [
              // Radio buttons section
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
                          // Validate on change if enabled
                          if (widget.validateOnChange) {
                            _validateStatus();
                          }
                        } : null,
                        activeColor: const Color(0xFF5678BA),
                        fillColor: MaterialStateProperty.resolveWith<Color>((states) {
                          if (states.contains(MaterialState.selected)) {
                            return const Color(0xFF5678BA);
                          }
                          return Colors.white;
                        }),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        "Ok",
                        style: TextStyle(
                          color: widget.isStatusEditable ? Colors.white : Colors.white.withOpacity(0.6),
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
                          // Validate on change if enabled
                          if (widget.validateOnChange) {
                            _validateStatus();
                          }
                        } : null,
                        activeColor: const Color(0xFF5678BA),
                        fillColor: MaterialStateProperty.resolveWith<Color>((states) {
                          if (states.contains(MaterialState.selected)) {
                            return const Color(0xFF5678BA);
                          }
                          return Colors.white;
                        }),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        "Not Ok",
                        style: TextStyle(
                          color: widget.isStatusEditable ? Colors.white : Colors.white.withOpacity(0.6),
                          fontSize: 16,
                          fontFamily: fontFamilyMontserrat,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            
            // Status error display
            if (_statusError != null && _hasValidated)
              _buildFieldErrorWidget(_statusError!),
            
            // Save button
            if (widget.showSaveButton) ...[
                const Spacer(),
                ElevatedButton(
                  onPressed: widget.isEditable ? () {
                    // Validate all fields before saving if validation is enabled
                    if (widget.validateOnSave) {
                      if (_validateAllFields()) {
                        widget.onSave?.call();
                      }
                    } else {
                      widget.onSave?.call();
                    }
                  } : null,
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

          // Saved items table
          _buildSavedItemsTable(),
        ],
      ),
    );
  }

  // Helper method to build field error widget
  Widget _buildFieldErrorWidget(String errorMessage) {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline,
            color: Colors.red,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              errorMessage,
              style: const TextStyle(
                color: Colors.red,
                fontSize: 12,
                fontFamily: fontFamilyMontserrat,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper method to build label with required asterisk
  Widget _buildLabelWithRequired(String label) {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: label,
            style: const TextStyle(
              fontWeight: FontWeight.w400,
              fontFamily: fontFamilyMontserrat,
              fontSize: 16,
              color: Colors.white,
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
    );
  }
}
