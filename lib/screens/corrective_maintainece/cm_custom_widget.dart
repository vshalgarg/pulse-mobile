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
import '../../services/service_locator.dart';
import '../../utils/connectivity_helper.dart';
import '../../utils/logger.dart';
import '../../enum/activity_type_enum.dart';

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
  String? _previousSelectedSerialNumber; // Track previous selection to clear old data
  
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
  
  // Child items state (for impacted_item_check_list) - keyed by cm_check_list_mst_id
  Map<int, bool> _childItemCheckboxStates = {}; // childId -> isChecked
  Map<int, String> _childItemNumericValues = {}; // childId -> numeric value
  Map<int, Map<String, String?>> _childItemDependentImageData = {}; // childId -> {elementKey -> imageData}
  Map<int, Map<String, File?>> _childItemDependentImageFiles = {}; // childId -> {elementKey -> imageFile}
  
  // Dynamic numeric specific variables
  final TextEditingController _dynamicNumericController = TextEditingController();
  Map<int, String?> _dynamicNumericImageData = {}; // index -> imageDataUrl (for display)
  Map<int, File?> _dynamicNumericImageFiles = {}; // index -> image file

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
    // Check if checklist ID or equipment type actually changed
    final oldChecklistId = oldWidget.pmItem['cm_check_list_mst_id'];
    final newChecklistId = widget.pmItem['cm_check_list_mst_id'];
    final oldItemType = oldWidget.pmItem['item_type']?.toString() ?? '';
    final newItemType = widget.pmItem['item_type']?.toString() ?? '';
    final oldSubItemType = oldWidget.pmItem['sub_item_type']?.toString() ?? '';
    final newSubItemType = widget.pmItem['sub_item_type']?.toString() ?? '';
    
    final checklistIdChanged = oldChecklistId != newChecklistId;
    final itemTypeChanged = oldItemType != newItemType || oldSubItemType != newSubItemType;
    
    // Only clear state if checklist ID or equipment type actually changed
    // Don't clear just because object reference changed (parent rebuild)
    if (checklistIdChanged || itemTypeChanged) {
      // Clear all state before re-initializing
      _clearAllState();
      
      setState(() {
        _currentItem = Map<String, dynamic>.from(widget.pmItem);
        
        // Explicitly preserve dependent_elements if it exists
        if (widget.pmItem['dependent_elements'] != null) {
          _currentItem['dependent_elements'] = widget.pmItem['dependent_elements'];
        }
        if (widget.pmItem['dependentElements'] != null) {
          _currentItem['dependentElements'] = widget.pmItem['dependentElements'];
        }
        
        // Clear response data when switching checklist items to ensure fresh start
        _currentItem['resp'] = null;
        _currentItem['response_images'] = null;
        _currentItem['numeric_value'] = null;
        _currentItem['resp_numeric'] = null;
        _currentItem['child_item_responses'] = null;
        
        print('[CM] didUpdateWidget - Cleared response data. Old ID: $oldChecklistId, New ID: $newChecklistId, Checklist changed: $checklistIdChanged, ItemType changed: $itemTypeChanged');
        
        _initializeValues();
      });
    } else {
      // If only reference changed but data is the same, just update _currentItem without clearing state
      setState(() {
        _currentItem = Map<String, dynamic>.from(widget.pmItem);
        
        // Preserve dependent_elements
        if (widget.pmItem['dependent_elements'] != null) {
          _currentItem['dependent_elements'] = widget.pmItem['dependent_elements'];
        }
        if (widget.pmItem['dependentElements'] != null) {
          _currentItem['dependentElements'] = widget.pmItem['dependentElements'];
        }
      });
    }
  }
  
  /// Clears all state when equipment type changes
  void _clearAllState() {
    // Clear checkbox states
    _isCheckboxChecked = false;
    _checkboxNumericController.clear();
    
    // Clear text values
    _textValue = null;
    _textController.clear();
    _remarksController.clear();
    
    // Clear dropdown/radio values
    _selectedDropdownValue = null;
    _selectedRadioValue = null;
    
    // Clear dependent elements
    _dependentImageIds.clear();
    _dependentImageData.clear();
    _dependentImageFiles.clear();
    
    // Clear dynamic dropdown data
    _dynamicDropdownData.clear();
    _selectedItemData = null;
    _previousSelectedSerialNumber = null;
    _serialNumberController.clear();
    _childFieldControllers.values.forEach((controller) => controller.clear());
    
    // Clear child item states
    _childItemCheckboxStates.clear();
    _childItemNumericValues.clear();
    _childItemDependentImageData.clear();
    _childItemDependentImageFiles.clear();
    
    // Clear multi dynamic dropdown
    _selectedMultiItems.clear();
    _availableMultiOptions.clear();
    _isMultiDropdownOpen = false;
    
    // Clear dynamic numeric state
    _dynamicNumericController.clear();
    _dynamicNumericImageData.clear();
    _dynamicNumericImageFiles.clear();
    
    // Clear response_images from current item
    _currentItem['response_images'] = null;
    _currentItem['resp'] = null;
    _currentItem['numeric_value'] = null;
    _currentItem['resp_numeric'] = null;
    
    print('[CM] Cleared all state - checklist item or equipment type changed');
  }

  @override
  void dispose() {
    _textController.dispose();
    _remarksController.dispose();
    _serialNumberController.dispose();
    _checkboxNumericController.dispose();
    _dynamicNumericController.dispose();
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
    if (respType == 'CHECKBOX' || respType == 'CHECKBOX_NUMERIC' || respType == 'CHECKBOX_TEXT') {
      // Handle both string "true"/"false" and string "1"/"0" for CHECKBOX_NUMERIC and CHECKBOX_TEXT
      if (respType == 'CHECKBOX_NUMERIC' || respType == 'CHECKBOX_TEXT') {
        _isCheckboxChecked = respValue == 1 || respValue == '1' || respValue == 'true' || respValue == true || respValue == 'True' || respValue == 'TRUE';
      } else {
        _isCheckboxChecked = respValue == 'true' || respValue == true || respValue == 'True' || respValue == 'TRUE';
      }
      
      if ((respType == 'CHECKBOX_NUMERIC' || respType == 'CHECKBOX_TEXT') && _isCheckboxChecked) {
        // For CHECKBOX_NUMERIC and CHECKBOX_TEXT, the numeric value might be stored separately
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
    
    // Initialize dynamic numeric
    if (respType == 'DYNAMIC_NUMERIC') {
      _initializeDynamicNumeric();
    }
    
    // Initialize dependent elements if checkbox is checked
    if ((respType == 'CHECKBOX' || respType == 'CHECKBOX_NUMERIC') && _isCheckboxChecked) {
      _initializeDependentElements();
    }
    
    // Initialize dependent elements for NUMERIC and TEXT fields if value exists
    if ((respType == 'NUMERIC' || respType == 'TEXT') && _textValue != null && _textValue!.isNotEmpty) {
      _initializeDependentElements();
    }
    
    // Initialize dependent elements for DYNAMIC_DROPDOWN if items are selected
    if (respType == 'DYNAMIC_DROPDOWN' && _dynamicDropdownData.isNotEmpty) {
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
        if (imageData is Map<String, dynamic>) {
          final photoId = imageData['photo_id']?.toString();
          final imageDataBase64 = imageData['image_data']?.toString();
          
          if (photoId != null && photoId.isNotEmpty) {
            _dependentImageIds[elementKey] = photoId;
            
            // If image_data is already loaded (from server), use it directly
            if (imageDataBase64 != null && imageDataBase64.isNotEmpty) {
              _dependentImageData[elementKey] = imageDataBase64;
            }
            // Otherwise, image data will be loaded asynchronously if needed
          }
        }
      }
    }
  }

  void _initializeDynamicDropdown() {
    // Initialize child field controllers - use impacted_item_check_list instead of childitemData
    final childItems = _currentItem['impacted_item_check_list'] as List<dynamic>? ?? 
                       _currentItem['childitemData'] as List<dynamic>? ?? [];
    
    // Initialize child item states from existing data
    final existingChildResponses = _currentItem['child_item_responses'] as List<dynamic>? ?? [];
    
    for (var childItem in childItems) {
      final childId = childItem['cm_check_list_mst_id'] as int? ?? 0;
      final respType = childItem['resp_type']?.toString() ?? '';
      final fieldName = childItem['checklist_desc']?.toString() ?? '';
      
      // Initialize controllers for TEXT/NUMERIC fields with impacted_item_value_map
      if (fieldName.isNotEmpty && (respType == 'TEXT' || respType == 'NUMERIC')) {
        final impactedItemValueMap = childItem['impacted_item_value_map']?.toString() ?? '';
        if (impactedItemValueMap.isNotEmpty) {
        _childFieldControllers[fieldName] = TextEditingController();
        }
      }
      
      // Initialize checkbox states from existing responses
      if (respType == 'CHECKBOX' || respType == 'CHECKBOX_NUMERIC') {
        // Check if there's an existing response for this child item
        final existingResponse = existingChildResponses.firstWhere(
          (r) => (r['cm_check_list_mst_id'] as int?) == childId,
          orElse: () => <String, dynamic>{},
        );
        
        if (existingResponse.isNotEmpty) {
          final resp = existingResponse['resp'];
          // Handle both string "true"/"false" and string "1"/"0" for CHECKBOX_NUMERIC and CHECKBOX_TEXT
          if (respType == 'CHECKBOX_NUMERIC' || respType == 'CHECKBOX_TEXT') {
            _childItemCheckboxStates[childId] = resp == 1 || resp == '1' || resp == 'true' || resp == true || resp == 'True' || resp == 'TRUE';
          } else {
            _childItemCheckboxStates[childId] = resp == 'true' || resp == 'True' || resp == 'TRUE';
          }
          
          if (respType == 'CHECKBOX_NUMERIC' || respType == 'CHECKBOX_TEXT') {
            final numericValue = existingResponse['numeric_value'] ?? existingResponse['resp_numeric'];
            if (numericValue != null) {
              _childItemNumericValues[childId] = numericValue.toString();
            }
          }
          
          // Initialize dependent images from existing response_images
          final responseImages = existingResponse['response_images'] as List<dynamic>? ?? [];
          if (responseImages.isNotEmpty) {
            final dependentElements = childItem['dependent_elements'] as List<dynamic>? ?? [];
            for (int i = 0; i < dependentElements.length && i < responseImages.length; i++) {
              final elementKey = '${childId}_$i';
              final imageData = responseImages[i];
              if (imageData is Map<String, dynamic>) {
                final photoId = imageData['photo_id']?.toString();
                final imageDataBase64 = imageData['image_data']?.toString();
                
                if (photoId != null && photoId.isNotEmpty) {
                  _childItemDependentImageData[childId] ??= {};
                  
                  // If image_data is already loaded (from server), use it directly
                  if (imageDataBase64 != null && imageDataBase64.isNotEmpty) {
                    _childItemDependentImageData[childId]![elementKey] = imageDataBase64;
                  } else {
                    // Otherwise, will be loaded asynchronously if needed
                    _childItemDependentImageData[childId]![elementKey] = null;
                  }
                }
              }
            }
          }
        } else {
          // Initialize as unchecked if no existing response
          _childItemCheckboxStates[childId] = false;
        }
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

  void _initializeDynamicNumeric() {
    // Initialize numeric value from response
    final respValue = _currentItem['resp']?.toString() ?? '';
    _dynamicNumericController.text = respValue;
    
    // Initialize images from response_images
    final responseImages = _currentItem['response_images'] as List<dynamic>? ?? [];
    for (int i = 0; i < responseImages.length; i++) {
      final imageData = responseImages[i];
      if (imageData is Map<String, dynamic>) {
        final imageDataBase64 = imageData['image_data']?.toString();
        final photoId = imageData['photo_id']?.toString();
        
        if (imageDataBase64 != null && imageDataBase64.isNotEmpty) {
          // If it's a data URL, use it directly; otherwise construct it
          if (imageDataBase64.startsWith('data:image')) {
            _dynamicNumericImageData[i] = imageDataBase64;
          } else {
            _dynamicNumericImageData[i] = 'data:image/jpeg;base64,$imageDataBase64';
          }
        } else if (photoId != null && photoId.isNotEmpty && photoId != 'LOCAL_IMAGE_ID') {
          // Load image from server using photoId (if needed)
          // For now, we'll just store the photoId reference
          _dynamicNumericImageData[i] = null; // Will be loaded on demand
        }
      }
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

  // Helper method to get all child items from impacted_item_check_list
  List<Map<String, dynamic>> _getAllChildItems() {
    final childItems = _currentItem['impacted_item_check_list'] as List<dynamic>? ?? 
                      _currentItem['childitemData'] as List<dynamic>? ?? [];
    final result = <Map<String, dynamic>>[];
    
    for (var childItem in childItems) {
      final fieldName = childItem['checklist_desc']?.toString() ?? '';
      if (fieldName.isNotEmpty) {
        result.add(Map<String, dynamic>.from(childItem));
      }
    }
    
    return result;
  }

  // Helper method to get dependent elements from child items
  List<Map<String, dynamic>> _getChildItemDependentElements(int childId) {
    final childItems = _getAllChildItems();
    for (var childItem in childItems) {
      final id = childItem['cm_check_list_mst_id'] as int? ?? 0;
      if (id == childId) {
        final dependentElements = childItem['dependent_elements'] as List<dynamic>? ?? 
                                 childItem['dependentElements'] as List<dynamic>? ?? [];
        return dependentElements.map((e) {
          if (e is Map<String, dynamic>) {
            return Map<String, dynamic>.from(e);
          }
          return Map<String, dynamic>.from(e as Map);
        }).toList();
      }
    }
    return [];
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
    print('[CM] _onTextChanged - value: $value, resp_type: ${_currentItem['resp_type']}, old _textValue: $_textValue');
    
    setState(() {
      _textValue = value;
      _currentItem['resp'] = value;
      
      // For NUMERIC and TEXT fields, initialize dependent elements if value is not empty
      if ((_currentItem['resp_type'] == 'NUMERIC' || _currentItem['resp_type'] == 'TEXT') && value.isNotEmpty) {
        print('[CM] _onTextChanged - Initializing dependent elements for ${_currentItem['resp_type']} field');
        _initializeDependentElements();
      }
    });
    
    // Force a rebuild after state update to ensure dependent elements show/hide
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          // Trigger rebuild to show/hide dependent elements
        });
      }
    });
    
    _notifyValueChanged();
  }
  
  void _onCheckboxChanged(bool? value) {
    print('[CM] _onCheckboxChanged called - value: $value');
    setState(() {
      _isCheckboxChecked = value ?? false;
      final respType = _currentItem['resp_type']?.toString() ?? '';
      
      // For CHECKBOX_NUMERIC and CHECKBOX_TEXT, resp should be the same as respNumeric (numeric value) when checked, "0" when unchecked
      // For regular CHECKBOX, save as string "true"/"false"
      if (respType == 'CHECKBOX_NUMERIC' || respType == 'CHECKBOX_TEXT') {
        // Get the numeric value if checkbox is checked, otherwise "0"
        final numericValue = _checkboxNumericController.text.trim();
        _currentItem['resp'] = _isCheckboxChecked && numericValue.isNotEmpty ? numericValue : '0';
      } else {
        _currentItem['resp'] = _isCheckboxChecked ? 'true' : 'false';
      }
      
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
      final respType = _currentItem['resp_type']?.toString() ?? '';
      
      // For CHECKBOX_NUMERIC and CHECKBOX_TEXT, resp should be the same as respNumeric (numeric value) when checked, "0" when unchecked
      if (respType == 'CHECKBOX_NUMERIC' || respType == 'CHECKBOX_TEXT') {
        // resp should be the numeric value when checked, "0" when unchecked
        _currentItem['resp'] = _isCheckboxChecked && value.trim().isNotEmpty ? value.trim() : '0';
      } else {
        _currentItem['resp'] = _isCheckboxChecked ? 'true' : 'false';
      }
      
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
    
    // Check if this is a different serial number than previously selected
    final currentSerialNo = serialNo.toLowerCase().trim();
    final previousSerialNo = _previousSelectedSerialNumber?.toLowerCase().trim();
    final isNewSelection = previousSerialNo != null && previousSerialNo != currentSerialNo;
    
    // If user is selecting a different checklist, clear previous response data
    if (isNewSelection) {
      _clearPreviousChecklistResponse();
    }
    
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
        final mfgSerialNo = matchingItem['mfg_serial_no']?.toString() ?? '';
        _serialNumberController.text = mfgSerialNo;
        _previousSelectedSerialNumber = mfgSerialNo; // Update tracked serial number
      });
    } else {
      if(isQrCodeScanned) {
        Toastbar.showErrorToastbar('Serial number is invalid', context);
      }
    }
  }
  
  /// Clears all response data for the previous checklist selection
  void _clearPreviousChecklistResponse() {
    // Clear child item checkbox states
    _childItemCheckboxStates.clear();
    
    // Clear child item numeric values
    _childItemNumericValues.clear();
    
    // Clear child item dependent images
    _childItemDependentImageData.clear();
    _childItemDependentImageFiles.clear();
    
    // Clear child field controllers (for TEXT/NUMERIC fields)
    _childFieldControllers.values.forEach((controller) => controller.clear());
    
    // Clear selected item data
    _selectedItemData = null;
    
    // Clear serial number controller
    _serialNumberController.clear();
    
    // Notify parent widget of the change
    _notifyValueChanged();
    
    print('[CM] Cleared previous checklist response data');
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
      final childId = childItem['cm_check_list_mst_id'] as int? ?? 0;
      final respType = childItem['resp_type']?.toString() ?? '';
      final fieldName = childItem['checklist_desc']?.toString() ?? '';
      final isMandatory = childItem['is_mandatory'] == true;
      
      // Validate based on field type
      if (respType == 'CHECKBOX' || respType == 'CHECKBOX_NUMERIC') {
        // For checkboxes, check if mandatory and not checked
        if (isMandatory && !(_childItemCheckboxStates[childId] ?? false)) {
          Toastbar.showErrorToastbar('Please check mandatory field: $fieldName', context);
          return;
        }
        // For CHECKBOX_NUMERIC, validate numeric value if checked
        if (respType == 'CHECKBOX_NUMERIC' && (_childItemCheckboxStates[childId] ?? false)) {
          final numericValue = _childItemNumericValues[childId] ?? '';
          if (isMandatory && numericValue.isEmpty) {
            Toastbar.showErrorToastbar('Please enter value for: $fieldName', context);
            return;
          }
        }
        // Validate dependent_elements if mandatory
        final dependentElements = childItem['dependent_elements'] as List<dynamic>? ?? [];
        if ((_childItemCheckboxStates[childId] ?? false) && dependentElements.isNotEmpty) {
          for (int i = 0; i < dependentElements.length; i++) {
            final element = dependentElements[i] as Map<String, dynamic>;
            final elementKey = '${childId}_$i';
            final mandatoryIfValue = element['mandatoryIfValue'];
            if (_isDependentElementMandatory(mandatoryIfValue, 'true') && 
                (_childItemDependentImageData[childId]?[elementKey] == null)) {
              final elementDesc = element['checklist_desc']?.toString() ?? 'photo';
              Toastbar.showErrorToastbar('Please upload $elementDesc for: $fieldName', context);
              return;
            }
          }
        }
      } else {
        // For TEXT/NUMERIC fields with impacted_item_value_map (old behavior)
        final controller = _childFieldControllers[fieldName];
      if (isMandatory && (controller?.text.isEmpty ?? true)) {
        Toastbar.showErrorToastbar('Please fill all mandatory fields', context);
        return;
        }
      }
    }

    // Get dynamic field names from childItemsData (for old TEXT fields with impacted_item_value_map)
    final fieldNames = _getFieldNamesFromChildItems();
    
    // Create data entry with dynamic field names
    final mfgSerialNo = _selectedItemData!['mfg_serial_no']?.toString() ?? '';
    final cmItemType = _selectedItemData!['item_type']?.toString() ?? _currentItem['sub_item_type']?.toString() ?? '';
    
    // Generate checklistRef (e.g., "Battery-1", "Battery-2") based on existing items
    final existingItemsCount = _dynamicDropdownData.length;
    final checklistRef = '$cmItemType-${existingItemsCount + 1}';
    
    final dataEntry = {
      "cmImpactedItemId": 0,
      "itemInstanceId": _selectedItemData!['item_instance_id'],
      "mfgSerialNo": mfgSerialNo,
      "nexgenSerialNo": _selectedItemData!['nexgen_serial_no'],
      "cmItemType": cmItemType,
      "isActive": true,
      "remarks": "",
      "subItemType": _currentItem['sub_item_type'],
      "respType": _currentItem['resp_type'],
      "checklistRef": checklistRef,
    };
    
    // Add dynamic fields based on impacted_item_value_map (old behavior for TEXT fields)
    for (var entry in fieldNames.entries) {
      final fieldName = entry.key;
      final fieldKey = entry.value;
      final controller = _childFieldControllers[fieldName];
      dataEntry[fieldKey] = controller?.text ?? '';
    }
    
    // Get parent's check_list_group_id (this should be used for child items' cmCheckListMstId)
    final parentCheckListGroupId = _currentItem['check_list_group_id'] as int? ?? 
                                   _currentItem['cm_check_list_mst_id'] as int? ?? 0;
    
    // Add child item responses (for new structure with CHECKBOX, CHECKBOX_NUMERIC, etc.)
    final childItemResponses = <Map<String, dynamic>>[];
    for (var childItem in childItems) {
      final childId = childItem['cm_check_list_mst_id'] as int? ?? 0;
      final respType = childItem['resp_type']?.toString() ?? '';
      final checklistDesc = childItem['checklist_desc']?.toString() ?? '';
      
      final clOrder = childItem['cl_order'] as int? ?? 
                     childItem['clOrder'] as int? ?? 0;
      
      if (respType == 'CHECKBOX') {
        final isChecked = _childItemCheckboxStates[childId] ?? false;
        childItemResponses.add({
          'cm_check_list_mst_id': childId, // Child's actual ID (for the impacted item entry)
          'parent_cm_check_list_mst_id': parentCheckListGroupId, // Parent's ID (for grouping)
          'checklist_desc': checklistDesc,
          'resp': isChecked ? 'true' : 'false',
          'resp_type': respType,
          'cl_order': clOrder,
        });
      } else if (respType == 'CHECKBOX_NUMERIC' || respType == 'CHECKBOX_TEXT') {
        final isChecked = _childItemCheckboxStates[childId] ?? false;
        final numericValue = _childItemNumericValues[childId] ?? '';
        // resp should be the same as respNumeric (numeric value) when checked, "0" when unchecked
        childItemResponses.add({
          'cm_check_list_mst_id': childId, // Child's actual ID (for the impacted item entry)
          'parent_cm_check_list_mst_id': parentCheckListGroupId, // Parent's ID (for grouping)
          'checklist_desc': checklistDesc,
          'resp': isChecked && numericValue.isNotEmpty ? numericValue : '0',
          'resp_numeric': numericValue,
          'numeric_value': numericValue,
          'resp_type': respType,
          'cl_order': clOrder,
        });
      }
      // Add dependent images for this child item
      final dependentImages = <Map<String, dynamic>>[];
      if (_childItemDependentImageData.containsKey(childId)) {
        _childItemDependentImageData[childId]!.forEach((elementKey, imageData) {
          if (imageData != null) {
            // Extract base64 from data URL if needed
            String? base64Image;
            if (imageData.startsWith('data:image')) {
              final parts = imageData.split(',');
              if (parts.length > 1) {
                base64Image = parts[1];
              }
            } else {
              base64Image = imageData;
            }
            
            dependentImages.add({
              'photo_id': 'LOCAL_IMAGE_ID',
              'pclsri_id': parentCheckListGroupId, // Use parent's check_list_group_id
              'photo_taken_ts': DateTime.now().toIso8601String(),
              'image_data': base64Image, // Store base64 for upload
            });
          }
        });
      }
      if (dependentImages.isNotEmpty && childItemResponses.isNotEmpty) {
        final lastResponse = childItemResponses.last;
        lastResponse['response_images'] = dependentImages;
      }
    }
    
    if (childItemResponses.isNotEmpty) {
      dataEntry['child_item_responses'] = childItemResponses;
    }
    
    // Store dependent element images (for parent-level dependent elements like IMG)
    final dependentElements = _currentItem['dependent_elements'] as List<dynamic>? ?? 
                             _currentItem['dependentElements'] as List<dynamic>? ?? [];
    final dependentImages = <Map<String, dynamic>>[];
    for (int i = 0; i < dependentElements.length; i++) {
      final element = dependentElements[i];
      Map<String, dynamic> elementMap;
      if (element is Map<String, dynamic>) {
        elementMap = element;
      } else {
        elementMap = Map<String, dynamic>.from(element as Map);
      }
      
      final respType = elementMap['resp_type']?.toString() ?? '';
      if (respType == 'IMG') {
        final elementKey = '${_currentItem['cm_check_list_mst_id']}_$i';
        final imageData = _dependentImageData[elementKey];
        if (imageData != null) {
          // Extract base64 from data URL if needed
          String? base64Image;
          if (imageData.startsWith('data:image')) {
            final parts = imageData.split(',');
            if (parts.length > 1) {
              base64Image = parts[1];
            }
          } else {
            base64Image = imageData;
          }
          
          if (base64Image != null) {
            dependentImages.add({
              'photo_id': 'LOCAL_IMAGE_ID',
              'pclsri_id': _currentItem['cm_check_list_mst_id'],
              'photo_taken_ts': DateTime.now().toIso8601String(),
              'image_data': base64Image, // Store base64 for display
            });
          }
        }
      }
    }
    if (dependentImages.isNotEmpty) {
      dataEntry['dependent_images'] = dependentImages;
    }
    
    // Validate dependent elements with mandatoryIfValue: true
    for (int i = 0; i < dependentElements.length; i++) {
      final element = dependentElements[i];
      Map<String, dynamic> elementMap;
      if (element is Map<String, dynamic>) {
        elementMap = element;
      } else {
        elementMap = Map<String, dynamic>.from(element as Map);
      }
      
      final respType = elementMap['resp_type']?.toString() ?? '';
      final mandatoryIfValue = elementMap['mandatoryIfValue'];
      
      // Check if this dependent element is mandatory
      if (respType == 'IMG' && _isDependentElementMandatory(mandatoryIfValue, 'true')) {
        final elementKey = '${_currentItem['cm_check_list_mst_id']}_$i';
        final imageData = _dependentImageData[elementKey];
        
        if (imageData == null || imageData.isEmpty) {
          final elementDesc = elementMap['checklist_desc']?.toString() ?? 'photo';
          Toastbar.showErrorToastbar('$elementDesc is missing', context);
          return;
        }
      }
    }

    setState(() {
      if(_dynamicDropdownData.any((d) => d['mfgSerialNo'] == dataEntry['mfgSerialNo'])){
        _dynamicDropdownData.removeWhere((d) => d['mfgSerialNo'] == dataEntry['mfgSerialNo']);
      }
      _dynamicDropdownData.add(dataEntry);
      
      // Initialize dependent elements when items are added to DYNAMIC_DROPDOWN
      if (_currentItem['resp_type'] == 'DYNAMIC_DROPDOWN' && _dynamicDropdownData.isNotEmpty) {
        _initializeDependentElements();
      }
    });
    print('[CM] _saveDynamicDropdownData - Calling onImpactedItemListChanged with ${_dynamicDropdownData.length} items');
    print('[CM] _saveDynamicDropdownData - Data: $_dynamicDropdownData');
    widget.onImpactedItemListChanged.call(_dynamicDropdownData);

    // Clear form
    _serialNumberController.clear();
    _childFieldControllers.values.forEach((controller) => controller.clear());
    _selectedItemData = null;
    _previousSelectedSerialNumber = null; // Reset tracked serial number after save
    
    // Clear child item states
    _childItemCheckboxStates.clear();
    _childItemNumericValues.clear();
    _childItemDependentImageData.clear();
    _childItemDependentImageFiles.clear();
    
    // Clear dependent element images (for parent-level dependent elements)
    _dependentImageData.clear();
    _dependentImageFiles.clear();
    _dependentImageIds.clear();

    _notifyValueChanged();
    Toastbar.showSuccessToastbar('Data saved successfully', context);
  }

  void _editDynamicDropdownItem(int index) {
    final item = _dynamicDropdownData[index];
    final fieldNames = _getFieldNamesFromChildItems();
    final serialNumber = item['mfgSerialNo']?.toString() ?? '';
    
    setState(() {
      _serialNumberController.text = serialNumber;
      
      // Validate and set selected item data based on serial number
      if (serialNumber.isNotEmpty) {
        _validateAndSetSerialNumber(serialNumber, false);
      }
      
      // Set values for dynamic fields based on impacted_item_value_map
      for (var entry in fieldNames.entries) {
        final fieldName = entry.key;
        final fieldKey = entry.value;
        final controller = _childFieldControllers[fieldName];
        controller?.text = item[fieldKey]?.toString() ?? '';
      }
      
      // Load child_item_responses for impacted_item_check_list items
      final childItemResponses = item['child_item_responses'] as List<dynamic>? ?? [];
      final childItems = _currentItem['impacted_item_check_list'] as List<dynamic>? ?? 
                        _currentItem['childitemData'] as List<dynamic>? ?? [];
      
      // Create a map for quick lookup: childId -> response
      final childResponseMap = <int, Map<String, dynamic>>{};
      for (var response in childItemResponses) {
        final childId = response['cm_check_list_mst_id'] as int? ?? 0;
        if (childId > 0) {
          childResponseMap[childId] = Map<String, dynamic>.from(response);
        }
      }
      
      // Load values from child_item_responses
      for (var childItem in childItems) {
        final childId = childItem['cm_check_list_mst_id'] as int? ?? 0;
        final respType = childItem['resp_type']?.toString() ?? '';
        
        if (childResponseMap.containsKey(childId)) {
          final response = childResponseMap[childId]!;
          
          // Handle CHECKBOX
          if (respType == 'CHECKBOX') {
            final resp = response['resp']?.toString() ?? '';
            _childItemCheckboxStates[childId] = (resp == 'true' || resp == 'True' || resp == 'TRUE');
          }
          // Handle CHECKBOX_NUMERIC or CHECKBOX_TEXT
          else if (respType == 'CHECKBOX_NUMERIC' || respType == 'CHECKBOX_TEXT') {
            final resp = response['resp']?.toString() ?? '';
            _childItemCheckboxStates[childId] = (resp != '0' && resp.isNotEmpty);
            final numericValue = response['numeric_value']?.toString() ?? 
                                response['resp_numeric']?.toString() ?? '';
            if (numericValue.isNotEmpty) {
              _childItemNumericValues[childId] = numericValue;
            }
          }
          
          // Load dependent images from child item's response_images
          final responseImages = response['response_images'] as List<dynamic>?;
          if (responseImages != null && responseImages.isNotEmpty) {
            final dependentElements = childItem['dependent_elements'] as List<dynamic>? ?? 
                                     childItem['dependentElements'] as List<dynamic>? ?? [];
            
            for (int i = 0; i < dependentElements.length && i < responseImages.length; i++) {
              final element = dependentElements[i];
              Map<String, dynamic> elementMap;
              if (element is Map<String, dynamic>) {
                elementMap = element;
              } else {
                elementMap = Map<String, dynamic>.from(element as Map);
              }
              
              final elementRespType = elementMap['resp_type']?.toString() ?? '';
              if (elementRespType == 'IMG') {
                final imageData = responseImages[i] as Map<String, dynamic>?;
                final imageDataBase64 = imageData?['image_data']?.toString();
                
                if (imageDataBase64 != null) {
                  final elementKey = '${childId}_$i';
                  // Convert base64 to data URL format for display
                  final imageDataUrl = imageDataBase64.startsWith('data:image')
                      ? imageDataBase64
                      : 'data:image/jpeg;base64,$imageDataBase64';
                  
                  _childItemDependentImageData[childId] ??= {};
                  _childItemDependentImageData[childId]![elementKey] = imageDataUrl;
                  print('[CM] _editDynamicDropdownItem - Loaded child item image for childId: $childId, elementKey: $elementKey');
                }
              }
            }
          }
        } else {
          // Clear states if no response exists
          if (respType == 'CHECKBOX' || respType == 'CHECKBOX_NUMERIC' || respType == 'CHECKBOX_TEXT') {
            _childItemCheckboxStates[childId] = false;
            if (respType == 'CHECKBOX_NUMERIC' || respType == 'CHECKBOX_TEXT') {
              _childItemNumericValues[childId] = '';
            }
          }
        }
      }
      
      // Load dependent images from saved item (parent-level)
      final dependentImages = item['dependent_images'] as List<dynamic>?;
      final dependentElements = _currentItem['dependent_elements'] as List<dynamic>? ?? 
                               _currentItem['dependentElements'] as List<dynamic>? ?? [];
      
      if (dependentImages != null && dependentImages.isNotEmpty) {
        // Find the first IMG dependent element and load its image
        int imgElementIndex = -1;
        for (int i = 0; i < dependentElements.length; i++) {
          final element = dependentElements[i];
          Map<String, dynamic> elementMap;
          if (element is Map<String, dynamic>) {
            elementMap = element;
          } else {
            elementMap = Map<String, dynamic>.from(element as Map);
          }
          
          final respType = elementMap['resp_type']?.toString() ?? '';
          if (respType == 'IMG') {
            imgElementIndex = i;
            break; // Found first IMG element
          }
        }
        
        if (imgElementIndex >= 0) {
          // Get the first image (since we only support one image per dependent element currently)
          final firstImage = dependentImages.first as Map<String, dynamic>?;
          final imageDataBase64 = firstImage?['image_data']?.toString();
          
          if (imageDataBase64 != null) {
            final elementKey = '${_currentItem['cm_check_list_mst_id']}_$imgElementIndex';
            // Convert base64 to data URL format for display
            final imageDataUrl = imageDataBase64.startsWith('data:image')
                ? imageDataBase64
                : 'data:image/jpeg;base64,$imageDataBase64';
            
            _dependentImageData[elementKey] = imageDataUrl;
            print('[CM] _editDynamicDropdownItem - Loaded image for elementKey: $elementKey');
          }
        }
      } else {
        // Clear dependent images if none exist
        for (int i = 0; i < dependentElements.length; i++) {
          final element = dependentElements[i];
          Map<String, dynamic> elementMap;
          if (element is Map<String, dynamic>) {
            elementMap = element;
          } else {
            elementMap = Map<String, dynamic>.from(element as Map);
          }
          
          final respType = elementMap['resp_type']?.toString() ?? '';
          if (respType == 'IMG') {
            final elementKey = '${_currentItem['cm_check_list_mst_id']}_$i';
            _dependentImageData.remove(elementKey);
          }
        }
      }
    });
  }

  Widget _buildDropdownField({bool isReadonly = false}) {
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
      onChanged: isReadonly ? (value) {} : (value) => _onDropdownChanged(value),
      isRequired: false,
      isDisabled: isReadonly,
    );
  }

  Widget _buildRadioField({bool isReadonly = false}) {
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
            onChanged: isReadonly ? null : (value) => _onRadioChanged(value),
            isRequired: false,
          ),
      ],
    );
  }

  Widget _buildTextField({bool isReadonly = false}) {
    // In readonly mode, just show the resp value
    if (isReadonly) {
      final resp = _currentItem['resp']?.toString() ?? '';
    return CustomFormField(
        label: _currentItem['checklist_desc']?.toString() ?? '',
        initialValue: resp,
        isEditable: false,
      );
    }
    
    // Always get dependent_elements from widget.pmItem (source of truth)
    dynamic rawDependentElements = widget.pmItem['dependent_elements'] ?? widget.pmItem['dependentElements'];
    
    // Convert to List if it's not null
    List<dynamic> dependentElements = [];
    if (rawDependentElements != null) {
      if (rawDependentElements is List) {
        dependentElements = rawDependentElements;
      } else {
        try {
          final parsed = jsonDecode(rawDependentElements.toString());
          if (parsed is List) {
            dependentElements = parsed;
          }
        } catch (e) {
          print('[CM] Error parsing dependent_elements in TEXT: $e');
        }
      }
    }
    
    // Also try from _currentItem as fallback
    if (dependentElements.isEmpty) {
      dependentElements = _currentItem['dependent_elements'] as List<dynamic>? ?? [];
    }
    
    // Store in _currentItem for future reference
    if (dependentElements.isNotEmpty && _currentItem['dependent_elements'] == null) {
      _currentItem['dependent_elements'] = dependentElements;
    }
    
    // Get parent response value (for TEXT, use the text value)
    final parentResponse = _textValue != null && _textValue!.isNotEmpty ? _textValue : null;
    
    print('[CM] _buildTextField - _textValue: $_textValue');
    print('[CM] _buildTextField - dependentElements.length: ${dependentElements.length}');
    
    // Create unique key that includes value and dependent_elements
    final dependentElementsHash = dependentElements.isNotEmpty 
        ? dependentElements.length.toString() 
        : '0';
    final textKey = 'text_${_currentItem['cm_check_list_mst_id']}_${_textValue?.length ?? 0}_$dependentElementsHash';
    
    return Column(
      key: ValueKey(textKey),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Text field
        CustomFormField(
      label: _currentItem['checklist_desc']?.toString() ?? '',
      initialValue: _textValue,
      controller: _textController,
          onChanged: isReadonly ? null : _onTextChanged,
      isRequired: false,
          isEditable: !isReadonly,
        ),
        
        // Show dependent_elements when value is not empty
        if (dependentElements.isNotEmpty) ...[
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
            
            // For TEXT fields, show dependent element when value is not empty
            final shouldShow = parentResponse != null && parentResponse.isNotEmpty;
            
            print('[CM] TEXT dependent element $index - respType: $respType, shouldShow: $shouldShow, parentResponse: $parentResponse');
            
            if (respType == 'IMG' && shouldShow) {
              final checklistDesc = elementMap['checklist_desc']?.toString() ?? 'Upload photo';
              final isRequired = _isDependentElementMandatory(
                elementMap['mandatoryIfValue'],
                parentResponse,
    );
              
              print('[CM] Building TEXT IMG field - checklistDesc: $checklistDesc, isRequired: $isRequired');
              
              final isReadonly = widget.readonlyFields.contains(
                _currentItem['checklist_desc']?.toString(),
              );
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: ImageUploadField(
                  key: ValueKey('text_dependent_${elementKey}_${_textValue?.length ?? 0}'),
                  label: checklistDesc,
                  placeholder: 'Upload Photos',
                  isRequired: false,
                  externalImageUrl: _dependentImageData[elementKey],
                  isDisabled: isReadonly,
                  onImageSelected: isReadonly ? (File? file) {} : (File? file) async {
                    if (file != null) {
                      await _uploadDependentImage(elementKey, file);
                    }
                  },
                ),
              );
            }
            return const SizedBox.shrink();
          }),
        ],
      ],
    );
  }

  Widget _buildImageField({bool isReadonly = false}) {
    return ImageUploadField(
      label: _currentItem['checklist_desc']?.toString() ?? '',
      placeholder: 'Upload Photos',
      isRequired: false,
      externalImageUrl: _imageData,
      isDisabled: isReadonly,
      onImageSelected: isReadonly ? (File? file) {} : (File? file) async {
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

  Widget _buildRemarksField({bool isReadonly = false}) {
    return CustomRemarksField(
      label: _currentItem['checklist_desc']?.toString() ?? '',
      hintText: 'Remarks',
      controller: _remarksController,
      isDisabled: isReadonly,
    );
  }

  Widget _buildDynamicNumericField({bool isReadonly = false}) {
    // In readonly mode, just show the resp value and images
    if (isReadonly) {
      final resp = _currentItem['resp']?.toString() ?? '';
      final responseImages = _currentItem['response_images'] as List<dynamic>? ?? [];
      final imageCount = responseImages.length;
      
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CustomFormField(
            label: _currentItem['checklist_desc']?.toString() ?? '',
            initialValue: resp,
            isEditable: false,
            inputType: InputType.number,
          ),
          if (imageCount > 0) ...[
            const SizedBox(height: 15),
            ...List.generate(imageCount, (index) {
              final imageData = responseImages[index];
              String? imageUrl;
              if (imageData is Map<String, dynamic>) {
                final imageDataBase64 = imageData['image_data']?.toString();
                if (imageDataBase64 != null && imageDataBase64.isNotEmpty) {
                  if (imageDataBase64.startsWith('data:image')) {
                    imageUrl = imageDataBase64;
                  } else {
                    imageUrl = 'data:image/jpeg;base64,$imageDataBase64';
                  }
                }
              }
              return Padding(
                padding: const EdgeInsets.only(bottom: 15),
                child: ImageUploadField(
                  label: 'Image ${index + 1}',
                  placeholder: 'Add a Photo',
                  isRequired: false,
                  externalImageUrl: imageUrl,
                  isDisabled: true,
                  onImageSelected: (File? file) {},
                ),
              );
            }),
          ],
        ],
      );
    }
    
    // Get the numeric value and parse it
    final numericValue = _dynamicNumericController.text.trim();
    int? count;
    if (numericValue.isNotEmpty) {
      count = int.tryParse(numericValue);
      if (count != null && count > 8) {
        count = 8; // Limit to 8
      }
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CustomFormField(
          label: _currentItem['checklist_desc']?.toString() ?? '',
          controller: _dynamicNumericController,
          inputType: InputType.number,
          maxLength: 1, // Limit to single digit (0-8)
          isRequired: _currentItem['is_mandatory'] == true,
          onChanged: (value) {
            // Validate and limit to 8
            final parsed = int.tryParse(value.trim());
            if (parsed != null && parsed > 8) {
              _dynamicNumericController.text = '8';
              _dynamicNumericController.selection = TextSelection.fromPosition(
                TextPosition(offset: _dynamicNumericController.text.length),
              );
            }
            
            setState(() {
              final newValue = _dynamicNumericController.text.trim();
              _currentItem['resp'] = newValue;
              
              // Update response_images array based on count
              final newCount = newValue.isNotEmpty ? (int.tryParse(newValue) ?? 0) : 0;
              final limitedCount = newCount > 8 ? 8 : newCount;
              
              // Get or create response_images array
              List<dynamic> responseImages = _currentItem['response_images'] as List<dynamic>? ?? [];
              
              // Trim or extend array to match count
              if (responseImages.length > limitedCount) {
                // Remove excess images
                responseImages = responseImages.sublist(0, limitedCount);
                // Also clear from state maps
                for (int i = limitedCount; i < _dynamicNumericImageData.length; i++) {
                  _dynamicNumericImageData.remove(i);
                  _dynamicNumericImageFiles.remove(i);
                }
              } else if (responseImages.length < limitedCount) {
                // Add empty entries for new images
                while (responseImages.length < limitedCount) {
                  responseImages.add({
                    'photo_id': 'LOCAL_IMAGE_ID',
                    'pclsri_id': _currentItem['cm_check_list_mst_id'],
                    'photo_taken_ts': DateTime.now().toIso8601String(),
                  });
                }
              }
              
              _currentItem['response_images'] = responseImages;
            });
            
            _notifyValueChanged();
          },
        ),
        if (count != null && count > 0) ...[
          const SizedBox(height: 15),
          ...List.generate(count, (index) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 15),
              child: ImageUploadField(
                label: 'Image ${index + 1}',
                placeholder: 'Add a Photo',
                isRequired: false,
                externalImageUrl: _dynamicNumericImageData[index],
                isDisabled: false,
                onImageSelected: (File? file) async {
                  if (file != null) {
                    await _uploadDynamicNumericImage(index, file);
                  }
                },
              ),
            );
          }),
        ],
      ],
    );
  }

  Future<void> _uploadDynamicNumericImage(int index, File imageFile) async {
    try {
      // Read file as bytes and encode to base64
      final bytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(bytes);
      
      // Store image data for display
      setState(() {
        _dynamicNumericImageFiles[index] = imageFile;
        _dynamicNumericImageData[index] = 'data:image/jpeg;base64,$base64Image';
      });
      
      // Add image to response_images array
      _addDynamicNumericImageToResponseImages(index, base64Image);
      
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

  void _addDynamicNumericImageToResponseImages(int index, String base64Image) {
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
    
    // Update the image at the specified index
    responseImages[index] = {
      'photo_id': 'LOCAL_IMAGE_ID',
      'pclsri_id': _currentItem['cm_check_list_mst_id'],
      'photo_taken_ts': DateTime.now().toIso8601String(),
      'image_data': base64Image, // Store base64 for upload
    };
    
    _currentItem['response_images'] = responseImages;
  }

  // Helper method to build a field widget from a child item in impacted_item_check_list
  Widget _buildChildItemField(Map<String, dynamic> childItem, int parentId, {bool isReadonly = false}) {
    final childId = childItem['cm_check_list_mst_id'] as int? ?? 0;
    final respType = childItem['resp_type']?.toString() ?? '';
    final checklistDesc = childItem['checklist_desc']?.toString() ?? '';
    
    // Get dependent_elements from childItem - try both field names
    List<dynamic> dependentElements = childItem['dependent_elements'] as List<dynamic>? ?? 
                                       childItem['dependentElements'] as List<dynamic>? ?? [];
    
    // Debug logging for child items with dependent_elements
    if (dependentElements.isNotEmpty) {
      print('[CM] _buildChildItemField - Child $childId ($respType) has ${dependentElements.length} dependent_elements');
    }
    
    // Initialize state for this child item if not exists
    if (!_childItemCheckboxStates.containsKey(childId)) {
      _childItemCheckboxStates[childId] = false;
    }
    if (!_childItemDependentImageData.containsKey(childId)) {
      _childItemDependentImageData[childId] = {};
    }
    if (!_childItemDependentImageFiles.containsKey(childId)) {
      _childItemDependentImageFiles[childId] = {};
    }
    
    final isChecked = _childItemCheckboxStates[childId] ?? false;
    final numericValue = _childItemNumericValues[childId] ?? '';
    
    switch (respType) {
      case 'CHECKBOX':
        // Create unique key that includes checkbox state and dependent_elements
        final childDependentElementsHash = dependentElements.isNotEmpty 
            ? dependentElements.length.toString() 
            : '0';
        final childCheckboxKey = 'child_checkbox_${childId}_${isChecked}_$childDependentElementsHash';
        
        return Column(
          key: ValueKey(childCheckboxKey),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CheckboxListTile(
              title: Text(checklistDesc),
              value: isChecked,
              onChanged: isReadonly ? null : (bool? value) {
                setState(() {
                  _childItemCheckboxStates[childId] = value ?? false;
                  print('[CM] Child CHECKBOX $childId changed to: $value');
                  print('[CM] Child CHECKBOX $childId - dependentElements.length: ${dependentElements.length}');
                });
              },
            ),
            // Show dependent_elements when checked
            if (isChecked && dependentElements.isNotEmpty) ...[
              const SizedBox(height: 8),
              ...dependentElements.asMap().entries.map((entry) {
                final index = entry.key;
                final element = entry.value as Map<String, dynamic>;
                final elementKey = '${childId}_$index';
                final elementRespType = element['resp_type']?.toString() ?? '';
                final isReadonly = widget.readonlyFields.contains(
                  _currentItem['checklist_desc']?.toString(),
                );
                
                if (elementRespType == 'IMG') {
                  final elementDesc = element['checklist_desc']?.toString() ?? 'Upload photo';
                  
                  return Padding(
                    padding: const EdgeInsets.only(left: 40, bottom: 16),
                    child: ImageUploadField(
                      key: ValueKey('child_dependent_$elementKey'),
                      label: elementDesc,
                      placeholder: 'Upload Photos',
                      isRequired: false,
                      externalImageUrl: _childItemDependentImageData[childId]![elementKey],
                      isDisabled: isReadonly,
                      onImageSelected: isReadonly ? (File? file) {} : (File? file) async {
                        if (file != null) {
                          await _uploadChildItemDependentImage(childId, elementKey, file);
                        }
                      },
                    ),
                  );
                }
                return const SizedBox.shrink();
              }),
            ],
          ],
        );
        
      case 'CHECKBOX_NUMERIC':
        // Create unique key that includes checkbox state and dependent_elements
        final childNumericDependentElementsHash = dependentElements.isNotEmpty 
            ? dependentElements.length.toString() 
            : '0';
        final childNumericCheckboxKey = 'child_checkbox_numeric_${childId}_${isChecked}_$childNumericDependentElementsHash';
        
        return Column(
          key: ValueKey(childNumericCheckboxKey),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CheckboxListTile(
              title: Text(checklistDesc),
              value: isChecked,
              onChanged: isReadonly ? null : (bool? value) {
                setState(() {
                  _childItemCheckboxStates[childId] = value ?? false;
                  print('[CM] Child CHECKBOX_NUMERIC $childId changed to: $value');
                  print('[CM] Child CHECKBOX_NUMERIC $childId - dependentElements.length: ${dependentElements.length}');
                });
              },
            ),
            // Show numeric field when checked
            if (isChecked) ...[
              Padding(
                padding: const EdgeInsets.only(left: 40, bottom: 16),
                child: CustomFormField(
                  label: 'Enter value',
                  initialValue: numericValue,
                  onChanged: isReadonly ? null : (String value) {
                    setState(() {
                      _childItemNumericValues[childId] = value;
                    });
                  },
                  isRequired: false,
                  inputType: InputType.number,
                  isEditable: !isReadonly,
                ),
              ),
            ],
            // Show dependent_elements when checked
            if (isChecked && dependentElements.isNotEmpty) ...[
              const SizedBox(height: 8),
              ...dependentElements.asMap().entries.map((entry) {
                final index = entry.key;
                final element = entry.value as Map<String, dynamic>;
                final elementKey = '${childId}_$index';
                final elementRespType = element['resp_type']?.toString() ?? '';
                final isReadonly = widget.readonlyFields.contains(
                  _currentItem['checklist_desc']?.toString(),
                );
                
                if (elementRespType == 'IMG') {
                  final elementDesc = element['checklist_desc']?.toString() ?? 'Upload photo';
                  
                  return Padding(
                    padding: const EdgeInsets.only(left: 40, bottom: 16),
                    child: ImageUploadField(
                      key: ValueKey('child_dependent_$elementKey'),
                      label: elementDesc,
                      placeholder: 'Upload Photos',
                      isRequired: false,
                      externalImageUrl: _childItemDependentImageData[childId]![elementKey],
                      isDisabled: isReadonly,
                      onImageSelected: isReadonly ? (File? file) {} : (File? file) async {
                        if (file != null) {
                          await _uploadChildItemDependentImage(childId, elementKey, file);
                        }
                      },
                    ),
                  );
                }
                return const SizedBox.shrink();
              }),
            ],
          ],
        );
        
      case 'TEXT':
      case 'NUMERIC':
        // For TEXT or NUMERIC, check if they have impacted_item_value_map (old behavior)
        final impactedItemValueMap = childItem['impacted_item_value_map']?.toString() ?? '';
        if (impactedItemValueMap.isNotEmpty) {
          // This is a dynamic field (like SOC, SOH) - use text field
          final controller = _childFieldControllers[checklistDesc] ??= TextEditingController();
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: CustomFormField(
              label: checklistDesc,
              controller: controller,
              isRequired: false,
              inputType: respType == 'NUMERIC' ? InputType.number : InputType.text,
              isEditable: !isReadonly,
            ),
          );
        }
        // Otherwise, render as regular field with dependent_elements
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CustomFormField(
              label: checklistDesc,
              isRequired: false,
              inputType: respType == 'NUMERIC' ? InputType.number : InputType.text,
              isEditable: !isReadonly,
            ),
            if (dependentElements.isNotEmpty) ...[
              const SizedBox(height: 8),
              ...dependentElements.asMap().entries.map((entry) {
                final index = entry.key;
                final element = entry.value as Map<String, dynamic>;
                final elementKey = '${childId}_$index';
                final elementRespType = element['resp_type']?.toString() ?? '';
                
                if (elementRespType == 'IMG') {
                  final elementDesc = element['checklist_desc']?.toString() ?? 'Upload photo';
                  final isReadonly = widget.readonlyFields.contains(
                    _currentItem['checklist_desc']?.toString(),
                  );
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: ImageUploadField(
                      key: ValueKey('child_dependent_$elementKey'),
                      label: elementDesc,
                      placeholder: 'Upload Photos',
                      isRequired: false,
                      externalImageUrl: _childItemDependentImageData[childId]![elementKey],
                      isDisabled: isReadonly,
                      onImageSelected: isReadonly ? (File? file) {} : (File? file) async {
                        if (file != null) {
                          await _uploadChildItemDependentImage(childId, elementKey, file);
                        }
                      },
                    ),
                  );
                }
                return const SizedBox.shrink();
              }),
            ],
          ],
        );
        
      default:
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Text('Unknown field type: $respType'),
        );
    }
  }
  
  Future<void> _uploadChildItemDependentImage(int childId, String elementKey, File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(bytes);
      
      setState(() {
        _childItemDependentImageFiles[childId] ??= {};
        _childItemDependentImageFiles[childId]![elementKey] = imageFile;
        _childItemDependentImageData[childId] ??= {};
        _childItemDependentImageData[childId]![elementKey] = 'data:image/jpeg;base64,$base64Image';
      });
      
      if (mounted) {
        Toastbar.showSuccessToastbar("Image uploaded successfully", context);
      }
    } catch (e) {
      if (mounted) {
        Toastbar.showErrorToastbar("Error uploading image: $e", context);
      }
    }
  }

  Widget _buildDynamicDropdownField({bool isReadonly = false}) {
    // In edit/view mode, if we have original cmImpactedItemList, show table view
    if (isReadonly) {
      final originalImpactedItems = _currentItem['_originalCmImpactedItemList'] as List<dynamic>?;
      if (originalImpactedItems != null && originalImpactedItems.isNotEmpty) {
        return _buildReadonlyImpactedItemsTable(originalImpactedItems);
      }
    }
    
    // Use impacted_item_check_list instead of childitemData
    final childItems = _currentItem['impacted_item_check_list'] as List<dynamic>? ?? 
                       _currentItem['childitemData'] as List<dynamic>? ?? [];
    final parentId = _currentItem['cm_check_list_mst_id'] as int? ?? 0;
    
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
          label: '${_currentItem['sub_item_type'] ?? 'Item'} - Serial Number',
          controller: _serialNumberController,
          onQRScanned: isReadonly ? null : _onQRScanned,
        ),
        const SizedBox(height: 16),
        
        // Show dependent_elements when filling form (always show, not just when items are saved)
        _buildDependentElementsForDynamicDropdown(isReadonly: isReadonly),
        
        // Child fields - render dynamically based on their resp_type
        ...childItems.map((childItem) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _buildChildItemField(childItem as Map<String, dynamic>, parentId, isReadonly: isReadonly),
          );
        }),
        
        // Save button
        if (!isReadonly)
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

        // Data table - only show if there are items
        if (_dynamicDropdownData.isNotEmpty) ...[
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
                  // Add columns for all child items from impacted_item_check_list
                  // (dependent_elements will be shown in the same column as the parent checklist_desc)
                  ..._getAllChildItems().map((childItem) {
                    final checklistDesc = childItem['checklist_desc']?.toString() ?? '';
                    if (checklistDesc.isEmpty) return null;
                    
                    return DataColumn(
                      label: Text(checklistDesc, style: TextStyle(fontWeight: FontWeight.bold)),
                    );
                  }).whereType<DataColumn>().toList(),
                  // Add Photo column if there's an IMG dependent element at parent level
                  if (_hasImgDependentElement()) ...[
                    DataColumn(
                      label: Text('Photo', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                  DataColumn(
                    label: Text('Edit', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
                rows: _dynamicDropdownData.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;
                  
                  // Get child_item_responses from saved data
                  final childItemResponses = item['child_item_responses'] as List<dynamic>? ?? [];
                  // Create a map for quick lookup: childId -> response
                  final childResponseMap = <int, Map<String, dynamic>>{};
                  for (var response in childItemResponses) {
                    final childId = response['cm_check_list_mst_id'] as int? ?? 0;
                    if (childId > 0) {
                      childResponseMap[childId] = Map<String, dynamic>.from(response);
                    }
                  }
                  
                  // Get dependent image from saved data (parent level)
                  String? dependentImageData;
                  final dependentImages = item['dependent_images'] as List<dynamic>?;
                  if (dependentImages != null && dependentImages.isNotEmpty) {
                    final firstImage = dependentImages.first as Map<String, dynamic>?;
                    final imageData = firstImage?['image_data']?.toString();
                    if (imageData != null) {
                      // Convert base64 to data URL for display
                      dependentImageData = imageData.startsWith('data:image') 
                          ? imageData 
                          : 'data:image/jpeg;base64,$imageData';
                    }
                  }
                  
                  return DataRow(
                    cells: [
                      DataCell(Text(item['mfgSerialNo']?.toString() ?? '')),
                      DataCell(Text(item['isScanned'] == true ? 'Yes' : 'No')),
                      // Add cells for all child items from impacted_item_check_list
                      // (combining value and dependent_elements in the same cell)
                      ..._getAllChildItems().map((childItem) {
                        final childId = childItem['cm_check_list_mst_id'] as int? ?? 0;
                        final respType = childItem['resp_type']?.toString() ?? '';
                        final impactedItemValueMap = childItem['impacted_item_value_map']?.toString() ?? '';
                        final dependentElements = _getChildItemDependentElements(childId);
                        
                        // Get response value for this child item
                        String? childResponseValue;
                        if (impactedItemValueMap.isNotEmpty) {
                          // For items with impacted_item_value_map, get value from item directly
                          childResponseValue = item[impactedItemValueMap]?.toString() ?? '';
                        } else if (childResponseMap.containsKey(childId)) {
                          // For other types (CHECKBOX, etc.), get from child_item_responses
                          final response = childResponseMap[childId]!;
                          if (respType == 'CHECKBOX') {
                            final resp = response['resp']?.toString() ?? '';
                            childResponseValue = (resp == 'true' || resp == 'True' || resp == 'TRUE') ? 'Yes' : 'No';
                          } else if (respType == 'CHECKBOX_NUMERIC' || respType == 'CHECKBOX_TEXT') {
                            final resp = response['resp']?.toString() ?? '';
                            final numericValue = response['numeric_value']?.toString() ?? response['resp_numeric']?.toString() ?? '';
                            if (resp == '0' || resp.isEmpty) {
                              childResponseValue = 'No';
                            } else {
                              childResponseValue = numericValue.isNotEmpty ? numericValue : 'Yes';
                            }
                          } else {
                            childResponseValue = response['resp']?.toString() ?? '';
                          }
                        }
                        
                        // Get dependent image data if available
                        String? childDependentImageData;
                        for (var element in dependentElements) {
                          final elementRespType = element['resp_type']?.toString() ?? '';
                          if (elementRespType == 'IMG' && childResponseMap.containsKey(childId)) {
                            final response = childResponseMap[childId]!;
                            final responseImages = response['response_images'] as List<dynamic>?;
                            if (responseImages != null && responseImages.isNotEmpty) {
                              final firstImage = responseImages.first as Map<String, dynamic>?;
                              final imageData = firstImage?['image_data']?.toString();
                              if (imageData != null) {
                                childDependentImageData = imageData.startsWith('data:image') 
                                    ? imageData 
                                    : 'data:image/jpeg;base64,$imageData';
                                break; // Use first image found
                              }
                            }
                          }
                        }
                        
                        // Create a cell that combines the value and dependent element (photo icon)
                        return DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Show the text value
                              Flexible(
                                child: Text(
                                  childResponseValue ?? '',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              // Show photo icon if dependent element has image
                              if (childDependentImageData != null) ...[
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: Icon(
                                    Icons.camera_alt,
                                    color: AppColors.color555555,
                                    size: 20,
                                  ),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () => _showDependentPhotoViewer(context, childDependentImageData!),
                                ),
                              ],
                            ],
                          ),
                        );
                      }).toList(),
                      // Show photo camera icon if available (parent level)
                      if (_hasImgDependentElement()) ...[
                        DataCell(
                          Container(
                            width: 50,
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: IconButton(
                              icon: Icon(
                                Icons.camera_alt,
                                color: dependentImageData != null
                                    ? AppColors.color555555
                                    : Colors.grey,
                                size: 24,
                              ),
                              onPressed: dependentImageData != null
                                  ? () => _showDependentPhotoViewer(context, dependentImageData!)
                                  : null,
                            ),
                          ),
                        ),
                      ],
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
        ],
    ),
          ),
      );
  }
  
  bool _hasImgDependentElement() {
    final dependentElements = _currentItem['dependent_elements'] as List<dynamic>? ?? 
                             _currentItem['dependentElements'] as List<dynamic>? ?? [];
    for (var element in dependentElements) {
      Map<String, dynamic> elementMap;
      if (element is Map<String, dynamic>) {
        elementMap = element;
      } else {
        elementMap = Map<String, dynamic>.from(element as Map);
      }
      final respType = elementMap['resp_type']?.toString() ?? '';
      if (respType == 'IMG') {
        return true;
      }
    }
    return false;
  }
  
  /// Shows photo viewer dialog for dependent element images
  Future<void> _showDependentPhotoViewer(BuildContext context, String? imageData) async {
    if (imageData == null || imageData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No photo available to view.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Ensure proper data URL format
    final finalImageData = imageData.startsWith('data:image/')
        ? imageData
        : 'data:image/jpeg;base64,$imageData';

    // Show photo viewer dialog
    if (context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (context) => Dialog(
          backgroundColor: Colors.black,
          child: Stack(
            children: [
              Center(
                child: Container(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.8,
                    maxWidth: MediaQuery.of(context).size.width * 0.9,
                  ),
                  child: Image.memory(
                    base64Decode(finalImageData.split(',').last),
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return const Center(
                        child: Text(
                          'Failed to load image',
                          style: TextStyle(color: Colors.white),
                        ),
                      );
                    },
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  icon: const Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 30,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }
  
  Widget _buildDependentElementsForDynamicDropdown({bool isReadonly = false}) {
    // Get dependent_elements from _currentItem
    List<dynamic> dependentElements = _currentItem['dependent_elements'] as List<dynamic>? ?? 
                                     _currentItem['dependentElements'] as List<dynamic>? ?? [];
    
    if (dependentElements.isEmpty) {
      dependentElements = widget.pmItem['dependent_elements'] as List<dynamic>? ?? 
                          widget.pmItem['dependentElements'] as List<dynamic>? ?? [];
    }
    
    if (dependentElements.isEmpty) {
      return const SizedBox.shrink();
    }
    
    // Always show dependent elements in the form (they will be saved with the item)
    final shouldShow = true;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
          
          print('[CM] DYNAMIC_DROPDOWN dependent element $index - respType: $respType, shouldShow: $shouldShow');
          
          if (respType == 'IMG' && shouldShow) {
            final checklistDesc = elementMap['checklist_desc']?.toString() ?? 'Add a photo';
            final mandatoryIfValue = elementMap['mandatoryIfValue'];
            final isRequired = _isDependentElementMandatory(mandatoryIfValue, 'true');
            final isReadonlyField = widget.readonlyFields.contains(
              _currentItem['checklist_desc']?.toString(),
            );
            
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: ImageUploadField(
                label: checklistDesc,
                placeholder: checklistDesc,
                isRequired: isRequired,
                externalImageUrl: _dependentImageData[elementKey],
                isDisabled: isReadonly || isReadonlyField,
                onImageSelected: (isReadonly || isReadonlyField) ? (File? file) {} : (File? file) async {
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
    );
  }

  Widget _buildMultiDynamicDropdownField({bool isReadonly = false}) {
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
            ],
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 2,
        ),
            // Multi-select dropdown
            InkWell(
              onTap: isReadonly ? null : () {
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
                        onChanged: isReadonly ? null : (bool? value) {
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
                    if (!isReadonly)
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

  Widget _buildCheckboxField({bool isReadonly = false}) {
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
    
    // Create a unique key that includes checkbox state and dependent_elements
    final dependentElementsHash = dependentElements.isNotEmpty 
        ? dependentElements.length.toString() 
        : '0';
    final checkboxKey = 'checkbox_${_currentItem['cm_check_list_mst_id']}_${_isCheckboxChecked}_$dependentElementsHash';
    
    return Column(
      key: ValueKey(checkboxKey),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Checkbox
        Row(
          children: [
            Checkbox(
              value: _isCheckboxChecked,
              onChanged: isReadonly ? null : (bool? value) {
                print('[CM] Checkbox clicked - value: $value');
                print('[CM] Checkbox - dependentElements.length: ${dependentElements.length}');
                _onCheckboxChanged(value);
              },
            ),
            Expanded(
              child: Text(
                _currentItem['checklist_desc']?.toString() ?? '',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.normal,
                ),
              ),
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
              final isReadonly = widget.readonlyFields.contains(
                _currentItem['checklist_desc']?.toString(),
              );
              
              print('[CM] Building IMG field - checklistDesc: $checklistDesc, isMandatory: $isMandatory');
              
              return Padding(
                padding: const EdgeInsets.only(left: 32, bottom: 16),
                child: ImageUploadField(
                  key: ValueKey('dependent_image_$elementKey'),
                  label: checklistDesc,
                  placeholder: checklistDesc,
                  isRequired: false,
                  externalImageUrl: _dependentImageData[elementKey],
                  isDisabled: isReadonly,
                  onImageSelected: isReadonly ? (File? file) {} : (File? file) async {
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
  
  Widget _buildCheckboxNumericField({bool isReadonly = false}) {
    // In readonly mode, just show the resp value
    if (isReadonly) {
      final resp = _currentItem['resp']?.toString() ?? '';
      return CustomFormField(
        label: _currentItem['checklist_desc']?.toString() ?? '',
        initialValue: resp,
        isEditable: false,
        inputType: InputType.number,
      );
    }
    
    // Always get dependent_elements from widget.pmItem (source of truth)
    dynamic rawDependentElements = widget.pmItem['dependent_elements'] ?? widget.pmItem['dependentElements'];
    
    // Convert to List if it's not null
    List<dynamic> dependentElements = [];
    if (rawDependentElements != null) {
      if (rawDependentElements is List) {
        dependentElements = rawDependentElements;
      } else {
        try {
          final parsed = jsonDecode(rawDependentElements.toString());
          if (parsed is List) {
            dependentElements = parsed;
          }
        } catch (e) {
          print('[CM] Error parsing dependent_elements in CHECKBOX_NUMERIC: $e');
        }
      }
    }
    
    // Also try from _currentItem as fallback
    if (dependentElements.isEmpty) {
      dependentElements = _currentItem['dependent_elements'] as List<dynamic>? ?? [];
    }
    
    // Store in _currentItem for future reference
    if (dependentElements.isNotEmpty && _currentItem['dependent_elements'] == null) {
      _currentItem['dependent_elements'] = dependentElements;
    }
    
    // Get parent response value (checkbox checked = "true", unchecked = null/empty)
    final parentResponse = _isCheckboxChecked ? 'true' : null;
    
    // Create unique key that includes checkbox state and dependent_elements
    final dependentElementsHash = dependentElements.isNotEmpty 
        ? dependentElements.length.toString() 
        : '0';
    final checkboxNumericKey = 'checkbox_numeric_${_currentItem['cm_check_list_mst_id']}_${_isCheckboxChecked}_$dependentElementsHash';
    
    return Column(
      key: ValueKey(checkboxNumericKey),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Checkbox
        Row(
          children: [
            Checkbox(
              value: _isCheckboxChecked,
              onChanged: isReadonly ? null : (bool? value) {
                _onCheckboxChanged(value);
              },
            ),
            Expanded(
              child: Text(
                _currentItem['checklist_desc']?.toString() ?? '',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.normal,
                ),
              ),
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
              onChanged: isReadonly ? null : _onCheckboxNumericChanged,
              isRequired: false,
              inputType: InputType.number,
              isEditable: !isReadonly,
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
              final isReadonly = widget.readonlyFields.contains(
                _currentItem['checklist_desc']?.toString(),
              );
              
              return Padding(
                padding: const EdgeInsets.only(left: 32, bottom: 16),
                child: ImageUploadField(
                  label: checklistDesc,
                  placeholder: checklistDesc,
                  isRequired: false,
                  externalImageUrl: _dependentImageData[elementKey],
                  isDisabled: isReadonly,
                  onImageSelected: isReadonly ? (File? file) {} : (File? file) async {
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
  
  Widget _buildFieldByType(String respType, {bool isReadonly = false}) {
    switch (respType) {
      case 'DROPDOWN':
        return _buildDropdownField(isReadonly: isReadonly);
      case 'RADIO':
        return _buildRadioField(isReadonly: isReadonly);
      case 'TEXT':
        return _buildTextField(isReadonly: isReadonly);
      case 'NUMERIC':
        return _buildNumericField(isReadonly: isReadonly);
      case 'CHECKBOX':
        return _buildCheckboxField(isReadonly: isReadonly);
      case 'CHECKBOX_NUMERIC':
        return _buildCheckboxNumericField(isReadonly: isReadonly);
      case 'IMG':
        return _buildImageField(isReadonly: isReadonly);
      case 'REMARKS':
        return _buildRemarksField(isReadonly: isReadonly);
      case 'DYNAMIC_DROPDOWN':
        return _buildDynamicDropdownField(isReadonly: isReadonly);
      case 'MULTI_DYNAMIC_DROPDOWN':
        return _buildMultiDynamicDropdownField(isReadonly: isReadonly);
      case 'DYNAMIC_NUMERIC':
        return _buildDynamicNumericField(isReadonly: isReadonly);
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
  
  Widget _buildNumericField({bool isReadonly = false}) {
    // In readonly mode, just show the resp value
    if (isReadonly) {
      final resp = _currentItem['resp']?.toString() ?? '';
      return CustomFormField(
        label: _currentItem['checklist_desc']?.toString() ?? '',
        initialValue: resp,
        isEditable: false,
        inputType: InputType.number,
      );
    }
    
    // Always get dependent_elements from widget.pmItem (source of truth)
    dynamic rawDependentElements = widget.pmItem['dependent_elements'] ?? widget.pmItem['dependentElements'];
    
    // Convert to List if it's not null
    List<dynamic> dependentElements = [];
    if (rawDependentElements != null) {
      if (rawDependentElements is List) {
        dependentElements = rawDependentElements;
      } else {
        try {
          final parsed = jsonDecode(rawDependentElements.toString());
          if (parsed is List) {
            dependentElements = parsed;
          }
        } catch (e) {
          print('[CM] Error parsing dependent_elements in NUMERIC: $e');
        }
      }
    }
    
    // Also try from _currentItem as fallback
    if (dependentElements.isEmpty) {
      dependentElements = _currentItem['dependent_elements'] as List<dynamic>? ?? [];
    }
    
    // Store in _currentItem for future reference
    if (dependentElements.isNotEmpty && _currentItem['dependent_elements'] == null) {
      _currentItem['dependent_elements'] = dependentElements;
    }
    
    // Get parent response value (for NUMERIC, use the text value)
    // For mandatoryIfValue: true, any non-empty value should show the dependent element
    final parentResponse = _textValue != null && _textValue!.isNotEmpty ? _textValue : null;
    
    print('[CM] _buildNumericField - _textValue: $_textValue');
    print('[CM] _buildNumericField - parentResponse: $parentResponse');
    print('[CM] _buildNumericField - dependentElements.length: ${dependentElements.length}');
    print('[CM] _buildNumericField - widget.pmItem keys: ${widget.pmItem.keys.toList()}');
    print('[CM] _buildNumericField - widget.pmItem[dependent_elements]: ${widget.pmItem['dependent_elements']}');
    if (dependentElements.isNotEmpty) {
      print('[CM] _buildNumericField - dependentElements[0]: ${dependentElements[0]}');
      final firstElement = dependentElements[0] as Map<String, dynamic>?;
      if (firstElement != null) {
        print('[CM] _buildNumericField - firstElement[mandatoryIfValue]: ${firstElement['mandatoryIfValue']}');
        print('[CM] _buildNumericField - firstElement[mandatoryIfValue] type: ${firstElement['mandatoryIfValue'].runtimeType}');
      }
    }
    
    // Create unique key that includes value and dependent_elements
    // Use the actual value (or hash) to ensure rebuild when value changes
    final valueHash = _textValue != null && _textValue!.isNotEmpty 
        ? _textValue.hashCode.toString() 
        : 'empty';
    final dependentElementsHash = dependentElements.isNotEmpty 
        ? dependentElements.length.toString() 
        : '0';
    final numericKey = 'numeric_${_currentItem['cm_check_list_mst_id']}_${valueHash}_$dependentElementsHash';
    
    print('[CM] _buildNumericField - Building with key: $numericKey, _textValue: $_textValue');
    
    return Column(
      key: ValueKey(numericKey),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Numeric field
        CustomFormField(
          key: ValueKey('numeric_input_${_currentItem['cm_check_list_mst_id']}_$valueHash'),
          label: _currentItem['checklist_desc']?.toString() ?? '',
          initialValue: _textValue,
          controller: _textController,
          onChanged: isReadonly ? null : _onTextChanged,
          isRequired: false,
          inputType: InputType.number,
          isEditable: !isReadonly,
        ),
        
        // Show dependent_elements when value is not empty
        if (dependentElements.isNotEmpty && parentResponse != null && parentResponse.isNotEmpty) ...[
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
            
            // For NUMERIC fields, show dependent element when value is not empty
            // The mandatoryIfValue only determines if it's required, not visibility
            // parentResponse is already checked in the outer if, so it's guaranteed to be non-null here
            final shouldShow = true; // Already checked in outer if condition
            
            print('[CM] NUMERIC dependent element $index - respType: $respType, shouldShow: $shouldShow, parentResponse: $parentResponse');
            
            if (respType == 'IMG' && shouldShow) {
              final checklistDesc = elementMap['checklist_desc']?.toString() ?? 'Upload photo';
              final isRequired = _isDependentElementMandatory(
                elementMap['mandatoryIfValue'],
                parentResponse,
              );
              final isReadonly = widget.readonlyFields.contains(
                _currentItem['checklist_desc']?.toString(),
              );
              
              print('[CM] Building NUMERIC IMG field - checklistDesc: $checklistDesc, isRequired: $isRequired');
              
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: ImageUploadField(
                  key: ValueKey('numeric_dependent_${elementKey}_${_textValue?.length ?? 0}'),
                  label: checklistDesc,
                  placeholder: 'Upload Photos',
                  isRequired: false,
                  externalImageUrl: _dependentImageData[elementKey],
                  isDisabled: isReadonly,
                  onImageSelected: isReadonly ? (File? file) {} : (File? file) async {
                    if (file != null) {
                      await _uploadDependentImage(elementKey, file);
                    }
                  },
                ),
              );
            }
            return const SizedBox.shrink();
          }),
        ],
      ],
    );
  }

  /// Build readonly table for impacted items in edit/view mode
  Widget _buildReadonlyImpactedItemsTable(List<dynamic> impactedItems) {
    // Get checklist descriptions from child items template
    final childItems = _currentItem['impacted_item_check_list'] as List<dynamic>? ?? 
                      _currentItem['childitemData'] as List<dynamic>? ?? [];
    final Map<int, String> mstIdToDesc = {};
    final List<MapEntry<int, String>> orderedDescs = [];
    
    for (var childItem in childItems) {
      if (childItem is Map<String, dynamic>) {
        final mstId = childItem['cm_check_list_mst_id'] as int?;
        final desc = childItem['checklist_desc']?.toString() ?? '';
        if (mstId != null && desc.isNotEmpty) {
          mstIdToDesc[mstId] = desc;
          orderedDescs.add(MapEntry(mstId, desc));
        }
      }
    }
    
    // Group items by serial number (mfgSerialNo)
    final Map<String, Map<int, Map<String, dynamic>>> groupedBySerial = {};
    
    for (var item in impactedItems) {
      if (item is Map<String, dynamic>) {
        final serialNo = item['mfgSerialNo']?.toString() ?? 
                        item['mfg_serial_no']?.toString() ?? '';
        if (serialNo.isNotEmpty) {
          if (!groupedBySerial.containsKey(serialNo)) {
            groupedBySerial[serialNo] = {};
          }
          final mstId = item['cmCheckListMstId'] as int? ?? 
                       item['cm_check_list_mst_id'] as int?;
          if (mstId != null) {
            groupedBySerial[serialNo]![mstId] = item;
          }
        }
      }
    }
    
    final parentDesc = _currentItem['checklist_desc']?.toString() ?? '';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Heading
          Text(
            parentDesc,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              fontFamily: fontFamilyMontserrat,
            ),
          ),
          const SizedBox(height: 12),
          // Table
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
                  const DataColumn(
                    label: Text('Serial Number', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  ...orderedDescs.map((entry) => 
                    DataColumn(
                      label: Text(entry.value, style: const TextStyle(fontWeight: FontWeight.bold)),
                    )
                  ),
                ],
                rows: groupedBySerial.entries.map((entry) {
                  final serialNo = entry.key;
                  final itemsByMstId = entry.value;
                  
                  return DataRow(
                    cells: [
                      DataCell(Text(serialNo)),
                      ...orderedDescs.map((descEntry) {
                        final mstId = descEntry.key;
                        final item = itemsByMstId[mstId];
                        
                        if (item == null) {
                          return const DataCell(Text(''));
                        }
                        
                        final respType = item['respType']?.toString() ?? 
                                        item['resp_type']?.toString() ?? '';
                        final resp = item['resp']?.toString() ?? '';
                        final images = item['cmCheckListSiteRespImagesList'] as List<dynamic>? ?? 
                                      item['cm_check_list_site_resp_images_list'] as List<dynamic>? ?? [];
                        
                        Widget cellContent;
                        if (respType == 'CHECKBOX_NUMERIC') {
                          cellContent = Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(resp),
                              if (images.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(left: 8),
                                  child: InkWell(
                                    onTap: () => _showImageGallery(images),
                                    child: const Icon(Icons.camera_alt, size: 20, color: Colors.blue),
                                  ),
                                ),
                            ],
                          );
                        } else if (respType == 'CHECKBOX') {
                          final isChecked = resp.toLowerCase() == 'true' || resp == '1';
                          cellContent = Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isChecked ? Icons.check_box : Icons.check_box_outline_blank,
                                size: 20,
                                color: isChecked ? Colors.green : Colors.grey,
                              ),
                              if (images.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(left: 8),
                                  child: InkWell(
                                    onTap: () => _showImageGallery(images),
                                    child: const Icon(Icons.camera_alt, size: 20, color: Colors.blue),
                                  ),
                                ),
                            ],
                          );
                        } else {
                          cellContent = Text(resp);
                        }
                        
                        return DataCell(cellContent);
                      }).toList(),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  /// Show image gallery dialog
  void _showImageGallery(List<dynamic> images) {
    if (images.isEmpty) return;
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.8,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Images', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: images.length,
                  itemBuilder: (context, index) {
                    final img = images[index];
                    final photoId = img['photoId'] ?? img['photo_id'];
                    if (photoId == null) return const SizedBox.shrink();
                    
                    return FutureBuilder<String?>(
                      future: _loadImageFromPhotoId(photoId.toString()),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        
                        if (snapshot.hasData && snapshot.data != null) {
                          return Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Image.memory(
                              base64Decode(snapshot.data!.split(',')[1]),
                              fit: BoxFit.contain,
                            ),
                          );
                        }
                        
                        return const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Center(child: Text('Failed to load image')),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  /// Load image from photo ID
  Future<String?> _loadImageFromPhotoId(String photoId) async {
    try {
      // First check cache
      final cachedImage = await ServiceLocator()
          .imageUploadService
          .getImagesByServerId(photoId);
      
      if (cachedImage != null && cachedImage.imageData != null) {
        return cachedImage.imageData;
      }
      
      // Try to download if online
      final isOnline = await ConnectivityHelper.isConnected();
      if (isOnline) {
        final uniqueId = await ServiceLocator()
            .imageUploadService
            .downloadImageUsingServerId(
              photoId,
              ActivityTypeEnum.correctiveMaintenance,
              '',
            );
        
        if (uniqueId != null) {
          return await ServiceLocator()
              .imageUploadService
              .getImageUsingUniqueId(uniqueId);
        }
      }
    } catch (e) {
      Logger.errorLog('[CM] Error loading image $photoId: $e');
    }
    
    return null;
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
          // Field based on resp_type - show actual field type even when readonly, but disabled
          if (checklistDesc.toLowerCase().contains('remarks'))
            _buildRemarksField(isReadonly: isReadonly)
          else
            _buildFieldByType(respType, isReadonly: isReadonly),
        ],
      ),
    );
  }
}