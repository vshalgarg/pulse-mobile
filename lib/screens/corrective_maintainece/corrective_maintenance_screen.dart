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
import 'package:app/utils/data_transformation_helper.dart';
import 'package:app/utils/logger.dart';
import 'package:app/utils/toastbar.dart';
import 'package:app/utils/connectivity_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../services/file_download_service.dart';
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
  final TextEditingController _cmTicketNoController = TextEditingController();
  final TextEditingController _infraEngineerNameController = TextEditingController();
  final TextEditingController _infraEngineerContactNoController = TextEditingController();
  final TextEditingController _clusterInchargeNameController = TextEditingController();
  final TextEditingController _clusterInchargeContactNoController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController();

  final TextEditingController _statusController = TextEditingController();
  final TextEditingController _remarksController = TextEditingController();

  // 👇 Dropdown selections
  CMSite? _selectedSite;
  String _selectedEquipmentType = "DG";

  int? cmSiteReqId;

  File? customerPhoto;
  String customerPhotoByteData = "";
  // Store original photo ID to reload if needed after submission
  dynamic _originalCustomerPhotoId;
  final List<File> _uploadedAttachments = [];
  final List<File> _remarksAttachments = [];
  
  // Store server attachment info (ID and filename)
  String? _customerAttachmentName;
  dynamic _customerAttachmentId;
  
  // Store remarks attachment info (for edit mode)
  String? _remarksAttachmentName;
  dynamic _remarksAttachmentId;

  // 👇 Dropdown options
  List<CMSite> _siteOptions = [];
  final List<String> _priorityOptions = ['Critical', 'Non Critical'];
  final List<String> _responsiblePartyOptions = ['OEM', 'Self'];
  final List<String> _natureOfFailureOptions = ['AMC', 'Paid', 'FOC'];
  final List<String> _scopeOfTicketOptions = ['AMC', 'Paid', 'FOC'];
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
      Map<String, dynamic> preloadedSite = Map<String, dynamic>.from(widget.preloadedSiteData!);
      
      // Handle nested data structure if present
      if (preloadedSite.containsKey('data') && preloadedSite['data'] is Map<String, dynamic>) {
        preloadedSite = Map<String, dynamic>.from(preloadedSite['data']);
      }

      // Try both camelCase and snake_case for cmSiteReqId
      cmSiteReqId = preloadedSite['cmSiteReqId'] ?? preloadedSite['cm_site_req_id'];
      CMSite site = CMSite(
        siteId: preloadedSite['site_id'] ?? 0,
        entityId: preloadedSite['entity_id'] ?? 0,
        siteCode: preloadedSite['site_code'] ?? '',
        siteName: preloadedSite['site_name'] ?? '',
        clusterDistrictId: preloadedSite['cluster_district_id'] ?? 0,
        clusterDistrictName: preloadedSite['cluster_district_name'] ?? preloadedSite['cluster'] ?? '',
        circleStateId: preloadedSite['circle_state_id'] ?? 0,
        circleStateName: preloadedSite['circle_state_name'] ?? preloadedSite['circle'] ?? '',
        clientId: preloadedSite['client_id'],
        clientName: preloadedSite['client_name']?.toString(),
        oem: preloadedSite['oem']?.toString(),
        oemId: preloadedSite['oem_id'],
        self: preloadedSite['assigned_to_name'] ?? preloadedSite['self'] ?? '',
        selfId: preloadedSite['assigned_to'] ?? preloadedSite['self_id'] ?? 0,
        infraEngineerName: preloadedSite['infra_engineer_name']?.toString() ?? preloadedSite['infraEngineerName']?.toString(),
        infraEngineerContactNo: preloadedSite['infra_engineer_contact_no']?.toString() ?? preloadedSite['infraEngineerContactNo']?.toString(),
        clusterInchargeName: preloadedSite['cluster_incharge_name']?.toString() ?? preloadedSite['clusterInchargeName']?.toString(),
        clusterInchargeContactNo: preloadedSite['cluster_incharge_contact_no']?.toString() ?? preloadedSite['clusterInchargeContactNo']?.toString(),
        category: preloadedSite['category']?.toString(),
      );
      _siteOptions = [site];
      _initializeTicketControllers(preloadedSite);
      _onSiteSelected(site);
    }
  }

  void _loadImages(Map<String, dynamic> preloadedSite) async {
    
    // Try both camelCase and snake_case for customer photo ID
    dynamic customerPhotoId = preloadedSite['customerPhotoId'] ?? preloadedSite['customer_photo_id'];
    // Store original photo ID to preserve it after form submission
    _originalCustomerPhotoId = customerPhotoId;
    
    if (customerPhotoId != null && customerPhotoId.toString().trim().isNotEmpty) {
      String? customerPhotoByteDataLocal;
      
      try {
        // First, check if image is already cached locally (works in offline mode)
        final cachedImage = await ServiceLocator()
            .imageUploadService
            .getImagesByServerId(customerPhotoId.toString());
        
        if (cachedImage != null && cachedImage.imageData != null) {
          // Image found in local cache - use it (works offline)
          Logger.infoLog('[CM] Customer photo found in local cache (offline mode supported)');
          customerPhotoByteDataLocal = cachedImage.imageData;
        } else {
          // Not in cache, check if we're online and try to download
          final isOnline = await ConnectivityHelper.isConnected();
          
          if (isOnline) {
            // Online: try to download from server and cache it
            Logger.infoLog('[CM] Customer photo not in cache, downloading from server (online mode)');
            
            // Use downloadImageUsingServerId which handles caching
            final uniqueId = await ServiceLocator()
                .imageUploadService
                .downloadImageUsingServerId(
                  customerPhotoId.toString(),
                  ActivityTypeEnum.correctiveMaintenance,
                  _selectedSite?.siteId.toString() ?? '',
                );
            
            if (uniqueId != null) {
              // Get the image data using the unique ID
              customerPhotoByteDataLocal = await ServiceLocator()
                  .imageUploadService
                  .getImageUsingUniqueId(uniqueId);
            }
          } else {
            // Offline and not in cache - cannot load image
            Logger.errorLog('[CM] Customer photo not in cache and device is offline - cannot load');
          }
        }
        
        // If we got image data (from cache or download), process it
        if (customerPhotoByteDataLocal != null && customerPhotoByteDataLocal.isNotEmpty) {
          File? imageFile = await Utils.buildImageFromBytesData(
            customerPhotoByteDataLocal,
          );
          customerPhoto = imageFile;
          setState(() {
            customerPhotoByteData = customerPhotoByteDataLocal!;
          });
        } else {
          Logger.errorLog('[CM] Failed to load customer photo: No data retrieved');
        }
      } catch (e) {
        Logger.errorLog('[CM] Error loading customer photo: $e');
      }
    }
    
    // Extract customer attachment info (only for edit/view mode, not create)
    if (widget.mode != CMScreenModeEnum.create) {
      // Try all possible field name variations for customer attachment ID (check camelCase first)
      dynamic customerAttachmentId = preloadedSite['customerAttachmentId'] ?? 
                                      preloadedSite['customer_attachment_id'] ??
                                      preloadedSite['customerAttachmenId']; // Handle typo variant
      
      // Convert to int if it's a string
      if (customerAttachmentId != null && customerAttachmentId is String && customerAttachmentId.trim().isNotEmpty) {
        try {
          customerAttachmentId = int.parse(customerAttachmentId.trim());
        } catch (e) {
          Logger.errorLog('[CM] Failed to parse attachment ID as int: $customerAttachmentId');
          customerAttachmentId = null;
        }
      }

      // Try all possible field name variations for attachment name (check typo variant first - it's in the JSON!)
      // Check all possible field variations with better null/empty handling
      dynamic customerAttachmentName;
      
      // First check the typo variant (customerAttachmenName - missing 't')
      if (preloadedSite.containsKey('customerAttachmenName')) {
        final value = preloadedSite['customerAttachmenName'];
        if (value != null && value.toString().trim().isNotEmpty) {
          customerAttachmentName = value;
        }
      }
      
      // Then check correct spelling if not found
      if (customerAttachmentName == null && preloadedSite.containsKey('customerAttachmentName')) {
        final value = preloadedSite['customerAttachmentName'];
        if (value != null && value.toString().trim().isNotEmpty) {
          customerAttachmentName = value;
        }
      }
      
      // Then check snake_case variant if still not found
      if (customerAttachmentName == null && preloadedSite.containsKey('customer_attachment_name')) {
        final value = preloadedSite['customer_attachment_name'];
        if (value != null && value.toString().trim().isNotEmpty) {
          customerAttachmentName = value;
        }
      }
      
      // Set customer attachment if ID is valid
      if (customerAttachmentId != null && customerAttachmentId != 0) {
        // If name is null or empty, use attachment ID as the name
        final nameToSet = (customerAttachmentName != null && customerAttachmentName.toString().trim().isNotEmpty) 
            ? customerAttachmentName.toString().trim() 
            : customerAttachmentId.toString(); // Use ID as name if name is not available
        
        Logger.infoLog('[CM] Setting customer attachment - ID: $customerAttachmentId, Name: $nameToSet');
        
        // Set state directly (same pattern as remarks attachment)
        setState(() {
          _customerAttachmentId = customerAttachmentId;
          _customerAttachmentName = nameToSet;
        });
      }
      
      // Load remarks data from cmRemarksList (for edit and view modes)
      final cmRemarksList = preloadedSite['cmRemarksList'] ?? preloadedSite['cm_remarks_list'];
      
      if (cmRemarksList != null && cmRemarksList is List && cmRemarksList.isNotEmpty) {
        // Get the latest/active remark (usually the last one)
        final latestRemark = cmRemarksList.last;
        
        final cmRemark = latestRemark['cmRemark'] ?? latestRemark['cm_remark'];
        dynamic cmAttachmentId = latestRemark['cmAttachmentId'] ?? latestRemark['cm_attachment_id'];
        final cmAttachmentName = latestRemark['cmAttachmentName'] ?? latestRemark['cm_attachment_name'];
        
        // Convert attachment ID to int if it's a string
        if (cmAttachmentId != null && cmAttachmentId is String && cmAttachmentId.toString().trim().isNotEmpty) {
          try {
            cmAttachmentId = int.parse(cmAttachmentId.toString().trim());
          } catch (e) {
            Logger.errorLog('[CM] Failed to parse remarks attachment ID as int: $cmAttachmentId');
            cmAttachmentId = null;
          }
        }
        
        setState(() {
          // Set remarks text (for edit mode only, view mode shows in CMRemarksShowWidget)
          if (widget.mode == CMScreenModeEnum.edit && 
              cmRemark != null && cmRemark.toString().trim().isNotEmpty) {
            _remarksController.text = cmRemark.toString().trim();
          }
          
          // Set remarks attachment info (for both edit and view modes)
          if (cmAttachmentId != null && cmAttachmentId != 0) {
            _remarksAttachmentId = cmAttachmentId;
            if (cmAttachmentName != null && cmAttachmentName.toString().trim().isNotEmpty) {
              _remarksAttachmentName = cmAttachmentName.toString().trim();
            } else {
              _remarksAttachmentName = null;
            }
          }
        });
      }
    }
  }

  /// Reload customer photo from server/cache to preserve it after form submission
  Future<void> _reloadCustomerPhoto(dynamic customerPhotoId) async {
    try {
      if (customerPhotoId == null || customerPhotoId.toString().trim().isEmpty) {
        return;
      }
      
      // First, check if image is already cached locally
      final cachedImage = await ServiceLocator()
          .imageUploadService
          .getImagesByServerId(customerPhotoId.toString());
      
      String? customerPhotoByteDataLocal;
      
      if (cachedImage != null && cachedImage.imageData != null) {
        // Image found in local cache - use it
        customerPhotoByteDataLocal = cachedImage.imageData;
      } else {
        // Not in cache, check if we're online and try to download
        final isOnline = await ConnectivityHelper.isConnected();
        
        if (isOnline) {
          // Use downloadImageUsingServerId which handles caching
          final uniqueId = await ServiceLocator()
              .imageUploadService
              .downloadImageUsingServerId(
                customerPhotoId.toString(),
                ActivityTypeEnum.correctiveMaintenance,
                _selectedSite?.siteId.toString() ?? '',
              );
          
          if (uniqueId != null) {
            // Get the image data using the unique ID
            customerPhotoByteDataLocal = await ServiceLocator()
                .imageUploadService
                .getImageUsingUniqueId(uniqueId);
          }
        }
      }
      
      // If we got image data, restore it
      if (customerPhotoByteDataLocal != null && customerPhotoByteDataLocal.isNotEmpty) {
        File? imageFile = await Utils.buildImageFromBytesData(
          customerPhotoByteDataLocal,
        );
        if (mounted) {
          setState(() {
            customerPhoto = imageFile;
            customerPhotoByteData = customerPhotoByteDataLocal!;
          });
        }
      }
    } catch (e) {
      Logger.errorLog('[CM] Error reloading customer photo after submission: $e');
    }
  }

  Future<bool> _requestStoragePermission() async {
    // Use common file download service for permission handling
    return await FileDownloadService.requestStoragePermissionWithDialog(
      context: context,
    );
  }

  Future<void> _loadAttachmentFromDocumentId(dynamic attachmentId) async {
    try {
      Logger.infoLog('[CM] Downloading attachment with ID: $attachmentId');
      
      // Request storage permission before downloading
      bool hasPermission = await _requestStoragePermission();
      if (!hasPermission) {
        if (mounted) {
          Toastbar.showErrorToastbar(
            'Storage permission is required to download files',
            context,
          );
        }
        return;
      }
      
      // Parse attachment ID safely
      int docId;
      try {
        docId = attachmentId is int 
            ? attachmentId 
            : int.parse(attachmentId.toString());
        Logger.infoLog('[CM] Parsed document ID: $docId');
      } catch (e) {
        Logger.errorLog('[CM] Format exception: Invalid attachment ID format: $attachmentId');
        if (mounted) {
          Toastbar.showErrorToastbar(
            'Invalid attachment ID format',
            context,
          );
        }
        return;
      }
      
      // Generate filename from attachment name or use default
      String fileName;
      if (_customerAttachmentName != null && _customerAttachmentName!.isNotEmpty) {
        // Use the exact filename from server (includes extension)
        fileName = _customerAttachmentName!;
        Logger.infoLog('[CM] Using filename from server: $fileName');
      } else {
        // Fallback to default filename if not available
        fileName = 'attachment_${DateTime.now().millisecondsSinceEpoch}';
        Logger.infoLog('[CM] Using default filename: $fileName');
      }
      
      // Sanitize filename - remove invalid characters but preserve extension
      // Split filename and extension to preserve extension separately
      final lastDotIndex = fileName.lastIndexOf('.');
      String nameWithoutExt = lastDotIndex > 0 
          ? fileName.substring(0, lastDotIndex) 
          : fileName;
      String extension = lastDotIndex > 0 && lastDotIndex < fileName.length - 1
          ? fileName.substring(lastDotIndex)
          : '';
      
      // Sanitize the name part (without extension)
      nameWithoutExt = nameWithoutExt.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
      
      // Reconstruct filename
      fileName = extension.isNotEmpty ? '$nameWithoutExt$extension' : nameWithoutExt;
      
      // Only add default extension if filename has no extension at all
      // We'll detect the actual file type from the binary data after download
      // For now, don't add a default - let the download method handle it
      if (!fileName.contains('.')) {
        Logger.infoLog('[CM] No extension found in filename, will detect from file content');
        // Don't add extension here - will be detected from file content
      }
      
      Logger.infoLog('[CM] Final filename: $fileName');
      
      // Download document directly to Downloads folder
      String filePath;
      try {
        filePath = await ServiceLocator()
            .cmRepository
            .downloadDocument(docId, fileName);
        
        Logger.infoLog('[CM] ✅ Document downloaded successfully to: $filePath');
      } catch (e) {
        Logger.errorLog('[CM] Error downloading document: $e');
        Logger.errorLog('[CM] Stack trace: ${StackTrace.current}');
        if (mounted) {
          Toastbar.showErrorToastbar(
            'Failed to download document: ${e.toString()}',
            context,
          );
        }
        return;
      }

      // Show success message
      if (mounted) {
        String locationMessage;
        if (filePath.contains('/Download/')) {
          locationMessage = 'File downloaded successfully to Downloads folder';
        } else {
          locationMessage = 'File downloaded to app storage';
        }
        
        Toastbar.showSuccessToastbar(locationMessage, context);
        
        // Show file path in snackbar after a delay
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('File saved to: $filePath'),
                duration: const Duration(seconds: 3),
                action: SnackBarAction(label: 'OK', onPressed: () {}),
              ),
            );
          }
        });
      }
      return; // Exit early since we're downloading directly now
    } catch (e) {
      Logger.errorLog('[CM] Error loading attachment: $e');
      Logger.errorLog('[CM] Stack trace: ${StackTrace.current}');
      if (mounted) {
        Toastbar.showErrorToastbar(
          'Failed to load attachment: ${e.toString()}',
          context,
        );
      }
    }
  }

  void _initializeTicketControllers(Map<String, dynamic> preloadedSite) {
    // Initialize CM Ticket No if cmSiteReqId is available (try both camelCase and snake_case)
    final ticketId = preloadedSite['cmSiteReqId'] ?? preloadedSite['cm_site_req_id'];
    if (ticketId != null && ticketId.toString().trim().isNotEmpty) {
      _cmTicketNoController.text = ticketId.toString();
      Logger.infoLog("✅ [CM] CM Ticket No initialized: ${_cmTicketNoController.text}");
    } else {
      Logger.errorLog("❌ [CM] CM Ticket No not found in preloadedSite. Available keys: ${preloadedSite.keys}");
    }
    
    controllers['responsible_party']!.text =
        preloadedSite['responsible_party']?.toString() ?? '';
    controllers['assigned_to']!.text =
        preloadedSite['assigned_to_name']?.toString() ?? '';
    controllers['priority']!.text = preloadedSite['priority']?.toString() ?? '';
    controllers['oem_ticket_id']!.text =
        preloadedSite['oem_ticket_id']?.toString() ?? '';
    controllers['fault_description']!.text =
        preloadedSite['fault_description']?.toString() ?? '';
    controllers['nature_of_failure']!.text =
        preloadedSite['nature_of_failure']?.toString() ?? '';
    controllers['scope_of_ticket']!.text =
        preloadedSite['scope_of_ticket']?.toString() ?? '';
    controllers['action_taken']!.text =
        preloadedSite['action_taken']?.toString() ?? '';
    controllers['rca']!.text = preloadedSite['rca']?.toString() ?? '';
    controllers['closure_date']!.text =
        preloadedSite['closure_date']?.toString() ?? 
        preloadedSite['closureDate']?.toString() ?? '';
    controllers['oem_representative']!.text =
        preloadedSite['oem_representative']?.toString() ?? 
        preloadedSite['oemRepresentative']?.toString() ?? '';
    controllers['oem_representative_contact']!.text =
        preloadedSite['oem_representative_contact']?.toString() ?? 
        preloadedSite['oemRepresentativeContact']?.toString() ?? '';
    controllers['customer_name']!.text =
        preloadedSite['customer_name']?.toString() ?? '';
    controllers['contact_no']!.text =
        preloadedSite['contact_no']?.toString() ?? '';
    controllers['customer_remarks']!.text =
        preloadedSite['customer_remarks']?.toString() ?? '';
    controllers['problem_summary']!.text =
        preloadedSite['problem_summary']?.toString() ?? '';
    
    // Set status from preloaded data (handle both camelCase and snake_case)
    final status = preloadedSite['status'] ?? preloadedSite['Status'];
    if (status != null && status.toString().trim().isNotEmpty) {
      _statusController.text = status.toString().trim();
    }
    
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
    
    // Load images and attachments asynchronously
    // This will update state after the widget has built
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
            final localChecklistData = await ServiceLocator()
                .centralAssetAuditDataService
                .getCMChecklistData(selectedSite.siteId);
            
            Logger.infoLog("🔍 [CM] Separate checklist lookup result: ${localChecklistData.length} equipment types");
            
            Logger.infoLog("🔍 [CM] Local checklist table returned ${localChecklistData.length} equipment types");

            if (localChecklistData.isNotEmpty) {
              Logger.infoLog("✅ [CM] Checklist data loaded from separate table with types: ${localChecklistData.keys.toList()}");
              checklistData = localChecklistData;
            } else {
              Logger.infoLog("⚠️ [CM] No local checklist data found, fetching from API");
              try {
                // Check connectivity first
                final isOnline = await ConnectivityHelper.isConnected();
                
                // Check if site is downloaded
                final isSiteDownloaded = await ServiceLocator()
                    .centralAssetAuditDataService
                    .isCMSiteDownloaded(selectedSite.siteId);
                
                // If offline and site is not downloaded, throw error
                if (!isOnline && !isSiteDownloaded) {
                  throw Exception("This site is not downloaded. Please download the site data first to use it offline.");
                }
                
                // If online, allow API call even if site is not downloaded
                if (isOnline) {
                  Logger.infoLog("🌐 [CM] Online mode - fetching checklist from API");
                  final apiResponse = await ServiceLocator().cmRepository
                      .getChecklistData(selectedSite.entityId);
                  
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
                      entityId: selectedSite.entityId,
                      siteCode: selectedSite.siteCode,
                      siteName: selectedSite.siteName,
                    );
                    Logger.infoLog("✅ [CM] Checklist data saved to local database");
                  } catch (saveError) {
                    Logger.errorLog("⚠️ [CM] Failed to save checklist to local database: $saveError");
                    // Continue even if save fails
                  }
                } else {
                  // Offline mode but no local data - should not reach here due to check above
                  throw Exception("No internet connection and site data not downloaded. Please download the site data first.");
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
    _cmTicketNoController.dispose();
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
      ],

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

        CustomRemarksField(
          label: "Fault Description",
          isRequired: true,
          hintText: "Enter fault description",
          controller: controllers['fault_description']!,
          isDisabled: widget.mode == CMScreenModeEnum.view,
        ),
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

        CustomDropdown(
          label: "Scope of Ticket",
          items: _scopeOfTicketOptions,
          initialValue: controllers['scope_of_ticket']!.text,
          isRequired: true,
          onChanged: (value) {
            setState(() {
              controllers['scope_of_ticket']!.text = value ?? "";
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

        // Closure Date - only visible in view mode
        if (widget.mode == CMScreenModeEnum.view) ...[
          CustomFormField(
            label: "Closure Date",
            controller: controllers['closure_date'],
            isEditable: false,
            isRequired: true,
          ),
          getHeight(15),
        ],

        // Show these fields only in edit and view mode
        if (widget.mode != CMScreenModeEnum.create) ...[
          CustomFormField(
            label: "OEM Representative",
            controller: controllers['oem_representative'],
            isEditable: widget.mode != CMScreenModeEnum.view,
            isRequired: true,
          ),
          getHeight(15),

          CustomFormField(
            label: "OEM Representative Contact",
            controller: controllers['oem_representative_contact'],
            isEditable: widget.mode != CMScreenModeEnum.view,
            isRequired: true,
            inputType: InputType.number,
            maxLength: 10,
          ),
          getHeight(15),
        ],

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
          serverAttachmentName: widget.mode != CMScreenModeEnum.create && 
              _customerAttachmentName != null && 
              _customerAttachmentName!.trim().isNotEmpty
              ? _customerAttachmentName!.trim()
              : null,
          serverAttachmentId: widget.mode != CMScreenModeEnum.create && 
              _customerAttachmentId != null && 
              _customerAttachmentId != 0
              ? _customerAttachmentId
              : null,
          onServerAttachmentClicked: widget.mode != CMScreenModeEnum.create
              ? (attachmentId) async {
                  LoaderWidget.showLoader(context);
                  try {
                    await _loadAttachmentFromDocumentId(attachmentId);
                  } finally {
                    LoaderWidget.hideLoader();
                  }
                }
              : null,
          onServerAttachmentDeleted: widget.mode != CMScreenModeEnum.create
              ? () {
                  setState(() {
                    _customerAttachmentId = null;
                    _customerAttachmentName = null;
                    _hasFormDataChanges = true;
                  });
                }
              : null,
          onFileSelected: (File? file) {
            if (file != null) {
              setState(() {
                // Clear server attachment when new file is uploaded
                _customerAttachmentId = null;
                _customerAttachmentName = null;
                // Clear existing attachments and add new one
                _uploadedAttachments.clear();
                _uploadedAttachments.add(file);
                _hasFormDataChanges = true;
              });
            }
          },
          onFileDeleted: (File file) {
            // Handle file deletion
            setState(() {
              _uploadedAttachments.remove(file);
              _hasFormDataChanges = true;
            });
          },
          isRequired: false,
          maxSizeText: "(Max Size: 2MB)",
          acceptedFileTypes: "(Accept Only - .pdf, .docx & .doc)",
          isDisabled: widget.mode == CMScreenModeEnum.view,
        ),
        getHeight(30),
        // Edit mode: Show editable remarks and attachments section
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
            isDisabled: false, // Allow editing in edit mode
          ),
          getHeight(15),
          CustomFileUploadNew(
            label: "Remark Attachment",
            placeholder: "Upload File",
                uploadedFiles: _remarksAttachments,
                serverAttachmentName: (_remarksAttachmentName != null && _remarksAttachmentName!.trim().isNotEmpty)
                    ? _remarksAttachmentName!.trim()
                    : null,
                serverAttachmentId: _remarksAttachmentId != null && 
                    _remarksAttachmentId != 0 && 
                    _remarksAttachmentId.toString().trim().isNotEmpty
                    ? _remarksAttachmentId 
                    : null,
                onServerAttachmentClicked: _remarksAttachmentId != null && 
                    _remarksAttachmentId != 0
                    ? (attachmentId) async {
                        LoaderWidget.showLoader(context);
                        try {
                          await _loadAttachmentFromDocumentId(attachmentId);
                        } finally {
                          LoaderWidget.hideLoader();
                        }
                      }
                    : null,
                onServerAttachmentDeleted: () {
                  setState(() {
                    _remarksAttachmentId = null;
                    _remarksAttachmentName = null;
                    _hasFormDataChanges = true;
                  });
                },
            onFileSelected: (File? file) {
              if (file != null) {
                setState(() {
                      // Clear server attachment when new file is uploaded
                      _remarksAttachmentId = null;
                      _remarksAttachmentName = null;
                      // Clear existing attachments and add new one
                  _remarksAttachments.clear();
                  _remarksAttachments.add(file);
                      _hasFormDataChanges = true;
                });
              }
            },
            onFileDeleted: (File file) {
              // Handle file deletion
              setState(() {
                _remarksAttachments.remove(file);
                    _hasFormDataChanges = true;
              });
            },
            isRequired: true,
            maxSizeText: "(Max Size: 2MB)",
                acceptedFileTypes: "(Accept Only - .pdf, .docx & .doc)",
          ),
          getHeight(30),
        ],
        // Show remarks in view mode (read-only display)
        if (widget.mode == CMScreenModeEnum.view)
          CMRemarksShowWidget(
            remarksList: widget.preloadedSiteData?['cmRemarksList'] ?? 
                        widget.preloadedSiteData?['cm_remarks_list'],
          ),
        CustomSubmitButtonV2(text: "Submit", onPressed: _validateAndSubmit),
      ],
    );
  }

  Future<void> _validateAndSubmit({bool shouldNavigate = true}) async {
    if (widget.mode == CMScreenModeEnum.create) {
      await _submitFormData(shouldNavigate: shouldNavigate);
    } else if (widget.mode == CMScreenModeEnum.edit) {
      await _editFormData(shouldNavigate: shouldNavigate);
    }
  }

  Future<void> _editFormData({bool shouldNavigate = true}) async {
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
      
      // Explicitly ensure these key fields are set
      requestData['scope_of_ticket'] = controllers['scope_of_ticket']!.text;
      requestData['fault_description'] = controllers['fault_description']!.text;
      requestData['responsible_party'] = controllers['responsible_party']!.text; // Value from Category dropdown
      
      // Set assigned_to based on responsible_party
      if (controllers['responsible_party']!.text == 'OEM') {
        requestData['assigned_to'] = _selectedSite!.oemId;
      } else if (controllers['responsible_party']!.text == 'Self') {
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
        requestData['assigned_to_name'] = controllers['responsible_party']!.text == 'OEM' 
            ? _selectedSite!.oem 
            : _selectedSite!.self;
      }
      
      // Set status and remarks
      requestData['status'] = _statusController.text.isNotEmpty 
          ? _statusController.text 
          : 'Open';
      requestData['remarks'] = _remarksController.text;
      requestData['is_active'] = true;
      
      // Set dates (if closure_date is provided, calculate noOfDays)
      if (controllers['closure_date']!.text.isNotEmpty) {
        try {
          final closureDate = DateTime.parse(controllers['closure_date']!.text);
          final now = DateTime.now();
          final daysDifference = closureDate.difference(now).inDays;
          requestData['end_dt'] = closureDate.toIso8601String();
          requestData['no_of_days'] = daysDifference > 0 ? daysDifference : 0;
        } catch (e) {
          Logger.errorLog("Error parsing closure date: $e");
        }
      }
      requestData['start_dt'] = DateTime.now().toIso8601String();
      
      // Set customer photo and attachment names (will be updated after upload)
      if (customerPhoto != null) {
        final photoName = customerPhoto!.path.split('/').last;
        requestData['customer_photo_name'] = photoName;
      }
      if (_uploadedAttachments.isNotEmpty) {
        final attachmentName = _uploadedAttachments.first.path.split('/').last;
        requestData['customer_attachmen_name'] = attachmentName; // Typo variant (matches API)
        requestData['customer_attachment_name'] = attachmentName; // Correct spelling
      }
      
      // Set impacted item list
      requestData['cm_impacted_item_list'] =
          DataTransformationHelper.convertListToCamelCase(_impactedItemList);
      final selectedCheckListData = _checklistData[_selectedEquipmentType];
      LocationModel? finalLocation;

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
      
      // Add remarks to request data
      if (_remarksController.text.trim().isNotEmpty) {
        requestData['cm_remark'] = _remarksController.text.trim();
      }
      
      // In edit mode, preserve customer attachment ID and name if they exist and weren't changed
      if (widget.mode == CMScreenModeEnum.edit) {
        // If attachment wasn't changed (no new file uploaded) but we have existing attachment info
        if (_uploadedAttachments.isEmpty && _customerAttachmentId != null && _customerAttachmentId != 0) {
          requestData['customer_attachment_id'] = _customerAttachmentId;
          
          // Use attachment name if available, otherwise use attachment ID as name
          final attachmentName = (_customerAttachmentName != null && _customerAttachmentName!.trim().isNotEmpty)
              ? _customerAttachmentName!.trim()
              : _customerAttachmentId.toString();
          
          // Include both possible field names (typo variant and correct spelling)
          requestData['customer_attachmen_name'] = attachmentName; // Typo variant (matches API)
          requestData['customer_attachment_name'] = attachmentName; // Correct spelling (fallback)
          
          Logger.infoLog('[CM] Preserving customer attachment in edit mode - ID: $_customerAttachmentId, Name: $attachmentName');
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

  Future<void> _handleOnlineEditSubmission(
    Map<String, dynamic> requestData, {
    bool shouldNavigate = true,
  }) async {
    try {
      Map<String, dynamic> processedData =
          DataTransformationHelper.convertKeysToCamelCase(requestData);
      await ServiceLocator().cmRepository.createCorrectiveMaintenance(
        processedData,
      );

      Logger.debugLog(" processedData: $processedData");

      // Only upload photo/attachment if they were actually changed (new files selected)
      // In edit mode, if customerPhoto is null and _uploadedAttachments is empty,
      // it means they weren't changed, so we should preserve them by not calling this method
      final hasNewPhoto = customerPhoto != null;
      final hasNewAttachment = _uploadedAttachments.isNotEmpty;
      
      if (hasNewPhoto || hasNewAttachment) {
        Logger.infoLog('[CM] Uploading changed photo/attachment - Photo: $hasNewPhoto, Attachment: $hasNewAttachment');
        await ServiceLocator().cmRepository.saveCustomerPhotoAndAttachments(
          cmSiteReqId!,
          customerPhoto, // Will be null if not changed, which is fine - API won't update it
          _uploadedAttachments.firstOrNull, // Will be null if not changed, which is fine - API won't update it
        );
      } else {
        Logger.infoLog('[CM] No changes to photo or attachment, skipping upload to preserve existing ones');
      }
      
      // Upload remarks with attachment if remarks or attachment were changed
      if (_remarksController.text.trim().isNotEmpty || _remarksAttachments.isNotEmpty) {
        // If remarks attachment is provided, upload it
        if (_remarksAttachments.isNotEmpty) {
          final remarksFile = _remarksAttachments.first;
          final originalFileName = remarksFile.path.split('/').last;
          await ServiceLocator().cmRepository.saveRemarks(
            cmSiteReqId!,
            _remarksController.text.trim(),
            _statusController.text,
            remarksFile,
            originalFileName: originalFileName,
          );
        } else if (_remarksController.text.trim().isNotEmpty) {
          // If only remarks text is provided without attachment, still save remarks
          // Note: saveRemarks requires a file, so we might need to handle text-only remarks differently
          // For now, only save if attachment is provided
          Logger.infoLog('[CM] Remarks text provided but no attachment - skipping remarks save (API requires file)');
        }
      }
      
      // Reload customer photo if it wasn't changed (preserve existing photo in edit mode)
      if (customerPhoto == null && _originalCustomerPhotoId != null && 
          _originalCustomerPhotoId.toString().trim().isNotEmpty) {
        Logger.infoLog('[CM] Reloading customer photo after submission to preserve display');
        await _reloadCustomerPhoto(_originalCustomerPhotoId);
      }
      
      // Reload customer attachment info if it wasn't changed (preserve existing attachment in edit mode)
      if (_uploadedAttachments.isEmpty && _customerAttachmentId != null && _customerAttachmentId != 0) {
        Logger.infoLog('[CM] Reloading customer attachment after submission to preserve display');
        // The attachment info is already in state, but ensure it's still displayed
        // No need to reload from server since we already have the ID and name
        setState(() {
          // Force rebuild to ensure attachment is displayed
        });
      }
      
      Toastbar.showSuccessToastbar("Form Submitted Successfully", context);
      // if (shouldNavigate && mounted) {
      //   Future.microtask(() {
      //     navigateBackOrToHome(
      //       context,
      //       targetContext: widget.parentContext ?? context,
      //     );
      //   });
      // }
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

      // Upload images first and get unique IDs (same as create mode)
      String? customerPhotoId;
      String? attachmentId;
      String? remarksAttachmentId;

      // Only upload if new files were selected (not preserving existing ones)
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

      // Upload remarks attachment if provided
      if (_remarksAttachments.isNotEmpty) {
        remarksAttachmentId = await _uploadImageWithOfflineSupport(
          _remarksAttachments.first,
          ActivityTypeEnum.correctiveMaintenance,
        );
      }

      // Add image IDs to request data (only if new files were uploaded)
      if (customerPhotoId != null) {
        requestData['customer_photo_id'] = customerPhotoId;
      } else if (_originalCustomerPhotoId != null && _originalCustomerPhotoId.toString().trim().isNotEmpty) {
        // Preserve existing photo ID if not changed
        requestData['customer_photo_id'] = _originalCustomerPhotoId;
      }
      
      if (attachmentId != null) {
        requestData['customer_attachment_id'] = attachmentId;
        // Store original file path and name to preserve extension and filename
        if (_uploadedAttachments.isNotEmpty) {
          final originalFile = _uploadedAttachments.first;
          final originalFileName = originalFile.path.split('/').last;
          requestData['customer_original_file_path'] = originalFile.path;
          requestData['customer_original_file_name'] = originalFileName;
          // Set attachment name for API (preserve original filename)
          requestData['customer_attachmen_name'] = originalFileName; // Typo variant (matches API)
          requestData['customer_attachment_name'] = originalFileName; // Correct spelling (fallback)
        }
      } else if (_customerAttachmentId != null && _customerAttachmentId != 0) {
        // Preserve existing attachment ID if not changed
        requestData['customer_attachment_id'] = _customerAttachmentId;
        // Also preserve attachment name
        final attachmentName = (_customerAttachmentName != null && _customerAttachmentName!.trim().isNotEmpty)
            ? _customerAttachmentName!.trim()
            : _customerAttachmentId.toString();
        requestData['customer_attachmen_name'] = attachmentName;
        requestData['customer_attachment_name'] = attachmentName;
      }
      
      // Add remarks attachment ID if uploaded
      if (remarksAttachmentId != null) {
        requestData['cm_attachment_id'] = remarksAttachmentId;
      } else if (_remarksAttachmentId != null && _remarksAttachmentId != 0) {
        // Preserve existing remarks attachment ID if not changed
        requestData['cm_attachment_id'] = _remarksAttachmentId;
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
        
        // If remarks were provided, also save remarks as a separate pending request
        // (since remarks might be saved via separate API call)
        if (_remarksController.text.trim().isNotEmpty || _remarksAttachments.isNotEmpty) {
          // Create a remarks request data
          final remarksRequestData = <String, dynamic>{
            'cmId': cmSiteReqId,
            'cmRemark': _remarksController.text.trim(),
            'cmStatus': _statusController.text,
          };
          
          if (remarksAttachmentId != null) {
            remarksRequestData['cmRemarksFile'] = remarksAttachmentId;
            // Store original file path to preserve extension and filename
            if (_remarksAttachments.isNotEmpty) {
              final originalFile = _remarksAttachments.first;
              remarksRequestData['originalFilePath'] = originalFile.path;
              remarksRequestData['originalFileName'] = originalFile.path.split('/').last;
            }
          } else if (_remarksAttachmentId != null && _remarksAttachmentId != 0) {
            remarksRequestData['cmAttachmentId'] = _remarksAttachmentId;
          }
          
          final remarksRequestId = 'cm_remarks_${cmSiteReqId}_${DateTime.now().millisecondsSinceEpoch}';
          final remarksUrl = '/api/v1/mobile/cmRemarks/upload';
          
          // For offline, we'll save the remarks file path and upload it when online
          // The actual file upload will happen when syncing pending requests
          await ServiceLocator().pendingRequestService.savePendingRequest(
            requestId: remarksRequestId,
            url: remarksUrl,
            headers: {},
            jsonEncodedRequestData: jsonEncode(remarksRequestData),
          );
          
          Logger.infoLog("CM remarks saved to pending requests successfully");
        }
        
        Toastbar.showSuccessToastbar(
          "Data saved offline. Will sync when online.",
          context,
        );
        // if (shouldNavigate && mounted) {
        //   Future.microtask(() {
        //     navigateBackOrToHome(
        //       context,
        //       targetContext: widget.parentContext ?? context,
        //     );
        //   });
        // }
      } else {
        throw Exception('Failed to save data to offline storage');
      }
    } catch (e) {
      Logger.errorLog("Error in offline edit submission: $e");
      Toastbar.showErrorToastbar(
        "Failed to save form edit offline: $e",
        context,
      );
    }
  }

  Future<void> _submitFormData({bool shouldNavigate = true}) async {
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
      
      // Explicitly ensure these key fields are set
      requestData['scope_of_ticket'] = controllers['scope_of_ticket']!.text;
      requestData['fault_description'] = controllers['fault_description']!.text;
      requestData['responsible_party'] = controllers['responsible_party']!.text; // Value from Category dropdown
      
      // Set assigned_to based on responsible_party
      if (controllers['responsible_party']!.text == 'OEM') {
        requestData['assigned_to'] = _selectedSite!.oemId;
      } else if (controllers['responsible_party']!.text == 'Self') {
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
        requestData['assigned_to_name'] = controllers['responsible_party']!.text == 'OEM' 
            ? _selectedSite!.oem 
            : _selectedSite!.self;
      }
      
      // Set status and remarks
      requestData['status'] = _statusController.text.isNotEmpty 
          ? _statusController.text 
          : 'Open';
      requestData['remarks'] = _remarksController.text;
      requestData['is_active'] = true;
      
      // Set dates (if closure_date is provided, calculate noOfDays)
      if (controllers['closure_date']!.text.isNotEmpty) {
        try {
          final closureDate = DateTime.parse(controllers['closure_date']!.text);
          final now = DateTime.now();
          final daysDifference = closureDate.difference(now).inDays;
          requestData['end_dt'] = closureDate.toIso8601String();
          requestData['no_of_days'] = daysDifference > 0 ? daysDifference : 0;
        } catch (e) {
          Logger.errorLog("Error parsing closure date: $e");
        }
      }
      requestData['start_dt'] = DateTime.now().toIso8601String();
      
      // Set customer photo and attachment names (will be updated after upload)
      if (customerPhoto != null) {
        final photoName = customerPhoto!.path.split('/').last;
        requestData['customer_photo_name'] = photoName;
      }
      if (_uploadedAttachments.isNotEmpty) {
        final attachmentName = _uploadedAttachments.first.path.split('/').last;
        requestData['customer_attachmen_name'] = attachmentName; // Typo variant (matches API)
        requestData['customer_attachment_name'] = attachmentName; // Correct spelling
      }
      
      // Set impacted item list
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
      // if (shouldNavigate && mounted) {
      //   Future.microtask(() {
      //     navigateBackOrToHome(
      //       context,
      //       targetContext: widget.parentContext ?? context,
      //     );
      //   });
      // }
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
        // Add customer photo name if available
        if (customerPhoto != null) {
          final photoName = customerPhoto!.path.split('/').last;
          requestData['customer_photo_name'] = photoName;
        }
      }
      if (attachmentId != null) {
        requestData['customer_attachment_id'] = attachmentId;
        // Add customer attachment name if available
        if (_uploadedAttachments.isNotEmpty) {
          final attachmentName = _uploadedAttachments.first.path.split('/').last;
          requestData['customer_attachmen_name'] = attachmentName; // Typo variant (matches API)
          requestData['customer_attachment_name'] = attachmentName; // Correct spelling
        }
      }
      
      // Add status and remarks if not already in requestData
      if (!requestData.containsKey('status') || requestData['status'] == null || requestData['status'].toString().isEmpty) {
        requestData['status'] = _statusController.text.isNotEmpty ? _statusController.text : 'Open';
      }
      if (!requestData.containsKey('remarks') || requestData['remarks'] == null) {
        requestData['remarks'] = _remarksController.text;
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
        Toastbar.showSuccessToastbar(
          "Data saved offline. Will sync when online.",
          context,
        );
        // if (shouldNavigate && mounted) {
        //   Future.microtask(() {
        //     navigateBackOrToHome(
        //       context,
        //       targetContext: widget.parentContext ?? context,
        //     );
        //   });
        // }
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
          parentContext: widget.parentContext ?? context,
          onSaveAndExit: () async {
            await _validateAndSubmit(shouldNavigate: false);
          },
          onDiscard: () {},
        ),
      );
    } else {
      // navigateBackOrToHome(
      //   context,
      //   targetContext: widget.parentContext ?? context,
      // );
    }
  }
}
