import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../commonWidgets/custom_form_appbar.dart';
import '../../../commonWidgets/custom_form_field.dart';
import '../../../commonWidgets/custom_dropdown.dart';
import '../../../commonWidgets/custom_image_upload_field.dart';
import '../../../commonWidgets/custom_form_field_v2.dart';
import '../../../commonWidgets/custom_file_upload_v2.dart';
import '../../../commonWidgets/custom_submit_button_v2.dart';
import '../../../commonWidgets/custom_buttons/arrow_botton.dart';
import '../../../commonWidgets/custom_dialogs/unsaved_changes_dialog.dart';
import 'dg_checklist_screen.dart';
import 'battery_checklist_screen.dart';
import 'solar_checklist_screen.dart';
import 'ccu_checklist_screen.dart';
import 'smps_checklist_screen.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_images.dart';
import '../../../constants/constants_methods.dart';

class CorrectiveMaintenanceScreen extends StatefulWidget {
  final String siteId;
  final String siteName;
  final String circleState;
  final String clusterDistrict;
  final String customer;
  final String responsibleParty;
  final String assignedTo;
  final String priority;
  final String natureOfFailure;

  const CorrectiveMaintenanceScreen({
    super.key,
    required this.siteId,
    required this.siteName,
    required this.circleState,
    required this.clusterDistrict,
    required this.customer,
    required this.responsibleParty,
    required this.assignedTo,
    required this.priority,
    required this.natureOfFailure,
  });

  @override
  State<CorrectiveMaintenanceScreen> createState() =>
      _CorrectiveMaintenanceScreenState();
}

