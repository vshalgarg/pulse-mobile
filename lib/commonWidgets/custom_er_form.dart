import 'dart:convert';
import 'dart:io';

import 'package:app/services/service_locator.dart';
import 'package:flutter/material.dart';
import 'package:app/constants/app_colors.dart';
import 'package:app/constants/constants_methods.dart';
import 'package:app/commonWidgets/custom_form_field.dart';
import 'package:app/commonWidgets/custom_image_upload_field.dart';
import 'package:app/services/image_upload_service.dart';
import 'package:app/enum/activity_type_enum.dart';
import 'package:app/app_config.dart';
import 'package:app/utils/logger.dart';

class CustomErForm extends StatefulWidget {
  final String sectionTitle;
  final String? inputLabel;
  final String? inputHintText;
  final String? inputInitialValue;
  final bool isInputRequired;
  final bool isInputEditable;
  final TextEditingController? inputController;
  final Function(String)? onInputChanged;

  final String? photoLabel;
  final bool isPhotoRequired;
  final String? photoHintText;
  final String? uploadedImageId;
  final Function(String?)? onImageSelected;

  final String? statusLabel;
  final bool isStatusRequired;
  final String? statusInitialValue;
  final Function(String?)? onStatusChanged;

  final String siteAuditSchId;
  final bool showTitle;
  final bool showStatus;
  final ActivityTypeEnum? activityType;

  const CustomErForm({
    super.key,
    required this.sectionTitle,
    this.inputLabel,
    this.inputHintText,
    this.inputInitialValue,
    this.isInputRequired = false,
    this.isInputEditable = true,
    this.inputController,
    this.onInputChanged,

    this.photoLabel,
    this.isPhotoRequired = false,
    this.photoHintText,
    this.uploadedImageId,
    this.onImageSelected,

    this.statusLabel,
    this.isStatusRequired = false,
    this.statusInitialValue,
    this.onStatusChanged,

    required this.siteAuditSchId,
    this.showTitle = true,
    this.showStatus = true,

    this.activityType,
  });

  @override
  State<CustomErForm> createState() => _CustomErFormState();
}

class _CustomErFormState extends State<CustomErForm> {
  String? _uploadedImgId;
  String? _selectedStatus;
  String? _selectedPhotoPath;

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.statusInitialValue ?? "Ok";
    _uploadedImgId = widget.uploadedImageId;
    _fetchAndDisplayServerImage(widget.uploadedImageId ?? "");
  }

  Future<void> _onImageSelected(File imageFile) async {
    try {
      Logger.debugLog('📸 CustomAssetAuditFormSection: Starting image upload');

      // Get API service from context
      final apiService = AppConfig.of(context).apiService;
      final imageUploadService = ImageUploadService(apiService: apiService);

      // Upload image using ImageUploadService
      final uniqueId = await imageUploadService.uploadImage(
        await imageFile.readAsBytes().then((bytes) => base64Encode(bytes)),
        ActivityTypeEnum.assetAudit,
        false,
        widget.siteAuditSchId,
      );

      if (uniqueId.isNotEmpty) {
        setState(() {
          _uploadedImgId = uniqueId;
        });

        // Notify parent component
        widget.onImageSelected?.call(uniqueId);

        Logger.debugLog(
          '✅ CustomAssetAuditFormSection: Image uploaded successfully with ID: $uniqueId',
        );
      } else {
        Logger.errorLog(
          '❌ CustomAssetAuditFormSection: Failed to upload image',
        );
        _showErrorSnackBar('Failed to upload image');
      }
    } catch (e) {
      Logger.errorLog(
        '❌ CustomAssetAuditFormSection: Error uploading image: $e',
      );
      _showErrorSnackBar('Error uploading image: $e');
    }
  }

  void _onStatusChanged(String? value) {
    setState(() {
      _selectedStatus = value;
    });

    // Notify parent component
    widget.onStatusChanged?.call(value);
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: AppColors.errorColor),
      );
    }
  }

  // Fetches and displays server image for editing using ImageUploadService
  Future<void> _fetchAndDisplayServerImage(String uniqueId) async {
    try {
      // Use ImageUploadService to get image data
      final imageData = await ServiceLocator().centralAssetAuditService
          .getImageAsDataUrl(uniqueId);

      if (mounted && imageData != null && imageData.isNotEmpty) {
        // Ensure the image data has proper data URL format
        final finalImageData = imageData.startsWith('data:image/')
            ? imageData
            : 'data:image/jpeg;base64,$imageData';

        setState(() {
          _selectedPhotoPath =
              finalImageData; // Store as base64 data for display
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _selectedPhotoPath = uniqueId;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Title (optional)
        if (widget.showTitle) ...[
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  widget.sectionTitle,
                  style: TextStyle(
                    color: AppColors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),

              const Text(
                ' *',
                style: TextStyle(color: Colors.red, fontSize: 16),
              ),
            ],
          ),

          getHeight(15),
        ],

        // Input Field (optional)
        if (widget.inputLabel != null) ...[
          CustomFormField(
            label: widget.inputLabel!,
            initialValue: widget.inputInitialValue ?? "",
            isRequired: widget.isInputRequired,
            isEditable: widget.isInputEditable,
            controller: widget.inputController,
            onChanged: widget.onInputChanged,
            hintText: widget.inputHintText,
          ),
          getHeight(15),
        ],

        // Photo Upload Section (optional)
        if (widget.photoLabel != null) ...[
          ImageUploadField(
            label: widget.photoLabel ?? "Add a Photo",
            placeholder: widget.photoHintText ?? "Add a Photo",
            isRequired: widget.isPhotoRequired,
            onImageSelected: (File? file) {
              if (file != null) {
                _onImageSelected(file);
              }
            },
            externalImageUrl: _selectedPhotoPath ?? "",
          ),
          getHeight(15),
        ],

        // Status Section (optional)
        if (widget.showStatus && widget.statusLabel != null) ...[
          Row(
            children: [
              Text(
                widget.statusLabel!,
                style: const TextStyle(
                  color: AppColors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (widget.isStatusRequired)
                const Text(
                  " *",
                  style: TextStyle(color: Colors.red, fontSize: 16),
                ),
            ],
          ),
          getHeight(8),

          Row(
            children: [
              Radio<String>(
                value: "Ok",
                groupValue: _selectedStatus,
                onChanged: _onStatusChanged,
                activeColor: AppColors.primaryGreen,
              ),
              const Text(
                "Ok",
                style: TextStyle(color: AppColors.white, fontSize: 16),
              ),
              const SizedBox(width: 20),
              Radio<String>(
                value: "Not Ok",
                groupValue: _selectedStatus,
                onChanged: _onStatusChanged,
                activeColor: AppColors.primaryGreen,
              ),
              const Text(
                "Not Ok",
                style: TextStyle(color: AppColors.white, fontSize: 16),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
