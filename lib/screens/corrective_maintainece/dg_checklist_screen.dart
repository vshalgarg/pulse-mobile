import 'package:flutter/material.dart';
import '../../../commonWidgets/custom_form_field.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/constants_methods.dart';
import '../../../services/service_locator.dart';
import '../../../models/cm_checklist_model.dart';
import '../../../services/api_service.dart';

class DGChecklistSection extends StatefulWidget {
  final VoidCallback onFormChanged;
  final int? entityId;

  const DGChecklistSection({
    super.key,
    required this.onFormChanged,
    this.entityId,
  });

  @override
  State<DGChecklistSection> createState() => _DGChecklistSectionState();
}

class _DGChecklistSectionState extends State<DGChecklistSection> {
  bool _isExpanded = false; // Start collapsed
  bool _isLoading = false;
  String? _errorMessage;
  
  List<CMChecklistItem> _checklistItems = [];
  Map<int, TextEditingController> _textControllers = {};
  Map<int, String?> _radioValues = {};

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    // Load checklist data automatically if entityId is available
    if (widget.entityId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadChecklistData();
      });
    } else {
      // If no entityId, collapse the section
      _isExpanded = false;
    }
  }

  @override
  void didUpdateWidget(DGChecklistSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Clear error message when entityId changes, but don't auto-expand
    if (oldWidget.entityId != widget.entityId) {
      if (widget.entityId != null) {
        print('🔄 [DGChecklist] EntityId changed to ${widget.entityId}, clearing errors');
        setState(() {
          _errorMessage = null;
        });
        // If already expanded, reload data
        if (_isExpanded) {
          _loadChecklistData();
        }
      } else {
        print('🔄 [DGChecklist] EntityId is null, collapsing section');
        setState(() {
          _isExpanded = false;
          _errorMessage = null;
        });
      }
    }
  }

  void _initializeControllers() {
    _textControllers = {};
    _radioValues = {};
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
      print('⚠️ [DGChecklist] entityId is null, cannot load data');
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

      print('🔄 [DGChecklist] Loading checklist data for entityId: ${widget.entityId}');
      
      // Check if ServiceLocator is initialized
      if (!ServiceLocator().isInitialized) {
        print('❌ [DGChecklist] ServiceLocator not initialized');
        throw Exception('ServiceLocator not initialized. Please restart the app.');
      }
      
      print('✅ [DGChecklist] ServiceLocator is initialized');
      
      CMChecklistResponse response;
      try {
        response = await ServiceLocator().cmChecklistRepository.getChecklistData(
          widget.entityId!,
          'DG',
        );
      } catch (e) {
        print('⚠️ [DGChecklist] ServiceLocator method failed, trying direct API call: $e');
        
        // Fallback: Use ApiService directly
        final apiService = ServiceLocator().apiService;
        final apiResponse = await apiService.get<Map<String, dynamic>>(
          path: '/api/v1/mobile/correctiveMaintenance/checkListDtlForMobile/${widget.entityId}/DG',
        );
        
        if (apiResponse.isSuccess && apiResponse.data != null) {
          response = CMChecklistResponse.fromJson(apiResponse.data!);
        } else {
          throw Exception('API call failed: ${apiResponse.errorMessage}');
        }
      }

      print('🔍 [DGChecklist] Response received: ${response.data}');
      final allDgItems = response.getDGChecklist();
      // Filter out items with empty descriptions
      final dgItems = allDgItems.where((item) => item.checklistDesc.trim().isNotEmpty).toList();
      print('📋 [DGChecklist] DG items count: ${dgItems.length} (filtered from ${allDgItems.length})');
      
      if (dgItems.isNotEmpty) {
        print('📝 [DGChecklist] First item: ${dgItems.first.checklistDesc} (${dgItems.first.respType})');
      }
      
      
      setState(() {
        _checklistItems = dgItems;
        
        // Initialize controllers with default values
        for (var item in dgItems) {
          if (item.respType == 'TEXT') {
            String defaultValue = '';
            
            // Set default values based on field names
            if (item.checklistDesc.toLowerCase().contains('rating')) {
              defaultValue = '1500 KW';
            } else if (item.checklistDesc.toLowerCase().contains('phase')) {
              defaultValue = '3';
            } else if (item.checklistDesc.toLowerCase().contains('make')) {
              defaultValue = 'Eicher';
            }
            
            _textControllers[item.cmCheckListMstId] = TextEditingController(text: defaultValue);
            print('🔄 [DGChecklist] Initialized ${item.checklistDesc} with value: "$defaultValue"');
          } else if (item.respType == 'RADIO') {
            // Set default radio values to match the image
            String defaultValue = 'OK'; // Default to "OK" for all radio buttons
            
            // Special case for DG Canopy Cleanliness - should be "Auto" if available, otherwise "OK"
            if (item.checklistDesc.toLowerCase().contains('canopy')) {
              final options = item.radioOptions ?? {};
              if (options.containsKey('AUTO')) {
                defaultValue = 'AUTO';
              } else {
                defaultValue = 'OK';
              }
            }
            
            _radioValues[item.cmCheckListMstId] = defaultValue;
            print('🔄 [DGChecklist] Initialized ${item.checklistDesc} radio with default: "$defaultValue"');
          }
        }
        
        _isLoading = false;
      });

      print('✅ [DGChecklist] Loaded ${dgItems.length} checklist items');
      widget.onFormChanged();

    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load checklist data: $e';
        _isLoading = false;
      });
      print('❌ [DGChecklist] Error loading data: $e');
    }
  }

  void _toggleExpansion() {
    print('🔄 [DGChecklist] Toggle expansion called. Current state: $_isExpanded');
    print('🔄 [DGChecklist] EntityId: ${widget.entityId}');
    
    if (_isExpanded) {
      setState(() {
        _isExpanded = false;
      });
      print('🔄 [DGChecklist] Collapsed section');
    } else {
      if (widget.entityId == null) {
        print('⚠️ [DGChecklist] Cannot expand - no site selected');
        // Show error message
        setState(() {
          _errorMessage = 'Please select a site first';
          _isExpanded = true; // Show error message
        });
        return;
      }
      setState(() {
        _isExpanded = true;
        _errorMessage = null; // Clear any previous errors
      });
      print('🔄 [DGChecklist] Expanded section, loading data...');
      _loadChecklistData();
    }
  }

  Widget _buildChecklistItem(CMChecklistItem item) {
    if (item.checklistDesc.isEmpty) return const SizedBox.shrink();
    
    switch (item.respType) {
      case 'TEXT':
        return _buildTextField(item);
      case 'RADIO':
        return _buildRadioField(item);
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

  Widget _buildRadioField(CMChecklistItem item) {
    final currentValue = _radioValues[item.cmCheckListMstId];
    final options = item.radioOptions ?? {'OK': 'OK', 'Not OK': 'Not OK'};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: item.checklistDesc,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.white),
              ),
              if (item.isMandatory)
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
        // Use Row instead of Wrap for horizontal layout
        Row(
          children: options.entries.map((entry) {
            return Expanded(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Radio<String>(
                    value: entry.key,
                    groupValue: currentValue,
                    onChanged: (value) {
                      setState(() {
                        _radioValues[item.cmCheckListMstId] = value;
                      });
                      widget.onFormChanged();
                    },
                    activeColor: const Color(0xFF1976D2), // Bright blue for selected
                    fillColor: MaterialStateProperty.resolveWith<Color>((Set<MaterialState> states) {
                      if (states.contains(MaterialState.selected)) {
                        return const Color(0xFF1976D2); // Bright blue when selected
                      }
                      return Colors.white; // White when not selected
                    }),
                    overlayColor: MaterialStateProperty.resolveWith<Color>((Set<MaterialState> states) {
                      return Colors.white.withOpacity(0.1); // Subtle overlay
                    }),
                  ),
                  Text(
                    entry.value, 
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 8), // Add spacing between radio buttons
                ],
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 12), // Add spacing after each radio group
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.withOpacity(0.5)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
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
                  "DG",
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
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF00695C), // Dark teal at top
                    const Color(0xFF00897B), // Lighter teal at bottom
                  ],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                  if (_isLoading)
                    const Center(
                      child: Column(
                        children: [
                          CircularProgressIndicator(color: AppColors.primaryGreen),
                          SizedBox(height: 16),
                          Text('Loading DG checklist...', style: TextStyle(color: Colors.white)),
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
                        'No checklist items found for DG',
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
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> getChecklistData() {
    final data = <String, dynamic>{};
    
    for (var item in _checklistItems) {
      if (item.respType == 'TEXT') {
        final controller = _textControllers[item.cmCheckListMstId];
        data[item.checklistDesc] = controller?.text ?? '';
      } else if (item.respType == 'RADIO') {
        data[item.checklistDesc] = _radioValues[item.cmCheckListMstId];
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
        } else if (item.respType == 'RADIO') {
          if (_radioValues[item.cmCheckListMstId] == null) {
            return false;
          }
        }
      }
    }
    return true;
  }
}