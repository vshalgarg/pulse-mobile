import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../commonWidgets/custom_form_appbar.dart';
import '../../../commonWidgets/custom_form_field.dart';
import '../../../commonWidgets/custom_dropdown.dart';
import '../../../commonWidgets/custom_buttons/arrow_botton.dart';
import '../../../commonWidgets/custom_dialogs/unsaved_changes_dialog.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_images.dart';
import '../../../constants/constants_methods.dart';

class CCUChecklistScreen extends StatefulWidget {
  final String siteId;
  final String siteName;

  const CCUChecklistScreen({
    super.key,
    required this.siteId,
    required this.siteName,
  });

  @override
  State<CCUChecklistScreen> createState() => _CCUChecklistScreenState();
}

class _CCUChecklistScreenState extends State<CCUChecklistScreen> {
  bool _isLoadingData = false;
  String? _errorMessage;

  // Controllers for text fields
  final TextEditingController _makeController = TextEditingController();
  final TextEditingController _ratingController = TextEditingController();
  final TextEditingController _countFaultyRectifiersController = TextEditingController();
  final TextEditingController _countNotOkRectifierBackplaneController = TextEditingController();
  final TextEditingController _countNotOkRectifierMcbController = TextEditingController();
  final TextEditingController _countNotOkMpptController = TextEditingController();
  final TextEditingController _countNotOkMpptMcbController = TextEditingController();
  final TextEditingController _countNotOkMpptBackplaneController = TextEditingController();

  // Dropdown selections
  String? _selectedControllerStatus;
  String? _selectedRectifierModuleStatus;
  String? _selectedFaultyRectifier;
  String? _selectedRectifierMcbStatus;
  String? _selectedRectifierBackplaneStatus;
  String? _selectedMpptStatus;
  String? _selectedFaultyMppt;
  String? _selectedMpptMcbStatus;
  String? _selectedCClassSpdStatus;
  String? _selectedLvdStatus;
  String? _selectedFuseStatus;
  String? _selectedMpptBackplaneStatus;

  bool _hasFormDataChanges = false;

  // Dynamic options based on count
  List<String> _faultyRectifierOptions = [];
  List<String> _faultyMpptOptions = [];

  @override
  void initState() {
    super.initState();
    _countFaultyRectifiersController.addListener(_updateFaultyRectifierOptions);
    _countNotOkMpptController.addListener(_updateFaultyMpptOptions);
    
    // Pre-fill with sample data
    _makeController.text = "Eicher";
    _ratingController.text = "1500 KW";
    _countFaultyRectifiersController.text = "0";
    _countNotOkRectifierBackplaneController.text = "0";
    _countNotOkRectifierMcbController.text = "0";
    _countNotOkMpptController.text = "0";
    _countNotOkMpptMcbController.text = "0";
    _countNotOkMpptBackplaneController.text = "0";
    
    _updateFaultyRectifierOptions();
    _updateFaultyMpptOptions();
  }

  @override
  void dispose() {
    _countFaultyRectifiersController.removeListener(_updateFaultyRectifierOptions);
    _countNotOkMpptController.removeListener(_updateFaultyMpptOptions);
    _makeController.dispose();
    _ratingController.dispose();
    _countFaultyRectifiersController.dispose();
    _countNotOkRectifierBackplaneController.dispose();
    _countNotOkRectifierMcbController.dispose();
    _countNotOkMpptController.dispose();
    _countNotOkMpptMcbController.dispose();
    _countNotOkMpptBackplaneController.dispose();
    super.dispose();
  }

  void _updateFaultyRectifierOptions() {
    final count = int.tryParse(_countFaultyRectifiersController.text) ?? 0;
    // Sample serial numbers - in real app, these would come from API
    final sampleSerialNumbers = [
      'SRN-2378',
      'SRN-1463', 
      'SRN-9075',
      'SRN-4521',
      'SRN-7890',
      'SRN-3456',
      'SRN-9012',
      'SRN-5678',
      'SRN-1234',
      'SRN-8901'
    ];
    
    _faultyRectifierOptions = count > 0 
        ? sampleSerialNumbers.take(count).toList()
        : ['Select'];
    setState(() {});
  }

