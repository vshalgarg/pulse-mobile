import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';
import '../constants/constants_strings.dart';
import '../constants/constants_methods.dart';
import '../commonWidgets/custom_form_field.dart';
import '../commonWidgets/custom_form_dropdown.dart';
import '../commonWidgets/custom_radio_options.dart';

class PMCustomFormComponent extends StatefulWidget {
  /// The checklist item containing resp_dtl_checklist and response_details
  final Map<String, dynamic> checklistItem;

  /// Callback when the form data changes
  final Function(Map<String, dynamic>) onChange;

  const PMCustomFormComponent({
    super.key,
    required this.checklistItem,
    required this.onChange,
  });

  @override
  State<PMCustomFormComponent> createState() => _PMCustomFormComponentState();
}

class _PMCustomFormComponentState extends State<PMCustomFormComponent> {
  // Parent field controller
  final TextEditingController _parentController = TextEditingController();

  // Store form values for each resp_dtl_checklist item
  // Key: pm_check_list_mst_id, Value: Map containing field values
  Map<int, Map<String, dynamic>> _formValues = {};

  // Controllers for each field type
  Map<int, TextEditingController> _textControllers = {};
  Map<int, TextEditingController> _numericControllers = {};

  // Reset counter to force widget rebuild when form is cleared
  int _resetCounter = 0;

  @override
  void initState() {
    super.initState();
    _initializeFromExistingData();
  }

