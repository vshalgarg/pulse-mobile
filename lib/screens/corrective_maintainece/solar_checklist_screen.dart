import 'package:app/commonWidgets/custom_form_dropdown.dart';
import 'package:flutter/material.dart';
import '../../../commonWidgets/custom_form_field.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/constants_methods.dart';
import '../../../services/service_locator.dart';
import '../../../models/cm_checklist_model.dart';

class SMPSChecklistSection extends StatefulWidget {
  final VoidCallback onFormChanged;
  final int? entityId;

  const SMPSChecklistSection({
    super.key,
    required this.onFormChanged,
    this.entityId,
  });

  @override
  State<SMPSChecklistSection> createState() => _SMPSChecklistSectionState();
}

class _SMPSChecklistSectionState extends State<SMPSChecklistSection> {
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

    // Set initial state based on entityId
    if (widget.entityId == null) {
      setState(() {
        _errorMessage = 'Please select a site first';
        _isExpanded = false;
      });

    } else {
      setState(() {
        _isExpanded = false; // Always start collapsed
        _errorMessage = null;
      });

    }
  }

  void _initializeControllers() {
    _textControllers = {};
    _dropdownValues = {};
    _dynamicData = {};
  }

  @override
  void didUpdateWidget(SMPSChecklistSection oldWidget) {
    super.didUpdateWidget(oldWidget);

    // If entityId changed, reload data
    if (oldWidget.entityId != widget.entityId) {

      if (widget.entityId != null && _isExpanded) {

        _loadChecklistData();
      } else if (widget.entityId == null) {

        // Clear data if entityId becomes null
        setState(() {
          _checklistItems = [];
          _errorMessage = 'Please select a site first';
          _isExpanded = false;
        });
      } else {

        // Clear error message if entityId is now available
        setState(() {
          _errorMessage = null;
        });
      }
    }
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

      final List<CMChecklistItem> smpsItems = [];
      
      // Debug: Check what we received

      for (var item in smpsItems) {

      }
      
      setState(() {
        _checklistItems = smpsItems;
        
        // Initialize controllers based on response type
        for (var item in smpsItems) {
          if (item.respType == 'TEXT') {
            // Make and Rating fields should be empty for user input
            String defaultValue = '';
            if (item.checklistDesc.toLowerCase() == 'make' || 
                item.checklistDesc.toLowerCase() == 'rating') {
              defaultValue = ''; // Empty for user input
            }
            _textControllers[item.cmCheckListMstId] = TextEditingController(text: defaultValue);

          } else if (item.respType == 'DROPDOWN' || 
                     item.respType == 'MULTI_DYNAMIC_DROPDOWN' ||
                     item.respType == 'DYNAMIC_DROPDOWN') {
            _dropdownValues[item.cmCheckListMstId] = null;
          }
          
          // Handle dynamic dropdowns for rectifiers and MPPTs
          if (item.respType == 'MULTI_DYNAMIC_DROPDOWN') {
            _dynamicData[item.cmCheckListMstId] = [];
          }
        }
        
        _isLoading = false;
      });

      widget.onFormChanged();

    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load checklist data: $e';
        _isLoading = false;
      });

    }
  }

  void _toggleExpansion() {

    if (_isExpanded) {
      setState(() {
        _isExpanded = false;
      });

    } else {
      if (widget.entityId == null) {
        setState(() {
          _errorMessage = 'Please select a site first';
          _isExpanded = false;
        });

        return;
      }
      setState(() {
        _isExpanded = true;
        _errorMessage = null; // Clear any previous error
      });

      // Only load data if we don't have any checklist items yet
      if (_checklistItems.isEmpty) {

        _loadChecklistData();
      } else {

      }
    }
  }

  Widget _buildChecklistItem(CMChecklistItem item) {
    if (item.checklistDesc.isEmpty) return const SizedBox.shrink();
    
    switch (item.respType) {
      case 'TEXT':
        return _buildTextField(item);
      case 'DROPDOWN':
        return _buildDropdownField(item);
      case 'MULTI_DYNAMIC_DROPDOWN':
        return _buildMultiDynamicDropdownField(item);
      default:
        return _buildTextField(item); // Fallback for unknown types
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

  Widget _buildMultiDynamicDropdownField(CMChecklistItem item) {
    final currentItems = _dynamicData[item.cmCheckListMstId] ?? [];
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          item.checklistDesc,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        
        // Display current items
        if (currentItems.isNotEmpty) ...[
          ...currentItems.map((rectifier) {
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Serial: ${rectifier['serial'] ?? 'N/A'}',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _removeDynamicItem(item.cmCheckListMstId, rectifier['id']),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 10),
        ],
        
        // Add new item section
        Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: TextFormField(
                  decoration: InputDecoration(
                    hintText: 'Enter ${item.checklistDesc}',
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  onChanged: (value) {
                    // Store temporary value
                  },
                ),
              ),
            ),
            const SizedBox(width: 10),
            ElevatedButton(
              onPressed: () => _addDynamicItem(item.cmCheckListMstId, item.checklistDesc),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5678BA),
                foregroundColor: Colors.white,
              ),
              child: const Text('Add'),
            ),
          ],
        ),
        
        if (item.isMandatory)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text(
              '* Required',
              style: TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),
      ],
    );
  }

  void _addDynamicItem(int parentId, String itemType) {
    // In real app, this would get data from API or user input
    final newItem = {
      'id': DateTime.now().millisecondsSinceEpoch,
      'serial': '${itemType.split(' ').last}-${DateTime.now().millisecondsSinceEpoch}',
      'type': itemType,
    };
    
    setState(() {
      if (_dynamicData[parentId] == null) {
        _dynamicData[parentId] = [newItem];
      } else {
        _dynamicData[parentId]!.add(newItem);
      }
    });
    widget.onFormChanged();
  }

  void _removeDynamicItem(int parentId, dynamic itemId) {
    setState(() {
      _dynamicData[parentId]?.removeWhere((item) => item['id'] == itemId);
    });
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
                  "SMPS",
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
                          Text('Loading SMPS checklist...', style: TextStyle(color: Colors.white)),
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
                        'No checklist items found for SMPS',
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
      } else if (item.respType == 'MULTI_DYNAMIC_DROPDOWN') {
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
        } else if (item.respType == 'DROPDOWN') {
          if (_dropdownValues[item.cmCheckListMstId] == null) {
            return false;
          }
        } else if (item.respType == 'MULTI_DYNAMIC_DROPDOWN') {
          if (_dynamicData[item.cmCheckListMstId]?.isEmpty ?? true) {
            return false;
          }
        }
      }
    }
    return true;
  }
}