  void _updateFaultyMpptOptions() {
    final count = int.tryParse(_countNotOkMpptController.text) ?? 0;
    // Sample MPPT serial numbers - in real app, these would come from API
    final sampleMpptSerialNumbers = [
      'MPPT-001',
      'MPPT-002', 
      'MPPT-003',
      'MPPT-004',
      'MPPT-005',
      'MPPT-006',
      'MPPT-007',
      'MPPT-008',
      'MPPT-009',
      'MPPT-010'
    ];
    
    _faultyMpptOptions = count > 0 
        ? sampleMpptSerialNumbers.take(count).toList()
        : ['Select'];
    setState(() {});
  }

  void _onFormChanged() {
    setState(() {
      _hasFormDataChanges = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      resizeToAvoidBottomInset: true,
      appBar: CustomFormAppbar(
        title: 'CCU Checklist',
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
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.of(context).viewInsets.bottom + 100,
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_isLoadingData)
                            const Center(
                              child: CircularProgressIndicator(
                                color: AppColors.primaryGreen,
                              ),
                            ),
                          if (_errorMessage != null)
                            Text(
                              _errorMessage!,
                              style: const TextStyle(color: AppColors.errorColor),
                            ),
                          if (!_isLoadingData && _errorMessage == null)
                            _buildFormFields(),
                        ],
                      ),
                    ),
                  ),
                ),

                // Bottom Button
                ArrowButton(
                  text: "Submit",
                  isLeftArrow: false,
                  backgroundColor: AppColors.buttonColorBg,
                  textColor: AppColors.buttonColorSite,
                  onPressed: _validateAndSubmit,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormFields() {
    return Column(
      children: [
        // Basic Information
        CustomFormField(
          label: "Rating",
          controller: _ratingController,
          isRequired: true,
          onChanged: (value) => _onFormChanged(),
        ),
        getHeight(15),
        
        CustomFormField(
          label: "Make",
          controller: _makeController,
          isRequired: true,
          onChanged: (value) => _onFormChanged(),
        ),
        getHeight(15),
        
        // Controller Status Dropdown
        CustomDropdown(
          label: "Controller Status",
          items: const ['Select', 'Ok', 'Not Ok', 'Faulty'],
          initialValue: _selectedControllerStatus,
          isRequired: true,
          onChanged: (value) {
            setState(() {
              _selectedControllerStatus = value;
              _onFormChanged();
            });
          },
        ),
        getHeight(15),
        
        // Rectifier Module Status Dropdown
        CustomDropdown(
          label: "Rectifier Module Status",
          items: const ['Select', 'Ok', 'Not Ok', 'Faulty'],
          initialValue: _selectedRectifierModuleStatus,
          isRequired: true,
          onChanged: (value) {
            setState(() {
              _selectedRectifierModuleStatus = value;
              _onFormChanged();
            });
          },
        ),
        getHeight(15),
        
        CustomFormField(
          label: "Count of Not OK Rectifier Module",
          controller: _countFaultyRectifiersController,
          isRequired: true,
          onChanged: (value) {
            _updateFaultyRectifierOptions();
            _onFormChanged();
          },
        ),
        getHeight(15),
        
        // S No of Faulty Rectifier Dropdown
        CustomDropdown(
          label: "S No of Faulty Rectifiers",
          items: _faultyRectifierOptions,
          initialValue: _selectedFaultyRectifier,
          isRequired: true,
          onChanged: (value) {
            setState(() {
              _selectedFaultyRectifier = value;
              _onFormChanged();
            });
          },
        ),
        getHeight(15),
        
        // Rectifier MCB Status Dropdown
        CustomDropdown(
          label: "Rectifier MCB Status",
          items: const ['Select', 'Ok', 'Not Ok', 'Faulty'],
          initialValue: _selectedRectifierMcbStatus,
          isRequired: true,
          onChanged: (value) {
            setState(() {
              _selectedRectifierMcbStatus = value;
              _onFormChanged();
            });
          },
        ),
        getHeight(15),
        
        CustomFormField(
          label: "Count of Not OK Rectifier MCB",
          controller: _countNotOkRectifierMcbController,
          isRequired: true,
          onChanged: (value) => _onFormChanged(),
        ),
        getHeight(15),
        
        // Rectifier Backplane Status Dropdown
        CustomDropdown(
          label: "Rectifier Backplane Status",
          items: const ['Select', 'Ok', 'Not Ok', 'Faulty'],
          initialValue: _selectedRectifierBackplaneStatus,
          isRequired: true,
          onChanged: (value) {
            setState(() {
              _selectedRectifierBackplaneStatus = value;
              _onFormChanged();
            });
          },
        ),
        getHeight(15),
        
        // S No of Faulty MPPT Dropdown
        CustomDropdown(
          label: "S No of Faulty MPPT",
          items: _faultyMpptOptions,
          initialValue: _selectedFaultyMppt,
          isRequired: true,
          onChanged: (value) {
            setState(() {
              _selectedFaultyMppt = value;
              _onFormChanged();
            });
          },
        ),
        getHeight(15),
        
        CustomFormField(
          label: "Count of Not OK Rectifier Backplane",
          controller: _countNotOkRectifierBackplaneController,
          isRequired: true,
          onChanged: (value) => _onFormChanged(),
        ),
        getHeight(15),
        
        // MPPT Status Dropdown
        CustomDropdown(
          label: "MPPT Status",
          items: const ['Select', 'Ok', 'Not Ok', 'Faulty'],
          initialValue: _selectedMpptStatus,
          isRequired: true,
          onChanged: (value) {
            setState(() {
              _selectedMpptStatus = value;
              _onFormChanged();
            });
          },
        ),
        getHeight(15),
        
        CustomFormField(
          label: "Count of Not OK MPPT",
          controller: _countNotOkMpptController,
          isRequired: true,
          onChanged: (value) {
            _updateFaultyMpptOptions();
            _onFormChanged();
          },
        ),
        getHeight(15),
        
        // MPPT MCB Status Dropdown
        CustomDropdown(
          label: "MPPT MCB Status",
          items: const ['Select', 'Ok', 'Not Ok', 'Faulty'],
          initialValue: _selectedMpptMcbStatus,
          isRequired: true,
          onChanged: (value) {
            setState(() {
              _selectedMpptMcbStatus = value;
              _onFormChanged();
            });
          },
        ),
        getHeight(15),
        
        // C Class SPD Status Dropdown
        CustomDropdown(
          label: "C Class SPD Status",
          items: const ['Select', 'Ok', 'Not Ok', 'Faulty'],
          initialValue: _selectedCClassSpdStatus,
          isRequired: true,
          onChanged: (value) {
            setState(() {
              _selectedCClassSpdStatus = value;
              _onFormChanged();
            });
          },
        ),
        getHeight(15),
        
        // LVD Status Dropdown
        CustomDropdown(
          label: "LVD Status",
          items: const ['Select', 'Ok', 'Not Ok', 'Faulty'],
          initialValue: _selectedLvdStatus,
          isRequired: true,
          onChanged: (value) {
            setState(() {
              _selectedLvdStatus = value;
              _onFormChanged();
            });
          },
        ),
        getHeight(15),
        
        // Fuse Status Dropdown
        CustomDropdown(
          label: "Fuse Status",
          items: const ['Select', 'Ok', 'Not Ok', 'Faulty'],
          initialValue: _selectedFuseStatus,
          isRequired: true,
          onChanged: (value) {
            setState(() {
              _selectedFuseStatus = value;
              _onFormChanged();
            });
          },
        ),
        getHeight(15),
        
        CustomFormField(
          label: "Count of Not OK MPPT MCB",
          controller: _countNotOkMpptMcbController,
          isRequired: true,
          onChanged: (value) => _onFormChanged(),
        ),
        getHeight(15),
        
        // MPPT Backplane Status Dropdown
        CustomDropdown(
          label: "MPPT Backplane Status",
          items: const ['Select', 'Ok', 'Not Ok', 'Faulty'],
          initialValue: _selectedMpptBackplaneStatus,
          isRequired: true,
          onChanged: (value) {
            setState(() {
              _selectedMpptBackplaneStatus = value;
              _onFormChanged();
            });
          },
        ),
        getHeight(15),
        
        CustomFormField(
          label: "Count of Not OK MPPT Backplane",
          controller: _countNotOkMpptBackplaneController,
          isRequired: true,
          onChanged: (value) => _onFormChanged(),
        ),
      ],
    );
  }

  void _validateAndSubmit() {
    if (_ratingController.text.isEmpty || _makeController.text.isEmpty) {
      showCustomToast(context, "Please fill all required fields");
      return;
    }

    // TODO: Call your API with JSON payload
    showCustomToast(context, "CCU Form Submitted Successfully ✅");
  }

  void _showUnsavedChangesDialog() {
    if (_hasFormDataChanges) {
      showDialog(
        context: context,
        builder: (ctx) => UnsavedChangesDialog(
          siteAuditSchId: widget.siteId,
          section: "CCU Checklist",
          parentContext: context,
          onSaveAndExit: () async {},
          onDiscard: () {},
        ),
      );
    } else {
      Navigator.pop(context);
    }
  }

  Future<void> postCurrentScreenData() async {}
}