class _CorrectiveMaintenanceScreenState
    extends State<CorrectiveMaintenanceScreen> {
  bool _isLoadingData = false;
  String? _errorMessage;

  // Controllers
  final TextEditingController _oemTicketController = TextEditingController();
  final TextEditingController _actionTakenController = TextEditingController();
  final TextEditingController _rcaController = TextEditingController();
  final TextEditingController _customerNameController = TextEditingController();
  final TextEditingController _contactNoController = TextEditingController();
  final TextEditingController _customerRemarksController =
      TextEditingController();
  final TextEditingController _problemSummaryController =
      TextEditingController();

  // Images
  File? _customerPhoto;
  File? _attachmentFile;

  // Dropdown selections
  String? _selectedSiteName;
  String? _selectedPriority;
  String? _selectedResponsibleParty;
  String? _selectedNatureOfFailure;

  // Radio button selection
  String? _selectedEquipmentType;

  // Dropdown options
  final List<String> _siteNameOptions = ['Site A', 'Site B', 'Site C', 'Site D'];
  final List<String> _priorityOptions = ['Low', 'Medium', 'High', 'Critical'];
  final List<String> _responsiblePartyOptions = ['Internal Team', 'External Vendor', 'Customer', 'Third Party'];
  final List<String> _natureOfFailureOptions = ['Hardware', 'Software', 'Network', 'Power', 'Environmental'];

  bool _hasFormDataChanges = false;
  bool _showValidationErrors = false;

  @override
  void dispose() {
    _oemTicketController.dispose();
    _actionTakenController.dispose();
    _rcaController.dispose();
    _customerNameController.dispose();
    _contactNoController.dispose();
    _customerRemarksController.dispose();
    _problemSummaryController.dispose();
    super.dispose();
  }

  void _onFormChanged() {
    setState(() {
      _hasFormDataChanges = true;
    });
  }

  // REMOVE THIS FUNCTION - No navigation needed
  // void _navigateToEquipmentScreen(String equipmentType) {
  //   // Remove this entire function
  // }

 Widget _buildEquipmentTypeRadioButtons() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        "Equipment Type",
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: Colors.white,
        ),
      ),
      const SizedBox(height: 8),
      // Single row with all radio buttons
      Row(
        children: [
          Radio<String>(
            value: 'DG',
            groupValue: _selectedEquipmentType,
            onChanged: (value) {
              setState(() {
                _selectedEquipmentType = value;
                _onFormChanged();
              });
            },
            activeColor: Colors.white,
            fillColor: MaterialStateProperty.all(Colors.white),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
          const Text(
            'DG',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
          const SizedBox(width: 8),
          Radio<String>(
            value: 'Battery',
            groupValue: _selectedEquipmentType,
            onChanged: (value) {
              setState(() {
                _selectedEquipmentType = value;
                _onFormChanged();
              });
            },
            activeColor: Colors.white,
            fillColor: MaterialStateProperty.all(Colors.white),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
          const Text(
            'Battery',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
          const SizedBox(width: 8),
          Radio<String>(
            value: 'CCU',
            groupValue: _selectedEquipmentType,
            onChanged: (value) {
              setState(() {
                _selectedEquipmentType = value;
                _onFormChanged();
              });
            },
            activeColor: Colors.white,
            fillColor: MaterialStateProperty.all(Colors.white),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
          const Text(
            'CCU',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
          const SizedBox(width: 8),
          Radio<String>(
            value: 'SMPS',
            groupValue: _selectedEquipmentType,
            onChanged: (value) {
              setState(() {
                _selectedEquipmentType = value;
                _onFormChanged();
              });
            },
            activeColor: Colors.white,
            fillColor: MaterialStateProperty.all(Colors.white),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
          const Text(
            'SMPS',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
          const SizedBox(width: 8),
          Radio<String>(
            value: 'Solar',
            groupValue: _selectedEquipmentType,
            onChanged: (value) {
              setState(() {
                _selectedEquipmentType = value;
                _onFormChanged();
              });
            },
            activeColor: Colors.white,
            fillColor: MaterialStateProperty.all(Colors.white),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
          const Text(
            'Solar',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
        ],
      ),
      
      // Equipment Checklist Sections (show below radio buttons)
      const SizedBox(height: 20),
      
      // DG Checklist Section - SHOW IN SAME SCREEN
      if (_selectedEquipmentType == 'DG')
        DGChecklistSection(
          onFormChanged: _onFormChanged,
        ),
      
      // Battery Checklist Section
      if (_selectedEquipmentType == 'Battery')
        BatteryChecklistSection(
          onFormChanged: _onFormChanged,
        ),
        
      // CCU Checklist Section
      if (_selectedEquipmentType == 'CCU')
        CCUChecklistSection(
          onFormChanged: _onFormChanged,
        ),
        
      // SMPS Checklist Section
      if (_selectedEquipmentType == 'SMPS')
        SMPSChecklistSection(
          onFormChanged: _onFormChanged,
        ),
        
      if (_selectedEquipmentType == 'Solar')
        SolarChecklistSection(
          onFormChanged: _onFormChanged,
        ),
    ],
  );
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      resizeToAvoidBottomInset: true,
      appBar: CustomFormAppbar(
        title: 'Corrective Maintenance',
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
        CustomDropdown(
          label: "Site Name",
          items: _siteNameOptions,
          initialValue: _selectedSiteName,
          onChanged: (value) {
            setState(() {
              _selectedSiteName = value;
              _onFormChanged();
            });
          },
        ),
        getHeight(15),
        CustomFormField(
          label: "Site Id",
          initialValue: widget.siteId,
          isEditable: false,
        ),
        getHeight(15),
        CustomFormField(
          label: "Circle/State",
          initialValue: widget.circleState,
          isEditable: false,
        ),
        getHeight(15),
        CustomFormField(
          label: "Cluster/District",
          initialValue: widget.clusterDistrict,
          isEditable: false,
        ),
        getHeight(15),
        CustomFormField(
          label: "Customer",
          initialValue: widget.customer,
          isEditable: false,
        ),
        getHeight(15),
        CustomDropdown(
          label: "Responsible Party",
          items: _responsiblePartyOptions,
          initialValue: _selectedResponsibleParty,
          onChanged: (value) {
            setState(() {
              _selectedResponsibleParty = value;
              _onFormChanged();
            });
          },
        ),
        getHeight(15),
        CustomFormField(
          label: "Assigned To",
          initialValue: widget.assignedTo,
          isEditable: false,
        ),
        getHeight(15),
        CustomFormField(
          label: "OEM Ticket ID",
          controller: _oemTicketController,
          isRequired: true,
        ),
        getHeight(15),
        CustomDropdown(
          label: "Priority",
          items: _priorityOptions,
          initialValue: _selectedPriority,
          onChanged: (value) {
            setState(() {
              _selectedPriority = value;
              _onFormChanged();
            });
          },
        ),
        getHeight(15),
        
        // Equipment Type Radio Buttons with Checklist Sections
        _buildEquipmentTypeRadioButtons(),
        getHeight(15),
        
        // Rest of the form fields
        CustomDropdown(
          label: "Nature of Failure",
          items: _natureOfFailureOptions,
          initialValue: _selectedNatureOfFailure,
          onChanged: (value) {
            setState(() {
              _selectedNatureOfFailure = value;
              _onFormChanged();
            });
          },
        ),
        getHeight(15),
        CustomFormField(
          label: "Action Taken",
          controller: _actionTakenController,
        ),
        getHeight(15),
        CustomFormField(
          label: "RCA",
          controller: _rcaController,
        ),
        getHeight(15),
        CustomFormField(
          label: "Customer Name",
          controller: _customerNameController,
          isRequired: true,
        ),
        getHeight(15),
        CustomFormField(
          label: "Contact No.",
          controller: _contactNoController,
          isRequired: true,
        ),
        getHeight(15),
        CustomFormField(
          label: "Customer Remarks",
          controller: _customerRemarksController,
        ),
        getHeight(15),
        CustomFormFieldV2(
          label: "Problem Summary",
          controller: _problemSummaryController,
          hintText: "Enter problem summary",
          maxLines: 1,
          onChanged: (value) => _onFormChanged(),
        ),
        getHeight(15),
        CustomFileUploadV2(
          label: "Customer Photo",
          placeholder: "Upload File",
          selectedFile: _customerPhoto,
          isRequired: true,
          maxSizeText: "(Max Size: 2MB)",
          onFileSelected: (file) {
            setState(() {
              _customerPhoto = file;
              _hasFormDataChanges = true;
            });
          },
        ),
        getHeight(15),
        CustomFileUploadV2(
          label: "Attachments",
          placeholder: "Upload File",
          selectedFile: _attachmentFile,
          maxSizeText: "(Max Size: 2MB)",
          onFileSelected: (file) {
            setState(() {
              _attachmentFile = file;
              _hasFormDataChanges = true;
            });
          },
        ),
        getHeight(30),
        CustomSubmitButtonV2(
          text: "Submit",
          onPressed: _validateAndSubmit,
        ),
      ],
    );
  }

  void _validateAndSubmit() {
    setState(() {
      _showValidationErrors = true;
    });

    if (_oemTicketController.text.isEmpty ||
        _customerNameController.text.isEmpty ||
        _contactNoController.text.isEmpty) {
      showCustomToast(context, "Please fill all required fields");
      return;
    }

    // TODO: Call your API with JSON payload
    showCustomToast(context, "Form Submitted Successfully ✅");
  }

  void _showUnsavedChangesDialog() {
    if (_hasFormDataChanges) {
      showDialog(
        context: context,
        builder: (ctx) => UnsavedChangesDialog(
          siteAuditSchId: widget.siteId,
          section: "Corrective Maintenance",
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