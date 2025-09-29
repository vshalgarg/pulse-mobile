import 'dart:convert';
import 'dart:io';
import 'package:app/commonWidgets/custom_radio_options.dart';
import 'package:app/utils/toastbar.dart';
import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../constants/constants_strings.dart';
import '../../commonWidgets/custom_remark.dart';
import '../../commonWidgets/custom_form_field.dart';
import '../../commonWidgets/custom_form_dropdown.dart';
import '../../commonWidgets/custom_horizontal_radio_buttons.dart';
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
    final respType = _currentItem['resp_type']?.toString();

    // Initialize dropdown value
    if (respType == 'DROPDOWN') {
      _selectedDropdownValue = respValue;
    }

    // Initialize radio value
    if (respType == 'RADIO') {
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
      // TODO: Implement image loading logic
      print('Loading image for photoId: $photoId');
    } catch (e) {
      print('Error loading image for photoId $photoId: $e');
    }
  }

  void _notifyValueChanged() {
    widget.onValueChanged(_currentItem);
  }

  void _onDropdownChanged(String? value) {
    setState(() {
      _selectedDropdownValue = value;
      _currentItem['resp'] = value;
    });
    _notifyValueChanged();
  }

  void _onRadioChanged(String? value) {
    setState(() {
      _selectedRadioValue = value;
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
    // Parse resp_type_value_map to get dropdown options
    final valueMap = _currentItem['resp_type_value_map'];
    List<String> dropdownOptions = [];
    
    if (valueMap is Map<String, dynamic>) {
      dropdownOptions = valueMap.keys.toList();
    } else if (valueMap is String) {
      try {
        final parsedMap = jsonDecode(valueMap) as Map<String, dynamic>;
        dropdownOptions = parsedMap.keys.toList();
      } catch (e) {
        dropdownOptions = ['OK', 'Not OK']; // Default options
      }
    } else {
      dropdownOptions = ['OK', 'Not OK']; // Default options
    }

    return CustomDropdown(
      label: _currentItem['checklist_desc']?.toString() ?? '',
      items: dropdownOptions,
      initialValue: _selectedDropdownValue,
      onChanged: (value) => _onDropdownChanged(value),
      isRequired: _currentItem['is_mandatory'] == true,
    );
  }

  Widget _buildRadioField() {
    // Parse resp_type_value_map to get radio options
    final valueMap = _currentItem['resp_type_value_map'];
    List<OptionItem> radioOptions = [];
    
    if (valueMap is Map<String, dynamic>) {
      radioOptions = valueMap.entries.map((entry) => 
        OptionItem(
          value: entry.value,
          label: entry.key,
        ),
      ).toList();
    } else if (valueMap is String) {
      try {
        final parsedMap = jsonDecode(valueMap) as Map<String, dynamic>;
        radioOptions = parsedMap.entries.map((entry) =>
            OptionItem(
              value: entry.value,
              label: entry.key,
            ),
        ).toList();
      } catch (e) {
        radioOptions = [
          OptionItem(label: "OK", value: "OK"),
          OptionItem(label: "Not OK", value: "Not OK")
        ];
      }
    } else {
      radioOptions = [
        OptionItem(label: "OK", value: "OK"),
        OptionItem(label: "Not OK", value: "Not OK")
      ];
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_currentItem['checklist_desc'] != null)
          CustomRadioButton(
            label: _currentItem['checklist_desc'],
            options: radioOptions,
            initialValue: _selectedRadioValue,
            onChanged: (value) => _onRadioChanged(value),
            isRequired: _currentItem['is_mandatory'] == true,
          ),
      ],
    );
  }

  Widget _buildTextField() {
    return CustomFormField(
      label: _currentItem['checklist_desc']?.toString() ?? '',
      initialValue: _textValue,
      controller: _textController,
      onChanged: _onTextChanged,
      isRequired: _currentItem['is_mandatory'] == true,
    );
  }

  Widget _buildImageField() {
    return ImageUploadField(
      label: _currentItem['checklist_desc']?.toString() ?? '',
      placeholder: 'Upload Photos',
      isRequired: _currentItem['is_mandatory'] == true,
      externalImageUrl: _imageData,
      onImageSelected: (File? file) async {
        if (file != null) {
          try {
            // TODO: Implement image upload logic
            setState(() {
              _imageData = file.path;
              _currentItem['resp'] = file.path;
            });
            _notifyValueChanged();
            
            if (mounted) {
              Toastbar.showSuccessToastbar("Image uploaded successfully", context);
            }
          } catch (e) {
            if (mounted) {
              Toastbar.showErrorToastbar("Error uploading image: $e", context);
            }
          }
        }
      },
    );
  }

  Widget _buildRemarksField() {
    return CustomRemarksField(
      label: _currentItem['checklist_desc']?.toString() ?? '',
      hintText: 'Remarks',
      controller: _remarksController,
    );
  }

  Widget _buildFieldByType(String respType) {
    switch (respType) {
      case 'DROPDOWN':
        return _buildDropdownField();
      case 'RADIO':
        return _buildRadioField();
      case 'TEXT':
        return _buildTextField();
      case 'IMG':
        return _buildImageField();
      case 'REMARKS':
        return _buildRemarksField();
      default:
        return Container(
          decoration: BoxDecoration(
            color: AppColors.colorF5F5F5,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.borderColorE0E0E0),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Text(
            'Unknown field type: $respType',
            style: const TextStyle(
              color: AppColors.black,
              fontFamily: fontFamilyMontserrat,
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isReadonly = widget.readonlyFields.contains(
      _currentItem['checklist_desc']?.toString(),
    );
    final respType = _currentItem['resp_type']?.toString() ?? '';
    final checklistDesc = _currentItem['checklist_desc']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Field based on resp_type
          if (isReadonly)
            CustomFormField(
              label: checklistDesc,
              initialValue: _currentItem['resp']?.toString() ?? 'N/A',
              isRequired: _currentItem['is_mandatory'] == true,
              isEditable: false,
            )
          else if (checklistDesc.toLowerCase().contains('remarks'))
            _buildRemarksField()
          else
            _buildFieldByType(respType),
        ],
      ),
    );
  }
}
