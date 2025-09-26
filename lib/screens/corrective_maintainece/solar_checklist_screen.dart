import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../commonWidgets/custom_form_appbar.dart';
import '../../../commonWidgets/custom_form_field.dart';
import '../../../commonWidgets/custom_dropdown.dart';
import '../../../commonWidgets/custom_buttons/arrow_botton.dart';
import '../../../commonWidgets/custom_dialogs/unsaved_changes_dialog.dart';
import '../../../commonWidgets/asset_audit_form_component.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_images.dart';
import '../../../constants/constants_methods.dart';

class SolarChecklistScreen extends StatefulWidget {
  final String siteId;
  final String siteName;

  const SolarChecklistScreen({
    super.key,
    required this.siteId,
    required this.siteName,
  });

  @override
  State<SolarChecklistScreen> createState() => _SolarChecklistScreenState();
}

class _SolarChecklistScreenState extends State<SolarChecklistScreen> {
  bool _isLoadingData = false;
  String? _errorMessage;

  // Controllers for text fields
  final TextEditingController _makeController = TextEditingController();
  final TextEditingController _ratingController = TextEditingController();
  final TextEditingController _countNotOkSolarPanelController = TextEditingController();
  final TextEditingController _solarPanelSerialController = TextEditingController();
  final TextEditingController _outputVoltageController = TextEditingController();

  // Radio button selections
  String? _crackedBrokenGlass;
  String? _foundationIssue;
  String? _structureIssue;

  // Dropdown selections
  String? _selectedFaultyWiring;
  String? _selectedInverterFailure;

  // Saved solar panels list
  List<Map<String, dynamic>> _savedSolarPanels = [];

  bool _hasFormDataChanges = false;

  @override
  void initState() {
    super.initState();
    
    // Pre-fill with sample data
    _makeController.text = "Eicher";
    _ratingController.text = "5 KW";
    _countNotOkSolarPanelController.text = "2";
    _outputVoltageController.text = "97";
    
    // Pre-fill with sample saved solar panel
    _savedSolarPanels = [
      {
        'serialNumber': 'SP-19301',
        'scanned': true,
        'output': '97',
        'id': '1',
      }
    ];
  }

  @override
  void dispose() {
    _makeController.dispose();
    _ratingController.dispose();
    _countNotOkSolarPanelController.dispose();
    _solarPanelSerialController.dispose();
    _outputVoltageController.dispose();
    super.dispose();
  }

  void _onFormChanged() {
    setState(() {
      _hasFormDataChanges = true;
    });
  }

  void _onSolarPanelSaved(List<Map<String, dynamic>> savedItems) {
    setState(() {
      _savedSolarPanels = savedItems;
    });
  }

