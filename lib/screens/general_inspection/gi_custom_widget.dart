import 'dart:convert';
import 'dart:io';

import 'package:app/commonWidgets/custom_horizontal_radio_buttons.dart';
import 'package:app/commonWidgets/custom_image_upload_field.dart';
import 'package:app/commonWidgets/custom_remark.dart';
import 'package:app/constants/app_colors.dart';
import 'package:app/enum/activity_type_enum.dart';
import 'package:app/enum/corrective_maintenance_screen_mode_enum.dart';
import 'package:app/models/all_site_model.dart';
import 'package:app/models/gen_ins_checklist_model.dart';
import 'package:app/services/service_locator.dart';
import 'package:app/utils/logger.dart';
import 'package:app/utils/toastbar.dart';
import 'package:flutter/material.dart';

class GICustomChecklistItem extends StatefulWidget {
  final GenInsCheckListData checklistItem;
  final AllSiteModel siteData;
  final CMScreenModeEnum mode;
  final Map<String, dynamic>? existingResponse; // Existing response data for edit mode
  final Function(String? value)? onRadioChanged; // Callback for radio button changes (returns key)
  final Function(String? imageId)? onImageChanged; // Callback for image changes (returns image ID)
  final Function(String? textValue)? onTextChanged; // Callback for text changes (returns text)

  const GICustomChecklistItem({
    super.key,
    required this.checklistItem,
    required this.siteData,
    this.mode = CMScreenModeEnum.create, // Default to create mode
    this.existingResponse,
    this.onRadioChanged,
    this.onImageChanged,
    this.onTextChanged,
  });

  @override
  State<GICustomChecklistItem> createState() => _GICustomChecklistItemState();
}

class _GICustomChecklistItemState extends State<GICustomChecklistItem> {
  String? _selectedRadioValue; // Stores the displayed value (e.g., "Yes")
  File? _imageFile; // Stores the captured image file
  String? _uploadedImageId; // Stores the uploaded image ID from server
  String? _fetchedImageData; // Stores the fetched image data for display
  final TextEditingController _textController = TextEditingController(); // For text input

