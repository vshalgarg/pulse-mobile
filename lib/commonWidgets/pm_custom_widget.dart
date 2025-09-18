import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/constants_strings.dart';
import '../services/image_upload_service.dart';
import '../enum/activity_type_enum.dart';
import '../app_config.dart';
import 'custom_remark.dart';
import 'custom_form_field.dart';
import 'custom_form_dropdown.dart';
import 'custom_radio_options.dart';
import 'custom_image_upload_field.dart';

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
    
    // Initialize dropdown value - convert numeric to string
    if (respTypes.contains('DROPDOWN')) {
      _selectedDropdownValue = respValue;
    }
    
    // Initialize radio value - convert 1/0 to Yes/No
    if (respTypes.contains('RADIO')) {
      _selectedRadioValue = respValue;
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
          _imageData = 'data:image/jpeg;base64,$imageData';
        });
        print('✅ Image loaded successfully for photoId: $photoId');
      } else {
        print('⚠️ No image data found for photoId: $photoId');
      }
    } catch (e) {
      print('❌ Error loading image for photoId $photoId: $e');
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
    if (respTypes.contains('DROPDOWN') && (respValue == null || respValue.toString().isEmpty)) {
      return false;
    }
    
    if (respTypes.contains('RADIO') && (respValue == null || respValue.toString().isEmpty)) {
      return false;
    }
    
    if (respTypes.contains('TEXT') && (respValue == null || respValue.toString().trim().isEmpty)) {
      return false;
    }
    
    if (respTypes.contains('IMG') && (respValue == null || respValue.toString().isEmpty)) {
      return false;
    }
    
    return true;
  }

  /// Get validation error message for this field
  String? getValidationError() {
    final respValue = _currentItem['resp'];
    final respTypeList = _currentItem['resp_type'];
    final checklistDesc = _currentItem['checklist_desc']?.toString() ?? 'This field';
    
    // Handle resp_type as array or string
    List<String> respTypes = [];
    if (respTypeList is List) {
      respTypes = respTypeList.map((e) => e.toString()).toList();
    } else if (respTypeList is String) {
      respTypes = respTypeList.split(",");
    }
    
    // Check if any required field is empty
    if (respTypes.contains('DROPDOWN') && (respValue == null || respValue.toString().isEmpty)) {
      return '$checklistDesc is required';
    }
    
    if (respTypes.contains('RADIO') && (respValue == null || respValue.toString().isEmpty)) {
      return '$checklistDesc is required';
    }
    
    if (respTypes.contains('TEXT') && (respValue == null || respValue.toString().trim().isEmpty)) {
      return '$checklistDesc is required';
    }
    
    if (respTypes.contains('IMG') && (respValue == null || respValue.toString().isEmpty)) {
      return '$checklistDesc is required';
    }
    
    return null;
  }

  void _onDropdownChanged(String? value) {
    setState(() {
      _selectedDropdownValue = value;
      // Convert dropdown selection back to numeric value for API
      _currentItem['resp'] = value;
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

  Widget _buildDropdownField() {
    const dropdownOptions = [
      'OK',
      'Corrected',
      'NOT OK - To be corrected',
      'Not Applicable',
    ];

    return CustomDropdown(
      items: dropdownOptions,
      initialValue: _selectedDropdownValue,
      onChanged: (value) => _onDropdownChanged(value),
    );
  }

  Widget _buildRadioField() {
    return CustomOptionSelector(
      options: [
        OptionItem(
          value: 'Yes', 
          label: 'Yes',
          selectedIcon: Icons.radio_button_checked,
          unselectedIcon: Icons.radio_button_unchecked,
        ),
        OptionItem(
          value: 'No', 
          label: 'No',
          selectedIcon: Icons.radio_button_checked,
          unselectedIcon: Icons.radio_button_unchecked,
        ),
      ],
      initialValue: _selectedRadioValue,
      onChanged: (value) => _onRadioChanged(value),
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

  Widget _buildImageField() {
    return ImageUploadField(
      placeholder: 'Upload Photos',
      isRequired: true,
      externalImageUrl: _imageData,
      onImageSelected: (File? file) async {
        if (file != null) {
          try {
            final apiService = AppConfig.of(context).apiService;
            final imageUploadService = ImageUploadService(apiService: apiService);
            
            final imageData = await file.readAsBytes();
            final photoId = await imageUploadService.uploadImage(
              base64Encode(imageData),
              ActivityTypeEnum.preventiveMaintenance,
              _currentItem['site_audit_sch_id']?.toString() ?? '',
            );

            if (photoId.isNotEmpty) {
              setState(() {
                _currentItem['photo_id'] = photoId;
                _imageData = 'data:image/jpeg;base64,${base64Encode(imageData)}';
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
          const SizedBox(height: 12),
          _buildImageField(),
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
    } else if (respTypes.contains('DROPDOWN')) {
      return _buildDropdownField();
    } else if (respTypes.contains('RADIO')) {
      return _buildRadioField();
    } else if (respTypes.contains('TEXT')) {
      return _buildTextField();
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
    final isReadonly = widget.readonlyFields.contains(_currentItem['checklist_desc']?.toString());
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
          Row(
            children: [
              Expanded(
                child: Text(
                  checklistDesc,
                  style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    fontFamily: fontFamilyMontserrat,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ),
              const Text(
                " *",
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.red,
                ),
              ),
            ]
          ),
          const SizedBox(height: 8),
          
          // Field based on resp_type
          if (isReadonly)
            CustomFormField(
              initialValue: _currentItem['resp']?.toString() ?? 'N/A',
              isRequired: true,
              isEditable: false,
            )
          else if (checklistDesc.toLowerCase().contains('rectification remarks'))
            _buildRemarksField()
          else
            _buildFieldByType(respTypes),
        ],
      ),
    );
  }
}