  void _onStatusChanged(bool? status) {
    // Handle status change if needed
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      resizeToAvoidBottomInset: true,
      appBar: CustomFormAppbar(
        title: 'Solar Checklist',
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
        // General Solar Panel Information
        CustomFormField(
          label: "Make",
          controller: _makeController,
          isRequired: true,
          onChanged: (value) => _onFormChanged(),
        ),
        getHeight(15),
        
        CustomFormField(
          label: "Rating",
          controller: _ratingController,
          isRequired: true,
          onChanged: (value) => _onFormChanged(),
        ),
        getHeight(15),
        
        // Cracked or Broken Glass Radio Buttons
        _buildRadioButtonGroup(
          "Cracked or Broken Glass",
          _crackedBrokenGlass,
          ["Yes", "No"],
          (value) {
            setState(() {
              _crackedBrokenGlass = value;
              _onFormChanged();
            });
          },
        ),
        getHeight(15),
        
        CustomFormField(
          label: "Count of Not OK Solar Panel",
          controller: _countNotOkSolarPanelController,
          isRequired: true,
          onChanged: (value) => _onFormChanged(),
        ),
        getHeight(15),
        
        // Solar Panel Serial Number and Output Voltage Section
        _buildSolarPanelSection(),
        getHeight(15),
        
        // Foundation issue Radio Buttons
        _buildRadioButtonGroup(
          "Foundation issue",
          _foundationIssue,
          ["Auto", "Manual"],
          (value) {
            setState(() {
              _foundationIssue = value;
              _onFormChanged();
            });
          },
        ),
        getHeight(15),
        
        // Faulty wiring Connection Dropdown
        CustomDropdown(
          label: "Faulty wiring Connection",
          items: const ['Select', 'Ok', 'Not Ok', 'Faulty'],
          initialValue: _selectedFaultyWiring,
          isRequired: true,
          onChanged: (value) {
            setState(() {
              _selectedFaultyWiring = value;
              _onFormChanged();
            });
          },
        ),
        getHeight(15),
        
        // Invertor Failure Dropdown
        CustomDropdown(
          label: "Invertor Failure",
          items: const ['Select', 'Ok', 'Not Ok', 'Faulty'],
          initialValue: _selectedInverterFailure,
          isRequired: true,
          onChanged: (value) {
            setState(() {
              _selectedInverterFailure = value;
              _onFormChanged();
            });
          },
        ),
        getHeight(15),
        
        // Structure issue Radio Buttons
        _buildRadioButtonGroup(
          "Structure issue",
          _structureIssue,
          ["Ok", "Not Ok"],
          (value) {
            setState(() {
              _structureIssue = value;
              _onFormChanged();
            });
          },
        ),
      ],
    );
  }

  Widget _buildRadioButtonGroup(String label, String? selectedValue, List<String> options, Function(String?) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label with asterisk
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: label,
                style: const TextStyle(
                  fontWeight: FontWeight.w400,
                  fontFamily: 'Montserrat',
                  fontSize: 16,
                  color: AppColors.white,
                ),
              ),
              const TextSpan(
                text: " *",
                style: TextStyle(
                  fontWeight: FontWeight.w400,
                  fontFamily: 'Montserrat',
                  fontSize: 16,
                  color: AppColors.errorColor,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        
        // Radio buttons
        Wrap(
          spacing: 20,
          children: options.map((option) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Radio<String>(
                  value: option,
                  groupValue: selectedValue,
                  onChanged: onChanged,
                  activeColor: const Color(0xFF5678BA),
                  fillColor: MaterialStateProperty.resolveWith<Color>((states) {
                    if (states.contains(MaterialState.selected)) {
                      return const Color(0xFF5678BA);
                    }
                    return Colors.white;
                  }),
                ),
                const SizedBox(width: 4),
                Text(
                  option,
                  style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 16,
                    fontFamily: 'Montserrat',
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }

  void _validateAndSubmit() {
    if (_makeController.text.isEmpty || 
        _ratingController.text.isEmpty || 
        _countNotOkSolarPanelController.text.isEmpty) {
      showCustomToast(context, "Please fill all required fields");
      return;
    }

    // TODO: Call your API with JSON payload
    showCustomToast(context, "Solar Form Submitted Successfully ✅");
  }

  void _showUnsavedChangesDialog() {
    if (_hasFormDataChanges) {
      showDialog(
        context: context,
        builder: (ctx) => UnsavedChangesDialog(
          siteAuditSchId: widget.siteId,
          section: "Solar Checklist",
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

  Widget _buildSolarPanelSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Solar Panel Serial Number
        _buildSerialNumberField(),
        getHeight(15),
        
        // Output Voltage of Solar Panel
        CustomFormField(
          label: "Output Voltage of Solar Panel",
          controller: _outputVoltageController,
          isRequired: true,
          onChanged: (value) => _onFormChanged(),
        ),
        getHeight(15),
        
        // Save Button
        Container(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _onSaveSolarPanelPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF5678BA),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              "Save",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                fontFamily: 'Montserrat',
              ),
            ),
          ),
        ),
        getHeight(15),
        
        // Saved Items Table
        if (_savedSolarPanels.isNotEmpty) _buildSavedItemsTable(),
      ],
    );
  }

  Widget _buildSerialNumberField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label with asterisk
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: "Solar Panel - Serial Number",
                style: const TextStyle(
                  fontWeight: FontWeight.w400,
                  fontFamily: 'Montserrat',
                  fontSize: 16,
                  color: AppColors.white,
                ),
              ),
              const TextSpan(
                text: " *",
                style: TextStyle(
                  fontWeight: FontWeight.w400,
                  fontFamily: 'Montserrat',
                  fontSize: 16,
                  color: AppColors.errorColor,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        
        // Text field with QR scanner icon
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.withOpacity(0.3)),
          ),
          child: TextFormField(
            controller: _solarPanelSerialController,
            onChanged: (value) => _onFormChanged(),
            decoration: InputDecoration(
              hintText: "Solar Panel Serial Number",
              hintStyle: TextStyle(
                color: Colors.grey.withOpacity(0.7),
                fontFamily: 'Montserrat',
                fontSize: 16,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              suffixIcon: GestureDetector(
                onTap: _onQRScanPressed,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    Icons.qr_code_scanner,
                    color: AppColors.primaryGreen,
                    size: 20,
                  ),
                ),
              ),
            ),
            style: const TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 16,
              color: Colors.black,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSavedItemsTable() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          // Table Header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    "Serial Number",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Montserrat',
                      fontSize: 14,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    "Scanned",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Montserrat',
                      fontSize: 14,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    "Output",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Montserrat',
                      fontSize: 14,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    "Edit",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Montserrat',
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Table Rows
          ..._savedSolarPanels.map((item) => Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: Colors.grey.withOpacity(0.3)),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    item['serialNumber'] ?? '',
                    style: const TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 14,
                    ),
                  ),
                ),
                Expanded(
                  child: Icon(
                    Icons.check_circle,
                    color: Colors.green,
                    size: 20,
                  ),
                ),
                Expanded(
                  child: Text(
                    item['output'] ?? '',
                    style: const TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 14,
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _onEditSolarPanel(item),
                    child: Icon(
                      Icons.edit,
                      color: AppColors.primaryGreen,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          )).toList(),
        ],
      ),
    );
  }

  void _onQRScanPressed() {
    // TODO: Implement QR scanner functionality
    showCustomToast(context, "QR Scanner functionality to be implemented");
  }

  void _onSaveSolarPanelPressed() {
    if (_solarPanelSerialController.text.isEmpty || _outputVoltageController.text.isEmpty) {
      showCustomToast(context, "Please fill all required fields");
      return;
    }

    // Add to saved items
    final newItem = {
      'serialNumber': _solarPanelSerialController.text,
      'output': _outputVoltageController.text,
      'scanned': true,
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
    };

    setState(() {
      _savedSolarPanels.add(newItem);
    });

    // Clear fields
    _solarPanelSerialController.clear();
    _outputVoltageController.clear();

    showCustomToast(context, "Solar Panel Saved Successfully ✅");
  }

  void _onEditSolarPanel(Map<String, dynamic> item) {
    // TODO: Implement edit functionality
    showCustomToast(context, "Edit functionality to be implemented");
  }
}

