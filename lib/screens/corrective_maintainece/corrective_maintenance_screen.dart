import 'dart:convert';
import 'dart:io';
import 'package:app/commonWidgets/custom_file_upload_new.dart';
import 'package:app/commonWidgets/custom_form_dropdown.dart';
import 'package:app/commonWidgets/custom_image_upload_field.dart';
import 'package:app/commonWidgets/custom_radio_options.dart';
import 'package:app/commonWidgets/custom_remark.dart';
import 'package:app/commonWidgets/loader_widget.dart';
import 'package:app/constants/exception_constants.dart';
import 'package:app/enum/corrective_maintenance_screen_mode_enum.dart';
import 'package:app/models/location_model.dart';
import 'package:app/screens/corrective_maintainece/checklist_preview_widget.dart';
import 'package:app/services/location_service.dart';
import 'package:app/utils.dart';
import 'package:app/utils/asset_audit_navigation_helper.dart';
import 'package:app/utils/data_transformation_helper.dart';
import 'package:app/utils/logger.dart';
import 'package:app/utils/toastbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../commonWidgets/custom_form_appbar.dart';
import '../../../commonWidgets/custom_form_field.dart';
import '../../../commonWidgets/custom_submit_button_v2.dart';
import '../../../commonWidgets/custom_buttons/arrow_botton.dart';
import '../../../commonWidgets/custom_dialogs/unsaved_changes_dialog.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_images.dart';
import '../../../constants/constants_methods.dart';
import '../../../services/service_locator.dart';
import '../../../models/cm_site_model.dart';

class CorrectiveMaintenanceScreen extends StatefulWidget {
  final CMScreenModeEnum mode;
  final List<CMSite>? preloadedSites;
  final Map<String, dynamic>? preloadedSiteData;

  const CorrectiveMaintenanceScreen({
    super.key,
    required this.mode,
    this.preloadedSites,
    this.preloadedSiteData,
  });

  @override
  State<CorrectiveMaintenanceScreen> createState() =>
      _CorrectiveMaintenanceScreenState();
}

