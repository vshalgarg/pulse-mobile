import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_images.dart';
import '../../constants/constants_methods.dart';
import '../../constants/pm_constants.dart';
import '../../commonWidgets/custom_pm_bottom_buttons.dart';
import '../../commonWidgets/custom_form_appbar.dart';
import '../../commonWidgets/custom_dialogs/unsaved_changes_dialog.dart';
import '../../routes/route_generator.dart';
import '../../custom_widgets/pm_custom_form_component.dart';
import 'pm_custom_widget.dart' show PMCustomWidget, PMCustomWidgetState;
import 'pm_dependent_element_helpers.dart' show parseDependentElements, isDependentElementMandatory;

class PMPageWidget extends StatefulWidget {
  final List<Map<String, dynamic>> pmItems;
  final List<String> readonlyFields;
  final String pageTitle;
  final String leftButtonText;
  final String rightButtonText;
  final VoidCallback onLeftButtonPressed;
  final VoidCallback onRightButtonPressed;
  final Function(List<Map<String, dynamic>>) onDataChanged;
  final bool isLoading;
  final String? errorMessage;
  final Future<void> Function() submitDataWhenExit;
  final String siteAuditSchId;
  final String sectionName;
  final BuildContext parentContext;

  const PMPageWidget({
    super.key,
    required this.pmItems,
    required this.readonlyFields,
    required this.pageTitle,
    required this.leftButtonText,
    required this.rightButtonText,
    required this.onLeftButtonPressed,
    required this.onRightButtonPressed,
    required this.onDataChanged,
    this.isLoading = false,
    this.errorMessage,
    required this.submitDataWhenExit,
    required this.siteAuditSchId,
    this.sectionName = '',
    required this.parentContext,
  });

  // Convenience constructor that automatically determines readonly fields
  factory PMPageWidget.forSection({
    required List<Map<String, dynamic>> pmItems,
    required String sectionName,
    required String pageTitle,
    required String leftButtonText,
    required String rightButtonText,
    required VoidCallback onLeftButtonPressed,
    required VoidCallback onRightButtonPressed,
    required Function(List<Map<String, dynamic>>) onDataChanged,
    bool isLoading = false,
    String? errorMessage,
    List<String>? customReadonlyFields,
    required Future<void> Function() submitDataWhenExit,
    required String siteAuditSchId,
    required BuildContext parentContext,
  }) {
    return PMPageWidget(
      pmItems: pmItems,
      readonlyFields:
          customReadonlyFields ??
          PMConstants.getReadonlyFieldsForSection(sectionName),
      pageTitle: pageTitle,
      leftButtonText: leftButtonText,
      rightButtonText: rightButtonText,
      onLeftButtonPressed: onLeftButtonPressed,
      onRightButtonPressed: onRightButtonPressed,
      onDataChanged: onDataChanged,
      isLoading: isLoading,
      errorMessage: errorMessage,
      submitDataWhenExit: submitDataWhenExit,
      siteAuditSchId: siteAuditSchId,
      sectionName: sectionName,
      parentContext: parentContext,
    );
  }

  @override
  State<PMPageWidget> createState() => _PMPageWidgetState();
}

class _PMPageWidgetState extends State<PMPageWidget> {
  late List<Map<String, dynamic>> _pmItems;
  bool _hasChanges = false;
  
  // GlobalKeys to access widget state for validation
  final Map<int, GlobalKey<PMCustomWidgetState>> _widgetKeys = {};

  @override
  void initState() {
    super.initState();
    _pmItems = List<Map<String, dynamic>>.from(widget.pmItems);
    
    // Initialize GlobalKeys for each PM item
    for (final item in _pmItems) {
      final pmCheckListSiteRespId = item['pm_check_list_site_resp_id'] as int?;
      if (pmCheckListSiteRespId != null) {
        _widgetKeys[pmCheckListSiteRespId] = GlobalKey<PMCustomWidgetState>();
      }
    }
  }

  @override
  void dispose() {
    // Clean up resources
    super.dispose();
  }

