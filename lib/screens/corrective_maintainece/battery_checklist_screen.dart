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

class BatteryChecklistScreen extends StatefulWidget {
  final String siteId;
  final String siteName;

  const BatteryChecklistScreen({
    super.key,
    required this.siteId,
    required this.siteName,
  });

  @override
  State<BatteryChecklistScreen> createState() => _BatteryChecklistScreenState();
}

class _BatteryChecklistScreenState extends State<BatteryChecklistScreen> {
  bool _isLoadingData = false;
  String? _errorMessage;

  // Controllers for text fields
  final TextEditingController _ratingController = TextEditingController();
  final TextEditingController _makeController = TextEditingController();
  final TextEditingController _noOfNotOkBatteriesController = TextEditingController();
  final TextEditingController _batterySerialController = TextEditingController();
  final TextEditingController _socController = TextEditingController();
  final TextEditingController _sohController = TextEditingController();

  // Dropdown selections
  String? _selectedCbmsStatus;
  String? _selectedBatteryPosTerminal;
  String? _selectedBatteryNegTerminal;

  // Saved batteries list
  List<Map<String, dynamic>> _savedBatteries = [];

  bool _hasFormDataChanges = false;

  // Dropdown options
  final List<String> _cbmsStatusOptions = ['Select', 'Ok', 'Not Ok', 'Faulty'];
  final List<String> _terminalOptions = ['Select', 'Ok', 'Not Ok', 'Faulty'];

  @override
  void initState() {
    super.initState();
    
    // Pre-fill with sample data
    _ratingController.text = "1500 KW";
    _makeController.text = "Eicher";
    _noOfNotOkBatteriesController.text = "8";
    _socController.text = "97";
    _sohController.text = "100";
  }

