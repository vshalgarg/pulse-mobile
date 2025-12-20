import 'package:app/commonWidgets/custom_form_appbar.dart';
import 'package:app/commonWidgets/custom_form_field.dart';
import 'package:app/commonWidgets/custom_form_dropdown.dart';
import 'package:app/commonWidgets/custom_submit_button_v2.dart';
import 'package:app/commonWidgets/custom_dialogs/unsaved_changes_dialog.dart';
import 'package:app/constants/app_images.dart';
import 'package:app/enum/corrective_maintenance_screen_mode_enum.dart';
import 'package:app/models/all_site_model.dart';
import 'package:app/repositories/incident_repository.dart';
import 'package:app/routes/route_generator.dart';
import 'package:app/services/service_locator.dart';
import 'package:app/utils/logger.dart';
import 'package:app/utils/toastbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class IncidentDetilScreen extends StatefulWidget {
  final AllSiteModel siteData;
  final CMScreenModeEnum mode;
  final Map<String, dynamic>? apiResponseData;
  final BuildContext? parentContext;

  const IncidentDetilScreen({
    super.key,
    required this.siteData,
    required this.mode,
    this.apiResponseData,
    this.parentContext,
  });

  @override
  State<IncidentDetilScreen> createState() => _IncidentDetilScreenState();
}

class _IncidentDetilScreenState extends State<IncidentDetilScreen> {
  // Dropdown selected values
  String? _selectedIncidentTicketReason;
  String? _selectedCurrentSiteStatus;
  String? _selectedStatus;

  // Text field controllers
  final TextEditingController _remarksController = TextEditingController();
  final TextEditingController _incidentRemarksController =
      TextEditingController();

  bool _hasFormDataChanges = false;

  // Checklist data
  bool _isLoadingChecklist = true;
  String? _checklistError;
  Map<String, List<Map<String, dynamic>>> _checklistData = {};
  late IncidentRepository _repository;

  // Dropdown options
  final List<String> _incidentTicketReasonOptions = ['Site Down', 'Other'];
  final List<String> _currentSiteStatusOptions = [
    'Restored',
    'Down',
    'Resolved',
    'Unresolved',
  ];
  final List<String> _statusOptions = ['OPEN', 'CLOSE'];

  // Check if mode is view (read-only)
  bool get _isViewMode => widget.mode == CMScreenModeEnum.view;

  @override
  void initState() {
    super.initState();

    _repository = IncidentRepository(ServiceLocator().apiService);
    _initializeFormData();
    _loadChecklistData();

    // Add listeners to track form changes
    _remarksController.addListener(() {
      if (!_hasFormDataChanges) {
        setState(() {
          _hasFormDataChanges = true;
        });
      }
    });

    _incidentRemarksController.addListener(() {
      if (!_hasFormDataChanges) {
        setState(() {
          _hasFormDataChanges = true;
        });
      }
    });
  }

  void _initializeFormData() {
    // Initialize form fields with API response data if available
    if (widget.apiResponseData != null) {
      _selectedIncidentTicketReason = widget
          .apiResponseData!['incidentTicketReason']
          ?.toString();
      _selectedCurrentSiteStatus = widget.apiResponseData!['currentSiteStatus']
          ?.toString();
      _selectedStatus = widget.apiResponseData!['status']?.toString();

      _remarksController.text =
          widget.apiResponseData!['remarks']?.toString() ?? "";
      _incidentRemarksController.text =
          widget.apiResponseData!['incidentRemarks']?.toString() ?? "";

      // If status is CLOSE, ensure it's set
      if (_selectedStatus == null || _selectedStatus!.isEmpty) {
        _selectedStatus =
            widget.apiResponseData!['status']?.toString() ?? 'OPEN';
      }
    } else {
      // Default values for create mode
      _selectedIncidentTicketReason = null;
      _selectedCurrentSiteStatus = null;
      _selectedStatus = 'OPEN';
      _remarksController.text = "";
      _incidentRemarksController.text = "";
    }

    // In view mode, if status is CLOSE, mark all as read-only
    if (_isViewMode || _selectedStatus == 'CLOSE') {
      setState(() {
        _hasFormDataChanges = false;
      });
    }
  }

