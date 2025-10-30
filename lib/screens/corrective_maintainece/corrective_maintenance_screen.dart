import 'dart:convert';
import 'dart:io';
import 'package:app/commonWidgets/cm_remarks_show_widget.dart';
import 'package:app/commonWidgets/custom_file_upload_new.dart';
import 'package:app/commonWidgets/custom_form_dropdown.dart';
import 'package:app/commonWidgets/custom_image_upload_field.dart';
import 'package:app/commonWidgets/custom_radio_options.dart';
import 'package:app/commonWidgets/custom_remark.dart';
import 'package:app/commonWidgets/loader_widget.dart';
import 'package:app/constants/exception_constants.dart';
import 'package:app/enum/corrective_maintenance_screen_mode_enum.dart';
import 'package:app/enum/activity_type_enum.dart';
import 'package:app/models/location_model.dart';
import 'package:app/screens/corrective_maintainece/cm_checklist_create_widget.dart';
import 'package:app/screens/corrective_maintainece/cm_view_widget.dart';
import 'package:app/services/location_service.dart';
import 'package:app/utils.dart';
import 'package:app/utils/asset_audit_navigation_helper.dart';
import 'package:app/utils/data_transformation_helper.dart';
import 'package:app/utils/logger.dart';
import 'package:app/utils/toastbar.dart';
import 'package:app/utils/connectivity_helper.dart';
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
    'site_id': TextEditingController(),
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
  final TextEditingController _siteNameController = TextEditingController();
  final TextEditingController _siteCodeController = TextEditingController();
  final TextEditingController _circleStateController = TextEditingController();
  final TextEditingController _clusterDistrictController =
      TextEditingController();
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

    controllers['responsible_party']!.addListener(_updateAssignedToField);
    if (widget.preloadedSites != null) {
      Logger.infoLog("🔄 [CM] Preloaded sites: ${widget.preloadedSites}");

      _siteOptions = widget.preloadedSites!;
      // Automatically select the first (and only) preloaded site
      if (_siteOptions.isNotEmpty) {
        _onSiteSelected(_siteOptions.first);
      }
    } else {
      Logger.infoLog("[CM] Preloaded site data: ${widget.preloadedSiteData}");

      if (widget.preloadedSiteData == null) {
        Logger.errorLog("❌ [CM] preloadedSiteData is null");
        return;
      }
      Map<String, dynamic> preloadedSite = widget.preloadedSiteData!;
      cmSiteReqId = preloadedSite['cm_site_req_id'];
      CMSite site = CMSite(
        siteId: preloadedSite['site_id'] ?? 0,
        entityId: preloadedSite['entity_id'] ?? 0,
        siteCode: preloadedSite['site_code'] ?? '',
        siteName: preloadedSite['site_name'] ?? '',
        clusterDistrictId: 0,
        clusterDistrictName: preloadedSite['cluster'] ?? '',
        circleStateId: 0,
        circleStateName: preloadedSite['circle'] ?? '',
        self: preloadedSite['assigned_to_name'] ?? '',
        selfId: preloadedSite['assigned_to'] ?? 0,
      );
      _siteOptions = [site];
      _initializeTicketControllers(preloadedSite);
      _onSiteSelected(site);
    }
  }

  void _loadImages(Map<String, dynamic> preloadedSite) async {
    if (preloadedSite['customer_photo_id'] != null) {
      String? customerPhotoByteDataLocal = await ServiceLocator()
          .imageUploadService
          .downloadFromServer(preloadedSite['customer_photo_id'].toString());

      if (customerPhotoByteDataLocal != null) {
        File? imageFile = await Utils.buildImageFromBytesData(
          customerPhotoByteDataLocal,
        );
        customerPhoto = imageFile;
        setState(() {
          customerPhotoByteData = customerPhotoByteDataLocal;
        });
      }
    }
    if (preloadedSite['customer_attachment_id'] != null) {
      String? attachmentByteData = await ServiceLocator().imageUploadService
          .downloadFromServer(
            preloadedSite['customer_attachment_id'].toString(),
          );

      if (attachmentByteData != null) {
        File? imageFile = await Utils.buildImageFromBytesData(
          attachmentByteData,
        );
        if (imageFile != null) {
          setState(() {
            _uploadedAttachments.add(imageFile);
          });
        }
      }
    }
  }

  void _initializeTicketControllers(Map<String, dynamic> preloadedSite) {
    controllers['responsible_party']!.text =
        preloadedSite['responsible_party']?.toString() ?? '';
    controllers['assigned_to']!.text =
        preloadedSite['assigned_to_name']?.toString() ?? '';
    controllers['priority']!.text = preloadedSite['priority']?.toString() ?? '';
    controllers['oem_ticket_id']!.text =
        preloadedSite['oem_ticket_id']?.toString() ?? '';
    controllers['nature_of_failure']!.text =
        preloadedSite['nature_of_failure']?.toString() ?? '';
    controllers['action_taken']!.text =
        preloadedSite['action_taken']?.toString() ?? '';
    controllers['rca']!.text = preloadedSite['rca']?.toString() ?? '';
    controllers['customer_name']!.text =
        preloadedSite['customer_name']?.toString() ?? '';
    controllers['contact_no']!.text =
        preloadedSite['contact_no']?.toString() ?? '';
    controllers['customer_remarks']!.text =
        preloadedSite['customer_remarks']?.toString() ?? '';
    controllers['problem_summary']!.text =
        preloadedSite['problem_summary']?.toString() ?? '';
    setState(() {
      if (preloadedSite['is_dg'] != null && preloadedSite['is_dg'] == true) {
        _selectedEquipmentType = 'DG';
      } else if (preloadedSite['is_battery'] != null &&
          preloadedSite['is_battery'] == true) {
        _selectedEquipmentType = 'BATTERY';
      } else if (preloadedSite['is_ccu'] != null &&
          preloadedSite['is_ccu'] == true) {
        _selectedEquipmentType = 'CCU';
      } else if (preloadedSite['is_smps'] != null &&
          preloadedSite['is_smps'] == true) {
        _selectedEquipmentType = 'SMPS';
      } else if (preloadedSite['is_solar'] != null &&
          preloadedSite['is_solar'] == true) {
        _selectedEquipmentType = 'SOLAR';
      }
    });
    _loadImages(preloadedSite);
    // Only set default status if not already set from preloaded data
    if (_statusController.text.isEmpty) {
      _statusController.text = 'Open';
    }
    for (var value in controllers.values) {
      value.addListener(_onFormChanged);
    }
  }

  // 👇 Jab user site select kare
  Future<void> _onSiteSelected(CMSite? selectedSite) async {
    if (selectedSite == null) {
      Logger.errorLog("⚠️ [CM] selectedSite is null");
      return;
    }

    Logger.infoLog(
      "✅ [CM] Site selected: ${selectedSite.siteName}, entityId: ${selectedSite.entityId}, mode: ${widget.mode}",
    );

    print("vishal printing selectedSite: $selectedSite");

    setState(() {
      _selectedSite = selectedSite;
      _hasFormDataChanges = true;

      // Populate site fields
      _siteNameController.text = selectedSite.siteName;
      _siteCodeController.text = selectedSite.siteCode;
      _circleStateController.text = selectedSite.circleStateName;
      _clusterDistrictController.text = selectedSite.clusterDistrictName;
      _customerController.text = selectedSite.clientName ?? '';
      controllers['site_id']!.text = selectedSite.siteId.toString();
    });

    // Wait for the current build to complete before showing loader
    await Future.delayed(Duration.zero);

    try {
      if (mounted) LoaderWidget.showLoader(context);
      if (widget.mode == CMScreenModeEnum.create) {
        // Try to load from local database first
        Logger.infoLog(
          "🔄 [CM] Attempting to load checklist data from local database for siteId: ${selectedSite.siteId}",
        );

        print("vishal printing selectedSite.entityId: ${selectedSite.entityId}");
        
        Map<String, dynamic> checklistData = {};
        
        try {
          // Try to get site data with checklist from local database first
          Logger.infoLog("🔄 [CM] Checking local database for site data with checklist...");
          Logger.infoLog("🆔 [CM] Looking for site ID: ${selectedSite.siteId}, entityId: ${selectedSite.entityId}");

        print("vishal printing selectedSite.entityId: ${selectedSite.entityId}");

          final siteDataWithChecklist = await ServiceLocator()
              .centralAssetAuditDataService
              .getCMSiteDataWithChecklist(selectedSite.siteId);
          
          Logger.infoLog("🔍 [CM] Site data lookup result: ${siteDataWithChecklist != null ? 'FOUND' : 'NOT_FOUND'}");
          
          if (siteDataWithChecklist != null && siteDataWithChecklist['checklist_items'] != null) {
            Logger.infoLog("✅ [CM] Found site data with checklist_items in local database");
            print("vishal printing siteDataWithChecklist: $siteDataWithChecklist");
            checklistData = Map<String, dynamic>.from(siteDataWithChecklist['checklist_items']);
            Logger.infoLog("✅ [CM] Checklist data loaded with types: ${checklistData.keys.toList()}");
            print("vishal printing checklistData: $checklistData");
          } else {
            // Fallback: Try separate checklist table
            Logger.infoLog("⚠️ [CM] No checklist in site data, checking separate checklist table...");

            Logger.infoLog("🆔 [CM] Looking for checklist data for site ID: ${selectedSite.siteId}");
            print("vishal printing selectedSite.entityId: ${selectedSite.entityId}");
            final localChecklistData = await ServiceLocator()
                .centralAssetAuditDataService
                .getCMChecklistData(selectedSite.siteId);
            
            Logger.infoLog("🔍 [CM] Separate checklist lookup result: ${localChecklistData.length} equipment types");
            
            Logger.infoLog("🔍 [CM] Local checklist table returned ${localChecklistData.length} equipment types");
            print("vishal printing localChecklistData: $localChecklistData");

            if (localChecklistData.isNotEmpty) {
              Logger.infoLog("✅ [CM] Checklist data loaded from separate table with types: ${localChecklistData.keys.toList()}");
              print("vishal printing localChecklistData: $localChecklistData");
              checklistData = localChecklistData;
            } else {
              Logger.infoLog("⚠️ [CM] No local checklist data found, fetching from API");
              print("vishal printing selectedSite.entityId: ${selectedSite.entityId}");
              try {
                // Check if site is downloaded - if not, suggest downloading first
                final isSiteDownloaded = await ServiceLocator()
                    .centralAssetAuditDataService
                    .isCMSiteDownloaded(selectedSite.siteId);
                
                if (!isSiteDownloaded) {
                  throw Exception("This site is not downloaded. Please download the site data first to use it offline.");
                }
                
                // Fallback to API call (only if online)
                checklistData = await ServiceLocator().cmRepository
                    .getChecklistData(selectedSite.entityId);
                
                Logger.infoLog("✅ [CM] Checklist data fetched from API");
                print("vishal printing checklistData: $checklistData");
                
                // Save to local database for offline use
                try {
                  await ServiceLocator().centralAssetAuditService.downloadCMChecklist(
                    siteId: selectedSite.siteId,
                    entityId: selectedSite.entityId,
                    siteCode: selectedSite.siteCode,
                    siteName: selectedSite.siteName,
                  );
                  Logger.infoLog("✅ [CM] Checklist data saved to local database");
                  print("vishal printing checklistData: $checklistData");
                } catch (saveError) {
                  Logger.errorLog("⚠️ [CM] Failed to save checklist to local database: $saveError");
                  print("vishal printing saveError: $saveError");
                  // Continue even if save fails
                }
              } catch (apiError) {
                Logger.errorLog("❌ [CM] Failed to fetch checklist from API: $apiError");
                print("vishal printing apiError: $apiError");
                // If API fails and no local data, show error
                if (apiError.toString().contains("host lookup") || 
                    apiError.toString().contains("connection") ||
                    apiError.toString().contains("internet")) {
                  throw Exception("No internet connection. Please download the site data first to use it offline, or check your internet connection.");
                }
                throw Exception("Unable to load checklist data. Please check your internet connection or download the site data first.");
              }
            }
          }
        } catch (dbError) {
          Logger.errorLog("❌ [CM] Local database check failed: $dbError");
          print("vishal printing dbError: $dbError");
          // Re-throw the error to show message to user
          rethrow;
        }
        
        Logger.infoLog("✅ [CM] Checklist data received: ${checklistData.keys}");
        if (mounted) {
          setState(() {
            _checklistData = checklistData;
          });
        }
      } else {
        Logger.infoLog(
          "⚠️ [CM] Skipping getChecklistData - mode is ${widget.mode}, not CREATE",
        );
      }
      for (var value in controllers.values) {
        value.addListener(_onFormChanged);
      }
    } catch (e) {
      Logger.errorLog("❌ [CM] Exception in loading checklist: $e");
      if (mounted) {
        Toastbar.showErrorToastbar(
          "Error loading checklist: ${e.toString()}",
          context,
        );
      }
    } finally {
      if (mounted) LoaderWidget.hideLoader();
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
    _siteNameController.dispose();
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

  //  Future<void> _onImageSelected(File imageFile) async {
  //   try {
  //     Logger.debugLog('📸 CustomAssetAuditFormSection: Starting image upload');

  //     // Get API service from context
  //     final apiService = AppConfig.of(context).apiService;
  //     final imageUploadService = ImageUploadService(apiService: apiService);

  //     // Upload image using ImageUploadService
  //     final uniqueId = await imageUploadService.uploadImage(
  //       await imageFile.readAsBytes().then((bytes) => base64Encode(bytes)),
  //       ActivityTypeEnum.assetAudit,
  //       false,
  //       widget.siteAuditSchId,
  //     );

  //     if (uniqueId.isNotEmpty) {
  //       setState(() {
  //         _uploadedImgId = uniqueId;
  //       });

  //       // Notify parent component
  //       widget.onImageSelected?.call(uniqueId);

  //       Logger.debugLog('✅ CustomAssetAuditFormSection: Image uploaded successfully with ID: $uniqueId');
  //     } else {
  //       Logger.errorLog('❌ CustomAssetAuditFormSection: Failed to upload image');
  //       _showErrorSnackBar('Failed to upload image');
  //     }
  //   } catch (e) {
  //     Logger.errorLog('❌ CustomAssetAuditFormSection: Error uploading image: $e');
  //     _showErrorSnackBar('Error uploading image: $e');
  //   }
  // }

  Widget _buildEquipmentTypeRadioButtons() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.mode == CMScreenModeEnum.create) ...[
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

        if (_selectedEquipmentType.isNotEmpty &&
            widget.mode == CMScreenModeEnum.create)
          ChecklistCreateWidget(
            key: ValueKey(
              'checklist_${_selectedEquipmentType}_${_selectedSite?.entityId}',
            ),
            equipmentType: _selectedEquipmentType,
            checklistItemsByApi: _checklistData[_selectedEquipmentType] ?? [],
            entityId: _selectedSite?.entityId.toString(),
            onChecklistDataChanged: (List<dynamic> updatedData) {
              setState(() {
                _onFormChanged();
                _checklistData[_selectedEquipmentType] = updatedData;
              });
            },
            cmImpactedItemList: _impactedItemList,
            onImpactedItemListChanged:
                (List<Map<String, dynamic>> impactedItems) {
                  setState(() {
                    _impactedItemList = impactedItems;
                  });
                },
            originalCmImpactedItemMap:
                _checklistData['siteDeployedItems'] ?? {},
            onMultiDynamicDropdownValueChanged:
                (List<Map<String, dynamic>> impactedItems, String dropdownId) {
                  setState(() {
                    // Remove existing items from this specific dropdown
                    _impactedItemList.removeWhere(
                      (item) => item['_dropdownId'] == dropdownId,
                    );

                    // Add new items with dropdown identifier
                    for (var item in impactedItems) {
                      var newItem = Map<String, dynamic>.from(item);
                      newItem['_dropdownId'] = dropdownId;
                      _impactedItemList.add(newItem);
                    }
                  });
                },
          ),
        if (widget.mode != CMScreenModeEnum.create)
          ChecklistCreateWidgetView(
            equipmentType: _selectedEquipmentType,
            checklistItemsByApi:
                widget.preloadedSiteData?['cm_check_list_site_resp_list'] ?? [],
            originalCmImpactedItemMap:
                widget.preloadedSiteData?['cm_impacted_item_map_list'] ?? {},
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
            child: SvgPicture.asset(AppImages.home, fit: BoxFit.cover),
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
                          if (_siteOptions.isNotEmpty) _buildFormFields(),
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
        // CustomDropdown(
        //     label: "Site Name",
        //     items: _siteOptions.map((o) => o.siteName).toList(),
        //     initialValue: _selectedSite?.siteName ?? '',
        //     onChanged: (selectedSiteName) async {
        //       if(selectedSiteName != null) {
        //         await _onSiteSelected(_siteOptions.firstWhere((o) => o.siteName == selectedSiteName));
        //       }
        //     },
        //     isRequired: true,
        //     isDisabled: true // Always disabled - cannot be clicked
        // ),
        CustomFormField(
          label: "Site Name",
          controller: _siteNameController,
          isEditable: false,
        ),
        getHeight(15),

        CustomFormField(
          label: "Site Id",
          controller: _siteCodeController,
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
          isDisabled: widget.mode != CMScreenModeEnum.create,
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
          isRequired:
              controllers['responsible_party'] != null &&
              controllers['responsible_party']?.text == 'OEM',
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
          isDisabled: widget.mode != CMScreenModeEnum.create,
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
          isDisabled: widget.mode == CMScreenModeEnum.view,
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
          inputType: InputType.number,
          maxLength: 10,
        ),
        getHeight(15),

        CustomFormField(
          label: "Customer Remarks",
          controller: controllers['customer_remarks'],
          isRequired: false,
          isEditable: widget.mode != CMScreenModeEnum.view,
        ),
        getHeight(15),

        CustomRemarksField(
          label: "Problem Summary",
          hintText: "Enter problem summary",
          controller: controllers['problem_summary']!,
          isDisabled: widget.mode == CMScreenModeEnum.view,
        ),
        getHeight(15),

        ImageUploadField(
          label: "Customer Photo",
          placeholder: "Add a Photo",
          isRequired: false,
          onImageSelected: (File? file) async {
            if (file != null) {
              // Perform async operation first
              final bytes = await file.readAsBytes();
              final encodedData = base64Encode(bytes);

              // Then update state synchronously
              setState(() {
                customerPhoto = file;
                customerPhotoByteData = encodedData;
              });
            }
          },
          externalImageUrl: customerPhotoByteData,
          isDisabled: widget.mode == CMScreenModeEnum.view,
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
          isRequired: false,
          maxSizeText: "(Max Size: 2MB)",
          acceptedFileTypes: "(Accept Only - .pdf, .docx & .doc)",
          isDisabled: widget.mode == CMScreenModeEnum.view,
        ),
        getHeight(30),
        if (widget.mode == CMScreenModeEnum.edit) ...[
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
        if (widget.mode != CMScreenModeEnum.create)
          CMRemarksShowWidget(
            remarksList: widget.preloadedSiteData?['cm_remarks_list'],
          ),
        CustomSubmitButtonV2(text: "Submit", onPressed: _validateAndSubmit),
      ],
    );
  }

  void _validateAndSubmit() async {
    if (widget.mode == CMScreenModeEnum.create) {
      _submitFormData();
    } else if (widget.mode == CMScreenModeEnum.edit) {
      _editFormData();
    }
  }

  void _editFormData() async {
    try {
      LoaderWidget.showLoader(context);
      if (cmSiteReqId == null) {
        return;
      }
      final requestData = <String, dynamic>{};
      requestData['cm_site_req_id'] = cmSiteReqId;
      for (var entry in controllers.entries) {
        requestData[entry.key] = entry.value.text;
      }
      // Add status to request data
      requestData['status'] = _statusController.text;
      if (controllers['responsible_party']!.text == 'OEM') {
        requestData['assigned_to'] = _selectedSite!.oemId;
      } else if (controllers['responsible_party']!.text == 'Self') {
        requestData['assigned_to'] = _selectedSite!.selfId;
      }
      requestData['cm_impacted_item_list'] =
          DataTransformationHelper.convertListToCamelCase(_impactedItemList);
      final selectedCheckListData = _checklistData[_selectedEquipmentType];
      LocationModel finalLocation;

      if (selectedCheckListData != null) {
        try {
          finalLocation = await LocationService.getCurrentLocation();
          DataTransformationHelper.updateMetadataInRequest(
            selectedCheckListData,
            finalLocation,
          );
        } catch (e) {
          Logger.infoLog('Error getting location: $e');
          Toastbar.showErrorToastbar(
            ExceptionConstants.UNABLE_TO_GET_LOCATION,
            context,
          );
          return;
        }
        
        // Add cmItemType to each checklist item if not already present
        for (var item in selectedCheckListData) {
          if (item['cmItemType'] == null || item['cmItemType'].toString().isEmpty) {
            item['cmItemType'] = item['subItemType'] ?? _selectedEquipmentType;
          }
        }
        
        requestData['cm_check_list_site_resp_list'] =
            DataTransformationHelper.convertListToCamelCase(
              selectedCheckListData,
            );
      }
      Logger.infoLog("requestData: $requestData");

      try {
        //   await ServiceLocator().assetAuditPostService.postAssetAuditDataWithPhotoReplacement(
        //   requests: [requestData],
        //   isLastPage: true,
        //   activityType: ActivityTypeEnum.correctiveMaintenance,
        // );

        Map<String, dynamic> processedData =
            DataTransformationHelper.convertKeysToCamelCase(requestData);
        await ServiceLocator().cmRepository.createCorrectiveMaintenance(
          processedData,
        );

        Logger.debugLog(" processedData: $processedData");

        await ServiceLocator().cmRepository.saveCustomerPhotoAndAttachments(
          cmSiteReqId!,
          customerPhoto,
          _uploadedAttachments.firstOrNull,
        );
        if (_remarksAttachments.isNotEmpty) {
          await ServiceLocator().cmRepository.saveRemarks(
            cmSiteReqId!,
            _remarksController.text,
            _statusController.text,
            _remarksAttachments.first,
          );
        }
        Toastbar.showSuccessToastbar("Form Submitted Successfully", context);
        // AssetAuditNavigationHelper.navigateToHomeScreen(context);
      } catch (e) {
        Logger.errorLog(e.toString());
        print("Failed to save the form edit : $e");
        Toastbar.showErrorToastbar(
          "Failed to save the form edit : $e",
          context,
        );
      }
    } finally {
      LoaderWidget.hideLoader();
    }
  }

  void _submitFormData() async {
    try {
      LoaderWidget.showLoader(context);

      // Check internet connectivity
      final isConnected = await ConnectivityHelper.isConnected();
      Logger.infoLog("CM form submission - Connected: $isConnected");

      final requestData = <String, dynamic>{};
      for (var entry in controllers.entries) {
        requestData[entry.key] = entry.value.text;
      }
      if (controllers['responsible_party']!.text == 'OEM') {
        requestData['assigned_to'] = _selectedSite!.oemId;
      } else if (controllers['responsible_party']!.text == 'Self') {
        requestData['assigned_to'] = _selectedSite!.selfId;
      }
      if (_selectedEquipmentType == 'DG') {
        requestData['isDg'] = true;
      } else if (_selectedEquipmentType == 'BATTERY') {
        requestData['isBattery'] = true;
      } else if (_selectedEquipmentType == 'CCU') {
        requestData['isCcu'] = true;
      } else if (_selectedEquipmentType == 'SMPS') {
        requestData['isSmps'] = true;
      } else if (_selectedEquipmentType == 'SOLAR') {
        requestData['isSolar'] = true;
      }
      requestData['cm_site_req_id'] = 0;
      requestData['cm_impacted_item_list'] =
          DataTransformationHelper.convertListToCamelCase(_impactedItemList);
      final selectedCheckListData = _checklistData[_selectedEquipmentType];
      LocationModel finalLocation;

      try {
        finalLocation = await LocationService.getCurrentLocation();
        DataTransformationHelper.updateMetadataInRequest(
          selectedCheckListData,
          finalLocation,
        );
      } catch (e) {
        Logger.infoLog('Error getting location: $e');
        Toastbar.showErrorToastbar(
          ExceptionConstants.UNABLE_TO_GET_LOCATION,
          context,
        );
        return;
      }
      
      // Add cmItemType to each checklist item if not already present
      for (var item in selectedCheckListData) {
        if (item['cmItemType'] == null || item['cmItemType'].toString().isEmpty) {
          item['cmItemType'] = item['subItemType'] ?? _selectedEquipmentType;
        }
      }
      
      requestData['cm_check_list_site_resp_list'] =
          DataTransformationHelper.convertListToCamelCase(
            selectedCheckListData,
          );
      Logger.infoLog("requestData: $requestData");
      print("vishal printing requestData: $requestData");

      if (isConnected) {
        // Online mode: Process images first, then submit
        try {
          await _handleOnlineSubmission(requestData);
        } catch (e) {
          Logger.errorLog("Online submission failed: $e");
          // Fallback to offline mode
          await _handleOfflineSubmission(requestData, finalLocation);
        }
      } else {
        // Offline mode: Save to pending requests
        await _handleOfflineSubmission(requestData, finalLocation);
      }
    } finally {
      LoaderWidget.hideLoader();
    }
  }

  Future<void> _handleOnlineSubmission(Map<String, dynamic> requestData) async {
    try {
      // Convert keys to camelCase for API
      Map<String, dynamic> processedData =
          DataTransformationHelper.convertKeysToCamelCase(requestData);
      
      // Create CM ticket first
      final response = await ServiceLocator().cmRepository.createCorrectiveMaintenance(processedData);
      
      if (response.containsKey('cmSiteReqId')) {
        final cmSiteReqId = response['cmSiteReqId'] as int;
        Logger.infoLog("CM ticket created with ID: $cmSiteReqId");
        
        // Upload customer photo and attachments after creating the ticket
        if (customerPhoto != null || _uploadedAttachments.isNotEmpty) {
          await ServiceLocator().cmRepository.saveCustomerPhotoAndAttachments(
            cmSiteReqId,
            customerPhoto,
            _uploadedAttachments.isNotEmpty ? _uploadedAttachments.first : null,
          );
          Logger.infoLog("CM images uploaded successfully");
        }
      }

      Toastbar.showSuccessToastbar("Form Submitted Successfully", context);
      // AssetAuditNavigationHelper.navigateToHomeScreen(context);
    } catch (e) {
      Logger.errorLog("Error in online submission: $e");
      rethrow;
    }
  }

  Future<void> _handleOfflineSubmission(
    Map<String, dynamic> requestData,
    LocationModel location,
  ) async {
    try {
      Logger.infoLog("Saving CM form data offline");

      // Upload images first and get unique IDs
      String? customerPhotoId;
      String? attachmentId;

      if (customerPhoto != null) {
        customerPhotoId = await _uploadImageWithOfflineSupport(
          customerPhoto!,
          ActivityTypeEnum.correctiveMaintenance,
        );
      }

      if (_uploadedAttachments.isNotEmpty) {
        attachmentId = await _uploadImageWithOfflineSupport(
          _uploadedAttachments.first,
          ActivityTypeEnum.correctiveMaintenance,
        );
      }

      // Add image IDs to request data
      if (customerPhotoId != null) {
        requestData['customer_photo_id'] = customerPhotoId;
      }
      if (attachmentId != null) {
        requestData['customer_attachment_id'] = attachmentId;
      }

      // Save to pending requests for sync when online
      final requestId = 'cm_${DateTime.now().millisecondsSinceEpoch}';
      final url = '/api/v1/mobile/correctiveMaintenance';
      final isSaved = await ServiceLocator().pendingRequestService.savePendingRequest(
        requestId: requestId,
        url: url,
        headers: {},
        jsonEncodedRequestData: jsonEncode([requestData]),
      );

      if (isSaved) {
        Logger.infoLog("CM data saved to pending requests successfully");
        Toastbar.showSuccessToastbar("Data saved offline. Will sync when online.", context);
        // AssetAuditNavigationHelper.navigateToHomeScreen(context);
      } else {
        throw Exception('Failed to save data to offline storage');
      }
    } catch (e) {
      Logger.errorLog("Error in offline submission: $e");
      Toastbar.showErrorToastbar(
        "Failed to save form offline: $e",
        context,
      );
    }
  }

  Future<String?> _uploadImageWithOfflineSupport(
    File imageFile,
    ActivityTypeEnum activityType,
  ) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(bytes);
      
      // Upload using ImageUploadService which handles offline automatically
      final uniqueId = await ServiceLocator().imageUploadService.uploadImage(
        base64Image,
        activityType,
        false, // not a selfie
        null, // no sch id for CM
      );

      Logger.infoLog("Image uploaded with ID: $uniqueId");
      return uniqueId;
    } catch (e) {
      Logger.errorLog("Error uploading image: $e");
      return null;
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
      // AssetAuditNavigationHelper.navigateToHomeScreen(context);
    }
  }
}
