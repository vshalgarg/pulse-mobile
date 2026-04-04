import 'package:app/commonWidgets/custom_form_appbar.dart';
import 'package:app/commonWidgets/custom_submit_button_v2.dart';
import 'package:app/commonWidgets/custom_dialogs/unsaved_changes_dialog.dart';
import 'package:app/commonWidgets/custom_dialogs/close_remarks_dialog.dart';
import 'package:app/constants/app_colors.dart';
import 'package:app/constants/app_images.dart';
import 'package:app/enum/corrective_maintenance_screen_mode_enum.dart';
import 'package:app/models/all_site_model.dart';
import 'package:app/routes/route_generator.dart';
import 'package:app/utils/logger.dart';
import 'package:app/utils/toastbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:geolocator/geolocator.dart';

class IncidentChecklistScreen extends StatefulWidget {
  final AllSiteModel siteData;
  final CMScreenModeEnum mode;
  final Map<String, List<Map<String, dynamic>>> checklistData;
  final Map<String, List<int>>? existingSelections; // parentType -> [iclm_ids] for edit mode
  final String? currentStatus; // Status passed from detail screen
  final Map<String, dynamic>? apiResponseData; // API response data for edit/view mode
  final BuildContext? parentContext;
  final Map<String, dynamic>? storedSelections; // Stored selections from previous navigation

