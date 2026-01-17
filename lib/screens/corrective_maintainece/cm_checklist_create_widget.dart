import 'dart:convert';
import 'package:flutter/material.dart';
import 'cm_custom_widget.dart';

class ChecklistCreateWidget extends StatefulWidget {
  final String equipmentType;
  final List<dynamic> checklistItemsByApi;
  final String? entityId;
  final Function(List<dynamic>)? onChecklistDataChanged;
  final Function (List<Map<String, dynamic>>) onImpactedItemListChanged;
  final List<Map<String, dynamic>> cmImpactedItemList;
  final Map<String, dynamic> originalCmImpactedItemMap;
  final Function(List<Map<String, dynamic>>, String) onMultiDynamicDropdownValueChanged;
  final bool isEditable;

  const ChecklistCreateWidget({
    super.key,
    required this.equipmentType,
    required this.checklistItemsByApi,
    this.entityId,
    this.onChecklistDataChanged,
    required this.onImpactedItemListChanged,
    required this.cmImpactedItemList,
    required this.originalCmImpactedItemMap,
    required this.onMultiDynamicDropdownValueChanged,
    this.isEditable = true,
  });

  @override
  State<ChecklistCreateWidget> createState() => _ChecklistCreateWidgetState();
}

class _ChecklistCreateWidgetState extends State<ChecklistCreateWidget> {
  late List<Map<String, dynamic>> _checklistItems;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _initializeChecklistData();
  }

  @override
  void didUpdateWidget(ChecklistCreateWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-initialize if checklistData has changed
    if (oldWidget.checklistItemsByApi != widget.checklistItemsByApi || oldWidget.equipmentType != widget.equipmentType) {
      setState(() {
        _initializeChecklistData();
      });
    }
  }

  void _initializeChecklistData() {
    try {
      final data = widget.checklistItemsByApi;

      // Convert the data to the format expected by pm_custom_widget
      _checklistItems = data.map((item) {
        final Map<String, dynamic> pmItem = Map<String, dynamic>.from(item);

        // Debug logging for dependent_elements (for all types that can have them)
        if (pmItem['resp_type'] == 'CHECKBOX' || pmItem['resp_type'] == 'CHECKBOX_NUMERIC' || 
            pmItem['resp_type'] == 'NUMERIC' || pmItem['resp_type'] == 'TEXT') {
          print('[CM] _initializeChecklistData - resp_type: ${pmItem['resp_type']}, checklist_desc: ${pmItem['checklist_desc']}');
          print('[CM] _initializeChecklistData - item keys: ${item.keys.toList()}');
          print('[CM] _initializeChecklistData - item[dependent_elements]: ${item['dependent_elements']}');
          print('[CM] _initializeChecklistData - item[dependentElements]: ${item['dependentElements']}');
          print('[CM] _initializeChecklistData - pmItem keys: ${pmItem.keys.toList()}');
          print('[CM] _initializeChecklistData - pmItem[dependent_elements]: ${pmItem['dependent_elements']}');
        }

        // Ensure dependent_elements is preserved (try both field names) - for ALL field types
        if (item['dependent_elements'] != null) {
          pmItem['dependent_elements'] = item['dependent_elements'];
          print('[CM] _initializeChecklistData - Preserved dependent_elements for ${pmItem['resp_type']}: ${pmItem['dependent_elements']}');
        }
        if (item['dependentElements'] != null && pmItem['dependentElements'] == null) {
          pmItem['dependentElements'] = item['dependentElements'];
        }
        
        // Ensure impacted_item_check_list is preserved (replaces childitemData)
        if (item['impacted_item_check_list'] != null) {
          pmItem['impacted_item_check_list'] = item['impacted_item_check_list'];
          // Also keep childitemData for backward compatibility
          if (pmItem['childitemData'] == null) {
            pmItem['childitemData'] = item['impacted_item_check_list'];
          }
        } else if (item['childitemData'] != null) {
          // Fallback: if impacted_item_check_list doesn't exist, use childitemData
          pmItem['childitemData'] = item['childitemData'];
        }

        // Parse resp_type_value_map for radio and dropdown options
        if (pmItem['resp_type'] == 'RADIO' || pmItem['resp_type'] == 'DROPDOWN') {
          final valueMapStr = pmItem['resp_type_value_map']?.toString();
          if (valueMapStr != null && valueMapStr.isNotEmpty) {
            try {
              final valueMap = jsonDecode(valueMapStr) as Map<String, dynamic>;
              pmItem['resp_type_value_map'] = valueMap;
            } catch (e) {
              // Set default values if parsing fails
              if (pmItem['resp_type'] == 'RADIO') {
                pmItem['resp_type_value_map'] = {"OK": "OK", "Not OK": "Not OK"};
              } else if (pmItem['resp_type'] == 'DROPDOWN') {
                pmItem['resp_type_value_map'] = {"OK": "OK", "Not OK": "Not OK"};
              }
            }
          }
        }

        // Add required fields for pm_custom_widget compatibility
        pmItem['pm_check_list_site_resp_id'] = pmItem['item_type_id'] ?? DateTime.now().millisecondsSinceEpoch;
        pmItem['site_audit_sch_id'] = widget.entityId;

        // Final check for dependent_elements
        if ((pmItem['resp_type'] == 'CHECKBOX' || pmItem['resp_type'] == 'CHECKBOX_NUMERIC') && 
            pmItem['dependent_elements'] != null) {
          print('[CM] _initializeChecklistData - Final pmItem[dependent_elements]: ${pmItem['dependent_elements']}');
        }

        return pmItem;
      }).toList();

      // Sort by cl_order
      _checklistItems.sort((a, b) {
        final orderA = a['cl_order'] as int? ?? 0;
        final orderB = b['cl_order'] as int? ?? 0;
        return orderA.compareTo(orderB);
      });

    } catch (e) {
    }
  }

  void _onItemChanged(int index, Map<String, dynamic> updatedItem) {
    if (mounted) {
      setState(() {
        _checklistItems[index] = updatedItem;
      });
      widget.onChecklistDataChanged?.call(_checklistItems);
    }
  }

  void _toggleExpansion() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.withOpacity(0.5)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header  //Checklist Edit Mode
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF00695C),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: _toggleExpansion,
                    child: Text(
                      widget.equipmentType,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _toggleExpansion,
                  icon: Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),

          // Content
          if (_isExpanded)
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFE6F5EF).withOpacity(0.3), // 30% opacity of #e6f5ef
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(8),
                  bottomRight: Radius.circular(8),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                        ..._checklistItems.asMap().entries.map((entry) {
                          final index = entry.key;
                          final checklistItem = entry.value;

                          // If not editable (edit/view mode), add all checklist descriptions to readonlyFields
                          final readonlyFields = !widget.isEditable
                              ? _checklistItems
                                  .map((item) => item['checklist_desc']?.toString() ?? '')
                                  .where((desc) => desc.isNotEmpty)
                                  .toList()
                              : <String>[];

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16.0),
                            child: CMCustomWidget(
                              key: ValueKey('checklist_item_${checklistItem['item_type_id']}_$index'),
                              pmItem: checklistItem,
                              readonlyFields: readonlyFields,
                              onValueChanged: (updatedItem) {
                                _onItemChanged(index, updatedItem);
                              },
                              onImpactedItemListChanged: widget.onImpactedItemListChanged,
                              originalCmImpactedItemMap: widget.originalCmImpactedItemMap,
                              cmImpactedItemList: widget.cmImpactedItemList,
                              onMultiDynamicDropdownValueChanged: widget.onMultiDynamicDropdownValueChanged,
                            ),
                          );
                        }).toList(),
                    ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}