  @override
  void initState() {
    super.initState();
    
    // Initialize form fields with existing response data if available
    if (widget.existingResponse != null) {
      print('🔍 Initializing checklist item with existing response: ${widget.existingResponse}');
      
      // Initialize text field with existing value
      final textValue = widget.existingResponse!['text_value']?.toString();
      if (textValue != null && textValue.isNotEmpty) {
        _textController.text = textValue;
      }
      
      // Initialize image with existing value
      final imageId = widget.existingResponse!['image_id']?.toString();
      if (imageId != null && imageId.isNotEmpty && imageId != "0") {
        _uploadedImageId = imageId;
        _loadExistingImage(imageId);
      }
      
      // Initialize radio button with existing value
      final radioValue = widget.existingResponse!['radio_value']?.toString();
      if (radioValue != null && radioValue.isNotEmpty) {
        // Convert to lowercase for comparison
        final lowerRadioValue = radioValue.toLowerCase();
        print('🔍 Initialized radio button with value: $radioValue (lowercase: $lowerRadioValue)');
        
        // Find matching display value by comparing lowercase values
        if (widget.checklistItem.respTypeValueMap != null) {
          try {
            final Map<String, dynamic> decodedMap = json.decode(widget.checklistItem.respTypeValueMap!.value);
            String? matchingDisplayValue;
            
            decodedMap.forEach((key, value) {
              if (value.toString().toLowerCase() == lowerRadioValue) {
                matchingDisplayValue = value.toString();
              }
            });
            
            if (matchingDisplayValue != null) {
              _selectedRadioValue = matchingDisplayValue;
              print('🔍 Found matching display value: $matchingDisplayValue');
            } else {
              // Fallback to original value
              _selectedRadioValue = radioValue;
              print('🔍 No matching display value found, using original: $radioValue');
            }
          } catch (e) {
            Logger.errorLog('Error decoding resp_type_value_map: $e');
            _selectedRadioValue = radioValue;
          }
        } else {
          _selectedRadioValue = radioValue;
        }
      }
    }
    
    // Add listener to text controller
    _textController.addListener(() {
      print('🔍 Text controller changed: "${_textController.text}"');
      widget.onTextChanged?.call(_textController.text);
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _loadExistingImage(String imageId) async {
    try {
      print("🔍 _loadExistingImage called with imageId: $imageId");

      String? uniqueId;
      
      // Check if this is already a unique ID (offline mode) or a server ID (online mode)
      if (imageId.contains("LOCAL_IMAGE_ID")) {
        // This is already a unique ID from offline mode
        print("🔍 Detected unique ID (offline mode): $imageId");
        uniqueId = imageId;
      } else {
        // This is a server ID, try to download from server (online mode)
        print("🔍 Detected server ID (online mode): $imageId");
        uniqueId = await ServiceLocator().imageUploadService
            .downloadImageUsingServerId(
              imageId,
              ActivityTypeEnum.generalInspection,
              widget.siteData.siteId.toString(),
            );
        print("🔍 Download result - uniqueId: $uniqueId");
      }

      if (uniqueId != null) {
        // Now get the image data using the unique ID
        final imageData = await ServiceLocator().centralAssetAuditService.getImageAsDataUrl(uniqueId);

        print("🔍 Image loading result: ${imageData != null ? 'SUCCESS' : 'FAILED'}");

        if (imageData != null) {
          Logger.debugLog('✅ Image data received: ${imageData.length} characters');
          setState(() {
            _fetchedImageData = imageData;
          });
          Logger.debugLog('✅ Image loaded successfully and state updated');
        } else {
          Logger.errorLog('❌ Failed to load image data with uniqueId $uniqueId - imageData is null');
        }
      } else {
        Logger.errorLog('❌ Failed to get unique ID for image: $imageId');
      }
    } catch (e) {
      Logger.errorLog('❌ Error loading existing image: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isEditable = widget.mode != CMScreenModeEnum.view;
    bool hasRadio = widget.checklistItem.respType.contains('RADIO');
    bool hasImage = widget.checklistItem.respType.contains('IMG');
    bool hasText = widget.checklistItem.respType.contains('TEXT');

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
      padding: const EdgeInsets.all(10.0),
      decoration: BoxDecoration(
        color: const Color(0x4DE6F5EF), // #E6F5EF4D - 30% opacity
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Checklist Description (Label)
          Row(
            children: [
              Text(
                widget.checklistItem.checklistDesc,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
              if (widget.checklistItem.isMandatory)
                const Text(
                  ' *',
                  style: TextStyle(color: AppColors.redColor), // Red asterisk
                ),
            ],
          ),
          const SizedBox(height: 8),

          if (hasRadio)
            _buildRadioButtons(isEditable),

          if (hasText)
            _buildTextInputField(isEditable),

          if (hasImage)
            _buildImageUploadField(isEditable),
        ],
      ),
    );
  }

  Widget _buildRadioButtons(bool isEditable) {
    Map<String, String> valueMap = {};
    if (widget.checklistItem.respTypeValueMap != null) {
      try {
        final Map<String, dynamic> decodedMap = json.decode(widget.checklistItem.respTypeValueMap!.value);
        decodedMap.forEach((key, value) {
          valueMap[key] = value.toString();
        });
      } catch (e) {
        Logger.errorLog('Error decoding resp_type_value_map for ${widget.checklistItem.checklistDesc}: $e');
      }
    }

    List<RadioOption> radioOptions = valueMap.entries
        .map((entry) => RadioOption(label: entry.value, value: entry.value))
        .toList();

    print('🔍 Building radio buttons for ${widget.checklistItem.checklistDesc}:');
    print('  - valueMap: $valueMap');
    print('  - radioOptions: ${radioOptions.map((opt) => '${opt.label}:${opt.value}').toList()}');
    print('  - _selectedRadioValue: $_selectedRadioValue');

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: CustomHorizontalRadioButtons(
        options: radioOptions,
        selectedValue: _selectedRadioValue,
        activeColor: Colors.white,
        inactiveColor: Colors.white,
        textColor: Colors.white,
        onButtonSelected: isEditable
            ? (value) {
                print('🔍 Radio button selected: $value');
                // Update the selected value with setState to show visual feedback
                setState(() {
                  _selectedRadioValue = value;
                });
                // Find the key corresponding to the selected value using lowercase comparison
                String? selectedKey;
                valueMap.forEach((key, val) {
                  if (val.toLowerCase() == value.toLowerCase()) {
                    selectedKey = key;
                  }
                });
                print('🔍 Sending selectedKey to parent: $selectedKey');
                widget.onRadioChanged?.call(selectedKey);
              }
            : null, // Disable if not editable
      ),
    );
  }

  Widget _buildTextInputField(bool isEditable) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Text input field without separate label
          CustomRemarksField(
            label: "",
            hintText: "Enter ${widget.checklistItem.checklistDesc.toLowerCase()}",
            controller: _textController,
            isDisabled: !isEditable,
          ),
          
          
        ],
      ),
    );
  }

  Widget _buildImageUploadField(bool isEditable) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label with asterisk
          Row(
            children: [
              const Text(
                "Add a Photo",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
              if (widget.checklistItem.isMandatory)
                const Text(
                  ' *',
                  style: TextStyle(color: AppColors.redColor),
                ),
            ],
          ),
          const SizedBox(height: 8),
          // Image upload field
          ImageUploadField(
            key: ValueKey('${widget.checklistItem.giclmId}_image'),
            placeholder: "Add a Photo",
            isRequired: widget.checklistItem.isMandatory,
            onImageSelected: isEditable
                ? (File? file) {
                    if (file != null) {
                      setState(() {
                        _imageFile = file;
                      });
                      // Upload image to server
                      _uploadImage();
                    } else {
                      setState(() {
                        _imageFile = null;
                        _uploadedImageId = null;
                        _fetchedImageData = null;
                      });
                      widget.onImageChanged?.call(null);
                    }
                  }
                : (File? file) {}, // Provide empty function if not editable
            externalImageUrl: _fetchedImageData,
            isDisabled: !isEditable,
          ),
        ],
      ),
    );
  }

  Future<void> _uploadImage() async {
    try {
      if (_imageFile == null) {
        Toastbar.showErrorToastbar('Please select an image first', context);
        return;
      }

      // Upload image to server
      final imgId = await ServiceLocator().centralAssetAuditService.uploadImage(
        siteAuditSchId: widget.siteData.siteId.toString(),
        imageFile: _imageFile!,
        isSelfie: false,
        activityType: ActivityTypeEnum.generalInspection,
      );

      print("imgId: after upload $imgId");

      if (imgId != null && imgId.isNotEmpty) {
        setState(() {
          _uploadedImageId = imgId;
        });

        // Notify parent about the uploaded image ID
        widget.onImageChanged?.call(_uploadedImageId);

        // Show appropriate message based on whether it's server or local ID
        if (imgId.contains("LOCAL_IMAGE_ID")) {
          Toastbar.showSuccessToastbar('Photo saved locally (offline mode)', context);
        } else {
          Toastbar.showSuccessToastbar('Photo uploaded successfully', context);
        }
      } else {
        Toastbar.showErrorToastbar('Failed to upload photo', context);
        throw Exception('Failed to get image ID');
      }
    } catch (e) {
      Logger.errorLog('❌ Error uploading photo: $e');
    }
  }

  // Validation method to check if mandatory fields are filled
  String? validateField() {
    if (!widget.checklistItem.isMandatory) {
      return null; // Not mandatory, no validation needed
    }

    bool hasRadio = widget.checklistItem.respType.contains('RADIO');
    bool hasImage = widget.checklistItem.respType.contains('IMG');
    bool hasText = widget.checklistItem.respType.contains('TEXT');

    if (hasRadio && (_selectedRadioValue == null || _selectedRadioValue!.isEmpty)) {
      return '${widget.checklistItem.checklistDesc} is required';
    }

    if (hasText && (_textController.text.trim().isEmpty)) {
      return '${widget.checklistItem.checklistDesc} is required';
    }

    if (hasImage && _uploadedImageId == null) {
      return '${widget.checklistItem.checklistDesc} photo is required';
    }

    return null; // All validations passed
  }

  // Get current values for form submission
  Map<String, dynamic> getCurrentValues() {
    Map<String, dynamic> values = {};
    
    if (widget.checklistItem.respType.contains('RADIO')) {
      values['radio_value'] = _selectedRadioValue;
    }
    
    if (widget.checklistItem.respType.contains('TEXT')) {
      values['text_value'] = _textController.text.trim();
    }
    
    if (widget.checklistItem.respType.contains('IMG')) {
      values['image_id'] = _uploadedImageId;
    }
    
    return values;
  }
}