  const IncidentChecklistScreen({
    super.key,
    required this.siteData,
    required this.mode,
    required this.checklistData,
    this.existingSelections,
    this.currentStatus,
    this.apiResponseData,
    this.parentContext,
    this.storedSelections,
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

  // Location data
  double? _latitude;
  double? _longitude;

  // Close remarks when status is CLOSED
  final TextEditingController _closedRemarksController =
      TextEditingController();
  
  // Check if mode is view (read-only)
  bool get _isViewMode => widget.mode == CMScreenModeEnum.view;
  
  // Check if mode is edit or view (parent checkbox should be disabled)
  bool get _isEditOrViewMode => widget.mode == CMScreenModeEnum.edit || widget.mode == CMScreenModeEnum.view;
  
  // Check if status is CLOSED AND mode is view (all items should be disabled only in view mode with CLOSED)
  bool get _isStatusClose => widget.currentStatus == 'CLOSED' && widget.mode == CMScreenModeEnum.view;

  @override
  void dispose() {
    _closedRemarksController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _initializeExpandedStates();
    _loadExistingSelections();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          Logger.errorLog('Location permissions are denied');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        Logger.errorLog(
          'Location permissions are permanently denied, we cannot request permissions.',
        );
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
      });

      Logger.debugLog(
        'Location obtained: Lat: $_latitude, Long: $_longitude',
      );
    } catch (e) {
      Logger.errorLog('Error getting location: $e');
    }
  }

  void _initializeExpandedStates() {
    // Initialize all parent nodes as collapsed
    for (final parentKey in widget.checklistData.keys) {
      _expandedStates[parentKey] = false;
    }
  }

  void _loadExistingSelections() {
    // First priority: Load from stored selections (when navigating back from detail screen)
    if (widget.storedSelections != null && widget.storedSelections!.isNotEmpty) {
      final parentType = widget.storedSelections!['parentIncidentType']?.toString();
      final selectedIds = widget.storedSelections!['selectedIclmIds'] as List?;
      
      if (parentType != null && selectedIds != null) {
        setState(() {
          _selectedParentNode = parentType;
          _selectedChildChecklistIds = Set<int>.from(selectedIds.map((id) => id as int));
          _expandedStates[parentType] = true;
        });
        
        Logger.debugLog('✅ Loaded stored selections: $parentType with ${selectedIds.length} selected items');
        return;
      }
    }
    
    // Second priority: In edit/view mode, load selections from API response
    if (widget.apiResponseData != null && 
        widget.apiResponseData!.containsKey('incidentCheckListSiteResp')) {
      final checklistResponses = widget.apiResponseData!['incidentCheckListSiteResp'] as List?;
      
      if (checklistResponses != null && checklistResponses.isNotEmpty) {
        // Get the incidentItemType from the first item (all items should have the same type)
        final firstItem = checklistResponses.first as Map<String, dynamic>;
        final incidentItemType = firstItem['incidentItemType']?.toString();
        
        if (incidentItemType != null) {
          // Extract selected iclmIds where resp == "true"
          final selectedIds = <int>[];
          for (final item in checklistResponses) {
            final iclmId = item['iclmId'] as int?;
            final resp = item['resp']?.toString();
            if (iclmId != null && resp == "true") {
              selectedIds.add(iclmId);
            }
          }
          
          setState(() {
            _selectedParentNode = incidentItemType;
            _selectedChildChecklistIds = Set<int>.from(selectedIds);
            _expandedStates[incidentItemType] = true;
          });
          
          Logger.debugLog('✅ Loaded existing selections from API: $incidentItemType with ${selectedIds.length} selected items');
          return;
        }
      }
    }
    
    // Fallback to existing selections if provided
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

  // Prepare data for storage (navigation only, no submission)
  Map<String, dynamic> _prepareStorageData() {
    if (_selectedParentNode == null) {
      return {'isNavigation': true};
    }

    return {
      'isNavigation': true,
      'parentIncidentType': _selectedParentNode!,
      'selectedIclmIds': _selectedChildChecklistIds.toList(),
      'latitude': _latitude,
      'longitude': _longitude,
    };
  }

  Map<String, dynamic> _prepareSubmitData() {
    if (_selectedParentNode == null) {
      return {};
    }

    final parentType = _selectedParentNode!;
    
    // In edit/view mode, use items from API response if available
    List<Map<String, dynamic>> childItems = [];
    
    if (widget.apiResponseData != null && 
        widget.apiResponseData!.containsKey('incidentCheckListSiteResp')) {
      // Use items from API response
      final checklistResponses = widget.apiResponseData!['incidentCheckListSiteResp'] as List?;
      if (checklistResponses != null) {
        for (final item in checklistResponses) {
          final itemMap = item as Map<String, dynamic>;
          final itemType = itemMap['incidentItemType']?.toString();
          if (itemType == parentType) {
            // Convert API response format to checklist format
            childItems.add({
              'iclm_id': itemMap['iclmId'] as int?,
              'iclmId': itemMap['iclmId'] as int?,
              'checklist_desc': itemMap['checklistDesc']?.toString(),
              'cl_order': itemMap['clOrder'] as int? ?? 0,
              'resp_type': 'CHECKBOX',
              'incident_item_type': itemType,
            });
          }
        }
      }
    }
    
    // If no items from API response, use full checklist data
    if (childItems.isEmpty) {
      childItems = widget.checklistData[parentType] ?? [];
    }

    // Build checklist responses for all items under the selected parent
    final List<Map<String, dynamic>> checklistResponses = [];

    for (final item in childItems) {
      final iclmId = item['iclm_id'] as int? ?? item['iclmId'] as int?;
      if (iclmId == null) continue;

      final isSelected = _selectedChildChecklistIds.contains(iclmId);
      final checklistDesc = item['checklist_desc']?.toString() ?? item['checklistDesc']?.toString();
      final clOrder = item['cl_order'] as int? ?? item['clOrder'] as int? ?? 0;
      
      // In edit mode, preserve iclsrId from API response if available
      int? iclsrId = 0;
      if (widget.apiResponseData != null && 
          widget.apiResponseData!.containsKey('incidentCheckListSiteResp')) {
        final apiResponses = widget.apiResponseData!['incidentCheckListSiteResp'] as List?;
        if (apiResponses != null) {
          for (final apiItem in apiResponses) {
            final apiItemMap = apiItem as Map<String, dynamic>;
            if (apiItemMap['iclmId'] == iclmId) {
              iclsrId = apiItemMap['iclsrId'] as int? ?? 0;
              break;
            }
          }
        }
      }

      checklistResponses.add({
        'iclsrId': iclsrId,
        'iclmId': iclmId,
        'siteId': widget.siteData.siteId,
        'incidentItemType': parentType,
        'checklistDesc': checklistDesc,
        'resp': isSelected ? 'true' : 'false',
        'clOrder': clOrder,
        'longitude': _longitude?.toString() ?? '',
        'latitude': _latitude?.toString() ?? '',
        'localAuditLogId': null,
        'localCreatedDt': null,
        'localModifiedDt': null,
        'syncProcessId': null,
        'isActive': true,
        'remarks': null,
      });
    }

    return {
      'parentIncidentType': parentType,
      'selectedIclmIds': _selectedChildChecklistIds.toList(),
      'checklistResponses': checklistResponses,
      'latitude': _latitude,
      'longitude': _longitude,
    };
  }

  Future<void> _submitForm() async {
    if (!_validateForm()) {
      return;
    }

    try {
      // If status is CLOSED, show dialog to get closing remarks
      if (widget.currentStatus == 'CLOSED') {
        final closedRemarks = await _showCloseRemarksDialog();
        if (closedRemarks == null) {
          // User cancelled the dialog
          return;
        }
        
        final submitData = _prepareSubmitData();
        submitData['closedRemarks'] = closedRemarks;
        
        Logger.debugLog('Incident Checklist Submit Data:');
        Logger.debugLog('  Parent Type: ${submitData['parentIncidentType']}');
        Logger.debugLog('  Selected ICLM IDs: ${submitData['selectedIclmIds']}');
        Logger.debugLog('  Closed Remarks: $closedRemarks');

        // Return data to previous screen (detail screen will handle connectivity check)
        Navigator.of(context).pop(submitData);
      } else {
        final submitData = _prepareSubmitData();
        
        Logger.debugLog('Incident Checklist Submit Data:');
        Logger.debugLog('  Parent Type: ${submitData['parentIncidentType']}');
        Logger.debugLog('  Selected ICLM IDs: ${submitData['selectedIclmIds']}');

        // Return data to previous screen (detail screen will handle connectivity check)
        Navigator.of(context).pop(submitData);
      }
    } catch (e) {
      Logger.errorLog('❌ Error submitting incident checklist: $e');
      Toastbar.showErrorToastbar('Failed to prepare checklist data', context);
    }
  }

  Future<String?> _showCloseRemarksDialog() async {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => CloseRemarksDialog(
        onCancel: () => Navigator.of(dialogContext).pop(null),
        onSubmit: (remarks) => Navigator.of(dialogContext).pop(remarks),
      ),
    );
  }

  Future<void> _showUnsavedChangesDialog() async {
    if (_hasFormDataChanges && !_isViewMode) {
      final result = await showDialog<String>(
        context: context,
        barrierDismissible: true,
        builder: (dialogContext) => UnsavedChangesDialog(
          siteAuditSchId: widget.siteData.siteId.toString(), // prevent dialog success message; detail screen handles UX
          section: "Incident Checklist",
          parentContext: widget.parentContext ?? context,
          onSaveAndExit: () async {
            // Close dialog with a flag; submit happens after dialog is dismissed
            Navigator.of(dialogContext).pop('save');
          },
          onDiscard: () {
            Navigator.of(dialogContext).pop('discard');
          },
        ),
      );

      if (result == 'save') {
        await _submitForm();
      }
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
                          onPressed: () {
                            // Return current selections for storage only (no submission)
                            final currentSelections = _prepareStorageData();
                            Navigator.of(context).pop(currentSelections);
                          },
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
                  // Parent Checkbox - disabled in edit, view mode, or when status is CLOSED
                  Checkbox(
                    value: isSelected,
                    onChanged: (_isEditOrViewMode || _isStatusClose)
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
                      onTap: (_isEditOrViewMode || _isStatusClose)
                          ? () {
                              // In edit/view mode or when status is CLOSED, only allow toggling expansion if parent is selected
                              if (isSelected) {
                                setState(() {
                                  _expandedStates[parentKey] = !isExpanded;
                                });
                              }
                            }
                          : () {
                              // In create mode, allow selecting parent
                              if (isSelected) {
                                setState(() {
                                  _expandedStates[parentKey] = !isExpanded;
                                });
                              } else {
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
                  // Expand/Collapse Icon - allow expansion even when status is CLOSED for viewing
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
            onChanged: (_isViewMode || _isStatusClose)
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
