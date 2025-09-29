import 'dart:convert';
import 'package:flutter/material.dart';
import 'cm_custom_widget.dart';

class ChecklistPreviewWidget extends StatefulWidget {
  final String equipmentType;
  final Map<String, dynamic> checklistData;
  final String? entityId;
  final Function(List<dynamic>)? onChecklistDataChanged;

  const ChecklistPreviewWidget({
    super.key,
    required this.equipmentType,
    required this.checklistData,
    this.entityId,
    this.onChecklistDataChanged,
  });

  @override
  State<ChecklistPreviewWidget> createState() => _ChecklistPreviewWidgetState();
}

class _ChecklistPreviewWidgetState extends State<ChecklistPreviewWidget> {
  late List<Map<String, dynamic>> _checklistItems;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _initializeChecklistData();
  }

  @override
  void didUpdateWidget(ChecklistPreviewWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-initialize if checklistData has changed
    if (oldWidget.checklistData != widget.checklistData || oldWidget.equipmentType != widget.equipmentType) {
      _initializeChecklistData();
    }
  }


  void _initializeChecklistData() {
    try {
      final data = widget.checklistData[widget.equipmentType] as List<dynamic>? ?? [];
      
      // Convert the data to the format expected by pm_custom_widget
      _checklistItems = data.map((item) {
        final Map<String, dynamic> pmItem = Map<String, dynamic>.from(item);
        
        // Parse resp_type_value_map for radio and dropdown options
        if (pmItem['resp_type'] == 'RADIO' || pmItem['resp_type'] == 'DROPDOWN') {
          final valueMapStr = pmItem['resp_type_value_map']?.toString();
          if (valueMapStr != null && valueMapStr.isNotEmpty) {
            try {
              final valueMap = jsonDecode(valueMapStr) as Map<String, dynamic>;
              pmItem['resp_type_value_map'] = valueMap;
            } catch (e) {
              print('Error parsing resp_type_value_map: $e');
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
          // Header
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
                          
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16.0),
                            child: PMCustomWidget(
                              key: ValueKey('checklist_item_${checklistItem['item_type_id']}_$index'),
                              pmItem: checklistItem,
                              readonlyFields: [], // No readonly fields for corrective maintenance
                              onValueChanged: (updatedItem) {
                                _onItemChanged(index, updatedItem);
                              },
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
