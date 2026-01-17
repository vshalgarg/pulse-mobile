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
import 'package:app/services/location_service.dart';
import 'package:app/utils.dart';
import 'package:app/utils/data_transformation_helper.dart';
import 'package:app/utils/logger.dart';
import 'package:app/utils/toastbar.dart';
import 'package:app/utils/connectivity_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
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
import '../../../routes/route_generator.dart';

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
  
  // New photo fields: Identification, Time Stamp Photo (only in edit/view mode)
  File? identificationPhoto;
  String identificationPhotoByteData = "";
  dynamic _originalIdentificationPhotoId;
  
  File? timestampPhoto;
  String timestampPhotoByteData = "";
  dynamic _originalTimestampPhotoId;
  
  final List<File> _uploadedAttachments = [];
  final List<File> _remarksAttachments = [];
  final List<File> _fsrAttachments = []; // FSR as file attachment
  
  // Store server attachment info (ID and filename)
  String? _customerAttachmentName;
  dynamic _customerAttachmentId;
  
  // Store FSR attachment info (ID and filename)
  String? _fsrAttachmentName;
  dynamic _fsrAttachmentId;
  
  // Store remarks attachment info (for edit mode)
  String? _remarksAttachmentName;
  dynamic _remarksAttachmentId;

  // 👇 Dropdown options
  List<CMSite> _siteOptions = [];
  final List<String> _priorityOptions = ['Critical', 'Non Critical'];
  final List<String> _responsiblePartyOptions = ['OEM', 'Self'];
  final List<String> _natureOfFailureOptions = ['AMC', 'Paid', 'FOC'];
  final List<String> _scopeOfTicketOptions = ['Warranty', 'Warranty Out'];
  final List<String> _statusOptions = ['Open','Closed'];
  Map<String, dynamic> _checklistData = {};
  List<Map<String, dynamic>> _impactedItemList = [];

  bool _hasFormDataChanges = false;
  bool _isSubmitting = false; // Flag to prevent duplicate submissions

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

      // Try both camelCase and snake_case for cmSiteReqId
      cmSiteReqId = preloadedSite['cmSiteReqId'] ?? preloadedSite['cm_site_req_id'];
      
      // Helper function to get value with fallback for both camelCase and snake_case
      T _getSiteValue<T>(Map<String, dynamic> map, String camelCaseKey, String snakeCaseKey, T defaultValue) {
        final value = map[camelCaseKey] ?? map[snakeCaseKey];
        return value != null ? value as T : defaultValue;
      }
      
      CMSite site = CMSite(
        siteId: _getSiteValue(preloadedSite, 'siteId', 'site_id', 0),
        entityId: _getSiteValue(preloadedSite, 'entityId', 'entity_id', 0),
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
    }
  }

  void _loadImages(Map<String, dynamic> preloadedSite) async {
    
    // Try both camelCase and snake_case for customer photo ID
    dynamic customerPhotoId = preloadedSite['customerPhotoId'] ?? preloadedSite['customer_photo_id'];
    // Store original photo ID to preserve it after form submission
    _originalCustomerPhotoId = customerPhotoId;
    
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
    
    if (customerPhotoId != null && customerPhotoId.toString().trim().isNotEmpty) {
      await _loadPhotoFromServer(customerPhotoId, (file, byteData) {
        customerPhoto = file;
        customerPhotoByteData = byteData;
      }, 'Customer');
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
      
      // Load FSR attachment info (only for edit/view mode, not create)
      // Try all possible field name variations for FSR attachment ID
      dynamic fsrAttachmentId = preloadedSite['fsrAttachmentId'] ?? 
                                preloadedSite['fsr_attachment_id'];
      
      // Convert to int if it's a string
      if (fsrAttachmentId != null && fsrAttachmentId is String && fsrAttachmentId.trim().isNotEmpty) {
        try {
          fsrAttachmentId = int.parse(fsrAttachmentId.trim());
        } catch (e) {
          Logger.errorLog('[CM] Failed to parse FSR attachment ID as int: $fsrAttachmentId');
          fsrAttachmentId = null;
        }
      }
      
      // Try all possible field name variations for FSR attachment name
      dynamic fsrAttachmentName = preloadedSite['fsrAttachmentName'] ?? 
                                   preloadedSite['fsr_attachment_name'];
      
      // Set FSR attachment if ID is valid
      if (fsrAttachmentId != null && fsrAttachmentId != 0) {
        // If name is null or empty, use attachment ID as the name
        final nameToSet = (fsrAttachmentName != null && fsrAttachmentName.toString().trim().isNotEmpty) 
            ? fsrAttachmentName.toString().trim() 
            : fsrAttachmentId.toString(); // Use ID as name if name is not available
        
        Logger.infoLog('[CM] Setting FSR attachment - ID: $fsrAttachmentId, Name: $nameToSet');
        
        // Set state directly
        setState(() {
          _fsrAttachmentId = fsrAttachmentId;
          _fsrAttachmentName = nameToSet;
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
          // Online: try to download from server and cache it
          Logger.infoLog('[CM] $photoName photo not in cache, downloading from server (online mode)');
          
          // Use downloadImageUsingServerId which handles caching
          final uniqueId = await ServiceLocator()
              .imageUploadService
              .downloadImageUsingServerId(
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

  /// Helper method to get value from preloadedSite handling both camelCase and snake_case
  String? _getValue(Map<String, dynamic> preloadedSite, String camelCaseKey, String snakeCaseKey) {
    final value = preloadedSite[camelCaseKey] ?? preloadedSite[snakeCaseKey];
    if (value == null) return null;
    final strValue = value.toString().trim();
    return strValue.isEmpty ? null : strValue;
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
    
    // Map all fields with support for both camelCase and snake_case
    // Responsible Party (Category)
    final responsibleParty = _getValue(preloadedSite, 'responsibleParty', 'responsible_party');
    if (responsibleParty != null) {
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
    final priority = _getValue(preloadedSite, 'priority', 'priority');
    if (priority != null) {
      controllers['priority']!.text = priority;
      Logger.infoLog('[CM] Priority initialized: $priority');
    }
    
    // OEM Ticket ID
    final oemTicketId = _getValue(preloadedSite, 'oemTicketId', 'oem_ticket_id');
    if (oemTicketId != null) {
      controllers['oem_ticket_id']!.text = oemTicketId;
      Logger.infoLog('[CM] OEM Ticket ID initialized: $oemTicketId');
    }
    
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
    final scopeOfTicket = _getValue(preloadedSite, 'scopeOfTicket', 'scope_of_ticket');
    if (scopeOfTicket != null) {
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
    
    // Closure Date
    final closureDate = _getValue(preloadedSite, 'closureDate', 'closure_date');
    if (closureDate != null) {
      controllers['closure_date']!.text = closureDate;
      Logger.infoLog('[CM] Closure Date initialized: $closureDate');
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
    
    // Customer Remarks
    final customerRemarks = _getValue(preloadedSite, 'customerRemarks', 'customer_remarks');
    if (customerRemarks != null) {
      controllers['customer_remarks']!.text = customerRemarks;
      Logger.infoLog('[CM] Customer Remarks initialized: $customerRemarks');
    }
    
    // Problem Summary
    final problemSummary = _getValue(preloadedSite, 'problemSummary', 'problem_summary');
    if (problemSummary != null) {
      controllers['problem_summary']!.text = problemSummary;
      Logger.infoLog('[CM] Problem Summary initialized: $problemSummary');
    }
    
    // Set status from preloaded data (handle both camelCase and snake_case)
    final status = _getValue(preloadedSite, 'status', 'status') ?? preloadedSite['Status']?.toString().trim();
    if (status != null && status.isNotEmpty) {
      _statusController.text = status;
      Logger.infoLog('[CM] Status initialized: $status');
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
    
    // Only set default status if not already set from preloaded data
    if (_statusController.text.isEmpty) {
      _statusController.text = 'Open';
    }
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
      } else if (widget.mode == CMScreenModeEnum.edit || widget.mode == CMScreenModeEnum.view) {
        // In edit/view mode, load checklist template and merge with existing responses
        Logger.infoLog(
          "🔄 [CM] Edit/View mode - Loading checklist template and merging with existing responses",
        );
        
        try {
          // Load checklist template from local database or API
          Map<String, dynamic> checklistTemplate = {};
          
          // Try to get from local database first
          final siteDataWithChecklist = await ServiceLocator()
              .centralAssetAuditDataService
              .getCMSiteDataWithChecklist(_selectedSite!.siteId);
          
          if (siteDataWithChecklist != null && siteDataWithChecklist['checklist_items'] != null) {
            checklistTemplate = Map<String, dynamic>.from(siteDataWithChecklist['checklist_items']);
          } else {
            // Try separate checklist table
            final localChecklistData = await ServiceLocator()
                .centralAssetAuditDataService
                .getCMChecklistData(_selectedSite!.siteId);
            
            if (localChecklistData.isNotEmpty) {
              checklistTemplate = localChecklistData;
            } else {
              // Fetch from API if online
              final isOnline = await ConnectivityHelper.isConnected();
              if (isOnline) {
                final apiResponse = await ServiceLocator().cmRepository
                    .getChecklistData(_selectedSite!.entityId);
                
                if (apiResponse.containsKey('checkListDetails')) {
                  checklistTemplate = Map<String, dynamic>.from(apiResponse['checkListDetails']);
                  if (apiResponse.containsKey('siteDeployedItems')) {
                    checklistTemplate['siteDeployedItems'] = apiResponse['siteDeployedItems'];
                  }
                } else {
                  checklistTemplate = apiResponse;
                }
              }
            }
          }
          
          // Get existing responses from API endpoint /mobile/correctiveMaintenanceForMobile/
          List<dynamic> existingResponses = [];
          
          // First, try to get from preloadedSiteData (handle nested structure)
          Map<String, dynamic>? preloadedData = widget.preloadedSiteData;
          if (preloadedData != null) {
            // Handle nested data structure if present
            if (preloadedData.containsKey('data') && preloadedData['data'] is Map<String, dynamic>) {
              preloadedData = Map<String, dynamic>.from(preloadedData['data']);
            }
            
            existingResponses = preloadedData['cmCheckListSiteRespList'] ?? 
                               preloadedData['cm_check_list_site_resp_list'] ?? [];
          }
          
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

  /// Merge existing checklist responses with template checklist data
  Future<Map<String, dynamic>> _mergeChecklistWithResponses(
    Map<String, dynamic> checklistTemplate,
    List<dynamic> existingResponses,
  ) async {
    final mergedData = <String, dynamic>{};
    
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
        final existingItemsForType = responsesByType[normalizedEquipmentType] ?? [];
        Logger.infoLog('[CM] Found ${existingItemsForType.length} existing responses for $equipmentType');
        
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
              
              // Merge cmImpactedItemList directly (for DYNAMIC_DROPDOWN)
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
                      // Load image data from server/cache
                      String? imageData;
                      try {
                        // First check cache
                        final cachedImage = await ServiceLocator()
                            .imageUploadService
                            .getImagesByServerId(photoId.toString());
                        
                        if (cachedImage != null && cachedImage.imageData != null) {
                          imageData = cachedImage.imageData;
                        } else {
                          // Try to download if online
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
                      });
                    }
                  }
                }
                mergedItem['response_images'] = responseImages;
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
                                  // Load image data from server/cache
                                  String? imageData;
                                  try {
                                    final cachedImage = await ServiceLocator()
                                        .imageUploadService
                                        .getImagesByServerId(photoId.toString());
                                    
                                    if (cachedImage != null && cachedImage.imageData != null) {
                                      imageData = cachedImage.imageData;
                                    } else {
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
                                    Logger.errorLog('[CM] Error loading child image $photoId: $e');
                                  }
                                  
                                  processedChildImages.add({
                                    'photo_id': photoId,
                                    'photo_taken_ts': childImg['photoTakenTs'] ?? childImg['photo_taken_ts'],
                                    'image_data': imageData,
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
            } else {
              // No matching response found - log for debugging
              Logger.infoLog('[CM] No matching response found for mstId: $mstId, equipmentType: $equipmentType, checklistDesc: ${mergedItem['checklistDesc'] ?? mergedItem['checklist_desc']}');
              // Still add the item even without a match (template item without response)
              // resp will remain null/empty from template
            }
            
            // Log the final merged item to verify resp is set
            Logger.infoLog('[CM] Final merged item - mstId: $mstId, checklistDesc: ${mergedItem['checklistDesc'] ?? mergedItem['checklist_desc']}, resp: ${mergedItem['resp']}, respType: ${mergedItem['respType'] ?? mergedItem['resp_type']}');
            mergedItems.add(mergedItem);
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
      // Clear Identification and FSR when responsibleParty is not OEM
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
                // Clear impacted item list when switching equipment types
                _impactedItemList.clear();
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
                    _impactedItemList = impactedItems;
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
        if (widget.mode == CMScreenModeEnum.edit &&
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
                    _impactedItemList = impactedItems;
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
        if (widget.mode == CMScreenModeEnum.view &&
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
                  onPressed: _isSubmitting ? null : _validateAndSubmit,
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

        // Action Taken - only in edit and view mode
        if (widget.mode != CMScreenModeEnum.create) ...[
        CustomFormField(
          label: "Action Taken",
          controller: controllers['action_taken'],
          isEditable: widget.mode != CMScreenModeEnum.view,
          isRequired: true,
        ),
        getHeight(15),
        ],

        // RCA - only in edit and view mode
        if (widget.mode != CMScreenModeEnum.create) ...[
        CustomFormField(
          label: "RCA",
          controller: controllers['rca'],
          isEditable: widget.mode != CMScreenModeEnum.view,
          isRequired: true,
        ),
        getHeight(15),
        ],

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

        // Show these fields only in edit and view mode, and only when Category is OEM
        if (widget.mode != CMScreenModeEnum.create && 
            controllers['responsible_party']!.text.trim().toUpperCase() == 'OEM') ...[
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

        // Problem Summary - only in edit and view mode
        if (widget.mode != CMScreenModeEnum.create) ...[
        CustomRemarksField(
          label: "Problem Summary",
          hintText: "Enter problem summary",
          controller: controllers['problem_summary']!,
          isDisabled: widget.mode == CMScreenModeEnum.view,
        ),
        getHeight(15),
        ],

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

        // Show Identification and FSR only in edit/view mode and when responsibleParty is "OEM"
        if (widget.mode != CMScreenModeEnum.create && 
            controllers['responsible_party']!.text.trim().toUpperCase() == 'OEM') ...[
          // Identification Photo
          ImageUploadField(
            label: "Identification",
            placeholder: "Add a Photo",
            isRequired: widget.mode == CMScreenModeEnum.edit,
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
                  encodedData,
                  'Identification',
                  (photoId) {
                    _originalIdentificationPhotoId = photoId;
                  },
                );
              }
            },
            externalImageUrl: identificationPhotoByteData,
            isDisabled: widget.mode == CMScreenModeEnum.view,
          ),
          getHeight(15),

          // FSR Attachment (file attachment, not photo)
          CustomFileUploadNew(
            label: "FSR",
            placeholder: "Upload File",
            isRequired: widget.mode == CMScreenModeEnum.edit,
            uploadedFiles: _fsrAttachments,
            serverAttachmentName: _fsrAttachmentName != null && 
                _fsrAttachmentName!.trim().isNotEmpty
                ? _fsrAttachmentName!.trim()
                : null,
            serverAttachmentId: _fsrAttachmentId != null && 
                _fsrAttachmentId != 0
                ? _fsrAttachmentId
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
            onFileSelected: (File? file) {
              if (file != null) {
                setState(() {
                  // Clear existing FSR attachment info when new file is selected
                  _fsrAttachmentId = null;
                  _fsrAttachmentName = null;
                  // Clear existing attachments and add new one
                  _fsrAttachments.clear();
                  _fsrAttachments.add(file);
                  _hasFormDataChanges = true;
                });
              }
            },
            onFileDeleted: (File file) {
              setState(() {
                _fsrAttachments.remove(file);
                _hasFormDataChanges = true;
              });
            },
            isDisabled: widget.mode == CMScreenModeEnum.view,
          ),
          getHeight(15),
        ],

        // Show Time Stamp Photo only in edit and view mode
        if (widget.mode != CMScreenModeEnum.create) ...[
          // Time Stamp Photo
          ImageUploadField(
            label: "Time Stamp Photo",
            placeholder: "Add a Photo",
            isRequired: widget.mode == CMScreenModeEnum.edit,
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
                  encodedData,
                  'Time Stamp',
                  (photoId) {
                    _originalTimestampPhotoId = photoId;
                  },
                );
              }
            },
            externalImageUrl: timestampPhotoByteData,
            isDisabled: widget.mode == CMScreenModeEnum.view,
          ),
          getHeight(15),
        ],

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
            isRequired: _statusController.text.trim().toUpperCase() == 'CLOSED',
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
        CustomSubmitButtonV2(
          text: "Submit", 
          onPressed: _isSubmitting ? null : _validateAndSubmit,
          isLoading: _isSubmitting,
        ),
      ],
    );
  }

  /// Format date to dd/MM/yyyy format as required by API
  String _formatDateForApi(DateTime date) {
    return DateFormat('dd/MM/yyyy').format(date);
  }

  /// Format date string to dd/MM/yyyy format
  String _formatDateStringForApi(String? dateString) {
    if (dateString == null || dateString.isEmpty) {
      return _formatDateForApi(DateTime.now());
    }
    try {
      // Try to parse the date string
      DateTime date;
      if (dateString.contains('T')) {
        // ISO format
        date = DateTime.parse(dateString);
      } else if (dateString.contains('/')) {
        // Already in dd/MM/yyyy format
        return dateString;
      } else {
        // Try parsing as is
        date = DateTime.parse(dateString);
      }
      return _formatDateForApi(date);
    } catch (e) {
      Logger.errorLog('[CM] Error formatting date: $dateString, error: $e');
      return _formatDateForApi(DateTime.now());
    }
  }

  /// Upload all checklist images that have LOCAL_IMAGE_ID and replace with actual photo IDs
  Future<void> _uploadChecklistImagesAndUpdateIds(
    List<dynamic> checklistData,
  ) async {
    Logger.infoLog('[CM] Starting to upload checklist images...');
    
    // Helper function to upload a single image
    Future<String?> _uploadSingleImage(Map<String, dynamic> imageData, String context) async {
      final photoId = imageData['photo_id']?.toString() ?? imageData['photoId']?.toString();
      
      // Only upload if it's a LOCAL_IMAGE_ID
      if (photoId != 'LOCAL_IMAGE_ID' && (photoId == null || !photoId.startsWith('LOCAL_IMAGE_ID'))) {
        return null; // Not a local image, skip
      }
      
      try {
        // Get base64 image data
        var base64Image = imageData['image_data']?.toString();
        
        // If image_data is a data URL, extract the base64 part
        if (base64Image != null && base64Image.startsWith('data:image')) {
          final parts = base64Image.split(',');
          if (parts.length > 1) {
            base64Image = parts[1];
          }
        }
        
        if (base64Image == null || base64Image.isEmpty) {
          Logger.errorLog('[CM] No image_data found for LOCAL_IMAGE_ID in $context');
          return null;
        }
        
        Logger.infoLog('[CM] Uploading image for: $context');
        
        // Upload image using ImageUploadService
        final serverPhotoId = await ServiceLocator().imageUploadService.uploadImage(
          base64Image,
          ActivityTypeEnum.correctiveMaintenance,
          false, // not a selfie
          _selectedSite?.siteId.toString(),
        );
        
        if (serverPhotoId.isNotEmpty) {
          // Replace LOCAL_IMAGE_ID with actual server photo ID
          imageData['photo_id'] = serverPhotoId;
          imageData['photoId'] = serverPhotoId;
          
          Logger.infoLog('[CM] ✅ Image uploaded successfully. Photo ID: $serverPhotoId');
          return serverPhotoId;
        } else {
          Logger.errorLog('[CM] ❌ Failed to upload image - empty photo ID returned');
          return null;
        }
      } catch (e) {
        Logger.errorLog('[CM] ❌ Error uploading image: $e');
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

  /// Upload a photo immediately when selected (if online)
  Future<void> _uploadPhotoImmediately(
    File file,
    String base64Image,
    String photoName,
    Function(String) onPhotoIdReceived,
  ) async {
    try {
      // Check if online
      final isOnline = await ConnectivityHelper.isConnected();
      
      if (!isOnline) {
        Logger.infoLog('[CM] Device is offline - $photoName photo will be uploaded later');
        return;
      }
      
      Logger.infoLog('[CM] Uploading $photoName photo immediately (online mode)...');
      
      final serverPhotoId = await ServiceLocator().imageUploadService.uploadImage(
        base64Image,
        ActivityTypeEnum.correctiveMaintenance,
        false, // not a selfie
        _selectedSite?.siteId.toString(),
      );
      
      if (serverPhotoId.isNotEmpty) {
        onPhotoIdReceived(serverPhotoId);
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

  /// Upload the two new photo fields (Identification, Time Stamp) before main API call
  /// This method only uploads photos that haven't been uploaded yet (no photo ID set)
  /// Note: FSR is now handled as a file attachment, not a photo
  Future<void> _uploadAdditionalPhotos() async {
    Logger.infoLog('[CM] Starting to upload additional photos (Identification, Time Stamp)...');
    Logger.infoLog('[CM] Photo status - Identification: ${identificationPhoto != null ? "present" : "null"} (ID: $_originalIdentificationPhotoId), TimeStamp: ${timestampPhoto != null ? "present" : "null"} (ID: $_originalTimestampPhotoId)');
    
    // Upload Identification Photo (only if not already uploaded)
    if (identificationPhoto != null && (_originalIdentificationPhotoId == null || _originalIdentificationPhotoId.toString().trim().isEmpty)) {
      try {
        Logger.infoLog('[CM] Reading Identification photo bytes...');
        final bytes = await identificationPhoto!.readAsBytes();
        final base64Image = base64Encode(bytes);
        Logger.infoLog('[CM] Identification photo encoded, size: ${base64Image.length} chars');
        
        Logger.infoLog('[CM] Uploading Identification photo to server...');
        final serverPhotoId = await ServiceLocator().imageUploadService.uploadImage(
          base64Image,
          ActivityTypeEnum.correctiveMaintenance,
          false, // not a selfie
          _selectedSite?.siteId.toString(),
        );
        
        if (serverPhotoId.isNotEmpty) {
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
    
    // Note: FSR is now handled as a file attachment (uploaded with customer attachments via saveCustomerPhotoAndAttachments)
    
    // Upload Time Stamp Photo (only if not already uploaded)
    if (timestampPhoto != null && (_originalTimestampPhotoId == null || _originalTimestampPhotoId.toString().trim().isEmpty)) {
      try {
        Logger.infoLog('[CM] Reading Time Stamp photo bytes...');
        final bytes = await timestampPhoto!.readAsBytes();
        final base64Image = base64Encode(bytes);
        Logger.infoLog('[CM] Time Stamp photo encoded, size: ${base64Image.length} chars');
        
        Logger.infoLog('[CM] Uploading Time Stamp photo to server...');
        final serverPhotoId = await ServiceLocator().imageUploadService.uploadImage(
          base64Image,
          ActivityTypeEnum.correctiveMaintenance,
          false, // not a selfie
          _selectedSite?.siteId.toString(),
        );
        
        if (serverPhotoId.isNotEmpty) {
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
    
    Logger.infoLog('[CM] Additional photos upload completed. Final IDs - Identification: $_originalIdentificationPhotoId, TimeStamp: $_originalTimestampPhotoId');
  }

  Future<void> _uploadImpactedItemImagesAndUpdateIds(
    List<Map<String, dynamic>> impactedItemList,
  ) async {
    Logger.infoLog('[CM] Starting to upload impacted item images...');
    
    // Helper function to upload a single image
    Future<String?> _uploadSingleImage(Map<String, dynamic> imageData, String context) async {
      final photoId = imageData['photoId']?.toString() ?? 
                     imageData['photo_id']?.toString();
      
      // Only upload if it's a LOCAL_IMAGE_ID
      if (photoId != 'LOCAL_IMAGE_ID' && (photoId == null || !photoId.startsWith('LOCAL_IMAGE_ID'))) {
        return null; // Not a local image, skip
      }
      
      try {
        // Get base64 image data - check both camelCase and snake_case
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
          Logger.errorLog('[CM] No imageData/image_data found for LOCAL_IMAGE_ID in $context');
          return null;
        }
        
        Logger.infoLog('[CM] Uploading impacted item image for: $context');
        
        // Upload image using ImageUploadService
        final serverPhotoId = await ServiceLocator().imageUploadService.uploadImage(
          base64Image,
          ActivityTypeEnum.correctiveMaintenance,
          false, // not a selfie
          _selectedSite?.siteId.toString(),
        );
        
        if (serverPhotoId.isNotEmpty) {
          // Replace LOCAL_IMAGE_ID with actual server photo ID (update both field names)
          imageData['photoId'] = serverPhotoId;
          imageData['photo_id'] = serverPhotoId;
          
          Logger.infoLog('[CM] ✅ Impacted item image uploaded successfully. Photo ID: $serverPhotoId');
          return serverPhotoId;
        } else {
          Logger.errorLog('[CM] ❌ Failed to upload impacted item image - empty photo ID returned');
          return null;
        }
      } catch (e) {
        Logger.errorLog('[CM] ❌ Error uploading impacted item image: $e');
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
    for (var impactedItem in _impactedItemList) {
      // Get the parent mstId from childItemResponses (they all reference the same parent)
      final childItemResponses = impactedItem['childItemResponses'] as List<dynamic>? ?? 
                                 impactedItem['child_item_responses'] as List<dynamic>? ?? [];
      if (childItemResponses.isNotEmpty) {
        final firstChild = childItemResponses.first as Map<String, dynamic>?;
        if (firstChild != null) {
          // Use parent_cm_check_list_mst_id for grouping, fallback to cm_check_list_mst_id
          final parentMstId = firstChild['parentCmCheckListMstId'] as int? ?? 
                            firstChild['parent_cm_check_list_mst_id'] as int? ??
                            firstChild['cmCheckListMstId'] as int? ?? 
                            firstChild['cm_check_list_mst_id'] as int?;
          if (parentMstId != null) {
            if (!impactedItemsByParentMstId.containsKey(parentMstId)) {
              impactedItemsByParentMstId[parentMstId] = [];
            }
            impactedItemsByParentMstId[parentMstId]!.add(impactedItem);
          }
        }
      }
    }
    
    Logger.infoLog('[CM] Grouped impacted items by parent MstId: ${impactedItemsByParentMstId.keys.toList()}');
    
    for (var item in checklistData) {
      final Map<String, dynamic> checklistItem = Map<String, dynamic>.from(item);
      
      // Get the checklist mstId first (needed for checking impacted items)
      final checklistMstId = checklistItem['cm_check_list_mst_id'] as int? ?? 
                            checklistItem['cmCheckListMstId'] as int? ??
                            checklistItem['item_type_id'] as int?;
      
      // Check if this checklist item has impacted items
      final hasImpactedItems = checklistMstId != null && impactedItemsByParentMstId.containsKey(checklistMstId);
      
      // Get response value based on resp_type
      dynamic respValue;
      final respType = checklistItem['resp_type']?.toString() ?? '';
      
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
      if (respValue == null || (respValue is String && respValue.isEmpty)) {
        // Don't skip if:
        // 1. It's a checkbox type (even if unchecked)
        // 2. It's a DYNAMIC_DROPDOWN with impacted items
        // 3. It's a MULTI_DYNAMIC_DROPDOWN with impacted items
        // 4. It's a DYNAMIC_NUMERIC with images (images are the actual response)
        if (respType != 'CHECKBOX' && 
            respType != 'CHECKBOX_NUMERIC' && 
            respType != 'CHECKBOX_TEXT' &&
            !(respType == 'DYNAMIC_DROPDOWN' && hasImpactedItems) &&
            !(respType == 'MULTI_DYNAMIC_DROPDOWN' && hasImpactedItems) &&
            !(respType == 'DYNAMIC_NUMERIC' && hasImages)) {
          continue; // Skip items without responses
        }
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
      
      // Add impacted items if this checklist item has any
      if (checklistMstId != null && impactedItemsByParentMstId.containsKey(checklistMstId)) {
        final impactedItemsForThisParent = impactedItemsByParentMstId[checklistMstId]!;
        final transformedImpactedItems = <Map<String, dynamic>>[];
        
        for (var impactedItem in impactedItemsForThisParent) {
          final transformedItemsList = _transformImpactedItemToApiFormat(impactedItem, location);
          transformedImpactedItems.addAll(transformedItemsList);
        }
        
        if (transformedImpactedItems.isNotEmpty) {
          transformedItem['cmImpactedItemList'] = transformedImpactedItems;
          Logger.infoLog('[CM] Added ${transformedImpactedItems.length} impacted items to checklist item with mstId: $checklistMstId');
        }
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
    
    // Nature of Failure - always required
    if (controllers['nature_of_failure']!.text.trim().isEmpty) {
      errors.add('Nature of Failure is required');
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
    
    // Customer Name - always required
    if (controllers['customer_name']!.text.trim().isEmpty) {
      errors.add('Customer Name is required');
    }
    
    // Contact No - always required
    if (controllers['contact_no']!.text.trim().isEmpty) {
      errors.add('Contact No. is required');
    }
    
    // Edit/View mode specific validations
    if (widget.mode == CMScreenModeEnum.edit || widget.mode == CMScreenModeEnum.view) {
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
      
      // Status - required in edit mode
      if (widget.mode == CMScreenModeEnum.edit && _statusController.text.trim().isEmpty) {
        errors.add('Status is required');
      }
      
      // Remarks - required in edit mode when status is "Closed"
      if (widget.mode == CMScreenModeEnum.edit && 
          _statusController.text.trim().toUpperCase() == 'CLOSED' &&
          _remarksController.text.trim().isEmpty) {
        errors.add('Remarks is required when Status is Closed');
      }
      
      // Photo and attachment validations for edit mode
      if (widget.mode == CMScreenModeEnum.edit) {
        final responsibleParty = controllers['responsible_party']!.text.trim().toUpperCase();
        
        // If responsibleParty is "OEM", Identification, FSR, and Time Stamp Photo are required
        if (responsibleParty == 'OEM') {
          // Check Identification Photo
          if (identificationPhoto == null && 
              (identificationPhotoByteData.isEmpty || 
               _originalIdentificationPhotoId == null || 
               _originalIdentificationPhotoId.toString().trim().isEmpty)) {
            errors.add('Identification is required when Category is OEM');
          }
          
          // Check FSR Attachment
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
      
      // Remarks attachment - required in edit mode
      // Check if there's either a new attachment or an existing server attachment
      if (widget.mode == CMScreenModeEnum.edit && 
          _remarksAttachments.isEmpty && 
          (_remarksAttachmentId == null || _remarksAttachmentId == 0)) {
        errors.add('Remarks attachment is required');
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

  Future<void> _validateAndSubmit({bool shouldNavigate = true}) async {
    // Prevent duplicate submissions
    if (_isSubmitting) {
      Logger.infoLog('[CM] Submission already in progress - ignoring duplicate call');
      return;
    }
    
    Logger.infoLog('[CM] _validateAndSubmit called - mode: ${widget.mode}');
    
    // Validate all required fields before submission
    final isValid = _validateRequiredFields();
    Logger.infoLog('[CM] Validation result: $isValid');
    
    if (!isValid) {
      Logger.errorLog('[CM] Validation failed - stopping submission');
      return; // Stop submission if validation fails
    }
    
    Logger.infoLog('[CM] Validation passed - proceeding with submission');
    
    // Set submitting flag
    _isSubmitting = true;
    
    try {
    if (widget.mode == CMScreenModeEnum.create) {
      await _submitFormData(shouldNavigate: shouldNavigate);
    } else if (widget.mode == CMScreenModeEnum.edit) {
      await _editFormData(shouldNavigate: shouldNavigate);
      }
    } finally {
      // Reset submitting flag
      _isSubmitting = false;
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
      
      // Set OEM Representative Contact with correct key for edit mode
      if (controllers['oem_representative_contact']!.text.trim().isNotEmpty) {
        requestData['oemRepresentativeContactNo'] = controllers['oem_representative_contact']!.text;
      }
      
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
          requestData['end_dt'] = _formatDateForApi(closureDate);
          requestData['no_of_days'] = daysDifference > 0 ? daysDifference : 0;
        } catch (e) {
          Logger.errorLog("Error parsing closure date: $e");
        }
      }
      requestData['start_dt'] = _formatDateForApi(DateTime.now());
      
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
      
      // Upload additional photos (Identification, FSR, Time Stamp) first
      await _uploadAdditionalPhotos();
      
      // Add the two new photo IDs to requestData (after upload)
      Logger.infoLog('[CM] Adding additional photo IDs to requestData (edit mode) - Identification: $_originalIdentificationPhotoId, TimeStamp: $_originalTimestampPhotoId');
      
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
      
      // Add FSR attachment info (file attachment, not photo)
      if (_fsrAttachmentId != null && _fsrAttachmentId != 0) {
        requestData['fsrAttachmentId'] = _fsrAttachmentId;
        Logger.infoLog('[CM] ✅ Added fsrAttachmentId to requestData: $_fsrAttachmentId');
        if (_fsrAttachmentName != null && _fsrAttachmentName!.trim().isNotEmpty) {
          requestData['fsrAttachmentName'] = _fsrAttachmentName;
          Logger.infoLog('[CM] ✅ Added fsrAttachmentName to requestData: $_fsrAttachmentName');
        } else if (_fsrAttachments.isNotEmpty) {
          final attachmentName = _fsrAttachments.first.path.split('/').last;
          requestData['fsrAttachmentName'] = attachmentName;
          Logger.infoLog('[CM] ✅ Added fsrAttachmentName to requestData: $attachmentName');
        }
      } else if (_fsrAttachments.isNotEmpty) {
        // FSR attachment was selected but not yet uploaded - will be uploaded with customer attachments
        final attachmentName = _fsrAttachments.first.path.split('/').last;
        requestData['fsrAttachmentName'] = attachmentName;
        Logger.infoLog('[CM] ⚠️ FSR attachment selected but not uploaded yet, adding name: $attachmentName');
      } else {
        Logger.infoLog('[CM] ⚠️ FSR attachment is null or empty - not adding to requestData');
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
          Toastbar.showErrorToastbar(
            ExceptionConstants.UNABLE_TO_GET_LOCATION,
            context,
          );
          return;
        }
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
      
      Logger.infoLog('[CM] Final processedData keys: ${processedData.keys.toList()}');
      
      // Impacted items are now nested inside cmCheckListSiteRespList, so no need for separate top-level field
      // Remove any top-level impacted item list if it exists
      processedData.remove('cmImpactedItemList');
      processedData.remove('CmImpactedItemList');
      Logger.infoLog('[CM] Removed top-level impacted item list - they are now nested inside checklist items');
      
      await ServiceLocator().cmRepository.createCorrectiveMaintenance(
        processedData,
      );

      Logger.debugLog(" processedData: $processedData");

      // Only upload photo/attachment if they were actually changed (new files selected)
      // In edit mode, if customerPhoto is null and _uploadedAttachments is empty,
      // it means they weren't changed, so we should preserve them by not calling this method
      final hasNewPhoto = customerPhoto != null;
      final hasNewAttachment = _uploadedAttachments.isNotEmpty;
      final hasNewFsrAttachment = _fsrAttachments.isNotEmpty;
      
      if (hasNewPhoto || hasNewAttachment || hasNewFsrAttachment) {
        Logger.infoLog('[CM] Uploading changed photo/attachment - Photo: $hasNewPhoto, Attachment: $hasNewAttachment, FSR: $hasNewFsrAttachment');
        await ServiceLocator().cmRepository.saveCustomerPhotoAndAttachments(
          cmSiteReqId!,
          customerPhoto, // Will be null if not changed, which is fine - API won't update it
          _uploadedAttachments.firstOrNull, // Will be null if not changed, which is fine - API won't update it
          _fsrAttachments.firstOrNull, // FSR attachment
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
      if (shouldNavigate && mounted) {
        Future.microtask(() {
          navigateBackOrToHome(
            context,
            targetContext: widget.parentContext ?? context,
          );
        });
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
      
      // Add the two new photo IDs (Identification and Time Stamp)
      if (_originalIdentificationPhotoId != null && _originalIdentificationPhotoId.toString().trim().isNotEmpty) {
        requestData['identificationImgId'] = _originalIdentificationPhotoId;
      }
      
      if (_originalTimestampPhotoId != null && _originalTimestampPhotoId.toString().trim().isNotEmpty) {
        requestData['timestampImgId'] = _originalTimestampPhotoId;
      }
      
      // Upload FSR attachment if provided (file attachment, not photo)
      String? fsrAttachmentId;
      if (_fsrAttachments.isNotEmpty) {
        fsrAttachmentId = await _uploadImageWithOfflineSupport(
          _fsrAttachments.first,
          ActivityTypeEnum.correctiveMaintenance,
        );
        if (fsrAttachmentId != null && fsrAttachmentId.isNotEmpty) {
          _fsrAttachmentId = int.tryParse(fsrAttachmentId) ?? fsrAttachmentId;
          _fsrAttachmentName = _fsrAttachments.first.path.split('/').last;
          Logger.infoLog('[CM] ✅ FSR attachment uploaded. ID: $_fsrAttachmentId, Name: $_fsrAttachmentName');
        }
      }
      
      // Add FSR attachment info to request data
      if (fsrAttachmentId != null && fsrAttachmentId.isNotEmpty) {
        requestData['fsrAttachmentId'] = fsrAttachmentId;
        requestData['fsrAttachmentName'] = _fsrAttachmentName ?? _fsrAttachments.first.path.split('/').last;
        // Store original file path and name for offline sync
        if (_fsrAttachments.isNotEmpty) {
          final originalFile = _fsrAttachments.first;
          requestData['fsr_original_file_path'] = originalFile.path;
          requestData['fsr_original_file_name'] = originalFile.path.split('/').last;
        }
        Logger.infoLog('[CM] ✅ Added FSR attachment to requestData - ID: $fsrAttachmentId, Name: ${requestData['fsrAttachmentName']}');
      } else if (_fsrAttachmentId != null && _fsrAttachmentId != 0) {
        // Preserve existing FSR attachment ID if not changed
        requestData['fsrAttachmentId'] = _fsrAttachmentId;
        if (_fsrAttachmentName != null && _fsrAttachmentName!.trim().isNotEmpty) {
          requestData['fsrAttachmentName'] = _fsrAttachmentName;
        }
        Logger.infoLog('[CM] ✅ Preserved existing FSR attachment in requestData - ID: $_fsrAttachmentId, Name: $_fsrAttachmentName');
      } else if (_fsrAttachments.isNotEmpty) {
        // FSR attachment was selected but upload failed - still add name
        requestData['fsrAttachmentName'] = _fsrAttachments.first.path.split('/').last;
        // Store original file path and name for offline sync
        final originalFile = _fsrAttachments.first;
        requestData['fsr_original_file_path'] = originalFile.path;
        requestData['fsr_original_file_name'] = originalFile.path.split('/').last;
        Logger.infoLog('[CM] ⚠️ FSR attachment selected but upload failed, adding name only: ${requestData['fsrAttachmentName']}');
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
        if (shouldNavigate && mounted) {
          Future.microtask(() {
            navigateBackOrToHome(
              context,
              targetContext: widget.parentContext ?? context,
            );
          });
        }
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
          requestData['end_dt'] = _formatDateForApi(closureDate);
          requestData['no_of_days'] = daysDifference > 0 ? daysDifference : 0;
        } catch (e) {
          Logger.errorLog("Error parsing closure date: $e");
        }
      }
      requestData['start_dt'] = _formatDateForApi(DateTime.now());
      
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
      
      // Upload additional photos (Identification, FSR, Time Stamp) first
      await _uploadAdditionalPhotos();
      
      // Add the two new photo IDs to requestData (after upload, before online/offline decision)
      Logger.infoLog('[CM] Adding additional photo IDs to requestData (create mode) - Identification: $_originalIdentificationPhotoId, TimeStamp: $_originalTimestampPhotoId');
      
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
      
      // Add FSR attachment info (file attachment, not photo)
      if (_fsrAttachmentId != null && _fsrAttachmentId != 0) {
        requestData['fsrAttachmentId'] = _fsrAttachmentId;
        Logger.infoLog('[CM] ✅ Added fsrAttachmentId to requestData: $_fsrAttachmentId');
        if (_fsrAttachmentName != null && _fsrAttachmentName!.trim().isNotEmpty) {
          requestData['fsrAttachmentName'] = _fsrAttachmentName;
          Logger.infoLog('[CM] ✅ Added fsrAttachmentName to requestData: $_fsrAttachmentName');
        } else if (_fsrAttachments.isNotEmpty) {
          final attachmentName = _fsrAttachments.first.path.split('/').last;
          requestData['fsrAttachmentName'] = attachmentName;
          Logger.infoLog('[CM] ✅ Added fsrAttachmentName to requestData: $attachmentName');
        }
      } else if (_fsrAttachments.isNotEmpty) {
        // FSR attachment was selected but not yet uploaded - will be uploaded with customer attachments
        final attachmentName = _fsrAttachments.first.path.split('/').last;
        requestData['fsrAttachmentName'] = attachmentName;
        Logger.infoLog('[CM] ⚠️ FSR attachment selected but not uploaded yet, adding name: $attachmentName');
      } else {
        Logger.infoLog('[CM] ⚠️ FSR attachment is null or empty - not adding to requestData');
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
      // Convert keys to camelCase for API
      Map<String, dynamic> processedData =
          DataTransformationHelper.convertKeysToCamelCase(requestData);
      
      Logger.infoLog('[CM] Final processedData keys (create): ${processedData.keys.toList()}');
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
        
        // Upload customer photo and attachments after creating the ticket
        // Upload customer photo, customer attachment, and FSR attachment
        if (customerPhoto != null || _uploadedAttachments.isNotEmpty || _fsrAttachments.isNotEmpty) {
          await ServiceLocator().cmRepository.saveCustomerPhotoAndAttachments(
            cmSiteReqId,
            customerPhoto,
            _uploadedAttachments.isNotEmpty ? _uploadedAttachments.first : null,
            _fsrAttachments.isNotEmpty ? _fsrAttachments.first : null,
          );
          Logger.infoLog("CM customer photo, attachment, and FSR attachment uploaded successfully");
        }
      }

      Toastbar.showSuccessToastbar("Form Submitted Successfully", context);
      if (shouldNavigate && mounted) {
        Future.microtask(() {
          navigateBackOrToHome(
            context,
            targetContext: widget.parentContext ?? context,
          );
        });
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
      
      // Add FSR attachment info (file attachment, not photo)
      if (_fsrAttachmentId != null && _fsrAttachmentId != 0) {
        requestData['fsrAttachmentId'] = _fsrAttachmentId;
        Logger.infoLog('[CM] ✅ Added fsrAttachmentId: $_fsrAttachmentId');
        if (_fsrAttachmentName != null && _fsrAttachmentName!.trim().isNotEmpty) {
          requestData['fsrAttachmentName'] = _fsrAttachmentName;
          Logger.infoLog('[CM] ✅ Added fsrAttachmentName: $_fsrAttachmentName');
        } else if (_fsrAttachments.isNotEmpty) {
          final attachmentName = _fsrAttachments.first.path.split('/').last;
          requestData['fsrAttachmentName'] = attachmentName;
          Logger.infoLog('[CM] ✅ Added fsrAttachmentName: $attachmentName');
        }
      } else if (_fsrAttachments.isNotEmpty) {
        // FSR attachment was selected but not yet uploaded
        final attachmentName = _fsrAttachments.first.path.split('/').last;
        requestData['fsrAttachmentName'] = attachmentName;
        // Store original file path and name for offline sync
        final originalFile = _fsrAttachments.first;
        requestData['fsr_original_file_path'] = originalFile.path;
        requestData['fsr_original_file_name'] = originalFile.path.split('/').last;
        Logger.infoLog('[CM] ⚠️ FSR attachment selected but not uploaded yet, adding name: $attachmentName');
      } else {
        Logger.infoLog('[CM] ⚠️ FSR attachment is null or empty - not adding to requestData');
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
        if (shouldNavigate && mounted) {
          Future.microtask(() {
            navigateBackOrToHome(
              context,
              targetContext: widget.parentContext ?? context,
            );
          });
        }
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
      navigateBackOrToHome(
        context,
        targetContext: widget.parentContext ?? context,
      );
    }
  }
}