  Future<void> _loadChecklistData() async {
    try {
      setState(() {
        _isLoadingChecklist = true;
        _checklistError = null;
      });

      Logger.debugLog('Loading incident checklist data');

      try {
        final checklistData = await _repository.getIncidentChecklist();

        setState(() {
          _checklistData = checklistData;
          _isLoadingChecklist = false;
        });

        Logger.debugLog(
          'Loaded incident checklist data: ${checklistData.length} item types',
        );
      } catch (apiError) {
        Logger.errorLog('API call failed: $apiError');

        // If API failed, show error
        setState(() {
          _isLoadingChecklist = false;
          _checklistError =
              'Failed to load checklist data. Please check your internet connection and try again.';
        });
      }
    } catch (e) {
      Logger.errorLog('Unexpected error loading checklist data: $e');
      setState(() {
        _isLoadingChecklist = false;
        _checklistError = 'Unexpected error: ${e.toString()}';
      });
    }
  }

  Future<void> _submitForm() async {
    // Check if checklist is still loading
    if (_isLoadingChecklist) {
      Toastbar.showInfoToastbar(
        'Please wait while checklist is loading',
        context,
      );
      return;
    }

    // Check if there was an error loading checklist
    if (_checklistError != null) {
      // Show error dialog with retry option
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Checklist Data Error'),
          content: Text(_checklistError!),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _loadChecklistData(); // Retry loading
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
      return;
    }

    // Validate required fields
    if (_selectedIncidentTicketReason == null ||
        _selectedIncidentTicketReason!.isEmpty) {
      Toastbar.showErrorToastbar(
        'Please select Incident Ticket Reason',
        context,
      );
      return;
    }

    if (_selectedCurrentSiteStatus == null ||
        _selectedCurrentSiteStatus!.isEmpty) {
      Toastbar.showErrorToastbar('Please select Current Site Status', context);
      return;
    }

    if (_selectedStatus == null || _selectedStatus!.isEmpty) {
      Toastbar.showErrorToastbar('Please select Status', context);
      return;
    }

    try {
      // TODO: Implement API call to save/update incident ticket
      // For now, just show success message
      Logger.debugLog('Incident Ticket Data:');
      Logger.debugLog(
        '  Incident Ticket Reason: $_selectedIncidentTicketReason',
      );
      Logger.debugLog('  Current Site Status: $_selectedCurrentSiteStatus');
      Logger.debugLog('  Status: $_selectedStatus');
      Logger.debugLog('  Remarks: ${_remarksController.text}');
      Logger.debugLog('  Incident Remarks: ${_incidentRemarksController.text}');
      Logger.debugLog('  Checklist Data: ${_checklistData.length} item types');

      // Show success message
      Toastbar.showSuccessToastbar(
        'Incident ticket saved successfully',
        context,
      );

      // Navigate back
      navigateBackOrToHome(
        context,
        targetContext: widget.parentContext ?? context,
      );
    } catch (e) {
      Logger.errorLog('❌ Error submitting incident ticket: $e');
      Toastbar.showErrorToastbar('Failed to save incident ticket', context);
    }
  }