class _CorrectiveMaintenanceScreenState
    extends State<CorrectiveMaintenanceScreen> {

  // 👇 Controllers
  Map<String, TextEditingController> controllers = {
    'site_id' : TextEditingController(),
    'responsible_party': TextEditingController(),
    'assigned_to': TextEditingController(),
    'oem_ticket_id': TextEditingController(),
    'priority': TextEditingController(),
    'nature_of_failure': TextEditingController(),
    'action_taken': TextEditingController(),
    'rca': TextEditingController(),
    'customer_name': TextEditingController(),
    'contact_no': TextEditingController(),
    'customer_remarks': TextEditingController(),
    'problem_summary': TextEditingController(),
  };

  // 👇 Site related controllers - Auto-fill ke liye
  final TextEditingController _siteCodeController = TextEditingController();
  final TextEditingController _circleStateController = TextEditingController();
  final TextEditingController _clusterDistrictController = TextEditingController();
  final TextEditingController _customerController = TextEditingController();

  final TextEditingController _statusController = TextEditingController();
  final TextEditingController _remarksController = TextEditingController();

  // 👇 Dropdown selections
  CMSite? _selectedSite;
  String _selectedEquipmentType = "DG";

  int? cmSiteReqId;

  File? customerPhoto;
  String customerPhotoByteData = "";
  final List<File> _uploadedAttachments = [];
  final List<File> _remarksAttachments = [];

  // 👇 Dropdown options
  List<CMSite> _siteOptions = [];
  final List<String> _priorityOptions = ['Critical', 'Non Critical'];
  final List<String> _responsiblePartyOptions = ['OEM', 'Self'];
  final List<String> _natureOfFailureOptions = ['AMC', 'Paid', 'FOC'];
  final List<String> _statusOptions = ['Open', 'In Progress', 'Closed'];
  Map<String, dynamic> _checklistData = {};
  List<Map<String, dynamic>> _impactedItemList = [];

  bool _hasFormDataChanges = false;

  @override
  void initState() {
    super.initState();
    // Use preloaded sites if available, otherwise load them
    if(widget.preloadedSites != null) {
      _siteOptions = widget.preloadedSites!;
    } else {
      Map<String, dynamic> preloadedSite = widget.preloadedSiteData!;
      cmSiteReqId = preloadedSite['cm_site_req_id'];
      CMSite site = CMSite(
          siteId: preloadedSite['site_id'],
          entityId: preloadedSite['entity_id'],
          siteCode: preloadedSite['site_code'],
          siteName: preloadedSite['site_name'],
          clusterDistrictId: 0,
          clusterDistrictName: preloadedSite['site_code'],
          circleStateId: 0,
          circleStateName: preloadedSite['site_code'],
          self: preloadedSite['site_code'],
          selfId: preloadedSite['assigned_to']);
      _siteOptions = [site];
      _initializeTicketControllers(preloadedSite);
      _onSiteSelected(site);
    }
  }

  void _loadImages(Map<String, dynamic> preloadedSite) async {
    if(preloadedSite['customer_photo_id'] != null) {
      String? customerPhotoByteDataLocal = await ServiceLocator()
          .imageUploadService
          .downloadFromServer(preloadedSite['customer_photo_id'].toString());

      if (customerPhotoByteDataLocal != null) {
        setState(() {
          customerPhotoByteData = customerPhotoByteDataLocal;
        });
      }
    }
    if(preloadedSite['customer_attachment_id'] != null) {
      String? attachmentByteData = await ServiceLocator().imageUploadService
          .downloadFromServer(
          preloadedSite['customer_attachment_id'].toString());

      if (attachmentByteData != null) {
        File? imageFile = await Utils.buildImageFromBytesData(
            attachmentByteData);
        if (imageFile != null) {
          setState(() {
            _uploadedAttachments.add(imageFile);
          });
        }
      }
    }
  }

  void _initializeTicketControllers(Map<String, dynamic> preloadedSite) {
    controllers['responsible_party']!.text = preloadedSite['responsible_party'];
    controllers['assigned_to']!.text = preloadedSite['responsible_party'];
    controllers['priority']!.text = preloadedSite['priority'];
    controllers['oem_ticket_id']!.text = preloadedSite['oem_ticket_id'];
    controllers['nature_of_failure']!.text = preloadedSite['nature_of_failure'];
    controllers['action_taken']!.text = preloadedSite['action_taken'];
    controllers['rca']!.text = preloadedSite['rca'];
    controllers['customer_name']!.text = preloadedSite['customer_name'];
    controllers['contact_no']!.text = preloadedSite['contact_no'];
    controllers['customer_remarks']!.text = preloadedSite['customer_remarks'];
    controllers['problem_summary']!.text = preloadedSite['problem_summary'];
    setState(() {
      if(preloadedSite['is_dg']!= null && preloadedSite['is_dg'] == true) {
        _selectedEquipmentType = 'DG';
      } else if(preloadedSite['is_battery']!= null && preloadedSite['is_battery'] == true) {
        _selectedEquipmentType = 'Battery';
      } else if(preloadedSite['is_ccu']!= null && preloadedSite['is_ccu'] == true) {
        _selectedEquipmentType = 'CCU';
      } else if(preloadedSite['is_smps']!= null && preloadedSite['is_smps'] == true) {
        _selectedEquipmentType = 'SMPS';
      } else if(preloadedSite['is_solar']!= null && preloadedSite['is_solar'] == true) {
        _selectedEquipmentType = 'Solar';
      }
    });
    _loadImages(preloadedSite);
    _statusController.text = 'Open';
    controllers['responsible_party']!.addListener(_updateAssignedToField);
    for (var value in controllers.values) {
      value.addListener(_onFormChanged);
    }
  }

  // 👇 Jab user site select kare
  Future<void> _onSiteSelected(CMSite? selectedSite) async {
    if (selectedSite == null) {
      return;
    }

    setState(() {
      _selectedSite = selectedSite;
      _hasFormDataChanges = true;
    });

    //Automatically baaki fields fill karo
    _siteCodeController.text = selectedSite.siteCode;
    controllers['site_id']!.text = selectedSite.siteId.toString();
    _circleStateController.text = selectedSite.circleStateName;
    _clusterDistrictController.text = selectedSite.clusterDistrictName;
    _customerController.text = selectedSite.clientName ?? 'N/A';

    try {

      LoaderWidget.showLoader(context);
      if (widget.mode == CMScreenModeEnum.create) {
        final checklistData = await ServiceLocator().cmRepository
            .getChecklistData(2485);
        setState(() {
          _checklistData = checklistData;
        });
      }
      for (var value in controllers.values) {
        value.addListener(_onFormChanged);
      }
    } catch (e) {
      Logger.errorLog("exception in loading checklist $e");
      Toastbar.showErrorToastbar("Error while loading checklist", context);
    } finally {
      LoaderWidget.hideLoader();
    }
  }

  // 👇 Update assigned to field based on responsible party selection
  void _updateAssignedToField() {
    if (_selectedSite == null) return;
    if (controllers['responsible_party']!.text == 'OEM') {
      controllers['assigned_to']!.text = _selectedSite!.oem ?? '';
    } else if (controllers['responsible_party']!.text == 'Self') {
      controllers['assigned_to']!.text = _selectedSite!.self;
    }
  }

  @override
  void dispose() {
    _siteCodeController.dispose();
    _circleStateController.dispose();
    _clusterDistrictController.dispose();
    _customerController.dispose();
    for (var a in controllers.values) {
      a.dispose();
    }
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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if(widget.mode == CMScreenModeEnum.create) ...[
            CustomRadioButton(
              options: [
                OptionItem(label: "DG", value: "DG"),
                OptionItem(label: "Battery", value: "BATTERY"),
                OptionItem(label: "CCU", value: "CCU"),
                OptionItem(label: "SMPS", value: "SMPS"),
                OptionItem(label: "SOLAR", value: "SOLAR"),
              ],
              horizontalSpacing: 20,
              iconTextSpacing: 5,
              initialValue: _selectedEquipmentType,
              onChanged: (value) {
                setState(() {
                  _selectedEquipmentType = value;
                  _hasFormDataChanges = true;
                });
              },
            ),
            const SizedBox(height: 8),
          ],

          if (_selectedEquipmentType.isNotEmpty)
            ChecklistPreviewWidget(
              key: ValueKey('checklist_${_selectedEquipmentType}_${_selectedSite
                  ?.entityId}'),
              equipmentType: _selectedEquipmentType,
              checklistItemsByApi: _checklistData[_selectedEquipmentType] ?? [],
              entityId: _selectedSite?.entityId.toString(),
              onChecklistDataChanged: (List<dynamic> updatedData) {
                setState(() {
                  _onFormChanged();
                  _checklistData[_selectedEquipmentType] = updatedData;
                });
              },
              cmImpactedItemList: _impactedItemList ?? [],
              onImpactedItemListChanged: (
                  List<Map<String, dynamic>> impactedItems) {
                setState(() {
                  _impactedItemList = impactedItems;
                });
              },
              originalCmImpactedItemMap: _checklistData['siteDeployedItems'] ??
                  {},
            ),
        ],
      ),
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
              mainAxisSize: MainAxisSize.min,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.of(context).viewInsets.bottom + 100,
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_siteOptions.isNotEmpty)
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
                  backgroundColor: AppColors.cmSubmitButtonColor,
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
      mainAxisSize: MainAxisSize.min,
      children: [
        CustomDropdown(
            label: "Site Name",
            items: _siteOptions.map((o) => o.siteName).toList(),
            initialValue: _selectedSite?.siteName ?? '',
            onChanged: (selectedSiteName) async {
              if(selectedSiteName != null) {
                await _onSiteSelected(_siteOptions.firstWhere((o) => o.siteName == selectedSiteName));
              }
            },
            isRequired: true,
            isDisabled: widget.mode != CMScreenModeEnum.create
        ),
        getHeight(15),

        CustomFormField(
          label: "Site Id",
          controller: controllers['site_id'],
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

        CustomDropdown(
            label: "Responsible Party",
            items: _responsiblePartyOptions,
            initialValue: controllers['responsible_party']!.text,
            isRequired: true,
            onChanged: (value) {
              setState(() {
                controllers['responsible_party']!.text = value ?? "";
                _onFormChanged();
              });
            },
            isDisabled: widget.mode != CMScreenModeEnum.create
        ),
        getHeight(15),

        CustomFormField(
          label: "Assigned To",
          controller: controllers['assigned_to'],
          isEditable: false,
          isRequired: true,
        ),
        getHeight(15),

        // 👇 OEM Ticket ID - Required only when OEM is selected
        CustomFormField(
          label: "OEM Ticket ID",
          controller: controllers['oem_ticket_id'],
          isEditable: widget.mode == CMScreenModeEnum.create,
        ),
        getHeight(15),

        CustomDropdown(
            label: "Priority",
            items: _priorityOptions,
            initialValue: controllers['priority']!.text,
            isRequired: true,
            onChanged: (value) {
              setState(() {
                controllers['priority']!.text = value ?? "";
                _onFormChanged();
              });
            },
            isDisabled: widget.mode != CMScreenModeEnum.create
        ),
        getHeight(15),

        _buildEquipmentTypeRadioButtons(),
        getHeight(15),

        CustomDropdown(
            label: "Nature of Failure",
            items: _natureOfFailureOptions,
            initialValue: controllers['nature_of_failure']!.text,
            isRequired: true,
            onChanged: (value) {
              setState(() {
                controllers['nature_of_failure']!.text = value ?? "";
                _onFormChanged();
              });
            },
            isDisabled: widget.mode == CMScreenModeEnum.view
        ),
        getHeight(15),

        CustomFormField(
          label: "Action Taken",
          controller: controllers['action_taken'],
          isEditable: widget.mode != CMScreenModeEnum.view,
          isRequired: true,
        ),
        getHeight(15),

        CustomFormField(
          label: "RCA",
          controller: controllers['rca'],
          isEditable: widget.mode != CMScreenModeEnum.view,
          isRequired: true,
        ),
        getHeight(15),

        CustomFormField(
          label: "Customer Name",
          controller: controllers['customer_name'],
          isRequired: true,
          isEditable: widget.mode != CMScreenModeEnum.view,
        ),
        getHeight(15),

        CustomFormField(
          label: "Contact No.",
          controller: controllers['contact_no'],
          isRequired: true,
          isEditable: widget.mode != CMScreenModeEnum.view,
        ),
        getHeight(15),

        CustomFormField(
          label: "Customer Remarks",
          controller: controllers['customer_remarks'],
          isRequired: true,
          isEditable: widget.mode != CMScreenModeEnum.view,
        ),
        getHeight(15),

        CustomRemarksField(
          label: "Problem Summary",
          hintText: "Enter problem summary",
          controller: controllers['problem_summary']!,
        ),
        getHeight(15),

        ImageUploadField(
            label: "Customer Photo",
            placeholder: "Add a Photo",
            isRequired: true,
            onImageSelected: (File? file) async {
              if (file != null) {
                setState(() async {
                  customerPhoto = file;
                  customerPhotoByteData = await file.readAsBytes().then((bytes) => base64Encode(bytes));
                });
              }
            },
            externalImageUrl: customerPhotoByteData
        ),
        getHeight(15),

        CustomFileUploadNew(
          label: "Attachments",
          placeholder: "Upload File",
          uploadedFiles: _uploadedAttachments,
          onFileSelected: (File? file) {
            if (file != null) {
              setState(() {
                _uploadedAttachments.clear();
                _uploadedAttachments.add(file);
              });
            }
          },
          onFileDeleted: (File file) {
            // Handle file deletion
            setState(() {
              _uploadedAttachments.remove(file);
            });
          },
          isRequired: true,
          maxSizeText: "(Max Size: 2MB)",
          acceptedFileTypes: "(Accept Only - .pdf, .docx & .doc)",
        ),
        getHeight(30),
        if(widget.mode == CMScreenModeEnum.edit) ...[
          CustomDropdown(
            label: "Status",
            items: _statusOptions,
            initialValue: _statusController.text,
            isRequired: true,
            onChanged: (value) {
              setState(() {
                _statusController.text = value ?? "";
                _onFormChanged();
              });
            },
          ),
          getHeight(15),
          CustomRemarksField(
            label: "Remarks",
            hintText: "Enter remarks",
            controller: _remarksController,
          ),
          getHeight(15),
          CustomFileUploadNew(
            label: "Attachments",
            placeholder: "Upload File",
            uploadedFiles: _remarksAttachments,
            onFileSelected: (File? file) {
              if (file != null) {
                setState(() {
                  _remarksAttachments.clear();
                  _remarksAttachments.add(file);
                });
              }
            },
            onFileDeleted: (File file) {
              // Handle file deletion
              setState(() {
                _remarksAttachments.remove(file);
              });
            },
            isRequired: true,
            maxSizeText: "(Max Size: 2MB)",
            acceptedFileTypes: "(Accept Only - .pdf, .docx & .doc)",
          ),
          getHeight(30),
        ],

        CustomSubmitButtonV2(
          text: "Submit",
          onPressed: _validateAndSubmit,
        ),
      ],
    );
  }

  void _validateAndSubmit() async {
    if(widget.mode == CMScreenModeEnum.create) {
      _submitFormData();
    } else if(widget.mode == CMScreenModeEnum.edit) {
      _editFormData();
    }
  }

  void _editFormData() async {
    try {
      LoaderWidget.showLoader(context);
      if(cmSiteReqId == null) {
        return;
      }
      final requestData = <String, dynamic>{};
      requestData['cm_site_req_id'] = cmSiteReqId;
      for (var entry in controllers.entries) {
        requestData[entry.key] = entry.value.text;
      }
      if (controllers['responsible_party']!.text == 'OEM') {
        requestData['assigned_to'] = _selectedSite!.oemId;
      } else if (controllers['responsible_party']!.text == 'Self') {
        requestData['assigned_to'] = _selectedSite!.selfId;
      }
      requestData['cm_impacted_item_list'] = DataTransformationHelper
          .convertListToCamelCase(_impactedItemList);
      final selectedCheckListData = _checklistData[_selectedEquipmentType];
      LocationModel finalLocation;

      if(selectedCheckListData != null) {
        try {
          finalLocation = await LocationService.getCurrentLocation();
          DataTransformationHelper.updateMetadataInRequest(
              selectedCheckListData, finalLocation);
        } catch (e) {
          Logger.infoLog('Error getting location: $e');
          Toastbar.showErrorToastbar(
              ExceptionConstants.UNABLE_TO_GET_LOCATION, context);
          return;
        }
        requestData['cm_check_list_site_resp_list'] =
            DataTransformationHelper.convertListToCamelCase(
                selectedCheckListData);
      }
      Logger.infoLog("requestData: $requestData");
      try {
        Map<String, dynamic> processedData = DataTransformationHelper
            .convertKeysToCamelCase(requestData);
        Map<String, dynamic> response = await ServiceLocator().cmRepository
            .createCorrectiveMaintenance(processedData);
        String cmSiteReqId = response['cmSiteReqId'].toString();
        await ServiceLocator().cmRepository.saveRemarks(
            cmSiteReqId, _remarksController.text, _statusController.text, _remarksAttachments.first);
        Toastbar.showSuccessToastbar("Form Submitted Successfully", context);
      } catch (e) {
        Logger.errorLog(e.toString());
        Toastbar.showErrorToastbar("Failed to save the form", context);
      }
    } finally {
      LoaderWidget.hideLoader();
    }
  }

  void _submitFormData() async {
    try {
      LoaderWidget.showLoader(context);
      Logger.debugLog("vishal printing $_checklistData");
      final requestData = <String, dynamic>{};
      for (var entry in controllers.entries) {
        requestData[entry.key] = entry.value.text;
      }
      if (controllers['responsible_party']!.text == 'OEM') {
        requestData['assigned_to'] = _selectedSite!.oemId;
      } else if (controllers['responsible_party']!.text == 'Self') {
        requestData['assigned_to'] = _selectedSite!.selfId;
      }
      requestData['cm_site_req_id'] = 0;
      requestData['cm_impacted_item_list'] = DataTransformationHelper
          .convertListToCamelCase(_impactedItemList);
      final selectedCheckListData = _checklistData[_selectedEquipmentType];
      LocationModel finalLocation;

      try {
        finalLocation = await LocationService.getCurrentLocation();
        DataTransformationHelper.updateMetadataInRequest(
            selectedCheckListData, finalLocation);
      } catch (e) {
        Logger.infoLog('Error getting location: $e');
        Toastbar.showErrorToastbar(
            ExceptionConstants.UNABLE_TO_GET_LOCATION, context);
        return;
      }
      requestData['cm_check_list_site_resp_list'] =
          DataTransformationHelper.convertListToCamelCase(
              selectedCheckListData);
      Logger.infoLog("requestData: $requestData");
      try {
        Map<String, dynamic> processedData = DataTransformationHelper
            .convertKeysToCamelCase(requestData);
        Map<String, dynamic> response = await ServiceLocator().cmRepository
            .createCorrectiveMaintenance(processedData);
        String cmSiteReqId = response['cmSiteReqId'].toString();
        await ServiceLocator().cmRepository.saveCustomerPhotoAndAttachments(
            cmSiteReqId, customerPhoto!, _uploadedAttachments.first);
        Toastbar.showSuccessToastbar("Form Submitted Successfully", context);
      } catch (e) {
        Logger.errorLog(e.toString());
        Toastbar.showErrorToastbar("Failed to save the form", context);
      }
    } finally {
      LoaderWidget.hideLoader();
    }

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
      AssetAuditNavigationHelper.navigateToHomeScreen(context);
    }
  }
}