// Widget for inline display in cm_create.dart
class SolarChecklistSection extends StatefulWidget {
  final VoidCallback onFormChanged;

  const SolarChecklistSection({
    super.key,
    required this.onFormChanged,
  });

  @override
  State<SolarChecklistSection> createState() => _SolarChecklistSectionState();
}

class _SolarChecklistSectionState extends State<SolarChecklistSection> {
  bool _isExpanded = false;
  
  // Controllers for text fields
  final TextEditingController _makeController = TextEditingController();
  final TextEditingController _ratingController = TextEditingController();
  final TextEditingController _countNotOkSolarPanelController = TextEditingController();
  final TextEditingController _solarPanelSerialController = TextEditingController();
  final TextEditingController _outputVoltageController = TextEditingController();

  // Radio button selections
  String? _crackedBrokenGlass;
  String? _foundationIssue;
  String? _structureIssue;

  // Dropdown selections
  String? _selectedFaultyWiring;
  String? _selectedInverterFailure;

  // Saved solar panels list
  List<Map<String, dynamic>> _savedSolarPanels = [];

  @override
  void initState() {
    super.initState();
    
    // Pre-fill with sample data
    _makeController.text = "Eicher";
    _ratingController.text = "5 KW";
    _countNotOkSolarPanelController.text = "2";
    _outputVoltageController.text = "97";
    
    // Pre-fill with sample saved solar panel
    _savedSolarPanels = [
      {
        'serialNumber': 'SP-19301',
        'scanned': true,
        'output': '97',
        'id': '1',
      }
    ];
  }