  @override
  void dispose() {
    _ratingController.dispose();
    _makeController.dispose();
    _noOfNotOkBatteriesController.dispose();
    _batterySerialController.dispose();
    _socController.dispose();
    _sohController.dispose();
    super.dispose();
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
        title: 'Battery Checklist',
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
        // General Battery Information
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
        
        CustomFormField(
          label: "No of Not OK Batteries",
          controller: _noOfNotOkBatteriesController,
          isRequired: true,
          onChanged: (value) => _onFormChanged(),
        ),
        getHeight(15),
        
        // Battery Serial Number and SOC/SOH Section
        _buildBatterySection(),
        getHeight(15),
        
        // CBMS Status Dropdown
        CustomDropdown(
          label: "CBMS Status",
          items: _cbmsStatusOptions,
          initialValue: _selectedCbmsStatus,
          isRequired: true,
          onChanged: (value) {
            setState(() {
              _selectedCbmsStatus = value;
              _onFormChanged();
            });
          },
        ),
        getHeight(15),
        
        // Battery Terminal Dropdowns
        CustomDropdown(
          label: "Battery +ve Terminal",
          items: _terminalOptions,
          initialValue: _selectedBatteryPosTerminal,
          isRequired: true,
          onChanged: (value) {
            setState(() {
              _selectedBatteryPosTerminal = value;
              _onFormChanged();
            });
          },
        ),
        getHeight(15),
        
        CustomDropdown(
          label: "Battery -ve Terminal",
          items: _terminalOptions,
          initialValue: _selectedBatteryNegTerminal,
          isRequired: true,
          onChanged: (value) {
            setState(() {
              _selectedBatteryNegTerminal = value;
              _onFormChanged();
            });
          },
        ),
      ],
    );
  }

  Widget _buildBatterySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Battery Serial Number
        _buildSerialNumberField(),
        getHeight(15),
        
        // SOC field
        CustomFormField(
          label: "SOC",
          controller: _socController,
          isRequired: true,
          onChanged: (value) => _onFormChanged(),
        ),
        getHeight(15),
        
        // SOH field
        CustomFormField(
          label: "SOH",
          controller: _sohController,
          isRequired: true,
          onChanged: (value) => _onFormChanged(),
        ),
        getHeight(15),
        
        // Save Button
        Container(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _onSaveBatteryPressed,
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
        if (_savedBatteries.isNotEmpty) _buildSavedItemsTable(),
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
                text: "Battery - Serial Number",
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
            controller: _batterySerialController,
            onChanged: (value) => _onFormChanged(),
            decoration: InputDecoration(
              hintText: "Battery Serial Number",
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
                    "SOC",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Montserrat',
                      fontSize: 14,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    "SOH",
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
          ..._savedBatteries.map((item) => Container(
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
                    item['soc'] ?? '',
                    style: const TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 14,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    item['soh'] ?? '',
                    style: const TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 14,
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _onEditBattery(item),
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

  void _onSaveBatteryPressed() {
    if (_batterySerialController.text.isEmpty || 
        _socController.text.isEmpty || 
        _sohController.text.isEmpty) {
      showCustomToast(context, "Please fill all required fields");
      return;
    }

    // Add to saved items
    final newItem = {
      'serialNumber': _batterySerialController.text,
      'soc': _socController.text,
      'soh': _sohController.text,
      'scanned': true,
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
    };

    setState(() {
      _savedBatteries.add(newItem);
    });

    // Clear fields
    _batterySerialController.clear();
    _socController.clear();
    _sohController.clear();

    showCustomToast(context, "Battery Saved Successfully ✅");
  }

  void _onEditBattery(Map<String, dynamic> item) {
    // TODO: Implement edit functionality
    showCustomToast(context, "Edit functionality to be implemented");
  }

  void _validateAndSubmit() {
    if (_ratingController.text.isEmpty || 
        _makeController.text.isEmpty || 
        _noOfNotOkBatteriesController.text.isEmpty) {
      showCustomToast(context, "Please fill all required fields");
      return;
    }

    // TODO: Call your API with JSON payload
    showCustomToast(context, "Battery Form Submitted Successfully ✅");
  }

  void _showUnsavedChangesDialog() {
    if (_hasFormDataChanges) {
      showDialog(
        context: context,
        builder: (ctx) => UnsavedChangesDialog(
          siteAuditSchId: widget.siteId,
          section: "Battery Checklist",
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
class BatteryChecklistSection extends StatefulWidget {
  final VoidCallback onFormChanged;

  const BatteryChecklistSection({
    super.key,
    required this.onFormChanged,
  });

  @override
  State<BatteryChecklistSection> createState() => _BatteryChecklistSectionState();
}

class _BatteryChecklistSectionState extends State<BatteryChecklistSection> {
  bool _isExpanded = false;
  
  // Controllers for text fields
  final TextEditingController _ratingController = TextEditingController();
  final TextEditingController _makeController = TextEditingController();
  final TextEditingController _noOfNotOkBatteriesController = TextEditingController();
  final TextEditingController _batterySerialController = TextEditingController();
  final TextEditingController _socController = TextEditingController();
  final TextEditingController _sohController = TextEditingController();

  // Dropdown selections
  String? _selectedCbmsStatus;
  String? _selectedBatteryPosTerminal;
  String? _selectedBatteryNegTerminal;

  // Saved batteries list
  List<Map<String, dynamic>> _savedBatteries = [];

  // Dropdown options
  final List<String> _cbmsStatusOptions = ['Select', 'Ok', 'Not Ok', 'Faulty'];
  final List<String> _terminalOptions = ['Select', 'Ok', 'Not Ok', 'Faulty'];

  @override
  void initState() {
    super.initState();
    
    // Pre-fill with sample data
    _ratingController.text = "1500 KW";
    _makeController.text = "Eicher";
    _noOfNotOkBatteriesController.text = "8";
    _socController.text = "97";
    _sohController.text = "100";
  }

  @override
  void dispose() {
    _ratingController.dispose();
    _makeController.dispose();
    _noOfNotOkBatteriesController.dispose();
    _batterySerialController.dispose();
    _socController.dispose();
    _sohController.dispose();
    super.dispose();
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
                  "Battery",
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
                  // General Battery Information
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
                  
                  CustomFormField(
                    label: "No of Not OK Batteries",
                    controller: _noOfNotOkBatteriesController,
                    isRequired: true,
                    onChanged: (value) => _onFormChanged(),
                  ),
                  getHeight(15),
                  
                  // Battery Serial Number and SOC/SOH Section
                  _buildBatterySection(),
                  getHeight(15),
                  
                  // CBMS Status Dropdown
                  CustomDropdown(
                    label: "CBMS Status",
                    items: _cbmsStatusOptions,
                    initialValue: _selectedCbmsStatus,
                    isRequired: true,
                    onChanged: (value) {
                      setState(() {
                        _selectedCbmsStatus = value;
                        _onFormChanged();
                      });
                    },
                  ),
                  getHeight(15),
                  
                  // Battery Terminal Dropdowns
                  CustomDropdown(
                    label: "Battery +ve Terminal",
                    items: _terminalOptions,
                    initialValue: _selectedBatteryPosTerminal,
                    isRequired: true,
                    onChanged: (value) {
                      setState(() {
                        _selectedBatteryPosTerminal = value;
                        _onFormChanged();
                      });
                    },
                  ),
                  getHeight(15),
                  
                  CustomDropdown(
                    label: "Battery -ve Terminal",
                    items: _terminalOptions,
                    initialValue: _selectedBatteryNegTerminal,
                    isRequired: true,
                    onChanged: (value) {
                      setState(() {
                        _selectedBatteryNegTerminal = value;
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

  Widget _buildBatterySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Battery Serial Number
        _buildSerialNumberField(),
        getHeight(15),
        
        // SOC field
        CustomFormField(
          label: "SOC",
          controller: _socController,
          isRequired: true,
          onChanged: (value) => _onFormChanged(),
        ),
        getHeight(15),
        
        // SOH field
        CustomFormField(
          label: "SOH",
          controller: _sohController,
          isRequired: true,
          onChanged: (value) => _onFormChanged(),
        ),
        getHeight(15),
        
        // Save Button
        Container(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _onSaveBatteryPressed,
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
        if (_savedBatteries.isNotEmpty) _buildSavedItemsTable(),
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
                text: "Battery - Serial Number",
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
            controller: _batterySerialController,
            onChanged: (value) => _onFormChanged(),
            decoration: InputDecoration(
              hintText: "Battery Serial Number",
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
                    "SOC",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Montserrat',
                      fontSize: 14,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    "SOH",
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
          ..._savedBatteries.map((item) => Container(
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
                    item['soc'] ?? '',
                    style: const TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 14,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    item['soh'] ?? '',
                    style: const TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 14,
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _onEditBattery(item),
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

  void _onSaveBatteryPressed() {
    if (_batterySerialController.text.isEmpty || 
        _socController.text.isEmpty || 
        _sohController.text.isEmpty) {
      showCustomToast(context, "Please fill all required fields");
      return;
    }

    // Add to saved items
    final newItem = {
      'serialNumber': _batterySerialController.text,
      'soc': _socController.text,
      'soh': _sohController.text,
      'scanned': true,
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
    };

    setState(() {
      _savedBatteries.add(newItem);
    });

    // Clear fields
    _batterySerialController.clear();
    _socController.clear();
    _sohController.clear();

    showCustomToast(context, "Battery Saved Successfully ✅");
  }

  void _onEditBattery(Map<String, dynamic> item) {
    // TODO: Implement edit functionality
    showCustomToast(context, "Edit functionality to be implemented");
  }
}