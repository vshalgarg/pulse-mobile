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
import 'package:app/enum/activity_type_enum.dart';
import 'package:app/models/location_model.dart';
import 'package:app/screens/corrective_maintainece/cm_checklist_create_widget.dart';
import 'package:app/services/location_service.dart';
import 'package:app/services/upload_dcouments.dart';
import 'package:app/utils.dart';
import 'package:app/utils/data_transformation_helper.dart';
import 'package:app/utils/logger.dart';
import 'package:app/utils/toastbar.dart';
import 'package:app/utils/connectivity_helper.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import '../../../commonWidgets/custom_form_appbar.dart';
import '../../../commonWidgets/custom_form_field.dart';
import '../../../commonWidgets/custom_buttons/arrow_botton.dart';
import '../../../commonWidgets/custom_dialogs/unsaved_changes_dialog.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_images.dart';
import '../../../constants/constants_methods.dart';
import '../../../services/service_locator.dart';
import '../../../models/cm_site_model.dart';
import '../../../routes/route_generator.dart';
import 'package:app/commonWidgets/safe_svg_picture.dart';

class CorrectiveMaintenanceScreen extends StatefulWidget {
  final CMScreenModeEnum mode;
  final List<CMSite>? preloadedSites;
  final Map<String, dynamic>? preloadedSiteData;
  final BuildContext? parentContext;

  const CorrectiveMaintenanceScreen({
    super.key,
    required this.mode,
    this.preloadedSites,
    this.preloadedSiteData,
    this.parentContext,
  });

  @override
  State<CorrectiveMaintenanceScreen> createState() =>
      _CorrectiveMaintenanceScreenState();
}