// Widget for inline display in cm_create.dart
class CCUChecklistSection extends StatefulWidget {
  final VoidCallback onFormChanged;

  const CCUChecklistSection({
    super.key,
    required this.onFormChanged,
  });

  @override
  State<CCUChecklistSection> createState() => _CCUChecklistSectionState();
}

class _CCUChecklistSectionState extends State<CCUChecklistSection> {
  bool _isExpanded = false;
  
  // Controllers for text fields
  final TextEditingController _makeController = TextEditingController();
  final TextEditingController _ratingController = TextEditingController();
  final TextEditingController _countFaultyRectifiersController = TextEditingController();
  final TextEditingController _countNotOkRectifierBackplaneController = TextEditingController();
  final TextEditingController _countNotOkRectifierMcbController = TextEditingController();
  final TextEditingController _countNotOkMpptController = TextEditingController();
  final TextEditingController _countNotOkMpptMcbController = TextEditingController();
  final TextEditingController _countNotOkMpptBackplaneController = TextEditingController();

  // Dropdown selections
  String? _selectedControllerStatus;
  String? _selectedRectifierModuleStatus;
  String? _selectedFaultyRectifier;
  String? _selectedRectifierMcbStatus;
  String? _selectedRectifierBackplaneStatus;
  String? _selectedMpptStatus;
  String? _selectedFaultyMppt;
  String? _selectedMpptMcbStatus;
  String? _selectedCClassSpdStatus;
  String? _selectedLvdStatus;
  String? _selectedFuseStatus;
  String? _selectedMpptBackplaneStatus;

