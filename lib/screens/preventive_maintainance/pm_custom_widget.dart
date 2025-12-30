import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../constants/constants_strings.dart';
import '../../services/image_upload_service.dart';
import '../../enum/activity_type_enum.dart';
import '../../app_config.dart';
import '../../commonWidgets/custom_remark.dart';
import '../../commonWidgets/custom_form_field.dart';
import '../../commonWidgets/custom_form_dropdown.dart';
import '../../commonWidgets/custom_image_upload_field.dart';
import '../../commonWidgets/custom_radio_options.dart';
import '../../utils/logger.dart';
import '../../utils/toastbar.dart';
import '../../utils.dart';
import 'pm_dependent_element_helpers.dart';

class PMCustomWidget extends StatefulWidget {
  final Map<String, dynamic> pmItem;
  final List<String> readonlyFields;
  final Function(Map<String, dynamic>) onValueChanged;

  const PMCustomWidget({
    super.key,
    required this.pmItem,
    required this.readonlyFields,
    required this.onValueChanged,
  });

  @override
  State<PMCustomWidget> createState() => PMCustomWidgetState();
}

class PMCustomWidgetState extends State<PMCustomWidget> {
  late Map<String, dynamic> _currentItem;
  String? _selectedDropdownValue;
  String? _selectedRadioValue;
  String? _textValue;
  String? _imageData;
  final TextEditingController _textController = TextEditingController();
  final TextEditingController _remarksController = TextEditingController();
  
  // Dependent elements state - keyed by dependent element respType or a unique key
  Map<String, String?> _dependentImageIds = {}; // key -> imageId
  Map<String, String?> _dependentImageData = {}; // key -> imageDataUrl (for display)
  Map<String, String> _dependentRemarks = {}; // key -> remarks text
  Map<String, String> _dependentTextValues = {}; // key -> text value
  Map<String, TextEditingController> _dependentControllers = {}; // key -> controller
  Map<String, File?> _dependentImageFiles = {}; // key -> image file
  
  // Track which dependent fields should be highlighted (for validation errors)
  Set<String> _highlightedDependentFields = {};

