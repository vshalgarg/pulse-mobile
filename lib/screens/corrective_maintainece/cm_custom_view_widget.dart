import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../constants/constants_strings.dart';
import '../../commonWidgets/custom_image_upload_field.dart';
import '../../commonWidgets/custom_file_upload_new.dart';
import '../../commonWidgets/custom_form_field.dart';

class CMCustomWidgetView extends StatelessWidget {
  final Map<String, dynamic> pmItem;
  final Map<String, dynamic> originalCmImpactedItemMap;

  const CMCustomWidgetView({
    super.key,
    required this.pmItem,
    required this.originalCmImpactedItemMap,
  });

  Map<String, String> _getFieldNamesFromChildItems() {
    final childItems = pmItem['childitemData'] as List<dynamic>? ?? [];
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

  Widget _buildFieldByType(String respType) {
    switch (respType) {
      case 'TEXT':
        return _buildTextField();
      case 'DROPDOWN':
        return _buildDropdownField();
      case 'RADIO':
        return _buildRadioField();
      case 'REMARKS':
        return _buildRemarksField();
      case 'IMAGE':
        return _buildImageField();
      case 'FILE':
        return _buildFileField();
      case 'DYNAMIC_DROPDOWN':
        return _buildDynamicDropdownField();
      case 'MULTI_DYNAMIC_DROPDOWN':
        return _buildMultiDynamicDropdownField();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildTextField() {
    final respValue = pmItem['resp']?.toString() ?? '';
    final checklistDesc = pmItem['checklist_desc']?.toString() ?? '';
    final isMandatory = pmItem['is_mandatory'] == true;
    
    return CustomFormField(
      label: checklistDesc,
      initialValue: respValue.isEmpty ? 'No value provided' : respValue,
      isRequired: isMandatory,
      isEditable: false,
    );
  }

  Widget _buildDropdownField() {
    final respValue = pmItem['resp']?.toString() ?? '';
    final checklistDesc = pmItem['checklist_desc']?.toString() ?? '';
    final isMandatory = pmItem['is_mandatory'] == true;
    
    return CustomFormField(
      label: checklistDesc,
      initialValue: respValue.isEmpty ? 'No value selected' : respValue,
      isRequired: isMandatory,
      isEditable: false,
    );
  }

  Widget _buildRadioField() {
    final respValue = pmItem['resp']?.toString() ?? '';
    final checklistDesc = pmItem['checklist_desc']?.toString() ?? '';
    final isMandatory = pmItem['is_mandatory'] == true;
    
    return CustomFormField(
      label: checklistDesc,
      initialValue: respValue.isEmpty ? 'No option selected' : respValue,
      isRequired: isMandatory,
      isEditable: false,
    );
  }

  Widget _buildRemarksField() {
    final respValue = pmItem['resp']?.toString() ?? '';
    final checklistDesc = pmItem['checklist_desc']?.toString() ?? '';
    final isMandatory = pmItem['is_mandatory'] == true;
    
    return CustomFormField(
      label: checklistDesc,
      initialValue: respValue.isEmpty ? 'No remarks provided' : respValue,
      isRequired: isMandatory,
      isEditable: false,
    );
  }

  Widget _buildImageField() {
    final respValue = pmItem['resp']?.toString() ?? '';
    final checklistDesc = pmItem['checklist_desc']?.toString() ?? '';
    final isMandatory = pmItem['is_mandatory'] == true;
    
    return ImageUploadField(
      label: checklistDesc,
      isRequired: isMandatory,
      isDisabled: true,
      externalImageUrl: respValue.isNotEmpty ? respValue : null,
      onImageSelected: (file) {}, // No-op for view mode
    );
  }

  Widget _buildFileField() {
    final respValue = pmItem['resp']?.toString() ?? '';
    final checklistDesc = pmItem['checklist_desc']?.toString() ?? '';
    final isMandatory = pmItem['is_mandatory'] == true;
    List<File> files = [];
    
    if (respValue.isNotEmpty) {
      try {
        // Try to parse as JSON array of file paths
        final List<dynamic> filePaths = jsonDecode(respValue);
        files = filePaths.map((path) => File(path.toString())).toList();
      } catch (e) {
        // If not JSON, treat as single file path
        files = [File(respValue)];
      }
    }

    return CustomFileUploadNew(
      label: checklistDesc,
      isRequired: isMandatory,
      isDisabled: true,
      uploadedFiles: files,
      onFileSelected: (file) {}, // No-op for view mode
      onFileDeleted: (file) {}, // No-op for view mode
    );
  }

  Widget _buildDynamicDropdownField() {
    // Get sub_item_type from pmItem
    final subItemType = pmItem['sub_item_type']?.toString() ?? '';

    // Get the list of items from originalCmImpactedItemMap using sub_item_type as key
    List<Map<String, dynamic>> selectedItems = [];
    if (originalCmImpactedItemMap.containsKey(subItemType)) {
      final items = originalCmImpactedItemMap[subItemType] as List<dynamic>? ?? [];
      selectedItems = items.map((item) => Map<String, dynamic>.from(item)).toList();
    }
    
    // Get all unique keys from selectedItems, excluding null values
    Set<String> allKeys = {};
    for (var item in selectedItems) {
      item.forEach((key, value) {
        if (value != null && key != 'nexgen_serial_no') {
          allKeys.add(key);
        }
      });
    }

    // Convert to list and sort for consistent display
    List<String> columnKeys = allKeys.toList()..sort();
    
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFE6F5EF).withOpacity(0.3)
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            
            // Child fields - show individual values for each selected item

            // Data table
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: selectedItems.isEmpty 
                ? Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'No data available for DYNAMIC_DROPDOWN',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  )
                : DataTable(
                    columnSpacing: 20,
                    horizontalMargin: 12,
                    columns: [
                      ...columnKeys.map((key) =>
                        DataColumn(
                          label: Text(key == 'mfg_serial_no' ? 'Serial Number' : key.toUpperCase(), style: TextStyle(fontWeight: FontWeight.bold)),
                        )
                      ),
                    ],
                    rows: selectedItems.map((item) {
                      return DataRow(
                        cells: [
                          ...columnKeys.map((key) {
                            final value = item[key]?.toString() ?? '';
                            return DataCell(Text(value.isEmpty ? 'NA' : value));
                          }),
                        ],
                      );
                    }).toList(),
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMultiDynamicDropdownField() {
    final subItemType = pmItem['sub_item_type']?.toString() ?? '';
    List<Map<String, dynamic>> selectedItems = [];
    
    // Get selected items from originalCmImpactedItemMap using sub_item_type
    if (originalCmImpactedItemMap.containsKey(subItemType)) {
      final options = originalCmImpactedItemMap[subItemType] as List<dynamic>? ?? [];
      selectedItems = options.map((item) => Map<String, dynamic>.from(item)).toList();
    }

    final checklistDesc = pmItem['checklist_desc']?.toString() ?? '';
    final isMandatory = pmItem['is_mandatory'] == true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: checklistDesc,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                  fontFamily: fontFamilyMontserrat,
                ),
              ),
              if (isMandatory)
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
        
        const SizedBox(height: 12),
        
        // Multi-select dropdown (disabled)
        Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  selectedItems.isEmpty 
                    ? 'No items selected'
                    : '${selectedItems.length} item(s) selected',
                  style: TextStyle(
                    fontSize: 16,
                    color: selectedItems.isEmpty ? Colors.grey.shade500 : Colors.black87,
                    fontFamily: fontFamilyMontserrat,
                  ),
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Selected items display
        if (selectedItems.isNotEmpty) ...[
          ...selectedItems.map((item) => Container(
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
                Icon(
                  Icons.check_circle_outline,
                  size: 16,
                  color: Colors.green.shade600,
                ),
              ],
            ),
          )),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final respType = pmItem['resp_type']?.toString() ?? '';
    final isMandatory = pmItem['is_mandatory'] == true;
    final checklistDesc = pmItem['checklist_desc']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Field based on resp_type
          if (checklistDesc.toLowerCase().contains('remarks'))
            _buildRemarksField()
          else
            _buildFieldByType(respType),
        ],
      ),
    );
  }
}
