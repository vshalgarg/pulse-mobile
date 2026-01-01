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
import '../../commonWidgets/custom_form_field.dart' show CustomFormField, InputType;
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
  
  // Checkbox specific variables
  bool _isCheckboxChecked = false;
  final TextEditingController _checkboxNumericController = TextEditingController();
  
  // Dependent elements state - keyed by dependent element index
  Map<String, String?> _dependentImageIds = {}; // key -> imageId
  Map<String, String?> _dependentImageData = {}; // key -> imageDataUrl (for display)
  Map<String, File?> _dependentImageFiles = {}; // key -> image file

  @override
  void initState() {
    super.initState();
    _currentItem = Map<String, dynamic>.from(widget.pmItem);
    
    // Explicitly preserve dependent_elements if it exists
    if (widget.pmItem['dependent_elements'] != null) {
      _currentItem['dependent_elements'] = widget.pmItem['dependent_elements'];
    }
    if (widget.pmItem['dependentElements'] != null) {
      _currentItem['dependentElements'] = widget.pmItem['dependentElements'];
    }
    
    // Debug logging to check if dependent_elements is present
    if (_currentItem['resp_type'] == 'CHECKBOX' || _currentItem['resp_type'] == 'CHECKBOX_NUMERIC') {
      print('[CM] initState - widget.pmItem keys: ${widget.pmItem.keys.toList()}');
      print('[CM] initState - widget.pmItem[dependent_elements]: ${widget.pmItem['dependent_elements']}');
      print('[CM] initState - widget.pmItem[dependentElements]: ${widget.pmItem['dependentElements']}');
      print('[CM] initState - _currentItem[dependent_elements]: ${_currentItem['dependent_elements']}');
      print('[CM] initState - _currentItem[dependentElements]: ${_currentItem['dependentElements']}');
      print('[CM] initState - _currentItem[resp_type]: ${_currentItem['resp_type']}');
      print('[CM] initState - _currentItem[checklist_desc]: ${_currentItem['checklist_desc']}');
    }
    
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
        
        // Explicitly preserve dependent_elements if it exists
        if (widget.pmItem['dependent_elements'] != null) {
          _currentItem['dependent_elements'] = widget.pmItem['dependent_elements'];
        }
        if (widget.pmItem['dependentElements'] != null) {
          _currentItem['dependentElements'] = widget.pmItem['dependentElements'];
        }
        
        _initializeValues();
      });
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _remarksController.dispose();
    _serialNumberController.dispose();
    _checkboxNumericController.dispose();
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

    // Initialize checkbox value
    if (respType == 'CHECKBOX' || respType == 'CHECKBOX_NUMERIC') {
      _isCheckboxChecked = respValue == 'true' || respValue == true || respValue == 'True' || respValue == 'TRUE';
      if (respType == 'CHECKBOX_NUMERIC' && _isCheckboxChecked) {
        // For CHECKBOX_NUMERIC, the numeric value might be stored separately
        // Check if there's a numeric value in the response
        final numericValue = _currentItem['numeric_value'] ?? _currentItem['resp_numeric'];
        if (numericValue != null) {
          _checkboxNumericController.text = numericValue.toString();
        }
      }
    }

    // Initialize dynamic dropdown
    if (respType == 'DYNAMIC_DROPDOWN') {
      _initializeDynamicDropdown();
    }
    
    // Initialize multi dynamic dropdown
    if (respType == 'MULTI_DYNAMIC_DROPDOWN') {
      _initializeMultiDynamicDropdown();
    }
    
    // Initialize dependent elements if checkbox is checked
    if ((respType == 'CHECKBOX' || respType == 'CHECKBOX_NUMERIC') && _isCheckboxChecked) {
      _initializeDependentElements();
    }
  }
  
  void _initializeDependentElements() {
    // Try to get dependent_elements from _currentItem, fallback to widget.pmItem
    List<dynamic> dependentElements = _currentItem['dependent_elements'] as List<dynamic>? ?? 
                                     _currentItem['dependentElements'] as List<dynamic>? ?? [];
    
    if (dependentElements.isEmpty) {
      dependentElements = widget.pmItem['dependent_elements'] as List<dynamic>? ?? 
                          widget.pmItem['dependentElements'] as List<dynamic>? ?? [];
      
      // If found in widget.pmItem but not in _currentItem, preserve it
      if (dependentElements.isNotEmpty) {
        _currentItem['dependent_elements'] = dependentElements;
      }
    }
    
    final responseImages = _currentItem['response_images'] as List<dynamic>? ?? [];
    
    print('[CM] _initializeDependentElements - dependentElements.length: ${dependentElements.length}');
    
    // Initialize dependent image data from response_images
    for (int i = 0; i < dependentElements.length; i++) {
      final elementKey = '${_currentItem['cm_check_list_mst_id']}_$i';
      
      // Check if there's a corresponding image in response_images
      if (i < responseImages.length) {
        final imageData = responseImages[i];
        final photoId = imageData['photo_id']?.toString();
        if (photoId != null && photoId.isNotEmpty) {
          _dependentImageIds[elementKey] = photoId;
          // Image data will be loaded asynchronously if needed
        }
      }
    }
  }

  void _initializeDynamicDropdown() {
    // Initialize child field controllers - use impacted_item_check_list instead of childitemData
    final childItems = _currentItem['impacted_item_check_list'] as List<dynamic>? ?? 
                       _currentItem['childitemData'] as List<dynamic>? ?? [];
    for (var childItem in childItems) {
      final fieldName = childItem['checklist_desc']?.toString() ?? '';
      if (fieldName.isNotEmpty) {
        _childFieldControllers[fieldName] = TextEditingController();
      }
    }

    _dynamicDropdownData = widget.cmImpactedItemList.map((item) => Map<String, dynamic>.from(item)).toList();
  }

  void _initializeMultiDynamicDropdown() {
    // Get sub_item_type and item_type to filter options from originalCmImpactedItemMap
    final subItemType = _currentItem['sub_item_type']?.toString() ?? '';
    final itemType = _currentItem['item_type']?.toString() ?? '';
    
    // Get available options from originalCmImpactedItemMap
    List<dynamic>? options;
    
    // First try the subItemType as-is
    if (widget.originalCmImpactedItemMap.containsKey(subItemType)) {
      options = widget.originalCmImpactedItemMap[subItemType] as List<dynamic>?;
    } 
    // If not found, try mapping from item_type (parent node)
    else if (itemType.isNotEmpty) {
      final mappedType = _mapItemTypeToSiteDeployedKey(itemType);
      if (widget.originalCmImpactedItemMap.containsKey(mappedType)) {
        options = widget.originalCmImpactedItemMap[mappedType] as List<dynamic>?;
      }
    }
    
    if (options != null && options.isNotEmpty) {
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
    // Use impacted_item_check_list instead of childitemData
    final childItems = _currentItem['impacted_item_check_list'] as List<dynamic>? ?? 
                      _currentItem['childitemData'] as List<dynamic>? ?? [];
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
  
  void _onCheckboxChanged(bool? value) {
    print('[CM] _onCheckboxChanged called - value: $value');
    setState(() {
      _isCheckboxChecked = value ?? false;
      _currentItem['resp'] = _isCheckboxChecked ? 'true' : 'false';
      
      print('[CM] _onCheckboxChanged - _isCheckboxChecked set to: $_isCheckboxChecked');
      print('[CM] _onCheckboxChanged - _currentItem[resp] set to: ${_currentItem['resp']}');
      
      // Clear dependent elements if unchecked
      if (!_isCheckboxChecked) {
        _dependentImageIds.clear();
        _dependentImageData.clear();
        _dependentImageFiles.clear();
        _currentItem['response_images'] = null;
      } else {
        // Initialize dependent elements when checked
        _initializeDependentElements();
      }
    });
    _notifyValueChanged();
  }
  
  void _onCheckboxNumericChanged(String value) {
    setState(() {
      _currentItem['resp'] = _isCheckboxChecked ? 'true' : 'false';
      _currentItem['numeric_value'] = value;
      // Also store in resp_numeric for compatibility
      _currentItem['resp_numeric'] = value;
    });
    _notifyValueChanged();
  }
  
  Future<void> _uploadDependentImage(String elementKey, File imageFile) async {
    try {
      // Read file as bytes and encode to base64
      final bytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(bytes);
      
      // Store image data for display
      setState(() {
        _dependentImageFiles[elementKey] = imageFile;
        _dependentImageData[elementKey] = 'data:image/jpeg;base64,$base64Image';
      });
      
      // Add image to response_images array
      _addImageToResponseImages(elementKey, base64Image);
      
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
  
  void _addImageToResponseImages(String elementKey, String base64Image) {
    // Extract index from elementKey (format: cm_check_list_mst_id_index)
    final parts = elementKey.split('_');
    final index = parts.isNotEmpty ? int.tryParse(parts.last) ?? 0 : 0;
    
    // Get or create response_images array
    List<dynamic> responseImages = _currentItem['response_images'] as List<dynamic>? ?? [];
    
    // Ensure array is large enough
    while (responseImages.length <= index) {
      responseImages.add({
        'photo_id': 'LOCAL_IMAGE_ID',
        'pclsri_id': _currentItem['cm_check_list_mst_id'],
        'photo_taken_ts': DateTime.now().toIso8601String(),
      });
    }
    
    // Update the image at the specific index
    responseImages[index] = {
      'photo_id': 'LOCAL_IMAGE_ID',
      'pclsri_id': _currentItem['cm_check_list_mst_id'],
      'photo_taken_ts': DateTime.now().toIso8601String(),
      'image_data': base64Image, // Store base64 for offline support
    };
    
    _currentItem['response_images'] = responseImages;
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

  // Helper method to map item_type from checkListDetails to siteDeployedItems key format
  String _mapItemTypeToSiteDeployedKey(String itemType) {
    // Map parent node names: "BATTERY" -> "Battery", "CCU MPPT" -> "CCU MPPT", etc.
    final mapping = {
      'BATTERY': 'Battery',
      'DG': 'DG',
      'CCU': 'CCU',
      'CCU MPPT': 'CCU MPPT',
      'SOLAR': 'Solar',
      'SMPS': 'SMPS',
    };
    
    return mapping[itemType] ?? itemType;
  }

  void _validateAndSetSerialNumber(String serialNo, bool isQrCodeScanned) {
    final siteDeployedItems = widget.originalCmImpactedItemMap as Map<String, dynamic>? ?? {};
    final subItemType = _currentItem['sub_item_type']?.toString() ?? '';
    final itemType = _currentItem['item_type']?.toString() ?? '';
    
    // Map parent node name from checkListDetails to siteDeployedItems format
    // e.g., "BATTERY" -> "Battery", "DG" -> "DG", etc.
    List<dynamic>? deployedItems;
    
    // First try the subItemType as-is
    if (siteDeployedItems.containsKey(subItemType)) {
      deployedItems = siteDeployedItems[subItemType] as List<dynamic>?;
    } 
    // If not found, try mapping from item_type (parent node)
    else if (itemType.isNotEmpty) {
      // Map common patterns: "BATTERY" -> "Battery", etc.
      final mappedType = _mapItemTypeToSiteDeployedKey(itemType);
      if (siteDeployedItems.containsKey(mappedType)) {
        deployedItems = siteDeployedItems[mappedType] as List<dynamic>?;
      }
    }
    
    deployedItems ??= [];

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

    // Validate child fields - use impacted_item_check_list instead of childitemData
    final childItems = _currentItem['impacted_item_check_list'] as List<dynamic>? ?? 
                       _currentItem['childitemData'] as List<dynamic>? ?? [];
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
    // Use impacted_item_check_list instead of childitemData
    final childItems = _currentItem['impacted_item_check_list'] as List<dynamic>? ?? 
                       _currentItem['childitemData'] as List<dynamic>? ?? [];
    
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

  Widget _buildCheckboxField() {
    // Always get dependent_elements from widget.pmItem (source of truth)
    // Try both snake_case and camelCase
    dynamic rawDependentElements = widget.pmItem['dependent_elements'] ?? widget.pmItem['dependentElements'];
    
    // Convert to List if it's not null
    List<dynamic> dependentElements = [];
    if (rawDependentElements != null) {
      if (rawDependentElements is List) {
        dependentElements = rawDependentElements;
      } else {
        // Try to parse if it's a string
        try {
          final parsed = jsonDecode(rawDependentElements.toString());
          if (parsed is List) {
            dependentElements = parsed;
          }
        } catch (e) {
          print('[CM] Error parsing dependent_elements: $e');
        }
      }
    }
    
    // Also store in _currentItem for future reference
    if (dependentElements.isNotEmpty && _currentItem['dependent_elements'] == null) {
      _currentItem['dependent_elements'] = dependentElements;
    }
    
    // Get parent response value (checkbox checked = "true", unchecked = null/empty)
    final parentResponse = _isCheckboxChecked ? 'true' : null;
    
    // Debug logging
    print('[CM] _buildCheckboxField - _isCheckboxChecked: $_isCheckboxChecked');
    print('[CM] _buildCheckboxField - widget.pmItem keys: ${widget.pmItem.keys.toList()}');
    print('[CM] _buildCheckboxField - widget.pmItem[dependent_elements]: ${widget.pmItem['dependent_elements']}');
    print('[CM] _buildCheckboxField - widget.pmItem[dependentElements]: ${widget.pmItem['dependentElements']}');
    print('[CM] _buildCheckboxField - dependentElements.length: ${dependentElements.length}');
    if (dependentElements.isNotEmpty) {
      print('[CM] _buildCheckboxField - dependentElements[0]: ${dependentElements[0]}');
    }
    
    return Column(
      key: ValueKey('checkbox_${_currentItem['cm_check_list_mst_id']}_$_isCheckboxChecked'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Checkbox
        Row(
          children: [
            Checkbox(
              value: _isCheckboxChecked,
              onChanged: (bool? value) {
                print('[CM] Checkbox clicked - value: $value');
                _onCheckboxChanged(value);
              },
            ),
            Expanded(
              child: Text(
                _currentItem['checklist_desc']?.toString() ?? '',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: _currentItem['is_mandatory'] == true 
                      ? FontWeight.w600 
                      : FontWeight.normal,
                ),
              ),
            ),
            if (_currentItem['is_mandatory'] == true)
              const Text(
                ' *',
                style: TextStyle(color: Colors.red),
              ),
          ],
        ),
        
        // Dependent elements (shown when checkbox is checked)
        if (_isCheckboxChecked && dependentElements.isNotEmpty) ...[
          const SizedBox(height: 16),
          ...dependentElements.asMap().entries.map((entry) {
            final index = entry.key;
            final element = entry.value;
            
            // Handle both Map and dynamic types
            Map<String, dynamic> elementMap;
            if (element is Map<String, dynamic>) {
              elementMap = element;
            } else {
              elementMap = Map<String, dynamic>.from(element as Map);
            }
            
            final elementKey = '${_currentItem['cm_check_list_mst_id']}_$index';
            final respType = elementMap['resp_type']?.toString() ?? '';
            
            print('[CM] Processing dependent element $index - respType: $respType, elementKey: $elementKey');
            print('[CM] Element data: $elementMap');
            
            // Show all dependent elements when checkbox is checked
            if (respType == 'IMG') {
              final checklistDesc = elementMap['checklist_desc']?.toString() ?? 'Add a photo';
              final mandatoryIfValue = elementMap['mandatoryIfValue'];
              final isMandatory = _isDependentElementMandatory(mandatoryIfValue, parentResponse);
              
              print('[CM] Building IMG field - checklistDesc: $checklistDesc, isMandatory: $isMandatory');
              
              return Padding(
                padding: const EdgeInsets.only(left: 32, bottom: 16),
                child: ImageUploadField(
                  key: ValueKey('dependent_image_$elementKey'),
                  label: checklistDesc,
                  placeholder: checklistDesc,
                  isRequired: isMandatory,
                  externalImageUrl: _dependentImageData[elementKey],
                  onImageSelected: (File? file) async {
                    if (file != null) {
                      await _uploadDependentImage(elementKey, file);
                    }
                  },
                ),
              );
            }
            
            return const SizedBox.shrink();
          }).toList(),
        ],
      ],
    );
  }
  
  Widget _buildCheckboxNumericField() {
    final dependentElements = _currentItem['dependent_elements'] as List<dynamic>? ?? [];
    // Get parent response value (checkbox checked = "true", unchecked = null/empty)
    final parentResponse = _isCheckboxChecked ? 'true' : null;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Checkbox
        Row(
          children: [
            Checkbox(
              value: _isCheckboxChecked,
              onChanged: (bool? value) {
                _onCheckboxChanged(value);
              },
            ),
            Expanded(
              child: Text(
                _currentItem['checklist_desc']?.toString() ?? '',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: _currentItem['is_mandatory'] == true 
                      ? FontWeight.w600 
                      : FontWeight.normal,
                ),
              ),
            ),
            if (_currentItem['is_mandatory'] == true)
              const Text(
                ' *',
                style: TextStyle(color: Colors.red),
              ),
          ],
        ),
        
        // Numeric field (shown when checkbox is checked)
        if (_isCheckboxChecked) ...[
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.only(left: 32),
            child: CustomFormField(
              label: 'Count',
              controller: _checkboxNumericController,
              onChanged: _onCheckboxNumericChanged,
              isRequired: _currentItem['is_mandatory'] == true,
              inputType: InputType.number,
            ),
          ),
        ],
        
        // Dependent elements (shown when checkbox is checked and element should be visible)
        if (_isCheckboxChecked && dependentElements.isNotEmpty) ...[
          const SizedBox(height: 16),
          ...dependentElements.asMap().entries.map((entry) {
            final index = entry.key;
            final element = entry.value as Map<String, dynamic>;
            final elementKey = '${_currentItem['cm_check_list_mst_id']}_$index';
            final respType = element['resp_type']?.toString() ?? '';
            
            // Check if this dependent element should be visible based on parent response
            final shouldShow = _shouldDependentElementBeVisible(element, parentResponse);
            if (!shouldShow) return const SizedBox.shrink();
            
            if (respType == 'IMG') {
              final checklistDesc = element['checklist_desc']?.toString() ?? 'Add a photo';
              final mandatoryIfValue = element['mandatoryIfValue'];
              final isMandatory = _isDependentElementMandatory(mandatoryIfValue, parentResponse);
              
              return Padding(
                padding: const EdgeInsets.only(left: 32, bottom: 16),
                child: ImageUploadField(
                  label: checklistDesc,
                  placeholder: checklistDesc,
                  isRequired: isMandatory,
                  externalImageUrl: _dependentImageData[elementKey],
                  onImageSelected: (File? file) async {
                    if (file != null) {
                      await _uploadDependentImage(elementKey, file);
                    }
                  },
                ),
              );
            }
            
            return const SizedBox.shrink();
          }).toList(),
        ],
      ],
    );
  }
  
  /// Check if a dependent element should be visible based on parent response
  /// Similar to DependentElement.shouldBeVisible() in GI
  bool _shouldDependentElementBeVisible(Map<String, dynamic> element, String? parentResponse) {
    final visibleIfValue = element['visibleIfValue'];
    final mandatoryIfValue = element['mandatoryIfValue'];
    
    print('[CM] _shouldDependentElementBeVisible - visibleIfValue: $visibleIfValue, mandatoryIfValue: $mandatoryIfValue, parentResponse: $parentResponse');
    
    // If visibleIfValue is specified, use it
    if (visibleIfValue != null) {
      // Case 1: Boolean true - show when parent has a response
      if (visibleIfValue is bool && visibleIfValue == true) {
        final result = parentResponse != null && parentResponse.isNotEmpty;
        print('[CM] visibleIfValue is bool true, returning: $result');
        return result;
      }
      
      // Case 2: Boolean false - never show
      if (visibleIfValue is bool && visibleIfValue == false) {
        print('[CM] visibleIfValue is bool false, returning: false');
        return false;
      }
      
      // Case 3: Array of values - show only when parent response matches
      if (visibleIfValue is List) {
        if (parentResponse == null || parentResponse.isEmpty) {
          print('[CM] visibleIfValue is List but parentResponse is empty, returning: false');
          return false;
        }
        
        final visibleValues = visibleIfValue
            .map((e) => e.toString().trim().toLowerCase())
            .toList();
        final parentValueLower = parentResponse.trim().toLowerCase();
        
        final result = visibleValues.contains(parentValueLower);
        print('[CM] visibleIfValue is List: $visibleValues, parentValueLower: $parentValueLower, returning: $result');
        return result;
      }
    }
    
    // If no visibleIfValue, check mandatoryIfValue as fallback
    // If mandatoryIfValue exists, show when parent response matches
    if (mandatoryIfValue != null) {
      // Case 1: Boolean true - show when parent has any response
      if (mandatoryIfValue is bool && mandatoryIfValue == true) {
        final result = parentResponse != null && parentResponse.isNotEmpty;
        print('[CM] mandatoryIfValue is bool true, returning: $result');
        return result;
      }
      
      // Case 2: Array of values - show only when parent response matches
      if (mandatoryIfValue is List) {
        if (parentResponse == null || parentResponse.isEmpty) {
          print('[CM] mandatoryIfValue is List but parentResponse is empty, returning: false');
          return false;
        }
        
        final mandatoryValues = mandatoryIfValue
            .map((e) => e.toString().trim().toLowerCase())
            .toList();
        final parentValueLower = parentResponse.trim().toLowerCase();
        
        final result = mandatoryValues.contains(parentValueLower);
        print('[CM] mandatoryIfValue is List: $mandatoryValues, parentValueLower: $parentValueLower, returning: $result');
        return result;
      }
    }
    
    // Default: show if parent has a response (for checkboxes, this means checked)
    final defaultResult = parentResponse != null && parentResponse.isNotEmpty;
    print('[CM] Using default logic, returning: $defaultResult');
    return defaultResult;
  }
  
  /// Determine if a dependent element is mandatory based on parent response
  /// Similar to DependentElement.isMandatoryForResponse() in GI
  bool _isDependentElementMandatory(dynamic mandatoryIfValue, String? parentResponse) {
    if (mandatoryIfValue == null) return false;
    
    // Case 1: Boolean mandatory (true = mandatory for all responses)
    if (mandatoryIfValue is bool && mandatoryIfValue == true) {
      return true;
    }
    
    // Case 2: Value-based mandatory (array of values)
    // Example: mandatoryIfValue: ["true", "Not Ok"]
    // This means: mandatory ONLY when parent response is "true" or "Not Ok"
    if (mandatoryIfValue is List) {
      if (parentResponse == null || parentResponse.isEmpty) {
        return false; // No parent response, not mandatory
      }
      
      // Check if parent response matches any value in the array (case-insensitive)
      final mandatoryValues = mandatoryIfValue
          .map((e) => e.toString().trim().toLowerCase())
          .toList();
      final parentValueLower = parentResponse.trim().toLowerCase();
      
      // Return true only if parent response matches one of the mandatory values
      return mandatoryValues.contains(parentValueLower);
    }
    
    // Case 3: String format: "true"
    if (mandatoryIfValue is String) {
      if (parentResponse == null || parentResponse.isEmpty) {
        return false;
      }
      return mandatoryIfValue.toLowerCase() == parentResponse.toLowerCase();
    }
    
    // Default: not mandatory
    return false;
  }
  
  Widget _buildFieldByType(String respType) {
    switch (respType) {
      case 'DROPDOWN':
        return _buildDropdownField();
      case 'RADIO':
        return _buildRadioField();
      case 'TEXT':
        return _buildTextField();
      case 'NUMERIC':
        return _buildNumericField();
      case 'CHECKBOX':
        return _buildCheckboxField();
      case 'CHECKBOX_NUMERIC':
        return _buildCheckboxNumericField();
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
  
  Widget _buildNumericField() {
    return CustomFormField(
      label: _currentItem['checklist_desc']?.toString() ?? '',
      initialValue: _textValue,
      controller: _textController,
      onChanged: _onTextChanged,
      isRequired: _currentItem['is_mandatory'] == true,
      inputType: InputType.number,
    );
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
