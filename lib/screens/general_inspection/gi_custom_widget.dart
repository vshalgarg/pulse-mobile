import 'dart:convert';
import 'dart:io';

import 'package:app/commonWidgets/custom_horizontal_radio_buttons.dart';
import 'package:app/commonWidgets/custom_image_upload_field.dart';
import 'package:app/commonWidgets/custom_remark.dart';
import 'package:app/commonWidgets/custom_form_dropdown.dart';
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
  State<GICustomChecklistItem> createState() => GICustomChecklistItemState();
}

class GICustomChecklistItemState extends State<GICustomChecklistItem> {
  String? _selectedRadioValue; // Stores the displayed value (e.g., "Yes")
  String? _selectedDropdownValue; // Stores the selected dropdown value
  File? _imageFile; // Stores the captured image file
  String? _uploadedImageId; // Stores the uploaded image ID from server
  String? _fetchedImageData; // Stores the fetched image data for display
  final TextEditingController _textController = TextEditingController(); // For text input
  
  // Dependent elements state - keyed by dependent element respType
  Map<String, String?> _dependentImageIds = {}; // respType -> imageId
  Map<String, String?> _dependentImageData = {}; // respType -> imageDataUrl (for display)
  Map<String, String> _dependentRemarks = {}; // respType -> remarks text
  Map<String, String> _dependentTextValues = {}; // respType -> text value
  Map<String, TextEditingController> _dependentControllers = {}; // respType -> controller
  
  // Track which dependent fields should be highlighted (for validation errors)
  Set<String> _highlightedDependentFields = {};