  void _onItemChanged(int index, Map<String, dynamic> updatedItem) {
    if (!mounted) return;

    // Validate index bounds
    if (index < 0 || index >= _pmItems.length) return;

    // Update the item first
    _pmItems[index] = updatedItem;
    _hasChanges = true;

    // Use addPostFrameCallback to avoid setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          // State is already updated above, just trigger rebuild
        });

        // Notify parent about data changes
        widget.onDataChanged(_pmItems);
      }
    });
  }

  /// Sequential validation: Item-by-item validation with dependent elements
  /// For each checklist item:
  ///   1. Validate parent field first
  ///   2. Then validate dependent elements (only if parent is valid)
  ///   3. Move to next item only if current item is fully valid
  /// Returns false on first failure and shows popup
  bool _validateAllFields() {
    // Get filtered items (excluding conditionally hidden fields)
    final filteredItems = _filterItemsByConditions(
      widget.sectionName,
      _pmItems,
    );

    // Loop through PM items in order (STRICT SEQUENTIAL)
    for (final pmItem in filteredItems) {
      final pmCheckListSiteRespId = pmItem['pm_check_list_site_resp_id'] as int?;
      if (pmCheckListSiteRespId == null) continue;

      // ============================================================
      // STEP 1: Validate Parent Field (basic validation)
      // ============================================================
      final respValue = pmItem['resp'];
      final respTypeList = pmItem['resp_type'];

      // Handle resp_type as array or string
      List<String> respTypes = [];
      if (respTypeList is List) {
        respTypes = respTypeList.map((e) => e.toString()).toList();
      } else if (respTypeList is String) {
        respTypes = respTypeList.split(",");
      }

      // Check if any required field is empty (basic validation)
      bool isParentFieldEmpty = false;
      String? errorMessage;
      final checklistDesc = pmItem['checklist_desc']?.toString() ?? 'This field';

      if (respTypes.contains('DROPDOWN') &&
          (respValue == null || respValue.toString().isEmpty)) {
        isParentFieldEmpty = true;
        errorMessage = '$checklistDesc is required';
      } else if (respTypes.contains('RADIO') &&
          (respValue == null || respValue.toString().isEmpty)) {
        isParentFieldEmpty = true;
        errorMessage = '$checklistDesc is required';
      } else if (respTypes.contains('TEXT') &&
          (respValue == null || respValue.toString().trim().isEmpty)) {
        isParentFieldEmpty = true;
        errorMessage = '$checklistDesc is required';
      } else if (respTypes.contains('NUMERIC') &&
          (respValue == null || respValue.toString().trim().isEmpty)) {
        isParentFieldEmpty = true;
        errorMessage = '$checklistDesc is required';
      } else if (respTypes.contains('IMG') &&
          (respValue == null || respValue.toString().isEmpty)) {
        isParentFieldEmpty = true;
        errorMessage = '$checklistDesc is required';
      }

      // If parent field is empty, show error and STOP
      if (isParentFieldEmpty) {
        _showValidationErrorDialog(errorMessage!);
        return false;
      }

      // ============================================================
      // STEP 2: Validate Dependent Elements (only if parent is valid)
      // ============================================================
      // Get parent response value for dependent element validation
      final parentResponse = _getParentResponseValue(pmItem);
      
      // Only validate dependent elements if parent field has a response
      if (parentResponse != null && parentResponse.isNotEmpty) {
        // Check if this item has dependent elements
        final dependentElements = parseDependentElements(pmItem);
        if (dependentElements != null && dependentElements.isNotEmpty) {
          // Get widget state for accessing dependent element data
          final widgetKey = _widgetKeys[pmCheckListSiteRespId];
          final widgetState = widgetKey?.currentState;
          
          if (widgetState != null) {
            // Loop through dependent elements in order
            for (final dependentElement in dependentElements) {
              // Determine if this dependent element is mandatory
              final isMandatory = isDependentElementMandatory(
                dependentElement,
                parentResponse,
              );
              
              // If mandatory, validate the dependent element value
              if (isMandatory) {
                final validationError = _validateDependentElementValue(
                  dependentElement,
                  widgetState,
                  parentResponse,
                );
                
                // If validation fails, show popup and STOP immediately
                if (validationError != null) {
                  _showValidationErrorDialog(validationError);
                  // Highlight the invalid dependent field
                  final respType = dependentElement['resp_type']?.toString() ?? '';
                  final elementChecklistDesc = dependentElement['checklist_desc']?.toString() ?? '';
                  final elementKey = '${respType}_${elementChecklistDesc}';
                  widgetState.highlightDependentField(elementKey);
                  return false; // Stop validation - do not check other dependencies or next item
                }
              }
            }
          }
        }
      }
    }
    
    // All PM items validated successfully
    return true;
  }
  
  /// Get parent response value for a PM item
  String? _getParentResponseValue(Map<String, dynamic> pmItem) {
    final respValue = pmItem['resp'];
    final respTypeList = pmItem['resp_type'];
    
    // Handle resp_type as array or string
    List<String> respTypes = [];
    if (respTypeList is List) {
      respTypes = respTypeList.map((e) => e.toString()).toList();
    } else if (respTypeList is String) {
      respTypes = respTypeList.split(",");
    }
    
    // Get value based on response type
    if (respTypes.contains('RADIO') || respTypes.contains('DROPDOWN')) {
      return respValue?.toString();
    } else if (respTypes.contains('TEXT') || respTypes.contains('NUMERIC')) {
      return respValue?.toString();
    }
    
    return null;
  }
  
  /// Validate a single dependent element value
  /// Returns error message if invalid, null if valid
  String? _validateDependentElementValue(
    Map<String, dynamic> dependentElement,
    PMCustomWidgetState widgetState,
    String? parentResponse,
  ) {
    final respType = dependentElement['resp_type']?.toString() ?? '';
    final checklistDesc = dependentElement['checklist_desc']?.toString() ?? '';
    final elementKey = '${respType}_${checklistDesc}';
    
    if (respType == 'IMG') {
      // IMG: At least one image must be added
      final imageId = widgetState.getDependentImageId(elementKey);
      if (imageId == null || imageId.isEmpty) {
        return '$checklistDesc is required';
      }
    } else if (respType == 'REMARKS' || respType == 'TEXT') {
      // REMARKS/TEXT: Non-empty text required
      final value = respType == 'REMARKS'
          ? widgetState.getDependentRemarks(elementKey)
          : widgetState.getDependentTextValue(elementKey);
      
      if (value == null || value.trim().isEmpty) {
        return '$checklistDesc is required';
      }
    }
    
    return null; // Valid
  }

  /// Get validation error messages for all fields
  List<String> _getValidationErrors() {
    List<String> errors = [];

    // Get filtered items (excluding conditionally hidden fields)
    final filteredItems = _filterItemsByConditions(
      widget.sectionName,
      _pmItems,
    );

    for (final pmItem in filteredItems) {
      final respValue = pmItem['resp'];
      final respTypeList = pmItem['resp_type'];
      final checklistDesc =
          pmItem['checklist_desc']?.toString() ?? 'This field';

      // Handle resp_type as array or string
      List<String> respTypes = [];
      if (respTypeList is List) {
        respTypes = respTypeList.map((e) => e.toString()).toList();
      } else if (respTypeList is String) {
        respTypes = respTypeList.split(",");
      }

      // Check if any required field is empty
      if (respTypes.contains('DROPDOWN') &&
          (respValue == null || respValue.toString().isEmpty)) {
        errors.add('$checklistDesc is required');
      }

      if (respTypes.contains('RADIO') &&
          (respValue == null || respValue.toString().isEmpty)) {
        errors.add('$checklistDesc is required');
      }

      if (respTypes.contains('TEXT') &&
          (respValue == null || respValue.toString().trim().isEmpty)) {
        errors.add('$checklistDesc is required');
      }

      if (respTypes.contains('IMG') &&
          (respValue == null || respValue.toString().isEmpty)) {
        errors.add('$checklistDesc is required');
      }
    }

    return errors;
  }

  /// Show validation error dialog
  void _showValidationErrorDialog(String errorMessage) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(
            'Validation Error',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: Text(
            errorMessage,
            style: const TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'OK',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Handle right button press with validation
  void _handleRightButtonPress() {
    // Validate all fields including dependent elements
    if (!_validateAllFields()) {
      return; // Stop if validation fails
    }
    // If validation passes, proceed with the original callback
    widget.onRightButtonPressed();
  }

  void _sortItemsByOrder() {
    _pmItems.sort((a, b) {
      final orderA = a['cl_order'] as int? ?? 0;
      final orderB = b['cl_order'] as int? ?? 0;
      return orderA.compareTo(orderB);
    });
  }

  /// Filter items based on conditional logic (e.g., CT availability)
  List<Map<String, dynamic>> _filterItemsByConditions(
    String sectionName,
    List<Map<String, dynamic>> items,
  ) {
    // Special handling for CT section
    if (sectionName == 'CT') {
      // Find CT availability item
      final ctAvailabilityItem = items.firstWhere(
        (item) =>
            item['checklist_desc']?.toString().toLowerCase().contains(
              'ct availability',
            ) ??
            false,
        orElse: () => {},
      );

      // If CT availability is "No", filter out CT Name and CT Contact Number
      if (ctAvailabilityItem.isNotEmpty) {
        final ctAvailability = ctAvailabilityItem['resp']?.toString();

        if (ctAvailability == 'No' || ctAvailability == 'NO') {
          // Filter out CT Name and CT Contact Number
          return items.where((item) {
            final checklistDesc =
                item['checklist_desc']?.toString().toLowerCase() ?? '';
            return !checklistDesc.contains('ct name') &&
                !checklistDesc.contains('ct contact');
          }).toList();
        }
      }
    }

    return items;
  }

  @override
  Widget build(BuildContext context) {
    // Sort items by cl_order
    _sortItemsByOrder();

    // Filter items based on conditional logic (CT availability, etc.)
    final filteredItems = _filterItemsByConditions(
      widget.sectionName,
      _pmItems,
    );

    return Scaffold(
      extendBodyBehindAppBar: true,
      resizeToAvoidBottomInset: true,
      appBar: CustomFormAppbar(
        title: widget.pageTitle,
        onClose: () {
          if (_hasChanges) {
            _showUnsavedChangesDialog();
          } else {
            navigateBackOrToHome(context, targetContext: widget.parentContext);
          }
        },
      ),
      body: Stack(
        children: [
          // Background image
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
                  child: widget.isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primaryGreen,
                          ),
                        )
                      : widget.errorMessage != null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                widget.errorMessage!,
                                style: const TextStyle(
                                  color: AppColors.white,
                                  fontSize: 16,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 20),
                              ElevatedButton(
                                onPressed: () {
                                  // Retry logic can be added here
                                },
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        )
                      : SingleChildScrollView(
                          padding: EdgeInsets.only(
                            bottom:
                                MediaQuery.of(context).viewInsets.bottom + 100,
                          ),
                          child: Container(
                            padding: const EdgeInsets.only(
                              top: 20,
                              left: 16,
                              right: 16,
                              bottom: 20,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Render filtered PM items
                                ...filteredItems.asMap().entries.map((entry) {
                                  final index = entry.key;
                                  final pmItem = entry.value;

                                  // Find the original index in _pmItems for proper state management
                                  final originalIndex = _pmItems.indexWhere(
                                    (item) =>
                                        item['pm_check_list_site_resp_id'] ==
                                        pmItem['pm_check_list_site_resp_id'],
                                  );

                                  // Check if this is a grouped item with resp_dtl_checklist
                                  final isGroup = pmItem['is_group'] == true;
                                  final hasRespDtlChecklist = pmItem['resp_dtl_checklist'] != null;

                                  // Use PMCustomFormComponent for grouped items with resp_dtl_checklist
                                  if (isGroup && hasRespDtlChecklist) {
                                    return PMCustomFormComponent(
                                      key: ValueKey(
                                        'pm_form_${pmItem['pm_check_list_site_resp_id']}_$index',
                                      ),
                                      checklistItem: pmItem,
                                      onChange: (updatedItem) {
                                        if (mounted) {
                                          _onItemChanged(
                                            originalIndex,
                                            updatedItem,
                                          );
                                        }
                                      },
                                    );
                                  }

                                  // Use regular PMCustomWidget for non-grouped items
                                  final pmCheckListSiteRespId = pmItem['pm_check_list_site_resp_id'] as int?;
                                  final widgetKey = pmCheckListSiteRespId != null 
                                      ? _widgetKeys[pmCheckListSiteRespId] 
                                      : null;
                                  
                                  // Create GlobalKey if it doesn't exist
                                  if (pmCheckListSiteRespId != null && widgetKey == null) {
                                    _widgetKeys[pmCheckListSiteRespId] = GlobalKey<PMCustomWidgetState>();
                                  }
                                  
                                  return PMCustomWidget(
                                    key: widgetKey ?? ValueKey(
                                      'pm_item_${pmCheckListSiteRespId}_$index',
                                    ),
                                    pmItem: pmItem,
                                    readonlyFields: widget.readonlyFields,
                                    onValueChanged: (updatedItem) {
                                      if (mounted) {
                                        _onItemChanged(
                                          originalIndex,
                                          updatedItem,
                                        );
                                      }
                                    },
                                  );
                                }),

                                // Add some bottom padding
                                getHeight(20),
                              ],
                            ),
                          ),
                        ),
                ),
                // Bottom buttons - matching asset audit style
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(color: Colors.transparent),
                  child: CustomPMBottomButtons(
                    leftButtonText: widget.leftButtonText,
                    rightButtonText: widget.rightButtonText,
                    onLeftButtonPressed: widget.onLeftButtonPressed,
                    onRightButtonPressed: _handleRightButtonPress,
                    isLoading: widget.isLoading,
                    errorMessage: widget.errorMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showUnsavedChangesDialog() {
    if (!_hasChanges) {
      navigateBackOrToHome(context, targetContext: widget.parentContext);
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => UnsavedChangesDialog(
        siteAuditSchId: widget.siteAuditSchId,
        onSaveAndExit: () async {
          // Save data and then navigate back
          await widget.submitDataWhenExit();

          if (mounted) {
            widget.onDataChanged(_pmItems);
          }
        },
        onDiscard: () {},
        section: widget.pageTitle,
        parentContext: widget.parentContext,
      ),
    );
  }
}
