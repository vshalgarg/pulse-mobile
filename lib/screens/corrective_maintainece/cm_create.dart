import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../commonWidgets/custom_form_appbar.dart';
import '../../../commonWidgets/custom_form_field.dart';
import '../../../commonWidgets/custom_image_upload_field.dart';
import '../../../commonWidgets/custom_form_field_v2.dart';
import '../../../commonWidgets/custom_file_upload_v2.dart';
import '../../../commonWidgets/custom_submit_button_v2.dart';
import '../../../commonWidgets/custom_buttons/arrow_botton.dart';
import '../../../commonWidgets/custom_dialogs/unsaved_changes_dialog.dart';
import '../../../commonWidgets/generic_dropdown.dart'; // 👈 Added GenericDropdown
import 'dg_checklist_screen.dart';
import 'battery_checklist_screen.dart';
import 'solar_checklist_screen.dart';
import 'ccu_checklist_screen.dart';
import 'smps_checklist_screen.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_images.dart';
import '../../../constants/constants_methods.dart';
import '../../../services/service_locator.dart';
import '../../../models/cm_site_model.dart';

class CorrectiveMaintenanceScreen extends StatefulWidget {
  const CorrectiveMaintenanceScreen({super.key});

  @override
  State<CorrectiveMaintenanceScreen> createState() =>
      _CorrectiveMaintenanceScreenState();
}

