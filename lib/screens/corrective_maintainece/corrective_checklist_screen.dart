import 'dart:convert';
import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_images.dart';
import '../../constants/constants_methods.dart';
import '../../commonWidgets/custom_form_appbar.dart';
import '../../commonWidgets/custom_pm_bottom_buttons.dart';
import '../../commonWidgets/custom_dialogs/unsaved_changes_dialog.dart';
import 'cm_custom_widget.dart';
import 'checklist_preview_widget.dart';

class CorrectiveChecklistScreen extends StatefulWidget {
  final Map<String, dynamic> checklistData;
  final String? entityId;
  final VoidCallback? onFormChanged;

  const CorrectiveChecklistScreen({
    super.key,
    required this.checklistData,
    this.entityId,
    this.onFormChanged,
  });

  @override
  State<CorrectiveChecklistScreen> createState() => _CorrectiveChecklistScreenState();
}

class _CorrectiveChecklistScreenState extends State<CorrectiveChecklistScreen> {
  late List<Map<String, dynamic>> _checklistItems;
  bool _hasChanges = false;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeChecklistData();
  }

  void _initializeChecklistData() {
    try {
      final data = widget.checklistData['data'] as List<dynamic>? ?? [];
      
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
      setState(() {
        _errorMessage = 'Error initializing checklist data: $e';
      });
    }
  }

  void _onItemChanged(int index, Map<String, dynamic> updatedItem) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _checklistItems[index] = updatedItem;
          _hasChanges = true;
        });
        
        // Notify parent about form changes
        widget.onFormChanged?.call();
      }
    });
  }

  void _onLeftButtonPressed() {
    if (_hasChanges) {
      _showUnsavedChangesDialog();
    } else {
      Navigator.pop(context);
    }
  }

  Future<void> _onRightButtonPressed() async {
    // Validate all fields
    if (!_validateAllFields()) {
      _showValidationErrorDialog();
      return;
    }
    
    // Show loading
    setState(() {
      _isLoading = true;
    });
    
    try {
      // TODO: Implement save logic here
      await Future.delayed(const Duration(seconds: 1)); // Simulate API call
      
      if (mounted) {
        setState(() {
          _hasChanges = false;
          _isLoading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Checklist saved successfully'),
            backgroundColor: AppColors.primaryGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error saving checklist: $e';
        });
      }
    }
  }

  bool _validateAllFields() {
    for (final item in _checklistItems) {
      final respValue = item['resp'];
      final respType = item['resp_type']?.toString();
      final isMandatory = item['is_mandatory'] == true;
      
      if (isMandatory) {
        if (respValue == null || respValue.toString().trim().isEmpty) {
          return false;
        }
      }
    }
    return true;
  }

  void _showValidationErrorDialog() {
    final List<String> errors = [];
    
    for (final item in _checklistItems) {
      final respValue = item['resp'];
      final isMandatory = item['is_mandatory'] == true;
      final checklistDesc = item['checklist_desc']?.toString() ?? 'This field';
      
      if (isMandatory && (respValue == null || respValue.toString().trim().isEmpty)) {
        errors.add('$checklistDesc is required');
      }
    }
    
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
              ...errors.map((error) => Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Text('• $error'),
              )).toList(),
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

  void _showUnsavedChangesDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => UnsavedChangesDialog(
        message: 'You have unsaved changes. Do you want to save before leaving?',
        onSaveAndExit: () async {
          await _onRightButtonPressed();
          if (mounted) {
            Navigator.pop(context);
          }
        },
        onDiscard: () {
          Navigator.pop(context);
          Navigator.pop(context);
        },
        siteAuditSchId: widget.entityId,
        section: 'Corrective Checklist',
        parentContext: context,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      resizeToAvoidBottomInset: true,
      appBar: CustomFormAppbar(
        title: '${widget.checklistData['type']} Checklist',
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
            child: Image.asset(
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
                  child: _errorMessage != null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _errorMessage!,
                                style: const TextStyle(
                                  color: AppColors.white,
                                  fontSize: 16,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 20),
                              ElevatedButton(
                                onPressed: () {
                                  setState(() {
                                    _errorMessage = null;
                                  });
                                  _initializeChecklistData();
                                },
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        )
                      : SingleChildScrollView(
                          padding: EdgeInsets.only(
                            bottom: MediaQuery.of(context).viewInsets.bottom + 100,
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
                                // Render checklist items using pm_custom_widget
                                ..._checklistItems.asMap().entries.map((entry) {
                                  final index = entry.key;
                                  final checklistItem = entry.value;
                                  
                                  return CMCustomWidget(
                                    key: ValueKey('checklist_item_${checklistItem['item_type_id']}_$index'),
                                    pmItem: checklistItem,
                                    readonlyFields: [], // No readonly fields for corrective maintenance
                                    onValueChanged: (updatedItem) {
                                      _onItemChanged(index, updatedItem);
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
                // Bottom buttons
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Colors.transparent,
                  ),
                  child: CustomPMBottomButtons(
                    leftButtonText: "Cancel",
                    rightButtonText: "Save",
                    onLeftButtonPressed: _onLeftButtonPressed,
                    onRightButtonPressed: _onRightButtonPressed,
                    isLoading: _isLoading,
                    errorMessage: _errorMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
