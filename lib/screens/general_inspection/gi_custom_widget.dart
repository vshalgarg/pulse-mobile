import 'dart:convert';
import 'dart:io';

import 'package:app/commonWidgets/custom_horizontal_radio_buttons.dart';
import 'package:app/commonWidgets/custom_image_upload_field.dart';
import 'package:app/constants/app_colors.dart';
import 'package:app/enum/corrective_maintenance_screen_mode_enum.dart';
import 'package:app/models/gen_ins_checklist_model.dart';
import 'package:app/utils/logger.dart';
import 'package:flutter/material.dart';

class GICustomChecklistItem extends StatefulWidget {
  final GenInsCheckListData checklistItem;
  final CMScreenModeEnum mode;
  final Function(String? value)? onRadioChanged; // Callback for radio button changes (returns key)
  final Function(File? imageFile)? onImageChanged; // Callback for image changes (returns File)

  const GICustomChecklistItem({
    super.key,
    required this.checklistItem,
    this.mode = CMScreenModeEnum.create, // Default to create mode
    this.onRadioChanged,
    this.onImageChanged,
  });

  @override
  State<GICustomChecklistItem> createState() => _GICustomChecklistItemState();
}

class _GICustomChecklistItemState extends State<GICustomChecklistItem> {
  String? _selectedRadioValue; // Stores the displayed value (e.g., "Yes")
  File? _imageFile; // Stores the captured image file

  @override
  void initState() {
    super.initState();
    // Initialize state if needed, e.g., from existing data in view mode
    // For now, assuming no pre-filled data for simplicity.
  }

  @override
  Widget build(BuildContext context) {
    bool isEditable = widget.mode != CMScreenModeEnum.view;
    bool hasRadio = widget.checklistItem.respType.contains('RADIO');
    bool hasImage = widget.checklistItem.respType.contains('IMG');

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: const Color(0xFF4A4A5A), // Dark grey background for the card
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

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: CustomHorizontalRadioButtons(
        options: radioOptions,
        selectedValue: _selectedRadioValue,
        onButtonSelected: isEditable
            ? (value) {
                setState(() {
                  _selectedRadioValue = value;
                });
                // Find the key corresponding to the selected value
                String? selectedKey;
                valueMap.forEach((key, val) {
                  if (val == value) {
                    selectedKey = key;
                  }
                });
                widget.onRadioChanged?.call(selectedKey);
              }
            : null, // Disable if not editable
      ),
    );
  }

  Widget _buildImageUploadField(bool isEditable) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: ImageUploadField(
        label: "Add a Photo", // Fixed label as per image
        placeholder: "Add a Photo",
        isRequired: widget.checklistItem.isMandatory,
        onImageSelected: isEditable
            ? (File? file) {
                setState(() {
                  _imageFile = file;
                });
                widget.onImageChanged?.call(_imageFile);
              }
            : (File? file) {}, // Provide empty function if not editable
        externalImageUrl: _imageFile != null ? _imageFile!.path : null,
        isDisabled: !isEditable,
      ),
    );
  }

  // Validation method to check if mandatory fields are filled
  String? validateField() {
    if (!widget.checklistItem.isMandatory) {
      return null; // Not mandatory, no validation needed
    }

    bool hasRadio = widget.checklistItem.respType.contains('RADIO');
    bool hasImage = widget.checklistItem.respType.contains('IMG');

    if (hasRadio && (_selectedRadioValue == null || _selectedRadioValue!.isEmpty)) {
      return '${widget.checklistItem.checklistDesc} is required';
    }

    if (hasImage && _imageFile == null) {
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
    
    if (widget.checklistItem.respType.contains('IMG')) {
      values['image_file'] = _imageFile;
    }
    
    return values;
  }
}
