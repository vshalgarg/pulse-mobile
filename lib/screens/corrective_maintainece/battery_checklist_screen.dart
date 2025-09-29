import 'package:app/commonWidgets/custom_form_dropdown.dart';
import 'package:flutter/material.dart';
import '../../../commonWidgets/custom_form_field.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/constants_methods.dart';
import '../../../services/service_locator.dart';
import '../../../models/cm_checklist_model.dart';

class BatteryChecklistSection extends StatefulWidget {
  final VoidCallback onFormChanged;
  final int? entityId;

  const BatteryChecklistSection({
    super.key,
    required this.onFormChanged,
    this.entityId,
  });

  @override
  State<BatteryChecklistSection> createState() => _BatteryChecklistSectionState();
}

class _BatteryChecklistSectionState extends State<BatteryChecklistSection> {
  bool _isExpanded = false;
  bool _isLoading = false;
  String? _errorMessage;
  
  List<CMChecklistItem> _checklistItems = [];
  Map<int, TextEditingController> _textControllers = {};
  Map<int, String?> _dropdownValues = {};
  Map<int, List<Map<String, dynamic>>> _dynamicData = {};

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    // Load checklist data automatically if entityId is available
    if (widget.entityId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadChecklistData();
      });
    }
  }

  @override
  void didUpdateWidget(BatteryChecklistSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Clear error message when entityId changes, but don't auto-expand
    if (oldWidget.entityId != widget.entityId) {
      if (widget.entityId != null) {
        print('🔄 [BatteryChecklist] EntityId changed to ${widget.entityId}, clearing errors');
        setState(() {
          _errorMessage = null;
        });
        // If already expanded, reload data
        if (_isExpanded) {
          _loadChecklistData();
        }
      } else {
        print('🔄 [BatteryChecklist] EntityId is null, collapsing section');
        setState(() {
          _isExpanded = false;
          _errorMessage = null;
        });
      }
    }
  }

  void _initializeControllers() {
    _textControllers = {};
    _dropdownValues = {};
    _dynamicData = {};
  }

  @override
  void dispose() {
    for (var controller in _textControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadChecklistData() async {
    if (widget.entityId == null) {
      print('⚠️ [BatteryChecklist] entityId is null, cannot load data');
      setState(() {
        _errorMessage = 'Please select a site first';
      });
      return;
    }

    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });


      // final response = await ServiceLocator().cmChecklistRepository.getChecklistData(
      //   widget.entityId!,
      // );

      final List<CMChecklistItem> batteryItems = [];
      print('📋 [BatteryChecklist] Battery items count: ${batteryItems.length}');
      
      // Debug: Check the type of items being returned
      if (batteryItems.isNotEmpty) {
        print('🔍 [BatteryChecklist] First item type: ${batteryItems.first.runtimeType}');
        print('🔍 [BatteryChecklist] First item: ${batteryItems.first}');
      }
      
      setState(() {
        _checklistItems = batteryItems;
        
        // Initialize controllers with default values to match the image
        for (var item in batteryItems) {
          // Safety check: Ensure item is a CMChecklistItem
          if (item is! CMChecklistItem) {
            print('❌ [BatteryChecklist] Invalid item type: ${item.runtimeType}');
            continue;
          }
          
          if (item.respType == 'TEXT') {
            String defaultValue = '';
            
            // Only set default values for SOC and SOH (child items), not for main fields
            // Main fields like Make, Rating, No. of Not OK Batteries should be empty for user input
            if (item.checklistDesc.toLowerCase().contains('soc')) {
              defaultValue = '97';
            } else if (item.checklistDesc.toLowerCase().contains('soh')) {
              defaultValue = '100';
            }
            // Make, Rating, No. of Not OK Batteries will have empty defaultValue = ''
            
            _textControllers[item.cmCheckListMstId] = TextEditingController(text: defaultValue);
            print('🔄 [BatteryChecklist] Initialized ${item.checklistDesc} with value: "${defaultValue.isEmpty ? "empty" : defaultValue}"');
          } else if (item.respType == 'DROPDOWN' || item.respType == 'DYNAMIC_DROPDOWN') {
            _dropdownValues[item.cmCheckListMstId] = null;
          }
          
          // Handle child items for dynamic dropdowns
          if (item.childitemData.isNotEmpty) {
            _dynamicData[item.cmCheckListMstId] = [];
            // Initialize child item controllers with default values
            for (var childItem in item.childitemData) {
              // Safety check: Ensure childItem is a CMChecklistItem
              if (childItem is! CMChecklistItem) {
                print('❌ [BatteryChecklist] Invalid child item type: ${childItem.runtimeType}');
                continue;
              }
              
              if (childItem.respType == 'TEXT') {
                String childDefaultValue = '';
                // Only set default values for SOC and SOH child items
                if (childItem.checklistDesc.toLowerCase().contains('soc')) {
                  childDefaultValue = '97';
                } else if (childItem.checklistDesc.toLowerCase().contains('soh')) {
                  childDefaultValue = '100';
                }
                // Other child items will have empty defaultValue = ''
                
                _textControllers[childItem.cmCheckListMstId] = TextEditingController(text: childDefaultValue);
                print('🔄 [BatteryChecklist] Initialized child ${childItem.checklistDesc} with value: "${childDefaultValue.isEmpty ? "empty" : childDefaultValue}"');
              }
            }
          }
        }
        
        _isLoading = false;
      });

      print('✅ [BatteryChecklist] Loaded ${batteryItems.length} checklist items');
      widget.onFormChanged();

    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load checklist data: $e';
        _isLoading = false;
      });
      print('❌ [BatteryChecklist] Error loading data: $e');
    }
  }

  void _toggleExpansion() {
    if (_isExpanded) {
      setState(() {
        _isExpanded = false;
      });
    } else {
      setState(() {
        _isExpanded = true;
      });
      _loadChecklistData();
    }
  }

  Widget _buildChecklistItem(CMChecklistItem item) {
    if (item.checklistDesc.isEmpty) return const SizedBox.shrink();
    
    switch (item.respType) {
      case 'TEXT':
        return _buildTextField(item);
      case 'DROPDOWN':
        return _buildDropdownField(item);
      case 'DYNAMIC_DROPDOWN':
        return _buildDynamicDropdownField(item);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildTextField(CMChecklistItem item) {
    final controller = _textControllers[item.cmCheckListMstId] ?? TextEditingController();
    
    return CustomFormField(
      label: item.checklistDesc,
      controller: controller,
      isRequired: item.isMandatory,
      onChanged: (_) => widget.onFormChanged(),
    );
  }

  Widget _buildDropdownField(CMChecklistItem item) {
    final currentValue = _dropdownValues[item.cmCheckListMstId];
    final options = item.radioOptions ?? {'OK': 'OK', 'Not OK': 'Not OK'};
    final optionList = options.values.toList();

    return CustomDropdown(
      label: item.checklistDesc,
      items: optionList,
      initialValue: currentValue,
      onChanged: (value) {
        setState(() {
          _dropdownValues[item.cmCheckListMstId] = value;
        });
        widget.onFormChanged();
      },
      isRequired: item.isMandatory,
    );
  }

  Widget _buildDynamicDropdownField(CMChecklistItem item) {
    // For Battery field, show backend-driven data instead of dropdown selection
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Battery Serial Number Field (Backend-driven)
        Container(
          margin: const EdgeInsets.only(bottom: 15),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: "Battery - Serial Number",
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.white),
                    ),
                    const TextSpan(
                      text: " *",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        child: Text(
                          "Battery Serial Number", // Backend data will be displayed here
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Icon(
                        Icons.qr_code_scanner,
                        color: Colors.grey[600],
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        // SOC Field (Backend-driven)
        _buildBackendTextField("SOC", "97", item.cmCheckListMstId, 'soc'),
        const SizedBox(height: 15),
        
        // SOH Field (Backend-driven)
        _buildBackendTextField("SOH", "100", item.cmCheckListMstId, 'soh'),
        const SizedBox(height: 15),
        
        // Save Button
        Container(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => _saveBatteryData(item.cmCheckListMstId),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF5678BA),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: const Text("Save"),
          ),
        ),
        const SizedBox(height: 15),
        
        // Scanned Battery List Header
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: const Row(
            children: [
              Expanded(child: Text("Serial Number", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500))),
              Expanded(child: Text("Scanned", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500))),
              Expanded(child: Text("SOC", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500))),
              Expanded(child: Text("SOH", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500))),
              Expanded(child: Text("Edit", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500))),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBackendTextField(String label, String defaultValue, int parentId, String fieldType) {
    final controller = TextEditingController(text: defaultValue);
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: label,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.white),
              ),
              const TextSpan(
                text: " *",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.red,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.withOpacity(0.3)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: TextField(
              controller: controller,
              style: const TextStyle(fontSize: 16),
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: "",
              ),
              onChanged: (value) {
                // Store the value for backend sync
                widget.onFormChanged();
              },
            ),
          ),
        ),
      ],
    );
  }

  void _saveBatteryData(int parentId) {
    // This will be called when Save button is pressed
    // Data will be sent to backend
    print('🔄 [BatteryChecklist] Saving battery data for parent: $parentId');
    widget.onFormChanged();
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
                const Text(
                  "Battery Checklist",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                Row(
                  children: [
                    if (_isLoading)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
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
              ],
            ),
          ),
          
          if (_isExpanded)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isLoading)
                    const Center(
                      child: Column(
                        children: [
                          CircularProgressIndicator(color: AppColors.primaryGreen),
                          SizedBox(height: 16),
                          Text('Loading Battery checklist...', style: TextStyle(color: Colors.white)),
                        ],
                      ),
                    ),

                  if (_errorMessage != null)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.errorColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.errorColor),
                      ),
                      child: Text(_errorMessage!, style: TextStyle(color: AppColors.errorColor)),
                    ),

                  if (!_isLoading && _errorMessage == null) ...[
                    if (_checklistItems.isEmpty)
                      const Text(
                        'No checklist items found for Battery',
                        style: TextStyle(color: Colors.white),
                      )
                    else
                      ..._checklistItems.map((item) {
                        return Column(
                          children: [
                            _buildChecklistItem(item),
                            getHeight(15),
                          ],
                        );
                      }).toList(),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Map<String, dynamic> getChecklistData() {
    final data = <String, dynamic>{};
    
    // Text fields
    for (var item in _checklistItems) {
      if (item.respType == 'TEXT') {
        final controller = _textControllers[item.cmCheckListMstId];
        data[item.checklistDesc] = controller?.text ?? '';
      } else if (item.respType == 'DROPDOWN') {
        data[item.checklistDesc] = _dropdownValues[item.cmCheckListMstId];
      } else if (item.respType == 'DYNAMIC_DROPDOWN') {
        data[item.checklistDesc] = _dynamicData[item.cmCheckListMstId] ?? [];
      }
    }
    
    return data;
  }

  bool validateChecklist() {
    for (var item in _checklistItems) {
      if (item.isMandatory) {
        if (item.respType == 'TEXT') {
          final controller = _textControllers[item.cmCheckListMstId];
          if (controller == null || controller.text.isEmpty) {
            return false;
          }
        } else if (item.respType == 'DROPDOWN' || item.respType == 'DYNAMIC_DROPDOWN') {
          if (_dropdownValues[item.cmCheckListMstId] == null) {
            return false;
          }
        }
      }
    }
    return true;
  }
}