import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_images.dart';
import '../../constants/constants_methods.dart';
import '../../constants/pm_constants.dart';
import 'pm_custom_widget.dart';
import '../../commonWidgets/custom_pm_bottom_buttons.dart';
import '../../commonWidgets/custom_form_appbar.dart';
import '../../commonWidgets/custom_dialogs/unsaved_changes_dialog.dart';

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
    );
  }

  @override
  State<PMPageWidget> createState() => _PMPageWidgetState();
}

class _PMPageWidgetState extends State<PMPageWidget> {
  late List<Map<String, dynamic>> _pmItems;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _pmItems = List<Map<String, dynamic>>.from(widget.pmItems);
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

  /// Validate all form fields
  bool _validateAllFields() {
    bool isValid = true;

    // Get filtered items (excluding conditionally hidden fields)
    final filteredItems = _filterItemsByConditions(widget.sectionName, _pmItems);

    for (final pmItem in filteredItems) {
      final respValue = pmItem['resp'];
      final respTypeList = pmItem['resp_type'];

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
        isValid = false;
        break;
      }

      if (respTypes.contains('RADIO') &&
          (respValue == null || respValue.toString().isEmpty)) {
        isValid = false;
        break;
      }

      if (respTypes.contains('TEXT') &&
          (respValue == null || respValue.toString().trim().isEmpty)) {
        isValid = false;
        break;
      }

      if (respTypes.contains('IMG') &&
          (respValue == null || respValue.toString().isEmpty)) {
        isValid = false;
        break;
      }
    }

    return isValid;
  }

  /// Get validation error messages for all fields
  List<String> _getValidationErrors() {
    List<String> errors = [];

    // Get filtered items (excluding conditionally hidden fields)
    final filteredItems = _filterItemsByConditions(widget.sectionName, _pmItems);

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
  void _showValidationErrorDialog(List<String> errors) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Validation Error'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Please fill in all required fields:'),
              const SizedBox(height: 16),
              ...errors
                  .map(
                    (error) => Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Text('• $error'),
                    ),
                  )
                  .toList(),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  /// Handle right button press with validation
  void _handleRightButtonPress() {
    // Validate all fields
    //TODO vishal enable validation by uncommenting this
    // if (!_validateAllFields()) {
    //   final errors = _getValidationErrors();
    //   _showValidationErrorDialog(errors);
    //   return;
    // }

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
            item['checklist_desc']
                ?.toString()
                .toLowerCase()
                .contains('ct availability') ??
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

    // Return all items if no filtering needed
    return items;
  }

  @override
  Widget build(BuildContext context) {
    // Sort items by cl_order
    _sortItemsByOrder();

    // Filter items based on conditional logic (CT availability, etc.)
    final filteredItems = _filterItemsByConditions(widget.sectionName, _pmItems);

    return Scaffold(
      extendBodyBehindAppBar: true,
      resizeToAvoidBottomInset: true,
      appBar: CustomFormAppbar(
        title: widget.pageTitle,
        onClose: () {
          if (_hasChanges) {
            _showUnsavedChangesDialog();
          } else {
            Navigator.pop(context);
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

                                  return PMCustomWidget(
                                    key: ValueKey(
                                      'pm_item_${pmItem['pm_check_list_site_resp_id']}_$index',
                                    ),
                                    pmItem: pmItem,
                                    readonlyFields: widget.readonlyFields,
                                    onValueChanged: (updatedItem) {
                                      if (mounted) {
                                        _onItemChanged(originalIndex, updatedItem);
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
          Navigator.pop(context);
        },
        onDiscard: () {
          Navigator.pop(context);
          Navigator.pop(context);
        },
        section: widget.pageTitle,
        parentContext: context,
      ),
    );
  }
}