class _CorrectiveMaintenanceScreenState
    extends State<CorrectiveMaintenanceScreen> {
  bool _isLoadingData = true;
  bool _isLoadingSites = false;
  String? _errorMessage;

  // 👇 Controllers
  final TextEditingController _oemTicketController = TextEditingController();
  final TextEditingController _actionTakenController = TextEditingController();
  final TextEditingController _rcaController = TextEditingController();
  final TextEditingController _customerNameController = TextEditingController();
  final TextEditingController _contactNoController = TextEditingController();
  final TextEditingController _customerRemarksController = TextEditingController();
  final TextEditingController _problemSummaryController = TextEditingController();

  // 👇 Site related controllers - Auto-fill ke liye
  final TextEditingController _siteIdController = TextEditingController();
  final TextEditingController _circleStateController = TextEditingController();
  final TextEditingController _clusterDistrictController = TextEditingController();
  final TextEditingController _customerController = TextEditingController();
  final TextEditingController _assignedToController = TextEditingController();

  // 👇 Images
  File? _customerPhoto;
  File? _attachmentFile;

  // 👇 Dropdown selections
  CMSite? _selectedSite;
  String? _selectedPriority;
  String? _selectedResponsibleParty;
  String? _selectedNatureOfFailure;

  // 👇 Radio button selection
  String? _selectedEquipmentType;

  // 👇 Dropdown options
  List<CMSite> _siteOptions = [];
  final List<String> _priorityOptions = ['Critical', 'Non Critical'];
  final List<String> _responsiblePartyOptions = ['OEM', 'Self'];
  final List<String> _natureOfFailureOptions = ['AMC', 'Paid', 'FOC'];

  bool _hasFormDataChanges = false;

  @override
  void initState() {
    super.initState();
    _loadSitesData();
  }

  // 👇 API se sites data load karo
  Future<void> _loadSitesData() async {
    try {
      setState(() {
        _isLoadingSites = true;
        _errorMessage = null;
      });

      print('🔄 Loading CM sites from API...');
      
      final sites = await ServiceLocator().cmRepository.getCMSitesDropdown();
      
      setState(() {
        _siteOptions = sites;
        _isLoadingSites = false;
        _isLoadingData = false;
      });
      
      print('✅ Loaded ${sites.length} sites');
      
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load sites: $e';
        _isLoadingSites = false;
        _isLoadingData = false;
      });
      print('❌ Error loading sites: $e');
    }
  }

  // 👇 Jab user site select kare
  void _onSiteSelected(CMSite? selectedSite) {
    print('🎯 [CMCreate] Site selection callback triggered');
    print('🎯 [CMCreate] Selected site: $selectedSite');
    
    if (selectedSite == null) {
      print('⚠️ [CMCreate] Selected site is null, ignoring');
      return;
    }
    
    print('📍 [CMCreate] Processing site selection:');
    print('   - Site Name: ${selectedSite.siteName}');
    print('   - Site ID: ${selectedSite.siteId}');
    print('   - Site Code: ${selectedSite.siteCode}');
    print('   - Entity ID: ${selectedSite.entityId}');
    print('   - Entity ID Type: ${selectedSite.entityId.runtimeType}');
    
    setState(() {
      _selectedSite = selectedSite;
      _hasFormDataChanges = true;
    });
    
    print('✅ [CMCreate] _selectedSite updated: $_selectedSite');
    print('✅ [CMCreate] _selectedSite.entityId: ${_selectedSite?.entityId}');

    // 👇 Automatically baaki fields fill karo
    _siteIdController.text = selectedSite.siteCode;
    _circleStateController.text = selectedSite.circleStateName;
    _clusterDistrictController.text = selectedSite.clusterDistrictName;
    _customerController.text = selectedSite.clientName ?? 'N/A';
    
    // 👇 Set assigned to based on current responsible party selection
    _updateAssignedToField();

    print('📍 [CMCreate] Selected Site: ${selectedSite.siteName}');
    print('📝 [CMCreate] Auto-filled data:');
    print('   - Site ID: ${_siteIdController.text}');
    print('   - Circle/State: ${_circleStateController.text}');
    print('   - Cluster/District: ${_clusterDistrictController.text}');
    print('   - Customer: ${_customerController.text}');
    print('   - Assigned To: ${_assignedToController.text}');
  }

  // 👇 Update assigned to field based on responsible party selection
  void _updateAssignedToField() {
    if (_selectedSite == null) return;
    
    if (_selectedResponsibleParty == 'OEM') {
      _assignedToController.text = _selectedSite!.oem ?? 'N/A';
      print('🔄 [CMCreate] Set Assigned To to OEM: ${_selectedSite!.oem}');
    } else if (_selectedResponsibleParty == 'Self') {
      _assignedToController.text = _selectedSite!.self;
      print('🔄 [CMCreate] Set Assigned To to Self: ${_selectedSite!.self}');
    }
  }

  @override
  void dispose() {
    _oemTicketController.dispose();
    _actionTakenController.dispose();
    _rcaController.dispose();
    _customerNameController.dispose();
    _contactNoController.dispose();
    _customerRemarksController.dispose();
    _problemSummaryController.dispose();
    _siteIdController.dispose();
    _circleStateController.dispose();
    _clusterDistrictController.dispose();
    _customerController.dispose();
    _assignedToController.dispose();
    super.dispose();
  }

  void _onFormChanged() {
    if (!_hasFormDataChanges) {
      setState(() {
        _hasFormDataChanges = true;
      });
    }
  }

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
        
        // Radio buttons row with proper spacing
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              // DG
              Row(
                mainAxisSize: MainAxisSize.min,
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
                    activeColor: const Color(0xFF1976D2), // Brighter blue
                    fillColor: MaterialStateProperty.resolveWith<Color>((states) {
                      if (states.contains(MaterialState.selected)) {
                        return const Color(0xFF1976D2); // Brighter blue for selected
                      }
                      return Colors.white;
                    }),
                    overlayColor: MaterialStateProperty.resolveWith<Color>((states) {
                      if (states.contains(MaterialState.hovered)) {
                        return const Color(0xFF1976D2).withOpacity(0.1);
                      }
                      return Colors.transparent;
                    }),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                  const Text('DG', style: TextStyle(color: Colors.white, fontSize: 14)),
                ],
              ),
              const SizedBox(width: 12),
              
              // Battery
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Radio<String>(
                    value: 'Battery',
                    groupValue: _selectedEquipmentType,
                    onChanged: (value) {
                      setState(() {
                        _selectedEquipmentType = value;
                        _onFormChanged();
                      });
                    },
                    activeColor: const Color(0xFF1976D2), // Brighter blue
                    fillColor: MaterialStateProperty.resolveWith<Color>((states) {
                      if (states.contains(MaterialState.selected)) {
                        return const Color(0xFF1976D2); // Brighter blue for selected
                      }
                      return Colors.white;
                    }),
                    overlayColor: MaterialStateProperty.resolveWith<Color>((states) {
                      if (states.contains(MaterialState.hovered)) {
                        return const Color(0xFF1976D2).withOpacity(0.1);
                      }
                      return Colors.transparent;
                    }),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                  const Text('Battery', style: TextStyle(color: Colors.white, fontSize: 14)),
                ],
              ),
              const SizedBox(width: 12),
              
              // CCU
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Radio<String>(
                    value: 'CCU',
                    groupValue: _selectedEquipmentType,
                    onChanged: (value) {
                      setState(() {
                        _selectedEquipmentType = value;
                        _onFormChanged();
                      });
                    },
                    activeColor: const Color(0xFF1976D2), // Brighter blue
                    fillColor: MaterialStateProperty.resolveWith<Color>((states) {
                      if (states.contains(MaterialState.selected)) {
                        return const Color(0xFF1976D2); // Brighter blue for selected
                      }
                      return Colors.white;
                    }),
                    overlayColor: MaterialStateProperty.resolveWith<Color>((states) {
                      if (states.contains(MaterialState.hovered)) {
                        return const Color(0xFF1976D2).withOpacity(0.1);
                      }
                      return Colors.transparent;
                    }),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                  const Text('CCU', style: TextStyle(color: Colors.white, fontSize: 14)),
                ],
              ),
              const SizedBox(width: 12),
              
              // SMPS
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Radio<String>(
                    value: 'SMPS',
                    groupValue: _selectedEquipmentType,
                    onChanged: (value) {
                      setState(() {
                        _selectedEquipmentType = value;
                        _onFormChanged();
                      });
                    },
                    activeColor: const Color(0xFF1976D2), // Brighter blue
                    fillColor: MaterialStateProperty.resolveWith<Color>((states) {
                      if (states.contains(MaterialState.selected)) {
                        return const Color(0xFF1976D2); // Brighter blue for selected
                      }
                      return Colors.white;
                    }),
                    overlayColor: MaterialStateProperty.resolveWith<Color>((states) {
                      if (states.contains(MaterialState.hovered)) {
                        return const Color(0xFF1976D2).withOpacity(0.1);
                      }
                      return Colors.transparent;
                    }),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                  const Text('SMPS', style: TextStyle(color: Colors.white, fontSize: 14)),
                ],
              ),
              const SizedBox(width: 12),
              
              // Solar
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Radio<String>(
                    value: 'Solar',
                    groupValue: _selectedEquipmentType,
                    onChanged: (value) {
                      setState(() {
                        _selectedEquipmentType = value;
                        _onFormChanged();
                      });
                    },
                    activeColor: const Color(0xFF1976D2), // Brighter blue
                    fillColor: MaterialStateProperty.resolveWith<Color>((states) {
                      if (states.contains(MaterialState.selected)) {
                        return const Color(0xFF1976D2); // Brighter blue for selected
                      }
                      return Colors.white;
                    }),
                    overlayColor: MaterialStateProperty.resolveWith<Color>((states) {
                      if (states.contains(MaterialState.hovered)) {
                        return const Color(0xFF1976D2).withOpacity(0.1);
                      }
                      return Colors.transparent;
                    }),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                  const Text('Solar', style: TextStyle(color: Colors.white, fontSize: 14)),
                ],
              ),
            ],
          ),
        ),
        
        // Equipment Checklist Sections
        const SizedBox(height: 20),
        
        if (_selectedEquipmentType == 'DG')
          Builder(
            builder: (context) {
              print('🔄 [CMCreate] Building DG checklist section');
              print('🔄 [CMCreate] _selectedSite: $_selectedSite');
              print('🔄 [CMCreate] _selectedSite?.entityId: ${_selectedSite?.entityId}');
              
              return DGChecklistSection(
                onFormChanged: _onFormChanged,
                entityId: _selectedSite?.entityId,
              );
            },
          ),
        
        if (_selectedEquipmentType == 'Battery')
          Builder(
            builder: (context) {
              print('🔄 [CMCreate] Building Battery checklist section');
              print('🔄 [CMCreate] _selectedSite: $_selectedSite');
              print('🔄 [CMCreate] _selectedSite?.entityId: ${_selectedSite?.entityId}');
              
              return BatteryChecklistSection(
                onFormChanged: _onFormChanged,
                entityId: _selectedSite?.entityId,
              );
            },
          ),
        
        if (_selectedEquipmentType == 'CCU')
          CCUChecklistSection(
            onFormChanged: _onFormChanged,
            entityId: _selectedSite?.entityId,
          ),
        
        if (_selectedEquipmentType == 'SMPS')
          Builder(
            builder: (context) {
              print('🔄 [CMCreate] Building SMPS checklist section');
              print('🔄 [CMCreate] _selectedSite: $_selectedSite');
              print('🔄 [CMCreate] _selectedSite?.entityId: ${_selectedSite?.entityId}');
              
              return SMPSChecklistSection(
                onFormChanged: _onFormChanged,
                entityId: _selectedSite?.entityId,
              );
            },
          ),
        
        if (_selectedEquipmentType == 'Solar')
          SolarChecklistSection(onFormChanged: _onFormChanged),
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
                          // 👇 Loading Indicator
                          if (_isLoadingData)
                            const Center(
                              child: Column(
                                children: [
                                  CircularProgressIndicator(color: AppColors.primaryGreen),
                                  SizedBox(height: 16),
                                  Text('Loading sites...', style: TextStyle(color: Colors.white)),
                                ],
                              ),
                            ),

                          // 👇 Error Message
                          if (_errorMessage != null)
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.errorColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.errorColor),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.error, color: AppColors.errorColor),
                                      const SizedBox(width: 8),
                                      Expanded(child: Text('Error loading sites', style: TextStyle(color: AppColors.errorColor))),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(_errorMessage!, style: TextStyle(color: AppColors.errorColor)),
                                  const SizedBox(height: 12),
                                  ElevatedButton(
                                    onPressed: _loadSitesData,
                                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.errorColor),
                                    child: const Text('Retry', style: TextStyle(color: Colors.white)),
                                  ),
                                ],
                              ),
                            ),

                          // 👇 Form Fields
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
        // 👇 Site Name Dropdown (API se data) - USING GenericDropdown
        GenericDropdown<CMSite>(
          label: "Site Name",
          items: _siteOptions,
          initialValue: _selectedSite,
          onChanged: _onSiteSelected,
          displayText: (site) => site.siteName,
          hintText: "Select Site",
          isRequired: true,
        ),
        getHeight(15),

        // 👇 Auto-filled fields (Read-only)
        CustomFormField(
          label: "Site Id",
          controller: _siteIdController,
          isEditable: false,
        ),
        getHeight(15),

        CustomFormField(
          label: "Circle/State",
          controller: _circleStateController,
          isEditable: false,
        ),
        getHeight(15),

        CustomFormField(
          label: "Cluster/District",
          controller: _clusterDistrictController,
          isEditable: false,
        ),
        getHeight(15),

        CustomFormField(
          label: "Customer",
          controller: _customerController,
          isEditable: false,
        ),
        getHeight(15),

        // 👇 Responsible Party Dropdown - USING GenericDropdown
        GenericDropdown<String>(
          label: "Responsible Party",
          items: _responsiblePartyOptions,
          initialValue: _selectedResponsibleParty,
          onChanged: (value) {
            setState(() {
              _selectedResponsibleParty = value;
              _onFormChanged();
            });
            // 👇 Update assigned to field when responsible party changes
            _updateAssignedToField();
          },
          hintText: "Select Responsible Party",
          isRequired: true,
        ),
        getHeight(15),

        CustomFormField(
          label: "Assigned To",
          controller: _assignedToController,
          isEditable: false,
        ),
        getHeight(15),

        // 👇 OEM Ticket ID - Required only when OEM is selected
        CustomFormField(
          label: "OEM Ticket ID",
          controller: _oemTicketController,
          isRequired: _selectedResponsibleParty == 'OEM',
          onChanged: (value) => _onFormChanged(),
        ),
        getHeight(15),

        // 👇 Priority Dropdown - USING GenericDropdown
        GenericDropdown<String>(
          label: "Priority",
          items: _priorityOptions,
          initialValue: _selectedPriority,
          onChanged: (value) {
            setState(() {
              _selectedPriority = value;
              _onFormChanged();
            });
          },
          hintText: "Select Priority",
        ),
        getHeight(15),

        _buildEquipmentTypeRadioButtons(),
        getHeight(15),

        // 👇 Nature of Failure Dropdown - USING GenericDropdown
        GenericDropdown<String>(
          label: "Nature of Failure",
          items: _natureOfFailureOptions,
          initialValue: _selectedNatureOfFailure,
          onChanged: (value) {
            setState(() {
              _selectedNatureOfFailure = value;
              _onFormChanged();
            });
          },
          hintText: "Select Nature of Failure",
        ),
        getHeight(15),

        CustomFormField(
          label: "Action Taken",
          controller: _actionTakenController,
          onChanged: (value) => _onFormChanged(),
        ),
        getHeight(15),

        CustomFormField(
          label: "RCA",
          controller: _rcaController,
          onChanged: (value) => _onFormChanged(),
        ),
        getHeight(15),

        CustomFormField(
          label: "Customer Name *",
          controller: _customerNameController,
          isRequired: true,
          onChanged: (value) => _onFormChanged(),
        ),
        getHeight(15),

        CustomFormField(
          label: "Contact No. *",
          controller: _contactNoController,
          isRequired: true,
          onChanged: (value) => _onFormChanged(),
        ),
        getHeight(15),

        CustomFormField(
          label: "Customer Remarks",
          controller: _customerRemarksController,
          onChanged: (value) => _onFormChanged(),
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
    // Validation
    if (_selectedSite == null) {
      showCustomToast(context, "Please select a site");
      return;
    }

    if (_selectedResponsibleParty == null) {
      showCustomToast(context, "Please select a responsible party");
      return;
    }

    // 👇 OEM Ticket ID is required only when OEM is selected
    if (_selectedResponsibleParty == 'OEM' && _oemTicketController.text.isEmpty) {
      showCustomToast(context, "OEM Ticket ID is required when OEM is selected");
      return;
    }

    if (_customerNameController.text.isEmpty ||
        _contactNoController.text.isEmpty) {
      showCustomToast(context, "Please fill all required fields");
      return;
    }

    // TODO: Submit API call yahan karo
    _submitFormData();
  }

  void _submitFormData() {
    // 👇 Yahan tumhara submit logic aayega
    final formData = {
      'site': _selectedSite!.toJson(),
      'responsible_party': _selectedResponsibleParty,
      'assigned_to': _assignedToController.text,
      'oem_ticket_id': _oemTicketController.text,
      'priority': _selectedPriority,
      'equipment_type': _selectedEquipmentType,
      'nature_of_failure': _selectedNatureOfFailure,
      'action_taken': _actionTakenController.text,
      'rca': _rcaController.text,
      'customer_name': _customerNameController.text,
      'contact_no': _contactNoController.text,
      'customer_remarks': _customerRemarksController.text,
      'problem_summary': _problemSummaryController.text,
    };

    print('📤 Submitting Form Data:');
    print(formData);
    
    showCustomToast(context, "Form Submitted Successfully ✅");
  }

  void _showUnsavedChangesDialog() {
    if (_hasFormDataChanges) {
      showDialog(
        context: context,
        builder: (ctx) => UnsavedChangesDialog(
          siteAuditSchId: _selectedSite?.siteCode ?? '',
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
}