  @override
  void initState() {
    super.initState();
    _currentItem = Map<String, dynamic>.from(widget.pmItem);
    _initializeValues();

    // Add listener for remarks controller
    _remarksController.addListener(() {
      _onRemarksChanged(_remarksController.text);
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _remarksController.dispose();
    // Dispose all dependent element controllers
    for (final controller in _dependentControllers.values) {
      controller.dispose();
    }
    _dependentControllers.clear();
    super.dispose();
  }

  void _initializeValues() {
    final respValue = _currentItem['resp'];
    final respTypeList = _currentItem['resp_type'];

    // Handle resp_type as array or string
    List<String> respTypes = [];
    if (respTypeList is List) {
      respTypes = respTypeList.map((e) => e.toString()).toList();
    } else if (respTypeList is String) {
      respTypes = respTypeList.split(",");
    }

    // Initialize dropdown value - handle dynamic mapping
    if (respTypes.contains('DROPDOWN')) {
      _selectedDropdownValue = _getDisplayLabelForValue(respValue);
    }

    // Initialize radio value from resp
    if (respTypes.contains('RADIO')) {
      if (respValue != null && respValue.toString().isNotEmpty) {
        _selectedRadioValue = respValue.toString();
      }
      // Don't set a default value - let user select
    }

    // Initialize text value
    _textValue = respValue?.toString();
    _textController.text = _textValue ?? '';

    // Initialize remarks value
    _remarksController.text = respValue?.toString() ?? '';

    // Load image data from responseImages array
    final responseImages = _currentItem['responseImages'] as List?;
    if (responseImages != null && responseImages.isNotEmpty) {
      final firstImage = responseImages[0];
      if (firstImage is Map && firstImage['photoId'] != null) {
        _loadImageFromPhotoId(firstImage['photoId'].toString());
      }
    } else if (_currentItem['photo_id'] != null) {
      // Fallback for backward compatibility
      _loadImageFromPhotoId(_currentItem['photo_id'].toString());
    }
  }

  Future<void> _loadImageFromPhotoId(String photoId) async {
    try {
      if (photoId.isEmpty) return;

      // Initialize ImageUploadService
      final apiService = AppConfig.of(context).apiService;
      final imageUploadService = ImageUploadService(apiService: apiService);

      // Get image data using the photoId
      final imageData = await imageUploadService.getImageUsingUniqueId(photoId);

      if (imageData != null && mounted) {
        setState(() {
          _imageData = imageData.startsWith('data:image/')
              ? imageData
              : 'data:image/jpeg;base64,$imageData';
        });

      } else {

      }
    } catch (e) {

      // Set a placeholder or error state if needed
      if (mounted) {
        setState(() {
          _imageData = null;
        });
      }
    }
  }

  /// Add or update image in responseImages array
  void _addImageToResponseImages(String photoId) {
    if (!_currentItem.containsKey('responseImages') || 
        _currentItem['responseImages'] == null) {
      _currentItem['responseImages'] = [];
    }
    
    List<Map<String, dynamic>> responseImages = 
        List<Map<String, dynamic>>.from(_currentItem['responseImages'] ?? []);
    
    // Check if photoId already exists, update it; otherwise add new
    final existingIndex = responseImages.indexWhere(
      (img) => img['photoId'] == photoId,
    );
    
    final imageData = {
      'photoId': photoId,
      'photoTakenTs': Utils.getCurrentDateTimeForAPICall(),
    };
    
    if (existingIndex >= 0) {
      responseImages[existingIndex] = imageData;
    } else {
      responseImages.add(imageData);
    }
    
    _currentItem['responseImages'] = responseImages;
  }

  void _notifyValueChanged() {
    widget.onValueChanged(_currentItem);
  }

  /// Validate if all required fields are filled
  bool validateForm() {
    final respValue = _currentItem['resp'];
    final respTypeList = _currentItem['resp_type'];

    // Handle resp_type as array or string
    List<String> respTypes = [];
    if (respTypeList is List) {
      respTypes = respTypeList.map((e) => e.toString()).toList();
    } else if (respTypeList is String) {
      respTypes = respTypeList.split(",");
    }

    // Check if any required field is empty
    if (respTypes.contains('DROPDOWN') &&
        (respValue == null || respValue.toString().isEmpty)) {
      return false;
    }

    if (respTypes.contains('RADIO') &&
        (respValue == null || respValue.toString().isEmpty)) {
      return false;
    }

    if (respTypes.contains('TEXT') &&
        (respValue == null || respValue.toString().trim().isEmpty)) {
      return false;
    }

    if (respTypes.contains('IMG') &&
        (respValue == null || respValue.toString().isEmpty)) {
      return false;
    }

    return true;
  }

  /// Get validation error message for this field
  String? getValidationError() {
    final respValue = _currentItem['resp'];
    final respTypeList = _currentItem['resp_type'];
    final checklistDesc =
        _currentItem['checklist_desc']?.toString() ?? 'This field';

    // Handle resp_type as array or string
    List<String> respTypes = [];
    if (respTypeList is List) {
      respTypes = respTypeList.map((e) => e.toString()).toList();
    } else if (respTypeList is String) {
      respTypes = respTypeList.split(",");
    }

    // Check if any required field is empty
    if (respTypes.contains('DROPDOWN') &&
        (respValue == null || respValue.toString().isEmpty)) {
      return '$checklistDesc is required';
    }

    if (respTypes.contains('RADIO') &&
        (respValue == null || respValue.toString().isEmpty)) {
      return '$checklistDesc is required';
    }

    if (respTypes.contains('TEXT') &&
        (respValue == null || respValue.toString().trim().isEmpty)) {
      return '$checklistDesc is required';
    }

    if (respTypes.contains('NUMERIC') &&
        (respValue == null || respValue.toString().trim().isEmpty)) {
      return '$checklistDesc is required';
    }

    if (respTypes.contains('IMG') &&
        (respValue == null || respValue.toString().isEmpty)) {
      return '$checklistDesc is required';
    }

    return null;
  }

  void _onDropdownChanged(String? value, [Map<String, String>? valueMap]) {
    setState(() {
      _selectedDropdownValue = value;
      // Use the mapped value for API if valueMap is provided, otherwise use the label
      if (valueMap != null && value != null && valueMap.containsKey(value)) {
        _currentItem['resp'] = valueMap[value];
      } else {
        _currentItem['resp'] = value;
      }
    });
    _notifyValueChanged();
    // Trigger rebuild to update dependent elements visibility
    setState(() {});
  }

  void _onRadioChanged(String? value) {
    setState(() {
      _selectedRadioValue = value;
      // Store the selected value directly (value comes from resp_type_value_map)
      _currentItem['resp'] = value;
    });
    _notifyValueChanged();
    // Trigger rebuild to update dependent elements visibility
    setState(() {});
  }

  void _onTextChanged(String value) {
    setState(() {
      _textValue = value;
      _currentItem['resp'] = value;
    });
    _notifyValueChanged();
    // Trigger rebuild to update dependent elements visibility
    setState(() {});
  }

  void _onRemarksChanged(String value) {
    setState(() {
      _currentItem['resp'] = value;
    });
    _notifyValueChanged();
  }

  /// Get display label for a given API value by reverse mapping
  String? _getDisplayLabelForValue(dynamic respValue) {
    if (respValue == null) return null;
    
    try {
      final respTypeValueMap = _currentItem['resp_type_value_map'];
      if (respTypeValueMap != null && respTypeValueMap['value'] != null) {
        final jsonString = respTypeValueMap['value'].toString();
        final Map<String, dynamic> parsedMap = Map<String, dynamic>.from(
          jsonDecode(jsonString)
        );
        
        // Find the key (label) for the given value
        for (final entry in parsedMap.entries) {
          if (entry.value.toString() == respValue.toString()) {
            return entry.key;
          }
        }
      }
    } catch (e) {
      // If parsing fails, return the original value
    }
    
    return respValue?.toString();
  }

  Widget _buildDropdownField() {
    // Parse resp_type_value_map to get dynamic dropdown options
    List<String> dropdownOptions = [];
    Map<String, String> valueMap = {};
    
    try {
      final respTypeValueMap = _currentItem['resp_type_value_map'];
      if (respTypeValueMap != null && respTypeValueMap['value'] != null) {
        final jsonString = respTypeValueMap['value'].toString();
        final Map<String, dynamic> parsedMap = Map<String, dynamic>.from(
          jsonDecode(jsonString)
        );
        
        // Convert to label-value mapping
        parsedMap.forEach((key, value) {
          dropdownOptions.add(key); // Label for display
          valueMap[key] = value.toString(); // Value for API
        });
      }
    } catch (e) {
      // Fallback to static options if parsing fails
      dropdownOptions = [
        'OK',
        'Corrected',
        'NOT OK - To be corrected',
        'Not Applicable',
      ];
    }

    // If no dynamic options found, use static fallback
    if (dropdownOptions.isEmpty) {
      dropdownOptions = [
        'OK',
        'Corrected',
        'NOT OK - To be corrected',
        'Not Applicable',
      ];
    }

    return CustomDropdown(
      items: dropdownOptions,
      initialValue: _selectedDropdownValue,
      onChanged: (value) => _onDropdownChanged(value, valueMap),
    );
  }

  Widget _buildRadioField() {
    // Parse resp_type_value_map to get radio options
    List<OptionItem> radioOptions = [];
    Map<String, String> valueMap = {};
    
    try {
      final respTypeValueMap = _currentItem['resp_type_value_map'];
      if (respTypeValueMap != null) {
        Map<String, dynamic>? parsedMap;
        
        // Try direct Map first (for RADIO types)
        if (respTypeValueMap is Map<String, dynamic>) {
          parsedMap = respTypeValueMap;
        } else if (respTypeValueMap is Map && respTypeValueMap.containsKey('value')) {
          // Try nested structure with 'value' key (for dropdown-style)
          final value = respTypeValueMap['value'];
          if (value is Map<String, dynamic>) {
            parsedMap = value;
          } else if (value is String) {
            parsedMap = Map<String, dynamic>.from(jsonDecode(value));
          }
        }
        
        if (parsedMap != null && parsedMap.isNotEmpty) {
          // Convert map entries to OptionItem list
          // For radio buttons, both key and value are the same (e.g., "OK": "OK")
          parsedMap.forEach((key, value) {
            final optionValue = value.toString();
            radioOptions.add(
              OptionItem(
                value: optionValue,
                label: key,
              ),
            );
            valueMap[key] = optionValue;
          });
        }
      }
    } catch (e) {
      // If parsing fails, use default options
    }
    
    // If no options found, use default Yes/No
    if (radioOptions.isEmpty) {
      radioOptions = [
        OptionItem(value: 'Yes', label: 'Yes'),
        OptionItem(value: 'No', label: 'No'),
      ];
      valueMap = {'Yes': 'Yes', 'No': 'No'};
    }
    
    return CustomRadioButton(
      options: radioOptions,
      initialValue: _selectedRadioValue,
      onChanged: (value) => _onRadioChanged(value),
      isRequired: true,
    );
  }

  Widget _buildTextField() {
    return CustomFormField(
      initialValue: _textValue,
      controller: _textController,
      onChanged: _onTextChanged,
      isRequired: true,
    );
  }

  Widget _buildNumericField() {
    return CustomFormField(
      initialValue: _textValue,
      controller: _textController,
      onChanged: _onTextChanged,
      isRequired: true,
      inputType: InputType.number,
      hintText: 'Enter Number',
    );
  }

  Widget _buildImageField() {
    return ImageUploadField(
      placeholder: 'Upload Photos',
      isRequired: true,
      externalImageUrl: _imageData,
      onImageSelected: (File? file) async {
        if (file != null) {
          try {
            final apiService = AppConfig.of(context).apiService;
            final imageUploadService = ImageUploadService(
              apiService: apiService,
            );

            final imageData = await file.readAsBytes();
            final photoId = await imageUploadService.uploadImage(
              base64Encode(imageData),
              ActivityTypeEnum.preventiveMaintenance,
              false,
              _currentItem['site_audit_sch_id']?.toString() ?? '',
            );

            if (photoId.isNotEmpty) {
              setState(() {
                _addImageToResponseImages(photoId);
                _imageData = 'data:image/jpeg;base64,${base64Encode(imageData)}';
              });

              _notifyValueChanged();

              if (mounted) {
                try {
                  Toastbar.showSuccessToastbar('Image uploaded successfully', context);
                } catch (err) {
                  Logger.errorLog('Error showing success toast: $err');
                }
              }
            }
          } catch (e) {
            if (mounted) {
              try {
                Toastbar.showErrorToastbar('Error uploading image', context);
              } catch (err) {
                Logger.errorLog('Error showing error toast: $err');
              }
            }
          }
        }
      },
    );
  }

  Widget _buildRemarksField() {
    return CustomRemarksField(
      hintText: 'Remarks',
      controller: _remarksController,
    );
  }

  Widget _buildFieldByType(List<String> respTypesArr) {
    final respTypes = respTypesArr.first.split(",");
    // Handle combined types like DROPDOWN,IMG
    if (respTypes.contains('DROPDOWN') && respTypes.contains('IMG')) {
      return Column(
        children: [
          _buildDropdownField(),

          if (_selectedDropdownValue != 'Not Applicable') ...[
            const SizedBox(height: 12),
            _buildImageField(),
          ],
        ],
      );
    } else if (respTypes.contains('RADIO') && respTypes.contains('IMG')) {
      return Column(
        children: [
          _buildRadioField(),
          const SizedBox(height: 12),
          _buildImageField(),
        ],
      );
    } else if (respTypes.contains('TEXT') && respTypes.contains('IMG')) {
      return Column(
        children: [
          _buildTextField(),
          const SizedBox(height: 12),
          _buildImageField(),
        ],
      );
    } else if (respTypes.contains('NUMERIC') && respTypes.contains('IMG')) {
      return Column(
        children: [
          _buildNumericField(),
          const SizedBox(height: 12),
          _buildImageField(),
        ],
      );
    } else if (respTypes.contains('DROPDOWN')) {
      return _buildDropdownField();
    } else if (respTypes.contains('RADIO')) {
      return _buildRadioField();
    } else if (respTypes.contains('TEXT')) {
      return _buildTextField();
    } else if (respTypes.contains('NUMERIC')) {
      return _buildNumericField();
    } else if (respTypes.contains('IMG')) {
      return _buildImageField();
    } else {
      return Container(
        decoration: BoxDecoration(
          color: AppColors.colorF5F5F5,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.borderColorE0E0E0),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Text(
          'Unknown field type: ${respTypes}',
          style: const TextStyle(
            color: AppColors.white,
            fontFamily: fontFamilyMontserrat,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isReadonlyFromList = widget.readonlyFields.contains(
      _currentItem['checklist_desc']?.toString(),
    );
    final isReadonlyFromItem = _currentItem['is_readonly'] == true;
    final isReadonly = isReadonlyFromList || isReadonlyFromItem;
    final respTypeList = _currentItem['resp_type'];
    final checklistDesc = _currentItem['checklist_desc']?.toString() ?? '';

    // Handle resp_type as array or string
    List<String> respTypes = [];
    if (respTypeList is List) {
      respTypes = respTypeList.map((e) => e.toString()).toList();
    } else if (respTypeList is String) {
      respTypes = [respTypeList];
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: checklistDesc,
                  style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    fontFamily: fontFamilyMontserrat,
                  ),
                ),
                const TextSpan(
                  text: " *",
                  style: TextStyle(fontSize: 16, color: Colors.red),
                ),
              ],
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),

          // Field based on resp_type
          if (isReadonly)
            CustomFormField(
              initialValue: _currentItem['resp']?.toString() ?? 'N/A',
              isRequired: true,
              isEditable: false,
              inputType: respTypes.contains('NUMERIC') ? InputType.number : null,
              hintText: respTypes.contains('NUMERIC') ? 'Enter Number' : null,
            )
          else if (checklistDesc.toLowerCase().contains(
            'rectification remarks',
          ))
            _buildRemarksField()
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildFieldByType(respTypes),
                // Render dependent elements (pass !isReadonly as isEditable)
                ..._buildDependentElements(!isReadonly),
              ],
            ),
        ],
      ),
    );
  }

  /// Get current main field response value for dependent elements visibility
  String? _getCurrentMainResponse() {
    final respTypeList = _currentItem['resp_type'];
    List<String> respTypes = [];
    if (respTypeList is List) {
      respTypes = respTypeList.map((e) => e.toString()).toList();
    } else if (respTypeList is String) {
      respTypes = respTypeList.split(",");
    }
    
    if (respTypes.contains('RADIO')) {
      return _selectedRadioValue;
    } else if (respTypes.contains('DROPDOWN')) {
      return _selectedDropdownValue;
    } else if (respTypes.contains('TEXT') || respTypes.contains('NUMERIC')) {
      return _textController.text;
    }
    
    return null;
  }

  /// Build dependent elements widgets
  List<Widget> _buildDependentElements(bool isEditable) {
    final dependentElements = parseDependentElements(_currentItem);
    if (dependentElements == null || dependentElements.isEmpty) {
      return [];
    }
    
    final currentMainResponse = _getCurrentMainResponse();
    List<Widget> widgets = [];
    
    for (final element in dependentElements) {
      final shouldShow = shouldDependentElementBeVisible(element, currentMainResponse);
      if (!shouldShow) continue;
      
      widgets.add(_buildDependentElement(element, isEditable, currentMainResponse));
    }
    
    return widgets;
  }

  /// Build a single dependent element widget
  Widget _buildDependentElement(
    Map<String, dynamic> element,
    bool isEditable,
    String? parentResponse,
  ) {
    final respType = element['resp_type']?.toString() ?? '';
    final checklistDesc = element['checklist_desc']?.toString() ?? '';
    final isMandatory = isDependentElementMandatory(element, parentResponse);
    final elementKey = '${respType}_${checklistDesc}'; // Create unique key
    final shouldHighlight = _highlightedDependentFields.contains(elementKey);
    
    if (respType == 'IMG') {
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
                    checklistDesc,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: shouldHighlight ? AppColors.errorColor : Colors.white,
                      fontFamily: fontFamilyMontserrat,
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
                key: ValueKey('${_currentItem['pm_check_list_site_resp_id']}_${elementKey}_image'),
                placeholder: checklistDesc,
                isRequired: isMandatory,
                onImageSelected: isEditable
                    ? (File? file) {
                        if (file != null) {
                          _uploadDependentImage(elementKey, file);
                          // Clear highlight when image is added
                          _clearDependentFieldHighlight(elementKey);
                        } else {
                          setState(() {
                            _dependentImageIds[elementKey] = null;
                            _dependentImageFiles[elementKey] = null;
                          });
                        }
                      }
                    : (File? file) {},
                externalImageUrl: _dependentImageData[elementKey],
                isDisabled: !isEditable,
              ),
            ],
          ),
        ),
      );
    } else if (respType == 'REMARKS' || respType == 'TEXT') {
      // Get or create controller for this dependent element
      if (!_dependentControllers.containsKey(elementKey)) {
        _dependentControllers[elementKey] = TextEditingController(
          text: respType == 'REMARKS'
              ? (_dependentRemarks[elementKey] ?? '')
              : (_dependentTextValues[elementKey] ?? ''),
        );
        _dependentControllers[elementKey]!.addListener(() {
          final value = _dependentControllers[elementKey]?.text ?? '';
          if (respType == 'REMARKS') {
            _dependentRemarks[elementKey] = value;
          } else {
            _dependentTextValues[elementKey] = value;
          }
          // Clear highlight when text is entered
          if (value.isNotEmpty) {
            _clearDependentFieldHighlight(elementKey);
          }
          _notifyValueChanged();
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
            label: checklistDesc,
            hintText: "Enter ${checklistDesc.toLowerCase()}",
            controller: _dependentControllers[elementKey]!,
            isDisabled: !isEditable,
          ),
        ),
      );
    }
    
    return const SizedBox.shrink();
  }

  /// Upload dependent image
  Future<void> _uploadDependentImage(String elementKey, File imageFile) async {
    try {
      setState(() {
        _dependentImageFiles[elementKey] = imageFile;
        _dependentImageData[elementKey] = null; // Clear previous image
      });

      // Get site data - we need siteId from current item
      final siteAuditSchId = _currentItem['site_audit_sch_id']?.toString() ?? '';
      
      if (siteAuditSchId.isEmpty) {
        if (mounted) {
          try {
            Toastbar.showErrorToastbar('Site ID not available', context);
          } catch (e) {
            // Context might be deactivated, ignore
          }
        }
        return;
      }

      // Use ImageUploadService like the main image field
      if (!mounted) return;
      final apiService = AppConfig.of(context).apiService;
      final imageUploadService = ImageUploadService(apiService: apiService);

      final imageData = await imageFile.readAsBytes();
      final photoId = await imageUploadService.uploadImage(
        base64Encode(imageData),
        ActivityTypeEnum.preventiveMaintenance,
        false,
        siteAuditSchId,
      );

      if (photoId.isNotEmpty) {
        setState(() {
          _dependentImageIds[elementKey] = photoId;
          // Store base64 image data for display
          _dependentImageData[elementKey] = 'data:image/jpeg;base64,${base64Encode(imageData)}';
          // Add to responseImages array
          _addImageToResponseImages(photoId);
        });
        
        _notifyValueChanged();
        
        // Show success message
        if (mounted) {
          try {
            Toastbar.showSuccessToastbar('Image uploaded successfully', context);
          } catch (e) {
            Logger.errorLog('Error showing success toast: $e');
          }
        }
      } else {
        Logger.errorLog('❌ Failed to get image ID after upload');
        if (mounted) {
          try {
            Toastbar.showErrorToastbar('Failed to upload photo', context);
          } catch (e) {
            Logger.errorLog('Error showing error toast: $e');
          }
        }
      }
    } catch (e) {
      Logger.errorLog('❌ Error uploading dependent image: $e');
      if (mounted) {
        setState(() {
          _dependentImageIds[elementKey] = null;
          _dependentImageData[elementKey] = null;
          _dependentImageFiles[elementKey] = null;
        });
      }
      if (mounted) {
        try {
          Toastbar.showErrorToastbar('Error uploading image', context);
        } catch (err) {
          Logger.errorLog('Error showing error toast: $err');
        }
      }
    }
  }

  /// Highlight a dependent field (called from parent validation)
  void highlightDependentField(String elementKey) {
    setState(() {
      _highlightedDependentFields.add(elementKey);
    });
  }
  
  /// Clear highlight for a dependent field
  void _clearDependentFieldHighlight(String elementKey) {
    setState(() {
      _highlightedDependentFields.remove(elementKey);
    });
  }

  /// Get dependent image ID by element key
  String? getDependentImageId(String elementKey) {
    return _dependentImageIds[elementKey];
  }
  
  /// Get dependent remarks by element key
  String? getDependentRemarks(String elementKey) {
    return _dependentRemarks[elementKey];
  }
  
  /// Get dependent text value by element key
  String? getDependentTextValue(String elementKey) {
    return _dependentTextValues[elementKey];
  }

  /// Validate dependent elements
  List<String> validateDependentElements(String? parentResponse) {
    final dependentElements = parseDependentElements(_currentItem);
    if (dependentElements == null || dependentElements.isEmpty) {
      return [];
    }
    
    List<String> errors = [];
    
    for (final element in dependentElements) {
      final respType = element['resp_type']?.toString() ?? '';
      final checklistDesc = element['checklist_desc']?.toString() ?? '';
      final elementKey = '${respType}_${checklistDesc}';
      
      final isMandatory = isDependentElementMandatory(element, parentResponse);
      if (!isMandatory) continue;
      
      if (respType == 'IMG') {
        final imageId = _dependentImageIds[elementKey];
        if (imageId == null || imageId.isEmpty) {
          errors.add('$checklistDesc is required');
        }
      } else if (respType == 'REMARKS' || respType == 'TEXT') {
        final value = respType == 'REMARKS'
            ? _dependentRemarks[elementKey]
            : _dependentTextValues[elementKey];
        if (value == null || value.trim().isEmpty) {
          errors.add('$checklistDesc is required');
        }
      }
    }
    
    return errors;
  }

  /// Get current values including dependent elements for form submission
  Map<String, dynamic> getCurrentValuesWithDependentElements() {
    final values = Map<String, dynamic>.from(_currentItem);
    
    // Add dependent elements data to response_details or remarks
    final dependentElements = parseDependentElements(_currentItem);
    if (dependentElements != null && dependentElements.isNotEmpty) {
      List<String> remarksList = [];
      
      for (final element in dependentElements) {
        final respType = element['resp_type']?.toString() ?? '';
        final checklistDesc = element['checklist_desc']?.toString() ?? '';
        final elementKey = '${respType}_${checklistDesc}';
        
        if (respType == 'IMG') {
          final imageId = _dependentImageIds[elementKey];
          // Store dependent image ID - could be added to response_details if needed
          values['dependent_${elementKey}_image_id'] = imageId;
        } else if (respType == 'REMARKS') {
          final remarks = _dependentRemarks[elementKey];
          if (remarks != null && remarks.trim().isNotEmpty) {
            remarksList.add(remarks.trim());
          }
        } else if (respType == 'TEXT') {
          final textValue = _dependentTextValues[elementKey];
          values['dependent_${elementKey}_text'] = textValue;
        }
      }
      
      // Add remarks to current item if any exist
      if (remarksList.isNotEmpty) {
        final existingRemarks = values['remarks']?.toString() ?? '';
        final combinedRemarks = existingRemarks.isNotEmpty
            ? '$existingRemarks; ${remarksList.join("; ")}'
            : remarksList.join("; ");
        values['remarks'] = combinedRemarks;
      }
    }
    
    return values;
  }
}