  // Dynamic options based on count
  List<String> _faultyRectifierOptions = [];
  List<String> _faultyMpptOptions = [];

  @override
  void initState() {
    super.initState();
    _countFaultyRectifiersController.addListener(_updateFaultyRectifierOptions);
    _countNotOkMpptController.addListener(_updateFaultyMpptOptions);
    
    // Pre-fill with sample data
    _makeController.text = "Eicher";
    _ratingController.text = "1500 KW";
    _countFaultyRectifiersController.text = "0";
    _countNotOkRectifierBackplaneController.text = "0";
    _countNotOkRectifierMcbController.text = "0";
    _countNotOkMpptController.text = "0";
    _countNotOkMpptMcbController.text = "0";
    _countNotOkMpptBackplaneController.text = "0";
    
    _updateFaultyRectifierOptions();
    _updateFaultyMpptOptions();
  }

  @override
  void dispose() {
    _countFaultyRectifiersController.removeListener(_updateFaultyRectifierOptions);
    _countNotOkMpptController.removeListener(_updateFaultyMpptOptions);
    _makeController.dispose();
    _ratingController.dispose();
    _countFaultyRectifiersController.dispose();
    _countNotOkRectifierBackplaneController.dispose();
    _countNotOkRectifierMcbController.dispose();
    _countNotOkMpptController.dispose();
    _countNotOkMpptMcbController.dispose();
    _countNotOkMpptBackplaneController.dispose();
    super.dispose();
  }

