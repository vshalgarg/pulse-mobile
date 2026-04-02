import 'package:flutter/material.dart';
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
import 'pm_dependent_element_helpers.dart'
    show isDependentElementMandatory, isPmMainFieldMandatory, parseDependentElements;
import 'package:app/commonWidgets/loader_widget.dart';
import 'package:app/commonWidgets/safe_svg_picture.dart';

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
  final bool isViewMode;

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
    this.isViewMode = false,
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
    bool isViewMode = false,
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
      isViewMode: isViewMode,
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

      // Skip validation for "Remarks, if any" fields
      final checklistDesc = pmItem['checklist_desc']?.toString().toLowerCase() ?? '';
      if (checklistDesc.contains('remarks')) {
        continue; // Skip validation for Remarks fields
      }

      // Parent row: API `is_mandatory` (see [isPmMainFieldMandatory]); dependents use STEP 2.
      final isParentMandatory = isPmMainFieldMandatory(pmItem);

      // Only validate parent field value when parent itself is mandatory
      if (isParentMandatory) {
        bool isParentFieldEmpty = false;
        String? errorMessage;
        final checklistDescDisplay = pmItem['checklist_desc']?.toString() ?? 'This field';

        if (respTypes.contains('DROPDOWN') &&
            (respValue == null || respValue.toString().isEmpty)) {
          isParentFieldEmpty = true;
          errorMessage = '$checklistDescDisplay is required';
        } else if (respTypes.contains('RADIO') &&
            (respValue == null || respValue.toString().isEmpty)) {
          isParentFieldEmpty = true;
          errorMessage = '$checklistDescDisplay is required';
        } else if (respTypes.contains('TEXT') &&
            (respValue == null || respValue.toString().trim().isEmpty)) {
          isParentFieldEmpty = true;
          errorMessage = '$checklistDescDisplay is required';
        } else if (respTypes.contains('NUMERIC') &&
            (respValue == null || respValue.toString().trim().isEmpty)) {
          isParentFieldEmpty = true;
          errorMessage = '$checklistDescDisplay is required';
        } else if (respTypes.contains('IMG') &&
            (respValue == null || respValue.toString().isEmpty)) {
          isParentFieldEmpty = true;
          errorMessage = '$checklistDescDisplay is required';
        }

        if (isParentFieldEmpty) {
          _showValidationErrorDialog(errorMessage!);
          return false;
        }
      }

      // ============================================================
      // STEP 2: Validate Dependent Elements (only if parent is valid)
      // ============================================================
      // Get parent response value for dependent element validation
      final parentResponse = _getParentResponseValue(pmItem);
      
      // Only validate dependent elements if parent field has a response
      if (parentResponse != null && parentResponse.isNotEmpty) {
        // ============================================================
        // STEP 2A: Validate grouped child checklist (resp_dtl_checklist)
        // ============================================================
        final groupedValidationError = _validateGroupedChecklistItem(pmItem);
        if (groupedValidationError != null) {
          _showValidationErrorDialog(groupedValidationError);
          return false;
        }

        // Check if this item has dependent elements
        final dependentElements = parseDependentElements(pmItem);
        if (dependentElements != null && dependentElements.isNotEmpty) {
          // Get widget state for accessing dependent element data
          final widgetKey = _widgetKeys[pmCheckListSiteRespId];
          final widgetState = widgetKey?.currentState;
          
          if (widgetState != null) {
            // Loop through dependent elements in order
            for (int index = 0; index < dependentElements.length; index++) {
              final dependentElement = dependentElements[index];
              final respType = dependentElement['resp_type']?.toString() ?? '';
              
              // REMARKS fields are always non-mandatory, skip validation
              if (respType == 'REMARKS') continue;
              
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
                  index,
                );
                
                // If validation fails, show popup and STOP immediately
                if (validationError != null) {
                  _showValidationErrorDialog(validationError);
                  // Highlight the invalid dependent field
                  final respType = dependentElement['resp_type']?.toString() ?? '';
                  final elementChecklistDesc = dependentElement['checklist_desc']?.toString() ?? '';
                  // Include index to make key unique when multiple elements have same resp_type and checklist_desc
                  final elementKey = '${respType}_${elementChecklistDesc}_$index';
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

  String? _validateGroupedChecklistItem(Map<String, dynamic> pmItem) {
    final isGroup = pmItem['is_group'] == true;
    final respDtlChecklist = pmItem['resp_dtl_checklist'];
    if (!isGroup || respDtlChecklist is! List || respDtlChecklist.isEmpty) {
      return null;
    }

    final responseDetails = pmItem['response_details'];
    final responseDetailsList = responseDetails is List ? responseDetails : const [];
    final parentCount = int.tryParse((pmItem['resp'] ?? '').toString()) ?? 0;

    bool isMandatory(dynamic value) {
      if (value == true || value == 1) return true;
      if (value == false || value == 0 || value == null) return false;
      final s = value.toString().trim().toLowerCase();
      return s == 'true' || s == '1';
    }

    Map<String, dynamic>? firstMissingForMstId(int mstId) {
      final matching = <Map<String, dynamic>>[];
      for (final detail in responseDetailsList) {
        if (detail is! Map) continue;
        final map = Map<String, dynamic>.from(detail);
        final detailMstId =
            int.tryParse((map['pm_check_list_mst_id'] ?? '').toString());
        if (detailMstId == mstId) {
          matching.add(map);
        }
      }

      // No rows found means mandatory grouped child has not been filled/saved.
      if (matching.isEmpty) {
        return <String, dynamic>{};
      }

      // If parent numeric count is present (e.g. Number of Earth Pits = 3),
      // each mandatory grouped child must exist for all instances.
      if (parentCount > 0 && matching.length < parentCount) {
        return <String, dynamic>{
          '_missing_count': parentCount - matching.length,
        };
      }

      // Strict rule: all rows for this pm_check_list_mst_id must have resp value.
      for (final row in matching) {
        final resp = row['resp']?.toString().trim();
        if (resp == null || resp.isEmpty) {
          return row;
        }
      }
      return null;
    }

    for (final child in respDtlChecklist) {
      if (child is! Map<String, dynamic>) continue;
      if (child['is_readonly'] == true) continue;
      if (!isMandatory(child['is_mandatory'])) continue;
      final mstId = int.tryParse((child['pm_check_list_mst_id'] ?? '').toString());
      if (mstId == null) continue;
      final missingRow = firstMissingForMstId(mstId);
      if (missingRow != null) {
        final desc = child['checklist_desc']?.toString().trim();
        final fieldName = (desc == null || desc.isEmpty) ? 'Grouped field' : desc;
        final missingCount =
            int.tryParse((missingRow['_missing_count'] ?? '').toString());
        if (missingCount != null && missingCount > 0) {
          if (parentCount > 0) {
            return '$fieldName is required for all $parentCount items';
          }
          return '$fieldName is required for all items';
        }
        final ref = missingRow['checklist_ref']?.toString().trim();
        if (ref != null && ref.isNotEmpty) {
          return '$fieldName is required for $ref';
        }
        return '$fieldName is required for all items';
      }
    }

    return null;
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
    int elementIndex,
  ) {
    final respType = dependentElement['resp_type']?.toString() ?? '';
    final checklistDesc = dependentElement['checklist_desc']?.toString() ?? '';
    // Include index to make key unique when multiple elements have same resp_type and checklist_desc
    final elementKey = '${respType}_${checklistDesc}_$elementIndex';
    
    if (respType == 'IMG') {
      // IMG: Check if image exists in either:
      // 1. _dependentImageIds (newly uploaded)
      // 2. _dependentImageData (display data)
      // 3. response_images (from server) - check by index
      final imageId = widgetState.getDependentImageId(elementKey);
      final imageData = widgetState.getDependentImageData(elementKey);
      final hasUploadedImage = (imageId != null && imageId.isNotEmpty) || 
                              (imageData != null && imageData.isNotEmpty);
      
      // Also check response_images from the pmItem - check if image exists at this element's index
      final pmItem = widgetState.getCurrentItem();
      final responseImages = pmItem['response_images'] ?? pmItem['responseImages'];
      bool hasServerImage = false;
      if (responseImages != null && responseImages is List) {
        // Count how many IMG elements come before this one to find the correct image index
        final dependentElements = parseDependentElements(pmItem);
        if (dependentElements != null) {
          int imgElementCount = 0;
          for (int i = 0; i < elementIndex && i < dependentElements.length; i++) {
            if (dependentElements[i]['resp_type']?.toString() == 'IMG') {
              imgElementCount++;
            }
          }
          // Check if response_images has an image at the corresponding index
          if (imgElementCount < responseImages.length) {
            final imageAtIndex = responseImages[imgElementCount];
            if (imageAtIndex is Map) {
              final photoId = imageAtIndex['photo_id'] ?? imageAtIndex['photoId'];
              hasServerImage = photoId != null && 
                              photoId.toString().trim().isNotEmpty && 
                              photoId.toString() != '0' && 
                              photoId.toString() != 'null';
            }
          }
        }
      }
      
      if (!hasUploadedImage && !hasServerImage) {
        return 'Photo is required';
      }
    } else if (respType == 'TEXT') {
      // TEXT: Non-empty text required (REMARKS are optional)
      final value = widgetState.getDependentTextValue(elementKey);
      
      if (value == null || value.trim().isEmpty) {
        return '$checklistDesc is required';
      }
    }
    // REMARKS fields are optional - no validation needed
    
    return null; // Valid
  }

  /// Show validation error dialog
  void _showValidationErrorDialog(String errorMessage) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          
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
    // IMPORTANT:
    // Validation can be heavy (grouped checklist + dependent validations).
    // Showing the loader but doing heavy synchronous work immediately can
    // delay the first frame, making it *feel* like nothing happened.
    // So we:
    //  1) show loader now
    //  2) run validation after the next frame
    //  3) hide loader on validation failure (submit/next flow owns hiding)
    final shouldShowLoader =
        widget.rightButtonText.trim().toLowerCase() != 'done';

    if (shouldShowLoader) {
      LoaderWidget.showLoader(context);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        if (shouldShowLoader) LoaderWidget.hideLoader();
        return;
      }

      final isValid = _validateAllFields();
      if (!isValid) {
        if (shouldShowLoader) LoaderWidget.hideLoader();
        return;
      }

      // If validation passes, proceed with the original callback.
      // The submit/next flow will manage loader visibility.
      widget.onRightButtonPressed();
    });
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
        orElse: () => <String, dynamic>{},
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
            child: SafeSvgPicture.asset(
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
                      : ListView.builder(
                          physics: const ClampingScrollPhysics(),
                          padding: EdgeInsets.only(
                            top: 20,
                            left: 16,
                            right: 16,
                            bottom:
                                MediaQuery.of(context).viewInsets.bottom + 120,
                          ),
                          itemCount: filteredItems.length + 1,
                          itemBuilder: (context, index) {
                            if (index == filteredItems.length) {
                              return getHeight(20);
                            }

                            final pmItem = filteredItems[index];

                            // Find the original index in _pmItems for proper state management.
                            final originalIndex = _pmItems.indexWhere(
                              (item) =>
                                  item['pm_check_list_site_resp_id'] ==
                                  pmItem['pm_check_list_site_resp_id'],
                            );

                            // Check if this is a grouped item with resp_dtl_checklist.
                            final isGroup = pmItem['is_group'] == true;
                            final hasRespDtlChecklist =
                                pmItem['resp_dtl_checklist'] != null;

                            if (isGroup && hasRespDtlChecklist) {
                              return PMCustomFormComponent(
                                key: ValueKey(
                                  'pm_form_${pmItem['pm_check_list_site_resp_id']}_$index',
                                ),
                                checklistItem: pmItem,
                                isViewMode: widget.isViewMode,
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

                            final pmCheckListSiteRespId =
                                pmItem['pm_check_list_site_resp_id'] as int?;
                            final widgetKey = pmCheckListSiteRespId != null
                                ? _widgetKeys[pmCheckListSiteRespId]
                                : null;

                            // Create GlobalKey if it doesn't exist.
                            if (pmCheckListSiteRespId != null &&
                                widgetKey == null) {
                              _widgetKeys[pmCheckListSiteRespId] =
                                  GlobalKey<PMCustomWidgetState>();
                            }

                            return PMCustomWidget(
                              key: widgetKey ??
                                  ValueKey(
                                    'pm_item_${pmCheckListSiteRespId}_$index',
                                  ),
                              pmItem: pmItem,
                              readonlyFields: widget.readonlyFields,
                              isViewMode: widget.isViewMode,
                              onValueChanged: (updatedItem) {
                                if (mounted) {
                                  _onItemChanged(
                                    originalIndex,
                                    updatedItem,
                                  );
                                }
                              },
                            );
                          },
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