  @override
  void dispose() {
    _makeController.dispose();
    _ratingController.dispose();
    _countNotOkSolarPanelController.dispose();
    _solarPanelSerialController.dispose();
    _outputVoltageController.dispose();
    super.dispose();
  }

  void _onFormChanged() {
    widget.onFormChanged();
  }

  void _onSolarPanelSaved(List<Map<String, dynamic>> savedItems) {
    setState(() {
      _savedSolarPanels = savedItems;
    });
  }

  void _onStatusChanged(bool? status) {
    // Handle status change if needed
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
                  "Solar",
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
                  // General Solar Panel Information
                  CustomFormField(
                    label: "Make",
                    controller: _makeController,
                    isRequired: true,
                    onChanged: (value) => _onFormChanged(),
                  ),
                  getHeight(15),
                  
                  CustomFormField(
                    label: "Rating",
                    controller: _ratingController,
                    isRequired: true,
                    onChanged: (value) => _onFormChanged(),
                  ),
                  getHeight(15),
                  
                  // Cracked or Broken Glass Radio Buttons
                  _buildRadioButtonGroup(
                    "Cracked or Broken Glass",
                    _crackedBrokenGlass,
                    ["Yes", "No"],
                    (value) {
                      setState(() {
                        _crackedBrokenGlass = value;
                        _onFormChanged();
                      });
                    },
                  ),
                  getHeight(15),
                  
                  CustomFormField(
                    label: "Count of Not OK Solar Panel",
                    controller: _countNotOkSolarPanelController,
                    isRequired: true,
                    onChanged: (value) => _onFormChanged(),
                  ),
                  getHeight(15),
                  
                  // Solar Panel Serial Number and Output Voltage Section
                  _buildSolarPanelSection(),
                  getHeight(15),
                  
                  // Foundation issue Radio Buttons
                  _buildRadioButtonGroup(
                    "Foundation issue",
                    _foundationIssue,
                    ["Auto", "Manual"],
                    (value) {
                      setState(() {
                        _foundationIssue = value;
                        _onFormChanged();
                      });
                    },
                  ),
                  getHeight(15),
                  
                  // Faulty wiring Connection Dropdown
                  CustomDropdown(
                    label: "Faulty wiring Connection",
                    items: const ['Select', 'Ok', 'Not Ok', 'Faulty'],
                    initialValue: _selectedFaultyWiring,
                    onChanged: (value) {
                      setState(() {
                        _selectedFaultyWiring = value;
                        _onFormChanged();
                      });
                    },
                  ),
                  getHeight(15),
                  
                  // Invertor Failure Dropdown
                  CustomDropdown(
                    label: "Invertor Failure",
                    items: const ['Select', 'Ok', 'Not Ok', 'Faulty'],
                    initialValue: _selectedInverterFailure,
                    onChanged: (value) {
                      setState(() {
                        _selectedInverterFailure = value;
                        _onFormChanged();
                      });
                    },
                  ),
                  getHeight(15),
                  
                  // Structure issue Radio Buttons
                  _buildRadioButtonGroup(
                    "Structure issue",
                    _structureIssue,
                    ["Ok", "Not Ok"],
                    (value) {
                      setState(() {
                        _structureIssue = value;
                        _onFormChanged();
                      });
                    },
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRadioButtonGroup(String label, String? selectedValue, List<String> options, Function(String?) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label with asterisk
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: label,
                style: const TextStyle(
                  fontWeight: FontWeight.w400,
                  fontFamily: 'Montserrat',
                  fontSize: 16,
                  color: AppColors.white,
                ),
              ),
              const TextSpan(
                text: " *",
                style: TextStyle(
                  fontWeight: FontWeight.w400,
                  fontFamily: 'Montserrat',
                  fontSize: 16,
                  color: AppColors.errorColor,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        
        // Radio buttons
        Wrap(
          spacing: 20,
          children: options.map((option) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Radio<String>(
                  value: option,
                  groupValue: selectedValue,
                  onChanged: onChanged,
                  activeColor: const Color(0xFF5678BA),
                  fillColor: MaterialStateProperty.resolveWith<Color>((states) {
                    if (states.contains(MaterialState.selected)) {
                      return const Color(0xFF5678BA);
                    }
                    return Colors.white;
                  }),
                ),
                const SizedBox(width: 4),
                Text(
                  option,
                  style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 16,
                    fontFamily: 'Montserrat',
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildSolarPanelSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Solar Panel Serial Number
        _buildSerialNumberField(),
        getHeight(15),
        
        // Output Voltage of Solar Panel
        CustomFormField(
          label: "Output Voltage of Solar Panel",
          controller: _outputVoltageController,
          isRequired: true,
          onChanged: (value) => _onFormChanged(),
        ),
        getHeight(15),
        
        // Save Button
        Container(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _onSaveSolarPanelPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF5678BA),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              "Save",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                fontFamily: 'Montserrat',
              ),
            ),
          ),
        ),
        getHeight(15),
        
        // Saved Items Table
        if (_savedSolarPanels.isNotEmpty) _buildSavedItemsTable(),
      ],
    );
  }