  void _updateFaultyRectifierOptions() {
    final count = int.tryParse(_countFaultyRectifiersController.text) ?? 0;
    // Sample serial numbers - in real app, these would come from API
    final sampleSerialNumbers = [
      'SRN-2378',
      'SRN-1463', 
      'SRN-9075',
      'SRN-4521',
      'SRN-7890',
      'SRN-3456',
      'SRN-9012',
      'SRN-5678',
      'SRN-1234',
      'SRN-8901'
    ];
    
    _faultyRectifierOptions = count > 0 
        ? sampleSerialNumbers.take(count).toList()
        : ['Select'];
    setState(() {});
  }

  void _updateFaultyMpptOptions() {
    final count = int.tryParse(_countNotOkMpptController.text) ?? 0;
    // Sample MPPT serial numbers - in real app, these would come from API
    final sampleMpptSerialNumbers = [
      'MPPT-001',
      'MPPT-002', 
      'MPPT-003',
      'MPPT-004',
      'MPPT-005',
      'MPPT-006',
      'MPPT-007',
      'MPPT-008',
      'MPPT-009',
      'MPPT-010'
    ];
    
    _faultyMpptOptions = count > 0 
        ? sampleMpptSerialNumbers.take(count).toList()
        : ['Select'];
    setState(() {});
  }

  void _onFormChanged() {
    widget.onFormChanged();
  }

