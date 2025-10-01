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
import '../../commonWidgets/custom_image_upload_field.dart';

class CMCustomWidget extends StatefulWidget {
  final Map<String, dynamic> pmItem;
  final List<String> readonlyFields;
  final Function(Map<String, dynamic>) onValueChanged;
  final Function(List<Map<String, dynamic>>) onImpactedItemListChanged;
  final List<Map<String,dynamic>> cmImpactedItemList;
  final Map<String, dynamic> originalCmImpactedItemMap;
  final Function(List<Map<String, dynamic>>, String) onMultiDynamicDropdownValueChanged;

  const CMCustomWidget({
    super.key,
    required this.pmItem,
    required this.readonlyFields,
    required this.onValueChanged,
    required this.onImpactedItemListChanged,
    required this.cmImpactedItemList,
    required this.originalCmImpactedItemMap,
    required this.onMultiDynamicDropdownValueChanged,
  });

  @override
  State<CMCustomWidget> createState() => _CMCustomWidgetState();
}

class _CMCustomWidgetState extends State<CMCustomWidget> {
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
  
  // Multi dynamic dropdown specific variables
  List<Map<String, dynamic>> _selectedMultiItems = [];
  List<Map<String, dynamic>> _availableMultiOptions = [];
  bool _isMultiDropdownOpen = false;

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
  void didUpdateWidget(CMCustomWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-initialize if pmItem has changed
    if (oldWidget.pmItem != widget.pmItem) {
      setState(() {
        _currentItem = Map<String, dynamic>.from(widget.pmItem);
        _initializeValues();
      });
    }
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
    
    // Initialize multi dynamic dropdown
    if (respType == 'MULTI_DYNAMIC_DROPDOWN') {
      _initializeMultiDynamicDropdown();
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

    _dynamicDropdownData = widget.cmImpactedItemList.map((item) => Map<String, dynamic>.from(item)).toList();
  }

  void _initializeMultiDynamicDropdown() {
    // Get sub_item_type to filter options from originalCmImpactedItemMap
    final subItemType = _currentItem['sub_item_type']?.toString() ?? '';
    
    // Get available options from originalCmImpactedItemMap based on sub_item_type
    if (widget.originalCmImpactedItemMap.containsKey(subItemType)) {
      final options = widget.originalCmImpactedItemMap[subItemType] as List<dynamic>? ?? [];
      _availableMultiOptions = options.map((item) => Map<String, dynamic>.from(item)).toList();
    }
    
    // Initialize selected items from current response
    final currentResp = _currentItem['resp'];
    if (currentResp is List) {
      _selectedMultiItems = currentResp.map((item) => Map<String, dynamic>.from(item)).toList();
    }
  }

  // Helper method to get field names from childItemsData
  Map<String, String> _getFieldNamesFromChildItems() {
    final childItems = _currentItem['childitemData'] as List<dynamic>? ?? [];
    final fieldNames = <String, String>{};
    
    for (var childItem in childItems) {
      final fieldName = childItem['checklist_desc']?.toString() ?? '';
      final impactedItemValueMap = childItem['impacted_item_value_map']?.toString() ?? '';
      
      if (fieldName.isNotEmpty && impactedItemValueMap.isNotEmpty) {
        fieldNames[fieldName] = impactedItemValueMap;
      }
    }
    
    return fieldNames;
  }

  void _notifyValueChanged() {
    // For MULTI_DYNAMIC_DROPDOWN, return only the selected items array with dropdown ID
    if (_currentItem['resp_type'] == 'MULTI_DYNAMIC_DROPDOWN') {
      final dropdownId = '${_currentItem['cm_check_list_mst_id']}_${_currentItem['sub_item_type']}';
      for (var item in _selectedMultiItems) {
        item['resp_type'] = _currentItem['resp_type'];
        item['sub_item_type'] = _currentItem['sub_item_type'];
      }
      widget.onMultiDynamicDropdownValueChanged(_selectedMultiItems, dropdownId);
    } else {
      widget.onValueChanged(_currentItem);
    }
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
    // Defer state update to avoid setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _currentItem['resp'] = value;
        });
        _notifyValueChanged();
      }
    });
  }

  // Dynamic dropdown methods
  void _onQRScanned(String scannedCode) {
    _validateAndSetSerialNumber(scannedCode, true);
  }

  void _validateAndSetSerialNumber(String serialNo, bool isQrCodeScanned) {
    final siteDeployedItems = widget.originalCmImpactedItemMap as Map<String, dynamic>? ?? {};
    final subItemType = _currentItem['sub_item_type']?.toString() ?? '';
    final deployedItems = siteDeployedItems[subItemType] as List<dynamic>? ?? [];

    Map<String, dynamic>? matchingItem = AssetAuditValidationHelper.findItemWithSerialNumber(serialNo, deployedItems, isQrCodeScanned);
    if (matchingItem != null) {
      setState(() {
        _selectedItemData = Map<String, dynamic>.from(matchingItem);
        _serialNumberController.text = matchingItem['mfg_serial_no']?.toString() ?? '';
      });
    } else {
      if(isQrCodeScanned) {
        Toastbar.showErrorToastbar('Serial number is invalid', context);
      }
    }
  }

  void _saveDynamicDropdownData() {
    if (_selectedItemData == null) {
      if(_serialNumberController.text.isNotEmpty) {
        _validateAndSetSerialNumber(_serialNumberController.text, false);
      }
      if(_selectedItemData == null) {
      Toastbar.showErrorToastbar('Please scan a valid serial number', context);
      return;

      }
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

    // Get dynamic field names from childItemsData
    final fieldNames = _getFieldNamesFromChildItems();
    
    // Create data entry with dynamic field names
    final dataEntry = {
      "cmImpactedItemId": 0,
      "itemInstanceId": _selectedItemData!['item_instance_id'],
      "mfgSerialNo": _selectedItemData!['mfg_serial_no'],
      "nexgenSerialNo": _selectedItemData!['nexgen_serial_no'],
      "cmItemType": _selectedItemData!['item_type'],
      "isActive": true,
      "remarks": "",
      "subItemType": _currentItem['sub_item_type'],
      "respType": _currentItem['resp_type'],
    };
    
    // Add dynamic fields based on impacted_item_value_map
    for (var entry in fieldNames.entries) {
      final fieldName = entry.key;
      final fieldKey = entry.value;
      final controller = _childFieldControllers[fieldName];
      dataEntry[fieldKey] = controller?.text ?? '';
    }

    setState(() {
      if(_dynamicDropdownData.any((d) => d['mfgSerialNo'] == dataEntry['mfgSerialNo'])){
        _dynamicDropdownData.removeWhere((d) => d['mfgSerialNo'] == dataEntry['mfgSerialNo']);
      }
      _dynamicDropdownData.add(dataEntry);
    });
    widget.onImpactedItemListChanged.call(_dynamicDropdownData);

    // Clear form
    _serialNumberController.clear();
    _childFieldControllers.values.forEach((controller) => controller.clear());
    _selectedItemData = null;

    _notifyValueChanged();
    Toastbar.showSuccessToastbar('Data saved successfully', context);
  }

  void _editDynamicDropdownItem(int index) {
    final item = _dynamicDropdownData[index];
    final fieldNames = _getFieldNamesFromChildItems();
    
    setState(() {
      _serialNumberController.text = item['mfgSerialNo']?.toString() ?? '';
      
      // Set values for dynamic fields based on impacted_item_value_map
      for (var entry in fieldNames.entries) {
        final fieldName = entry.key;
        final fieldKey = entry.value;
        final controller = _childFieldControllers[fieldName];
        controller?.text = item[fieldKey]?.toString() ?? '';
      }
    });
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
    
    return
      Container(
        decoration: BoxDecoration(
          color: const Color(0xFFE6F5EF).withOpacity(0.3)
        ),
          child: Padding(
            padding: const EdgeInsets.all(16),
        child: Column(
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
        }),
        
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
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 20,
                horizontalMargin: 12,
                columns: [
                  DataColumn(
                    label: Text('Serial Number', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  DataColumn(
                    label: Text('Scanned', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  ..._getFieldNamesFromChildItems().keys.map((fieldName) => 
                    DataColumn(
                      label: Text(fieldName, style: TextStyle(fontWeight: FontWeight.bold)),
                    )
                  ),
                  DataColumn(
                    label: Text('Edit', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
                rows: _dynamicDropdownData.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;
                  
                  return DataRow(
                    cells: [
                      DataCell(Text(item['mfgSerialNo']?.toString() ?? '')),
                      DataCell(Text(item['isScanned'] == true ? 'Yes' : 'No')),
                      ..._getFieldNamesFromChildItems().entries.map((entry) {
                        final fieldKey = entry.value;
                        return DataCell(Text(item[fieldKey]?.toString() ?? ''));
                      }).toList(),
                      DataCell(
                        IconButton(
                          icon: const Icon(Icons.edit, size: 20),
                          onPressed: () => _editDynamicDropdownItem(index),
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
          ),
      );
  }

  Widget _buildMultiDynamicDropdownField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: _currentItem['checklist_desc']?.toString() ?? '',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                  fontFamily: fontFamilyMontserrat,
                ),
              ),
              if (_currentItem['is_mandatory'] == true)
                const TextSpan(
                  text: " *",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.red,
                    fontFamily: fontFamilyMontserrat,
                  ),
                ),
            ],
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 2,
        ),
            // Multi-select dropdown
            InkWell(
              onTap: () {
                setState(() {
                  _isMultiDropdownOpen = !_isMultiDropdownOpen;
                });
              },
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        _selectedMultiItems.isEmpty 
                          ? 'Select ${_currentItem['checklist_desc']?.toString() ?? 'Items'}'
                          : '${_selectedMultiItems.length} item(s) selected',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                    Icon(
                      _isMultiDropdownOpen ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                      color: Colors.grey.shade600,
                    ),
                  ],
                ),
              ),
            ),
            
            // Dropdown options
            if (_isMultiDropdownOpen) ...[
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.2),
                      spreadRadius: 1,
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                constraints: const BoxConstraints(maxHeight: 200),
                child: SingleChildScrollView(
                  child: Column(
                    children: _availableMultiOptions.map((option) {
                      final isSelected = _selectedMultiItems.any((selected) => 
                        selected['item_instance_id'] == option['item_instance_id']
                      );
                      
                      return CheckboxListTile(
                        title: Text(option['mfg_serial_no']?.toString() ?? 'Unknown'),
                        subtitle: Text(option['item_type']?.toString() ?? ''),
                        value: isSelected,
                        onChanged: (bool? value) {
                          setState(() {
                            if (value == true) {
                              _selectedMultiItems.add(Map<String, dynamic>.from(option));
                            } else {
                              _selectedMultiItems.removeWhere((selected) => 
                                selected['item_instance_id'] == option['item_instance_id']
                              );
                            }
                            _onMultiSelectionChanged();
                          });
                        },
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
            
            const SizedBox(height: 16),
            
            // Selected items display
            if (_selectedMultiItems.isNotEmpty) ...[
              const SizedBox(height: 8),
              ..._selectedMultiItems.map((item) => Container(
                margin: const EdgeInsets.only(bottom: 4),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        item['mfg_serial_no']?.toString() ?? 'Unknown',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 16),
                      onPressed: () {
                        setState(() {
                          _selectedMultiItems.removeWhere((selected) => 
                            selected['item_instance_id'] == item['item_instance_id']
                          );
                          _onMultiSelectionChanged();
                        });
                      },
                    ),
                  ],
                ),
              )),
            ],
    ],
      );
  }

  void _onMultiSelectionChanged() {
    // Return selected multi items directly without storing in resp
    _notifyValueChanged();
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
      case 'MULTI_DYNAMIC_DROPDOWN':
        return _buildMultiDynamicDropdownField();
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
