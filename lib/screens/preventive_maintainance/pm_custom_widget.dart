import 'dart:convert';
import 'dart:io';
import 'package:app/screens/asset_audit/asset_audit_widget_helper/WidgetHelper.dart';
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
  State<PMCustomWidget> createState() => _PMCustomWidgetState();
}

class _PMCustomWidgetState extends State<PMCustomWidget> {
  late Map<String, dynamic> _currentItem;
  String? _selectedDropdownValue;
  String? _selectedRadioValue;
  String? _textValue;
  String? _imageData;
  final TextEditingController _textController = TextEditingController();
  final TextEditingController _remarksController = TextEditingController();

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

    // Initialize radio value - convert 1/0 to Yes/No
    if (respTypes.contains('RADIO')) {
      _selectedRadioValue = respValue == null || respValue.isEmpty
          ? 'Yes'
          : respValue;
      if (respValue == null || respValue.isEmpty) {
        _onRadioChanged('Yes');
      }
    }

    // Initialize text value
    _textValue = respValue?.toString();
    _textController.text = _textValue ?? '';

    // Initialize remarks value
    _remarksController.text = respValue?.toString() ?? '';

    // Load image data if photo_id exists
    if (_currentItem['photo_id'] != null) {
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
  }

  void _onRadioChanged(String? value) {
    setState(() {
      _selectedRadioValue = value;
      // Convert Yes/No to 1/0 for API compatibility
      _currentItem['resp'] = value;
    });
    _notifyValueChanged();
  }

  void _onTextChanged(String value) {
    setState(() {
      _textValue = value;
      _currentItem['resp'] = value;
    });
    _notifyValueChanged();
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
    return WidgetHelper.buildRadioField(
      isRequired: true,
      initialSelectedValue: _selectedRadioValue ?? 'Yes',
      onChanged: _onRadioChanged,
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
                _currentItem['photo_id'] = photoId;
                _imageData = imageData.toString().startsWith('data:image/')
                    ? imageData.toString()
                    : 'data:image/jpeg;base64,$imageData';
              });

              _notifyValueChanged();

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Image uploaded successfully'),
                    backgroundColor: AppColors.primaryGreen,
                  ),
                );
              }
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error uploading image: $e'),
                  backgroundColor: AppColors.errorColor,
                ),
              );
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
            _buildFieldByType(respTypes),
        ],
      ),
    );
  }
}