  @override
  void initState() {
    super.initState();
    
    // Initialize form fields with existing response data if available
    if (widget.existingResponse != null) {

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
      
      // Initialize radio/dropdown button with existing value
      final radioValue = widget.existingResponse!['radio_value']?.toString();
      if (radioValue != null && radioValue.isNotEmpty) {
        // Convert to lowercase for comparison
        final lowerRadioValue = radioValue.toLowerCase();
        
        // Find matching display value by comparing lowercase values
        if (widget.checklistItem.respTypeValueMap != null) {
          final valueMap = widget.checklistItem.respTypeValueMap!.valueAsMap;
          if (valueMap != null) {
            String? matchingDisplayValue;
            
            valueMap.forEach((key, value) {
              if (value.toString().toLowerCase() == lowerRadioValue) {
                matchingDisplayValue = value.toString();
              }
            });
            
            if (matchingDisplayValue != null) {
              if (widget.checklistItem.respType.contains('DROPDOWN')) {
                _selectedDropdownValue = matchingDisplayValue;
              } else {
                _selectedRadioValue = matchingDisplayValue;
              }
            } else {
              // Fallback to original value
              if (widget.checklistItem.respType.contains('DROPDOWN')) {
                _selectedDropdownValue = radioValue;
              } else {
                _selectedRadioValue = radioValue;
              }
            }
          } else {
            if (widget.checklistItem.respType.contains('DROPDOWN')) {
              _selectedDropdownValue = radioValue;
            } else {
              _selectedRadioValue = radioValue;
            }
          }
        } else {
          if (widget.checklistItem.respType.contains('DROPDOWN')) {
            _selectedDropdownValue = radioValue;
          } else {
            _selectedRadioValue = radioValue;
          }
        }
      }
    }
    
    // Add listener to text controller
    _textController.addListener(() {
      widget.onTextChanged?.call(_textController.text);
      // Trigger rebuild to update flag condition and dependent elements
      setState(() {});
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    // Dispose all dependent element controllers
    for (final controller in _dependentControllers.values) {
      controller.dispose();
    }
    _dependentControllers.clear();
    super.dispose();
  }

  Future<void> _loadExistingImage(String imageId) async {
    try {

      String? uniqueId;
      
      // Check if this is already a unique ID (offline mode) or a server ID (online mode)
      if (imageId.contains("LOCAL_IMAGE_ID")) {
        // This is already a unique ID from offline mode
        uniqueId = imageId;
      } else {
        // This is a server ID, try to download from server (online mode)
        uniqueId = await ServiceLocator().imageUploadService
            .downloadImageUsingServerId(
              imageId,
              ActivityTypeEnum.generalInspection,
              widget.siteData.siteId.toString(),
            );

      }

      if (uniqueId != null) {
        // Now get the image data using the unique ID
        final imageData = await ServiceLocator().centralAssetAuditService.getImageAsDataUrl(uniqueId);

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
    bool hasDropdown = widget.checklistItem.respType.contains('DROPDOWN');
    bool hasImage = widget.checklistItem.respType.contains('IMG');
    bool hasText = widget.checklistItem.respType.contains('TEXT');
    
    // Evaluate flag condition to determine if field should be highlighted
    // Wrap in try-catch to prevent lookup failures
    bool shouldHighlight = false;
    try {
      shouldHighlight = _evaluateFlagCondition();
    } catch (e) {
      Logger.errorLog('Error in _evaluateFlagCondition: $e');
      shouldHighlight = false;
    }
    
    // Get current main field response for dependent elements visibility
    // This value is used to determine if dependent elements should be visible
    final currentMainResponse = hasRadio 
        ? _selectedRadioValue 
        : hasDropdown 
            ? _selectedDropdownValue 
            : hasText 
                ? _textController.text 
                : null;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
      padding: const EdgeInsets.all(10.0),
      decoration: BoxDecoration(
        color: shouldHighlight 
            ? AppColors.errorColor.withOpacity(0.2) // Red highlight if flag condition met
            : const Color(0x4DE6F5EF), // #E6F5EF4D - 30% opacity
        borderRadius: BorderRadius.circular(8.0),
        border: shouldHighlight 
            ? Border.all(color: AppColors.errorColor, width: 2)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Checklist Description (Label)
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.checklistItem.checklistDesc,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: shouldHighlight ? AppColors.errorColor : Colors.white,
                  ),
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

          // Main field based on resp_type
          if (hasRadio)
            _buildRadioButtons(isEditable),
          
          if (hasDropdown)
            _buildDropdownField(isEditable),

          if (hasText)
            _buildTextInputField(isEditable),

          if (hasImage)
            _buildImageUploadField(isEditable),
          
          // Render dependent elements
          if (widget.checklistItem.dependentElements != null)
            ...widget.checklistItem.dependentElements!.map((dependentElement) {
              final shouldShow = dependentElement.shouldBeVisible(currentMainResponse);
              if (!shouldShow) return const SizedBox.shrink();
              
              return _buildDependentElement(dependentElement, isEditable, currentMainResponse);
            }),
        ],
      ),
    );
  }

  // Evaluate flag condition - returns true if field should be highlighted
  bool _evaluateFlagCondition() {
    try {
      // Check if flag exists and is not empty
      if (widget.checklistItem.flag == null || 
          widget.checklistItem.flag!.isEmpty) {
        return false;
      }
      
      final flag = widget.checklistItem.flag!;
      final currentValue = _getCurrentMainFieldValue();
      
      // If no current value, can't evaluate
      if (currentValue == null || currentValue.isEmpty) {
        return false;
      }
      
      // Parse flag condition (e.g., ">10", "<5", ">=20", "<=100", "==50")
      final numericValue = double.tryParse(currentValue);
      if (numericValue == null) {
        return false; // Can't compare non-numeric values
      }
      
      // Extract operator and threshold
      if (flag.startsWith('>=')) {
        final threshold = double.tryParse(flag.substring(2)) ?? 0;
        return numericValue >= threshold;
      } else if (flag.startsWith('<=')) {
        final threshold = double.tryParse(flag.substring(2)) ?? 0;
        return numericValue <= threshold;
      } else if (flag.startsWith('>')) {
        final threshold = double.tryParse(flag.substring(1)) ?? 0;
        return numericValue > threshold;
      } else if (flag.startsWith('<')) {
        final threshold = double.tryParse(flag.substring(1)) ?? 0;
        return numericValue < threshold;
      } else if (flag.startsWith('==')) {
        final threshold = double.tryParse(flag.substring(2)) ?? 0;
        return numericValue == threshold;
      } else if (flag.startsWith('=')) {
        final threshold = double.tryParse(flag.substring(1)) ?? 0;
        return numericValue == threshold;
      }
    } catch (e, stackTrace) {
      Logger.errorLog('Error evaluating flag condition: $e');
      Logger.errorLog('Stack trace: $stackTrace');
    }
    
    return false;
  }
  
  // Get current main field value for flag evaluation
  String? _getCurrentMainFieldValue() {
    if (widget.checklistItem.respType.contains('RADIO')) {
      return _selectedRadioValue;
    } else if (widget.checklistItem.respType.contains('DROPDOWN')) {
      return _selectedDropdownValue;
    } else if (widget.checklistItem.respType.contains('TEXT')) {
      return _textController.text;
    }
    return null;
  }

  Widget _buildRadioButtons(bool isEditable) {
    Map<String, String> valueMap = {};
    if (widget.checklistItem.respTypeValueMap != null) {
      final valueAsMap = widget.checklistItem.respTypeValueMap!.valueAsMap;
      if (valueAsMap != null) {
        valueAsMap.forEach((key, value) {
          valueMap[key] = value.toString();
        });
      } else {
        // Fallback to string parsing for backward compatibility
        try {
          final Map<String, dynamic> decodedMap = json.decode(widget.checklistItem.respTypeValueMap!.valueAsString);
          decodedMap.forEach((key, value) {
            valueMap[key] = value.toString();
          });
        } catch (e) {
          Logger.errorLog('Error decoding resp_type_value_map for ${widget.checklistItem.checklistDesc}: $e');
        }
      }
    }

    List<RadioOption> radioOptions = valueMap.entries
        .map((entry) => RadioOption(label: entry.value, value: entry.value))
        .toList();

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

                widget.onRadioChanged?.call(selectedKey);
                // Trigger rebuild to update dependent elements visibility
                setState(() {});
              }
            : null, // Disable if not editable
      ),
    );
  }

  Widget _buildDropdownField(bool isEditable) {
    List<String> options = [];
    if (widget.checklistItem.respTypeValueMap != null) {
      final valueAsMap = widget.checklistItem.respTypeValueMap!.valueAsMap;
      if (valueAsMap != null) {
        options = valueAsMap.values.map((v) => v.toString()).toList();
      } else {
        // Fallback to string parsing
        try {
          final Map<String, dynamic> decodedMap = json.decode(widget.checklistItem.respTypeValueMap!.valueAsString);
          options = decodedMap.values.map((v) => v.toString()).toList();
        } catch (e) {
          Logger.errorLog('Error decoding dropdown options: $e');
        }
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: CustomDropdown(
        label: "",
        items: options,
        isRequired: widget.checklistItem.isMandatory,
        initialValue: _selectedDropdownValue,
        onChanged: isEditable
            ? (String? value) {
                setState(() {
                  _selectedDropdownValue = value;
                });
                // Find the key corresponding to the selected value
                String? selectedKey;
                final valueAsMap = widget.checklistItem.respTypeValueMap?.valueAsMap;
                if (valueAsMap != null) {
                  valueAsMap.forEach((key, val) {
                    if (val.toString().toLowerCase() == value?.toLowerCase()) {
                      selectedKey = key;
                    }
                  });
                }
                widget.onRadioChanged?.call(selectedKey ?? value);
                // Trigger rebuild to update dependent elements visibility
                setState(() {});
              }
            : (String? value) {}, // Provide empty function if not editable
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

  /// Highlight a dependent field (called from parent validation)
  void highlightDependentField(String respType) {
    setState(() {
      _highlightedDependentFields.add(respType);
    });
  }
  
  /// Clear highlight for a dependent field
  void _clearDependentFieldHighlight(String respType) {
    setState(() {
      _highlightedDependentFields.remove(respType);
    });
  }
  
  // Getters to expose dependent element data for validation
  String? getDependentImageId(String respType) {
    return _dependentImageIds[respType];
  }
  
  String? getDependentRemarks(String respType) {
    return _dependentRemarks[respType];
  }
  
  /// Get remarks by checklist description (for cases with multiple REMARKS elements)
  String? getDependentRemarksByDesc(String checklistDesc) {
    // Try to find remarks by matching checklist description
    // Since we key by respType, we return the first match
    // In most cases there's only one REMARKS per item
    return _dependentRemarks['REMARKS'];
  }
  
  String? getDependentTextValue(String respType) {
    return _dependentTextValues[respType];
  }

  // Build dependent element widget
  Widget _buildDependentElement(
    DependentElement element,
    bool isEditable,
    String? parentResponse,
  ) {
    final isMandatory = element.isMandatoryForResponse(parentResponse);
    final shouldHighlight = _highlightedDependentFields.contains(element.respType);
    
    if (element.respType == 'IMG') {
      return Padding(
        padding: const EdgeInsets.only(top: 12.0, bottom: 16.0),
        child: Container(
          decoration: shouldHighlight
              ? BoxDecoration(
                  border: Border.all(color: AppColors.errorColor, width: 2),
                  borderRadius: BorderRadius.circular(8),
                  color: AppColors.errorColor.withOpacity(0.1),
                )
              : null,
          padding: shouldHighlight ? const EdgeInsets.all(8.0) : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    element.checklistDesc,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: shouldHighlight ? AppColors.errorColor : Colors.white,
                    ),
                  ),
                  if (isMandatory)
                    const Text(
                      ' *',
                      style: TextStyle(color: AppColors.redColor),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              ImageUploadField(
                key: ValueKey('${widget.checklistItem.giclmId}_${element.respType}_image'),
                placeholder: element.checklistDesc,
                isRequired: isMandatory,
                onImageSelected: isEditable
                    ? (File? file) {
                        if (file != null) {
                          _uploadDependentImage(element.respType, file);
                          // Clear highlight when image is added
                          _clearDependentFieldHighlight(element.respType);
                        } else {
                          setState(() {
                            _dependentImageIds[element.respType] = null;
                          });
                          widget.onImageChanged?.call(null);
                        }
                      }
                    : (File? file) {},
                externalImageUrl: _getDependentImageData(element.respType),
                isDisabled: !isEditable,
              ),
            ],
          ),
        ),
      );
    } else if (element.respType == 'REMARKS') {
      // Get or create controller for this dependent element
      if (!_dependentControllers.containsKey(element.respType)) {
        _dependentControllers[element.respType] = TextEditingController(
          text: _dependentRemarks[element.respType] ?? '',
        );
        _dependentControllers[element.respType]!.addListener(() {
          _dependentRemarks[element.respType] = 
              _dependentControllers[element.respType]?.text ?? '';
          // Clear highlight when text is entered
          if (_dependentRemarks[element.respType]?.isNotEmpty == true) {
            _clearDependentFieldHighlight(element.respType);
          }
        });
      }
      
      return Padding(
        padding: const EdgeInsets.only(top: 12.0, bottom: 16.0),
        child: Container(
          decoration: shouldHighlight
              ? BoxDecoration(
                  border: Border.all(color: AppColors.errorColor, width: 2),
                  borderRadius: BorderRadius.circular(8),
                  color: AppColors.errorColor.withOpacity(0.1),
                )
              : null,
          padding: shouldHighlight ? const EdgeInsets.all(8.0) : null,
          child: CustomRemarksField(
            label: element.checklistDesc,
            hintText: "Enter ${element.checklistDesc.toLowerCase()}",
            controller: _dependentControllers[element.respType]!,
            isDisabled: !isEditable,
          ),
        ),
      );
    } else if (element.respType == 'TEXT') {
      // Get or create controller for this dependent element
      if (!_dependentControllers.containsKey(element.respType)) {
        _dependentControllers[element.respType] = TextEditingController(
          text: _dependentTextValues[element.respType] ?? '',
        );
        _dependentControllers[element.respType]!.addListener(() {
          _dependentTextValues[element.respType] = 
              _dependentControllers[element.respType]?.text ?? '';
          // Clear highlight when text is entered
          if (_dependentTextValues[element.respType]?.isNotEmpty == true) {
            _clearDependentFieldHighlight(element.respType);
          }
        });
      }
      
      return Padding(
        padding: const EdgeInsets.only(top: 12.0, bottom: 16.0),
        child: Container(
          decoration: shouldHighlight
              ? BoxDecoration(
                  border: Border.all(color: AppColors.errorColor, width: 2),
                  borderRadius: BorderRadius.circular(8),
                  color: AppColors.errorColor.withOpacity(0.1),
                )
              : null,
          padding: shouldHighlight ? const EdgeInsets.all(8.0) : null,
          child: CustomRemarksField(
            label: element.checklistDesc,
            hintText: "Enter ${element.checklistDesc.toLowerCase()}",
            controller: _dependentControllers[element.respType]!,
            isDisabled: !isEditable,
          ),
        ),
      );
    }
    
    return const SizedBox.shrink();
  }

  Future<void> _uploadDependentImage(String elementKey, File imageFile) async {
    try {
      // Show loading state
      setState(() {
        _dependentImageData[elementKey] = null; // Clear previous image
      });

      final imgId = await ServiceLocator().centralAssetAuditService.uploadImage(
        siteAuditSchId: widget.siteData.siteId.toString(),
        imageFile: imageFile,
        isSelfie: false,
        activityType: ActivityTypeEnum.generalInspection,
      );

      if (imgId != null && imgId.isNotEmpty) {
        setState(() {
          _dependentImageIds[elementKey] = imgId;
        });
        
        // Load the image data for display
        await _loadDependentImageData(elementKey, imgId);
        
        widget.onImageChanged?.call(imgId);
      } else {
        Logger.errorLog('❌ Failed to get image ID after upload');
      }
    } catch (e) {
      Logger.errorLog('❌ Error uploading dependent image: $e');
      setState(() {
        _dependentImageIds[elementKey] = null;
        _dependentImageData[elementKey] = null;
      });
    }
  }

  /// Load image data for a dependent element using the image ID
  Future<void> _loadDependentImageData(String elementKey, String imageId) async {
    try {
      String? uniqueId;
      
      // Check if this is already a unique ID (offline mode) or a server ID (online mode)
      if (imageId.contains("LOCAL_IMAGE_ID")) {
        // This is already a unique ID from offline mode
        uniqueId = imageId;
      } else {
        // This is a server ID, try to download from server (online mode)
        uniqueId = await ServiceLocator().imageUploadService
            .downloadImageUsingServerId(
              imageId,
              ActivityTypeEnum.generalInspection,
              widget.siteData.siteId.toString(),
            );
      }

      if (uniqueId != null) {
        // Now get the image data using the unique ID
        final imageData = await ServiceLocator().centralAssetAuditService
            .getImageAsDataUrl(uniqueId);

        if (imageData != null) {
          setState(() {
            _dependentImageData[elementKey] = imageData;
          });
          Logger.debugLog('✅ Dependent image data loaded for $elementKey');
        } else {
          Logger.errorLog('❌ Failed to load image data with uniqueId $uniqueId');
        }
      } else {
        Logger.errorLog('❌ Failed to get unique ID for dependent image: $imageId');
      }
    } catch (e) {
      Logger.errorLog('❌ Error loading dependent image data: $e');
    }
  }

  String? _getDependentImageData(String elementKey) {
    return _dependentImageData[elementKey];
  }

  // Get current values for form submission
  Map<String, dynamic> getCurrentValues() {
    Map<String, dynamic> values = {};
    
    if (widget.checklistItem.respType.contains('RADIO')) {
      values['radio_value'] = _selectedRadioValue;
    } else if (widget.checklistItem.respType.contains('DROPDOWN')) {
      values['radio_value'] = _selectedDropdownValue; // Dropdown uses same key as radio
    }
    
    if (widget.checklistItem.respType.contains('TEXT')) {
      values['text_value'] = _textController.text.trim();
    }
    
    if (widget.checklistItem.respType.contains('IMG')) {
      values['image_id'] = _uploadedImageId;
    }
    
    // Include dependent elements data
    if (widget.checklistItem.dependentElements != null) {
      for (final element in widget.checklistItem.dependentElements!) {
        if (element.respType == 'IMG') {
          values['dependent_${element.respType}_${element.checklistDesc}'] = 
              _dependentImageIds[element.respType];
        } else if (element.respType == 'REMARKS') {
          values['dependent_${element.respType}_${element.checklistDesc}'] = 
              _dependentRemarks[element.respType] ?? '';
        } else if (element.respType == 'TEXT') {
          values['dependent_${element.respType}_${element.checklistDesc}'] = 
              _dependentTextValues[element.respType] ?? '';
        }
      }
    }
    
    return values;
  }
  
  // Validate dependent elements
  List<String> validateDependentElements(String? parentResponse) {
    List<String> errors = [];
    
    if (widget.checklistItem.dependentElements != null) {
      for (final element in widget.checklistItem.dependentElements!) {
        final isMandatory = element.isMandatoryForResponse(parentResponse);
        if (!isMandatory) continue;
        
        if (element.respType == 'IMG') {
          final imageId = _dependentImageIds[element.respType];
          if (imageId == null || imageId.isEmpty) {
            errors.add('${element.checklistDesc} is required');
          }
        } else if (element.respType == 'REMARKS' || element.respType == 'TEXT') {
          final value = element.respType == 'REMARKS' 
              ? _dependentRemarks[element.respType] 
              : _dependentTextValues[element.respType];
          if (value == null || value.trim().isEmpty) {
            errors.add('${element.checklistDesc} is required');
          }
        }
      }
    }
    
    return errors;
  }
}