  void _toggleExpansion() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
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
          // Accordion Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF00695C), // Dark teal background
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "CCU",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
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
          ),
          
          // Accordion Content
          if (_isExpanded)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
        
        // Basic Information
        CustomFormField(
          label: "Rating",
          controller: _ratingController,
          isRequired: true,
          onChanged: (value) => _onFormChanged(),
        ),
        getHeight(15),
        
        CustomFormField(
          label: "Make",
          controller: _makeController,
          isRequired: true,
          onChanged: (value) => _onFormChanged(),
        ),
        getHeight(15),
        
        // Controller Status Dropdown
        CustomDropdown(
          label: "Controller Status",
          items: const ['Select', 'Ok', 'Not Ok', 'Faulty'],
          initialValue: _selectedControllerStatus,
          isRequired: true,
          onChanged: (value) {
            setState(() {
              _selectedControllerStatus = value;
              _onFormChanged();
            });
          },
        ),
        getHeight(15),
        
        // Rectifier Module Status Dropdown
        CustomDropdown(
          label: "Rectifier Module Status",
          items: const ['Select', 'Ok', 'Not Ok', 'Faulty'],
          initialValue: _selectedRectifierModuleStatus,
          isRequired: true,
          onChanged: (value) {
            setState(() {
              _selectedRectifierModuleStatus = value;
              _onFormChanged();
            });
          },
        ),
        getHeight(15),
        
        CustomFormField(
          label: "Count of Not OK Rectifier Module",
          controller: _countFaultyRectifiersController,
          isRequired: true,
          onChanged: (value) {
            _updateFaultyRectifierOptions();
            _onFormChanged();
          },
        ),
        getHeight(15),
        
        // S No of Faulty Rectifier Dropdown
        CustomDropdown(
          label: "S No of Faulty Rectifiers",
          items: _faultyRectifierOptions,
          initialValue: _selectedFaultyRectifier,
          isRequired: true,
          onChanged: (value) {
            setState(() {
              _selectedFaultyRectifier = value;
              _onFormChanged();
            });
          },
        ),
        getHeight(15),
        
        // Rectifier MCB Status Dropdown
        CustomDropdown(
          label: "Rectifier MCB Status",
          items: const ['Select', 'Ok', 'Not Ok', 'Faulty'],
          initialValue: _selectedRectifierMcbStatus,
          isRequired: true,
          onChanged: (value) {
            setState(() {
              _selectedRectifierMcbStatus = value;
              _onFormChanged();
            });
          },
        ),
        getHeight(15),
        
        CustomFormField(
          label: "Count of Not OK Rectifier MCB",
          controller: _countNotOkRectifierMcbController,
          isRequired: true,
          onChanged: (value) => _onFormChanged(),
        ),
        getHeight(15),
        
        // Rectifier Backplane Status Dropdown
        CustomDropdown(
          label: "Rectifier Backplane Status",
          items: const ['Select', 'Ok', 'Not Ok', 'Faulty'],
          initialValue: _selectedRectifierBackplaneStatus,
          isRequired: true,
          onChanged: (value) {
            setState(() {
              _selectedRectifierBackplaneStatus = value;
              _onFormChanged();
            });
          },
        ),
        getHeight(15),
        
        // S No of Faulty MPPT Dropdown
        CustomDropdown(
          label: "S No of Faulty MPPT",
          items: _faultyMpptOptions,
          initialValue: _selectedFaultyMppt,
          isRequired: true,
          onChanged: (value) {
            setState(() {
              _selectedFaultyMppt = value;
              _onFormChanged();
            });
          },
        ),
        getHeight(15),
        
        CustomFormField(
          label: "Count of Not OK Rectifier Backplane",
          controller: _countNotOkRectifierBackplaneController,
          isRequired: true,
          onChanged: (value) => _onFormChanged(),
        ),
        getHeight(15),
        
        // MPPT Status Dropdown
        CustomDropdown(
          label: "MPPT Status",
          items: const ['Select', 'Ok', 'Not Ok', 'Faulty'],
          initialValue: _selectedMpptStatus,
          isRequired: true,
          onChanged: (value) {
            setState(() {
              _selectedMpptStatus = value;
              _onFormChanged();
            });
          },
        ),
        getHeight(15),
        
        CustomFormField(
          label: "Count of Not OK MPPT",
          controller: _countNotOkMpptController,
          isRequired: true,
          onChanged: (value) {
            _updateFaultyMpptOptions();
            _onFormChanged();
          },
        ),
        getHeight(15),
        
        // MPPT MCB Status Dropdown
        CustomDropdown(
          label: "MPPT MCB Status",
          items: const ['Select', 'Ok', 'Not Ok', 'Faulty'],
          initialValue: _selectedMpptMcbStatus,
          isRequired: true,
          onChanged: (value) {
            setState(() {
              _selectedMpptMcbStatus = value;
              _onFormChanged();
            });
          },
        ),
        getHeight(15),
        
        // C Class SPD Status Dropdown
        CustomDropdown(
          label: "C Class SPD Status",
          items: const ['Select', 'Ok', 'Not Ok', 'Faulty'],
          initialValue: _selectedCClassSpdStatus,
          isRequired: true,
          onChanged: (value) {
            setState(() {
              _selectedCClassSpdStatus = value;
              _onFormChanged();
            });
          },
        ),
        getHeight(15),
        
        // LVD Status Dropdown
        CustomDropdown(
          label: "LVD Status",
          items: const ['Select', 'Ok', 'Not Ok', 'Faulty'],
          initialValue: _selectedLvdStatus,
          isRequired: true,
          onChanged: (value) {
            setState(() {
              _selectedLvdStatus = value;
              _onFormChanged();
            });
          },
        ),
        getHeight(15),
        
        // Fuse Status Dropdown
        CustomDropdown(
          label: "Fuse Status",
          items: const ['Select', 'Ok', 'Not Ok', 'Faulty'],
          initialValue: _selectedFuseStatus,
          isRequired: true,
          onChanged: (value) {
            setState(() {
              _selectedFuseStatus = value;
              _onFormChanged();
            });
          },
        ),
        getHeight(15),
        
        CustomFormField(
          label: "Count of Not OK MPPT MCB",
          controller: _countNotOkMpptMcbController,
          isRequired: true,
          onChanged: (value) => _onFormChanged(),
        ),
        getHeight(15),
        
        // MPPT Backplane Status Dropdown
        CustomDropdown(
          label: "MPPT Backplane Status",
          items: const ['Select', 'Ok', 'Not Ok', 'Faulty'],
          initialValue: _selectedMpptBackplaneStatus,
          isRequired: true,
          onChanged: (value) {
            setState(() {
              _selectedMpptBackplaneStatus = value;
              _onFormChanged();
            });
          },
        ),
        getHeight(15),
        
        CustomFormField(
          label: "Count of Not OK MPPT Backplane",
          controller: _countNotOkMpptBackplaneController,
          isRequired: true,
          onChanged: (value) => _onFormChanged(),
        ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}