import 'package:app/commonWidgets/custom_form_appbar.dart';
import 'package:app/commonWidgets/custom_submit_button_v2.dart';
import 'package:app/commonWidgets/custom_dialogs/unsaved_changes_dialog.dart';
import 'package:app/constants/app_colors.dart';
import 'package:app/constants/app_images.dart';
import 'package:app/enum/corrective_maintenance_screen_mode_enum.dart';
import 'package:app/models/all_site_model.dart';
import 'package:app/routes/route_generator.dart';
import 'package:app/utils/logger.dart';
import 'package:app/utils/toastbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class IncidentChecklistScreen extends StatefulWidget {
  final AllSiteModel siteData;
  final CMScreenModeEnum mode;
  final Map<String, List<Map<String, dynamic>>> checklistData;
  final Map<String, List<int>>? existingSelections; // parentType -> [iclm_ids] for edit mode
  final BuildContext? parentContext;

  const IncidentChecklistScreen({
    super.key,
    required this.siteData,
    required this.mode,
    required this.checklistData,
    this.existingSelections,
    this.parentContext,
  });

  @override
  State<IncidentChecklistScreen> createState() => _IncidentChecklistScreenState();
}

class _IncidentChecklistScreenState extends State<IncidentChecklistScreen> {
  // Selected parent node (only one can be selected at a time)
  String? _selectedParentNode;
  
  // Selected child checklist IDs (iclm_id values) for the selected parent
  Set<int> _selectedChildChecklistIds = {};
  
  // Expanded state for each parent node
  Map<String, bool> _expandedStates = {};
  
  // Form change tracking
  bool _hasFormDataChanges = false;
  
  // Check if mode is view (read-only)
  bool get _isViewMode => widget.mode == CMScreenModeEnum.view;

  @override
  void initState() {
    super.initState();
    _initializeExpandedStates();
    _loadExistingSelections();
  }

  void _initializeExpandedStates() {
    // Initialize all parent nodes as collapsed
    for (final parentKey in widget.checklistData.keys) {
      _expandedStates[parentKey] = false;
    }
  }

  void _loadExistingSelections() {
    if (widget.existingSelections != null && widget.existingSelections!.isNotEmpty) {
      // Load existing selections from edit mode
      final existingParent = widget.existingSelections!.keys.first;
      final existingIds = widget.existingSelections![existingParent] ?? [];
      
      setState(() {
        _selectedParentNode = existingParent;
        _selectedChildChecklistIds = Set<int>.from(existingIds);
        _expandedStates[existingParent] = true;
      });
    }
  }

  void _onParentCheckboxChanged(String parentKey, bool? value) {
    if (_isViewMode) return;
    
    setState(() {
      if (value == true) {
        // If another parent was selected, clear it
        if (_selectedParentNode != null && _selectedParentNode != parentKey) {
          _expandedStates[_selectedParentNode!] = false;
        }
        
        // Select this parent and expand it
        _selectedParentNode = parentKey;
        _expandedStates[parentKey] = true;
        
        // Clear child selections when switching parents
        _selectedChildChecklistIds.clear();
      } else {
        // Unselect parent and collapse
        _selectedParentNode = null;
        _expandedStates[parentKey] = false;
        _selectedChildChecklistIds.clear();
      }
      
      _hasFormDataChanges = true;
    });
  }

  void _onChildCheckboxChanged(int iclmId, bool? value) {
    if (_isViewMode) return;
    
    setState(() {
      if (value == true) {
        _selectedChildChecklistIds.add(iclmId);
      } else {
        _selectedChildChecklistIds.remove(iclmId);
      }
      
      _hasFormDataChanges = true;
    });
  }

  bool _validateForm() {
    // At least one child checklist item must be selected
    if (_selectedParentNode == null || _selectedChildChecklistIds.isEmpty) {
      Toastbar.showErrorToastbar(
        'Please select at least one checklist item',
        context,
      );
      return false;
    }
    return true;
  }

  Map<String, dynamic> _prepareSubmitData() {
    return {
      'parentIncidentType': _selectedParentNode,
      'selectedIclmIds': _selectedChildChecklistIds.toList(),
    };
  }

  Future<void> _submitForm() async {
    if (!_validateForm()) {
      return;
    }

    try {
      final submitData = _prepareSubmitData();
      
      Logger.debugLog('Incident Checklist Submit Data:');
      Logger.debugLog('  Parent Type: ${submitData['parentIncidentType']}');
      Logger.debugLog('  Selected ICLM IDs: ${submitData['selectedIclmIds']}');

      // TODO: Implement API call to save incident checklist data
      // For now, just show success message
      Toastbar.showSuccessToastbar(
        'Incident checklist saved successfully',
        context,
      );

      // Navigate back
      navigateBackOrToHome(
        context,
        targetContext: widget.parentContext ?? context,
      );
    } catch (e) {
      Logger.errorLog('❌ Error submitting incident checklist: $e');
      Toastbar.showErrorToastbar('Failed to save incident checklist', context);
    }
  }

