import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';
import '../constants/constants_strings.dart';
import '../constants/constants_methods.dart';
import '../commonWidgets/custom_form_field.dart';
import '../commonWidgets/custom_form_dropdown.dart';
import '../commonWidgets/custom_radio_options.dart';
import '../utils/logger.dart';
import '../utils/toastbar.dart';

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
  // Key: pm_check_list_mst_id (as String) or 'pmCheckListMstId_sectionIndex' for sections, Value: Map containing field values
  Map<String, Map<String, dynamic>> _formValues = <String, Map<String, dynamic>>{};

  // Controllers for each field type (using String keys to support both int keys and section keys like 'pmCheckListMstId_sectionIndex')
  Map<String, TextEditingController> _textControllers = {};
  Map<String, TextEditingController> _numericControllers = {};
  // Controllers for serial number inputs (key: 'pmCheckListMstId_serialNumber')
  Map<String, TextEditingController> _serialNumberControllers = {};

  // Reset counter to force widget rebuild when form is cleared
  int _resetCounter = 0;

  // True when user has edited any field since last save; Save button disabled when false
  bool _hasEditsSinceLastSave = false;

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
    for (final controller in _serialNumberControllers.values) {
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
        _formValues[pmCheckListMstId.toString()] = {};
        
        // Initialize controllers (using string key for compatibility)
        final respType = item['resp_type']?.toString() ?? '';
        if (respType == 'TEXT') {
          _textControllers[pmCheckListMstId.toString()] = TextEditingController();
        } else if (respType == 'NUMERIC') {
          _numericControllers[pmCheckListMstId.toString()] = TextEditingController();
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

  /// Check if parent field has a value
  bool get _isParentFieldEmpty {
    final resp = widget.checklistItem['resp'];
    return resp == null || resp.toString().isEmpty;
  }

  /// Handle parent field value change
  void _onParentValueChanged(String value) {
    final updatedItem = Map<String, dynamic>.from(widget.checklistItem);
    updatedItem['resp'] = value.isEmpty ? null : value;
    widget.onChange(updatedItem);
    // Trigger rebuild to enable/disable child fields
    setState(() {});
  }

  /// Check if should show multiple sections (RADIO type, no serial numbers, no response_details initially)
  bool _shouldShowMultipleSections(List<Map<String, dynamic>> respDtlChecklistItems) {
    if (_isParentFieldEmpty) return false;
    
    // Check if we have response_details with mfg_serial_no (if so, don't use multiple sections)
    final responseDetails = widget.checklistItem['response_details'];
    if (responseDetails != null && responseDetails is List && responseDetails.isNotEmpty) {
      // Check if any response_detail has mfg_serial_no
      final hasSerialNumbers = responseDetails.any((detail) {
        if (detail is! Map<String, dynamic>) return false;
        return detail['mfg_serial_no'] != null && detail['mfg_serial_no'].toString().isNotEmpty;
      });
      if (hasSerialNumbers) return false; // NUMERIC with serial numbers uses its own UI
    }
    
    // Check if all items are RADIO type
    bool hasRadioItems = false;
    for (final item in respDtlChecklistItems) {
      final respType = item['resp_type']?.toString() ?? '';
      if (respType == 'RADIO' || respType == 'Radio') {
        hasRadioItems = true;
      } else if (respType == 'NUMERIC' && _shouldShowSerialNumberDropdown(item)) {
        // NUMERIC with serial numbers uses its own UI, don't use multiple sections
        return false;
      }
    }
    
    return hasRadioItems;
  }

  /// Get save button text based on checklist_desc from NUMERIC item with serial numbers
  String _getSaveButtonText() {
    // Always return 'Save' regardless of checklist description
    return 'Save';
  }

  /// Get section heading based on checklist_ref and count
  String _getSectionHeading(int sectionIndex) {
    final parentChecklistRef = widget.checklistItem['checklist_ref']?.toString() ?? 
                               widget.checklistItem['pm_item_type']?.toString() ?? '';
    if (parentChecklistRef.isNotEmpty) {
      return '$parentChecklistRef ${sectionIndex + 1}';
    }
    return 'Section ${sectionIndex + 1}';
  }

  /// Build multiple sections for RADIO type
  Widget _buildMultipleSections(List<Map<String, dynamic>> respDtlChecklistItems) {
    final parentResp = widget.checklistItem['resp'];
    if (parentResp == null) return const SizedBox.shrink();
    
    final count = int.tryParse(parentResp.toString()) ?? 0;
    if (count <= 0) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(count, (index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Section heading
              Text(
                _getSectionHeading(index),
                style: const TextStyle(
                  color: AppColors.black,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  fontFamily: fontFamilyMontserrat,
                ),
              ),
              const SizedBox(height: 16),
              
              // Fields for this section
              ...respDtlChecklistItems.map((item) => _buildFieldForItemWithSection(item, index)).toList(),
            ],
          ),
        );
      }),
    );
  }

  /// Build field for a resp_dtl_checklist item with section index
  Widget _buildFieldForItemWithSection(Map<String, dynamic> item, int sectionIndex) {
    final pmCheckListMstId = item['pm_check_list_mst_id'] as int?;
    if (pmCheckListMstId == null) return const SizedBox.shrink();

    final label = item['checklist_desc']?.toString() ?? '';
    final respType = item['resp_type']?.toString() ?? '';

    // Initialize form value if not exists (with section index)
    final sectionKey = '${pmCheckListMstId}_$sectionIndex';
    if (!_formValues.containsKey(sectionKey)) {
      _formValues[sectionKey] = {};
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

          // Build field based on resp_type (using section key)
          if (respType == 'RADIO' || respType == 'Radio')
            _buildRadioFieldWithSection(item, pmCheckListMstId, sectionIndex)
          else if (respType == 'TEXT')
            _buildTextFieldWithSection(item, pmCheckListMstId, sectionIndex)
          else if (respType == 'DROPDOWN')
            _buildDropdownFieldWithSection(item, pmCheckListMstId, sectionIndex)
          else if (respType == 'NUMERIC')
            _buildNumericFieldWithSection(item, pmCheckListMstId, sectionIndex),
        ],
      ),
    );
  }

  /// Build Radio field with section index
  Widget _buildRadioFieldWithSection(Map<String, dynamic> item, int pmCheckListMstId, int sectionIndex) {
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

    final sectionKey = '${pmCheckListMstId}_$sectionIndex';
    final currentValue = _formValues[sectionKey]?['value'] as String?;
    final isDisabled = _isParentFieldEmpty;

    return CustomRadioButton(
      key: ValueKey('radio_${pmCheckListMstId}_${sectionIndex}_$_resetCounter'),
      options: valueMap.entries
          .map(
            (entry) => OptionItem(
              label: entry.key,
              value: entry.value.toString(),
            ),
          )
          .toList(),
      initialValue: currentValue,
      onChanged: isDisabled ? null : (value) {
        setState(() {
          _formValues[sectionKey] = {'value': value};
        });
      },
      isRequired: true,
      textColor: AppColors.black,
    );
  }

  /// Build Text field with section index
  Widget _buildTextFieldWithSection(Map<String, dynamic> item, int pmCheckListMstId, int sectionIndex) {
    final sectionKey = '${pmCheckListMstId}_$sectionIndex';
    if (!_textControllers.containsKey(sectionKey)) {
      _textControllers[sectionKey] = TextEditingController();
    }

    final controller = _textControllers[sectionKey]!;

    return CustomFormField(
      controller: controller,
      onChanged: (value) {
        setState(() {
          _hasEditsSinceLastSave = true;
          _formValues[sectionKey] = {'value': value};
        });
      },
      isRequired: true,
      inputType: InputType.text,
      hintText: 'Enter text',
    );
  }

  /// Build Dropdown field with section index
  Widget _buildDropdownFieldWithSection(Map<String, dynamic> item, int pmCheckListMstId, int sectionIndex) {
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

    final sectionKey = '${pmCheckListMstId}_$sectionIndex';
    final currentValue = _formValues[sectionKey]?['value'] as String?;
    final isDisabled = _isParentFieldEmpty;

    return CustomDropdown(
      key: ValueKey('dropdown_${pmCheckListMstId}_${sectionIndex}_$_resetCounter'),
      items: dropdownOptions,
      initialValue: currentValue,
      onChanged: (value) {
        setState(() {
          _hasEditsSinceLastSave = true;
          // Use mapped value if available, otherwise use the label
          final mappedValue = valueMap[value] ?? value;
          _formValues[sectionKey] = {'value': mappedValue};
        });
      },
      isRequired: true,
      isDisabled: isDisabled,
    );
  }

  /// Build Numeric field with section index
  Widget _buildNumericFieldWithSection(Map<String, dynamic> item, int pmCheckListMstId, int sectionIndex) {
    final sectionKey = '${pmCheckListMstId}_$sectionIndex';
    if (!_numericControllers.containsKey(sectionKey)) {
      _numericControllers[sectionKey] = TextEditingController();
    }

    final controller = _numericControllers[sectionKey]!;

    return CustomFormField(
      controller: controller,
      onChanged: (value) {
        setState(() {
          _hasEditsSinceLastSave = true;
          _formValues[sectionKey] = {'value': value};
        });
      },
      isRequired: true,
      isEditable: !_isParentFieldEmpty,
      inputType: InputType.number,
      hintText: 'Enter numeric value',
    );
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
              hintText: 'Enter Number',
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
    final key = pmCheckListMstId.toString();
    if (!_formValues.containsKey(key)) {
      _formValues[key] = {};
    }

    // For NUMERIC with serial numbers, don't show the label here (it's shown in _buildSerialNumberListField)
    final shouldShowLabel = !(respType == 'NUMERIC' && _shouldShowSerialNumberDropdown(item));

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label (only show if not NUMERIC with serial numbers)
        if (shouldShowLabel) ...[
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
        ],

          // Build field based on resp_type
          if (respType == 'RADIO' || respType == 'Radio')
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

    final key = pmCheckListMstId.toString();
    final currentValue = _formValues[key]?['value'] as String?;
    final isDisabled = _isParentFieldEmpty;

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
      onChanged: isDisabled ? null : (value) {
        setState(() {
          _formValues[key] = {'value': value};
        });
      },
      isRequired: true,
      textColor: AppColors.black,
    );
  }

  /// Build Text field
  Widget _buildTextField(Map<String, dynamic> item, int pmCheckListMstId) {
    final key = pmCheckListMstId.toString();
    if (!_textControllers.containsKey(key)) {
      _textControllers[key] = TextEditingController();
    }

    final controller = _textControllers[key]!;

    return CustomFormField(
      controller: controller,
      onChanged: (value) {
        setState(() {
          _hasEditsSinceLastSave = true;
          final key = pmCheckListMstId.toString();
          _formValues[key] = {'value': value};
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

    final key = pmCheckListMstId.toString();
    final currentValue = _formValues[key]?['value'] as String?;
    final isDisabled = _isParentFieldEmpty;

    return CustomDropdown(
      key: ValueKey('dropdown_${pmCheckListMstId}_$_resetCounter'),
      items: dropdownOptions,
      initialValue: currentValue,
      onChanged: (value) {
        setState(() {
          _hasEditsSinceLastSave = true;
          // Use mapped value if available, otherwise use the label
          final mappedValue = valueMap[value] ?? value;
          _formValues[key] = {'value': mappedValue};
        });
      },
      isRequired: true,
      isDisabled: isDisabled,
    );
  }

  /// Build Numeric field (may include serial number list)
  Widget _buildNumericField(Map<String, dynamic> item, int pmCheckListMstId) {
    // Check if should show serial number list instead of dropdown
    if (_shouldShowSerialNumberDropdown(item)) {
      return _buildSerialNumberListField(item, pmCheckListMstId);
    }

    // Simple numeric input (no serial numbers)
    final key = pmCheckListMstId.toString();
    if (!_numericControllers.containsKey(key)) {
      _numericControllers[key] = TextEditingController();
    }

    final controller = _numericControllers[key]!;

    return CustomFormField(
      controller: controller,
      onChanged: (value) {
        setState(() {
          _hasEditsSinceLastSave = true;
          final key = pmCheckListMstId.toString();
          _formValues[key] = {'value': value};
        });
      },
      isRequired: true,
      isEditable: !_isParentFieldEmpty,
      inputType: InputType.number,
      hintText: 'Enter numeric value',
    );
  }

  /// Build serial number list field (new UI with list of serial numbers and text fields)
  Widget _buildSerialNumberListField(Map<String, dynamic> item, int pmCheckListMstId) {
    final checklistDesc = item['checklist_desc']?.toString() ?? '';
    final serialNumbers = _getAvailableSerialNumbers(pmCheckListMstId);
    
    if (serialNumbers.isEmpty) {
      return const SizedBox.shrink();
    }

    // Initialize controllers for each serial number if not exists
    final responseDetails = widget.checklistItem['response_details'] as List?;
    for (final serialNumber in serialNumbers) {
      final controllerKey = '${pmCheckListMstId}_$serialNumber';
      if (!_serialNumberControllers.containsKey(controllerKey)) {
        _serialNumberControllers[controllerKey] = TextEditingController();
        
        // Load existing value if available
        if (responseDetails != null) {
          final matching = responseDetails.where(
            (detail) =>
                detail is Map<String, dynamic> &&
                detail['mfg_serial_no']?.toString() == serialNumber &&
                detail['pm_check_list_mst_id'] == pmCheckListMstId &&
                detail['resp'] != null &&
                detail['resp'].toString().isNotEmpty,
          );
          if (matching.isNotEmpty) {
            final matchingItem = matching.first as Map<String, dynamic>;
            _serialNumberControllers[controllerKey]!.text = matchingItem['resp']?.toString() ?? '';
          }
        }
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title/Header (checklist_desc)
          Text(
            checklistDesc,
            style: const TextStyle(
              color: AppColors.black,
              fontSize: 18,
              fontWeight: FontWeight.w600,
              fontFamily: fontFamilyMontserrat,
            ),
          ),
          const SizedBox(height: 16),
          
          // Serial number list with text fields
          ...serialNumbers.map((serialNumber) {
            final controllerKey = '${pmCheckListMstId}_$serialNumber';
            final controller = _serialNumberControllers[controllerKey]!;
            
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  // Serial number label
                  Expanded(
                    flex: 2,
                    child: Text(
                      serialNumber,
                      style: const TextStyle(
                        color: AppColors.black,
                        fontSize: 16,
                        fontFamily: fontFamilyMontserrat,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Numeric input field
                  Expanded(
                    flex: 1,
                    child: CustomFormField(
                      controller: controller,
                      onChanged: (value) {
                        setState(() {
                          _hasEditsSinceLastSave = true;
                          // Store value in formValues with serial number key
                          final key = pmCheckListMstId.toString();
                          if (!_formValues.containsKey(key)) {
                            _formValues[key] = {};
                          }
                          final serialValues = _formValues[key]?['serialValues'] as Map<String, String>? ?? {};
                          if (value.isEmpty) {
                            serialValues.remove(serialNumber);
                          } else {
                            serialValues[serialNumber] = value;
                          }
                          _formValues[key] = {
                            ..._formValues[key] ?? {},
                            'serialValues': serialValues,
                          };
                        });
                      },
                      isRequired: false,
                      isEditable: !_isParentFieldEmpty,
                      inputType: InputType.number,
                      hintText: '',
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
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

    // Get parent object values
    final parentPmCheckListSiteRespId = widget.checklistItem['pm_check_list_site_resp_id'];
    final parentChecklistRef = widget.checklistItem['checklist_ref']?.toString() ?? 
                               widget.checklistItem['pm_item_type']?.toString() ?? '';
    final parentClOrder = widget.checklistItem['cl_order'];

    // Count how many unique checklist_ref values exist (this tells us how many "batches" have been saved)
    // Each save operation creates entries with the same checklist_ref sequence number for all items
    Set<String> existingChecklistRefs = {};
    for (final detail in updatedResponseDetails) {
      final checklistRef = detail['checklist_ref']?.toString();
      if (checklistRef != null && checklistRef.isNotEmpty) {
        existingChecklistRefs.add(checklistRef);
      }
    }

    // Determine the next sequence number based on existing checklist_ref values
    // Extract numbers from existing checklist_refs like "Earth Pit 1", "Earth Pit 2", etc.
    int nextSequenceNumber = 1;
    if (existingChecklistRefs.isNotEmpty && parentChecklistRef.isNotEmpty) {
      List<int> sequenceNumbers = [];
      for (final ref in existingChecklistRefs) {
        // Try to extract number from checklist_ref (e.g., "Earth Pit 1" -> 1)
        final match = RegExp(r'(\d+)$').firstMatch(ref);
        if (match != null) {
          final num = int.tryParse(match.group(1) ?? '');
          if (num != null) {
            sequenceNumbers.add(num);
          }
        }
      }
      if (sequenceNumbers.isNotEmpty) {
        nextSequenceNumber = sequenceNumbers.reduce((a, b) => a > b ? a : b) + 1;
      } else {
        nextSequenceNumber = existingChecklistRefs.length + 1;
      }
    }

    // Check if should handle multiple sections (need to do this before the loop)
    final shouldHandleMultipleSections = _shouldShowMultipleSections(respDtlChecklistItems);

    // Process each resp_dtl_checklist item
    for (final item in respDtlChecklistItems) {
      final pmCheckListMstId = item['pm_check_list_mst_id'] as int?;
      if (pmCheckListMstId == null) continue;

      final respType = item['resp_type']?.toString() ?? '';

      // Handle multiple sections case (RADIO type with sections)
      if (shouldHandleMultipleSections && respType == 'RADIO') {
        // Handle multiple sections - save all sections at once
        final parentResp = widget.checklistItem['resp'];
        final count = int.tryParse(parentResp?.toString() ?? '0') ?? 0;
        
        for (int sectionIndex = 0; sectionIndex < count; sectionIndex++) {
          final sectionKey = '${pmCheckListMstId}_$sectionIndex';
          final sectionFormValue = _formValues[sectionKey];
          if (sectionFormValue == null) continue;
          
          final valueObj = sectionFormValue['value'];
          if (valueObj == null) continue;
          
          final value = valueObj.toString();
          if (value.isEmpty) continue;
          
          final sectionChecklistRef = _getSectionHeading(sectionIndex);
          
          // Find existing entry with matching checklist_ref and pm_check_list_mst_id
          bool found = false;
          for (int i = 0; i < updatedResponseDetails.length; i++) {
            final detail = updatedResponseDetails[i];
            if (detail['checklist_ref']?.toString() == sectionChecklistRef &&
                detail['pm_check_list_mst_id'] == pmCheckListMstId) {
              // Update existing entry
              updatedResponseDetails[i] = {
                ...detail,
                'resp': value,
              };
              found = true;
              break;
            }
          }
          
          if (!found) {
            // Create new entry from resp_dtl_checklist item
            final newEntry = Map<String, dynamic>.from(item);
            newEntry['resp'] = value;
            newEntry['cl_order'] = item['cl_order'] ?? parentClOrder;
            newEntry['pclsrd_id'] = 0;
            newEntry['checklist_ref'] = sectionChecklistRef;
            newEntry['item_instance_id'] = null;
            newEntry['response_dtl_images'] = null;
            newEntry['pm_check_list_site_resp_id'] = parentPmCheckListSiteRespId;
            
            // Remove mfg_serial_no and nexgen_serial_no if they don't exist in response_details
            final hasSerialNumbers = updatedResponseDetails.any((detail) {
              return detail['mfg_serial_no'] != null || detail['nexgen_serial_no'] != null;
            });
            
            if (!hasSerialNumbers) {
              newEntry.remove('mfg_serial_no');
              newEntry.remove('nexgen_serial_no');
            }
            
            updatedResponseDetails.add(newEntry);
          }
        }
        continue; // Skip to next resp_dtl_checklist item
      }

      // For non-multiple-sections case, use simple key
      final key = pmCheckListMstId.toString();
      final formValue = _formValues[key];
      if (formValue == null) continue;

      if (respType == 'NUMERIC' && _shouldShowSerialNumberDropdown(item)) {
        // NUMERIC with serial numbers - save all serial numbers with their values
        final serialValues = formValue['serialValues'] as Map<String, String>?;
        if (serialValues == null || serialValues.isEmpty) {
          if (mounted) {
            try {
              Toastbar.showErrorToastbar('Please enter values for at least one serial number', context);
            } catch (e) {
              Logger.errorLog('Error showing error toast: $e');
            }
          }
          return;
        }

        // Process each serial number and its value
        for (final entry in serialValues.entries) {
          final serialNumber = entry.key;
          final serialValue = entry.value;
          
          if (serialValue.isEmpty) continue; // Skip empty values

          // Find and update matching entry by mfg_serial_no and pm_check_list_mst_id
          bool found = false;
          for (int i = 0; i < updatedResponseDetails.length; i++) {
            final detail = updatedResponseDetails[i];
            if (detail['mfg_serial_no']?.toString() == serialNumber &&
                detail['pm_check_list_mst_id'] == pmCheckListMstId) {
              // Update existing entry
              updatedResponseDetails[i] = {
                ...detail,
                'resp': serialValue,
              };
              found = true;
              break;
            }
          }

          if (!found) {
            // Find an existing entry with this serial number to copy structure
            Map<String, dynamic>? existingEntryWithSerial;
            for (final detail in updatedResponseDetails) {
              if (detail['mfg_serial_no']?.toString() == serialNumber) {
                existingEntryWithSerial = detail;
                break;
              }
            }

            if (existingEntryWithSerial != null) {
              // Use existing entry structure and update resp
              final newEntry = Map<String, dynamic>.from(existingEntryWithSerial);
              newEntry['resp'] = serialValue;
              newEntry['pm_check_list_mst_id'] = pmCheckListMstId;
              updatedResponseDetails.add(newEntry);
            } else {
              // Create new entry from resp_dtl_checklist item
              final newEntry = Map<String, dynamic>.from(item);
              newEntry['resp'] = serialValue;
              newEntry['mfg_serial_no'] = serialNumber;
              newEntry['nexgen_serial_no'] = serialNumber;
              newEntry['cl_order'] = item['cl_order'] ?? parentClOrder;
              newEntry['pclsrd_id'] = existingEntryWithSerial?['pclsrd_id'] ?? 0;
              newEntry['checklist_ref'] = '$parentChecklistRef $nextSequenceNumber';
              newEntry['item_instance_id'] = null;
              newEntry['response_dtl_images'] = '';
              newEntry['pm_check_list_site_resp_id'] = parentPmCheckListSiteRespId;
              updatedResponseDetails.add(newEntry);
            }
          }
        }
      } else {
        // Other types (RADIO single section, TEXT, DROPDOWN, NUMERIC without serial numbers) - find existing entry with same pm_check_list_mst_id
        // and update resp, or create new entry if not found
        final valueObj = formValue['value'];
        if (valueObj == null) continue;
        
        final value = valueObj.toString();
        if (value.isEmpty) continue;

        bool found = false;
        
        // Find first entry with matching pm_check_list_mst_id that has null or empty resp
        for (int i = 0; i < updatedResponseDetails.length; i++) {
          final detail = updatedResponseDetails[i];
          if (detail['pm_check_list_mst_id'] == pmCheckListMstId &&
              (detail['resp'] == null || detail['resp'].toString().isEmpty)) {
            // Update existing entry with null/empty resp
            updatedResponseDetails[i] = {
              ...detail,
              'resp': value,
            };
            found = true;
            break;
          }
        }

        if (!found) {
          // Create new entry from resp_dtl_checklist item
          final newEntry = Map<String, dynamic>.from(item);
          newEntry['resp'] = value;
          newEntry['cl_order'] = item['cl_order'] ?? parentClOrder;
          newEntry['pclsrd_id'] = 0;
          newEntry['checklist_ref'] = '$parentChecklistRef $nextSequenceNumber';
          newEntry['item_instance_id'] = null;
          newEntry['response_dtl_images'] = null;
          newEntry['pm_check_list_site_resp_id'] = parentPmCheckListSiteRespId;
          
          // Remove mfg_serial_no and nexgen_serial_no if they don't exist in response_details
          final hasSerialNumbers = updatedResponseDetails.any((detail) {
            return detail['mfg_serial_no'] != null || detail['nexgen_serial_no'] != null;
          });
          
          if (!hasSerialNumbers) {
            newEntry.remove('mfg_serial_no');
            newEntry.remove('nexgen_serial_no');
          }
          
          updatedResponseDetails.add(newEntry);
        }
      }
    }

    // Console log the response_details array
    Logger.infoLog('response_details after save: ${jsonEncode(updatedResponseDetails)}');
    print('response_details after save: ${jsonEncode(updatedResponseDetails)}');

    // Update the checklist item
    final updatedItem = Map<String, dynamic>.from(widget.checklistItem);
    updatedItem['response_details'] = updatedResponseDetails;
    widget.onChange(updatedItem);

    // For NUMERIC with serial numbers (e.g. Battery SOH): do not clear form so values stay in text fields.
    // User can edit and save again with current values. Other form types still clear after save.
    final hasSerialNumberFields = respDtlChecklistItems.any((item) =>
        item['resp_type']?.toString() == 'NUMERIC' && _shouldShowSerialNumberDropdown(item));

    if (!hasSerialNumberFields) {
      // Clear form and increment reset counter to force widget rebuild
      setState(() {
        _hasEditsSinceLastSave = false;
        _formValues.clear();
        for (final controller in _textControllers.values) {
          controller.clear();
        }
        for (final controller in _numericControllers.values) {
          controller.clear();
        }
        for (final controller in _serialNumberControllers.values) {
          controller.clear();
        }
        _textControllers.clear();
        _numericControllers.clear();
        _resetCounter++; // Increment to force widgets to rebuild with new keys
      });
    } else {
      setState(() {
        _hasEditsSinceLastSave = false;
      });
    }

    // Show success message
    if (mounted) {
      try {
        Toastbar.showSuccessToastbar('Saved successfully', context);
      } catch (e) {
        Logger.errorLog('Error showing success toast: $e');
      }
    }
  }

  /// Build saved items table
  Widget _buildSavedItemsTable() {
    final responseDetails = widget.checklistItem['response_details'];
    if (responseDetails == null || responseDetails is! List) {
      return const SizedBox.shrink();
    }

    // Hide table if response_details contains items with mfg_serial_no
    final hasMfgSerialNo = responseDetails.any((item) {
      if (item is! Map<String, dynamic>) return false;
      return item['mfg_serial_no'] != null && 
             item['mfg_serial_no'].toString().trim().isNotEmpty;
    });
    
    if (hasMfgSerialNo) {
      return const SizedBox.shrink(); // Hide table when mfg_serial_no exists
    }

    // Filter only items that have been saved (have resp value) and don't have mfg_serial_no
    final savedItems = responseDetails.where((item) {
      if (item is! Map<String, dynamic>) return false;
      final resp = item['resp'];
      final mfgSerialNo = item['mfg_serial_no'];
      final hasSerialNo = mfgSerialNo != null && 
                          mfgSerialNo.toString().trim().isNotEmpty;
      return resp != null && resp.toString().isNotEmpty && !hasSerialNo;
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

    // Group items by checklist_ref (parent identifier like "Earth Pit 1", "Earth Pit 2")
    final Map<String, List<Map<String, dynamic>>> groupedItems = {};
    
    for (final item in savedItems) {
      if (item is! Map<String, dynamic>) continue;
      
      final checklistRef = item['checklist_ref']?.toString() ?? '';
      final pmCheckListMstId = item['pm_check_list_mst_id'] as int?;
      
      // Get checklist name from resp_dtl_checklist (without appending number)
      String checklistName = '';
      if (pmCheckListMstId != null) {
        checklistName = checklistNameMap[pmCheckListMstId] ??
                        item['checklist_desc']?.toString() ??
                        '';
      } else {
        checklistName = item['checklist_desc']?.toString() ?? '';
      }
      
      // Use checklist_ref as the group key (parent identifier)
      // If checklist_ref is empty, use a default group
      final groupKey = checklistRef.isNotEmpty ? checklistRef : 'Other';
      
      if (!groupedItems.containsKey(groupKey)) {
        groupedItems[groupKey] = [];
      }
      
      // Create item with checklist name and value
      final itemWithData = Map<String, dynamic>.from(item);
      itemWithData['_checklist_name'] = checklistName;
      itemWithData['_display_value'] = item['resp']?.toString() ?? '';
      groupedItems[groupKey]!.add(itemWithData);
    }

    // Sort groups by extracting number from checklist_ref for proper ordering
    final sortedGroupKeys = groupedItems.keys.toList()..sort((a, b) {
      // Extract numbers from keys (e.g., "Earth Pit 1" -> 1, "Earth Pit 2" -> 2)
      final matchA = RegExp(r'(\d+)$').firstMatch(a);
      final matchB = RegExp(r'(\d+)$').firstMatch(b);
      final numA = matchA != null ? int.tryParse(matchA.group(1) ?? '') : null;
      final numB = matchB != null ? int.tryParse(matchB.group(1) ?? '') : null;
      
      if (numA != null && numB != null) {
        return numA.compareTo(numB);
      }
      return a.compareTo(b);
    });

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
          // Grouped items - each group has a parent heading and child items
          ...sortedGroupKeys.map((groupKey) {
            final itemsInGroup = groupedItems[groupKey]!;
            
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Parent heading (e.g., "Earth Pit 1")
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 4),
                  child: Text(
                    groupKey,
                    style: const TextStyle(
                      color: AppColors.color555555,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      fontFamily: fontFamilyMontserrat,
                    ),
                  ),
                ),
                // Child items under this parent (indented with dash)
                ...itemsInGroup.map((item) {
                  final checklistName = item['_checklist_name']?.toString() ?? '';
                  final displayValue = item['_display_value']?.toString() ?? '';
                  return _buildTableRow('$checklistName', displayValue, isChild: true);
                }).toList(),
              ],
            );
          }).toList(),
        ],
      ),
    );
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
  Widget _buildTableRow(String checklistName, String value, {bool isChild = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.symmetric(
        horizontal: isChild ? 20 : 12, // Indent child items
        vertical: 8,
      ),
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

        // 2. White box containing resp_dtl_checklist items (form fields) - only show if parent field has value
        if (respDtlChecklistItems.isNotEmpty && !_isParentFieldEmpty)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: AppColors.colorF5F5F5,
            borderRadius: BorderRadius.circular(5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                // Check if should show multiple sections (RADIO type without serial numbers)
                if (_shouldShowMultipleSections(respDtlChecklistItems))
                  _buildMultipleSections(respDtlChecklistItems)
                else
                  // All resp_dtl_checklist fields (original single section)
                  ...respDtlChecklistItems.map((item) => _buildFieldForItem(item)).toList(),
                // Save button: for Battery SOH only, disable when no edits since last save; others always enabled when parent has value
                Builder(
                  builder: (context) {
                    final hasSerialNumberFields = respDtlChecklistItems.any((item) =>
                        item['resp_type']?.toString() == 'NUMERIC' && _shouldShowSerialNumberDropdown(item));
                    final isSaveDisabled = _isParentFieldEmpty ||
                        (hasSerialNumberFields && !_hasEditsSinceLastSave);
                    return Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton(
                        onPressed: isSaveDisabled ? null : _onSaveAllEntries,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isSaveDisabled
                              ? Colors.grey.shade400
                              : AppColors.primaryGreen,
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 20),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(5),
                          ),
                          minimumSize: const Size(0, 36),
                        ),
                        child: Text(
                          _getSaveButtonText(),
                          style: TextStyle(
                            color: isSaveDisabled ? Colors.grey : Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            fontFamily: fontFamilyMontserrat,
                          ),
                        ),
                      ),
                    );
                  },
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
