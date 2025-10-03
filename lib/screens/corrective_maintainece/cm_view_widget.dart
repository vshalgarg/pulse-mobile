import 'package:flutter/material.dart';
import 'cm_custom_view_widget.dart';

class ChecklistCreateWidgetView extends StatefulWidget {
  final String equipmentType;
  final List<dynamic> checklistItemsByApi;
  final String? entityId;
  final Map<String, dynamic> originalCmImpactedItemMap;

  const ChecklistCreateWidgetView({
    super.key,
    required this.equipmentType,
    required this.checklistItemsByApi,
    this.entityId,
    required this.originalCmImpactedItemMap,
  });

  @override
  State<ChecklistCreateWidgetView> createState() => _ChecklistCreateWidgetViewState();
}

class _ChecklistCreateWidgetViewState extends State<ChecklistCreateWidgetView> {
  late List<Map<String, dynamic>> _checklistItems;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _initializeChecklistData();
  }

  @override
  void didUpdateWidget(ChecklistCreateWidgetView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-initialize if checklistData has changed
    if (oldWidget.checklistItemsByApi != widget.checklistItemsByApi || oldWidget.equipmentType != widget.equipmentType) {
      setState(() {
        _initializeChecklistData();
      });
    }
  }

  void _initializeChecklistData() {
    _checklistItems = widget.checklistItemsByApi
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.withOpacity(0.5)),
        borderRadius: BorderRadius.circular(8),
          color: const Color(0xFFE6F5EF).withOpacity(0.2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            child: Container(
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
                    child: Text(
                      widget.equipmentType,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                  Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.white,
                  ),
                ],
              ),
            ),
          ),
          
          if (_isExpanded)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: _checklistItems.asMap().entries.map((entry) {
                  final index = entry.key;
                  final checklistItem = entry.value;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: CMCustomWidgetView(
                      key: ValueKey('checklist_item_${checklistItem['item_type_id']}_$index'),
                      pmItem: checklistItem,
                      originalCmImpactedItemMap: widget.originalCmImpactedItemMap,
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}