class _CorrectiveMaintenanceScreenState
    extends State<CorrectiveMaintenanceScreen> {
  UploadDcoumentsService get _uploadDocumentsService =>
      UploadDcoumentsService(apiService: ServiceLocator().apiService);

  // 👇 Controllers
  Map<String, TextEditingController> controllers = {
    'site_id': TextEditingController(),
    'responsible_party': TextEditingController(),
    'assigned_to': TextEditingController(),
    'oem_ticket_id': TextEditingController(),
    'priority': TextEditingController(),
    'fault_description': TextEditingController(),
    'nature_of_failure': TextEditingController(),
    'scope_of_ticket': TextEditingController(),
    'action_taken': TextEditingController(),
    'rca': TextEditingController(),
    'closure_date': TextEditingController(),
    'oem_representative': TextEditingController(),
    'oem_representative_contact': TextEditingController(),
    'customer_name': TextEditingController(),
    'contact_no': TextEditingController(),
    'problem_summary': TextEditingController(),
  };

  // 👇 Site related controllers - Auto-fill ke liye
  final TextEditingController _siteNameController = TextEditingController();
  final TextEditingController _siteCodeController = TextEditingController();
  final TextEditingController _circleStateController = TextEditingController();
  final TextEditingController _clusterDistrictController =
      TextEditingController();
  final TextEditingController _customerController = TextEditingController();
  final TextEditingController _cmTicketNoController = TextEditingController();
  final TextEditingController _startDateController = TextEditingController();
  final TextEditingController _currentStatusController = TextEditingController();
  final TextEditingController _infraEngineerNameController = TextEditingController();
  final TextEditingController _infraEngineerContactNoController = TextEditingController();
  final TextEditingController _clusterInchargeNameController = TextEditingController();
  final TextEditingController _clusterInchargeContactNoController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController();

  // 👇 Dropdown selections
  CMSite? _selectedSite;
  String _selectedEquipmentType = "DG";

  int? cmSiteReqId;

  // New photo fields: Identification, Time Stamp Photo (only in edit/view mode)
  File? identificationPhoto;
  String identificationPhotoByteData = "";
  dynamic _originalIdentificationPhotoId;
  
  File? timestampPhoto;
  String timestampPhotoByteData = "";
  dynamic _originalTimestampPhotoId;

  final List<File> _fsrAttachments = [];
  String? _fsrAttachmentName;
  dynamic _fsrAttachmentId;
  
  // 👇 Dropdown options
  List<CMSite> _siteOptions = [];
  final List<String> _priorityOptions = ['Critical', 'Non Critical'];
  final List<String> _responsiblePartyOptions = ['OEM', 'Self'];
  final List<String> _natureOfFailureOptions = ['AMC', 'Paid', 'FOC'];
  final List<String> _scopeOfTicketOptions = ['In Warranty', 'Warranty Out'];
  Map<String, dynamic> _checklistData = {};
  List<Map<String, dynamic>> _impactedItemList = [];

  bool _hasFormDataChanges = false;
  bool _isSubmitting = false; // Flag to prevent duplicate submissions
  bool _forceViewMode = false;
  Map<String, dynamic>? _mergedPreloadedSite;
  String _oemTicketIdDisplay = '';

  CMScreenModeEnum get _resolvedMode =>
      _forceViewMode ? CMScreenModeEnum.view : widget.mode;

  bool _isClosedStatus(dynamic status) {
    if (status == null) return false;
    final normalized = status.toString().trim().toUpperCase();
    return normalized == 'CLOSE' || normalized == 'CLOSED';
  }

  @override
  void initState() {
    super.initState();
    // Use preloaded sites if available, otherwise load them

    controllers['responsible_party']!.addListener(() {
      _updateAssignedToField();
      // Trigger rebuild when responsible party changes to show/hide OEM fields
      if (mounted) {
        setState(() {});
      }
    });
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
      Map<String, dynamic> preloadedSite = Map<String, dynamic>.from(widget.preloadedSiteData!);
      
      // Handle nested data structure if present
      if (preloadedSite.containsKey('data') && preloadedSite['data'] is Map<String, dynamic>) {
        preloadedSite = Map<String, dynamic>.from(preloadedSite['data']);
      }
      _mergedPreloadedSite = preloadedSite;

      // Try both camelCase and snake_case for cmSiteReqId
      cmSiteReqId = preloadedSite['cmSiteReqId'] ?? preloadedSite['cm_site_req_id'];
      
      // Helper function to get value with fallback for both camelCase and snake_case
      T _getSiteValue<T>(Map<String, dynamic> map, String camelCaseKey, String snakeCaseKey, T defaultValue) {
        final value = map[camelCaseKey] ?? map[snakeCaseKey];
        return value != null ? value as T : defaultValue;
      }
      
      int siteIdVal = _getSiteValue(preloadedSite, 'siteId', 'site_id', 0);
      int entityIdVal = _getSiteValue(preloadedSite, 'entityId', 'entity_id', 0);
      // For ticket open from My Tickets: API may not return entity_id; use cmSiteReqId so checklist lookup by entityId finds downloaded data
      if (entityIdVal == 0 && cmSiteReqId != null) {
        final parsed = cmSiteReqId is int ? cmSiteReqId : int.tryParse(cmSiteReqId.toString());
        if (parsed != null && parsed != 0) entityIdVal = parsed;
      }
      if (siteIdVal == 0 && entityIdVal != 0) siteIdVal = entityIdVal;
      
      CMSite site = CMSite(
        siteId: siteIdVal,
        entityId: entityIdVal,
        siteCode: _getSiteValue(preloadedSite, 'siteCode', 'site_code', '').toString(),
        siteName: _getSiteValue(preloadedSite, 'siteName', 'site_name', '').toString(),
        clusterDistrictId: _getSiteValue(preloadedSite, 'clusterDistrictId', 'cluster_district_id', 0),
        clusterDistrictName: _getSiteValue(preloadedSite, 'clusterDistrictName', 'cluster_district_name', '').toString().isEmpty
            ? (preloadedSite['cluster']?.toString() ?? '')
            : _getSiteValue(preloadedSite, 'clusterDistrictName', 'cluster_district_name', '').toString(),
        circleStateId: _getSiteValue(preloadedSite, 'circleStateId', 'circle_state_id', 0),
        circleStateName: _getSiteValue(preloadedSite, 'circleStateName', 'circle_state_name', '').toString().isEmpty
            ? (preloadedSite['circle']?.toString() ?? '')
            : _getSiteValue(preloadedSite, 'circleStateName', 'circle_state_name', '').toString(),
        clientId: preloadedSite['clientId'] ?? preloadedSite['client_id'],
        clientName: (preloadedSite['clientName'] ?? preloadedSite['client_name'])?.toString(),
        oem: preloadedSite['oem']?.toString(),
        oemId: preloadedSite['oemId'] ?? preloadedSite['oem_id'],
        self: _getSiteValue(preloadedSite, 'assignedToName', 'assigned_to_name', '').toString().isEmpty
            ? (preloadedSite['self']?.toString() ?? '')
            : _getSiteValue(preloadedSite, 'assignedToName', 'assigned_to_name', '').toString(),
        selfId: (preloadedSite['assignedTo'] ?? preloadedSite['assigned_to'] ?? preloadedSite['selfId'] ?? preloadedSite['self_id']) as int? ?? 0,
        infraEngineerName: (preloadedSite['infraEngineerName'] ?? preloadedSite['infra_engineer_name'])?.toString(),
        infraEngineerContactNo: (preloadedSite['infraEngineerContactNo'] ?? preloadedSite['infra_engineer_contact_no'])?.toString(),
        clusterInchargeName: (preloadedSite['clusterInchargeName'] ?? preloadedSite['cluster_incharge_name'])?.toString(),
        clusterInchargeContactNo: (preloadedSite['clusterInchargeContactNo'] ?? preloadedSite['cluster_incharge_contact_no'])?.toString(),
        category: preloadedSite['category']?.toString(),
      );
      _siteOptions = [site];
      _initializeTicketControllers(preloadedSite);
      _onSiteSelected(site);
      _loadFreshTicketDetailsIfNeeded();
    }
  }

  void _loadImages(Map<String, dynamic> preloadedSite) async {
    // Load Identification Photo
    dynamic identificationPhotoId = preloadedSite['identificationImgId'] ?? preloadedSite['identification_img_id'];
    _originalIdentificationPhotoId = identificationPhotoId;
    if (identificationPhotoId != null && identificationPhotoId.toString().trim().isNotEmpty) {
      await _loadPhotoFromServer(identificationPhotoId, (file, byteData) {
        identificationPhoto = file;
        identificationPhotoByteData = byteData;
      }, 'Identification');
    }
    
    // Load Time Stamp Photo
    dynamic timestampPhotoId = preloadedSite['timestampImgId'] ?? preloadedSite['timestamp_img_id'];
    _originalTimestampPhotoId = timestampPhotoId;
    if (timestampPhotoId != null && timestampPhotoId.toString().trim().isNotEmpty) {
      await _loadPhotoFromServer(timestampPhotoId, (file, byteData) {
        timestampPhoto = file;
        timestampPhotoByteData = byteData;
      }, 'Time Stamp');
    }

    if (widget.mode != CMScreenModeEnum.create) {
      dynamic fsrAttachmentId =
          preloadedSite['fsrAttachmentId'] ?? preloadedSite['fsr_attachment_id'];
      if (fsrAttachmentId is String && fsrAttachmentId.trim().isNotEmpty) {
        fsrAttachmentId = int.tryParse(fsrAttachmentId.trim()) ?? fsrAttachmentId;
      }

      final fsrAttachmentName =
          preloadedSite['fsrAttachmentName'] ?? preloadedSite['fsr_attachment_name'];
      if (fsrAttachmentId != null && fsrAttachmentId != 0) {
        _fsrAttachmentId = fsrAttachmentId;
        _fsrAttachmentName = (fsrAttachmentName != null &&
                fsrAttachmentName.toString().trim().isNotEmpty)
            ? fsrAttachmentName.toString().trim()
            : fsrAttachmentId.toString();
      }
    }
  }

  /// Helper method to load photo from server/cache
  Future<void> _loadPhotoFromServer(
    dynamic photoId,
    Function(File?, String) onLoaded,
    String photoName,
  ) async {
    if (photoId == null || photoId.toString().trim().isEmpty) {
      return;
    }
    
    String? photoByteDataLocal;
    
    try {
      // First, check if image is already cached locally (works in offline mode)
      final cachedImage = await ServiceLocator()
          .imageUploadService
          .getImagesByServerId(photoId.toString());
      
      if (cachedImage != null && cachedImage.imageData != null) {
        // Image found in local cache - use it (works offline)
        Logger.infoLog('[CM] $photoName photo found in local cache (offline mode supported)');
        photoByteDataLocal = cachedImage.imageData;
      } else {
        // Not in cache, check if we're online and try to download
        final isOnline = await ConnectivityHelper.isConnected();
        
        if (isOnline) {
          // Online: try to download from /common/DocumentById/{id} and cache it
          Logger.infoLog('[CM] $photoName photo not in cache, downloading from DocumentById (online mode)');

          final uniqueId = await ServiceLocator()
              .imageUploadService
              .downloadPmisDocumentByServerId(
                photoId.toString(),
                ActivityTypeEnum.correctiveMaintenance,
                _selectedSite?.siteId.toString() ?? '',
              );
          
          if (uniqueId != null) {
            // Get the cached image data
            photoByteDataLocal = await ServiceLocator()
                .imageUploadService
                .getImageUsingUniqueId(uniqueId);
          }
        } else {
          // Offline and not in cache - cannot load image
          Logger.errorLog('[CM] $photoName photo not in cache and device is offline - cannot load');
        }
      }
      
      // If we got image data (from cache or download), process it
      if (photoByteDataLocal != null && photoByteDataLocal.isNotEmpty) {
        File? imageFile = await Utils.buildImageFromBytesData(
          photoByteDataLocal,
        );
        if (mounted) {
          setState(() {
            onLoaded(imageFile, photoByteDataLocal!);
          });
        }
      } else {
        Logger.errorLog('[CM] Failed to load $photoName photo: No data retrieved');
      }
    } catch (e) {
      Logger.errorLog('[CM] Error loading $photoName photo: $e');
    }
  }

  Future<void> _openServerAttachment(dynamic attachmentId) async {
    try {
      final id = int.tryParse(attachmentId.toString().trim());
      if (id == null || id <= 0) {
        if (!mounted) return;
        Toastbar.showErrorToastbar('Invalid attachment id', context);
        return;
      }

      if (mounted) LoaderWidget.showLoader(context);
      final fileName = (_fsrAttachmentName != null &&
              _fsrAttachmentName!.trim().isNotEmpty)
          ? _fsrAttachmentName!.trim()
          : 'fsr_$id';
      final filePath = await ServiceLocator().cmRepository.downloadDocument(
        id,
        fileName,
      );
      final openResult = await OpenFile.open(filePath);
      if (openResult.type != ResultType.done) {
        Logger.errorLog(
          '[CM] OpenFile failed for FSR: ${openResult.type} - ${openResult.message}',
        );
        if (!mounted) return;
        Toastbar.showErrorToastbar(
          openResult.message.isNotEmpty
              ? openResult.message
              : 'Unable to open attachment',
          context,
        );
      }
    } catch (e) {
      Logger.errorLog('[CM] Error opening FSR attachment: $e');
      if (!mounted) return;
      Toastbar.showErrorToastbar('Unable to open attachment: $e', context);
    } finally {
      LoaderWidget.hideLoader();
    }
  }

  /// Helper method to get value from preloadedSite handling both camelCase and snake_case
  String? _getValue(Map<String, dynamic> preloadedSite, String camelCaseKey, String snakeCaseKey) {
    final value = preloadedSite[camelCaseKey] ?? preloadedSite[snakeCaseKey];
    if (value == null) return null;
    final strValue = value.toString().trim();
    if (strValue.isEmpty) return null;
    // Treat "n/a" as null so UI shows blank instead of "n/a"
    if (strValue.toUpperCase() == 'N/A') return null;
    return strValue;
  }

  void _applyOemTicketIdFromMap(Map<String, dynamic> map) {
    final oemTicketId = _getValue(map, 'oemTicketId', 'oem_ticket_id');
    if (oemTicketId != null) {
      controllers['oem_ticket_id']!.text = oemTicketId;
      _oemTicketIdDisplay = oemTicketId;
      Logger.infoLog('[CM] OEM Ticket ID initialized: $oemTicketId');
    }
  }

  Future<void> _loadFreshTicketDetailsIfNeeded() async {
    if (widget.mode == CMScreenModeEnum.create) return;
    final parsedId = cmSiteReqId is int
        ? cmSiteReqId
        : int.tryParse(cmSiteReqId?.toString() ?? '');
    if (parsedId == null || parsedId <= 0) return;
    if (!await ConnectivityHelper.isConnected()) return;

    try {
      final ticketData =
          await ServiceLocator().cmRepository.getCmTicketData(parsedId);
      if (!mounted) return;

      _mergedPreloadedSite = {
        ...?_mergedPreloadedSite,
        ...ticketData,
      };
      _applyOemTicketIdFromMap(ticketData);
      setState(() {});
    } catch (e) {
      Logger.errorLog('[CM] Failed to refresh ticket details from API: $e');
    }
  }

  /// Match API value to a static option ignoring case; returns the option string so UI shows exact option (e.g. "Self" not "SELF").
  String? _matchOptionIgnoreCase(String? apiValue, List<String> options) {
    if (apiValue == null || apiValue.trim().isEmpty) return null;
    final upper = apiValue.trim().toUpperCase();
    for (final option in options) {
      if (option.trim().toUpperCase() == upper) return option;
    }
    return null;
  }

  void _initializeTicketControllers(Map<String, dynamic> preloadedSite) {
    Logger.infoLog('[CM] Initializing ticket controllers from preloadedSite');
    Logger.infoLog('[CM] Available keys: ${preloadedSite.keys.toList()}');
    
    // Initialize CM Ticket No if cmSiteReqId is available (try both camelCase and snake_case)
    final ticketId = preloadedSite['cmSiteReqId'] ?? preloadedSite['cm_site_req_id'];
    if (ticketId != null && ticketId.toString().trim().isNotEmpty) {
      _cmTicketNoController.text = ticketId.toString();
      Logger.infoLog("✅ [CM] CM Ticket No initialized: ${_cmTicketNoController.text}");
    } else {
      Logger.errorLog("❌ [CM] CM Ticket No not found in preloadedSite. Available keys: ${preloadedSite.keys}");
    }

    final currentStatus = preloadedSite['status'] ?? preloadedSite['Status'];
    if (currentStatus != null && currentStatus.toString().trim().isNotEmpty) {
      _currentStatusController.text = currentStatus.toString().trim();
      if (_isClosedStatus(currentStatus)) {
        _forceViewMode = true;
      }
    }

    final startDate = preloadedSite['startDt'] ?? preloadedSite['start_dt'];
    if (startDate != null && startDate.toString().trim().isNotEmpty) {
      _startDateController.text = _formatDateStringForApi(startDate.toString());
    }
    
    // Map all fields with support for both camelCase and snake_case
    // Match dropdown fields to static options ignore-case so we show exact option text (e.g. "Self" not "SELF")
    // Responsible Party (Category)
    final responsiblePartyRaw = _getValue(preloadedSite, 'responsibleParty', 'responsible_party');
    final responsibleParty = _matchOptionIgnoreCase(responsiblePartyRaw, _responsiblePartyOptions) ?? responsiblePartyRaw;
    if (responsibleParty != null && responsibleParty.isNotEmpty) {
      controllers['responsible_party']!.text = responsibleParty;
      Logger.infoLog('[CM] Responsible Party initialized: $responsibleParty');
    }
    
    // Assigned To
    final assignedToName = _getValue(preloadedSite, 'assignedToName', 'assigned_to_name');
    if (assignedToName != null) {
      controllers['assigned_to']!.text = assignedToName;
      Logger.infoLog('[CM] Assigned To initialized: $assignedToName');
    }
    
    // Priority
    final priorityRaw = _getValue(preloadedSite, 'priority', 'priority');
    final priority = _matchOptionIgnoreCase(priorityRaw, _priorityOptions) ?? priorityRaw;
    if (priority != null && priority.isNotEmpty) {
      controllers['priority']!.text = priority;
      Logger.infoLog('[CM] Priority initialized: $priority');
    }
    
    _applyOemTicketIdFromMap(preloadedSite);
    
    // Fault Description
    final faultDescription = _getValue(preloadedSite, 'faultDescription', 'fault_description');
    if (faultDescription != null) {
      controllers['fault_description']!.text = faultDescription;
      Logger.infoLog('[CM] Fault Description initialized: $faultDescription');
    }
    
    // Nature of Failure
    final natureOfFailure = _getValue(preloadedSite, 'natureOfFailure', 'nature_of_failure');
    if (natureOfFailure != null) {
      controllers['nature_of_failure']!.text = natureOfFailure;
      Logger.infoLog('[CM] Nature of Failure initialized: $natureOfFailure');
    }
    
    // Scope of Ticket
    final scopeOfTicketRaw = _getValue(preloadedSite, 'scopeOfTicket', 'scope_of_ticket');
    final scopeOfTicket = _matchOptionIgnoreCase(scopeOfTicketRaw, _scopeOfTicketOptions) ?? scopeOfTicketRaw;
    if (scopeOfTicket != null && scopeOfTicket.isNotEmpty) {
      controllers['scope_of_ticket']!.text = scopeOfTicket;
      Logger.infoLog('[CM] Scope of Ticket initialized: $scopeOfTicket');
    }
    
    // Action Taken
    final actionTaken = _getValue(preloadedSite, 'actionTaken', 'action_taken');
    if (actionTaken != null) {
      controllers['action_taken']!.text = actionTaken;
      Logger.infoLog('[CM] Action Taken initialized: $actionTaken');
    }
    
    // RCA
    final rca = _getValue(preloadedSite, 'rca', 'rca');
    if (rca != null) {
      controllers['rca']!.text = rca;
      Logger.infoLog('[CM] RCA initialized: $rca');
    }
    
    // Closure Date — use calendar date from API string only (part before `T`), no timezone
    final rawEndDt = preloadedSite['endDt'] ??
        preloadedSite['end_dt'] ??
        preloadedSite['closureDate'] ??
        preloadedSite['closure_date'];
    if (rawEndDt != null) {
      final display = _apiDateStringToDdMmYyyy(rawEndDt.toString());
      if (display.isNotEmpty) {
        controllers['closure_date']!.text = display;
        Logger.infoLog('[CM] Closure Date initialized from endDt: $rawEndDt -> $display');
      }
    }
    
    // OEM Representative
    final oemRepresentative = _getValue(preloadedSite, 'oemRepresentative', 'oem_representative');
    if (oemRepresentative != null) {
      controllers['oem_representative']!.text = oemRepresentative;
      Logger.infoLog('[CM] OEM Representative initialized: $oemRepresentative');
    }
    
    // OEM Representative Contact
    final oemRepresentativeContact = _getValue(preloadedSite, 'oemRepresentativeContactNo', 'oem_representative_contact_no') ??
                                     _getValue(preloadedSite, 'oemRepresentativeContact', 'oem_representative_contact');
    if (oemRepresentativeContact != null) {
      controllers['oem_representative_contact']!.text = oemRepresentativeContact;
      Logger.infoLog('[CM] OEM Representative Contact initialized: $oemRepresentativeContact');
    }
    
    // Customer Name
    final customerName = _getValue(preloadedSite, 'customerName', 'customer_name');
    if (customerName != null) {
      controllers['customer_name']!.text = customerName;
      Logger.infoLog('[CM] Customer Name initialized: $customerName');
    }
    
    // Contact No
    final contactNo = _getValue(preloadedSite, 'contactNo', 'contact_no');
    if (contactNo != null) {
      controllers['contact_no']!.text = contactNo;
      Logger.infoLog('[CM] Contact No initialized: $contactNo');
    }
    
    // Problem Summary
    final problemSummary = _getValue(preloadedSite, 'problemSummary', 'problem_summary');
    if (problemSummary != null) {
      controllers['problem_summary']!.text = problemSummary;
      Logger.infoLog('[CM] Problem Summary initialized: $problemSummary');
    }
    
    // Set equipment type (handle both camelCase and snake_case)
    setState(() {
      final isDg = preloadedSite['isDg'] ?? preloadedSite['is_dg'];
      final isBattery = preloadedSite['isBattery'] ?? preloadedSite['is_battery'];
      final isCcu = preloadedSite['isCcu'] ?? preloadedSite['is_ccu'];
      final isSmps = preloadedSite['isSmps'] ?? preloadedSite['is_smps'];
      final isSolar = preloadedSite['isSolar'] ?? preloadedSite['is_solar'];
      
      if (isDg == true) {
        _selectedEquipmentType = 'DG';
        Logger.infoLog('[CM] Equipment Type initialized: DG');
      } else if (isBattery == true) {
        _selectedEquipmentType = 'BATTERY';
        Logger.infoLog('[CM] Equipment Type initialized: BATTERY');
      } else if (isCcu == true) {
        _selectedEquipmentType = 'CCU';
        Logger.infoLog('[CM] Equipment Type initialized: CCU');
      } else if (isSmps == true) {
        _selectedEquipmentType = 'SMPS';
        Logger.infoLog('[CM] Equipment Type initialized: SMPS');
      } else if (isSolar == true) {
        _selectedEquipmentType = 'SOLAR';
        Logger.infoLog('[CM] Equipment Type initialized: SOLAR');
      }
    });
    
    // Load images and attachments asynchronously
    // This will update state after the widget has built
    _loadImages(preloadedSite);
    
    for (var value in controllers.values) {
      value.addListener(_onFormChanged);
    }
    
    Logger.infoLog('[CM] Ticket controllers initialization completed');
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

    setState(() {
      _selectedSite = selectedSite;
      _hasFormDataChanges = true;

      // Populate site fields
      _siteNameController.text = selectedSite.siteName;
      _siteCodeController.text = selectedSite.siteCode;
      _circleStateController.text = selectedSite.circleStateName;
      _clusterDistrictController.text = selectedSite.clusterDistrictName;
      _customerController.text = selectedSite.clientName ?? '';
      _infraEngineerNameController.text = selectedSite.infraEngineerName ?? '';
      _infraEngineerContactNoController.text = selectedSite.infraEngineerContactNo ?? '';
      _clusterInchargeNameController.text = selectedSite.clusterInchargeName ?? '';
      _clusterInchargeContactNoController.text = selectedSite.clusterInchargeContactNo ?? '';
      _categoryController.text = selectedSite.category ?? '';
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

        Map<String, dynamic> checklistData = {};
        
        try {
          // Try to get site data with checklist from local database first
          Logger.infoLog("🔄 [CM] Checking local database for site data with checklist...");
          Logger.infoLog("🆔 [CM] Looking for site ID: ${selectedSite.siteId}, entityId: ${selectedSite.entityId}");

          final siteDataWithChecklist = await ServiceLocator()
              .centralAssetAuditDataService
              .getCMSiteDataWithChecklist(selectedSite.siteId);
          
          Logger.infoLog("🔍 [CM] Site data lookup result: ${siteDataWithChecklist != null ? 'FOUND' : 'NOT_FOUND'}");
          
          if (siteDataWithChecklist != null && siteDataWithChecklist['checklist_items'] != null) {
            Logger.infoLog("✅ [CM] Found site data with checklist_items in local database");
            checklistData = Map<String, dynamic>.from(siteDataWithChecklist['checklist_items']);
            Logger.infoLog("✅ [CM] Checklist data loaded with types: ${checklistData.keys.toList()}");
          } else {
            // Fallback: Try separate checklist table
            Logger.infoLog("⚠️ [CM] No checklist in site data, checking separate checklist table...");

            Logger.infoLog("🆔 [CM] Looking for checklist data for site ID: ${selectedSite.siteId}");
            Map<String, List<Map<String, dynamic>>> localChecklistData =
                await ServiceLocator()
                    .centralAssetAuditDataService
                    .getCMChecklistData(selectedSite.siteId);

            Logger.infoLog("🔍 [CM] Separate checklist lookup result: ${localChecklistData.length} equipment types");

            // If no rows by site_id, try entity_id stored in cm_checklist_data (offline open from My Tickets)
            if (localChecklistData.isEmpty) {
              final entityIdFromDb = await ServiceLocator()
                  .centralAssetAuditDataService
                  .getEntityIdFromCMChecklistForSite(selectedSite.siteId);
              if (entityIdFromDb != null && entityIdFromDb != 0) {
                Logger.infoLog("🔄 [CM] No checklist by site_id, trying entity_id from DB: $entityIdFromDb");
                localChecklistData = await ServiceLocator()
                    .centralAssetAuditDataService
                    .getCMChecklistDataByEntityId(entityIdFromDb);
                if (localChecklistData.isNotEmpty) {
                  Logger.infoLog("✅ [CM] Checklist loaded by entity_id from cm_checklist_data");
                }
              }
            }

            if (localChecklistData.isNotEmpty) {
              Logger.infoLog("✅ [CM] Checklist data loaded from separate table with types: ${localChecklistData.keys.toList()}");
              checklistData = localChecklistData;
            } else {
              // Fallback for offline ticket open: lookup by entityId or cmSiteReqId (ticket/site may use these as key)
              final effectiveEntityId = selectedSite.entityId != 0
                  ? selectedSite.entityId
                  : (cmSiteReqId is int
                      ? cmSiteReqId
                      : int.tryParse(cmSiteReqId?.toString() ?? ''));
              if (effectiveEntityId != null && effectiveEntityId != 0) {
                Logger.infoLog("🔄 [CM] No checklist by siteId, trying by entityId: $effectiveEntityId");
                final siteDataByEntityId = await ServiceLocator()
                    .centralAssetAuditDataService
                    .getCMSiteDataWithChecklistByEntityId(effectiveEntityId);
                if (siteDataByEntityId != null &&
                    siteDataByEntityId['checklist_items'] != null) {
                  checklistData = Map<String, dynamic>.from(
                      siteDataByEntityId['checklist_items'] as Map);
                  Logger.infoLog(
                      "✅ [CM] Checklist loaded from site data by entityId with types: ${checklistData.keys.toList()}");
                } else {
                  final checklistByEntityId = await ServiceLocator()
                      .centralAssetAuditDataService
                      .getCMChecklistDataByEntityId(effectiveEntityId);
                  if (checklistByEntityId.isNotEmpty) {
                    checklistData = checklistByEntityId;
                    Logger.infoLog(
                        "✅ [CM] Checklist loaded from separate table by entityId with types: ${checklistData.keys.toList()}");
                  }
                }
              }
            }
            if (checklistData.isEmpty) {
              Logger.infoLog("⚠️ [CM] No local checklist data found, fetching from API");
              try {
                // Last-chance: resolve entity_id from cm_checklist_data and load (offline My Tickets flow)
                final entityIdFromDb = await ServiceLocator()
                    .centralAssetAuditDataService
                    .getEntityIdFromCMChecklistForSite(selectedSite.siteId);
                if (entityIdFromDb != null && entityIdFromDb != 0) {
                  final byEntity = await ServiceLocator()
                      .centralAssetAuditDataService
                      .getCMChecklistDataByEntityId(entityIdFromDb);
                  if (byEntity.isNotEmpty) {
                    checklistData = byEntity;
                    Logger.infoLog("✅ [CM] Checklist loaded by entity_id from DB (last-chance fallback)");
                  }
                }

                // Check connectivity first
                final isOnline = await ConnectivityHelper.isConnected();

                // Check if site is downloaded (by siteId or by entityId for ticket/open-from-my-tickets flow)
                bool isSiteDownloaded = await ServiceLocator()
                    .centralAssetAuditDataService
                    .isCMSiteDownloaded(selectedSite.siteId);
                if (!isSiteDownloaded &&
                    entityIdFromDb != null &&
                    entityIdFromDb != 0) {
                  isSiteDownloaded = await ServiceLocator()
                      .centralAssetAuditDataService
                      .isCMChecklistDownloadedByEntityId(entityIdFromDb);
                }
                final effectiveEntityIdForCheck = selectedSite.entityId != 0
                    ? selectedSite.entityId
                    : (cmSiteReqId is int
                        ? cmSiteReqId
                        : int.tryParse(cmSiteReqId?.toString() ?? ''));
                if (!isSiteDownloaded &&
                    effectiveEntityIdForCheck != null &&
                    effectiveEntityIdForCheck != 0) {
                  isSiteDownloaded = await ServiceLocator()
                      .centralAssetAuditDataService
                      .isCMChecklistDownloadedByEntityId(effectiveEntityIdForCheck);
                  if (isSiteDownloaded) {
                    final retryByEntityId = await ServiceLocator()
                        .centralAssetAuditDataService
                        .getCMChecklistDataByEntityId(effectiveEntityIdForCheck);
                    if (retryByEntityId.isNotEmpty) {
                      checklistData = retryByEntityId;
                      Logger.infoLog(
                          "✅ [CM] Checklist loaded by entityId on offline check: ${checklistData.keys.toList()}");
                    }
                  }
                }
                
                // If offline and site is not downloaded, throw error
                if (!isOnline && !isSiteDownloaded) {
                  throw Exception("This site is not downloaded. Please download the site data first to use it offline.");
                }
                
                // Only fetch from API or throw when we still don't have checklist (e.g. just loaded by entityId retry above)
                if (checklistData.isEmpty) {
                  if (isOnline) {
                    Logger.infoLog("🌐 [CM] Online mode - fetching checklist from API");
                    final effectiveEntityIdForApi = selectedSite.entityId != 0
                        ? selectedSite.entityId
                        : (cmSiteReqId is int
                            ? cmSiteReqId
                            : int.tryParse(cmSiteReqId?.toString() ?? ''));
                    final apiResponse = await ServiceLocator().cmRepository
                        .getChecklistData(effectiveEntityIdForApi ?? selectedSite.entityId);
                    
                    // API now returns both checkListDetails and siteDeployedItems
                    if (apiResponse.containsKey('checkListDetails')) {
                      checklistData = Map<String, dynamic>.from(apiResponse['checkListDetails']);
                      // Add siteDeployedItems to checklistData
                      if (apiResponse.containsKey('siteDeployedItems')) {
                        checklistData['siteDeployedItems'] = apiResponse['siteDeployedItems'];
                      }
                    } else {
                      // Fallback for old format
                      checklistData = apiResponse;
                    }
                    
                    Logger.infoLog("✅ [CM] Checklist data fetched from API");
                    
                    // Save to local database for offline use
                    try {
                      await ServiceLocator().centralAssetAuditService.downloadCMChecklist(
                        siteId: selectedSite.siteId,
                        entityId: effectiveEntityIdForApi ?? selectedSite.entityId,
                        siteCode: selectedSite.siteCode,
                        siteName: selectedSite.siteName,
                      );
                      Logger.infoLog("✅ [CM] Checklist data saved to local database");
                    } catch (saveError) {
                      Logger.errorLog("⚠️ [CM] Failed to save checklist to local database: $saveError");
                      // Continue even if save fails
                    }
                  } else {
                    // Offline mode but no local data - should not reach here if entityId retry succeeded
                    throw Exception("No internet connection and site data not downloaded. Please download the site data first.");
                  }
                }
              } catch (apiError) {
                Logger.errorLog("❌ [CM] Failed to fetch checklist from API: $apiError");
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
          // Re-throw the error to show message to user
          rethrow;
        }
        
        Logger.infoLog("✅ [CM] Checklist data received: ${checklistData.keys}");
        if (mounted) {
          setState(() {
            _checklistData = checklistData;
          });
        }
      } else if (_resolvedMode == CMScreenModeEnum.edit || _resolvedMode == CMScreenModeEnum.view) {
        // In edit/view mode, load checklist template and merge with existing responses
        Logger.infoLog(
          "🔄 [CM] Edit/View mode - Loading checklist template and merging with existing responses",
        );
        
        try {
          int effectiveEntityId = _selectedSite!.entityId;
          if (effectiveEntityId == 0) {
            if (cmSiteReqId is int) {
              effectiveEntityId = cmSiteReqId!;
            } else {
              effectiveEntityId =
                  int.tryParse(cmSiteReqId?.toString() ?? '') ?? 0;
            }
          }

          Map<String, dynamic> checklistTemplate =
              await _loadLocalChecklistTemplate(
            siteId: _selectedSite!.siteId,
            entityId: effectiveEntityId,
          );

          if (checklistTemplate.isEmpty) {
            final isOnline = await ConnectivityHelper.isConnected();
            if (isOnline && effectiveEntityId != 0) {
              final apiResponse = await ServiceLocator().cmRepository
                  .getChecklistData(effectiveEntityId);
              if (apiResponse.containsKey('checkListDetails')) {
                checklistTemplate =
                    Map<String, dynamic>.from(apiResponse['checkListDetails']);
                if (apiResponse.containsKey('siteDeployedItems')) {
                  checklistTemplate['siteDeployedItems'] =
                      apiResponse['siteDeployedItems'];
                }
              } else {
                checklistTemplate = apiResponse;
              }
            }
          }

          List<dynamic> existingResponses = _resolveExistingChecklistResponses();
          
          // If not found in preloadedSiteData and we have cmSiteReqId, fetch from API
          if (existingResponses.isEmpty && cmSiteReqId != null && cmSiteReqId! > 0) {
            Logger.infoLog('[CM] Checklist responses not found in preloadedSiteData, fetching from API for cmSiteReqId: $cmSiteReqId');
            
            final isOnline = await ConnectivityHelper.isConnected();
            if (isOnline) {
              try {
                final ticketData = await ServiceLocator().cmRepository.getCmTicketData(cmSiteReqId!);
                
                // Extract cmCheckListSiteRespList from API response
                existingResponses = ticketData['cmCheckListSiteRespList'] ?? 
                                   ticketData['cm_check_list_site_resp_list'] ?? [];
                
                Logger.infoLog('[CM] Fetched ${existingResponses.length} checklist responses from API');

                if (mounted) {
                  _mergedPreloadedSite = {
                    ...?_mergedPreloadedSite,
                    ...ticketData,
                  };
                  _applyOemTicketIdFromMap(ticketData);
                  setState(() {});
                }
                
                // Also update preloadedSiteData with the fetched data for consistency
                if (mounted && existingResponses.isNotEmpty) {
                  // Update the preloadedSiteData structure if needed
                  if (widget.preloadedSiteData != null) {
                    Map<String, dynamic> updatedPreloadedData = Map<String, dynamic>.from(widget.preloadedSiteData!);
                    if (updatedPreloadedData.containsKey('data') && updatedPreloadedData['data'] is Map<String, dynamic>) {
                      (updatedPreloadedData['data'] as Map<String, dynamic>)['cmCheckListSiteRespList'] = existingResponses;
                    } else {
                      updatedPreloadedData['cmCheckListSiteRespList'] = existingResponses;
                    }
                  }
                }
              } catch (apiError) {
                Logger.errorLog('[CM] Error fetching checklist responses from API: $apiError');
                // Continue with empty responses if API call fails
              }
            } else {
              Logger.infoLog('[CM] Offline mode - cannot fetch checklist responses from API');
            }
          }
          
          Logger.infoLog('[CM] Found ${existingResponses.length} existing checklist responses');
          
          // Merge existing responses with checklist template (async - loads images)
          final mergedChecklistData = await _mergeChecklistWithResponses(
            checklistTemplate,
            existingResponses,
        );
          
          if (mounted) {
            setState(() {
              _checklistData = mergedChecklistData;
            });
          }
          
          Logger.infoLog('[CM] Merged checklist data prepared for edit/view mode');
        } catch (e) {
          Logger.errorLog('[CM] Error loading checklist template in edit/view mode: $e');
          // Continue with empty checklist if loading fails
        }
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

  List<dynamic> _resolveExistingChecklistResponses() {
    Map<String, dynamic>? source = _mergedPreloadedSite;
    if (source == null && widget.preloadedSiteData != null) {
      source = Map<String, dynamic>.from(widget.preloadedSiteData!);
      if (source.containsKey('data') && source['data'] is Map<String, dynamic>) {
        source = Map<String, dynamic>.from(source['data'] as Map<String, dynamic>);
      }
    }
    final list = source?['cmCheckListSiteRespList'] ??
        source?['cm_check_list_site_resp_list'];
    return list is List ? list : const [];
  }

  /// When only ticket responses exist (offline downloaded ticket), build a minimal
  /// template so [_mergeChecklistWithResponses] can render checklist rows.
  Map<String, dynamic> _buildPseudoTemplateFromResponses(
    List<dynamic> existingResponses,
  ) {
    final template = <String, dynamic>{};
    for (final response in existingResponses) {
      if (response is! Map<String, dynamic>) continue;
      final itemType =
          (response['cmItemType'] ?? response['cm_item_type'] ?? 'DG')
              .toString()
              .trim();
      if (itemType.isEmpty) continue;
      template.putIfAbsent(itemType, () => <Map<String, dynamic>>[]);
      (template[itemType] as List<Map<String, dynamic>>).add({
        'cm_check_list_mst_id':
            response['cmCheckListMstId'] ?? response['cm_check_list_mst_id'],
        'cmCheckListMstId':
            response['cmCheckListMstId'] ?? response['cm_check_list_mst_id'],
        'checklist_desc':
            response['checklistDesc'] ?? response['checklist_desc'] ?? '',
        'checklistDesc':
            response['checklistDesc'] ?? response['checklist_desc'] ?? '',
        'resp_type': response['respType'] ?? response['resp_type'] ?? '',
        'respType': response['respType'] ?? response['resp_type'] ?? '',
        'cl_order': response['clOrder'] ?? response['cl_order'] ?? 0,
        'clOrder': response['clOrder'] ?? response['cl_order'] ?? 0,
      });
    }
    return template;
  }

  Future<Map<String, dynamic>> _loadLocalChecklistTemplate({
    required int siteId,
    required int entityId,
  }) async {
    Map<String, dynamic> checklistTemplate = {};

    final siteDataWithChecklist = await ServiceLocator()
        .centralAssetAuditDataService
        .getCMSiteDataWithChecklist(siteId);
    if (siteDataWithChecklist != null &&
        siteDataWithChecklist['checklist_items'] != null) {
      return Map<String, dynamic>.from(
        siteDataWithChecklist['checklist_items'] as Map,
      );
    }

    final localChecklistData = await ServiceLocator()
        .centralAssetAuditDataService
        .getCMChecklistData(siteId);
    if (localChecklistData.isNotEmpty) {
      return localChecklistData;
    }

    final entityIdFromDb = await ServiceLocator()
        .centralAssetAuditDataService
        .getEntityIdFromCMChecklistForSite(siteId);
    final effectiveEntityId = entityId != 0
        ? entityId
        : (entityIdFromDb ?? 0);
    if (effectiveEntityId != 0) {
      final siteDataByEntityId = await ServiceLocator()
          .centralAssetAuditDataService
          .getCMSiteDataWithChecklistByEntityId(effectiveEntityId);
      if (siteDataByEntityId != null &&
          siteDataByEntityId['checklist_items'] != null) {
        return Map<String, dynamic>.from(
          siteDataByEntityId['checklist_items'] as Map,
        );
      }
      final checklistByEntityId = await ServiceLocator()
          .centralAssetAuditDataService
          .getCMChecklistDataByEntityId(effectiveEntityId);
      if (checklistByEntityId.isNotEmpty) {
        return checklistByEntityId;
      }
    }

    return checklistTemplate;
  }

  /// Merge existing checklist responses with template checklist data
  Future<Map<String, dynamic>> _mergeChecklistWithResponses(
    Map<String, dynamic> checklistTemplate,
    List<dynamic> existingResponses,
  ) async {
    if (checklistTemplate.isEmpty && existingResponses.isNotEmpty) {
      Logger.infoLog(
        '[CM] No checklist template in local DB; building pseudo-template from '
        '${existingResponses.length} saved ticket response(s) for offline display',
      );
      checklistTemplate = _buildPseudoTemplateFromResponses(existingResponses);
    }

    final mergedData = <String, dynamic>{};
    // When ticket GET returns rows, show only those (cmCheckListSiteRespList), not the full master checklist.
    final restrictToTicketResponses = existingResponses.isNotEmpty;
    if (restrictToTicketResponses) {
      Logger.infoLog(
        '[CM] Checklist UI limited to cmCheckListSiteRespList (${existingResponses.length} row(s)); template used only to enrich matching mstIds',
      );
    }
    
    // Copy siteDeployedItems if present
    if (checklistTemplate.containsKey('siteDeployedItems')) {
      mergedData['siteDeployedItems'] = checklistTemplate['siteDeployedItems'];
    }
    
    // Group existing responses by equipment type (normalize to uppercase for matching)
    final responsesByType = <String, List<Map<String, dynamic>>>{};
    Logger.infoLog('[CM] Processing ${existingResponses.length} existing responses for merging');
    for (var response in existingResponses) {
      if (response is Map<String, dynamic>) {
        final itemType = response['cmItemType']?.toString() ?? 
                        response['cm_item_type']?.toString() ?? '';
        final normalizedItemType = itemType.toUpperCase(); // Normalize to uppercase
        final mstId = response['cmCheckListMstId'] ?? response['cm_check_list_mst_id'];
        final resp = response['resp'];
        Logger.infoLog('[CM] Response itemType: $itemType (normalized: $normalizedItemType), mstId: $mstId, resp: $resp');
        if (normalizedItemType.isNotEmpty) {
          if (!responsesByType.containsKey(normalizedItemType)) {
            responsesByType[normalizedItemType] = [];
          }
          responsesByType[normalizedItemType]!.add(response);
        } else {
          Logger.infoLog('[CM] Response has empty itemType, mstId: $mstId');
        }
      }
    }
    Logger.infoLog('[CM] Grouped responses by type: ${responsesByType.keys.toList()}');
    
    // Merge each equipment type
    for (var entry in checklistTemplate.entries) {
      final equipmentType = entry.key;
      final normalizedEquipmentType = equipmentType.toUpperCase(); // Normalize to uppercase for matching
      final templateItems = entry.value;
      
      if (equipmentType == 'siteDeployedItems') {
        continue; // Skip, already handled
      }
      
      Logger.infoLog('[CM] Processing equipment type: $equipmentType (normalized: $normalizedEquipmentType)');
      
      if (templateItems is List) {
        final mergedItems = <Map<String, dynamic>>[];
        // Match using normalized (uppercase) equipment type
        // For CCU, SMPS, Solar: responses may have subtypes like "CCU Rectifiers", "CCU MPPT"
        // So we need to match if the response itemType starts with the equipment type
        final existingItemsForType = <Map<String, dynamic>>[];
        for (var typeKey in responsesByType.keys) {
          // Exact match OR starts with (for subtypes like "CCU Rectifiers", "CCU MPPT")
          if (typeKey == normalizedEquipmentType || 
              typeKey.startsWith(normalizedEquipmentType + ' ')) {
            existingItemsForType.addAll(responsesByType[typeKey]!);
            Logger.infoLog('[CM] Matched response type "$typeKey" to equipment type "$equipmentType"');
          }
        }
        Logger.infoLog('[CM] Found ${existingItemsForType.length} existing responses for $equipmentType (matched from: ${responsesByType.keys.where((k) => k == normalizedEquipmentType || k.startsWith(normalizedEquipmentType + ' ')).toList()})');
        
        // Create a map of existing responses by cmCheckListMstId for quick lookup
        final existingResponsesMap = <int, Map<String, dynamic>>{};
        for (var existingItem in existingItemsForType) {
          final mstId = existingItem['cmCheckListMstId'] as int? ??
              existingItem['cm_check_list_mst_id'] as int?;
          if (mstId != null) {
            existingResponsesMap[mstId] = existingItem;
          }
        }
        
        // Merge template items with existing responses
        for (var templateItem in templateItems) {
          if (templateItem is Map<String, dynamic>) {
            final mergedItem = Map<String, dynamic>.from(templateItem);
            final mstId = mergedItem['cm_check_list_mst_id'] as int? ??
                mergedItem['cmCheckListMstId'] as int?;

            if (restrictToTicketResponses &&
                (mstId == null || !existingResponsesMap.containsKey(mstId))) {
              continue;
            }
            
            // Find matching existing response
            if (mstId != null && existingResponsesMap.containsKey(mstId)) {
              final existingResponse = existingResponsesMap[mstId]!;
              
              Logger.infoLog('[CM] Merging response for mstId: $mstId, resp: ${existingResponse['resp']}');
              
              // Merge response data - preserve resp even if null
              mergedItem['resp'] = existingResponse['resp'];
              mergedItem['cm_check_list_site_resp_id'] = existingResponse['cmCheckListSiteRespId'] ?? 
                                                         existingResponse['cm_check_list_site_resp_id'];
              
              // Also merge respType if present in response (in case it differs)
              if (existingResponse.containsKey('respType')) {
                mergedItem['respType'] = existingResponse['respType'];
              }
              if (existingResponse.containsKey('resp_type')) {
                mergedItem['resp_type'] = existingResponse['resp_type'];
              }
              
              // Merge cmImpactedItemList when API returns it (dynamic dropdown, CHECKBOX_NUMERIC with impacted rows, etc.)
              final existingImpactedItems = existingResponse['cmImpactedItemList'] ?? 
                                           existingResponse['CmImpactedItemList'] ?? 
                                           existingResponse['cm_impacted_item_list'] ?? [];
              if (existingImpactedItems is List && existingImpactedItems.isNotEmpty) {
                mergedItem['cmImpactedItemList'] = existingImpactedItems;
                mergedItem['cm_impacted_item_list'] = existingImpactedItems; // Also set snake_case for compatibility
                Logger.infoLog('[CM] Merged ${existingImpactedItems.length} impacted items for mstId: $mstId');
              }
              
              // Merge images and load image data from server
              final existingImages = existingResponse['CmCheckListSiteRespImagesList'] ?? 
                                    existingResponse['cmCheckListSiteRespImagesList'] ?? 
                                    existingResponse['cm_check_list_site_resp_images_list'] ?? [];
              
              if (existingImages is List && existingImages.isNotEmpty) {
                // Convert to response_images format and load image data
                final responseImages = <Map<String, dynamic>>[];
                for (var img in existingImages) {
                  if (img is Map<String, dynamic>) {
                    final photoId = img['photoId'] ?? img['photo_id'];
                    if (photoId != null) {
                      String? imageData;
                      try {
                        imageData = await ServiceLocator()
                            .imageUploadService
                            .resolveImageBase64ForPhotoRef(photoId.toString());
                        if (imageData == null || imageData.isEmpty) {
                          final isOnline = await ConnectivityHelper.isConnected();
                          if (isOnline) {
                            final uniqueId = await ServiceLocator()
                                .imageUploadService
                                .downloadImageUsingServerId(
                                  photoId.toString(),
                                  ActivityTypeEnum.correctiveMaintenance,
                                  _selectedSite?.siteId.toString() ?? '',
                                );
                            if (uniqueId != null) {
                              imageData = await ServiceLocator()
                                  .imageUploadService
                                  .getImageUsingUniqueId(uniqueId);
                            }
                          }
                        }
                      } catch (e) {
                        Logger.errorLog('[CM] Error loading image $photoId: $e');
                      }
                      
                      responseImages.add({
                        'photo_id': photoId,
                        'pclsri_id': mergedItem['cm_check_list_mst_id'] ?? mergedItem['cmCheckListMstId'],
                        'photo_taken_ts': img['photoTakenTs'] ?? img['photo_taken_ts'],
                        'image_data': imageData, // Add base64 image data for display
                        'image_path': imageData != null && imageData.startsWith('/')
                            ? imageData
                            : null,
                      });
                    }
                  }
                }
                // Set both field names for compatibility
                mergedItem['response_images'] = responseImages;
                mergedItem['cmCheckListSiteRespImagesList'] = existingImages; // Keep original format for edit/view mode
                mergedItem['cm_check_list_site_resp_images_list'] = existingImages; // Also set snake_case
              }
              
              // Store original cmImpactedItemList for display in edit/view mode (already merged above)
              final originalImpactedItems = existingImpactedItems;
              
              // Merge impacted items (for dynamic dropdowns) and load their images
              final impactedItems = originalImpactedItems;
              
              if (impactedItems is List && impactedItems.isNotEmpty) {
                final processedImpactedItems = <Map<String, dynamic>>[];
                for (var impactedItem in impactedItems) {
                  if (impactedItem is Map<String, dynamic>) {
                    final processedItem = Map<String, dynamic>.from(impactedItem);
                    
                    // Process child item responses and load their images
                    final childItemResponses = impactedItem['childItemResponses'] as List<dynamic>? ?? 
                                               impactedItem['child_item_responses'] as List<dynamic>? ?? [];
                    
                    if (childItemResponses.isNotEmpty) {
                      final processedChildResponses = <Map<String, dynamic>>[];
                      for (var childResponse in childItemResponses) {
                        if (childResponse is Map<String, dynamic>) {
                          final processedChild = Map<String, dynamic>.from(childResponse);
                          
                          // Load images for child response
                          final childImages = childResponse['cmCheckListSiteRespImagesList'] ?? 
                                            childResponse['cm_check_list_site_resp_images_list'] ?? [];
                          
                          if (childImages is List && childImages.isNotEmpty) {
                            final processedChildImages = <Map<String, dynamic>>[];
                            for (var childImg in childImages) {
                              if (childImg is Map<String, dynamic>) {
                                final photoId = childImg['photoId'] ?? childImg['photo_id'];
                                if (photoId != null) {
                                  String? imageData;
                                  try {
                                    imageData = await ServiceLocator()
                                        .imageUploadService
                                        .resolveImageBase64ForPhotoRef(
                                          photoId.toString(),
                                        );
                                    if (imageData == null || imageData.isEmpty) {
                                      final isOnline =
                                          await ConnectivityHelper.isConnected();
                                      if (isOnline) {
                                        final uniqueId = await ServiceLocator()
                                            .imageUploadService
                                            .downloadImageUsingServerId(
                                              photoId.toString(),
                                              ActivityTypeEnum.correctiveMaintenance,
                                              _selectedSite?.siteId.toString() ?? '',
                                            );
                                        if (uniqueId != null) {
                                          imageData = await ServiceLocator()
                                              .imageUploadService
                                              .getImageUsingUniqueId(uniqueId);
                                        }
                                      }
                                    }
                                  } catch (e) {
                                    Logger.errorLog('[CM] Error loading child image $photoId: $e');
                                  }
                                  
                                  processedChildImages.add({
                                    'photo_id': photoId,
                                    'photo_taken_ts': childImg['photoTakenTs'] ?? childImg['photo_taken_ts'],
                                    'image_data': imageData,
                                    'image_path': imageData != null && imageData.startsWith('/')
                                        ? imageData
                                        : null,
                                  });
                                }
                              }
                            }
                            processedChild['response_images'] = processedChildImages;
                          }
                          
                          processedChildResponses.add(processedChild);
                        }
                      }
                      processedItem['child_item_responses'] = processedChildResponses;
                    }
                    
                    processedImpactedItems.add(processedItem);
                  }
                }
                mergedItem['siteDeployedItems'] = processedImpactedItems;
              }
              
              // Merge numeric values if present
              if (existingResponse.containsKey('numeric_value')) {
                mergedItem['numeric_value'] = existingResponse['numeric_value'];
              }
              if (existingResponse.containsKey('resp_numeric')) {
                mergedItem['resp_numeric'] = existingResponse['resp_numeric'];
              }
            } else if (!restrictToTicketResponses) {
              // No matching response found - log for debugging (full master checklist preview)
              Logger.infoLog('[CM] No matching response found for mstId: $mstId, equipmentType: $equipmentType, checklistDesc: ${mergedItem['checklistDesc'] ?? mergedItem['checklist_desc']}');
            }
            
            // Log the final merged item to verify resp is set
            Logger.infoLog('[CM] Final merged item - mstId: $mstId, checklistDesc: ${mergedItem['checklistDesc'] ?? mergedItem['checklist_desc']}, resp: ${mergedItem['resp']}, respType: ${mergedItem['respType'] ?? mergedItem['resp_type']}');
            mergedItems.add(mergedItem);
          }
        }

        // Ticket-only mode: append any cmCheckListSiteRespList rows not matched above (missing mstId on template branch / API-only shapes).
        if (restrictToTicketResponses && existingItemsForType.isNotEmpty) {
          final included = <int>{};
          for (final mi in mergedItems) {
            final id =
                mi['cm_check_list_mst_id'] as int? ?? mi['cmCheckListMstId'] as int?;
            if (id != null) included.add(id);
          }
          for (final resp in existingItemsForType) {
            final mid = resp['cmCheckListMstId'] as int? ??
                resp['cm_check_list_mst_id'] as int?;
            if (mid != null && !included.contains(mid)) {
              mergedItems.add(Map<String, dynamic>.from(resp));
              included.add(mid);
              Logger.infoLog(
                '[CM] Added ticket-only checklist row not in template (mstId: $mid) for equipmentType: $equipmentType',
              );
            }
          }
        }
        
        Logger.infoLog('[CM] Merged ${mergedItems.length} items for equipmentType: $equipmentType');
        mergedData[equipmentType] = mergedItems;
      } else {
        mergedData[equipmentType] = templateItems;
      }
    }
    
    Logger.infoLog('[CM] Merged checklist data: ${mergedData.keys.toList()}');
    return mergedData;
  }

  // 👇 Update assigned to field based on responsible party selection
  void _updateAssignedToField() {
    if (_selectedSite == null) return;
    if (controllers['responsible_party']!.text == 'OEM') {
      controllers['assigned_to']!.text = _selectedSite!.oem ?? '';
    } else if (controllers['responsible_party']!.text == 'Self') {
      controllers['assigned_to']!.text = _selectedSite!.self;
      // Clear identification photo when responsibleParty is not OEM
      setState(() {
        identificationPhoto = null;
        identificationPhotoByteData = "";
        _originalIdentificationPhotoId = null;
        _fsrAttachments.clear();
        _fsrAttachmentId = null;
        _fsrAttachmentName = null;
      });
    }
  }

  @override
  void dispose() {
    _siteNameController.dispose();
    _siteCodeController.dispose();
    _circleStateController.dispose();
    _clusterDistrictController.dispose();
    _customerController.dispose();
    _cmTicketNoController.dispose();
    _startDateController.dispose();
    _currentStatusController.dispose();
    _infraEngineerNameController.dispose();
    _infraEngineerContactNoController.dispose();
    _clusterInchargeNameController.dispose();
    _clusterInchargeContactNoController.dispose();
    _categoryController.dispose();
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
        if (_resolvedMode == CMScreenModeEnum.create) ...[
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
                // Clear impacted item list when switching equipment types
                _impactedItemList.clear();
                _hasFormDataChanges = true;
              });
            },
          ),
          const SizedBox(height: 8),
        ],

        if (_selectedEquipmentType.isNotEmpty &&
            _resolvedMode == CMScreenModeEnum.create)
          ChecklistCreateWidget(
            key: ValueKey(
              'checklist_${_selectedEquipmentType}_${_selectedSite?.entityId}',
            ),
            equipmentType: _selectedEquipmentType,
            checklistItemsByApi: _checklistData[_selectedEquipmentType] ?? [],
            entityId: _selectedSite?.entityId.toString(),
            isEditable: true, // Editable in create mode
            onChecklistDataChanged: (List<dynamic> updatedData) {
              setState(() {
                _onFormChanged();
                _checklistData[_selectedEquipmentType] = updatedData;
              });
            },
            cmImpactedItemList: _impactedItemList,
            onImpactedItemListChanged:
                (List<Map<String, dynamic>> impactedItems) {
                  Logger.infoLog('[CM] onImpactedItemListChanged called with ${impactedItems.length} items');
                  Logger.infoLog('[CM] onImpactedItemListChanged data: $impactedItems');
                  setState(() {
                    // Get the parent ID from the first impacted item (if available)
                    int? currentParentId;
                    if (impactedItems.isNotEmpty) {
                      final firstItem = impactedItems.first;
                      final childResponses = firstItem['childItemResponses'] as List<dynamic>? ?? 
                                           firstItem['child_item_responses'] as List<dynamic>? ?? [];
                      if (childResponses.isNotEmpty) {
                        final firstChild = childResponses.first as Map<String, dynamic>?;
                        if (firstChild != null) {
                          currentParentId = firstChild['parentCmCheckListMstId'] as int? ?? 
                                          firstChild['parent_cm_check_list_mst_id'] as int?;
                        }
                      }
                    }
                    
                    // If we have a parent ID, remove existing items for this parent and add new ones
                    // Otherwise, replace the entire list (backward compatibility)
                    if (currentParentId != null && currentParentId != 0) {
                      Logger.infoLog('[CM] Merging impacted items for parent ID: $currentParentId');
                      // Remove items that belong to this parent (by checking child responses)
                      _impactedItemList.removeWhere((existingItem) {
                        final existingChildResponses = existingItem['childItemResponses'] as List<dynamic>? ?? 
                                                     existingItem['child_item_responses'] as List<dynamic>? ?? [];
                        for (var childResponse in existingChildResponses) {
                          if (childResponse is Map<String, dynamic>) {
                            final parentMstId = childResponse['parentCmCheckListMstId'] as int? ?? 
                                              childResponse['parent_cm_check_list_mst_id'] as int?;
                            if (parentMstId == currentParentId) {
                              return true; // Remove this item
                            }
                          }
                        }
                        return false; // Keep items from other parents
                      });
                      // Add new items for this parent
                      _impactedItemList.addAll(impactedItems);
                      Logger.infoLog('[CM] Merged impacted items. New total length: ${_impactedItemList.length}');
                    } else {
                      // Fallback: Replace entire list if no parent ID found
                      Logger.infoLog('[CM] No parent ID found, replacing entire list');
                      _impactedItemList = impactedItems;
                    }
                  });
                  Logger.infoLog('[CM] _impactedItemList updated. New length: ${_impactedItemList.length}');
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
        // In edit mode, use ChecklistCreateWidget (read-only) with merged data
        if (_resolvedMode == CMScreenModeEnum.edit &&
            _selectedEquipmentType.isNotEmpty &&
            _checklistData[_selectedEquipmentType] != null)
          ChecklistCreateWidget(
            key: ValueKey(
              'checklist_edit_${_selectedEquipmentType}_${_selectedSite?.entityId}',
            ),
            equipmentType: _selectedEquipmentType,
            checklistItemsByApi: _checklistData[_selectedEquipmentType] ?? [],
            entityId: _selectedSite?.entityId.toString(),
            isEditable: false, // Not editable in edit mode (fields disabled, images shown but upload disabled)
            mode: CMScreenModeEnum.edit, // Pass mode to distinguish edit vs view
            onChecklistDataChanged: (List<dynamic> updatedData) {
              setState(() {
                _onFormChanged();
                _checklistData[_selectedEquipmentType] = updatedData;
              });
            },
            cmImpactedItemList: _impactedItemList,
            onImpactedItemListChanged:
                (List<Map<String, dynamic>> impactedItems) {
                  Logger.infoLog('[CM] onImpactedItemListChanged called with ${impactedItems.length} items (edit)');
                  setState(() {
                    // Get the parent ID from the first impacted item (if available)
                    int? currentParentId;
                    if (impactedItems.isNotEmpty) {
                      final firstItem = impactedItems.first;
                      final childResponses = firstItem['childItemResponses'] as List<dynamic>? ?? 
                                           firstItem['child_item_responses'] as List<dynamic>? ?? [];
                      if (childResponses.isNotEmpty) {
                        final firstChild = childResponses.first as Map<String, dynamic>?;
                        if (firstChild != null) {
                          currentParentId = firstChild['parentCmCheckListMstId'] as int? ?? 
                                          firstChild['parent_cm_check_list_mst_id'] as int?;
                        }
                      }
                    }
                    
                    // If we have a parent ID, remove existing items for this parent and add new ones
                    // Otherwise, replace the entire list (backward compatibility)
                    if (currentParentId != null && currentParentId != 0) {
                      Logger.infoLog('[CM] Merging impacted items for parent ID: $currentParentId (edit)');
                      // Remove items that belong to this parent (by checking child responses)
                      _impactedItemList.removeWhere((existingItem) {
                        final existingChildResponses = existingItem['childItemResponses'] as List<dynamic>? ?? 
                                                     existingItem['child_item_responses'] as List<dynamic>? ?? [];
                        for (var childResponse in existingChildResponses) {
                          if (childResponse is Map<String, dynamic>) {
                            final parentMstId = childResponse['parentCmCheckListMstId'] as int? ?? 
                                              childResponse['parent_cm_check_list_mst_id'] as int?;
                            if (parentMstId == currentParentId) {
                              return true; // Remove this item
                            }
                          }
                        }
                        return false; // Keep items from other parents
                      });
                      // Add new items for this parent
                      _impactedItemList.addAll(impactedItems);
                      Logger.infoLog('[CM] Merged impacted items. New total length: ${_impactedItemList.length} (edit)');
                    } else {
                      // Fallback: Replace entire list if no parent ID found
                      Logger.infoLog('[CM] No parent ID found, replacing entire list (edit)');
                      _impactedItemList = impactedItems;
                    }
                  });
                },
            originalCmImpactedItemMap:
                _checklistData['siteDeployedItems'] ?? {},
            onMultiDynamicDropdownValueChanged:
                (List<Map<String, dynamic>> impactedItems, String dropdownId) {
                  setState(() {
                    _impactedItemList.removeWhere(
                      (item) => item['_dropdownId'] == dropdownId,
                    );
                    for (var item in impactedItems) {
                      var newItem = Map<String, dynamic>.from(item);
                      newItem['_dropdownId'] = dropdownId;
                      _impactedItemList.add(newItem);
                    }
                  });
                },
          ),
        // In view mode, use ChecklistCreateWidget with isReadOnly: true (read-only with images)
        if (_resolvedMode == CMScreenModeEnum.view &&
            _selectedEquipmentType.isNotEmpty &&
            _checklistData[_selectedEquipmentType] != null)
          ChecklistCreateWidget(
            key: ValueKey(
              'checklist_view_${_selectedEquipmentType}_${_selectedSite?.entityId}',
            ),
            equipmentType: _selectedEquipmentType,
            checklistItemsByApi: _checklistData[_selectedEquipmentType] ?? [],
            entityId: _selectedSite?.entityId.toString(),
            isEditable: false, // Not editable in view mode (fields disabled, images shown but upload disabled)
            mode: CMScreenModeEnum.view, // Pass mode to distinguish edit vs view
            onChecklistDataChanged: (List<dynamic> updatedData) {
              // No-op in view mode
            },
            cmImpactedItemList: _impactedItemList,
            onImpactedItemListChanged:
                (List<Map<String, dynamic>> impactedItems) {
                  // No-op in view mode
                },
            originalCmImpactedItemMap:
                _checklistData['siteDeployedItems'] ?? {},
            onMultiDynamicDropdownValueChanged:
                (List<Map<String, dynamic>> impactedItems, String dropdownId) {
                  // No-op in view mode
                },
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
        showCloseButton: _resolvedMode != CMScreenModeEnum.view,
      ),
      body: Stack(
        children: [
          // Background
          Positioned.fill(
            child: SafeSvgPicture.asset(AppImages.home, fit: BoxFit.cover),
          ),
          SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.of(context).viewInsets.bottom +
                          (_resolvedMode == CMScreenModeEnum.view ? 24 : 100),
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

                if (_resolvedMode != CMScreenModeEnum.view)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: ArrowButton(
                            text: "Save",
                            isLeftArrow: false,
                            showArrow: false,
                            backgroundColor: AppColors.cmSubmitButtonColor,
                            textColor: AppColors.buttonColorSite,
                            onPressed: _isSubmitting ? null : _save,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ArrowButton(
                            text: "Save & Close",
                            isLeftArrow: false,
                            showArrow: false,
                            backgroundColor: AppColors.cmSubmitButtonColor,
                            textColor: AppColors.buttonColorSite,
                            onPressed: _isSubmitting ? null : _saveAndClose,
                          ),
                        ),
                      ],
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
    // Ensure all controllers are initialized
    controllers['fault_description'] ??= TextEditingController();
    controllers['scope_of_ticket'] ??= TextEditingController();
    
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

      // add a CM Ticket No field if case of mode is not create get cm_site_req_id from ticket response
      if (widget.mode != CMScreenModeEnum.create) ...[
        CustomFormField(
          label: "CM Ticket No",
          controller: _cmTicketNoController,
          isEditable: false,
        ),
        getHeight(15),
        CustomFormField(
          label: "Start Date",
          controller: _startDateController,
          isEditable: false,
        ),
        getHeight(15),
        CustomFormField(
          label: "Current Status",
          controller: _currentStatusController,
          isEditable: false,
          textColor: AppColors.color555555,
        ),
        getHeight(15),
        CustomFormField(
          label: "Site ID",
          controller: _siteCodeController,
          isEditable: false,
        ),
        getHeight(15),
      ],

      CustomFormField(
          label: "Site Name",
          controller: _siteNameController,
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
          label: "Infra Engineer Name",
          controller: _infraEngineerNameController,
          isEditable: false,
        ),
        getHeight(15),

        CustomFormField(
          label: "Infra Engineer Contact No",
          controller: _infraEngineerContactNoController,
          isEditable: false,
        ),
        getHeight(15),

        CustomFormField(
          label: "Cluster Incharge Name",
          controller: _clusterInchargeNameController,
          isEditable: false,
        ),
        getHeight(15),

        CustomFormField(
          label: "Cluster Incharge Contact No",
          controller: _clusterInchargeContactNoController,
          isEditable: false,
        ),
        getHeight(15),

        

        CustomDropdown(
          label: "Category",
          items: _responsiblePartyOptions,
          initialValue: controllers['responsible_party']!.text,
          isRequired: false,
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
          isRequired: false,
        ),
        getHeight(15),

        // OEM Ticket ID — editable in create/edit for both OEM and Self category
        CustomFormField(
          key: ValueKey('oem-ticket-$_oemTicketIdDisplay'),
          label: "OEM Ticket ID",
          initialValue: _oemTicketIdDisplay,
          isEditable: _resolvedMode != CMScreenModeEnum.view,
          isRequired: false,
          onChanged: (value) {
            _oemTicketIdDisplay = value;
            controllers['oem_ticket_id']!.text = value;
            _onFormChanged();
          },
        ),
        getHeight(15),

        if (_resolvedMode == CMScreenModeEnum.create)
          CustomDropdown(
            label: "Priority",
            items: _priorityOptions,
            initialValue: controllers['priority']!.text,
            isRequired: false,
            onChanged: (value) {
              setState(() {
                controllers['priority']!.text = value ?? "";
                _onFormChanged();
              });
            },
            isDisabled: false,
          )
        else
          CustomFormField(
            label: "Priority",
            controller: controllers['priority'],
            isRequired: false,
            isEditable: false,
          ),
        getHeight(15),

        _buildEquipmentTypeRadioButtons(),
        getHeight(15),

        CustomRemarksField(
          label: "Fault Description",
          isRequired: false,
          hintText: "Enter fault description",
          controller: controllers['fault_description']!,
          isDisabled: true,
        ),
        getHeight(15),

        // CustomDropdown(
        //   label: "Nature of Failure",
        //   items: _natureOfFailureOptions,
        //   initialValue: controllers['nature_of_failure']!.text,
        //   isRequired: true,
        //   onChanged: (value) {
        //     setState(() {
        //       controllers['nature_of_failure']!.text = value ?? "";
        //       _onFormChanged();
        //     });
        //   },
        //   isDisabled: widget.mode == CMScreenModeEnum.view,
        // ),
        // getHeight(15),

        // CustomDropdown(
        //   label: "Scope of Ticket",
        //   items: _scopeOfTicketOptions,
        //   initialValue: controllers['scope_of_ticket']!.text,
        //   isRequired: true,
        //   onChanged: (value) {
        //     setState(() {
        //       controllers['scope_of_ticket']!.text = value ?? "";
        //       _onFormChanged();
        //     });
        //   },
        //   isDisabled: widget.mode == CMScreenModeEnum.view,
        // ),
       

        // Action Taken - only in edit and view mode
        if (widget.mode != CMScreenModeEnum.create) ...[
        CustomFormField(
          label: "Action Taken",
          controller: controllers['action_taken'],
          isEditable: _resolvedMode != CMScreenModeEnum.view,
          isRequired: false,
          inputType: InputType.multiline,
        ),
        getHeight(15),
        ],

        // RCA - only in edit and view mode
        if (widget.mode != CMScreenModeEnum.create) ...[
        CustomFormField(
          label: "RCA",
          controller: controllers['rca'],
          isEditable: _resolvedMode != CMScreenModeEnum.view,
          isRequired: false,
        ),
        getHeight(15),
        ],

        // Closure Date - tap to open calendar in edit only; view mode disabled
        if (widget.mode != CMScreenModeEnum.create) ...[
          GestureDetector(
            onTap: _resolvedMode == CMScreenModeEnum.edit
                ? _pickClosureDate
                : null,
            child: AbsorbPointer(
              child: CustomFormField(
                label: "Closure Date",
                controller: controllers['closure_date'],
                isEditable: _resolvedMode == CMScreenModeEnum.edit,
                isRequired: false,
              ),
            ),
          ),
          getHeight(15),
        ],

        // Show these fields only in edit and view mode, and only when Category is OEM
        if (widget.mode != CMScreenModeEnum.create && 
            controllers['responsible_party']!.text.trim().toUpperCase() == 'OEM') ...[
          CustomFormField(
            label: "OEM Representative",
            controller: controllers['oem_representative'],
            isEditable: _resolvedMode != CMScreenModeEnum.view,
            isRequired: false,
          ),
          getHeight(15),

          CustomFormField(
            label: "OEM Representative Contact",
            controller: controllers['oem_representative_contact'],
            isEditable: _resolvedMode != CMScreenModeEnum.view,
            isRequired: false,
            inputType: InputType.number,
            maxLength: 10,
          ),
          getHeight(15),
        ],

       

       

        // Problem Summary - only in edit and view mode
        if (widget.mode != CMScreenModeEnum.create) ...[
        CustomRemarksField(
          label: "Problem Summary",
          hintText: "Enter problem summary",
          controller: controllers['problem_summary']!,
          isDisabled: _resolvedMode == CMScreenModeEnum.view,
        ),
        getHeight(15),
        ],

       
        getHeight(15),

     
          // Identification Photo
          ImageUploadField(
            label: "Identification",
            placeholder: "Add a Photo",
            isRequired: false,
            onImageSelected: (File? file) async {
              if (file != null) {
                final bytes = await file.readAsBytes();
                final encodedData = base64Encode(bytes);
                setState(() {
                  identificationPhoto = file;
                  identificationPhotoByteData = encodedData;
                });
                
                // Upload immediately if online
                await _uploadPhotoImmediately(
                  file,
                  'Identification',
                  (photoId) {
                    _originalIdentificationPhotoId = photoId;
                  },
                );
              }
            },
            externalImageUrl: identificationPhotoByteData,
            isDisabled: _resolvedMode == CMScreenModeEnum.view,
          ),
          getHeight(15),

          CustomFileUploadNew(
            label: "FSR",
            placeholder: "Upload File",
            isRequired: false,
            uploadedFiles: _fsrAttachments,
            serverAttachmentName: _fsrAttachments.isEmpty &&
                    _fsrAttachmentName != null &&
                    _fsrAttachmentName!.trim().isNotEmpty
                ? _fsrAttachmentName!.trim()
                : null,
            serverAttachmentId: _fsrAttachments.isEmpty &&
                    _fsrAttachmentId != null &&
                    _fsrAttachmentId != 0
                ? _fsrAttachmentId
                : null,
            onServerAttachmentClicked: _openServerAttachment,
            onFileSelected: (File? file) async {
              if (file != null) {
                setState(() {
                  _fsrAttachmentId = null;
                  _fsrAttachmentName = null;
                  _fsrAttachments.clear();
                  _fsrAttachments.add(file);
                  _hasFormDataChanges = true;
                });
                // Same as Identification: online → UploadDocuments immediately; offline → local queue (LOCAL_IMAGE_ID).
                await _uploadPhotoImmediately(
                  file,
                  'FSR',
                  (docId) {
                    _fsrAttachmentId = docId;
                    _fsrAttachmentName = file.path.split('/').last;
                  },
                );
              }
            },
            onFileDeleted: (File file) {
              setState(() {
                _fsrAttachments.remove(file);
                _fsrAttachmentId = null;
                _fsrAttachmentName = null;
                _hasFormDataChanges = true;
              });
            },
            isDisabled: _resolvedMode == CMScreenModeEnum.view,
          ),
          getHeight(15),

        // Show Time Stamp Photo only in edit and view mode
        if (widget.mode != CMScreenModeEnum.create) ...[
          // Time Stamp Photo
          ImageUploadField(
            label: "Time Stamp Photo",
            placeholder: "Add a Photo",
            isRequired: false,
            onImageSelected: (File? file) async {
              if (file != null) {
                final bytes = await file.readAsBytes();
                final encodedData = base64Encode(bytes);
                setState(() {
                  timestampPhoto = file;
                  timestampPhotoByteData = encodedData;
                });
                
                // Upload immediately if online
                await _uploadPhotoImmediately(
                  file,
                  'Time Stamp',
                  (photoId) {
                    _originalTimestampPhotoId = photoId;
                  },
                );
              }
            },
            externalImageUrl: timestampPhotoByteData,
            isDisabled: _resolvedMode == CMScreenModeEnum.view,
          ),
          getHeight(15),
        ],

        
      ],
    );
  }

  /// Format date to dd/MM/yyyy format as required by API
  String _formatDateForApi(DateTime date) {
    return DateFormat('dd/MM/yyyy').format(date);
  }

  /// For correctiveMaintenance POST: send null instead of "" for actionTaken, rca, problemSummary when empty.
  void _nullifyEmptyCmTextFields(Map<String, dynamic> requestData) {
    final actionTaken = requestData['action_taken'];
    if (actionTaken is String && actionTaken.trim().isEmpty) {
      requestData['action_taken'] = null;
      requestData['actionTaken'] = null;
    }
    final rca = requestData['rca'];
    if (rca is String && rca.trim().isEmpty) {
      requestData['rca'] = null;
    }
    final problemSummary = requestData['problem_summary'];
    if (problemSummary is String && problemSummary.trim().isEmpty) {
      requestData['problem_summary'] = null;
      requestData['problemSummary'] = null;
    }
  }

  void _applyOemTicketIdToRequest(Map<String, dynamic> requestData) {
    final value = controllers['oem_ticket_id']!.text.trim();
    requestData.remove('oem_ticket_id');
    requestData['oemTicketId'] = value.isEmpty ? null : value;
  }

  /// API expects camelCase [oemTicketId] on the final POST body.
  void _ensureOemTicketIdOnApiPayload(Map<String, dynamic> payload) {
    payload.remove('oem_ticket_id');
    final value = controllers['oem_ticket_id']!.text.trim();
    payload['oemTicketId'] = value.isEmpty ? null : value;
  }

  /// API date → `dd/MM/yyyy` using only the `YYYY-MM-DD` segment (before `T` if present). No timezone.
  String _apiDateStringToDdMmYyyy(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '';
    if (trimmed.contains('/')) return trimmed;

    String ymd;
    final tIndex = trimmed.indexOf('T');
    if (tIndex > 0) {
      ymd = trimmed.substring(0, tIndex);
    } else if (trimmed.length >= 10 &&
        trimmed[4] == '-' &&
        trimmed[7] == '-') {
      ymd = trimmed.substring(0, 10);
    } else {
      return trimmed;
    }

    final parts = ymd.split('-');
    if (parts.length == 3 && parts[0].length == 4) {
      return '${parts[2]}/${parts[1]}/${parts[0]}';
    }
    return trimmed;
  }

  /// Format date string to dd/MM/yyyy for display (e.g. Start Date).
  String _formatDateStringForApi(String? dateString) {
    if (dateString == null || dateString.isEmpty) {
      return _formatDateForApi(DateTime.now());
    }
    final display = _apiDateStringToDdMmYyyy(dateString);
    if (display.contains('/')) {
      return display;
    }
    try {
      return _formatDateForApi(DateTime.parse(dateString.trim()));
    } catch (e) {
      Logger.errorLog('[CM] Error formatting date: $dateString, error: $e');
      return _formatDateForApi(DateTime.now());
    }
  }

  DateTime? _parseFlexibleDate(String? dateString) {
    if (dateString == null || dateString.trim().isEmpty) return null;
    var raw = dateString.trim();

    // dd/MM/yyyy from field / picker
    try {
      return DateFormat('dd/MM/yyyy').parseStrict(raw);
    } catch (_) {}

    // API ISO: date before T only
    final tIndex = raw.indexOf('T');
    if (tIndex > 0) {
      raw = raw.substring(0, tIndex);
    }
    if (raw.length >= 10 && raw[4] == '-' && raw[7] == '-') {
      final parts = raw.substring(0, 10).split('-');
      if (parts.length == 3) {
        try {
          return DateTime(
            int.parse(parts[0]),
            int.parse(parts[1]),
            int.parse(parts[2]),
          );
        } catch (_) {}
      }
    }

    try {
      return DateTime.parse(raw);
    } catch (_) {}
    return null;
  }

  bool _isFutureDate(DateTime date) {
    final normalizedDate = DateUtils.dateOnly(date);
    final today = DateUtils.dateOnly(DateTime.now());
    return normalizedDate.isAfter(today);
  }

  Future<void> _pickClosureDate() async {
    if (_resolvedMode == CMScreenModeEnum.create ||
        _resolvedMode == CMScreenModeEnum.view) {
      return;
    }
    final initialDate = _parseFlexibleDate(controllers['closure_date']!.text) ?? DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (pickedDate != null) {
      setState(() {
        controllers['closure_date']!.text = DateFormat('dd/MM/yyyy').format(pickedDate);
        _hasFormDataChanges = true;
      });
    }
  }

  /// Normalizes image payload maps to keep local file paths in `image_path`.
  /// This reduces base64 fallback during LOCAL_IMAGE_ID reconciliation uploads.
  void _normalizeLocalImagePayload(Map<String, dynamic> imageData) {
    final existingPath = imageData['image_path']?.toString() ??
        imageData['imagePath']?.toString();
    if (existingPath != null && existingPath.startsWith('/')) {
      imageData['image_path'] = existingPath;
      imageData['imagePath'] = existingPath;
      return;
    }

    final candidates = <String?>[
      imageData['image_url']?.toString(),
      imageData['imageUrl']?.toString(),
      imageData['image_data']?.toString(),
      imageData['imageData']?.toString(),
    ];

    for (final candidate in candidates) {
      if (candidate != null && candidate.startsWith('/')) {
        imageData['image_path'] = candidate;
        imageData['imagePath'] = candidate;
        return;
      }
    }
  }

  /// Upload all checklist images that have LOCAL_IMAGE_ID and replace with actual photo IDs
  Future<void> _uploadChecklistImagesAndUpdateIds(
    List<dynamic> checklistData,
  ) async {
    Logger.infoLog('[CM] Starting to upload checklist images...');
    
    // Helper function to upload a single image
    Future<String?> _uploadSingleImage(
      Map<String, dynamic> imageData,
      String context,
    ) async {
      _normalizeLocalImagePayload(imageData);
      final photoId = imageData['photo_id']?.toString() ?? imageData['photoId']?.toString();
      
      // Only upload if it's a LOCAL_IMAGE_ID
      if (photoId != 'LOCAL_IMAGE_ID' && (photoId == null || !photoId.startsWith('LOCAL_IMAGE_ID'))) {
        return null; // Not a local image, skip
      }
      
      try {
        // Prefer file-path upload to reduce memory pressure; fallback to base64 for legacy payloads.
        final imagePath =
            imageData['image_path']?.toString() ??
            imageData['imagePath']?.toString();
        final imageFile =
            imagePath != null && imagePath.isNotEmpty ? File(imagePath) : null;

        String? serverPhotoId;
        if (imageFile != null && await imageFile.exists()) {
          Logger.infoLog('[CM] Uploading image for: $context using file path');
          serverPhotoId = await ServiceLocator()
              .imageUploadService
              .uploadImageFromFilePath(
                imageFile.path,
                ActivityTypeEnum.correctiveMaintenance,
                false,
                _selectedSite?.siteId.toString(),
              );
        } else {
          var base64Image = imageData['image_data']?.toString();

          // If image_data is a data URL, extract the base64 part
          if (base64Image != null && base64Image.startsWith('data:image')) {
            final parts = base64Image.split(',');
            if (parts.length > 1) {
              base64Image = parts[1];
            }
          }

          if (base64Image == null || base64Image.isEmpty) {
            Logger.errorLog(
              '[CM] No image_data/image_path found for LOCAL_IMAGE_ID in $context - clearing photoId so it is not sent',
            );
            imageData['photo_id'] = null;
            imageData['photoId'] = null;
            return null;
          }

          Logger.infoLog('[CM] Uploading image for: $context using base64 fallback');
          serverPhotoId = await ServiceLocator().imageUploadService.uploadImage(
            base64Image,
            ActivityTypeEnum.correctiveMaintenance,
            false, // not a selfie
            _selectedSite?.siteId.toString(),
          );
        }

        if (serverPhotoId.isEmpty) {
          Logger.errorLog(
            '[CM] ❌ Failed to upload image - empty photo ID returned, clearing photoId so it is not sent',
          );
          imageData['photo_id'] = null;
          imageData['photoId'] = null;
          return null;
        }

        // Replace LOCAL_IMAGE_ID with actual server photo ID
        imageData['photo_id'] = serverPhotoId;
        imageData['photoId'] = serverPhotoId;

        Logger.infoLog('[CM] ✅ Image uploaded successfully. Photo ID: $serverPhotoId');
        return serverPhotoId;
      } catch (e) {
        Logger.errorLog('[CM] ❌ Error uploading image: $e - clearing photoId so it is not sent');
        imageData['photo_id'] = null;
        imageData['photoId'] = null;
        return null;
      }
    }
    
    // Process main checklist items
    for (var item in checklistData) {
      final Map<String, dynamic> checklistItem = Map<String, dynamic>.from(item);
      
      // Process main item images
      final responseImages = checklistItem['response_images'] as List<dynamic>? ?? [];
      
      if (responseImages.isNotEmpty) {
        for (int i = 0; i < responseImages.length; i++) {
          final imageData = responseImages[i] as Map<String, dynamic>;
          await _uploadSingleImage(
            imageData,
            'checklist item ${checklistItem['checklist_desc']} - image ${i + 1}',
          );
        }
      }
    }
    
    // Process child item images from _impactedItemList (dynamic dropdown data)
    Logger.infoLog('[CM] Processing child item images from impacted item list (${_impactedItemList.length} items)...');
    for (var impactedItem in _impactedItemList) {
      // Handle both camelCase and snake_case field names
      final childItemResponses = impactedItem['childItemResponses'] as List<dynamic>? ?? 
                                 impactedItem['child_item_responses'] as List<dynamic>? ?? [];
      
      Logger.infoLog('[CM] Processing ${childItemResponses.length} child item responses for impacted item: ${impactedItem['mfgSerialNo'] ?? impactedItem['mfg_serial_no']}');
      
      for (var childResponse in childItemResponses) {
        if (childResponse is Map<String, dynamic>) {
          // Handle both camelCase and snake_case field names
          final childResponseImages = childResponse['responseImages'] as List<dynamic>? ?? 
                                     childResponse['response_images'] as List<dynamic>? ?? [];
          
          final checklistDesc = childResponse['checklistDesc']?.toString() ?? 
                               childResponse['checklist_desc']?.toString() ?? 
                               'child item ${childResponse['cmCheckListMstId'] ?? childResponse['cm_check_list_mst_id']}';
          
          Logger.infoLog('[CM] Processing ${childResponseImages.length} images for: $checklistDesc');
          
          for (var childImageData in childResponseImages) {
            if (childImageData is Map<String, dynamic>) {
              // Get base64 from imageData field (camelCase) or image_data (snake_case)
              var base64Image = childImageData['imageData']?.toString() ?? 
                               childImageData['image_data']?.toString();
              
              // If base64 is not directly available, try to extract from data URL
              if (base64Image == null || base64Image.isEmpty) {
                // Check if there's a data URL format
                final imageUrl = childImageData['imageUrl']?.toString() ?? 
                                childImageData['image_url']?.toString();
                if (imageUrl != null && imageUrl.startsWith('data:image')) {
                  final parts = imageUrl.split(',');
                  if (parts.length > 1) {
                    base64Image = parts[1];
                  }
                }
              }
              
              // Store base64 in image_data for the upload function
              if (base64Image != null && base64Image.isNotEmpty) {
                childImageData['image_data'] = base64Image;
              }
              final imagePath = childImageData['imagePath']?.toString() ??
                  childImageData['image_path']?.toString() ??
                  childImageData['imageUrl']?.toString() ??
                  childImageData['image_url']?.toString();
              if (imagePath != null && imagePath.startsWith('/')) {
                childImageData['image_path'] = imagePath;
              }
              
              await _uploadSingleImage(
                childImageData,
                '$checklistDesc (impacted item)',
              );
            }
          }
        }
      }
    }
    
    Logger.infoLog('[CM] Finished uploading checklist images');
  }

  /// Whether Identification / Time Stamp / FSR still need [_uploadDocumentWithFallback]:
  /// missing id, or offline placeholder [LOCAL_IMAGE_ID] (pick was offline — replace with real doc id before POST when online).
  bool _needsCmAttachmentUpload(dynamic id) {
    if (id == null) return true;
    final s = id.toString().trim();
    if (s.isEmpty || s == '0') return true;
    if (s.startsWith('LOCAL_IMAGE_ID')) return true;
    return false;
  }

  /// Upload a photo immediately when selected (online: UploadDocuments; offline: queue locally).
  Future<void> _uploadPhotoImmediately(
    File file,
    String photoName,
    Function(String) onPhotoIdReceived,
  ) async {
    try {
      Logger.infoLog('[CM] Persisting $photoName (immediate: UploadDocuments if online else local queue)...');
      final serverPhotoId = await _uploadDocumentWithFallback(file);
      
      if (serverPhotoId?.isNotEmpty == true) {
        onPhotoIdReceived(serverPhotoId!);
        Logger.infoLog('[CM] ✅ $photoName photo uploaded immediately. Photo ID: $serverPhotoId');
        
        if (mounted) {
          setState(() {}); // Update UI to reflect photo ID is set
        }
      } else {
        Logger.errorLog('[CM] ❌ Failed to upload $photoName photo - empty photo ID returned');
      }
    } catch (e, stackTrace) {
      Logger.errorLog('[CM] ❌ Error uploading $photoName photo immediately: $e');
      Logger.errorLog('[CM] Stack trace: $stackTrace');
    }
  }

  /// Retry Identification / Time Stamp / FSR when id missing, pick-time upload failed, or id is still LOCAL_IMAGE_ID (offline pick, online submit).
  /// Primary upload for all three runs on user selection (see [ImageUploadField] / [CustomFileUploadNew.onFileSelected]).
  Future<void> _uploadAdditionalPhotos() async {
    Logger.infoLog('[CM] Retry uploads before CM POST if needed — Identification, Time Stamp, FSR...');
    Logger.infoLog('[CM] Photo status - Identification: ${identificationPhoto != null ? "present" : "null"} (ID: $_originalIdentificationPhotoId), TimeStamp: ${timestampPhoto != null ? "present" : "null"} (ID: $_originalTimestampPhotoId), FSR files: ${_fsrAttachments.length}, FSR id: $_fsrAttachmentId');
    
    // Identification — retry when no server doc id yet or still offline placeholder
    if (identificationPhoto != null && _needsCmAttachmentUpload(_originalIdentificationPhotoId)) {
      try {
        Logger.infoLog('[CM] Uploading Identification using UploadDocuments service...');
        final serverPhotoId =
            await _uploadDocumentWithFallback(identificationPhoto!);
        
        if (serverPhotoId?.isNotEmpty == true) {
          _originalIdentificationPhotoId = serverPhotoId;
          Logger.infoLog('[CM] ✅ Identification photo uploaded successfully. Photo ID: $serverPhotoId');
        } else {
          Logger.errorLog('[CM] ❌ Failed to upload Identification photo - empty photo ID returned');
          _originalIdentificationPhotoId = null;
        }
      } catch (e, stackTrace) {
        Logger.errorLog('[CM] ❌ Error uploading Identification photo: $e');
        Logger.errorLog('[CM] Stack trace: $stackTrace');
        _originalIdentificationPhotoId = null;
      }
    } else if (identificationPhoto != null) {
      Logger.infoLog('[CM] ⏭️ Identification photo already uploaded (ID: $_originalIdentificationPhotoId) - skipping');
    } else {
      Logger.infoLog('[CM] ⚠️ Identification photo is null - skipping upload');
    }
    
    // Time Stamp — same as Identification
    if (timestampPhoto != null && _needsCmAttachmentUpload(_originalTimestampPhotoId)) {
      try {
        Logger.infoLog('[CM] Uploading Time Stamp using UploadDocuments service...');
        final serverPhotoId = await _uploadDocumentWithFallback(timestampPhoto!);
        
        if (serverPhotoId?.isNotEmpty == true) {
          _originalTimestampPhotoId = serverPhotoId;
          Logger.infoLog('[CM] ✅ Time Stamp photo uploaded successfully. Photo ID: $serverPhotoId');
        } else {
          Logger.errorLog('[CM] ❌ Failed to upload Time Stamp photo - empty photo ID returned');
          _originalTimestampPhotoId = null;
        }
      } catch (e, stackTrace) {
        Logger.errorLog('[CM] ❌ Error uploading Time Stamp photo: $e');
        Logger.errorLog('[CM] Stack trace: $stackTrace');
        _originalTimestampPhotoId = null;
      }
    } else if (timestampPhoto != null) {
      Logger.infoLog('[CM] ⏭️ Time Stamp photo already uploaded (ID: $_originalTimestampPhotoId) - skipping');
    } else {
      Logger.infoLog('[CM] ⚠️ Time Stamp photo is null - skipping upload');
    }

    // FSR — uploaded on file pick (online + offline); retry if no id, failed pick upload, or LOCAL_IMAGE_ID while submitting online
    if (_fsrAttachments.isNotEmpty && _needsCmAttachmentUpload(_fsrAttachmentId)) {
      try {
        Logger.infoLog('[CM] Retrying FSR upload / replacing LOCAL placeholder before CM POST...');
        final uploadedId =
            await _uploadDocumentWithFallback(_fsrAttachments.first);
        final fsrIdStr = uploadedId?.toString().trim() ?? '';
        if (fsrIdStr.isNotEmpty) {
          _fsrAttachmentId = fsrIdStr;
          _fsrAttachmentName = _fsrAttachments.first.path.split('/').last;
          Logger.infoLog('[CM] ✅ FSR retry OK. Id: $uploadedId');
        } else {
          Logger.errorLog('[CM] ❌ FSR retry returned empty doc ID');
        }
      } catch (e, stackTrace) {
        Logger.errorLog('[CM] ❌ Error retrying FSR upload: $e');
        Logger.errorLog('[CM] Stack trace: $stackTrace');
      }
    } else if (_fsrAttachments.isNotEmpty) {
      Logger.infoLog('[CM] ⏭️ FSR already has doc id ($_fsrAttachmentId) — skip retry before CM POST');
    }

    Logger.infoLog('[CM] Pre-CM POST upload pass done. Identification: $_originalIdentificationPhotoId, TimeStamp: $_originalTimestampPhotoId, FSR: $_fsrAttachmentId');
  }

  Future<String?> _uploadDocumentWithFallback(File file) async {
    final isOnline = await ConnectivityHelper.isConnected();
    if (!isOnline) {
      Logger.infoLog(
        '[CM] Offline: persist file locally (no api/v1/mobile/uploads — CM docs use UploadDocuments only when online): ${file.path.split('/').last}',
      );
      return await _persistCmDocumentLocalOnly(file);
    }

    final result = await _uploadDocumentsService.uploadFile(
      file: file,
      id: '0',
      activityType: ActivityTypeEnum.correctiveMaintenance.value,
    );

    if (result.isSuccess && (result.data ?? '').trim().isNotEmpty) {
      return (result.data ?? '').trim();
    }

    Logger.infoLog(
      '[CM] UploadDocuments failed; persisting locally without calling api/v1/mobile/uploads: ${file.path.split('/').last}',
    );
    return await _persistCmDocumentLocalOnly(file);
  }

  /// Offline / UploadDocuments-failure: store file + LOCAL id only — never [uploadImageFromFilePath] / mobile/uploads.
  Future<String?> _persistCmDocumentLocalOnly(File file) async {
    try {
      return await ServiceLocator().imageUploadService
          .persistCmDocumentLocalWithoutMobileUploads(file.path);
    } catch (e) {
      Logger.errorLog('[CM] persistCmDocumentLocalOnly failed: $e');
      return null;
    }
  }

  Future<void> _uploadImpactedItemImagesAndUpdateIds(
    List<Map<String, dynamic>> impactedItemList,
  ) async {
    Logger.infoLog('[CM] Starting to upload impacted item images...');
    
    // Helper function to upload a single image
    Future<String?> _uploadSingleImage(
      Map<String, dynamic> imageData,
      String context,
    ) async {
      _normalizeLocalImagePayload(imageData);
      final photoId = imageData['photoId']?.toString() ?? 
                     imageData['photo_id']?.toString();
      
      // Only upload if it's a LOCAL_IMAGE_ID
      if (photoId != 'LOCAL_IMAGE_ID' && (photoId == null || !photoId.startsWith('LOCAL_IMAGE_ID'))) {
        return null; // Not a local image, skip
      }
      
      try {
        // Prefer file-path upload to reduce memory pressure; fallback to base64 for legacy payloads.
        final imagePath =
            imageData['imagePath']?.toString() ??
            imageData['image_path']?.toString();
        final imageFile =
            imagePath != null && imagePath.isNotEmpty ? File(imagePath) : null;

        String? serverPhotoId;
        if (imageFile != null && await imageFile.exists()) {
          Logger.infoLog(
            '[CM] Uploading impacted item image for: $context using file path',
          );
          serverPhotoId = await ServiceLocator()
              .imageUploadService
              .uploadImageFromFilePath(
                imageFile.path,
                ActivityTypeEnum.correctiveMaintenance,
                false,
                _selectedSite?.siteId.toString(),
              );
        } else {
          var base64Image = imageData['imageData']?.toString() ??
              imageData['image_data']?.toString();

          // If image_data is a data URL, extract the base64 part
          if (base64Image != null && base64Image.startsWith('data:image')) {
            final parts = base64Image.split(',');
            if (parts.length > 1) {
              base64Image = parts[1];
            }
          }

          if (base64Image == null || base64Image.isEmpty) {
            Logger.errorLog(
              '[CM] No imageData/image_data/imagePath found for LOCAL_IMAGE_ID in $context - clearing photoId so it is not sent',
            );
            imageData['photoId'] = null;
            imageData['photo_id'] = null;
            return null;
          }

          Logger.infoLog(
            '[CM] Uploading impacted item image for: $context using base64 fallback',
          );
          serverPhotoId = await ServiceLocator().imageUploadService.uploadImage(
            base64Image,
            ActivityTypeEnum.correctiveMaintenance,
            false, // not a selfie
            _selectedSite?.siteId.toString(),
          );
        }

        if (serverPhotoId.isEmpty) {
          Logger.errorLog(
            '[CM] ❌ Failed to upload impacted item image - empty photo ID returned, clearing photoId so it is not sent',
          );
          imageData['photoId'] = null;
          imageData['photo_id'] = null;
          return null;
        }

        // Replace LOCAL_IMAGE_ID with actual server photo ID (update both field names)
        imageData['photoId'] = serverPhotoId;
        imageData['photo_id'] = serverPhotoId;

        Logger.infoLog('[CM] ✅ Impacted item image uploaded successfully. Photo ID: $serverPhotoId');
        return serverPhotoId;
      } catch (e) {
        Logger.errorLog('[CM] ❌ Error uploading impacted item image: $e - clearing photoId so it is not sent');
        imageData['photoId'] = null;
        imageData['photo_id'] = null;
        return null;
      }
    }
    
    // Process each impacted item
    for (var impactedItem in impactedItemList) {
      // Handle both camelCase and snake_case field names
      final childItemResponses = impactedItem['childItemResponses'] as List<dynamic>? ?? 
                                 impactedItem['child_item_responses'] as List<dynamic>? ?? [];
      
      final mfgSerialNo = impactedItem['mfgSerialNo']?.toString() ?? 
                         impactedItem['mfg_serial_no']?.toString() ?? 
                         'unknown';
      
      Logger.infoLog('[CM] Processing impacted item: $mfgSerialNo (${childItemResponses.length} child responses)');
      
      for (var childResponse in childItemResponses) {
        if (childResponse is Map<String, dynamic>) {
          // Handle both camelCase and snake_case field names
          final responseImages = childResponse['responseImages'] as List<dynamic>? ?? 
                                childResponse['response_images'] as List<dynamic>? ?? [];
          
          final checklistDesc = childResponse['checklistDesc']?.toString() ?? 
                               childResponse['checklist_desc']?.toString() ?? 
                               'child item ${childResponse['cmCheckListMstId'] ?? childResponse['cm_check_list_mst_id']}';
          
          Logger.infoLog('[CM] Processing ${responseImages.length} images for: $checklistDesc');
          
          for (var imageData in responseImages) {
            if (imageData is Map<String, dynamic>) {
              await _uploadSingleImage(
                imageData,
                '$checklistDesc (impacted item: $mfgSerialNo)',
              );
            }
          }
        }
      }
    }
    
    Logger.infoLog('[CM] Finished uploading impacted item images');
  }

  /// Transform checklist data to the API required format
  List<Map<String, dynamic>> _transformChecklistDataToApiFormat(
    List<dynamic> checklistData,
    LocationModel location,
  ) {
    final transformedList = <Map<String, dynamic>>[];
    final now = DateTime.now();
    
    // Group impacted items by their parent checklist mstId
    final impactedItemsByParentMstId = <int, List<Map<String, dynamic>>>{};
    Logger.infoLog('[CM] Processing ${_impactedItemList.length} impacted items for grouping');
    
    for (var impactedItem in _impactedItemList) {
      // Get the parent mstId from childItemResponses (they all reference the same parent)
      // OR from the impacted item itself if no child responses exist
      final childItemResponses = impactedItem['childItemResponses'] as List<dynamic>? ?? 
                                 impactedItem['child_item_responses'] as List<dynamic>? ?? [];
      
      Logger.infoLog('[CM] Processing impacted item - mfgSerialNo: ${impactedItem['mfgSerialNo']}, cmItemType: ${impactedItem['cmItemType']}, has ${childItemResponses.length} child responses');
      
      int? parentMstId;
      
      if (childItemResponses.isNotEmpty) {
        final firstChild = childItemResponses.first as Map<String, dynamic>?;
        if (firstChild != null) {
          // Use ONLY parent_cm_check_list_mst_id for grouping (don't fallback to child's mstId)
          parentMstId = firstChild['parentCmCheckListMstId'] as int? ?? 
                       firstChild['parent_cm_check_list_mst_id'] as int?;
          
          final childMstId = firstChild['cmCheckListMstId'] as int? ?? 
                            firstChild['cm_check_list_mst_id'] as int?;
          
          Logger.infoLog('[CM] Impacted item - parentMstId: $parentMstId, childMstId: $childMstId, firstChild keys: ${firstChild.keys.toList()}');
          Logger.infoLog('[CM] Impacted item - parentCmCheckListMstId: ${firstChild['parentCmCheckListMstId']}, parent_cm_check_list_mst_id: ${firstChild['parent_cm_check_list_mst_id']}');
        }
      } else {
        // If no child responses, check if parent ID is stored directly on the impacted item
        // This handles cases where impacted_item_check_list is null (e.g., SOLAR with only dependent_elements)
        parentMstId = impactedItem['parentCmCheckListMstId'] as int? ?? 
                     impactedItem['parent_cm_check_list_mst_id'] as int?;
        Logger.infoLog('[CM] Impacted item has no child responses, checking for direct parent ID: $parentMstId');
      }
      
      if (parentMstId != null && parentMstId != 0) {
        if (!impactedItemsByParentMstId.containsKey(parentMstId)) {
          impactedItemsByParentMstId[parentMstId] = [];
        }
        impactedItemsByParentMstId[parentMstId]!.add(impactedItem);
        Logger.infoLog('[CM] Added impacted item to parent group: $parentMstId');
      } else {
        Logger.errorLog('[CM] Warning: Impacted item has no valid parentMstId (null or 0)');
      }
    }
    
    Logger.infoLog('[CM] Grouped impacted items by parent MstId: ${impactedItemsByParentMstId.keys.toList()}');
    Logger.infoLog('[CM] Impacted items count per parent: ${impactedItemsByParentMstId.map((k, v) => MapEntry(k.toString(), v.length))}');
    
    // Debug: Log all parent IDs found in impacted items
    final allParentIds = <int>{};
    for (var impactedItem in _impactedItemList) {
      final childItemResponses = impactedItem['childItemResponses'] as List<dynamic>? ?? 
                                 impactedItem['child_item_responses'] as List<dynamic>? ?? [];
      for (var childResponse in childItemResponses) {
        if (childResponse is Map<String, dynamic>) {
          final parentMstId = childResponse['parentCmCheckListMstId'] as int? ?? 
                            childResponse['parent_cm_check_list_mst_id'] as int?;
          if (parentMstId != null && parentMstId != 0) {
            allParentIds.add(parentMstId);
          }
        }
      }
    }
    Logger.infoLog('[CM] All unique parent IDs found in impacted items: ${allParentIds.toList()}');
    
    for (var item in checklistData) {
      final Map<String, dynamic> checklistItem = Map<String, dynamic>.from(item);
      
      // Get the checklist mstId first (needed for checking impacted items)
      final checklistMstId = checklistItem['cm_check_list_mst_id'] as int? ?? 
                            checklistItem['cmCheckListMstId'] as int? ??
                            checklistItem['item_type_id'] as int?;
      
      final checklistDesc = checklistItem['checklist_desc']?.toString() ?? 
                           checklistItem['checklistDesc']?.toString() ?? '';
      
      Logger.infoLog('[CM] Transform - Processing item - mstId: $checklistMstId, checklistDesc: $checklistDesc, respType: ${checklistItem['resp_type'] ?? checklistItem['respType']}');
      
      // Get response value based on resp_type
      dynamic respValue;
      final respType = checklistItem['resp_type']?.toString() ??
          checklistItem['respType']?.toString() ??
          '';
      
      // Check if this checklist item has impacted items (primary check)
      final hasImpactedItems = checklistMstId != null && impactedItemsByParentMstId.containsKey(checklistMstId);
      
      // Additional fallback: walk impacted items when grouping may miss the parent row
      // (DYNAMIC_DROPDOWN, MULTI_DYNAMIC_DROPDOWN, or parent rows that carry impacted data under CHECKBOX_NUMERIC / CHECKBOX_TEXT)
      bool hasAnyImpactedItems = false;
      if (checklistMstId != null &&
          (respType == 'DYNAMIC_DROPDOWN' ||
              respType == 'MULTI_DYNAMIC_DROPDOWN' ||
              respType == 'CHECKBOX_NUMERIC' ||
              respType == 'CHECKBOX_TEXT')) {
        Logger.infoLog('[CM] Transform - Checking impacted-item fallback for respType $respType, mstId: $checklistMstId, checklistDesc: $checklistDesc, total impacted items: ${_impactedItemList.length}');
        // Check all impacted items to see if any have this parent ID
        for (var impactedItem in _impactedItemList) {
          final childItemResponses = impactedItem['childItemResponses'] as List<dynamic>? ?? 
                                     impactedItem['child_item_responses'] as List<dynamic>? ?? [];
          Logger.infoLog('[CM] Transform - Impacted item - mfgSerialNo: ${impactedItem['mfgSerialNo']}, cmItemType: ${impactedItem['cmItemType']}, has ${childItemResponses.length} child responses');
          
          // If no child responses, skip this impacted item
          if (childItemResponses.isEmpty) {
            Logger.infoLog('[CM] Transform - Impacted item has no child responses, skipping');
            continue;
          }
          
          for (var childResponse in childItemResponses) {
            if (childResponse is Map<String, dynamic>) {
              final parentMstId = childResponse['parentCmCheckListMstId'] as int? ?? 
                                childResponse['parent_cm_check_list_mst_id'] as int?;
              final childMstId = childResponse['cmCheckListMstId'] as int? ?? 
                               childResponse['cm_check_list_mst_id'] as int?;
              Logger.infoLog('[CM] Transform - Child response - parentMstId: $parentMstId, childMstId: $childMstId, checking against checklistMstId: $checklistMstId');
              if (parentMstId != null && parentMstId != 0 && parentMstId == checklistMstId) {
                Logger.infoLog('[CM] Transform - ✅ Found matching parent ID in fallback check! parentMstId: $parentMstId == checklistMstId: $checklistMstId');
                hasAnyImpactedItems = true;
                break;
              }
            }
          }
          if (hasAnyImpactedItems) break;
        }
        if (!hasAnyImpactedItems) {
          Logger.errorLog('[CM] Transform - ❌ No matching parent ID found in fallback check for mstId: $checklistMstId, checklistDesc: $checklistDesc, respType: $respType');
          Logger.errorLog('[CM] Transform - Available parent IDs in impacted items: ${impactedItemsByParentMstId.keys.toList()}');
        }
      }
      
      final finalHasImpactedItems = hasImpactedItems || hasAnyImpactedItems;
      
      Logger.infoLog('[CM] Transform - mstId: $checklistMstId, respType: $respType, respValue: $respValue, hasImpactedItems: $hasImpactedItems, hasAnyImpactedItems: $hasAnyImpactedItems, finalHasImpactedItems: $finalHasImpactedItems');
      
      if (respType == 'CHECKBOX') {
        // For checkbox, resp should be "true" or "false"
        final resp = checklistItem['resp']?.toString() ?? '';
        respValue = (resp == 'true' || resp == 'True' || resp == 'TRUE') ? 'true' : 'false';
      } else if (respType == 'CHECKBOX_NUMERIC' || respType == 'CHECKBOX_TEXT') {
        // For CHECKBOX_NUMERIC and CHECKBOX_TEXT, resp should be the same as respNumeric (numeric value) when checked, "0" when unchecked
        final numericValue = checklistItem['numeric_value'] ?? 
                            checklistItem['numericValue'] ??
                            checklistItem['resp_numeric'] ??
                            checklistItem['respNumeric'] ??
                            '';
        final resp = checklistItem['resp'];
        // If checkbox is checked and numeric value exists, use numeric value; otherwise use "0"
        if (resp == 1 || resp == '1' || resp == 'true' || resp == true || resp == 'True' || resp == 'TRUE' || (resp != null && resp != '0' && resp != 0)) {
          // Checkbox is checked - use numeric value if available, otherwise use resp value
          respValue = numericValue.toString().isNotEmpty ? numericValue.toString() : (resp?.toString() ?? '0');
        } else {
          respValue = '0'; // Save as string "0" when unchecked
        }
        // Note: numeric_value is stored separately for CHECKBOX_NUMERIC
      } else if (respType == 'TEXT' || respType == 'NUMERIC') {
        // For text/numeric, resp is the actual value
        respValue = checklistItem['resp']?.toString() ?? '';
      } else if (respType == 'RADIO' || respType == 'DROPDOWN') {
        // For radio/dropdown, resp is the selected value
        respValue = checklistItem['resp']?.toString() ?? '';
      } else if (respType == 'DYNAMIC_DROPDOWN' || respType == 'MULTI_DYNAMIC_DROPDOWN') {
        // For dynamic dropdowns, we might need to handle differently
        // For now, use resp if available
        respValue = checklistItem['resp']?.toString();
      } else if (respType == 'DYNAMIC_NUMERIC') {
        // For DYNAMIC_NUMERIC, resp is the numeric count value
        respValue = checklistItem['resp']?.toString() ?? '';
      }
      
      // Get response_images to check if there are images (needed for DYNAMIC_NUMERIC skip logic)
      final responseImages = checklistItem['response_images'] as List<dynamic>? ?? [];
      final hasImages = responseImages.isNotEmpty;
      
      // For DYNAMIC_NUMERIC, if resp is empty but images exist, set resp to the count of images
      if (respType == 'DYNAMIC_NUMERIC' && (respValue == null || respValue.isEmpty) && hasImages) {
        respValue = responseImages.length.toString();
      }
      
      // Skip items without a response (unless they're required or have impacted items or images)
      // IMPORTANT: Always include DYNAMIC_DROPDOWN and MULTI_DYNAMIC_DROPDOWN items from checklist template
      // even if they have no impacted items, to ensure complete checklist is sent
      if (respValue == null || (respValue is String && respValue.isEmpty)) {
        // Don't skip if:
        // 1. It's a checkbox type (even if unchecked)
        // 2. It's a DYNAMIC_DROPDOWN (always include, even without impacted items)
        // 3. It's a MULTI_DYNAMIC_DROPDOWN (always include, even without impacted items)
        // 4. It's a DYNAMIC_NUMERIC with images (images are the actual response)
        if (respType != 'CHECKBOX' && 
            respType != 'CHECKBOX_NUMERIC' && 
            respType != 'CHECKBOX_TEXT' &&
            respType != 'DYNAMIC_DROPDOWN' &&  // Always include DYNAMIC_DROPDOWN
            respType != 'MULTI_DYNAMIC_DROPDOWN' &&  // Always include MULTI_DYNAMIC_DROPDOWN
            !(respType == 'DYNAMIC_NUMERIC' && hasImages)) {
          Logger.infoLog('[CM] Skipping item with mstId: $checklistMstId, respType: $respType (no response and no impacted items/images)');
          continue; // Skip items without responses
        }
      }
      
      // For DYNAMIC_DROPDOWN, always set resp to null if no resp value (will be sent as null in API)
      // This ensures all DYNAMIC_DROPDOWN items from checklist template are included
      if ((respType == 'DYNAMIC_DROPDOWN' || respType == 'MULTI_DYNAMIC_DROPDOWN') && 
          (respValue == null || (respValue is String && respValue.isEmpty))) {
        respValue = null; // Explicitly set to null for API
        Logger.infoLog('[CM] Setting respValue to null for DYNAMIC_DROPDOWN (mstId: $checklistMstId, hasImpactedItems: $finalHasImpactedItems)');
      }
      
      // Transform response_images to cmCheckListSiteRespImagesList
      final List<Map<String, dynamic>> imageList = [];
      // responseImages already retrieved above for skip logic
      
      for (var imageData in responseImages) {
        final Map<String, dynamic> imageItem = Map<String, dynamic>.from(imageData);
        
        // Format photoTakenTs to dd/MM/yyyy format
        final photoTakenTs = imageItem['photo_taken_ts'] ?? 
                            imageItem['photoTakenTs'];
        final formattedPhotoTakenTs = photoTakenTs != null 
            ? _formatDateStringForApi(photoTakenTs.toString())
            : _formatDateForApi(now);
        
        final transformedImage = {
          'cclsriId': 0, // New image, so ID is 0
          'photoId': imageItem['photo_id'] ?? imageItem['photoId'],
          'photoTakenTs': formattedPhotoTakenTs,
          'isActive': true,
          'remarks': imageItem['remarks'] ?? 'string',
        };
        
        imageList.add(transformedImage);
      }
      
      // Get cmItemType
      final cmItemType = checklistItem['cmItemType'] ?? 
                        checklistItem['subItemType'] ?? 
                        checklistItem['sub_item_type'] ??
                        _selectedEquipmentType;
      
      // Build the transformed item
      final transformedItem = {
        'cmCheckListSiteRespId': checklistItem['cm_check_list_site_resp_id'] ?? 
                                 checklistItem['cmCheckListSiteRespId'] ?? 
                                 0, // 0 for new items
        'cmCheckListMstId': checklistMstId ?? 0,
        'cmItemType': cmItemType.toString(),
        'checklistDesc': checklistItem['checklist_desc'] ?? 
                        checklistItem['checklistDesc'] ?? 
                        '',
        'resp': respValue ?? (respType == 'CHECKBOX_NUMERIC' || respType == 'CHECKBOX_TEXT' ? '0' : null),
        'clOrder': checklistItem['cl_order'] ?? 
                  checklistItem['clOrder'] ?? 
                  0,
        'longitude': location.longitude.toString(),
        'latitude': location.latitude.toString(),
        'isActive': true,
        'remarks': checklistItem['remarks']?.toString() ?? '',
        'cmCheckListSiteRespImagesList': imageList,
      };
      
      // Add numeric_value for CHECKBOX_NUMERIC if present
      if (respType == 'CHECKBOX_NUMERIC') {
        final numericValue = checklistItem['numeric_value'] ?? 
                            checklistItem['numericValue'] ??
                            checklistItem['resp_numeric'];
        if (numericValue != null) {
          transformedItem['numericValue'] = numericValue.toString();
        }
      }
      
      // Add impacted items for DYNAMIC_DROPDOWN / MULTI_DYNAMIC_DROPDOWN, and for CHECKBOX_NUMERIC / CHECKBOX_TEXT
      // when this parent row has impacted data (same payload shape as dynamic dropdown).
      final bool attachImpactedListToRow = respType == 'DYNAMIC_DROPDOWN' ||
          respType == 'MULTI_DYNAMIC_DROPDOWN' ||
          (finalHasImpactedItems &&
              (respType == 'CHECKBOX_NUMERIC' || respType == 'CHECKBOX_TEXT'));
      if (attachImpactedListToRow) {
        final transformedImpactedItems = <Map<String, dynamic>>[];
        List<Map<String, dynamic>> impactedItemsForThisParent = [];
        
        Logger.infoLog('[CM] Processing impacted list for checklist row - respType: $respType, mstId: $checklistMstId, checklistDesc: $checklistDesc, total impacted items in list: ${_impactedItemList.length}');
        
        // Primary check: Use grouped impacted items
        if (checklistMstId != null && impactedItemsByParentMstId.containsKey(checklistMstId)) {
          impactedItemsForThisParent = impactedItemsByParentMstId[checklistMstId]!;
          Logger.infoLog('[CM] Found ${impactedItemsForThisParent.length} impacted items in primary grouping for mstId: $checklistMstId');
        } else {
          // Fallback: Search through all impacted items to find ones with matching parent ID
          Logger.infoLog('[CM] Primary grouping failed for mstId: $checklistMstId ($checklistDesc), trying fallback search through ${_impactedItemList.length} impacted items');
          
          // Get the subItemType from checklist item for additional matching
          final checklistSubItemType = checklistItem['sub_item_type']?.toString() ?? 
                                     checklistItem['subItemType']?.toString() ?? '';
          final checklistCmItemType = checklistItem['cmItemType']?.toString() ?? 
                                    checklistItem['item_type']?.toString() ?? '';
          // Use the calculated cmItemType (which is what gets sent to API)
          final calculatedCmItemType = cmItemType.toString();
          
          Logger.infoLog('[CM] Looking for impacted items matching - mstId: $checklistMstId, subItemType: $checklistSubItemType, cmItemType: $checklistCmItemType, calculatedCmItemType: $calculatedCmItemType');
          
          for (var impactedItem in _impactedItemList) {
            final childItemResponses = impactedItem['childItemResponses'] as List<dynamic>? ?? 
                                       impactedItem['child_item_responses'] as List<dynamic>? ?? [];
            
            // Get impacted item's type info
            final impactedItemType = impactedItem['cmItemType']?.toString() ?? 
                                    impactedItem['item_type']?.toString() ?? '';
            final impactedSubItemType = impactedItem['subItemType']?.toString() ?? 
                                       impactedItem['sub_item_type']?.toString() ?? '';
            final impactedMfgSerialNo = impactedItem['mfgSerialNo']?.toString() ?? '';
            
            Logger.infoLog('[CM] Checking impacted item - mfgSerialNo: $impactedMfgSerialNo, cmItemType: $impactedItemType, subItemType: $impactedSubItemType, has ${childItemResponses.length} child responses');
            
            bool foundMatch = false;
            
            // First try: Match by parent ID in child responses (if child responses exist)
            if (childItemResponses.isNotEmpty) {
              for (var childResponse in childItemResponses) {
                if (childResponse is Map<String, dynamic>) {
                  final parentMstId = childResponse['parentCmCheckListMstId'] as int? ?? 
                                    childResponse['parent_cm_check_list_mst_id'] as int?;
                  Logger.infoLog('[CM] Child response parent IDs - parentCmCheckListMstId: ${childResponse['parentCmCheckListMstId']}, parent_cm_check_list_mst_id: ${childResponse['parent_cm_check_list_mst_id']}');
                  
                  if (parentMstId != null && parentMstId != 0 && parentMstId == checklistMstId) {
                    foundMatch = true;
                    Logger.infoLog('[CM] ✅ Matched by parent ID: $parentMstId == $checklistMstId');
                    break;
                  }
                }
              }
            } else {
              Logger.infoLog('[CM] Impacted item has no child responses, will try type matching');
            }
            
            // Second try: Match by subItemType or cmItemType if parent ID didn't match
            // Use case-insensitive matching and trim whitespace
            if (!foundMatch) {
              final normalizedChecklistSubItemType = checklistSubItemType.trim().toLowerCase();
              final normalizedCalculatedCmItemType = calculatedCmItemType.trim().toLowerCase();
              final normalizedImpactedSubItemType = impactedSubItemType.trim().toLowerCase();
              final normalizedImpactedItemType = impactedItemType.trim().toLowerCase();
              
              if (normalizedChecklistSubItemType.isNotEmpty) {
                if (normalizedImpactedSubItemType == normalizedChecklistSubItemType || 
                    normalizedImpactedItemType == normalizedChecklistSubItemType ||
                    normalizedImpactedSubItemType.contains(normalizedChecklistSubItemType) ||
                    normalizedImpactedItemType.contains(normalizedChecklistSubItemType)) {
                  foundMatch = true;
                  Logger.infoLog('[CM] ✅ Matched by subItemType: "$impactedSubItemType"/"$impactedItemType" == "$checklistSubItemType"');
                }
              }
              
              if (!foundMatch && normalizedCalculatedCmItemType.isNotEmpty) {
                if (normalizedImpactedItemType == normalizedCalculatedCmItemType || 
                    normalizedImpactedSubItemType == normalizedCalculatedCmItemType ||
                    normalizedImpactedItemType.contains(normalizedCalculatedCmItemType) ||
                    normalizedImpactedSubItemType.contains(normalizedCalculatedCmItemType)) {
                  foundMatch = true;
                  Logger.infoLog('[CM] ✅ Matched by cmItemType: "$impactedItemType"/"$impactedSubItemType" == "$calculatedCmItemType"');
                }
              }
            }
            
            if (foundMatch) {
              // Check if we already added this impacted item
              if (!impactedItemsForThisParent.any((item) => 
                item['mfgSerialNo'] == impactedItem['mfgSerialNo'])) {
                impactedItemsForThisParent.add(impactedItem);
                Logger.infoLog('[CM] Added impacted item to list - mfgSerialNo: $impactedMfgSerialNo');
              }
            }
          }
          
          if (impactedItemsForThisParent.isNotEmpty) {
            Logger.infoLog('[CM] Fallback search found ${impactedItemsForThisParent.length} impacted items for mstId: $checklistMstId ($checklistDesc)');
          } else {
            Logger.errorLog('[CM] ❌ No impacted items found in fallback search for mstId: $checklistMstId ($checklistDesc)');
            Logger.errorLog('[CM] Available impacted items in list: ${_impactedItemList.map((item) => '${item['mfgSerialNo']} (${item['cmItemType']}/${item['subItemType']})').toList()}');
            
            // Detailed debug: Show full structure of first few impacted items
            if (_impactedItemList.isNotEmpty) {
              Logger.errorLog('[CM] Detailed structure of first impacted item:');
              final firstItem = _impactedItemList.first;
              Logger.errorLog('[CM] Keys: ${firstItem.keys.toList()}');
              Logger.errorLog('[CM] mfgSerialNo: ${firstItem['mfgSerialNo']}');
              Logger.errorLog('[CM] cmItemType: ${firstItem['cmItemType']}');
              Logger.errorLog('[CM] subItemType: ${firstItem['subItemType']}');
              Logger.errorLog('[CM] childItemResponses: ${firstItem['childItemResponses']}');
              Logger.errorLog('[CM] child_item_responses: ${firstItem['child_item_responses']}');
              if (firstItem['childItemResponses'] != null || firstItem['child_item_responses'] != null) {
                final childResponses = firstItem['childItemResponses'] as List<dynamic>? ?? 
                                      firstItem['child_item_responses'] as List<dynamic>? ?? [];
                if (childResponses.isNotEmpty) {
                  final firstChild = childResponses.first;
                  if (firstChild is Map) {
                    Logger.errorLog('[CM] First child response keys: ${firstChild.keys.toList()}');
                    Logger.errorLog('[CM] First child parent IDs: parentCmCheckListMstId=${firstChild['parentCmCheckListMstId']}, parent_cm_check_list_mst_id=${firstChild['parent_cm_check_list_mst_id']}');
                  } else {
                    Logger.errorLog('[CM] First child response is not a map: ${firstChild.runtimeType}');
                  }
                }
              }
            }
          }
        }
        
        // Transform the impacted items
        for (var impactedItem in impactedItemsForThisParent) {
          final transformedItemsList = _transformImpactedItemToApiFormat(impactedItem, location);
          transformedImpactedItems.addAll(transformedItemsList);
        }
        
        Logger.infoLog('[CM] Added ${transformedImpactedItems.length} transformed impacted items to checklist item with mstId: $checklistMstId');
        
        // Always include cmImpactedItemList for DYNAMIC_DROPDOWN items (even if empty)
          transformedItem['cmImpactedItemList'] = transformedImpactedItems;
      }
      
      transformedList.add(transformedItem);
    }
    
    Logger.infoLog('[CM] Transformed ${transformedList.length} checklist items for API');
    return transformedList;
  }
  
  /// Transform a single impacted item to API format
  /// Each child response becomes a separate impacted item entry
  List<Map<String, dynamic>> _transformImpactedItemToApiFormat(
    Map<String, dynamic> impactedItem,
    LocationModel location,
  ) {
    final now = DateTime.now();
    final transformedItems = <Map<String, dynamic>>[];
    
    // Get base impacted item info
    final itemInstanceId = impactedItem['itemInstanceId'] ?? 
                           impactedItem['item_instance_id'] ?? 0;
    final mfgSerialNo = impactedItem['mfgSerialNo']?.toString() ?? 
                       impactedItem['mfg_serial_no']?.toString() ?? '';
    final nexgenSerialNo = impactedItem['nexgenSerialNo']?.toString() ?? 
                         impactedItem['nexgen_serial_no']?.toString() ?? '';
    final cmItemType = impactedItem['cmItemType']?.toString() ?? 
                     impactedItem['cm_item_type']?.toString() ?? '';
    final subItemType = impactedItem['subItemType']?.toString() ?? 
                      impactedItem['sub_item_type']?.toString() ?? '';
    final checklistRef = impactedItem['checklistRef']?.toString() ?? 
                        impactedItem['checklist_ref']?.toString() ?? '';
    
    // Transform childItemResponses - each becomes a separate impacted item
    final childItemResponses = impactedItem['childItemResponses'] as List<dynamic>? ?? 
                              impactedItem['child_item_responses'] as List<dynamic>? ?? [];
    
    // If there are no child responses (e.g., impacted_item_check_list is null),
    // create a single impacted item entry with dependent images
    if (childItemResponses.isEmpty) {
      // Get dependent images from the impacted item
      final dependentImages = impactedItem['dependent_images'] as List<dynamic>? ?? [];
      
      final transformedImages = <Map<String, dynamic>>[];
      for (var imageData in dependentImages) {
        if (imageData is Map<String, dynamic>) {
          final photoIdValue = imageData['photoId'] ?? imageData['photo_id'];
          final photoTakenTs = imageData['photoTakenTs']?.toString() ?? 
                             imageData['photo_taken_ts']?.toString();
          
          final formattedPhotoTakenTs = photoTakenTs != null 
              ? _formatDateStringForApi(photoTakenTs)
              : _formatDateForApi(now);
          
          // Convert photoId to int
          int photoIdInt = 0;
          if (photoIdValue != null) {
            if (photoIdValue is int) {
              photoIdInt = photoIdValue;
            } else if (photoIdValue is String) {
              photoIdInt = int.tryParse(photoIdValue) ?? 0;
            }
          }
          
          transformedImages.add({
            'cclsriId': 0,
            'photoId': photoIdInt,
            'photoTakenTs': formattedPhotoTakenTs,
            'isActive': true,
            'remarks': imageData['remarks']?.toString() ?? 'string',
          });
        }
      }
      
      // Create a single impacted item entry (no child items, just the serial number and images)
      final transformedItem = {
        'cmImpactedItemId': 0,
        'itemInstanceId': itemInstanceId,
        'mfgSerialNo': mfgSerialNo,
        'nexgenSerialNo': nexgenSerialNo,
        'cmItemType': cmItemType,
        'subItemType': subItemType,
        'resp': null, // No response since there are no child items
        'checklistDesc': '', // No checklist desc since there are no child items
        'clOrder': 0,
        'cmCheckListMstId': 0, // No child mstId since there are no child items
        'checklistRef': checklistRef,
        'isActive': true,
        'remarks': impactedItem['remarks']?.toString() ?? 'string',
        'cmCheckListSiteRespImagesList': transformedImages,
      };
      
      transformedItems.add(transformedItem);
      Logger.infoLog('[CM] Created impacted item entry without child responses (for dependent images only)');
      return transformedItems;
    }
    
    for (var childResponse in childItemResponses) {
      if (childResponse is Map<String, dynamic>) {
        final childResp = childResponse['resp']?.toString() ?? '';
        final checklistDesc = childResponse['checklistDesc']?.toString() ?? 
                             childResponse['checklist_desc']?.toString() ?? '';
        // Use the child's actual cmCheckListMstId (not the parent's)
        final cmCheckListMstId = childResponse['cmCheckListMstId'] as int? ?? 
                                childResponse['cm_check_list_mst_id'] as int? ?? 0;
        final clOrder = childResponse['clOrder'] as int? ?? 
                       childResponse['cl_order'] as int? ?? 0;
        
        // Transform response images
        final responseImages = childResponse['responseImages'] as List<dynamic>? ?? 
                              childResponse['response_images'] as List<dynamic>? ?? [];
        
        final transformedImages = <Map<String, dynamic>>[];
        for (var imageData in responseImages) {
          if (imageData is Map<String, dynamic>) {
            final photoIdValue = imageData['photoId'] ?? imageData['photo_id'];
            final photoTakenTs = imageData['photoTakenTs']?.toString() ?? 
                               imageData['photo_taken_ts']?.toString();
            
            final formattedPhotoTakenTs = photoTakenTs != null 
                ? _formatDateStringForApi(photoTakenTs)
                : _formatDateForApi(now);
            
            // Convert photoId to int
            int photoIdInt = 0;
            if (photoIdValue != null) {
              if (photoIdValue is int) {
                photoIdInt = photoIdValue;
              } else if (photoIdValue is String) {
                photoIdInt = int.tryParse(photoIdValue) ?? 0;
              }
            }
            
            transformedImages.add({
              'cclsriId': 0,
              'photoId': photoIdInt,
              'photoTakenTs': formattedPhotoTakenTs,
              'isActive': true,
              'remarks': imageData['remarks']?.toString() ?? 'string',
            });
          }
        }
        
        // Build the transformed impacted item (one per child response)
        final transformedItem = {
          'cmImpactedItemId': 0,
          'itemInstanceId': itemInstanceId,
          'mfgSerialNo': mfgSerialNo,
          'nexgenSerialNo': nexgenSerialNo,
          'cmItemType': cmItemType,
          'subItemType': subItemType,
          'resp': childResp,
          'checklistDesc': checklistDesc,
          'clOrder': clOrder,
          'cmCheckListMstId': cmCheckListMstId,
          'checklistRef': checklistRef,
          'isActive': true,
          'remarks': impactedItem['remarks']?.toString() ?? 'string',
          'cmCheckListSiteRespImagesList': transformedImages,
        };
        
        transformedItems.add(transformedItem);
      }
    }
    
    return transformedItems;
  }

  /// Validate all required fields (except checklist)
  /// Returns true if all validations pass, false otherwise
  bool _validateRequiredFields() {
    final errors = <String>[];
    
    // Site selection - always required
    if (_selectedSite == null) {
      errors.add('Please select a site');
    }
    
    // Equipment type - always required
    if (_selectedEquipmentType.isEmpty) {
      errors.add('Please select an equipment type');
    }
    
    // Category (responsible_party) - always required
    if (controllers['responsible_party']!.text.trim().isEmpty) {
      errors.add('Category is required');
    }
    
  
    
    // OEM Ticket ID - required only when Category is 'OEM'
    if (controllers['responsible_party']!.text.trim() == 'OEM' &&
        controllers['oem_ticket_id']!.text.trim().isEmpty) {
      errors.add('OEM Ticket ID is required when Category is OEM');
    }
    
    // Priority - always required
    if (controllers['priority']!.text.trim().isEmpty) {
      errors.add('Priority is required');
    }
    
    // Fault Description - always required
    final faultDescriptionController = controllers['fault_description'];
    if (faultDescriptionController == null) {
      Logger.errorLog('[CM] fault_description controller is null!');
      errors.add('Fault Description is required');
    } else {
      final faultDescription = faultDescriptionController.text.trim();
      Logger.infoLog('[CM] Validating Fault Description - value: "$faultDescription", isEmpty: ${faultDescription.isEmpty}');
      if (faultDescription.isEmpty) {
        errors.add('Fault Description is required');
      }
    }
    
    // Scope of Ticket - always required
    if (controllers['scope_of_ticket']!.text.trim().isEmpty) {
      errors.add('Scope of Ticket is required');
    }
    
    // Action Taken - required only in edit/view mode
    if (widget.mode != CMScreenModeEnum.create) {
      if (controllers['action_taken']!.text.trim().isEmpty) {
        errors.add('Action Taken is required');
      }
    }
    
    // RCA - required only in edit/view mode
    if (widget.mode != CMScreenModeEnum.create) {
      if (controllers['rca']!.text.trim().isEmpty) {
        errors.add('RCA is required');
      }
    }
    
   
    
    // Edit/View mode specific validations
    if (_resolvedMode == CMScreenModeEnum.edit || _resolvedMode == CMScreenModeEnum.view) {
      // OEM Representative - required only when Category is OEM
      if (controllers['responsible_party']!.text.trim().toUpperCase() == 'OEM') {
        if (controllers['oem_representative']!.text.trim().isEmpty) {
          errors.add('OEM Representative is required');
        }
        
        // OEM Representative Contact - required only when Category is OEM
        if (controllers['oem_representative_contact']!.text.trim().isEmpty) {
          errors.add('OEM Representative Contact is required');
        }
      }
      
      // Photo validations for edit mode
      if (_resolvedMode == CMScreenModeEnum.edit) {
        final responsibleParty = controllers['responsible_party']!.text.trim().toUpperCase();
        
        // If responsibleParty is "OEM", Identification, FSR and Time Stamp Photo are required
        if (responsibleParty == 'OEM') {
          // Check Identification Photo
          if (identificationPhoto == null && 
              (identificationPhotoByteData.isEmpty || 
               _originalIdentificationPhotoId == null || 
               _originalIdentificationPhotoId.toString().trim().isEmpty)) {
            errors.add('Identification is required when Category is OEM');
          }

          if (_fsrAttachments.isEmpty &&
              (_fsrAttachmentId == null || _fsrAttachmentId == 0)) {
            errors.add('FSR is required when Category is OEM');
          }
          
          // Check Time Stamp Photo
          if (timestampPhoto == null && 
              (timestampPhotoByteData.isEmpty || 
               _originalTimestampPhotoId == null || 
               _originalTimestampPhotoId.toString().trim().isEmpty)) {
            errors.add('Time Stamp Photo is required when Category is OEM');
          }
        }
        
        // If responsibleParty is "SELF", only Time Stamp Photo is required
        if (responsibleParty == 'SELF') {
          // Check Time Stamp Photo
          if (timestampPhoto == null && 
              (timestampPhotoByteData.isEmpty || 
               _originalTimestampPhotoId == null || 
               _originalTimestampPhotoId.toString().trim().isEmpty)) {
            errors.add('Time Stamp Photo is required when Category is Self');
          }
        }
      }
    }
    
    // Show error message if validation fails
    if (errors.isNotEmpty) {
      Logger.errorLog('[CM] Validation failed with ${errors.length} error(s)');
      for (var i = 0; i < errors.length; i++) {
        Logger.errorLog('[CM] Error ${i + 1}: ${errors[i]}');
      }
      
      // Show all errors in a snackbar (more visible than toast)
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Please fill all required fields:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                ...errors.map((error) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('• $error'),
                )),
              ],
            ),
            duration: const Duration(seconds: 5),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      
      // Also show first error in toast for immediate feedback
      Toastbar.showErrorToastbar(
        errors.first,
        context,
      );
      
      return false;
    }
    
    Logger.infoLog('[CM] All validations passed');
    return true;
  }

  Future<void> _submitAction({
    required bool validateMandatory,
    required bool forceCloseStatus,
    bool shouldNavigate = true,
  }) async {
    // Prevent duplicate submissions
    if (_isSubmitting) {
      Logger.infoLog('[CM] Submission already in progress - ignoring duplicate call');
      return;
    }
    
    Logger.infoLog(
      '[CM] _submitAction called - mode: ${widget.mode}, validateMandatory: $validateMandatory, forceCloseStatus: $forceCloseStatus',
    );

    if (validateMandatory) {
      final isValid = _validateRequiredFields();
      Logger.infoLog('[CM] Validation result: $isValid');

      if (!isValid) {
        Logger.errorLog('[CM] Validation failed - stopping submission');
        return;
      }
    }

    if (forceCloseStatus) {
      _currentStatusController.text = 'CLOSED';
    }

    // Set submitting flag
    _isSubmitting = true;
    
    try {
    if (_resolvedMode == CMScreenModeEnum.create) {
      await _submitFormData(
        shouldNavigate: shouldNavigate,
        forceCloseStatus: forceCloseStatus,
      );
    } else if (_resolvedMode == CMScreenModeEnum.edit) {
      await _editFormData(
        shouldNavigate: shouldNavigate,
        forceCloseStatus: forceCloseStatus,
      );
      }
    } finally {
      // Reset submitting flag
      _isSubmitting = false;
    }
  }

  Future<void> _save({bool shouldNavigate = true}) async {
    await _submitAction(
      validateMandatory: false,
      forceCloseStatus: false,
      shouldNavigate: shouldNavigate,
    );
  }

  Future<void> _saveAndClose({bool shouldNavigate = true}) async {
    await _submitAction(
      validateMandatory: true,
      forceCloseStatus: true,
      shouldNavigate: shouldNavigate,
    );
  }

  Future<void> _editFormData({
    bool shouldNavigate = true,
    bool forceCloseStatus = false,
  }) async {
    try {
      LoaderWidget.showLoader(context);
      if (cmSiteReqId == null) {
        return;
      }
      
      // Check internet connectivity
      final isConnected = await ConnectivityHelper.isConnected();
      Logger.infoLog("CM form edit submission - Connected: $isConnected");
      
      final requestData = <String, dynamic>{};
      requestData['cm_site_req_id'] = cmSiteReqId;
      
      // Add all controller fields
      // This includes:
      // - scope_of_ticket: from "Scope of Ticket" dropdown
      // - fault_description: from "Fault Description" field
      // - responsible_party: from "Category" dropdown
      for (var entry in controllers.entries) {
        requestData[entry.key] = entry.value.text;
      }
      _nullifyEmptyCmTextFields(requestData);
      
      // Explicitly ensure these key fields are set and sent in UPPERCASE
      requestData['scope_of_ticket'] = controllers['scope_of_ticket']!.text.trim().toUpperCase();
      requestData['fault_description'] = controllers['fault_description']!.text;
      requestData['responsible_party'] = controllers['responsible_party']!.text.trim().toUpperCase(); // Category
      requestData['priority'] = controllers['priority']!.text.trim().toUpperCase();
      requestData['status'] = forceCloseStatus ? 'CLOSED' : 'OPEN';
      _applyOemTicketIdToRequest(requestData);
      
      // Set OEM Representative Contact with correct key for edit mode
      if (controllers['oem_representative_contact']!.text.trim().isNotEmpty) {
        requestData['oemRepresentativeContactNo'] = controllers['oem_representative_contact']!.text;
      }
      
      // Set assigned_to based on responsible_party
      if (controllers['responsible_party']!.text.trim().toUpperCase() == 'OEM') {
        requestData['assigned_to'] = _selectedSite!.oemId;
      } else if (controllers['responsible_party']!.text.trim().toUpperCase() == 'SELF') {
        requestData['assigned_to'] = _selectedSite!.selfId;
      }
      
      // Set equipment type flags
      requestData['isDg'] = _selectedEquipmentType == 'DG';
      requestData['isBattery'] = _selectedEquipmentType == 'BATTERY';
      requestData['isCcu'] = _selectedEquipmentType == 'CCU';
      requestData['isSmps'] = _selectedEquipmentType == 'SMPS';
      requestData['isSolar'] = _selectedEquipmentType == 'SOLAR';
      
      // Set site information
      if (_selectedSite != null) {
        requestData['site_id'] = _selectedSite!.siteId;
        requestData['site_name'] = _selectedSite!.siteName;
        requestData['site_code'] = _selectedSite!.siteCode;
        requestData['entity_id'] = _selectedSite!.entityId;
        requestData['circle'] = _selectedSite!.circleStateName;
        requestData['cluster'] = _selectedSite!.clusterDistrictName;
        requestData['client'] = _selectedSite!.clientName ?? '';
        requestData['assigned_to_name'] = controllers['responsible_party']!.text.trim().toUpperCase() == 'OEM'
            ? _selectedSite!.oem
            : _selectedSite!.self;
      }
      
      requestData['is_active'] = true;
      requestData['application_type'] = 'Mobile';
      requestData['applicationType'] = 'Mobile';
      
      // Set dates (if closure_date is provided, calculate noOfDays)
      if (controllers['closure_date']!.text.isNotEmpty) {
        try {
          final closureDate = _parseFlexibleDate(controllers['closure_date']!.text);
          if (closureDate == null) {
            throw FormatException('Invalid closure date');
          }
          if (_isFutureDate(closureDate)) {
            if (!mounted) return;
            Toastbar.showErrorToastbar(
              "Closure date cannot be a future date.",
              context,
            );
            return;
          }
          final now = DateTime.now();
          final daysDifference = closureDate.difference(now).inDays;
          requestData['end_dt'] = _formatDateForApi(closureDate);
          requestData['endDt'] = _formatDateForApi(closureDate);
          requestData['no_of_days'] = daysDifference > 0 ? daysDifference : 0;
        } catch (e) {
          Logger.errorLog("Error parsing closure date: $e");
        }
      }
      requestData['start_dt'] = _formatDateForApi(DateTime.now());
      
      // Upload Identification, Time Stamp, FSR (UploadDocuments / local queue) before CM POST
      await _uploadAdditionalPhotos();
      
      // Add attachment IDs to requestData (after upload)
      Logger.infoLog('[CM] Adding IDs to requestData (edit mode) - Identification: $_originalIdentificationPhotoId, TimeStamp: $_originalTimestampPhotoId, FSR: $_fsrAttachmentId');
      
      if (_originalIdentificationPhotoId != null && _originalIdentificationPhotoId.toString().trim().isNotEmpty) {
        requestData['identificationImgId'] = _originalIdentificationPhotoId;
        Logger.infoLog('[CM] ✅ Added identificationImgId to requestData: $_originalIdentificationPhotoId');
        if (identificationPhoto != null) {
          final photoName = identificationPhoto!.path.split('/').last;
          requestData['identificationImgName'] = photoName;
        }
      } else {
        Logger.infoLog('[CM] ⚠️ identificationImgId is null or empty - not adding to requestData');
      }
      
      if (_originalTimestampPhotoId != null && _originalTimestampPhotoId.toString().trim().isNotEmpty) {
        requestData['timestampImgId'] = _originalTimestampPhotoId;
        Logger.infoLog('[CM] ✅ Added timestampImgId to requestData: $_originalTimestampPhotoId');
        if (timestampPhoto != null) {
          final photoName = timestampPhoto!.path.split('/').last;
          requestData['timestampImgName'] = photoName;
        }
      } else {
        Logger.infoLog('[CM] ⚠️ timestampImgId is null or empty - not adding to requestData');
      }

      if (_fsrAttachmentId != null && _fsrAttachmentId != 0) {
        requestData['fsrAttachmentId'] = _fsrAttachmentId;
        if (_fsrAttachmentName != null && _fsrAttachmentName!.trim().isNotEmpty) {
          requestData['fsrAttachmentName'] = _fsrAttachmentName;
        }
      } else if (_fsrAttachments.isNotEmpty) {
        requestData['fsrAttachmentName'] = _fsrAttachments.first.path.split('/').last;
      }
      
      // Upload all impacted item images first and replace LOCAL_IMAGE_ID with actual photo IDs
      await _uploadImpactedItemImagesAndUpdateIds(_impactedItemList);
      
      // Note: Impacted items are now nested inside cmCheckListSiteRespList items
      // No need to set them as a separate top-level field
      Logger.infoLog('[CM] Impacted items will be nested inside checklist items (edit mode)');
      final selectedCheckListData = _checklistData[_selectedEquipmentType];
      LocationModel? finalLocation;

      if (selectedCheckListData != null) {
        try {
          finalLocation = await LocationService.getCurrentLocation();
          DataTransformationHelper.updateMetadataInRequest(
            selectedCheckListData,
            finalLocation,
          );
          
          // Upload all checklist images first and replace LOCAL_IMAGE_ID with actual photo IDs
          await _uploadChecklistImagesAndUpdateIds(selectedCheckListData);
          
          // Transform checklist data to required format (with updated photo IDs)
          requestData['cm_check_list_site_resp_list'] = _transformChecklistDataToApiFormat(
            selectedCheckListData,
            finalLocation,
          );
        } catch (e) {
          Logger.infoLog('Error getting location: $e');
          if (!mounted) return;
          Toastbar.showErrorToastbar(
            ExceptionConstants.UNABLE_TO_GET_LOCATION,
            context,
          );
          return;
        }
      }
      
      Logger.infoLog("requestData: $requestData");

      if (isConnected) {
        // Online mode: Process and submit
        try {
          await _handleOnlineEditSubmission(
            requestData,
            shouldNavigate: shouldNavigate,
          );
        } catch (e) {
          Logger.errorLog("Online edit submission failed: $e");
          // Fallback to offline mode
          if (finalLocation != null) {
            await _handleOfflineEditSubmission(
              requestData,
              finalLocation,
              shouldNavigate: shouldNavigate,
            );
          }
        }
      } else {
        // Offline mode: Save to pending requests
        if (finalLocation != null) {
          await _handleOfflineEditSubmission(
            requestData,
            finalLocation,
            shouldNavigate: shouldNavigate,
          );
        } else {
          // Get location if not already available
          try {
            finalLocation = await LocationService.getCurrentLocation();
            await _handleOfflineEditSubmission(
              requestData,
              finalLocation,
              shouldNavigate: shouldNavigate,
            );
          } catch (e) {
            Logger.errorLog('Error getting location for offline submission: $e');
            if (!mounted) return;
            Toastbar.showErrorToastbar(
              ExceptionConstants.UNABLE_TO_GET_LOCATION,
              context,
            );
          }
        }
      }
    } finally {
      LoaderWidget.hideLoader();
    }
  }

  /// Avoid [DataTransformationHelper.convertKeysToCamelCase] merging snake + camel into one key twice with wrong winner.
  void _stripDuplicateFsrKeysBeforeCamelCase(Map<String, dynamic> requestData) {
    if (requestData.containsKey('fsrAttachmentId')) {
      requestData.remove('fsr_attachment_id');
    }
    if (requestData.containsKey('fsrAttachmentName')) {
      requestData.remove('fsr_attachment_name');
    }
  }

  Future<void> _handleOnlineEditSubmission(
    Map<String, dynamic> requestData, {
    bool shouldNavigate = true,
  }) async {
    try {
      _stripDuplicateFsrKeysBeforeCamelCase(requestData);
      Map<String, dynamic> processedData =
          DataTransformationHelper.convertKeysToCamelCase(requestData);
      _ensureOemTicketIdOnApiPayload(processedData);
      
      Logger.infoLog('[CM] Final processedData keys: ${processedData.keys.toList()}');
      Logger.infoLog('[CM] oemTicketId in payload: ${processedData['oemTicketId']}');
      
      // Impacted items are now nested inside cmCheckListSiteRespList, so no need for separate top-level field
      // Remove any top-level impacted item list if it exists
      processedData.remove('cmImpactedItemList');
      processedData.remove('CmImpactedItemList');
      Logger.infoLog('[CM] Removed top-level impacted item list - they are now nested inside checklist items');
      
      await ServiceLocator().cmRepository.createCorrectiveMaintenance(
        processedData,
      );

      Logger.debugLog(" processedData: $processedData");

      if (!mounted) return;
      Toastbar.showSuccessToastbar("Form Submitted Successfully", context);
      if (shouldNavigate) {
        navigateBackOrToHome(
          context,
          targetContext: widget.parentContext ?? context,
        );
      }
    } catch (e) {
      Logger.errorLog("Error in online edit submission: $e");
      rethrow;
    }
  }

  Future<void> _handleOfflineEditSubmission(
    Map<String, dynamic> requestData,
    LocationModel location, {
    bool shouldNavigate = true,
  }) async {
    try {
      Logger.infoLog("Saving CM edit form data offline");
      
      // Add the two new photo IDs (Identification and Time Stamp)
      if (_originalIdentificationPhotoId != null && _originalIdentificationPhotoId.toString().trim().isNotEmpty) {
        requestData['identificationImgId'] = _originalIdentificationPhotoId;
      }
      
      if (_originalTimestampPhotoId != null && _originalTimestampPhotoId.toString().trim().isNotEmpty) {
        requestData['timestampImgId'] = _originalTimestampPhotoId;
      }

      // FSR: uploaded on pick; retry UploadDocuments only if no id yet (same as _uploadAdditionalPhotos).
      if ((_fsrAttachmentId == null ||
              _fsrAttachmentId.toString().trim().isEmpty ||
              _fsrAttachmentId == 0) &&
          _fsrAttachments.isNotEmpty) {
        final id = await _uploadDocumentWithFallback(_fsrAttachments.first);
        final s = id?.toString().trim() ?? '';
        if (s.isNotEmpty) {
          _fsrAttachmentId = s;
          _fsrAttachmentName = _fsrAttachments.first.path.split('/').last;
        }
      }
      if (_fsrAttachmentId != null &&
          _fsrAttachmentId.toString().trim().isNotEmpty &&
          _fsrAttachmentId != 0) {
        requestData['fsrAttachmentId'] = _fsrAttachmentId;
        requestData['fsrAttachmentName'] =
            _fsrAttachmentName ?? _fsrAttachments.first.path.split('/').last;
        if (_fsrAttachments.isNotEmpty) {
          final originalFile = _fsrAttachments.first;
          requestData['fsr_original_file_path'] = originalFile.path;
          requestData['fsr_original_file_name'] = originalFile.path.split('/').last;
        }
      }

      // Save to pending requests for sync when online
      final requestId = 'cm_edit_${cmSiteReqId}_${DateTime.now().millisecondsSinceEpoch}';
      final url = '/api/v1/mobile/correctiveMaintenance';
      final isSaved = await ServiceLocator().pendingRequestService.savePendingRequest(
        requestId: requestId,
        url: url,
        headers: {},
        jsonEncodedRequestData: jsonEncode([requestData]),
      );

      if (isSaved) {
        Logger.infoLog("CM edit data saved to pending requests successfully");
        
        if (!mounted) return;
        Toastbar.showSuccessToastbar(
          "Data saved offline. Will sync when online.",
          context,
        );
        if (shouldNavigate) {
          navigateBackOrToHome(
            context,
            targetContext: widget.parentContext ?? context,
          );
        }
      } else {
        throw Exception('Failed to save data to offline storage');
      }
    } catch (e) {
      Logger.errorLog("Error in offline edit submission: $e");
      if (!mounted) return;
      Toastbar.showErrorToastbar(
        "Failed to save form edit offline: $e",
        context,
      );
    }
  }

  Future<void> _submitFormData({
    bool shouldNavigate = true,
    bool forceCloseStatus = false,
  }) async {
    try {
      LoaderWidget.showLoader(context);

      // Check internet connectivity
      final isConnected = await ConnectivityHelper.isConnected();
      Logger.infoLog("CM form submission - Connected: $isConnected");

      final requestData = <String, dynamic>{};
      
      // Add all controller fields
      // This includes:
      // - scope_of_ticket: from "Scope of Ticket" dropdown
      // - fault_description: from "Fault Description" field
      // - responsible_party: from "Category" dropdown
      for (var entry in controllers.entries) {
        requestData[entry.key] = entry.value.text;
      }
      _nullifyEmptyCmTextFields(requestData);
      
      // Explicitly ensure these key fields are set and sent in UPPERCASE
      requestData['scope_of_ticket'] = controllers['scope_of_ticket']!.text.trim().toUpperCase();
      requestData['fault_description'] = controllers['fault_description']!.text;
      requestData['responsible_party'] = controllers['responsible_party']!.text.trim().toUpperCase(); // Category
      requestData['priority'] = controllers['priority']!.text.trim().toUpperCase();
      requestData['status'] = forceCloseStatus ? 'CLOSED' : 'OPEN';
      _applyOemTicketIdToRequest(requestData);
      
      // Set assigned_to based on responsible_party
      if (controllers['responsible_party']!.text.trim().toUpperCase() == 'OEM') {
        requestData['assigned_to'] = _selectedSite!.oemId;
      } else if (controllers['responsible_party']!.text.trim().toUpperCase() == 'SELF') {
        requestData['assigned_to'] = _selectedSite!.selfId;
      }
      
      // Set equipment type flags
      requestData['isDg'] = _selectedEquipmentType == 'DG';
      requestData['isBattery'] = _selectedEquipmentType == 'BATTERY';
      requestData['isCcu'] = _selectedEquipmentType == 'CCU';
      requestData['isSmps'] = _selectedEquipmentType == 'SMPS';
      requestData['isSolar'] = _selectedEquipmentType == 'SOLAR';
      
      // Set CM site request ID (0 for new, existing ID for edit)
      requestData['cm_site_req_id'] = cmSiteReqId ?? 0;
      
      // Set site information
      if (_selectedSite != null) {
        requestData['site_id'] = _selectedSite!.siteId;
        requestData['site_name'] = _selectedSite!.siteName;
        requestData['site_code'] = _selectedSite!.siteCode;
        requestData['entity_id'] = _selectedSite!.entityId;
        requestData['circle'] = _selectedSite!.circleStateName;
        requestData['cluster'] = _selectedSite!.clusterDistrictName;
        requestData['client'] = _selectedSite!.clientName ?? '';
        requestData['assigned_to_name'] = controllers['responsible_party']!.text.trim().toUpperCase() == 'OEM'
            ? _selectedSite!.oem
            : _selectedSite!.self;
      }
      
      requestData['is_active'] = true;
      requestData['application_type'] = 'Mobile';
      requestData['applicationType'] = 'Mobile';
      
      // Set dates (if closure_date is provided, calculate noOfDays)
      if (controllers['closure_date']!.text.isNotEmpty) {
        try {
          final closureDate = _parseFlexibleDate(controllers['closure_date']!.text);
          if (closureDate == null) {
            throw FormatException('Invalid closure date');
          }
          if (_isFutureDate(closureDate)) {
            if (!mounted) return;
            Toastbar.showErrorToastbar(
              "Closure date cannot be a future date.",
              context,
            );
            return;
          }
          final now = DateTime.now();
          final daysDifference = closureDate.difference(now).inDays;
          requestData['end_dt'] = _formatDateForApi(closureDate);
          requestData['endDt'] = _formatDateForApi(closureDate);
          requestData['no_of_days'] = daysDifference > 0 ? daysDifference : 0;
        } catch (e) {
          Logger.errorLog("Error parsing closure date: $e");
        }
      }
      requestData['start_dt'] = _formatDateForApi(DateTime.now());
      
      // Upload Identification, Time Stamp, FSR before CM POST
      await _uploadAdditionalPhotos();
      
      Logger.infoLog('[CM] Adding IDs to requestData (create mode) - Identification: $_originalIdentificationPhotoId, TimeStamp: $_originalTimestampPhotoId, FSR: $_fsrAttachmentId');
      
      if (_originalIdentificationPhotoId != null && _originalIdentificationPhotoId.toString().trim().isNotEmpty) {
        requestData['identificationImgId'] = _originalIdentificationPhotoId;
        Logger.infoLog('[CM] ✅ Added identificationImgId to requestData: $_originalIdentificationPhotoId');
        if (identificationPhoto != null) {
          final photoName = identificationPhoto!.path.split('/').last;
          requestData['identificationImgName'] = photoName;
        }
      } else {
        Logger.infoLog('[CM] ⚠️ identificationImgId is null or empty - not adding to requestData');
      }
      
      if (_originalTimestampPhotoId != null && _originalTimestampPhotoId.toString().trim().isNotEmpty) {
        requestData['timestampImgId'] = _originalTimestampPhotoId;
        Logger.infoLog('[CM] ✅ Added timestampImgId to requestData: $_originalTimestampPhotoId');
        if (timestampPhoto != null) {
          final photoName = timestampPhoto!.path.split('/').last;
          requestData['timestampImgName'] = photoName;
        }
      } else {
        Logger.infoLog('[CM] ⚠️ timestampImgId is null or empty - not adding to requestData');
      }

      if (_fsrAttachmentId != null && _fsrAttachmentId != 0) {
        requestData['fsrAttachmentId'] = _fsrAttachmentId;
        if (_fsrAttachmentName != null && _fsrAttachmentName!.trim().isNotEmpty) {
          requestData['fsrAttachmentName'] = _fsrAttachmentName;
        }
      } else if (_fsrAttachments.isNotEmpty) {
        requestData['fsrAttachmentName'] = _fsrAttachments.first.path.split('/').last;
      }
      
      // Upload all impacted item images first and replace LOCAL_IMAGE_ID with actual photo IDs
      await _uploadImpactedItemImagesAndUpdateIds(_impactedItemList);
      
      // Note: Impacted items are now nested inside cmCheckListSiteRespList items
      // No need to set them as a separate top-level field
      Logger.infoLog('[CM] Impacted items will be nested inside checklist items (create mode)');
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
        if (!mounted) return;
        Toastbar.showErrorToastbar(
          ExceptionConstants.UNABLE_TO_GET_LOCATION,
          context,
        );
        return;
      }
      
      // Upload all checklist images first and replace LOCAL_IMAGE_ID with actual photo IDs
      await _uploadChecklistImagesAndUpdateIds(selectedCheckListData);
      
      // Transform checklist data to required format (with updated photo IDs)
      requestData['cm_check_list_site_resp_list'] = _transformChecklistDataToApiFormat(
            selectedCheckListData,
        finalLocation,
          );
      Logger.infoLog("requestData: $requestData");

      if (isConnected) {
        // Online mode: Process images first, then submit
        try {
          await _handleOnlineSubmission(
            requestData,
            shouldNavigate: shouldNavigate,
          );
        } catch (e) {
          Logger.errorLog("Online submission failed: $e");
          // Fallback to offline mode
          await _handleOfflineSubmission(
            requestData,
            finalLocation,
            shouldNavigate: shouldNavigate,
          );
        }
      } else {
        // Offline mode: Save to pending requests
        await _handleOfflineSubmission(
          requestData,
          finalLocation,
          shouldNavigate: shouldNavigate,
        );
      }
    } finally {
      LoaderWidget.hideLoader();
    }
  }

  Future<void> _handleOnlineSubmission(
    Map<String, dynamic> requestData, {
    bool shouldNavigate = true,
  }) async {
    try {
      _stripDuplicateFsrKeysBeforeCamelCase(requestData);
      // Convert keys to camelCase for API
      Map<String, dynamic> processedData =
          DataTransformationHelper.convertKeysToCamelCase(requestData);
      _ensureOemTicketIdOnApiPayload(processedData);
      
      Logger.infoLog('[CM] Final processedData keys (create): ${processedData.keys.toList()}');
      Logger.infoLog('[CM] oemTicketId in payload: ${processedData['oemTicketId']}');
      // Impacted items are now nested inside cmCheckListSiteRespList, so no need for separate top-level field
      // Remove any top-level impacted item list if it exists
      processedData.remove('cmImpactedItemList');
      processedData.remove('CmImpactedItemList');
      Logger.infoLog('[CM] Removed top-level impacted item list - they are now nested inside checklist items (create)');
      
      // Create CM ticket first
      final response = await ServiceLocator().cmRepository.createCorrectiveMaintenance(processedData);
      
      if (response.containsKey('cmSiteReqId')) {
        final cmSiteReqId = response['cmSiteReqId'] as int;
        Logger.infoLog("CM ticket created with ID: $cmSiteReqId");
      }

      if (!mounted) return;
      Toastbar.showSuccessToastbar("Form Submitted Successfully", context);
      if (shouldNavigate) {
        navigateBackOrToHome(
          context,
          targetContext: widget.parentContext ?? context,
        );
      }
    } catch (e) {
      Logger.errorLog("Error in online submission: $e");
      rethrow;
    }
  }

  Future<void> _handleOfflineSubmission(
    Map<String, dynamic> requestData,
    LocationModel location, {
    bool shouldNavigate = true,
  }) async {
    try {
      Logger.infoLog("Saving CM form data offline");

      // Add the two new photo IDs (Identification and Time Stamp)
      Logger.infoLog('[CM] Checking additional photo IDs - Identification: $_originalIdentificationPhotoId, TimeStamp: $_originalTimestampPhotoId');
      
      if (_originalIdentificationPhotoId != null && _originalIdentificationPhotoId.toString().trim().isNotEmpty) {
        requestData['identificationImgId'] = _originalIdentificationPhotoId;
        Logger.infoLog('[CM] ✅ Added identificationImgId: $_originalIdentificationPhotoId');
        if (identificationPhoto != null) {
          final photoName = identificationPhoto!.path.split('/').last;
          requestData['identificationImgName'] = photoName;
        }
      } else {
        Logger.infoLog('[CM] ⚠️ identificationImgId is null or empty - photo may not have been uploaded');
      }
      
      if (_originalTimestampPhotoId != null && _originalTimestampPhotoId.toString().trim().isNotEmpty) {
        requestData['timestampImgId'] = _originalTimestampPhotoId;
        Logger.infoLog('[CM] ✅ Added timestampImgId: $_originalTimestampPhotoId');
        if (timestampPhoto != null) {
          final photoName = timestampPhoto!.path.split('/').last;
          requestData['timestampImgName'] = photoName;
        }
      } else {
        Logger.infoLog('[CM] ⚠️ timestampImgId is null or empty - photo may not have been uploaded');
      }

      // FSR: uploaded on pick; retry only if no id yet.
      if ((_fsrAttachmentId == null ||
              _fsrAttachmentId.toString().trim().isEmpty ||
              _fsrAttachmentId == 0) &&
          _fsrAttachments.isNotEmpty) {
        final id = await _uploadDocumentWithFallback(_fsrAttachments.first);
        final s = id?.toString().trim() ?? '';
        if (s.isNotEmpty) {
          _fsrAttachmentId = s;
          _fsrAttachmentName = _fsrAttachments.first.path.split('/').last;
        }
      }
      if (_fsrAttachmentId != null &&
          _fsrAttachmentId.toString().trim().isNotEmpty &&
          _fsrAttachmentId != 0) {
        requestData['fsrAttachmentId'] = _fsrAttachmentId;
        requestData['fsrAttachmentName'] =
            _fsrAttachmentName ?? _fsrAttachments.first.path.split('/').last;
        if (_fsrAttachments.isNotEmpty) {
          final originalFile = _fsrAttachments.first;
          requestData['fsr_original_file_path'] = originalFile.path;
          requestData['fsr_original_file_name'] = originalFile.path.split('/').last;
        }
      }
      if (!requestData.containsKey('is_active')) {
        requestData['is_active'] = true;
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
        if (!mounted) return;
        Toastbar.showSuccessToastbar(
          "Data saved offline. Will sync when online.",
          context,
        );
        if (shouldNavigate) {
          navigateBackOrToHome(
            context,
            targetContext: widget.parentContext ?? context,
          );
        }
      } else {
        throw Exception('Failed to save data to offline storage');
      }
    } catch (e) {
      Logger.errorLog("Error in offline submission: $e");
      if (!mounted) return;
      Toastbar.showErrorToastbar(
        "Failed to save form offline: $e",
        context,
      );
    }
  }

  void _showUnsavedChangesDialog() {
    if (_hasFormDataChanges) {
      showDialog(
        context: context,
        builder: (ctx) => UnsavedChangesDialog(
          siteAuditSchId: _selectedSite?.siteCode ?? '',
          section: "Corrective Maintenance",
          parentContext: widget.parentContext ?? context,
          onSaveAndExit: () async {
            await _save(shouldNavigate: false);
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