  @override
  void dispose() {
    _remarksController.dispose();
    _incidentRemarksController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      resizeToAvoidBottomInset: true,
      appBar: CustomFormAppbar(
        title: "Incident Ticket",
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
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.of(context).viewInsets.bottom + 100,
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [_buildFormFields()],
                      ),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  child: CustomSubmitButtonV2(
                    text: widget.mode == CMScreenModeEnum.create
                        ? "Next"
                        : widget.mode == CMScreenModeEnum.edit
                        ? "Update"
                        : "Close",
                    onPressed: _isViewMode || _selectedStatus == 'CLOSE'
                        ? null
                        : _submitForm,
                  ),
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
        // Site Code (Read-only)
        CustomFormField(
          label: "Site Code",
          initialValue: widget.siteData.siteCode,
          isRequired: false,
          isEditable: false,
        ),
        const SizedBox(height: 15),

        // Site Name (Read-only)
        CustomFormField(
          label: "Site Name",
          initialValue: widget.siteData.siteName,
          isRequired: false,
          isEditable: false,
        ),
        const SizedBox(height: 15),

        // Cluster/District (Read-only)
        CustomFormField(
          label: "District",
          initialValue: widget.siteData.clusterDistrictName,
          isRequired: false,
          isEditable: false,
        ),
        const SizedBox(height: 15),

        // Circle/State (Read-only)
        CustomFormField(
          label: "Circle",
          initialValue: widget.siteData.circleStateName,
          isRequired: false,
          isEditable: false,
        ),
        const SizedBox(height: 15),

        // Infra Engineer
        CustomFormField(
          label: "Infra Engineer Name",
          initialValue: widget.siteData.infraEngineerName ?? "N/A",
          isRequired: false,
          isEditable: false,
        ),
        const SizedBox(height: 15),

        // Infra Engineer Contact No.
        CustomFormField(
          label: "Infra Engineer Contact No.",
          initialValue: widget.siteData.infraEngineerPhone ?? "N/A",
          isRequired: false,
          isEditable: false,
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 15),

        // Cluster Incharge
        CustomFormField(
          label: "Cluster Incharge Name",
          initialValue: widget.siteData.clusterInchargeName ?? "N/A",
          isRequired: false,
          isEditable: false,
        ),
        const SizedBox(height: 15),

        // Cluster Incharge Contact No.
        CustomFormField(
          label: "Cluster Incharge Contact No.",
          initialValue: widget.siteData.clusterInchargeContactNo ?? "N/A",
          isRequired: false,
          isEditable: false,
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 15),

        // Incident Ticket Reason Dropdown
        CustomDropdown(
          label: "Incident Ticket Reason",
          items: _incidentTicketReasonOptions,
          initialValue: _selectedIncidentTicketReason,
          onChanged: (value) {
            if (!_hasFormDataChanges) {
              setState(() {
                _hasFormDataChanges = true;
              });
            }
            setState(() {
              _selectedIncidentTicketReason = value;
            });
          },
          isDisabled: _isViewMode || _selectedStatus == 'CLOSE',
          isRequired: true,
        ),
        const SizedBox(height: 15),

        // Incident Remarks Text Field
        CustomFormField(
          label: "Incident Remarks",
          controller: _incidentRemarksController,
          isRequired: false,
          isEditable: !_isViewMode && _selectedStatus != 'CLOSE',
          keyboardType: TextInputType.text,
          inputType: InputType.multiline,
        ),
        const SizedBox(height: 15),

        // Current Site Status Dropdown
        CustomDropdown(
          label: "Current Site Status",
          items: _currentSiteStatusOptions,
          initialValue: _selectedCurrentSiteStatus,
          onChanged: (value) {
            if (!_hasFormDataChanges) {
              setState(() {
                _hasFormDataChanges = true;
              });
            }
            setState(() {
              _selectedCurrentSiteStatus = value;
            });
          },
          isDisabled: _isViewMode || _selectedStatus == 'CLOSE',
          isRequired: true,
        ),
        const SizedBox(height: 15),

        // Remarks Text Field
        CustomFormField(
          label: "Remarks",
          controller: _remarksController,
          isRequired: false,
          isEditable: !_isViewMode && _selectedStatus != 'CLOSE',
          keyboardType: TextInputType.text,
          inputType: InputType.multiline,
        ),
        const SizedBox(height: 15),

        // Status Dropdown
        CustomDropdown(
          label: "Status",
          items: _statusOptions,
          initialValue: _selectedStatus,
          onChanged: (value) {
            if (!_hasFormDataChanges) {
              setState(() {
                _hasFormDataChanges = true;
              });
            }
            setState(() {
              _selectedStatus = value;
              // When status changes to CLOSE, mark form as read-only
              if (value == 'CLOSE') {
                _hasFormDataChanges = false;
              }
            });
          },
          isDisabled: _isViewMode,
          isRequired: true,
        ),
        const SizedBox(height: 15),
      ],
    );
  }

  void _showUnsavedChangesDialog() {
    if (_hasFormDataChanges && !_isViewMode && _selectedStatus != 'CLOSE') {
      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (dialogContext) => UnsavedChangesDialog(
          siteAuditSchId: widget.siteData.siteId.toString(),
          section: "Incident Ticket",
          parentContext: widget.parentContext ?? context,
          onSaveAndExit: () async {
            await _submitForm();
          },
          onDiscard: () {},
        ),
      );
    } else {
      navigateBackOrToHome(
        context,
        targetContext: widget.parentContext ?? context,
      );
    }
  }
}