  Widget _buildSerialNumberField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label with asterisk
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: "Solar Panel - Serial Number",
                style: const TextStyle(
                  fontWeight: FontWeight.w400,
                  fontFamily: 'Montserrat',
                  fontSize: 16,
                  color: AppColors.white,
                ),
              ),
              const TextSpan(
                text: " *",
                style: TextStyle(
                  fontWeight: FontWeight.w400,
                  fontFamily: 'Montserrat',
                  fontSize: 16,
                  color: AppColors.errorColor,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        
        // Text field with QR scanner icon
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.withOpacity(0.3)),
          ),
          child: TextFormField(
            controller: _solarPanelSerialController,
            onChanged: (value) => _onFormChanged(),
            decoration: InputDecoration(
              hintText: "Solar Panel Serial Number",
              hintStyle: TextStyle(
                color: Colors.grey.withOpacity(0.7),
                fontFamily: 'Montserrat',
                fontSize: 16,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              suffixIcon: GestureDetector(
                onTap: _onQRScanPressed,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    Icons.qr_code_scanner,
                    color: AppColors.primaryGreen,
                    size: 20,
                  ),
                ),
              ),
            ),
            style: const TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 16,
              color: Colors.black,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSavedItemsTable() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          // Table Header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    "Serial Number",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Montserrat',
                      fontSize: 14,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    "Scanned",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Montserrat',
                      fontSize: 14,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    "Output",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Montserrat',
                      fontSize: 14,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    "Edit",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Montserrat',
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Table Rows
          ..._savedSolarPanels.map((item) => Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: Colors.grey.withOpacity(0.3)),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    item['serialNumber'] ?? '',
                    style: const TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 14,
                    ),
                  ),
                ),
                Expanded(
                  child: Icon(
                    Icons.check_circle,
                    color: Colors.green,
                    size: 20,
                  ),
                ),
                Expanded(
                  child: Text(
                    item['output'] ?? '',
                    style: const TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 14,
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _onEditSolarPanel(item),
                    child: Icon(
                      Icons.edit,
                      color: AppColors.primaryGreen,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          )).toList(),
        ],
      ),
    );
  }

  void _onQRScanPressed() {
    // TODO: Implement QR scanner functionality
    showCustomToast(context, "QR Scanner functionality to be implemented");
  }

  void _onSaveSolarPanelPressed() {
    if (_solarPanelSerialController.text.isEmpty || _outputVoltageController.text.isEmpty) {
      showCustomToast(context, "Please fill all required fields");
      return;
    }

    // Add to saved items
    final newItem = {
      'serialNumber': _solarPanelSerialController.text,
      'output': _outputVoltageController.text,
      'scanned': true,
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
    };

    setState(() {
      _savedSolarPanels.add(newItem);
    });

    // Clear fields
    _solarPanelSerialController.clear();
    _outputVoltageController.clear();

    showCustomToast(context, "Solar Panel Saved Successfully ✅");
  }

  void _onEditSolarPanel(Map<String, dynamic> item) {
    // TODO: Implement edit functionality
    showCustomToast(context, "Edit functionality to be implemented");
  }
}