  void _showUnsavedChangesDialog() {
    if (_hasFormDataChanges && !_isViewMode) {
      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (dialogContext) => UnsavedChangesDialog(
          siteAuditSchId: widget.siteData.siteId.toString(),
          section: "Incident Checklist",
          parentContext: widget.parentContext ?? context,
          onSaveAndExit: () async {
            await _submitForm();
          },
          onDiscard: () {},
        ),
      );
    } else {
      navigateBackOrToHome(
        context,
        targetContext: widget.parentContext ?? context,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      resizeToAvoidBottomInset: true,
      appBar: CustomFormAppbar(
        title: "Incident Checklist",
        onClose: () => _showUnsavedChangesDialog(),
      ),
      body: Stack(
        children: [
          // Background
          Positioned.fill(
            child: SvgPicture.asset(
              AppImages.home,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.of(context).viewInsets.bottom + 100,
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 20),
                          ..._buildChecklistItems(),
                        ],
                      ),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      // Back Button
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.buttonColorBg,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            "Previous",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.buttonColorSite,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Submit Button
                      Expanded(
                        child: CustomSubmitButtonV2(
                          text: "Submit",
                          onPressed: _isViewMode ? null : _submitForm,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildChecklistItems() {
    // Sort parent keys for consistent display
    final sortedParentKeys = widget.checklistData.keys.toList()
      ..sort((a, b) {
        // Get the first item's cl_order from each parent for sorting
        final itemsA = widget.checklistData[a] ?? [];
        final itemsB = widget.checklistData[b] ?? [];
        final orderA = itemsA.isNotEmpty
            ? (itemsA.first['cl_order'] as int? ?? 0)
            : 0;
        final orderB = itemsB.isNotEmpty
            ? (itemsB.first['cl_order'] as int? ?? 0)
            : 0;
        return orderA.compareTo(orderB);
      });

    return sortedParentKeys.map((parentKey) {
      final childItems = widget.checklistData[parentKey] ?? [];
      final isExpanded = _expandedStates[parentKey] ?? false;
      final isSelected = _selectedParentNode == parentKey;

      return Container(
        margin: const EdgeInsets.only(bottom: 12),
       
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Parent Header with Checkbox
            Container(
             
              child: Row(
                children: [
                  // Parent Checkbox
                  Checkbox(
                    value: isSelected,
                    onChanged: _isViewMode
                        ? null
                        : (bool? value) {
                            _onParentCheckboxChanged(parentKey, value);
                          },
                    activeColor: Colors.white,

                    checkColor: const Color(0xFF00695C),
                  ),
                  // Parent Label
                  Expanded(
                    child: GestureDetector(
                      onTap: _isViewMode
                          ? null
                          : () {
                              if (isSelected) {
                                // Toggle expansion when clicking label of selected parent
                                setState(() {
                                  _expandedStates[parentKey] = !isExpanded;
                                });
                              } else {
                                // Select parent if not selected
                                _onParentCheckboxChanged(parentKey, true);
                              }
                            },
                      child: Text(
                        parentKey,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  // Expand/Collapse Icon
                  if (isSelected)
                    IconButton(
                      onPressed: _isViewMode
                          ? null
                          : () {
                              setState(() {
                                _expandedStates[parentKey] = !isExpanded;
                              });
                            },
                      icon: Icon(
                        isExpanded ? Icons.expand_less : Icons.expand_more,
                        color: Colors.white,
                      ),
                    ),
                ],
              ),
            ),
            // Child Items (only show if parent is selected and expanded)
            if (isSelected && isExpanded)
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFE6F5EF).withOpacity(0.3),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(8),
                    bottomRight: Radius.circular(8),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _buildChildItems(childItems),
                  ),
                ),
              ),
          ],
        ),
      );
    }).toList();
  }

  List<Widget> _buildChildItems(List<Map<String, dynamic>> childItems) {
    // Sort child items by cl_order
    final sortedItems = List<Map<String, dynamic>>.from(childItems)
      ..sort((a, b) {
        final orderA = a['cl_order'] as int? ?? 0;
        final orderB = b['cl_order'] as int? ?? 0;
        return orderA.compareTo(orderB);
      });

    return sortedItems.map((item) {
      final iclmId = item['iclm_id'] as int?;
      final checklistDesc = item['checklist_desc']?.toString();
      final respType = item['resp_type']?.toString() ?? 'CHECKBOX';
      
      if (iclmId == null) return const SizedBox.shrink();

      // Handle CHECKBOX type
      if (respType == 'CHECKBOX') {
        final label = checklistDesc ?? item['incident_item_type']?.toString() ?? 'Unknown';
        final isChecked = _selectedChildChecklistIds.contains(iclmId);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Colors.grey.withOpacity(0.3),
            ),
          ),
          child: CheckboxListTile(
            value: isChecked,
            onChanged: _isViewMode
                ? null
                : (bool? value) {
                    _onChildCheckboxChanged(iclmId, value);
                  },
            title: Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w400,
                color: AppColors.color555555,
                fontFamily: 'Montserrat',
              ),
            ),
            activeColor: AppColors.primaryGreen,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
          ),
        );
      }

      // Fallback for unknown types
      return const SizedBox.shrink();
    }).toList();
  }
}