  @override
  void dispose() {
    _parentController.dispose();
    for (final controller in _textControllers.values) {
      controller.dispose();
    }
    for (final controller in _numericControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  /// Initialize form from existing data
  void _initializeFromExistingData() {
    // Initialize parent resp value if exists
    final parentResp = widget.checklistItem['resp'];
    if (parentResp != null) {
      _parentController.text = parentResp.toString();
    }

    // Initialize form values for resp_dtl_checklist items
    final respDtlChecklistItems = _respDtlChecklistItems;
    for (final item in respDtlChecklistItems) {
      final pmCheckListMstId = item['pm_check_list_mst_id'] as int?;
      if (pmCheckListMstId != null) {
        _formValues[pmCheckListMstId] = {};
        
        // Initialize controllers
        final respType = item['resp_type']?.toString() ?? '';
        if (respType == 'TEXT') {
          _textControllers[pmCheckListMstId] = TextEditingController();
        } else if (respType == 'NUMERIC') {
          _numericControllers[pmCheckListMstId] = TextEditingController();
        }
      }
    }
  }

  /// Get all resp_dtl_checklist items
  List<Map<String, dynamic>> get _respDtlChecklistItems {
    final respDtlChecklist = widget.checklistItem['resp_dtl_checklist'];
    if (respDtlChecklist is List) {
      return respDtlChecklist
          .where((item) => item is Map<String, dynamic>)
          .map((item) => item as Map<String, dynamic>)
          .toList();
    }
    return [];
  }

  /// Get parent resp_type
  String get _parentRespType {
    return widget.checklistItem['resp_type']?.toString() ?? '';
  }

  /// Get parent resp value as count (max allowed entries per checklist item)
  int? get _maxAllowedEntriesPerItem {
    final resp = widget.checklistItem['resp'];
    if (resp == null || resp.toString().isEmpty) return null;
    return int.tryParse(resp.toString());
  }

  /// Get current response_details count for a specific checklist item
  int _getCurrentEntriesCountForChecklist(int pmCheckListMstId) {
    final responseDetails = widget.checklistItem['response_details'];
    if (responseDetails == null || responseDetails is! List) {
      return 0;
    }
    return responseDetails.where((item) {
      if (item is! Map<String, dynamic>) return false;
      return item['pm_check_list_mst_id'] == pmCheckListMstId;
    }).length;
  }

  /// Check if we can add more entries for a specific checklist item
  bool _canAddMoreEntriesForChecklist(int pmCheckListMstId) {
    final maxEntries = _maxAllowedEntriesPerItem;
    if (maxEntries == null || maxEntries == 0) {
      // If parent resp is null/0, allow unlimited entries
      return true;
    }
    return _getCurrentEntriesCountForChecklist(pmCheckListMstId) < maxEntries;
  }

  /// Check if save button should be enabled
  /// Returns false if any field with a value has reached its maximum entries
  bool _isSaveButtonEnabled() {
    final respDtlChecklistItems = _respDtlChecklistItems;
    
    // Check each field that has a value
    for (final item in respDtlChecklistItems) {
      final pmCheckListMstId = item['pm_check_list_mst_id'] as int?;
      if (pmCheckListMstId == null) continue;
      
      final formValue = _formValues[pmCheckListMstId];
      if (formValue == null) continue;
      
      final valueObj = formValue['value'];
      if (valueObj == null) continue;
      
      final value = valueObj.toString();
      if (value.isEmpty) continue;
      
      // If this field has a value but max entries reached, disable save
      if (!_canAddMoreEntriesForChecklist(pmCheckListMstId)) {
        return false;
      }
    }
    
    return true;
  }

  /// Handle parent field value change
  void _onParentValueChanged(String value) {
    final updatedItem = Map<String, dynamic>.from(widget.checklistItem);
    updatedItem['resp'] = value.isEmpty ? null : value;
    widget.onChange(updatedItem);
  }

  /// Get all mfg_serial_no values from response_details for NUMERIC type with serial numbers
  List<String> _getAvailableSerialNumbers(int pmCheckListMstId) {
    final responseDetails = widget.checklistItem['response_details'];
    if (responseDetails == null || responseDetails is! List) {
      return [];
    }

    // Get unique serial numbers (remove duplicates)
    final serialNumbersSet = <String>{};
    for (final item in responseDetails) {
      if (item is Map<String, dynamic> &&
          item['pm_check_list_mst_id'] == pmCheckListMstId &&
          item['mfg_serial_no'] != null &&
          item['mfg_serial_no'].toString().isNotEmpty) {
        final serial = item['mfg_serial_no']?.toString();
        if (serial != null && serial.isNotEmpty) {
          serialNumbersSet.add(serial);
        }
      }
    }
    
    return serialNumbersSet.toList();
  }

  /// Check if NUMERIC type should show serial number dropdown
  bool _shouldShowSerialNumberDropdown(Map<String, dynamic> item) {
    final respType = item['resp_type']?.toString() ?? '';
    if (respType != 'NUMERIC') return false;

    final responseDetails = widget.checklistItem['response_details'];
    if (responseDetails == null || responseDetails is! List) return false;

    // Check if any response_detail has mfg_serial_no for this checklist item
    final pmCheckListMstId = item['pm_check_list_mst_id'] as int?;
    if (pmCheckListMstId == null) return false;

    return responseDetails.any((detail) {
      if (detail is! Map<String, dynamic>) return false;
      return detail['pm_check_list_mst_id'] == pmCheckListMstId &&
          detail['mfg_serial_no'] != null &&
          detail['mfg_serial_no'].toString().isNotEmpty;
    });
  }

  /// Build parent field based on resp_type
  Widget _buildParentField() {
    final checklistDesc =
        widget.checklistItem['checklist_desc']?.toString() ?? '';
    final respType = _parentRespType;
    final isReadonly = widget.checklistItem['is_readonly'] == true;

    if (respType.isEmpty) return const SizedBox.shrink();

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
          if (respType == 'NUMERIC')
            CustomFormField(
              controller: _parentController,
              onChanged: _onParentValueChanged,
              isRequired: true,
              isEditable: !isReadonly,
              inputType: InputType.number,
              hintText: 'Enter numeric value',
            )
          else if (respType == 'TEXT')
            CustomFormField(
              controller: _parentController,
              onChanged: _onParentValueChanged,
              isRequired: true,
              isEditable: !isReadonly,
              inputType: InputType.text,
              hintText: 'Enter text',
            ),
        ],
      ),
    );
  }

  /// Build field for a resp_dtl_checklist item based on its resp_type
  Widget _buildFieldForItem(Map<String, dynamic> item) {
    final pmCheckListMstId = item['pm_check_list_mst_id'] as int?;
    if (pmCheckListMstId == null) return const SizedBox.shrink();

    final label = item['checklist_desc']?.toString() ?? '';
    final respType = item['resp_type']?.toString() ?? '';

    // Initialize form value if not exists
    if (!_formValues.containsKey(pmCheckListMstId)) {
      _formValues[pmCheckListMstId] = {};
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label
          Text(
            label,
            style: const TextStyle(
              color: AppColors.black,
              fontSize: 16,
              fontWeight: FontWeight.w500,
              fontFamily: fontFamilyMontserrat,
            ),
          ),
          const SizedBox(height: 8),

          // Build field based on resp_type
          if (respType == 'RADIO')
            _buildRadioField(item, pmCheckListMstId)
          else if (respType == 'TEXT')
            _buildTextField(item, pmCheckListMstId)
          else if (respType == 'DROPDOWN')
            _buildDropdownField(item, pmCheckListMstId)
          else if (respType == 'NUMERIC')
            _buildNumericField(item, pmCheckListMstId),
        ],
      ),
    );
  }

  /// Build Radio field
  Widget _buildRadioField(Map<String, dynamic> item, int pmCheckListMstId) {
    final respTypeValueMap = item['resp_type_value_map'];

    // Parse radio options from resp_type_value_map
    Map<String, dynamic> valueMap = {};
    if (respTypeValueMap is Map<String, dynamic>) {
      valueMap = respTypeValueMap;
    } else if (respTypeValueMap is String) {
      try {
        valueMap = jsonDecode(respTypeValueMap) as Map<String, dynamic>;
      } catch (e) {
        valueMap = {'OK': 'OK', 'Not Ok': 'Not Ok'};
      }
    } else {
      valueMap = {'OK': 'OK', 'Not Ok': 'Not Ok'};
    }

    final currentValue = _formValues[pmCheckListMstId]?['value'] as String?;

    return CustomRadioButton(
      key: ValueKey('radio_${pmCheckListMstId}_$_resetCounter'),
      options: valueMap.entries
          .map(
            (entry) => OptionItem(
              label: entry.key,
              value: entry.value.toString(),
            ),
          )
          .toList(),
      initialValue: currentValue,
      onChanged: (value) {
        setState(() {
          _formValues[pmCheckListMstId] = {'value': value};
        });
      },
      isRequired: true,
      textColor: AppColors.black,
    );
  }

  /// Build Text field
  Widget _buildTextField(Map<String, dynamic> item, int pmCheckListMstId) {
    if (!_textControllers.containsKey(pmCheckListMstId)) {
      _textControllers[pmCheckListMstId] = TextEditingController();
    }

    final controller = _textControllers[pmCheckListMstId]!;

    return CustomFormField(
      controller: controller,
      onChanged: (value) {
        setState(() {
          _formValues[pmCheckListMstId] = {'value': value};
        });
      },
      isRequired: true,
      inputType: InputType.text,
      hintText: 'Enter text',
    );
  }

  /// Build Dropdown field
  Widget _buildDropdownField(Map<String, dynamic> item, int pmCheckListMstId) {
    final respTypeValueMap = item['resp_type_value_map'];

    // Parse dropdown options from resp_type_value_map
    List<String> dropdownOptions = [];
    Map<String, String> valueMap = {};

    if (respTypeValueMap is Map<String, dynamic>) {
      respTypeValueMap.forEach((key, value) {
        dropdownOptions.add(key);
        valueMap[key] = value.toString();
      });
    } else if (respTypeValueMap is String) {
      try {
        final parsedMap = jsonDecode(respTypeValueMap) as Map<String, dynamic>;
        parsedMap.forEach((key, value) {
          dropdownOptions.add(key);
          valueMap[key] = value.toString();
        });
      } catch (e) {
        dropdownOptions = ['OK', 'Not Ok'];
        valueMap = {'OK': 'OK', 'Not Ok': 'Not Ok'};
      }
    }

    if (dropdownOptions.isEmpty) {
      dropdownOptions = ['OK', 'Not Ok'];
      valueMap = {'OK': 'OK', 'Not Ok': 'Not Ok'};
    }

    final currentValue = _formValues[pmCheckListMstId]?['value'] as String?;

    return CustomDropdown(
      key: ValueKey('dropdown_${pmCheckListMstId}_$_resetCounter'),
      items: dropdownOptions,
      initialValue: currentValue,
      onChanged: (value) {
        setState(() {
          // Use mapped value if available, otherwise use the label
          final mappedValue = valueMap[value] ?? value;
          _formValues[pmCheckListMstId] = {'value': mappedValue};
        });
      },
    );
  }

  /// Build Numeric field (may include serial number dropdown)
  Widget _buildNumericField(Map<String, dynamic> item, int pmCheckListMstId) {
    if (!_numericControllers.containsKey(pmCheckListMstId)) {
      _numericControllers[pmCheckListMstId] = TextEditingController();
    }

    final controller = _numericControllers[pmCheckListMstId]!;

    // Check if should show serial number dropdown
    if (_shouldShowSerialNumberDropdown(item)) {
      final serialNumbers = _getAvailableSerialNumbers(pmCheckListMstId);
      final currentSerial = _formValues[pmCheckListMstId]?['serialNumber'] as String?;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Serial number dropdown
          if (serialNumbers.isNotEmpty)
            CustomDropdown(
              key: ValueKey('serial_dropdown_${pmCheckListMstId}_$_resetCounter'),
              items: serialNumbers,
              initialValue: (currentSerial != null && serialNumbers.contains(currentSerial))
                  ? currentSerial
                  : null,
              onChanged: (value) {
                setState(() {
                  _formValues[pmCheckListMstId] = {
                    ..._formValues[pmCheckListMstId] ?? {},
                    'serialNumber': value,
                  };

                  // Load existing value if available
                  if (value != null) {
                    final responseDetails = widget.checklistItem['response_details'];
                    if (responseDetails is List) {
                      final matchingItem = responseDetails.firstWhere(
                        (detail) =>
                            detail is Map<String, dynamic> &&
                            detail['mfg_serial_no']?.toString() == value &&
                            detail['pm_check_list_mst_id'] == pmCheckListMstId &&
                            detail['resp'] != null &&
                            detail['resp'].toString().isNotEmpty,
                        orElse: () => null,
                      );
                      if (matchingItem != null && matchingItem is Map<String, dynamic>) {
                        controller.text = matchingItem['resp']?.toString() ?? '';
                        _formValues[pmCheckListMstId] = {
                          ..._formValues[pmCheckListMstId] ?? {},
                          'value': matchingItem['resp']?.toString(),
                        };
                      } else {
                        controller.clear();
                      }
                    }
                  }
                });
              },
            ),
          const SizedBox(height: 12),

          // Numeric input
          CustomFormField(
            controller: controller,
            onChanged: (value) {
              setState(() {
                _formValues[pmCheckListMstId] = {
                  ..._formValues[pmCheckListMstId] ?? {},
                  'value': value,
                };
              });
            },
            isRequired: true,
            inputType: InputType.number,
            hintText: 'Enter numeric value',
          ),
        ],
      );
    } else {
      // Simple numeric input
      return CustomFormField(
        controller: controller,
        onChanged: (value) {
          setState(() {
            _formValues[pmCheckListMstId] = {'value': value};
          });
        },
        isRequired: true,
        inputType: InputType.number,
        hintText: 'Enter numeric value',
      );
    }
  }

  /// Handle save button click - saves all filled fields
  void _onSaveAllEntries() {
    final respDtlChecklistItems = _respDtlChecklistItems;
    List<Map<String, dynamic>> updatedResponseDetails = [];

    // Get existing response_details
    final existingResponseDetails = widget.checklistItem['response_details'];
    if (existingResponseDetails is List) {
      updatedResponseDetails = List<Map<String, dynamic>>.from(
        existingResponseDetails.map((item) {
          if (item is Map<String, dynamic>) {
            return Map<String, dynamic>.from(item);
          }
          return item;
        }),
      );
    }

    // Process each resp_dtl_checklist item
    for (final item in respDtlChecklistItems) {
      final pmCheckListMstId = item['pm_check_list_mst_id'] as int?;
      if (pmCheckListMstId == null) continue;

      final formValue = _formValues[pmCheckListMstId];
      if (formValue == null) continue;

      final valueObj = formValue['value'];
      if (valueObj == null) continue;
      
      final value = valueObj.toString();
      if (value.isEmpty) continue;

      final respType = item['resp_type']?.toString() ?? '';

      if (respType == 'NUMERIC' && _shouldShowSerialNumberDropdown(item)) {
        // NUMERIC with serial number - update existing entry
        final serialNumber = formValue['serialNumber']?.toString();
        if (serialNumber == null || serialNumber.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please select a serial number'),
              backgroundColor: AppColors.errorColor,
            ),
          );
          return;
        }

        // Find and update matching entry
        bool found = false;
        for (int i = 0; i < updatedResponseDetails.length; i++) {
          final detail = updatedResponseDetails[i];
          if (detail['mfg_serial_no']?.toString() == serialNumber &&
              detail['pm_check_list_mst_id'] == pmCheckListMstId) {
            updatedResponseDetails[i] = {
              ...detail,
              'resp': value,
            };
            found = true;
            break;
          }
        }

        if (!found) {
          // Create new entry
          final newEntry = Map<String, dynamic>.from(item);
          newEntry['mfg_serial_no'] = serialNumber;
          newEntry['resp'] = value;
          updatedResponseDetails.add(newEntry);
        }
      } else {
        // Other types - check if we can add more entries
        if (!_canAddMoreEntriesForChecklist(pmCheckListMstId)) {
          final maxEntries = _maxAllowedEntriesPerItem;
          final checklistDesc = item['checklist_desc']?.toString() ?? 'this item';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Maximum entries reached for $checklistDesc (${maxEntries})'),
              backgroundColor: AppColors.errorColor,
            ),
          );
          return;
        }

        // Add new entry
        final newEntry = Map<String, dynamic>.from(item);
        newEntry['resp'] = value;
        updatedResponseDetails.add(newEntry);
      }
    }

    // Update the checklist item
    final updatedItem = Map<String, dynamic>.from(widget.checklistItem);
    updatedItem['response_details'] = updatedResponseDetails;
    widget.onChange(updatedItem);

    // Clear form and increment reset counter to force widget rebuild
    setState(() {
      _formValues.clear();
      for (final controller in _textControllers.values) {
        controller.clear();
      }
      for (final controller in _numericControllers.values) {
        controller.clear();
      }
      _resetCounter++; // Increment to force widgets to rebuild with new keys
    });

    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Saved successfully'),
        backgroundColor: AppColors.primaryGreen,
      ),
    );
  }

  /// Build saved items table
  Widget _buildSavedItemsTable() {
    final responseDetails = widget.checklistItem['response_details'];
    if (responseDetails == null || responseDetails is! List) {
      return const SizedBox.shrink();
    }

    // Filter only items that have been saved (have resp value)
    final savedItems = responseDetails.where((item) {
      if (item is! Map<String, dynamic>) return false;
      final resp = item['resp'];
      return resp != null && resp.toString().isNotEmpty;
    }).toList();

    if (savedItems.isEmpty) {
      return const SizedBox.shrink();
    }

    // Create a map of pm_check_list_mst_id to checklist_desc for lookup
    final respDtlChecklistItems = _respDtlChecklistItems;
    final Map<int, String> checklistNameMap = {};
    for (final item in respDtlChecklistItems) {
      final id = item['pm_check_list_mst_id'] as int?;
      final name = item['checklist_desc']?.toString() ?? '';
      if (id != null) {
        checklistNameMap[id] = name;
      }
    }

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.colorF5F5F5,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Table header
          Row(
            children: [
              Expanded(child: _buildTableHeaderCell('Checklist Name')),
              Expanded(child: _buildTableHeaderCell('Value')),
            ],
          ),
          const SizedBox(height: 8),
          // Table rows with sequence numbers
          ..._buildTableRowsWithSequence(savedItems, checklistNameMap),
        ],
      ),
    );
  }

  /// Build table rows with sequence numbers for each checklist item
  List<Widget> _buildTableRowsWithSequence(
    List<dynamic> savedItems,
    Map<int, String> checklistNameMap,
  ) {
    // Group items by pm_check_list_mst_id
    final Map<int, List<Map<String, dynamic>>> groupedItems = {};
    
    for (final item in savedItems) {
      if (item is! Map<String, dynamic>) continue;
      final pmCheckListMstId = item['pm_check_list_mst_id'] as int?;
      if (pmCheckListMstId == null) continue;
      
      if (!groupedItems.containsKey(pmCheckListMstId)) {
        groupedItems[pmCheckListMstId] = [];
      }
      groupedItems[pmCheckListMstId]!.add(item);
    }

    // Build rows with sequence numbers
    List<Widget> rows = [];
    
    // Get max entries to determine how many sequence numbers we need
    final maxEntries = _maxAllowedEntriesPerItem;
    if (maxEntries == null || maxEntries == 0) {
      // If no limit, just show all items without sequence numbers
      for (final item in savedItems) {
        if (item is! Map<String, dynamic>) continue;
        final pmCheckListMstId = item['pm_check_list_mst_id'] as int?;
        final checklistName = pmCheckListMstId != null
            ? (checklistNameMap[pmCheckListMstId] ??
                  item['checklist_desc']?.toString() ??
                  '')
            : (item['checklist_desc']?.toString() ?? '');
        
        String displayValue = item['resp']?.toString() ?? '';
        if (item['mfg_serial_no'] != null) {
          final serial = item['mfg_serial_no']?.toString() ?? '';
          displayValue = '$serial: $displayValue';
        }
        rows.add(_buildTableRow(checklistName, displayValue));
      }
      return rows;
    }
    
    // For each sequence number (1 to maxEntries)
    for (int seq = 1; seq <= maxEntries; seq++) {
      // For each checklist item in resp_dtl_checklist order
      final respDtlChecklistItems = _respDtlChecklistItems;
      for (final checklistItem in respDtlChecklistItems) {
        final pmCheckListMstId = checklistItem['pm_check_list_mst_id'] as int?;
        if (pmCheckListMstId == null) continue;
        
        final items = groupedItems[pmCheckListMstId] ?? [];
        
        // Get the item at this sequence position (seq - 1 because it's 0-indexed)
        if (seq <= items.length) {
          final item = items[seq - 1];
          final checklistName = checklistNameMap[pmCheckListMstId] ??
              item['checklist_desc']?.toString() ??
              '';
          
          String displayValue = item['resp']?.toString() ?? '';
          // If has mfg_serial_no, include it in display
          if (item['mfg_serial_no'] != null) {
            final serial = item['mfg_serial_no']?.toString() ?? '';
            displayValue = '$serial: $displayValue';
          }
          
          // Add sequence number to checklist name
          final checklistNameWithSeq = '$checklistName $seq';
          rows.add(_buildTableRow(checklistNameWithSeq, displayValue));
        }
      }
    }
    
    return rows;
  }

  /// Build table header cell
  Widget _buildTableHeaderCell(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: AppColors.color555555,
        fontSize: 14,
        fontFamily: fontFamilyMontserrat,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  /// Build table row
  Widget _buildTableRow(String checklistName, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              checklistName,
              style: const TextStyle(
                color: AppColors.color555555,
                fontSize: 14,
                fontFamily: fontFamilyMontserrat,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.color555555,
                fontSize: 14,
                fontFamily: fontFamilyMontserrat,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final respDtlChecklistItems = _respDtlChecklistItems;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Parent field OUTSIDE white box
        _buildParentField(),

        // 2. White box containing resp_dtl_checklist items (form fields)
        if (respDtlChecklistItems.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.colorF5F5F5,
              borderRadius: BorderRadius.circular(5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // All resp_dtl_checklist fields
                ...respDtlChecklistItems.map((item) => _buildFieldForItem(item)).toList(),

                // Save button at bottom right
                Align(
                  alignment: Alignment.bottomRight,
                  child: ElevatedButton.icon(
                    onPressed: _isSaveButtonEnabled() ? _onSaveAllEntries : null,
                    icon: Icon(
                      Icons.save,
                      color: _isSaveButtonEnabled() ? Colors.white : Colors.grey,
                    ),
                    label: Text(
                      'Save',
                      style: TextStyle(
                        color: _isSaveButtonEnabled() ? Colors.white : Colors.grey,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        fontFamily: fontFamilyMontserrat,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isSaveButtonEnabled()
                          ? AppColors.primaryGreen
                          : Colors.grey.shade400,
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

        // 3. Saved items table in separate white box
        _buildSavedItemsTable(),

        // Add margin below saved items table
        getHeight(15),
      ],
    );
  }
}
