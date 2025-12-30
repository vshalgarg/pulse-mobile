import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';
import '../constants/constants_strings.dart';
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
  // Parent field controller (for "Number of Battery Modules")
  final TextEditingController _parentNumericController = TextEditingController();

  // For CASE 1: Battery (NUMERIC + response_details with mfg_serial_no)
  String? _selectedSerialNumber;
  final TextEditingController _childNumericController = TextEditingController();

  // For CASE 2: Earthing (RADIO + No response_details initially)
  // Track selected radio value for each resp_dtl_checklist item
  Map<int, String?> _selectedRadioValues = {};

  @override
  void initState() {
    super.initState();
    _initializeFromExistingData();
  }

  @override
  void dispose() {
    _parentNumericController.dispose();
    _childNumericController.dispose();
    super.dispose();
  }

  /// Initialize form from existing data
  void _initializeFromExistingData() {
    // Initialize parent resp value if exists
    final parentResp = widget.checklistItem['resp'];
    if (parentResp != null) {
      _parentNumericController.text = parentResp.toString();
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

  /// Get resp_dtl_checklist first item (for backward compatibility)
  Map<String, dynamic>? get _respDtlChecklistItem {
    final items = _respDtlChecklistItems;
    return items.isNotEmpty ? items[0] : null;
  }

  /// Determine which case we're handling based on resp_dtl_checklist
  bool get _isCase1Battery {
    final respDtlChecklistItem = _respDtlChecklistItem;
    if (respDtlChecklistItem == null) return false;
    return respDtlChecklistItem['resp_type'] == 'NUMERIC';
  }

  bool get _isCase2Earthing {
    final respDtlChecklistItem = _respDtlChecklistItem;
    if (respDtlChecklistItem == null) return false;
    return respDtlChecklistItem['resp_type'] == 'RADIO';
  }

  /// Get all mfg_serial_no values from response_details (CASE 1)
  List<String> get _availableSerialNumbers {
    final responseDetails = widget.checklistItem['response_details'];
    if (responseDetails == null || responseDetails is! List) {
      return [];
    }

    return responseDetails
        .where((item) => item is Map<String, dynamic>)
        .map((item) => item['mfg_serial_no']?.toString())
        .where((serial) => serial != null && serial.isNotEmpty)
        .toList()
        .cast<String>();
  }

  /// Get parent resp value as count (CASE 2)
  int? get _maxAllowedEntries {
    final resp = widget.checklistItem['resp'];
    if (resp == null || resp.toString().isEmpty) return null;
    return int.tryParse(resp.toString());
  }

  /// Get current response_details count for a specific checklist item (CASE 2)
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

  /// Check if we can add more entries for a specific checklist item (CASE 2)
  bool _canAddMoreEntriesForChecklist(int pmCheckListMstId) {
    final maxEntries = _maxAllowedEntries;
    if (maxEntries == null || maxEntries == 0) {
      // If parent resp is null/0, allow unlimited entries
      return true;
    }
    return _getCurrentEntriesCountForChecklist(pmCheckListMstId) < maxEntries;
  }

  /// Handle parent field value change
  void _onParentValueChanged(String value) {
    final updatedItem = Map<String, dynamic>.from(widget.checklistItem);
    updatedItem['resp'] = value.isEmpty ? null : value;
    widget.onChange(updatedItem);
  }

  /// Handle CASE 1: Battery - Serial number selection
  void _onSerialNumberSelected(String? serialNumber) {
    setState(() {
      _selectedSerialNumber = serialNumber;
      // Load existing saved value if available
      if (serialNumber != null) {
        final responseDetails = widget.checklistItem['response_details'];
        if (responseDetails is List) {
          final matchingItem = responseDetails.firstWhere(
            (item) => item is Map<String, dynamic> &&
                item['mfg_serial_no']?.toString() == serialNumber &&
                item['resp'] != null &&
                item['resp'].toString().isNotEmpty,
            orElse: () => null,
          );
          if (matchingItem != null && matchingItem is Map<String, dynamic>) {
            _childNumericController.text = matchingItem['resp']?.toString() ?? '';
          } else {
            _childNumericController.clear();
          }
        }
      }
    });
  }

  /// Handle CASE 1: Battery - Save button clicked
  void _onSaveBatteryEntry() {
    if (_selectedSerialNumber == null || _childNumericController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a serial number and enter a value'),
          backgroundColor: AppColors.errorColor,
        ),
      );
      return;
    }

    final responseDetails = widget.checklistItem['response_details'];
    if (responseDetails == null || responseDetails is! List) return;

    // Find and update the matching item
    final updatedResponseDetails = List<Map<String, dynamic>>.from(
      responseDetails.map((item) {
        if (item is Map<String, dynamic> &&
            item['mfg_serial_no']?.toString() == _selectedSerialNumber) {
          final updatedItem = Map<String, dynamic>.from(item);
          updatedItem['resp'] = _childNumericController.text;
          return updatedItem;
        }
        return item is Map<String, dynamic>
            ? Map<String, dynamic>.from(item)
            : item;
      }),
    );

    // Update the checklist item
    final updatedItem = Map<String, dynamic>.from(widget.checklistItem);
    updatedItem['response_details'] = updatedResponseDetails;
    widget.onChange(updatedItem);

    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Saved successfully'),
        backgroundColor: AppColors.primaryGreen,
      ),
    );

    // Clear form
    setState(() {
      _selectedSerialNumber = null;
      _childNumericController.clear();
    });
  }

  /// Handle CASE 2: Earthing - Radio selection for a specific checklist item
  void _onRadioSelectedForChecklist(int pmCheckListMstId, String? value) {
    if (value == null) return;

    setState(() {
      _selectedRadioValues[pmCheckListMstId] = value;
    });
  }

  /// Handle CASE 2: Earthing - Save button clicked for a specific checklist item
  void _onSaveEarthingEntry(int pmCheckListMstId) {
    final selectedValue = _selectedRadioValues[pmCheckListMstId];
    if (selectedValue == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an option'),
          backgroundColor: AppColors.errorColor,
        ),
      );
      return;
    }

    if (!_canAddMoreEntriesForChecklist(pmCheckListMstId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Maximum entries reached for this checklist'),
          backgroundColor: AppColors.errorColor,
        ),
      );
      return;
    }

    // Find the resp_dtl_checklist item
    final respDtlChecklistItem = _respDtlChecklistItems.firstWhere(
      (item) => item['pm_check_list_mst_id'] == pmCheckListMstId,
      orElse: () => {},
    );

    if (respDtlChecklistItem.isEmpty) return;

    // Clone the resp_dtl_checklist item
    final newEntry = Map<String, dynamic>.from(respDtlChecklistItem);
    newEntry['resp'] = selectedValue;

    // Get or create response_details array
    final responseDetails = widget.checklistItem['response_details'];
    List<Map<String, dynamic>> updatedResponseDetails;
    if (responseDetails == null || responseDetails is! List) {
      updatedResponseDetails = [newEntry];
    } else {
      updatedResponseDetails = List<Map<String, dynamic>>.from(responseDetails);
      updatedResponseDetails.add(newEntry);
    }

    // Update the checklist item
    final updatedItem = Map<String, dynamic>.from(widget.checklistItem);
    updatedItem['response_details'] = updatedResponseDetails;

    // Reset radio selection
    setState(() {
      _selectedRadioValues[pmCheckListMstId] = null;
    });

    widget.onChange(updatedItem);

    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Saved successfully'),
        backgroundColor: AppColors.primaryGreen,
      ),
    );
  }

  /// Build parent field (e.g., "Number of Battery Modules") - OUTSIDE white box
  Widget _buildParentField() {
    final checklistDesc = widget.checklistItem['checklist_desc']?.toString() ?? '';
    final respType = widget.checklistItem['resp_type']?.toString() ?? '';

    // Only show numeric input if resp_type is NUMERIC
    if (respType == 'NUMERIC') {
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Label - BLACK TEXT (outside white box)
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: checklistDesc,
                    style: const TextStyle(
                      color: AppColors.black, // Black text
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

            // Numeric input
            CustomFormField(
              controller: _parentNumericController,
              onChanged: _onParentValueChanged,
              isRequired: true,
              inputType: InputType.number,
              hintText: 'Enter numeric value',
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  /// Build CASE 1: Battery form (NUMERIC + response_details with mfg_serial_no)
  Widget _buildCase1BatteryForm() {
    final respDtlChecklistItem = _respDtlChecklistItem;
    if (respDtlChecklistItem == null) return const SizedBox.shrink();

    final label = respDtlChecklistItem['checklist_desc']?.toString() ?? '';
    final serialNumbers = _availableSerialNumbers;

    return Column(
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

        // Dropdown for serial numbers
        if (serialNumbers.isNotEmpty)
          CustomDropdown(
            items: serialNumbers,
            initialValue: _selectedSerialNumber,
            onChanged: _onSerialNumberSelected,
          ),
        const SizedBox(height: 12),

        // Numeric input
        CustomFormField(
          controller: _childNumericController,
          isRequired: true,
          inputType: InputType.number,
          hintText: 'Enter numeric value',
        ),
        const SizedBox(height: 12),

        // Save button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _onSaveBatteryEntry,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(5),
              ),
            ),
            child: const Text(
              'Save',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                fontFamily: fontFamilyMontserrat,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Build CASE 2: Earthing form for a single checklist item
  Widget _buildEarthingFormForItem(Map<String, dynamic> checklistItem) {
    final pmCheckListMstId = checklistItem['pm_check_list_mst_id'] as int?;
    if (pmCheckListMstId == null) return const SizedBox.shrink();

    final label = checklistItem['checklist_desc']?.toString() ?? '';
    final respTypeValueMap = checklistItem['resp_type_value_map'];

    // Parse radio options from resp_type_value_map
    Map<String, dynamic> valueMap = {};
    if (respTypeValueMap is Map<String, dynamic>) {
      valueMap = respTypeValueMap;
    } else if (respTypeValueMap is String) {
      try {
        valueMap = jsonDecode(respTypeValueMap) as Map<String, dynamic>;
      } catch (e) {
        // Fallback
        valueMap = {'OK': 'OK', 'Not Ok': 'Not Ok'};
      }
    }

    final canAddMore = _canAddMoreEntriesForChecklist(pmCheckListMstId);
    final maxEntries = _maxAllowedEntries;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label
          Text(
            label,
            style: const TextStyle(
              color: AppColors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
              fontFamily: fontFamilyMontserrat,
            ),
          ),
          const SizedBox(height: 8),

          // Radio buttons
          if (canAddMore)
            CustomRadioButton(
              options: valueMap.entries.map((entry) => OptionItem(
                label: entry.key,
                value: entry.value.toString(),
              )).toList(),
              initialValue: _selectedRadioValues[pmCheckListMstId],
              onChanged: (value) => _onRadioSelectedForChecklist(pmCheckListMstId, value),
              isRequired: true,
            )
          else if (maxEntries != null && maxEntries > 0)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.colorF5F5F5,
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                'Maximum entries reached (${maxEntries})',
                style: const TextStyle(
                  color: AppColors.color555555,
                  fontSize: 14,
                  fontFamily: fontFamilyMontserrat,
                ),
              ),
            ),

          // Save button
          if (canAddMore && _selectedRadioValues[pmCheckListMstId] != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _onSaveEarthingEntry(pmCheckListMstId),
                icon: const Icon(Icons.save, color: Colors.white),
                label: const Text(
                  'Save',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    fontFamily: fontFamilyMontserrat,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Build CASE 2: Earthing form (RADIO + No response_details initially)
  Widget _buildCase2EarthingForm() {
    final respDtlChecklistItems = _respDtlChecklistItems;
    if (respDtlChecklistItems.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: respDtlChecklistItems.map((item) => _buildEarthingFormForItem(item)).toList(),
    );
  }

  /// Build saved items table - Only shows items with saved resp values (without outer container)
  Widget _buildSavedItemsTableContent() {
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Table header
        Row(
          children: [
            Expanded(
              child: _buildTableHeaderCell('Checklist Name'),
            ),
            Expanded(
              child: _buildTableHeaderCell('Value'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Table rows - Only show saved items
        ...savedItems.map((item) {
          if (item is! Map<String, dynamic>) return const SizedBox.shrink();

          // Get checklist name from pm_check_list_mst_id
          final pmCheckListMstId = item['pm_check_list_mst_id'] as int?;
          final checklistName = pmCheckListMstId != null
              ? (checklistNameMap[pmCheckListMstId] ?? item['checklist_desc']?.toString() ?? '')
              : (item['checklist_desc']?.toString() ?? '');

          // Get the value to display
          String displayValue = '';
          if (_isCase1Battery) {
            // For Battery: Show the resp value (numeric value saved)
            displayValue = item['resp']?.toString() ?? '';
          } else if (_isCase2Earthing) {
            // For Earthing: Show the resp value (radio selection)
            displayValue = item['resp']?.toString() ?? '';
          }

          return _buildTableRow(checklistName, displayValue);
        }).toList(),
      ],
    );
  }

  /// Build saved items table in separate white box
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

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.colorF5F5F5, // Dull white background
        borderRadius: BorderRadius.circular(5),
      ),
      child: _buildSavedItemsTableContent(),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Parent field OUTSIDE white box (e.g., "Number of Battery Modules")
        _buildParentField(),

        // 2. First white box containing resp_dtl_checklist items (form fields only)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.colorF5F5F5, // Dull white background
            borderRadius: BorderRadius.circular(5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Child fields from resp_dtl_checklist
              if (_isCase1Battery)
                _buildCase1BatteryForm()
              else if (_isCase2Earthing)
                _buildCase2EarthingForm(),
            ],
          ),
        ),

        // 3. Second white box containing saved items table (separate from form fields)
        _buildSavedItemsTable(),
      ],
    );
  }
}
