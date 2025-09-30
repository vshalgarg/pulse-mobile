import 'dart:convert';
import 'dart:io';
import 'package:app/commonWidgets/custom_radio_options.dart';
import 'package:app/commonWidgets/qr_screen_form_field.dart';
import 'package:app/utils/asset_audit_validation_helper.dart';
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
  
  // Dynamic dropdown specific variables
  List<Map<String, dynamic>> _dynamicDropdownData = [];
  final TextEditingController _serialNumberController = TextEditingController();
  final Map<String, TextEditingController> _childFieldControllers = {};
  Map<String, dynamic>? _selectedItemData;

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
    _serialNumberController.dispose();
    _childFieldControllers.values.forEach((controller) => controller.dispose());
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

    // Initialize dynamic dropdown
    if (respType == 'DYNAMIC_DROPDOWN') {
      _initializeDynamicDropdown();
    }
  }

  void _initializeDynamicDropdown() {
    // Initialize child field controllers
    final childItems = _currentItem['childitemData'] as List<dynamic>? ?? [];
    for (var childItem in childItems) {
      final fieldName = childItem['checklist_desc']?.toString() ?? '';
      if (fieldName.isNotEmpty) {
        _childFieldControllers[fieldName] = TextEditingController();
      }
    }
    
    // Initialize dynamic dropdown data from current item
    final existingData = _currentItem['dynamicDropdownData'] as List<dynamic>? ?? [];
    _dynamicDropdownData = existingData.map((item) => Map<String, dynamic>.from(item)).toList();
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

  // Dynamic dropdown methods
  void _onQRScanned(String scannedCode) {
    // Find matching item in siteDeployedItems
    final siteDeployedItems = _currentItem['siteDeployedItems'] as Map<String, dynamic>? ?? {};
    final subItemType = _currentItem['sub_item_type']?.toString() ?? '';
    final deployedItems = siteDeployedItems[subItemType] as List<dynamic>? ?? [];
    
    Map<String, dynamic>? matchingItem = AssetAuditValidationHelper.findItemWithSerialNumber(scannedCode, deployedItems, true);
    if (matchingItem != null) {
      setState(() {
        _selectedItemData = Map<String, dynamic>.from(matchingItem ?? {});
        _serialNumberController.text = matchingItem?['mfg_serial_no']?.toString() ?? '';
      });
    } else {
      Toastbar.showErrorToastbar('Serial number is invalid', context);
    }
  }

  void _saveDynamicDropdownData() {
    if (_selectedItemData == null) {
      Toastbar.showErrorToastbar('Please scan a valid serial number first', context);
      return;
    }

    // Validate child fields
    final childItems = _currentItem['childitemData'] as List<dynamic>? ?? [];
    for (var childItem in childItems) {
      final fieldName = childItem['checklist_desc']?.toString() ?? '';
      final isMandatory = childItem['is_mandatory'] == true;
      final controller = _childFieldControllers[fieldName];
      
      if (isMandatory && (controller?.text.isEmpty ?? true)) {
        Toastbar.showErrorToastbar('Please fill all mandatory fields', context);
        return;
      }
    }

    // Create data entry
    final dataEntry = {
      "cmImpactedItemId": 0,
      "itemInstanceId": _selectedItemData!['item_instance_id'],
      "mfgSerialNo": _selectedItemData!['mfg_serial_no'],
      "nexgenSerialNo": _selectedItemData!['nexgen_serial_no'],
      "isScanned": true,
      "cmItemType": _selectedItemData!['item_type'],
      "soc": _childFieldControllers['SOC']?.text ?? '',
      "soh": _childFieldControllers['SOH']?.text ?? '',
      "outputVoltage": 0,
      "isActive": true,
      "remarks": ""
    };

    setState(() {
      _dynamicDropdownData.add(dataEntry);
      _currentItem['dynamicDropdownData'] = _dynamicDropdownData;
    });

    // Clear form
    _serialNumberController.clear();
    _childFieldControllers.values.forEach((controller) => controller.clear());
    _selectedItemData = null;

    _notifyValueChanged();
    Toastbar.showSuccessToastbar('Data saved successfully', context);
  }

  void _editDynamicDropdownItem(int index) {
    final item = _dynamicDropdownData[index];
    setState(() {
      _serialNumberController.text = item['mfgSerialNo']?.toString() ?? '';
      _childFieldControllers['SOC']?.text = item['soc']?.toString() ?? '';
      _childFieldControllers['SOH']?.text = item['soh']?.toString() ?? '';
    });
  }

  void _updateDynamicDropdownItem(int index) {
    if (_selectedItemData == null) {
      Toastbar.showErrorToastbar('Please scan a valid serial number first', context);
      return;
    }

    // Validate child fields
    final childItems = _currentItem['childitemData'] as List<dynamic>? ?? [];
    for (var childItem in childItems) {
      final fieldName = childItem['checklist_desc']?.toString() ?? '';
      final isMandatory = childItem['is_mandatory'] == true;
      final controller = _childFieldControllers[fieldName];
      
      if (isMandatory && (controller?.text.isEmpty ?? true)) {
        Toastbar.showErrorToastbar('Please fill all mandatory fields', context);
        return;
      }
    }

    // Update data entry
    final updatedEntry = {
      "cmImpactedItemId": _dynamicDropdownData[index]['cmImpactedItemId'],
      "itemInstanceId": _selectedItemData!['item_instance_id'],
      "mfgSerialNo": _selectedItemData!['mfg_serial_no'],
      "nexgenSerialNo": _selectedItemData!['nexgen_serial_no'],
      "isScanned": true,
      "cmItemType": _selectedItemData!['item_type'],
      "soc": _childFieldControllers['SOC']?.text ?? '',
      "soh": _childFieldControllers['SOH']?.text ?? '',
      "outputVoltage": 0,
      "isActive": true,
      "remarks": ""
    };

    setState(() {
      _dynamicDropdownData[index] = updatedEntry;
      _currentItem['dynamicDropdownData'] = _dynamicDropdownData;
    });

    // Clear form
    _serialNumberController.clear();
    _childFieldControllers.values.forEach((controller) => controller.clear());
    _selectedItemData = null;

    _notifyValueChanged();
    Toastbar.showSuccessToastbar('Data updated successfully', context);
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

  Widget _buildDynamicDropdownField() {
    final childItems = _currentItem['childitemData'] as List<dynamic>? ?? [];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Serial Number field with QR scanner
        SerialNumberField(
          label: 'Battery - Serial Number',
          controller: _serialNumberController,
          onQRScanned: _onQRScanned,
        ),
        const SizedBox(height: 16),
        
        // Child fields (SOC, SOH, etc.)
        ...childItems.map((childItem) {
          final fieldName = childItem['checklist_desc']?.toString() ?? '';
          final isMandatory = childItem['is_mandatory'] == true;
          final controller = _childFieldControllers[fieldName];
          
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: CustomFormField(
              label: fieldName,
              controller: controller,
              isRequired: isMandatory,
            ),
          );
        }).toList(),
        
        // Save button
        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton(
            onPressed: _saveDynamicDropdownData,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Save'),
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Data table
        if (_dynamicDropdownData.isNotEmpty) ...[
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              children: [
                // Table header
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(8),
                      topRight: Radius.circular(8),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(flex: 2, child: Text('Serial Number', style: TextStyle(fontWeight: FontWeight.bold))),
                      Expanded(child: Text('Scanned', style: TextStyle(fontWeight: FontWeight.bold))),
                      Expanded(child: Text('SOC', style: TextStyle(fontWeight: FontWeight.bold))),
                      Expanded(child: Text('SOH', style: TextStyle(fontWeight: FontWeight.bold))),
                      Expanded(child: Text('Edit', style: TextStyle(fontWeight: FontWeight.bold))),
                    ],
                  ),
                ),
                // Table rows
                ..._dynamicDropdownData.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;
                  
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: Colors.grey.shade200)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Text(item['mfgSerialNo']?.toString() ?? ''),
                        ),
                        Expanded(
                          child: Text(item['isScanned'] == true ? 'Yes' : 'No'),
                        ),
                        Expanded(
                          child: Text(item['soc']?.toString() ?? ''),
                        ),
                        Expanded(
                          child: Text(item['soh']?.toString() ?? ''),
                        ),
                        Expanded(
                          child: IconButton(
                            icon: const Icon(Icons.edit, size: 20),
                            onPressed: () => _editDynamicDropdownItem(index),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
        ],
      ],
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
      case 'DYNAMIC_DROPDOWN':
        return _buildDynamicDropdownField();
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
