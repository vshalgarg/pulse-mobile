import 'dart:io';

import 'package:app/commonWidgets/custom_buttons/arrow_botton.dart';
import 'package:app/constants/constants_methods.dart';
import 'package:app/screens/asset_audit/asset_audit_telecom/extinguisher_screen.dart';
import 'package:app/screens/asset_audit/asset_audit_telecom/dg_screen.dart';
import 'package:app/screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';
import '../../../models/asset_audit_model.dart';
import '../../../models/asset_audit_post_model.dart';
import '../../../utils/asset_audit_post_helper.dart';
import '../../../utils/asset_audit_photo_upload_helper.dart';
import '../../../bloc/asset_audit_cubit.dart';
import '../../../bloc/asset_audit_state.dart';

import '../../../commonWidgets/asset_type_card.dart';
import '../../../commonWidgets/custom_dialogs/success_dialog.dart';
import '../../../commonWidgets/custom_dialogs/unsaved_changes_dialog.dart';
import '../../../commonWidgets/custom_form_appbar.dart';
import '../../../commonWidgets/custom_form_field.dart';
import '../../../commonWidgets/custom_image_upload_field.dart';
import '../../../commonWidgets/custom_radio_options.dart';
import '../../../commonWidgets/custom_remark.dart';
import '../../../commonWidgets/qr_screen_form_field.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_images.dart';
import '../../../constants/constants_strings.dart';
import '../../../commonWidgets/base64_image_widget.dart';
import '../../../repositories/image_repository.dart';
import '../../../services/api_provider.dart';
import '../../../app_config.dart';

class SMPSScreen extends StatefulWidget {
  final CategoryData? smpsData;
  final AssetAuditModel? assetAuditData;
  final bool showSuccessMessage; // Flag to show success message
  final String? ticketId; // Ticket ID from TicketScreen

  // Data from previous screens in the flow
  final List<Map<String, dynamic>>? extinguisherItems;
  final List<Map<String, dynamic>>? fencingItems;
  final List<Map<String, dynamic>>? dgItems;
  final List<Map<String, dynamic>>? solarPlatesItems;

  const SMPSScreen({
    super.key,
    this.smpsData,
    this.assetAuditData,
    this.showSuccessMessage = false, // Default to false
    this.ticketId, // Ticket ID from TicketScreen
    this.extinguisherItems,
    this.fencingItems,
    this.dgItems,
    this.solarPlatesItems,
  });

  @override
  State<SMPSScreen> createState() => _SMPSScreenState();
}

class _SMPSScreenState extends State<SMPSScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController serialController = TextEditingController();
  String? selectedFile;
  String? selectedStatus;
  String? selectedBatteryStatus;
  String? selectedType;
  bool hasUnsavedChanges = false;
  bool showValidationErrors = false; // Control when to show validation errors
  int totalRectifierItems = 6; // Total rectifier items to scan
  int totalMPPTItems = 6; // Total MPPT items to scan
  int currentScannedItems = 0; // Number of items already scanned
  List<Map<String, dynamic>> savedRectifierItems =
      []; // List to store saved rectifier items
  List<Map<String, dynamic>> savedMPPTItems =
      []; // List to store saved MPPT items
  List<Map<String, dynamic>> savedACDBItems =
      []; // List to store saved ACDB items
  List<Map<String, dynamic>> savedLSPUItems =
      []; // List to store saved LSPU items
  Map<String, dynamic> currentFormData = {}; // Current form data
  String? uploadedPhotoPath;

  // AssetTypeCard field values for Rectifier
  String? rectifierSerialNumber;
  String? rectifierPhoto;
  int? rectifierPhotoId; // Store the photoId from API
  String? rectifierStatus;

  // Separate controllers for each section to avoid conflicts
  final rectifierRemarksController = TextEditingController();
  final mpptRemarksController = TextEditingController();
  final generalRemarksController = TextEditingController();

  // AssetTypeCard field values for MPPT
  String? mpptSerialNumber;
  String? mpptPhoto;
  int? mpptPhotoId; // Store the photoId from API
  String? mpptStatus;

  // AssetTypeCard field values for ACDB
  String? acdbSerialNumber;
  String? acdbPhoto;
  int? acdbPhotoId; // Store the photoId from API
  String? acdbStatus;

  // AssetTypeCard field values for LSPU
  String? lspuSerialNumber;
  String? lspuPhoto;
  int? lspuPhotoId; // Store the photoId from API
  String? lspuStatus;

  // Controllers for CustomInfoCard
  final TextEditingController rectifierSerialController =
      TextEditingController();
  final TextEditingController mpptSerialController = TextEditingController();
  final TextEditingController acdbSerialController = TextEditingController();
  final TextEditingController lspuSerialController = TextEditingController();

  // Keys to force rebuild of CustomInfoCard widgets
  int rectifierCardKey = 0;
  int mpptCardKey = 0;
  int acdbCardKey = 0;
  int lspuCardKey = 0;

  // Flag to track if SMPS screen has posted data
  bool _hasPostedSMPSData = false;

  // Ticket ID from backend for final submission
  String? _ticketId;

  // Image service for fetching images from API
  late ImageRepository _imageService;
  
  // Cache for storing fetched images
  Map<int, String> _imageCache = {};
  
  // Loading state for images
  Set<int> _loadingImages = {};

  void _navigateToHomeScreen() {
    print('SMPS Screen: Navigating to home screen');
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const HomeScreen()),
      (route) => false, // Remove all previous routes
    );
  }

  /// Get asset audit site response ID from GET API response for a specific item type
  int _getAssetAuditSiteRespId(String itemType) {
    print('=== SMPS Screen: Getting AssetAuditSiteRespId for $itemType ===');

    if (widget.smpsData == null) {
      print('SMPS Screen: smpsData is null, returning default ID');
      return 0; // Default ID
    }

    print('SMPS Screen: smpsData is not null, searching for $itemType...');

    // Debug: Print all available data structures
    print('SMPS Screen: Available data structures:');
    print('  - assets: ${widget.smpsData!.assets?.length ?? 0} items');
    print(
      '  - smpsRectifiers: ${widget.smpsData!.smpsRectifiers?.length ?? 0} items',
    );
    print('  - smpsMppt: ${widget.smpsData!.smpsMppt?.length ?? 0} items');
    print(
      '  - smpsCabinet: ${widget.smpsData!.smpsCabinet?.length ?? 0} items',
    );
    print('  - acdb: ${widget.smpsData!.acdb?.length ?? 0} items');
    print('  - lspu: ${widget.smpsData!.lspu?.length ?? 0} items');
    print('  - remarks: ${widget.smpsData!.remarks?.length ?? 0} items');

    // First check in assets
    final smpsAssets = widget.smpsData!.assets ?? [];
    if (smpsAssets.isNotEmpty) {
      print(
        'SMPS Screen: Found ${smpsAssets.length} assets in CategoryData.assets',
      );
      for (var asset in smpsAssets) {
        print(
          'SMPS Screen: Asset: ${asset.itemType} - ID: ${asset.assetAuditSiteRespId}',
        );
        if (asset.assetAuditSiteRespId != null &&
            asset.assetAuditSiteRespId! > 0) {
          print(
            'SMPS Screen: Found valid assetAuditSiteRespId: ${asset.assetAuditSiteRespId}',
          );
          return asset.assetAuditSiteRespId!;
        }
      }
    } else {
      print('SMPS Screen: No assets found in CategoryData.assets');
    }

    // Check specific subcategory helper methods
    if (itemType == 'SMPS Rectifiers') {
      final smpsRectifierItems = widget.smpsData!.smpsRectifiers;
      if (smpsRectifierItems != null && smpsRectifierItems.isNotEmpty) {
        final firstItem = smpsRectifierItems.first;
        print(
          'SMPS Screen: SMPS Rectifier first item - ID: ${firstItem.assetAuditSiteRespId}',
        );
        if (firstItem.assetAuditSiteRespId != null &&
            firstItem.assetAuditSiteRespId! > 0) {
          print(
            'SMPS Screen: Found valid assetAuditSiteRespId in SMPS Rectifiers: ${firstItem.assetAuditSiteRespId}',
          );
          return firstItem.assetAuditSiteRespId!;
        }
      }
    } else if (itemType == 'SMPS MPPT') {
      final smpsMpptItems = widget.smpsData!.smpsMppt;
      if (smpsMpptItems != null && smpsMpptItems.isNotEmpty) {
        final firstItem = smpsMpptItems.first;
        print(
          'SMPS Screen: SMPS MPPT first item - ID: ${firstItem.assetAuditSiteRespId}',
        );
        if (firstItem.assetAuditSiteRespId != null &&
            firstItem.assetAuditSiteRespId! > 0) {
          print(
            'SMPS Screen: Found valid assetAuditSiteRespId in SMPS MPPT: ${firstItem.assetAuditSiteRespId}',
          );
          return firstItem.assetAuditSiteRespId!;
        }
      }
    } else if (itemType == 'SMPS Cabinet') {
      final smpsCabinetItems = widget.smpsData!.smpsCabinet;
      if (smpsCabinetItems != null && smpsCabinetItems.isNotEmpty) {
        final firstItem = smpsCabinetItems.first;
        print(
          'SMPS Screen: SMPS Cabinet first item - ID: ${firstItem.assetAuditSiteRespId}',
        );
        if (firstItem.assetAuditSiteRespId != null &&
            firstItem.assetAuditSiteRespId! > 0) {
          print(
            'SMPS Screen: Found valid assetAuditSiteRespId in SMPS Cabinet: ${firstItem.assetAuditSiteRespId}',
          );
          return firstItem.assetAuditSiteRespId!;
        }
      }
    } else if (itemType == 'ACDB') {
      final acdbItems = widget.smpsData!.acdb;
      if (acdbItems != null && acdbItems.isNotEmpty) {
        final firstItem = acdbItems.first;
        print(
          'SMPS Screen: ACDB first item - ID: ${firstItem.assetAuditSiteRespId}',
        );
        if (firstItem.assetAuditSiteRespId != null &&
            firstItem.assetAuditSiteRespId! > 0) {
          print(
            'SMPS Screen: Found valid assetAuditSiteRespId in ACDB: ${firstItem.assetAuditSiteRespId}',
          );
          return firstItem.assetAuditSiteRespId!;
        }
      }
    } else if (itemType == 'LSPU') {
      final lspuItems = widget.smpsData!.lspu;
      if (lspuItems != null && lspuItems.isNotEmpty) {
        final firstItem = lspuItems.first;
        print(
          'SMPS Screen: LSPU first item - ID: ${firstItem.assetAuditSiteRespId}',
        );
        if (firstItem.assetAuditSiteRespId != null &&
            firstItem.assetAuditSiteRespId! > 0) {
          print(
            'SMPS Screen: Found valid assetAuditSiteRespId in LSPU: ${firstItem.assetAuditSiteRespId}',
          );
          return firstItem.assetAuditSiteRespId!;
        }
      }
    }

    // If still not found, check remarks
    final remarks = widget.smpsData!.remarks;
    if (remarks.isNotEmpty) {
      print('SMPS Screen: Checking remarks for valid ID...');
      for (var remark in remarks) {
        print(
          'SMPS Screen: Remark: ${remark.itemType} - ID: ${remark.assetAuditSiteRespId}',
        );
        if (remark.assetAuditSiteRespId != null &&
            remark.assetAuditSiteRespId! > 0) {
          print(
            'SMPS Screen: Found valid assetAuditSiteRespId in remarks: ${remark.assetAuditSiteRespId}',
          );
          return remark.assetAuditSiteRespId!;
        }
      }
    } else {
      print('SMPS Screen: No remarks found');
    }

    print(
      'SMPS Screen: No valid assetAuditSiteRespId found, returning default ID',
    );
    return 0; // Default ID
  }

  /// Load ticket ID from backend data for final submission
  void _loadTicketIdFromBackend() {

    if (widget.ticketId != null && widget.ticketId!.isNotEmpty) {
      _ticketId = widget.ticketId;
      print('SMPS Screen: Using ticket ID from TicketScreen: $_ticketId');
      return;
    }

    // Priority 2: Try to get ticket ID from asset audit data
    if (widget.assetAuditData != null) {
      // Check if there's a ticket ID in the page header or response data
      if (widget.assetAuditData!.pageHeader.isNotEmpty) {
        final pageHeader = widget.assetAuditData!.pageHeader.first;

        // Create a meaningful ticket ID using available fields
        String ticketId = '';

        // Use site code if available
        if (pageHeader.siteCode.isNotEmpty) {
          ticketId += pageHeader.siteCode;
        }

        // Add site audit schedule ID
        if (pageHeader.siteAuditSchId != null) {
          if (ticketId.isNotEmpty) ticketId += '-';
          ticketId += 'SCH${pageHeader.siteAuditSchId}';
        }

        // Add site name if available (truncated to avoid too long IDs)
        if (pageHeader.siteName.isNotEmpty) {
          if (ticketId.isNotEmpty) ticketId += '-';
          String siteName = pageHeader.siteName.replaceAll(' ', '-');
          if (siteName.length > 20) {
            siteName = siteName.substring(0, 20);
          }
          ticketId += siteName;
        }

        if (ticketId.isNotEmpty) {
          _ticketId = ticketId;
          print('SMPS Screen: Created meaningful ticket ID: $_ticketId');
        } else {
          // Fallback to site audit schedule ID
          _ticketId = 'SITE-${pageHeader.siteAuditSchId}';
          print('SMPS Screen: Using fallback ticket ID: $_ticketId');
        }
      }

      // Also check response data for ticket information
      if (widget.assetAuditData!.responseData != null) {
        final responseData = widget.assetAuditData!.responseData;
        // You can add more logic here to extract ticket ID from response data if available
      }
    }

    // Priority 3: Generate a default ticket ID if none found
    if (_ticketId == null || _ticketId!.isEmpty) {
      final now = DateTime.now();
      _ticketId =
          'AUDIT-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
      print('SMPS Screen: Generated default ticket ID: $_ticketId');
    }

    print('SMPS Screen: Final ticket ID: $_ticketId');
    print('SMPS Screen: Ticket ID will be displayed in success dialog');
  }

  /// Get formatted ticket ID for display
  String get _formattedTicketId {
    if (_ticketId == null || _ticketId!.isEmpty) {
      return 'N/A';
    }

    // Format the ticket ID for better display
    String formatted = _ticketId!;

    // If it's a long ID, add some formatting
    if (formatted.length > 30) {
      formatted =
          '${formatted.substring(0, 15)}...${formatted.substring(formatted.length - 15)}';
    }

    return formatted;
  }

  // Method to get OEM name from API data
  String _getSMPSOEMName() {
    if (widget.smpsData != null) {
      // Try to get OEM name from SMPS assets first
      final smpsAssets = widget.smpsData!.assets;
      if (smpsAssets.isNotEmpty) {
        return smpsAssets.first.oemName ?? 'Exicom';
      }

      // Fallback to SMPS Rectifiers if assets not available
      final smpsRectifierItems = widget.smpsData!.smpsRectifiers ?? [];
      if (smpsRectifierItems.isNotEmpty) {
        return smpsRectifierItems.first.oemName ?? 'Exicom';
      }

      // Fallback to SMPS Cabinet if others not available
      final smpsCabinetItems = widget.smpsData!.smpsCabinet ?? [];
      if (smpsCabinetItems.isNotEmpty) {
        return smpsCabinetItems.first.oemName ?? 'Exicom';
      }
    }
    return 'Exicom'; // Default fallback
  }

  @override
  void initState() {
    super.initState();
    // Listen to form changes
    serialController.addListener(_onFormChanged);
    
    // Initialize image service - will be done in post frame callback

    print('=== SMPS Screen: initState ===');
    print(
      'SMPS Screen: widget.smpsData: ${widget.smpsData != null ? 'NOT NULL' : 'NULL'}',
    );
    print(
      'SMPS Screen: widget.assetAuditData: ${widget.assetAuditData != null ? 'NOT NULL' : 'NULL'}',
    );
    print(
      'SMPS Screen: widget.showSuccessMessage: ${widget.showSuccessMessage}',
    );

    // Load SMPS data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Initialize image service
      _imageService = ImageRepository(AppConfig.of(context).apiProvider);
      
      // Load SMPS data if available
      _loadSMPSData();

      // Show success message if coming from DG Screen
      if (widget.showSuccessMessage) {
        showCustomToast(context, '✅ DG data saved successfully!');
      }
    });

    print('=== SMPS Screen: initState Complete ===');
  }

  void _loadSMPSData() {
    print('=== SMPS Screen: Loading SMPS Data from Backend ===');

    if (widget.smpsData != null) {
      print('SMPS Screen: smpsData is NOT NULL');
      print('SMPS Screen: smpsData type: ${widget.smpsData.runtimeType}');

      setState(() {
        // Load ticket ID from backend data first
        _loadTicketIdFromBackend();
        print('SMPS Screen: Ticket ID loaded: $_ticketId');

        // Load SMPS assets data
        final smpsAssets = widget.smpsData!.assets;
        print('SMPS Screen: SMPS Assets count: ${smpsAssets.length}');
        if (smpsAssets.isNotEmpty) {
          print('--- SMPS Assets Details ---');
          for (int i = 0; i < smpsAssets.length; i++) {
            var item = smpsAssets[i];
            print('  Asset $i:');
            print('    - itemType: ${item.itemType}');
            print('    - nexgenSerialNo: ${item.nexgenSerialNo}');
            print('    - mfgSerialNo: ${item.mfgSerialNo}');
            print('    - assetStatus: ${item.assetStatus}');
            print('    - photoId: ${item.photoId}');
            print('    - capacity: ${item.capacity}');
            print('    - assetAuditSiteRespId: ${item.assetAuditSiteRespId}');
            print(
              '    - isFilled: ${item.assetStatus != null || item.photoId != null}',
            );
          }
        } else {
          print('SMPS Screen: No SMPS assets found');
        }

        // Load SMPS Rectifiers data
        final smpsRectifiersItems = widget.smpsData!.smpsRectifiers ?? [];
        print(
          'SMPS Screen: SMPS Rectifiers count: ${smpsRectifiersItems.length}',
        );
        if (smpsRectifiersItems.isNotEmpty) {
          print('--- SMPS Rectifiers Details ---');
          for (int i = 0; i < smpsRectifiersItems.length; i++) {
            var item = smpsRectifiersItems[i];
            print('  Rectifier $i:');
            print('    - itemType: ${item.itemType}');
            print('    - nexgenSerialNo: ${item.nexgenSerialNo}');
            print('    - mfgSerialNo: ${item.mfgSerialNo}');
            print('    - assetStatus: ${item.assetStatus}');
            print('    - photoId: ${item.photoId}');
            print('    - capacity: ${item.capacity}');
            print('    - assetAuditSiteRespId: ${item.assetAuditSiteRespId}');
            print(
              '    - isFilled: ${item.assetStatus != null || item.photoId != null}',
            );
          }
        } else {
          print('SMPS Screen: No SMPS Rectifiers found');
        }

        // Load SMPS MPPT data
        final smpsMpptItems = widget.smpsData!.smpsMppt ?? [];
        print('SMPS Screen: SMPS MPPT count: ${smpsMpptItems.length}');
        if (smpsMpptItems.isNotEmpty) {
          print('--- SMPS MPPT Details ---');
          for (int i = 0; i < smpsMpptItems.length; i++) {
            var item = smpsMpptItems[i];
            print('  MPPT $i:');
            print('    - itemType: ${item.itemType}');
            print('    - nexgenSerialNo: ${item.nexgenSerialNo}');
            print('    - mfgSerialNo: ${item.mfgSerialNo}');
            print('    - assetStatus: ${item.assetStatus}');
            print('    - photoId: ${item.photoId}');
            print('    - capacity: ${item.capacity}');
            print('    - assetAuditSiteRespId: ${item.assetAuditSiteRespId}');
            print(
              '    - isFilled: ${item.assetStatus != null || item.photoId != null}',
            );
          }
        } else {
          print('SMPS Screen: No SMPS MPPT found');
        }

        // Load SMPS Cabinet data
        final smpsCabinetItems = widget.smpsData!.smpsCabinet ?? [];
        print('SMPS Screen: SMPS Cabinet count: ${smpsCabinetItems.length}');
        if (smpsCabinetItems.isNotEmpty) {
          print('--- SMPS Cabinet Details ---');
          for (int i = 0; i < smpsCabinetItems.length; i++) {
            var item = smpsCabinetItems[i];
            print('  Cabinet $i:');
            print('    - itemType: ${item.itemType}');
            print('    - nexgenSerialNo: ${item.nexgenSerialNo}');
            print('    - mfgSerialNo: ${item.mfgSerialNo}');
            print('    - assetStatus: ${item.assetStatus}');
            print('    - photoId: ${item.photoId}');
            print('    - capacity: ${item.capacity}');
            print('    - assetAuditSiteRespId: ${item.assetAuditSiteRespId}');
            print(
              '    - isFilled: ${item.assetStatus != null || item.photoId != null}',
            );
          }
        } else {
          print('SMPS Screen: No SMPS Cabinet found');
        }

        // Load ACDB data
        final acdbItems = widget.smpsData!.acdb ?? [];
        print('SMPS Screen: ACDB count: ${acdbItems.length}');
        if (acdbItems.isNotEmpty) {
          print('--- ACDB Details ---');
          for (int i = 0; i < acdbItems.length; i++) {
            var item = acdbItems[i];
            print('  ACDB $i:');
            print('    - itemType: ${item.itemType}');
            print('    - nexgenSerialNo: ${item.nexgenSerialNo}');
            print('    - mfgSerialNo: ${item.mfgSerialNo}');
            print('    - assetStatus: ${item.assetStatus}');
            print('    - photoId: ${item.photoId}');
            print('    - capacity: ${item.capacity}');
            print('    - assetAuditSiteRespId: ${item.assetAuditSiteRespId}');
            print(
              '    - isFilled: ${item.assetStatus != null || item.photoId != null}',
            );
          }
        } else {
          print('SMPS Screen: No ACDB found');
        }

        // Load LSPU data
        final lspuItems = widget.smpsData!.lspu ?? [];
        print('SMPS Screen: LSPU count: ${lspuItems.length}');
        if (lspuItems.isNotEmpty) {
          print('--- LSPU Details ---');
          for (int i = 0; i < lspuItems.length; i++) {
            var item = lspuItems[i];
            print('  LSPU $i:');
            print('    - itemType: ${item.itemType}');
            print('    - nexgenSerialNo: ${item.nexgenSerialNo}');
            print('    - mfgSerialNo: ${item.mfgSerialNo}');
            print('    - assetStatus: ${item.assetStatus}');
            print('    - photoId: ${item.photoId}');
            print('    - capacity: ${item.capacity}');
            print('    - assetAuditSiteRespId: ${item.assetAuditSiteRespId}');
            print(
              '    - isFilled: ${item.assetStatus != null || item.photoId != null}',
            );
          }
        } else {
          print('SMPS Screen: No LSPU found');
        }

        // Load remarks and populate the CustomRemarksField
        final remarks = widget.smpsData!.remarks;
        print('SMPS Screen: Remarks count: ${remarks.length}');
        if (remarks.isNotEmpty) {
          print('--- SMPS Remarks Details ---');
          for (int i = 0; i < remarks.length; i++) {
            var remark = remarks[i];
            print('  Remark $i:');
            print('    - itemType: ${remark.itemType}');
            print('    - itemTypeRemark: ${remark.itemTypeRemark}');
            print('    - assetAuditSiteRespId: ${remark.assetAuditSiteRespId}');
            print('    - recordType: ${remark.recordType}');

            // Populate the CustomRemarksField with the first valid remark
            if (remark.itemTypeRemark != null &&
                remark.itemTypeRemark!.isNotEmpty) {
              generalRemarksController.text = remark.itemTypeRemark!;
              print(
                'SMPS Screen: Loaded remark from API: ${remark.itemTypeRemark}',
              );
              break; // Use the first valid remark
            }
          }
        } else {
          print('SMPS Screen: No remarks found');
        }

        // Load saved items from API - only items with complete data
        _loadSavedItemsFromAPI();

        // Load images for saved items
        _loadImagesForSavedItems();

        // Update total count based on actual data (but don't pre-populate saved items)
        totalRectifierItems =
            smpsAssets.length +
            smpsRectifiersItems.length +
            smpsMpptItems.length +
            smpsCabinetItems.length +
            acdbItems.length +
            lspuItems.length;

        print('=== SMPS Screen: Data Summary ===');
        print('SMPS Screen: Total expected items: $totalRectifierItems');
        print(
          'SMPS Screen: Assets: ${smpsAssets.length}, Rectifiers: ${smpsRectifiersItems.length}, MPPT: ${smpsMpptItems.length}, Cabinet: ${smpsCabinetItems.length}, ACDB: ${acdbItems.length}, LSPU: ${lspuItems.length}',
        );
        print('SMPS Screen: Remarks: ${remarks.length}');
        print('=== End SMPS Data Loading ===');
      });
    } else {
      print('SMPS Screen: smpsData is NULL - This is the problem!');
      print('SMPS Screen: Backend is not returning SMPS data');
    }
  }

  /// Load images for saved items using the image API
  void _loadImagesForSavedItems() async {
    print('=== SMPS Screen: Loading Images for Saved Items ===');
    
    // Collect all photo IDs from saved items
    Set<int> photoIds = {};
    
    // Add photo IDs from rectifier items
    for (var item in savedRectifierItems) {
      if (item['photoId'] != null) {
        photoIds.add(item['photoId']);
      }
    }
    
    // Add photo IDs from MPPT items
    for (var item in savedMPPTItems) {
      if (item['photoId'] != null) {
        photoIds.add(item['photoId']);
      }
    }
    
    // Add photo IDs from ACDB items
    for (var item in savedACDBItems) {
      if (item['photoId'] != null) {
        photoIds.add(item['photoId']);
      }
    }
    
    // Add photo IDs from LSPU items
    for (var item in savedLSPUItems) {
      if (item['photoId'] != null) {
        photoIds.add(item['photoId']);
      }
    }
    
    if (photoIds.isEmpty) {
      print('SMPS Screen: No photo IDs found to load images');
      return;
    }
    
    print('SMPS Screen: Loading ${photoIds.length} images...');
    
    try {
      // Mark images as loading
      setState(() {
        _loadingImages.addAll(photoIds);
      });
      
      // Fetch images from API
      final imageMap = await _imageService.fetchImagesByIds(photoIds.toList());
      
      // Update cache and remove loading state
      setState(() {
        _imageCache.addAll(imageMap);
        _loadingImages.removeAll(photoIds);
      });
      
      print('SMPS Screen: Successfully loaded ${imageMap.length} images');
    } catch (e) {
      print('SMPS Screen: Error loading images: $e');
      setState(() {
        _loadingImages.removeAll(photoIds);
      });
    }
  }

  /// Build photo column for saved items list
  Widget _buildPhotoColumn(Map<String, dynamic> item) {
    final photoId = item['photoId'];
    
    if (photoId == null) {
      return Icon(
        Icons.photo_camera_outlined,
        color: AppColors.greyColor,
        size: 20,
      );
    }
    
    // Check if image is loading
    if (_loadingImages.contains(photoId)) {
      return Container(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.green7),
        ),
      );
    }
    
    // Check if image is cached
    final imageData = _imageCache[photoId];
    if (imageData != null) {
      return GestureDetector(
        onTap: () => _showImageDialog(imageData),
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: AppColors.green7, width: 1),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Base64ImageWidget(
              base64Data: imageData,
              width: 30,
              height: 30,
              boxFit: BoxFit.cover,
            ),
          ),
        ),
      );
    }
    
    // Show camera icon if no image data
    return Icon(
      Icons.photo_camera,
      color: AppColors.green7,
      size: 20,
    );
  }

  /// Show image in full screen dialog
  void _showImageDialog(String imageData) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.8,
          height: MediaQuery.of(context).size.height * 0.6,
          child: Column(
            children: [
              AppBar(
                title: Text('Image View'),
                actions: [
                  IconButton(
                    icon: Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              Expanded(
                child: Base64ImageWidget(
                  base64Data: imageData,
                  boxFit: BoxFit.contain,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Load saved items from API - only items with complete data (serial, photo, status)
  void _loadSavedItemsFromAPI() {
    if (widget.smpsData == null) {
      print('SMPS Screen: No SMPS data available');
      return;
    }

    print('SMPS Screen: Loading saved items from API...');

    setState(() {
      // Clear existing saved items to avoid duplicates
      savedRectifierItems.clear();
      savedMPPTItems.clear();
      savedACDBItems.clear();
      savedLSPUItems.clear();
      currentScannedItems = 0;

      // Load SMPS assets (from assets array)
      final smpsAssets = widget.smpsData!.assets;
      print('SMPS Screen: Found ${smpsAssets.length} SMPS assets');

      for (var item in smpsAssets) {
        // Only add items that have complete data (serial, photo, status)
        if (item.mfgSerialNo != null &&
            item.photoId != null &&
            item.assetStatus != null) {
          Map<String, dynamic> savedItem = {
            'serialNumber':
                item.mfgSerialNo ?? item.nexgenSerialNo ?? 'Unknown',
            'photo': null,
            'photoId': item.photoId,
            'status': item.assetStatus ?? 'OK',
            'timestamp': DateTime.now(),
            'isQRCodeScanned': item.qrCodeScanned ?? false,
            'itemType': item.itemType ?? 'SMPS',
            'remarks': item.itemTypeRemark ?? 'SMPS Item',
            'assetStatus': item.assetStatus,
            'assetAuditSiteRespId': item.assetAuditSiteRespId,
            'capacity': item.capacity ?? 'N/A',

            // Full API response details
            'asset_audit_site_resp_id': item.assetAuditSiteRespId,
            'site_audit_sch_id': item.siteAuditSchId,
            'item_instance_id': item.itemInstanceId,
            'oem_name': item.oemName,
            'nexgen_serial_no': item.nexgenSerialNo,
            'mfg_serial_no': item.mfgSerialNo,
            'qr_code_scanned': item.qrCodeScanned ?? false,
            'qr_code_scanned_ts': item.qrCodeScannedTs,
            'image_name': item.imageName,
            'longitude': item.longitude,
            'latitude': item.latitude,
            'item_type_group': item.itemTypeGroup,
            'record_type': item.recordType,
            'item_type_remark': item.itemTypeRemark,
          };
          savedRectifierItems.add(savedItem);
          currentScannedItems++;
          print(
            'SMPS Screen: Added SMPS asset item: ${savedItem['serialNumber']}',
          );
        }
      }

      // Load SMPS Rectifiers (from subcategories)
      final smpsRectifiersItems = widget.smpsData!.smpsRectifiers ?? [];
      print('SMPS Screen: Found ${smpsRectifiersItems.length} SMPS Rectifiers');

      for (var item in smpsRectifiersItems) {
        // Only add items that have complete data
        if (item.mfgSerialNo != null &&
            item.photoId != null &&
            item.assetStatus != null) {
          Map<String, dynamic> savedItem = {
            'serialNumber':
                item.mfgSerialNo ?? item.nexgenSerialNo ?? 'Unknown',
            'photo': null,
            'photoId': item.photoId,
            'status': item.assetStatus ?? 'OK',
            'timestamp': DateTime.now(),
            'isQRCodeScanned': item.qrCodeScanned ?? false,
            'itemType': item.itemType ?? 'SMPS Rectifier',
            'remarks': item.itemTypeRemark ?? 'SMPS Rectifier Item',
            'assetStatus': item.assetStatus,
            'assetAuditSiteRespId': item.assetAuditSiteRespId,
            'capacity': item.capacity ?? 'N/A',

            // Full API response details
            'asset_audit_site_resp_id': item.assetAuditSiteRespId,
            'site_audit_sch_id': item.siteAuditSchId,
            'item_instance_id': item.itemInstanceId,
            'oem_name': item.oemName,
            'nexgen_serial_no': item.nexgenSerialNo,
            'mfg_serial_no': item.mfgSerialNo,
            'qr_code_scanned': item.qrCodeScanned ?? false,
            'qr_code_scanned_ts': item.qrCodeScannedTs,
            'image_name': item.imageName,
            'longitude': item.longitude,
            'latitude': item.latitude,
            'item_type_group': item.itemTypeGroup,
            'record_type': item.recordType,
            'item_type_remark': item.itemTypeRemark,
          };
          savedRectifierItems.add(savedItem);
          currentScannedItems++;
          print(
            'SMPS Screen: Added SMPS Rectifier item: ${savedItem['serialNumber']}',
          );
        }
      }

      // Load SMPS MPPT (from subcategories)
      final smpsMpptItems = widget.smpsData!.smpsMppt ?? [];
      print('SMPS Screen: Found ${smpsMpptItems.length} SMPS MPPT');

      for (var item in smpsMpptItems) {
        // Only add items that have complete data
        if (item.mfgSerialNo != null &&
            item.photoId != null &&
            item.assetStatus != null) {
          Map<String, dynamic> savedItem = {
            'serialNumber':
                item.mfgSerialNo ?? item.nexgenSerialNo ?? 'Unknown',
            'photo': null,
            'photoId': item.photoId,
            'status': item.assetStatus ?? 'OK',
            'timestamp': DateTime.now(),
            'isQRCodeScanned': item.qrCodeScanned ?? false,
            'itemType': item.itemType ?? 'SMPS MPPT',
            'remarks': item.itemTypeRemark ?? 'SMPS MPPT Item',
            'assetStatus': item.assetStatus,
            'assetAuditSiteRespId': item.assetAuditSiteRespId,
            'capacity': item.capacity ?? 'N/A',

            // Full API response details
            'asset_audit_site_resp_id': item.assetAuditSiteRespId,
            'site_audit_sch_id': item.siteAuditSchId,
            'item_instance_id': item.itemInstanceId,
            'oem_name': item.oemName,
            'nexgen_serial_no': item.nexgenSerialNo,
            'mfg_serial_no': item.mfgSerialNo,
            'qr_code_scanned': item.qrCodeScanned ?? false,
            'qr_code_scanned_ts': item.qrCodeScannedTs,
            'image_name': item.imageName,
            'longitude': item.longitude,
            'latitude': item.latitude,
            'item_type_group': item.itemTypeGroup,
            'record_type': item.recordType,
            'item_type_remark': item.itemTypeRemark,
          };
          savedMPPTItems.add(savedItem);
          currentScannedItems++;
          print(
            'SMPS Screen: Added SMPS MPPT item: ${savedItem['serialNumber']}',
          );
        }
      }

      // Load ACDB (from subcategories)
      final acdbItems = widget.smpsData!.acdb ?? [];
      print('SMPS Screen: Found ${acdbItems.length} ACDB');

      for (var item in acdbItems) {
        // Only add items that have complete data
        if (item.mfgSerialNo != null &&
            item.photoId != null &&
            item.assetStatus != null) {
          Map<String, dynamic> savedItem = {
            'serialNumber':
                item.mfgSerialNo ?? item.nexgenSerialNo ?? 'Unknown',
            'photo': null,
            'photoId': item.photoId,
            'status': item.assetStatus ?? 'OK',
            'timestamp': DateTime.now(),
            'isQRCodeScanned': item.qrCodeScanned ?? false,
            'itemType': item.itemType ?? 'ACDB',
            'remarks': item.itemTypeRemark ?? 'ACDB Item',
            'assetStatus': item.assetStatus,
            'assetAuditSiteRespId': item.assetAuditSiteRespId,
            'capacity': item.capacity ?? 'N/A',

            // Full API response details
            'asset_audit_site_resp_id': item.assetAuditSiteRespId,
            'site_audit_sch_id': item.siteAuditSchId,
            'item_instance_id': item.itemInstanceId,
            'oem_name': item.oemName,
            'nexgen_serial_no': item.nexgenSerialNo,
            'mfg_serial_no': item.mfgSerialNo,
            'qr_code_scanned': item.qrCodeScanned ?? false,
            'qr_code_scanned_ts': item.qrCodeScannedTs,
            'image_name': item.imageName,
            'longitude': item.longitude,
            'latitude': item.latitude,
            'item_type_group': item.itemTypeGroup,
            'record_type': item.recordType,
            'item_type_remark': item.itemTypeRemark,
          };
          savedACDBItems.add(savedItem);
          currentScannedItems++;
          print('SMPS Screen: Added ACDB item: ${savedItem['serialNumber']}');
        }
      }

      // Load LSPU (from subcategories)
      final lspuItems = widget.smpsData!.lspu ?? [];
      print('SMPS Screen: Found ${lspuItems.length} LSPU');

      for (var item in lspuItems) {
        // Only add items that have complete data
        if (item.mfgSerialNo != null &&
            item.photoId != null &&
            item.assetStatus != null) {
          Map<String, dynamic> savedItem = {
            'serialNumber':
                item.mfgSerialNo ?? item.nexgenSerialNo ?? 'Unknown',
            'photo': null,
            'photoId': item.photoId,
            'status': item.assetStatus ?? 'OK',
            'timestamp': DateTime.now(),
            'isQRCodeScanned': item.qrCodeScanned ?? false,
            'itemType': item.itemType ?? 'LSPU',
            'remarks': item.itemTypeRemark ?? 'LSPU Item',
            'assetStatus': item.assetStatus,
            'assetAuditSiteRespId': item.assetAuditSiteRespId,
            'capacity': item.capacity ?? 'N/A',

            // Full API response details
            'asset_audit_site_resp_id': item.assetAuditSiteRespId,
            'site_audit_sch_id': item.siteAuditSchId,
            'item_instance_id': item.itemInstanceId,
            'oem_name': item.oemName,
            'nexgen_serial_no': item.nexgenSerialNo,
            'mfg_serial_no': item.mfgSerialNo,
            'qr_code_scanned': item.qrCodeScanned ?? false,
            'qr_code_scanned_ts': item.qrCodeScannedTs,
            'image_name': item.imageName,
            'longitude': item.longitude,
            'latitude': item.latitude,
            'item_type_group': item.itemTypeGroup,
            'record_type': item.recordType,
            'item_type_remark': item.itemTypeRemark,
          };
          savedLSPUItems.add(savedItem);
          currentScannedItems++;
          print('SMPS Screen: Added LSPU item: ${savedItem['serialNumber']}');
        }
      }

      print(
        'SMPS Screen: Loaded ${savedRectifierItems.length} Rectifier items, ${savedMPPTItems.length} MPPT items, ${savedACDBItems.length} ACDB items, ${savedLSPUItems.length} LSPU items',
      );
      print('SMPS Screen: Current scanned items: $currentScannedItems');
    });
  }

  /// Build the "No Data" message widget
  Widget _buildNoDataMessage() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.info_outline,
            size: 64,
            color: AppColors.white.withOpacity(0.7),
          ),
          getHeight(16),
          Text(
            'No SMPS Data Available',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppColors.white,
              fontFamily: fontFamilyMontserrat,
            ),
            textAlign: TextAlign.center,
          ),
          getHeight(8),
          Text(
            'There are no SMPS items to audit for this site.',
            style: TextStyle(
              fontSize: 16,
              color: AppColors.white.withOpacity(0.8),
              fontFamily: fontFamilyMontserrat,
            ),
            textAlign: TextAlign.center,
          ),
          getHeight(16),
          Text(
            'You can proceed to the next screen or contact your administrator if you believe this is an error.',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.white.withOpacity(0.6),
              fontFamily: fontFamilyMontserrat,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    serialController.removeListener(_onFormChanged);
    serialController.dispose();
    rectifierSerialController.dispose();
    mpptSerialController.dispose();
    acdbSerialController.dispose();
    lspuSerialController.dispose();
    rectifierRemarksController.dispose();
    mpptRemarksController.dispose();
    generalRemarksController.dispose();
    super.dispose();
  }

  void _onFormChanged() {
    setState(() {
      hasUnsavedChanges =
          selectedFile != null ||
          selectedStatus != null ||
          selectedBatteryStatus != null ||
          selectedType != null ||
          serialController.text.isNotEmpty ||
          rectifierSerialController.text.isNotEmpty ||
          mpptSerialController.text.isNotEmpty ||
          acdbSerialController.text.isNotEmpty ||
          lspuSerialController.text.isNotEmpty;

      // Hide validation errors when user starts filling the form
      if (showValidationErrors &&
          selectedFile != null &&
          selectedBatteryStatus != null &&
          selectedType != null &&
          serialController.text.isNotEmpty) {
        showValidationErrors = false;
      }
    });
  }

  void _saveAndExit() async {
    // First close the unsaved changes dialog
    Navigator.of(context).pop();

    // Wait a bit for the dialog to fully close and overlay to clear
    await Future.delayed(const Duration(milliseconds: 200));

    // Then show success dialog with a clean barrier
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.black54, // Ensure clean barrier
        builder: (context) => SuccessDialog(
          ticketId: "UVORKJR00044",
          message:
              "Asset Audit for Site (ID: SITE-38974) has been recorded and saved.",
          onDone: () {
            Navigator.of(context).pop();
            Navigator.of(context).pop();
          },
          // auditName: "Asset Audit", // Required parameter
          // status: "Saved", // Required parameter
        ),
      );
    }
  }

  // Validate required fields for saved items only
  bool _isFormValid() {
    print('=== Form Validation Debug ===');
    print('Checking all controllers:');
    print('  - rectifierSerialController: "${rectifierSerialController.text}"');
    print('  - mpptSerialController: "${mpptSerialController.text}"');
    print('  - acdbSerialController: "${acdbSerialController.text}"');
    print('  - lspuSerialController: "${lspuSerialController.text}"');
    print('Checking all photos:');
    print('  - rectifierPhoto: $rectifierPhoto');
    print('  - mpptPhoto: $mpptPhoto');
    print('  - acdbPhoto: $acdbPhoto');
    print('  - lspuPhoto: $lspuPhoto');

    // Only check serial number and photo for saved items
    // Type, battery status, and file are not required for individual item saving

    // Check if serial number is entered in the CustomInfoCard
    // Check all controllers to see which one has data
    String? serialNumber = rectifierSerialController.text.isNotEmpty
        ? rectifierSerialController.text
        : mpptSerialController.text.isNotEmpty
        ? mpptSerialController.text
        : acdbSerialController.text.isNotEmpty
        ? acdbSerialController.text
        : lspuSerialController.text.isNotEmpty
        ? lspuSerialController.text
        : null;

    print('Serial number: "$serialNumber"');
    if (serialNumber == null || serialNumber.isEmpty) {
      print(' Serial number validation failed');
      return false;
    } else {
      print('Serial number validation passed');
    }

    // Check if photo is added
    // Check all photo variables to see which one has data
    String? photo = rectifierPhoto ?? mpptPhoto ?? acdbPhoto ?? lspuPhoto;
    print('Photo: $photo');
    if (photo == null || photo.isEmpty) {
      print(' Photo validation failed');
      return false;
    } else {
      print('Photo validation passed');
    }

    // Note: status is not required since it comes from API
    // and is set to true by default (backendStatus: true)
    String? status = rectifierStatus ?? mpptStatus ?? acdbStatus ?? lspuStatus;
    print('Status: $status (not required)');

    print(' All validations passed!');
    return true;
  }

  bool _validateForm() {
    setState(() {
      showValidationErrors = true;
    });

    print('=== Form Validation Debug (_validateForm) ===');
    String? serialNumber = rectifierSerialController.text.isNotEmpty
        ? rectifierSerialController.text
        : mpptSerialController.text.isNotEmpty
        ? mpptSerialController.text
        : acdbSerialController.text.isNotEmpty
        ? acdbSerialController.text
        : lspuSerialController.text.isNotEmpty
        ? lspuSerialController.text
        : null;

    print('Serial number: "$serialNumber"');
    if (serialNumber == null || serialNumber.isEmpty) {
      print(' Serial number validation failed');
      return false;
    } else {
      print(' Serial number validation passed');
    }

    String? photo = rectifierPhoto ?? mpptPhoto ?? acdbPhoto ?? lspuPhoto;
    print('Photo: $photo');
    if (photo == null || photo.isEmpty) {
      print(' Photo validation failed');
      return false;
    } else {
      print(' Photo validation passed');
    }

    // Note: status is not required since it comes from API
    // and is set to true by default (backendStatus: true)
    String? status = rectifierStatus ?? mpptStatus ?? acdbStatus ?? lspuStatus;
    print('Status: $status (not required)');

    print('Final validation result: true');
    return true;
  }

  // Save current form data for Rectifier
  void _saveRectifierForm() {
    // Check if we've reached the limit for rectifier items
    if (savedRectifierItems.length >= totalRectifierItems) {
      showCustomToast(
        context,
        'Maximum number of Rectifier items ($totalRectifierItems) already added.',
      );
      return;
    }

    if (_isFormValid()) {
      setState(() {
        // Create a map of current form data
        Map<String, dynamic> currentFormData = {
          'serialNumber': rectifierSerialNumber,
          'photo': rectifierPhoto,
          'photoId': rectifierPhotoId,
          // Include the photoId from API
          'photoTakenTs': DateTime.now().toString(),
          'itemType': 'SMPS Rectifier',
          'remarks': 'SMPS Rectifier Item',
          'assetStatus': rectifierStatus ?? "OK",
          'assetAuditSiteRespId': _getAssetAuditSiteRespId('SMPS Rectifiers'),
          'timestamp': DateTime.now(),
          'isQRCodeScanned': false,
          // Track if this was QR scanned or manual entry (false for manual entry)
        };

        print('Saving Rectifier item: $currentFormData');
        print(
          'Current savedRectifierItems count: ${savedRectifierItems.length}',
        );

        // Add to saved rectifier items list
        savedRectifierItems.add(currentFormData);
        currentScannedItems++;

        print(
          'After saving - savedRectifierItems count: ${savedRectifierItems.length}',
        );
        print('currentScannedItems: $currentScannedItems');

        // Clear AssetTypeCard form for next entry
        rectifierSerialNumber = null;
        rectifierPhoto = null;
        rectifierPhotoId = null;
        rectifierStatus = null;

        // Clear the controller
        rectifierSerialController.clear();

        // Force rebuild of the CustomInfoCard widget
        rectifierCardKey++;

        hasUnsavedChanges = false;
        showValidationErrors = false;
      });

      // Show success message
      int remainingRectifiers =
          totalRectifierItems - savedRectifierItems.length;
      showCustomToast(
        context,
        'Rectifier item saved successfully! ${remainingRectifiers > 0 ? '(${remainingRectifiers} remaining)' : '(All items added)'}',
      );
    } else {
      print('Form validation failed - cannot save rectifier item');
    }
  }

  // Save current form data for MPPT
  void _saveMPPTForm() {
    // Check if we've reached the limit for MPPT items
    if (savedMPPTItems.length >= totalMPPTItems) {
      showCustomToast(
        context,
        'Maximum number of MPPT items ($totalMPPTItems) already added.',
      );
      return;
    }

    if (_isFormValid()) {
      setState(() {
        // Create a map of current form data
        Map<String, dynamic> currentFormData = {
          'serialNumber': mpptSerialNumber,
          'photo': mpptPhoto,
          'photoId': mpptPhotoId,
          // Include the photoId from API
          'photoTakenTs': DateTime.now().toString(),
          'itemType': 'SMPS MPPT',
          'remarks': 'SMPS MPPT Item',
          'assetStatus': mpptStatus ?? "OK",
          'assetAuditSiteRespId': _getAssetAuditSiteRespId('SMPS MPPT'),
          'timestamp': DateTime.now(),
          'isQRCodeScanned': false,
          // Track if this was QR scanned or manual entry (false for manual entry)
        };

        print('Saving MPPT item: $currentFormData');
        print('Current savedMPPTItems count: ${savedMPPTItems.length}');

        // Add to saved MPPT items list
        savedMPPTItems.add(currentFormData);
        currentScannedItems++;

        print('After saving - savedMPPTItems count: ${savedMPPTItems.length}');
        print('currentScannedItems: $currentScannedItems');

        // Clear AssetTypeCard form for next entry
        mpptSerialNumber = null;
        mpptPhoto = null;
        mpptPhotoId = null;
        mpptStatus = null;

        // Clear the controller
        mpptSerialController.clear();

        // Force rebuild of the CustomInfoCard widget
        mpptCardKey++;

        hasUnsavedChanges = false;
        showValidationErrors = false;
      });

      // Show success message
      int remainingMPPTs = totalMPPTItems - savedMPPTItems.length;
      showCustomToast(
        context,
        'MPPT item saved successfully! ${remainingMPPTs > 0 ? '(${remainingMPPTs} remaining)' : '(All items added)'}',
      );
    } else {
      print('Form validation failed - cannot save MPPT item');
    }
  }

  // Save current form data for ACDB
  void _saveACDBForm() {
    print('=== SMPS Screen: Saving ACDB Form ===');
    print('ACDB Serial Number: $acdbSerialNumber');
    print('ACDB Photo: $acdbPhoto');
    print('ACDB Photo ID: $acdbPhotoId');
    print('ACDB Status: $acdbStatus');

    if (_isFormValid()) {
      setState(() {
        // Get the actual serial number from the controller
        String actualSerialNumber = acdbSerialController.text.isNotEmpty
            ? acdbSerialController.text
            : 'Unknown';

        Map<String, dynamic> currentFormData = {
          'serialNumber': actualSerialNumber,
          // Use the actual serial number from controller
          'photo': acdbPhoto,
          'photoId': acdbPhotoId,
          // Include the photoId from API
          'photoTakenTs': DateTime.now().toString(),
          'itemType': 'ACDB',
          'remarks': 'ACDB Item',
          'assetStatus': acdbStatus ?? "OK",
          'assetAuditSiteRespId': _getAssetAuditSiteRespId('ACDB'),
          'timestamp': DateTime.now(),
          'isQRCodeScanned': false,
          // Track if this was QR scanned or manual entry (false for manual entry)
        };

        print('Saving ACDB item: $currentFormData');
        print('Current savedACDBItems count: ${savedACDBItems.length}');

        savedACDBItems.add(currentFormData);
        currentScannedItems++;

        print('After saving - savedACDBItems count: ${savedACDBItems.length}');
        print('currentScannedItems: $currentScannedItems');

        // Clear form for next entry
        acdbSerialNumber = null;
        acdbPhoto = null;
        acdbPhotoId = null;
        acdbStatus = null;
        acdbSerialController.clear();
        acdbCardKey++;

        hasUnsavedChanges = false;
        showValidationErrors = false;
      });

      showCustomToast(context, 'ACDB item saved successfully!');
    } else {
      print('Form validation failed - cannot save ACDB item');
      showCustomToast(
        context,
        '❌ Please fill all required fields before saving',
      );
    }
  }

  // Save current form data for LSPU
  void _saveLSPUForm() {
    print('=== SMPS Screen: Saving LSPU Form ===');
    print('LSPU Serial Number: $lspuSerialNumber');
    print('LSPU Photo: $lspuPhoto');
    print('LSPU Photo ID: $lspuPhotoId');
    print('LSPU Status: $lspuStatus');

    if (_isFormValid()) {
      setState(() {
        // Get the actual serial number from the controller
        String actualSerialNumber = lspuSerialController.text.isNotEmpty
            ? lspuSerialController.text
            : 'Unknown';

        Map<String, dynamic> currentFormData = {
          'serialNumber': actualSerialNumber,
          // Use the actual serial number from controller
          'photo': lspuPhoto,
          'photoId': lspuPhotoId,
          // Include the photoId from API
          'photoTakenTs': DateTime.now().toString(),
          'itemType': 'LSPU',
          'remarks': 'LSPU Item',
          'assetStatus': lspuStatus ?? "OK",
          'assetAuditSiteRespId': _getAssetAuditSiteRespId('LSPU'),
          'timestamp': DateTime.now(),
          'isQRCodeScanned': false,
          // Track if this was QR scanned or manual entry (false for manual entry)
        };

        print('Saving LSPU item: $currentFormData');
        print('Current savedLSPUItems count: ${savedLSPUItems.length}');

        savedLSPUItems.add(currentFormData);
        currentScannedItems++;

        print('After saving - savedLSPUItems count: ${savedLSPUItems.length}');
        print('currentScannedItems: $currentScannedItems');

        // Clear form for next entry
        lspuSerialNumber = null;
        lspuPhoto = null;
        lspuPhotoId = null;
        lspuStatus = null;
        lspuSerialController.clear();
        lspuCardKey++;

        hasUnsavedChanges = false;
        showValidationErrors = false;
      });

      showCustomToast(context, 'LSPU item saved successfully!');
    } else {
      print('Form validation failed - cannot save LSPU item');
      showCustomToast(
        context,
        '❌ Please fill all required fields before saving',
      );
    }
  }

  // Check if all items are scanned
  bool _isAllItemsScanned() {
    return (savedRectifierItems.length >= totalRectifierItems) &&
        (savedMPPTItems.length >= totalMPPTItems);
  }

  /// Validate serial number against API data
  /// Returns true if valid, false if invalid
  bool _validateSerialNumber(String serialNumber, bool isQRCodeScanned) {
    if (widget.smpsData == null) return false;

    if (isQRCodeScanned) {
      // For QR code scans, validate against nexgen_serial_no
      final allItems = [
        ...(widget.smpsData!.assets ?? []),
        ...(widget.smpsData!.smpsRectifiers ?? []),
        ...(widget.smpsData!.smpsMppt ?? []),
        ...(widget.smpsData!.smpsCabinet ?? []),
        ...(widget.smpsData!.acdb ?? []),
        ...(widget.smpsData!.lspu ?? []),
      ];

      final isValid = allItems.any(
        (item) =>
            item.nexgenSerialNo?.toLowerCase() == serialNumber.toLowerCase(),
      );

      if (isValid) {
        showCustomToast(context, '✅ QR Code validated successfully!');
      } else {
        showCustomToast(
          context,
          '❌ Invalid QR Code! Serial number not found in system.',
        );
      }

      return isValid;
    } else {
      // For manual entries, validate against mfg_serial_no
      final allItems = [
        ...(widget.smpsData!.assets ?? []),
        ...(widget.smpsData!.smpsRectifiers ?? []),
        ...(widget.smpsData!.smpsMppt ?? []),
        ...(widget.smpsData!.smpsCabinet ?? []),
        ...(widget.smpsData!.acdb ?? []),
        ...(widget.smpsData!.lspu ?? []),
      ];

      final isValid = allItems.any(
        (item) => item.mfgSerialNo?.toLowerCase() == serialNumber.toLowerCase(),
      );

      if (isValid) {
        showCustomToast(context, '✅ Manual entry validated successfully!');
      } else {
        showCustomToast(
          context,
          '❌ Invalid manual entry! Serial number not found in system.',
        );
      }

      return isValid;
    }
  }

  /// Submit all data directly without extra popup
  void _submitAllData() async {
    print('=== SMPS Screen: Submitting All Data ===');
    print('SMPS Screen: Ticket ID: $_ticketId');

    // Check if user has saved at least one item from current screen
    if (savedRectifierItems.isEmpty &&
        savedMPPTItems.isEmpty &&
        savedACDBItems.isEmpty &&
        savedLSPUItems.isEmpty) {
      showCustomToast(
        context,
        '❌ Please add at least one item before final submission.',
      );
      return;
    }

    // Check if there are any unsaved changes
    if (hasUnsavedChanges) {
      print(
        'SMPS Screen: Unsaved changes detected, posting current screen data first...',
      );

      // Post current screen data first
      final success = await _postCurrentScreenData();
      if (success) {
        print('SMPS Screen: Current screen data posted successfully');
        showCustomToast(context, '✅ SMPS data saved successfully!');

        // Reset the unsaved changes flag
        setState(() {
          hasUnsavedChanges = false;
        });

        // Now proceed with final submission
        _performFinalSubmission();
      } else {
        showCustomToast(
          context,
          '❌ Failed to post current screen data. Please try again.',
        );
        return;
      }
    } else {
      print(
        'SMPS Screen: No unsaved changes, proceeding directly to final submission...',
      );
      // No changes, proceed directly to final submission
      _performFinalSubmission();
    }
  }

  /// Perform final submission of all data
  Future<void> _performFinalSubmission() async {
    print('=== SMPS Screen: Performing Final Submission ===');

    // Check if user has saved at least one item from current screen
    if (savedRectifierItems.isEmpty &&
        savedMPPTItems.isEmpty &&
        savedACDBItems.isEmpty &&
        savedLSPUItems.isEmpty) {
      showCustomToast(
        context,
        '❌ Please add at least one item before final submission.',
      );
      return;
    }

    // Post all data from the entire flow
    final success = await _postAllFlowData();
    if (success) {
      print(
        'SMPS Screen: All flow data posted successfully, waiting for API response...',
      );
      // The success dialog will be shown in the BlocListener after API success
    } else {
      showCustomToast(
        context,
        '❌ Failed to post all flow data. Please try again.',
      );
    }
  }

  /// Post all data from the entire flow to API
  Future<bool> _postAllFlowData() async {
    print('=== SMPS Screen: Posting All Flow Data ===');

    if (widget.assetAuditData == null) {
      print('SMPS Screen: No asset audit data available for posting');
      return false;
    }

    try {
      // Collect all data from the entire flow
      List<Map<String, dynamic>> allFlowItems = [];

      // Add data from previous screens
      if (widget.extinguisherItems != null &&
          widget.extinguisherItems!.isNotEmpty) {
        print(
          'SMPS Screen: Adding ${widget.extinguisherItems!.length} extinguisher items',
        );
        allFlowItems.addAll(widget.extinguisherItems!);
      }

      if (widget.fencingItems != null && widget.fencingItems!.isNotEmpty) {
        print(
          'SMPS Screen: Adding ${widget.fencingItems!.length} fencing items',
        );
        allFlowItems.addAll(widget.fencingItems!);
      }

      if (widget.dgItems != null && widget.dgItems!.isNotEmpty) {
        print('SMPS Screen: Adding ${widget.dgItems!.length} DG items');
        allFlowItems.addAll(widget.dgItems!);
      }

      if (widget.solarPlatesItems != null &&
          widget.solarPlatesItems!.isNotEmpty) {
        print(
          'SMPS Screen: Adding ${widget.solarPlatesItems!.length} solar plates items',
        );
        allFlowItems.addAll(widget.solarPlatesItems!);
      }

      // Add current screen data
      allFlowItems.addAll(savedRectifierItems);
      allFlowItems.addAll(savedMPPTItems);
      allFlowItems.addAll(savedACDBItems);
      allFlowItems.addAll(savedLSPUItems);

      print('SMPS Screen: Total flow items to post: ${allFlowItems.length}');
      print('SMPS Screen: Breakdown:');
      print('  - Extinguisher: ${widget.extinguisherItems?.length ?? 0}');
      print('  - Fencing: ${widget.fencingItems?.length ?? 0}');
      print('  - DG: ${widget.dgItems?.length ?? 0}');
      print('  - Solar Plates: ${widget.solarPlatesItems?.length ?? 0}');
      print(
        '  - SMPS: ${savedRectifierItems.length + savedMPPTItems.length + savedACDBItems.length + savedLSPUItems.length}',
      );

      if (allFlowItems.isEmpty) {
        print('SMPS Screen: No flow items to post');
        return false;
      }

      // Log all flow items before enhancement
      print('=== SMPS Screen: ALL FLOW ITEMS BEFORE ENHANCEMENT ===');
      for (int i = 0; i < allFlowItems.length; i++) {
        var item = allFlowItems[i];
        print('--- Flow Item $i Details ---');
        print('  - serialNumber: ${item['serialNumber']}');
        print('  - photo: ${item['photo']}');
        print('  - photoId: ${item['photoId']}');
        print('  - itemType: ${item['itemType']}');
        print('  - remarks: ${item['remarks']}');
        print('  - assetStatus: ${item['assetStatus']}');
        print('  - assetAuditSiteRespId: ${item['assetAuditSiteRespId']}');
        print('  - timestamp: ${item['timestamp']}');
        print('  - isQRCodeScanned: ${item['isQRCodeScanned']}');
        print('  - Full item object: $item');
        print('--- End Flow Item $i ---');
      }

      // Enhance all flow items with additional data
      final enhancedItems = AssetAuditPostHelper.enhanceSavedItems(
        savedItems: allFlowItems,
        screenName: 'Complete Flow',
      );

      // Log the enhanced items data
      print('=== SMPS Screen: ENHANCED FLOW ITEMS DATA ===');
      print('SMPS Screen: Total enhanced flow items: ${enhancedItems.length}');
      for (int i = 0; i < enhancedItems.length; i++) {
        var item = enhancedItems[i];
        print('--- Enhanced Flow Item $i Details ---');
        print('  - serialNumber: ${item['serialNumber']}');
        print('  - photo: ${item['photo']}');
        print('  - photoId: ${item['photoId']}');
        print('  - itemType: ${item['itemType']}');
        print('  - remarks: ${item['remarks']}');
        print('  - assetStatus: ${item['assetStatus']}');
        print('  - assetAuditSiteRespId: ${item['assetAuditSiteRespId']}');
        print('  - timestamp: ${item['timestamp']}');
        print('  - isQRCodeScanned: ${item['isQRCodeScanned']}');
        print('  - Full item object: $item');
        print('--- End Enhanced Flow Item $i ---');
      }

      // Convert enhanced items to proper post request format
      final postRequests =
          await AssetAuditPostHelper.convertSavedItemsToPostRequest(
            savedItems: enhancedItems,
            assetAuditData: widget.assetAuditData!,
            itemType: 'Complete Flow',
            itemTypeId: 1,
            // Default item type ID
            screenName: 'Complete Flow',
            context: context,
          );

      if (postRequests.isNotEmpty) {
        print(
          'SMPS Screen: Posting ${postRequests.length} flow items to API...',
        );

        // Use the cubit to post the data
        context.read<AssetAuditCubit>().postAssetAuditData(
          requests: postRequests,
        );
      } else {
        print('SMPS Screen: No valid post requests created');
        return false;
      }

      return true;
    } catch (e) {
      print('SMPS Screen: Error posting all flow data: $e');
      return false;
    }
  }

  int? _getRemarksAssetAuditSiteRespId() {
    print('=== SMPS Screen: Getting Remarks AssetAuditSiteRespId ===');

    if (widget.smpsData == null) {
      print('smpsData is null, cannot get remarks ID');
      return null;
    }

    // Check if there are remarks in the backend data
    final remarks = widget.smpsData!.remarks;
    if (remarks.isNotEmpty) {
      print('Found ${remarks.length} remarks in backend data');

      // First try to find a general remarks entry (SMPS category is usually the main one)
      for (var remark in remarks) {
        if (remark.assetAuditSiteRespId != null &&
            remark.assetAuditSiteRespId > 0 &&
            remark.itemType == 'SMPS') {
          print('Using SMPS remarks ID: ${remark.assetAuditSiteRespId}');
          return remark.assetAuditSiteRespId;
        }
      }

      // Fallback: find any remarks entry with a valid ID
      for (var remark in remarks) {
        if (remark.assetAuditSiteRespId != null &&
            remark.assetAuditSiteRespId > 0) {
          print(
            'Using fallback remarks ID: ${remark.assetAuditSiteRespId} for itemType: ${remark.itemType}',
          );
          return remark.assetAuditSiteRespId;
        }
      }
    }

    print('No valid remarks ID found in backend data');
    return null;
  }

  /// Post current screen data to API before submitting
  Future<bool> _postCurrentScreenData() async {
    if (widget.assetAuditData == null) {
      print('SMPS Screen: No asset audit data available for posting');
      return false;
    }

    try {
      // Combine all saved items from different categories
      List<Map<String, dynamic>> allSavedItems = [];
      allSavedItems.addAll(savedRectifierItems);
      allSavedItems.addAll(savedMPPTItems);
      allSavedItems.addAll(savedACDBItems);
      allSavedItems.addAll(savedLSPUItems);

      print('SMPS Screen: Total items to post: ${allSavedItems.length}');
      print('SMPS Screen: Rectifier items: ${savedRectifierItems.length}');
      print('SMPS Screen: MPPT items: ${savedMPPTItems.length}');
      print('SMPS Screen: ACDB items: ${savedACDBItems.length}');
      print('SMPS Screen: LSPU items: ${savedLSPUItems.length}');

      // Log the saved items data before enhancement
      print('=== SMPS Screen: SAVED ITEMS DATA BEFORE ENHANCEMENT ===');
      for (int i = 0; i < allSavedItems.length; i++) {
        var item = allSavedItems[i];
        print('--- Saved Item $i Details ---');
        print('  - serialNumber: ${item['serialNumber']}');
        print('  - photo: ${item['photo']}');
        print('  - photoId: ${item['photoId']}');
        print('  - itemType: ${item['itemType']}');
        print('  - remarks: ${item['remarks']}');
        print('  - assetStatus: ${item['assetStatus']}');
        print('  - assetAuditSiteRespId: ${item['assetAuditSiteRespId']}');
        print('  - timestamp: ${item['timestamp']}');
        print('  - isQRCodeScanned: ${item['isQRCodeScanned']}');
        print('  - Full item object: $item');
        print('--- End Saved Item $i ---');
      }

      // Add user's general remarks if entered
      if (generalRemarksController.text.isNotEmpty) {
        // Find the appropriate remarks entry from backend data
        int? remarksAssetAuditSiteRespId = _getRemarksAssetAuditSiteRespId();

        if (remarksAssetAuditSiteRespId != null) {
          Map<String, dynamic> remarksData = {
            'itemType': 'SMPS',
            // Use the main screen category
            'remarks': generalRemarksController.text,
            // User's actual remarks text
            'recordType': 'Remarks',
            'timestamp': DateTime.now(),
            'assetAuditSiteRespId': remarksAssetAuditSiteRespId,
            // Use backend remarks ID
            'status': 'OK',
            // Default status for remarks
            'serialNumber': 'REMARKS',
            // Default serial for remarks
            'photo': null,
            // No photo file for remarks
            'photoTakenTs': DateTime.now().toString(),
            // Current timestamp
            'isQRCodeScanned': false,
            // Remarks are not QR scanned
            'localQrCodeScannedTs': DateTime.now().toString(),
            // Local timestamp for QR scan
            'localCreatedDt': DateTime.now().toString(),
            // Local creation timestamp
            'localModifiedDt': DateTime.now().toString(),
            // Local modification timestamp
          };
          allSavedItems.add(remarksData);
          print(
            'SMPS Screen: Added user remarks to post with ID: $remarksAssetAuditSiteRespId, text: "${generalRemarksController.text}"',
          );
        } else {
          print('SMPS Screen: Could not find remarks ID from backend data');
        }
      }

      if (allSavedItems.isEmpty) {
        print('SMPS Screen: No items to post');
        return false;
      }

      // Enhance saved items with additional data
      final enhancedItems = AssetAuditPostHelper.enhanceSavedItems(
        savedItems: allSavedItems,
        screenName: 'SMPS',
      );

      // Log the enhanced items data
      print('=== SMPS Screen: ENHANCED ITEMS DATA ===');
      print('SMPS Screen: Total enhanced items: ${enhancedItems.length}');
      for (int i = 0; i < enhancedItems.length; i++) {
        var item = enhancedItems[i];
        print('--- Enhanced Item $i Details ---');
        print('  - serialNumber: ${item['serialNumber']}');
        print('  - photo: ${item['photo']}');
        print('  - photoId: ${item['photoId']}');
        print('  - itemType: ${item['itemType']}');
        print('  - remarks: ${item['remarks']}');
        print('  - assetStatus: ${item['assetStatus']}');
        print('  - assetAuditSiteRespId: ${item['assetAuditSiteRespId']}');
        print('  - timestamp: ${item['timestamp']}');
        print('  - isQRCodeScanned: ${item['isQRCodeScanned']}');
        print('  - Full enhanced item object: $item');
        print('--- End Enhanced Item $i ---');
      }

      // Convert to POST request format
      final requests =
          await AssetAuditPostHelper.convertSavedItemsToPostRequest(
            savedItems: enhancedItems,
            assetAuditData: widget.assetAuditData!,
            itemType: 'SMPS',
            itemTypeId: AssetAuditPostHelper.getItemTypeId('SMPS'),
            screenName: 'SMPS',
            context: context,
          );

      if (requests.isEmpty) {
        print('SMPS Screen: Failed to create POST requests');
        return false;
      }

      // Log the request data being sent to API
      print('=== SMPS Screen: POST API REQUEST DATA ===');
      print('SMPS Screen: Total requests to post: ${requests.length}');

      for (int i = 0; i < requests.length; i++) {
        var request = requests[i];
        print('--- Request $i Details ---');
        print('  - auditSchId: ${request.auditSchId}');
        print('  - siteAuditSchId: ${request.siteAuditSchId}');
        print('  - siteId: ${request.siteId}');
        print('  - itemInstanceId: ${request.itemInstanceId}');
        print('  - nexgenSerialNo: ${request.nexgenSerialNo}');
        print('  - itemTypeId: ${request.itemTypeId}');
        print('  - qrCodeScanned: ${request.qrCodeScanned}');
        print('  - photoId: ${request.photoId}');
        print('  - photoTakenTs: ${request.photoTakenTs}');
        print('  - assetStatus: ${request.assetStatus}');
        print('  - longitude: ${request.longitude}');
        print('  - latitude: ${request.latitude}');
        print('  - itemTypeRemark: ${request.itemTypeRemark}');
        print('  - localAuditLogId: ${request.localAuditLogId}');
        print('  - localQrCodeScannedTs: ${request.localQrCodeScannedTs}');
        print('  - localCreatedDt: ${request.localCreatedDt}');
        print('  - localModifiedDt: ${request.localModifiedDt}');
        print('  - syncProcessId: ${request.syncProcessId}');
        print('  - isActive: ${request.isActive}');
        print('  - remarks: ${request.remarks}');
        print('  - Full request object: $request');
        print('--- End Request $i ---');
      }

      // Set flag BEFORE making the API call to ensure it's set when success state is received
      setState(() {
        _hasPostedSMPSData = true;
      });
      print('SMPS Screen: Set _hasPostedSMPSData flag to true BEFORE API call');
      print('SMPS Screen: Flag value after setting: $_hasPostedSMPSData');

      // Use the existing cubit to post data
      print('SMPS Screen: Posting ${requests.length} items to API...');
      context.read<AssetAuditCubit>().postAssetAuditData(requests: requests);

      // Return true to indicate data is being posted
      return true;
    } catch (e) {
      print('SMPS Screen: Error preparing data: $e');
      return false;
    }
  }

  // Format serial number to show first 5 digits + ...
  String _formatSerialNumber(String serialNumber) {
    if (serialNumber.length <= 7) {
      return serialNumber;
    }
    return "${serialNumber.substring(0, 5)}...";
  }

  // Edit a specific Rectifier item from the saved list
  void _editItem(Map<String, dynamic> item) {
    setState(() {
      // Load the item data back into the form
      rectifierSerialNumber = item["serialNumber"];
      rectifierPhoto = item["photo"];
      rectifierPhotoId = item["photoId"];
      rectifierStatus = item["assetStatus"] ?? item["status"];

      // Set the serial controller text
      rectifierSerialController.text = item["serialNumber"] ?? "";

      // Remove the item from saved rectifier items
      savedRectifierItems.remove(item);
      currentScannedItems--;

      // Force rebuild of the CustomInfoCard widget with new data
      rectifierCardKey++;

      hasUnsavedChanges = true;
    });

    // Show message to user
    showCustomToast(
      context,
      'Rectifier item loaded for editing. Make changes and save again.',
    );
  }

  // Edit a specific MPPT item from the saved list
  void _editMPPTItem(Map<String, dynamic> item) {
    setState(() {
      // Load the item data back into the form
      mpptSerialNumber = item["serialNumber"];
      mpptPhoto = item["photo"];
      mpptPhotoId = item["photoId"];
      mpptStatus = item["assetStatus"] ?? item["status"];

      // Set the serial controller text
      mpptSerialController.text = item["serialNumber"] ?? "";

      // Remove the item from saved MPPT items
      savedMPPTItems.remove(item);
      currentScannedItems--;

      // Force rebuild of the CustomInfoCard widget with new data
      mpptCardKey++;

      hasUnsavedChanges = true;
    });

    // Show message to user
    showCustomToast(
      context,
      'MPPT item loaded for editing. Make changes and save again.',
    );
  }

  // Edit a specific ACDB item from the saved list
  void _editACDBItem(Map<String, dynamic> item) {
    setState(() {
      // Load the item data back into the form
      acdbSerialNumber = item["serialNumber"];
      acdbPhoto = item["photo"];
      acdbPhotoId = item["photoId"];
      acdbStatus = item["assetStatus"]; // Use assetStatus from saved item

      // Set the serial controller text
      acdbSerialController.text = item["serialNumber"] ?? "";

      // Remove the item from saved ACDB items
      savedACDBItems.remove(item);
      currentScannedItems--;

      // Force rebuild of the CustomInfoCard widget with new data
      acdbCardKey++;

      hasUnsavedChanges = true;
    });

    // Show message to user
    showCustomToast(
      context,
      'ACDB item loaded for editing. Make changes and save again.',
    );
  }

  // Edit a specific LSPU item from the saved list
  void _editLSPUItem(Map<String, dynamic> item) {
    setState(() {
      // Load the item data back into the form
      lspuSerialNumber = item["serialNumber"];
      lspuPhoto = item["photo"];
      lspuPhotoId = item["photoId"];
      lspuStatus = item["assetStatus"]; // Use assetStatus from saved item

      // Set the serial controller text
      lspuSerialController.text = item["serialNumber"] ?? "";

      // Remove the item from saved LSPU items
      savedLSPUItems.remove(item);
      currentScannedItems--;

      // Force rebuild of the CustomInfoCard widget with new data
      lspuCardKey++;

      hasUnsavedChanges = true;
    });

    // Show message to user
    showCustomToast(
      context,
      'LSPU item loaded for editing. Make changes and save again.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AssetAuditCubit, AssetAuditState>(
      listener: (context, state) {
        print('SMPS Screen: BlocListener received state: $state');
        print('SMPS Screen: State type: ${state.runtimeType}');

        if (state is AssetAuditPostSuccess) {
          print('=== SMPS Screen: POST API SUCCESS RESPONSE ===');
          print('SMPS Screen: AssetAuditPostSuccess received!');
          print('SMPS Screen: State details: $state');
          print('SMPS Screen: _hasPostedSMPSData flag: $_hasPostedSMPSData');
          print(
            'SMPS Screen: Total responses received: ${state.responses.length}',
          );

          // Log each response in detail
          for (int i = 0; i < state.responses.length; i++) {
            var response = state.responses[i];
            print('--- Response $i Details ---');
            print('  - itemTypeRemark: ${response.itemTypeRemark}');
            print('  - itemTypeId: ${response.itemTypeId}');
            print('  - nexgenSerialNo: ${response.nexgenSerialNo}');
            print('  - assetStatus: ${response.assetStatus}');
            print('  - remarks: ${response.remarks}');
            print('  - photoId: ${response.photoId}');
            print('  - qrCodeScanned: ${response.qrCodeScanned}');
            print('  - qrCodeScannedTs: ${response.qrCodeScannedTs}');
            print('  - longitude: ${response.longitude}');
            print('  - latitude: ${response.latitude}');
            print('  - siteAuditSchId: ${response.siteAuditSchId}');
            print('  - siteId: ${response.siteId}');
            print('  - auditSchId: ${response.auditSchId}');
            print('  - itemInstanceId: ${response.itemInstanceId}');
            print('  - assetAuditSiteRespId: ${response.assetAuditSiteRespId}');
            print('  - localAuditLogId: ${response.localAuditLogId}');
            print('  - localQrCodeScannedTs: ${response.localQrCodeScannedTs}');
            print('  - localCreatedDt: ${response.localCreatedDt}');
            print('  - localModifiedDt: ${response.localModifiedDt}');
            print('  - syncProcessId: ${response.syncProcessId}');
            print('  - isActive: ${response.isActive}');
            print('  - Full response object: $response');
            print('--- End Response $i ---');
          }

          // Check if this success state contains SMPS-related items
          bool isSMPSData = false;
          for (var response in state.responses) {
            // Primary check: itemTypeRemark contains SMPS-related text
            if (response.itemTypeRemark != null &&
                (response.itemTypeRemark!.contains('SMPS') ||
                    response.itemTypeRemark!.contains('Rectifier') ||
                    response.itemTypeRemark!.contains('MPPT') ||
                    response.itemTypeRemark!.contains('ACDB') ||
                    response.itemTypeRemark!.contains('LSPU') ||
                    response.itemTypeRemark!.contains('Cabinet'))) {
              isSMPSData = true;
              print(
                'SMPS Screen: Found SMPS-related item by itemTypeRemark: ${response.itemTypeRemark}',
              );
              break;
            }

            // Fallback check: Check if this is a response to SMPS screen data by looking at the flag
            if (_hasPostedSMPSData) {
              isSMPSData = true;
              print(
                'SMPS Screen: Found SMPS-related item by flag check (fallback)',
              );
              break;
            }

            print(
              'SMPS Screen: itemTypeRemark "${response.itemTypeRemark}" does not match SMPS patterns',
            );
          }

          // Only process this success state if it contains SMPS screen data
          if (isSMPSData) {
            print(
              'SMPS Screen: Confirmed this is SMPS screen data, proceeding with data refresh and final submission...',
            );

            // Show success message
            showCustomToast(context, '✅ SMPS data saved successfully!');

            // Refresh data from API before final submission
            print(
              'SMPS Screen: Refreshing data from API before final submission...',
            );
            try {
              // Trigger a refresh of the asset audit data
              context.read<AssetAuditCubit>().getAssetAuditData(
                siteType: "telecom",
                auditSchId:
                    widget.assetAuditData?.pageHeader.first.siteAuditSchId
                        .toString() ??
                    "0",
                siteAuditSchId:
                    widget.assetAuditData?.pageHeader.first.siteAuditSchId
                        .toString() ??
                    "0",
              );

              // Wait for data to refresh, then show success dialog
              Future.delayed(const Duration(seconds: 2), () {
                if (mounted) {
                  print(
                    'SMPS Screen: Data refreshed, showing final success dialog...',
                  );
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) => SuccessDialog(
                      ticketId: widget.ticketId ?? _formattedTicketId,
                      message:
                          "Asset Audit completed successfully!\n\nTicket ID: ${widget.ticketId ?? _formattedTicketId}",
                      onDone: () {
                        // Navigate back to HomeScreen after completion
                        Navigator.of(context).pop(); // Close success dialog

                        // Navigate back to HomeScreen
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(
                            builder: (context) => const HomeScreen(),
                          ),
                          (route) => false, // Remove all previous routes
                        );
                      }, // Required parameter
                    ),
                  );

                  // Reset the flag after successful submission
                  setState(() {
                    _hasPostedSMPSData = false;
                  });
                  print(
                    'SMPS Screen: Reset _hasPostedSMPSData flag to false after final submission',
                  );
                }
              });
            } catch (e) {
              print('SMPS Screen: Error refreshing data: $e');
              // Fallback: show success dialog anyway after delay
              Future.delayed(const Duration(seconds: 2), () {
                if (mounted) {
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) => SuccessDialog(
                      ticketId: widget.ticketId ?? _formattedTicketId,
                      message:
                          "Asset Audit completed successfully!\n\nTicket ID: ${widget.ticketId ?? _formattedTicketId}",
                      onDone: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(
                            builder: (context) => const HomeScreen(),
                          ),
                          (route) => false,
                        );
                      },
                    ),
                  );
                  setState(() {
                    _hasPostedSMPSData = false;
                  });
                }
              });
            }
          } else {
            print(
              'SMPS Screen: Success state received but not for SMPS screen data, ignoring...',
            );
            print('SMPS Screen: _hasPostedSMPSData flag: $_hasPostedSMPSData');
          }
        } else if (state is AssetAuditPostError) {
          // Only show error message if this error belongs to SMPS screen data
          if (_hasPostedSMPSData) {
            print('SMPS Screen: AssetAuditPostError received for SMPS data');
            // Show error message and block completion
            showCustomToast(
              context,
              '❌ Failed to save SMPS data. Please try again.',
            );

            // Reset the flag on error
            setState(() {
              _hasPostedSMPSData = false;
            });
            print(
              'SMPS Screen: Reset _hasPostedSMPSData flag to false after error',
            );
          } else {
            print(
              'SMPS Screen: AssetAuditPostError received but not for SMPS data, ignoring...',
            );
          }
        }
      },
      child: PopScope(
        canPop: !hasUnsavedChanges,
        onPopInvoked: (didPop) async {
          if (didPop) return;

          if (hasUnsavedChanges) {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => UnsavedChangesDialog(
                message:
                    "Do you want to cancel the Asset Audit for Site (ID: SITE-38974) ?",
                onSaveAndExit: () {
                  _saveAndExit();
                },
                onDiscard: () {
                  Navigator.of(context).pop();
                },
              ),
            );
          }
        },
        child: Scaffold(
          extendBodyBehindAppBar: true,
          resizeToAvoidBottomInset: false,
          appBar: CustomFormAppbar(
            title: "Asset Audit",
            onClose: () async {
              if (hasUnsavedChanges) {
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => UnsavedChangesDialog(
                    message:
                        "Do you want to cancel the Asset Audit for Site (ID: SITE-38974) ?",
                    onSaveAndExit: () {
                      _saveAndExit();
                    },
                    onDiscard: () {
                      Navigator.of(context).pop();
                    },
                  ),
                );
              } else {
                Navigator.pop(context);
              }
            },
          ),
          body: Stack(
            children: [
              // Background image
              Positioned.fill(
                child: SvgPicture.asset(
                  AppImages.home,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                ),
              ),
              SafeArea(
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          padding: EdgeInsets.only(
                            bottom:
                                MediaQuery.of(context).viewInsets.bottom + 120,
                          ),
                          child: Container(
                            padding: const EdgeInsets.only(
                              top: 20,
                              left: 16,
                              right: 16,
                              bottom: 20,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CustomFormField(
                                  label: "SMPS Make",
                                  initialValue: _getSMPSOEMName(),
                                  isRequired: false,
                                  isEditable: false,
                                ),
                                getHeight(15),
                                CustomFormField(
                                  label: "Count of SMPS",
                                  // "Number of ${selectedType ?? 'Batteries'}",
                                  initialValue: totalRectifierItems.toString(),
                                  isRequired: false,
                                  isEditable: false,
                                  onChanged: (value) {
                                    setState(() {
                                      totalRectifierItems =
                                          int.tryParse(value) ?? 6;
                                      hasUnsavedChanges = true;
                                    });
                                  },
                                ),
                                getHeight(15),
                                CustomInfoCard(
                                  key: ValueKey('cabinet_$rectifierCardKey'),
                                  serialLabel: "Cabinet Serial Number",
                                  serialHintText: "Cabinet Serial Number",
                                  photoLabel:
                                      "Add Photo of Cabinet Serial Number",
                                  statusLabel: "Status",
                                  serialController: rectifierSerialController,
                                  // onSave: _saveRectifierForm,
                                  isStatusEditable: true,
                                  backendStatus: false,
                                  showSaveButton: false,
                                  onPhotoTap: (photoPath) async {
                                    setState(() {
                                      rectifierPhoto = photoPath;
                                      hasUnsavedChanges = true;
                                    });

                                    // Upload photo immediately and get photoId
                                    if (photoPath != null &&
                                        photoPath.isNotEmpty) {
                                      try {
                                        final photoFile = File(photoPath);
                                        if (await photoFile.exists()) {
                                          final photoId =
                                              await AssetAuditPhotoUploadHelper.uploadPhotoAndGetId(
                                                photoFile: photoFile,
                                                schId:
                                                    widget
                                                        .assetAuditData
                                                        ?.pageHeader
                                                        .first
                                                        .siteAuditSchId
                                                        .toString() ??
                                                    "0",
                                                imgId: null,
                                                context: context,
                                              );

                                          if (photoId != null) {
                                            setState(() {
                                              rectifierPhotoId = photoId;
                                            });
                                            print(
                                              'SMPS Screen: Cabinet Photo uploaded successfully, photoId: $photoId',
                                            );
                                          }
                                        }
                                      } catch (e) {
                                        print(
                                          'SMPS Screen: Error uploading Cabinet photo: $e',
                                        );
                                      }
                                    }
                                  },
                                  onStatusChanged: (val) {
                                    setState(() {
                                      rectifierStatus = val ? "OK" : "Not OK";
                                      hasUnsavedChanges = true;
                                    });
                                  },
                                  onSerialChanged: (serialNumber) {
                                    setState(() {
                                      rectifierSerialNumber = serialNumber;
                                      hasUnsavedChanges = true;
                                    });

                                    // Validate serial number (assume manual entry)
                                    if (serialNumber.isNotEmpty) {
                                      bool isValid = _validateSerialNumber(
                                        serialNumber,
                                        false,
                                      );
                                      if (!isValid) {
                                        // Clear the field if validation fails
                                        rectifierSerialController.clear();
                                        setState(() {
                                          rectifierSerialNumber = null;
                                          hasUnsavedChanges = false;
                                        });
                                      }
                                    }
                                  },
                                  initialStatus: rectifierStatus == "OK"
                                      ? true
                                      : (rectifierStatus == "Not OK"
                                            ? false
                                            : null),
                                  initialPhotoPath: rectifierPhoto,
                                  isEditable: true,
                                ),
                                _buildRectifierSavedItemsList(),

                                getHeight(15),
                                CustomFormField(
                                  label: "Count of Rectifiers",
                                  // "Number of ${selectedType ?? 'Batteries'}",
                                  initialValue: totalMPPTItems.toString(),
                                  isRequired: false,
                                  isEditable: false,
                                  onChanged: (value) {
                                    setState(() {
                                      totalMPPTItems =
                                          int.tryParse(value) ?? 6;
                                      hasUnsavedChanges = true;
                                    });
                                  },
                                ),
                                getHeight(15),
                                CustomInfoCard(
                                  key: ValueKey('mppt_$mpptCardKey'),
                                  serialLabel: "Rectifier - Serial Number",
                                  serialHintText: "Rectifier Serial Number",
                                  photoLabel: "Add a Photo",
                                  statusLabel: "Status",
                                  serialController: mpptSerialController,
                                  onSave: _saveMPPTForm,
                                  isStatusEditable: true,
                                  backendStatus: false,
                                  remarksController: mpptRemarksController,
                                  onPhotoTap: (photoPath) async {
                                    setState(() {
                                      mpptPhoto = photoPath;
                                      hasUnsavedChanges = true;
                                    });

                                    // Upload photo immediately and get photoId
                                    if (photoPath != null &&
                                        photoPath.isNotEmpty) {
                                      try {
                                        final photoFile = File(photoPath);
                                        if (await photoFile.exists()) {
                                          final photoId =
                                              await AssetAuditPhotoUploadHelper.uploadPhotoAndGetId(
                                                photoFile: photoFile,
                                                schId:
                                                    widget
                                                        .assetAuditData
                                                        ?.pageHeader
                                                        .first
                                                        .siteAuditSchId
                                                        .toString() ??
                                                    "0",
                                                imgId: null,
                                                context: context,
                                              );

                                          if (photoId != null) {
                                            setState(() {
                                              mpptPhotoId = photoId;
                                            });
                                            print(
                                              'SMPS Screen: Rectifier Photo uploaded successfully, photoId: $photoId',
                                            );
                                          }
                                        }
                                      } catch (e) {
                                        print(
                                          'SMPS Screen: Error uploading Rectifier photo: $e',
                                        );
                                      }
                                    }
                                  },
                                  onStatusChanged: (val) {
                                    setState(() {
                                      mpptStatus = val ? "OK" : "Not OK";
                                      hasUnsavedChanges = true;
                                    });
                                  },
                                  onSerialChanged: (serialNumber) {
                                    setState(() {
                                      mpptSerialNumber = serialNumber;
                                      hasUnsavedChanges = true;
                                    });

                                    // Validate serial number (assume manual entry)
                                    if (serialNumber.isNotEmpty) {
                                      bool isValid = _validateSerialNumber(
                                        serialNumber,
                                        false,
                                      );
                                      if (!isValid) {
                                        // Clear the field if validation fails
                                        mpptSerialController.clear();
                                        setState(() {
                                          mpptSerialNumber = null;
                                          hasUnsavedChanges = false;
                                        });
                                      }
                                    }
                                  },
                                  initialStatus: mpptStatus == "OK"
                                      ? true
                                      : (mpptStatus == "Not OK"
                                            ? false
                                            : null),
                                  initialPhotoPath: mpptPhoto,
                                  isEditable: true,
                                ),
                                getHeight(8),
                                _buildMPPTSavedItemsList(),
                                getHeight(15),
                                CustomInfoCard(
                                  key: ValueKey('acdb_$acdbCardKey'),
                                  serialLabel: "ACDB",
                                  serialHintText: "ACDB",
                                  photoLabel: "Add Photo",
                                  statusLabel: "Status",
                                  serialController: acdbSerialController,
                                  onSave: _saveACDBForm,
                                  isStatusEditable: true,
                                  backendStatus: false,
                                  showSaveButton: true,
                                  onPhotoTap: (photoPath) async {
                                    setState(() {
                                      acdbPhoto = photoPath;
                                      hasUnsavedChanges = true;
                                    });

                                    // Upload photo immediately and get photoId
                                    if (photoPath != null &&
                                        photoPath.isNotEmpty) {
                                      try {
                                        final photoFile = File(photoPath);
                                        if (await photoFile.exists()) {
                                          final photoId =
                                              await AssetAuditPhotoUploadHelper.uploadPhotoAndGetId(
                                                photoFile: photoFile,
                                                schId:
                                                    widget
                                                        .assetAuditData
                                                        ?.pageHeader
                                                        .first
                                                        .siteAuditSchId
                                                        .toString() ??
                                                    "0",
                                                imgId: null,
                                                context: context,
                                              );

                                          if (photoId != null) {
                                            setState(() {
                                              acdbPhotoId = photoId;
                                            });
                                            print(
                                              'SMPS Screen: ACDB Photo uploaded successfully, photoId: $photoId',
                                            );
                                          }
                                        }
                                      } catch (e) {
                                        print(
                                          'SMPS Screen: Error uploading ACDB photo: $e',
                                        );
                                      }
                                    }
                                  },
                                  onStatusChanged: (val) {
                                    setState(() {
                                      acdbStatus = val ? "OK" : "Not OK";
                                      hasUnsavedChanges = true;
                                    });
                                  },
                                  onSerialChanged: (serialNumber) {
                                    setState(() {
                                      acdbSerialNumber = serialNumber;
                                      hasUnsavedChanges = true;
                                    });

                                    // Validate serial number (assume manual entry)
                                    if (serialNumber.isNotEmpty) {
                                      bool isValid = _validateSerialNumber(
                                        serialNumber,
                                        false,
                                      );
                                      if (!isValid) {
                                        // Clear the field if validation fails
                                        acdbSerialController.clear();
                                        setState(() {
                                          acdbSerialNumber = null;
                                          hasUnsavedChanges = false;
                                        });
                                      }
                                    }
                                  },
                                  initialStatus: acdbStatus == "OK"
                                      ? true
                                      : (acdbStatus == "Not OK" ? false : null),
                                  initialPhotoPath: acdbPhoto,
                                  isEditable: true,
                                ),
                                getHeight(15),

                                _buildACDBSavedItemsList(),
                                getHeight(15),
                                CustomInfoCard(
                                  key: ValueKey('lspu_$lspuCardKey'),
                                  serialLabel: "LSPU",
                                  serialHintText: "LSPU",
                                  photoLabel: "Add Photo of LSPU",
                                  statusLabel: "Status",
                                  serialController: lspuSerialController,
                                  onSave: _saveLSPUForm,
                                  isStatusEditable: true,
                                  backendStatus: false,
                                  showSaveButton: true,
                                  onPhotoTap: (photoPath) async {
                                    setState(() {
                                      lspuPhoto = photoPath;
                                      hasUnsavedChanges = true;
                                    });

                                    // Upload photo immediately and get photoId
                                    if (photoPath != null &&
                                        photoPath.isNotEmpty) {
                                      try {
                                        final photoFile = File(photoPath);
                                        if (await photoFile.exists()) {
                                          final photoId =
                                              await AssetAuditPhotoUploadHelper.uploadPhotoAndGetId(
                                                photoFile: photoFile,
                                                schId:
                                                    widget
                                                        .assetAuditData
                                                        ?.pageHeader
                                                        .first
                                                        .siteAuditSchId
                                                        .toString() ??
                                                    "0",
                                                imgId: null,
                                                context: context,
                                              );

                                          if (photoId != null) {
                                            setState(() {
                                              lspuPhotoId = photoId;
                                            });
                                            print(
                                              'SMPS Screen: LSPU Photo uploaded successfully, photoId: $photoId',
                                            );
                                          }
                                        }
                                      } catch (e) {
                                        print(
                                          'SMPS Screen: Error uploading LSPU photo: $e',
                                        );
                                      }
                                    }
                                  },
                                  onStatusChanged: (val) {
                                    setState(() {
                                      lspuStatus = val ? "OK" : "Not OK";
                                      hasUnsavedChanges = true;
                                    });
                                  },
                                  onSerialChanged: (serialNumber) {
                                    setState(() {
                                      lspuSerialNumber = serialNumber;
                                      hasUnsavedChanges = true;
                                    });

                                    // Validate serial number (assume manual entry)
                                    if (serialNumber.isNotEmpty) {
                                      bool isValid = _validateSerialNumber(
                                        serialNumber,
                                        false,
                                      );
                                      if (!isValid) {
                                        // Clear the field if validation fails
                                        lspuSerialController.clear();
                                        setState(() {
                                          lspuSerialNumber = null;
                                          hasUnsavedChanges = false;
                                        });
                                      }
                                    }
                                  },
                                  initialStatus: lspuStatus == "OK"
                                      ? true
                                      : (lspuStatus == "Not OK" ? false : null),
                                  initialPhotoPath: lspuPhoto,
                                  isEditable: true,
                                ),
                                getHeight(8),
                                _buildLSPUSavedItemsList(),

                                getHeight(15),
                                CustomRemarksField(
                                  label: "Add Remarks",
                                  hintText: "Remarks",
                                  controller: generalRemarksController,
                                  // onChanged: (value) {
                                  //   setState(() {
                                  //     hasUnsavedChanges = true;
                                  //   });
                                  // },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      Container(
                        padding: const EdgeInsets.all(16),
                        width: double.infinity,
                        child: Row(
                          children: [
                            Expanded(
                              child: ArrowButton(
                                text: "DG",
                                isLeftArrow: true,
                                backgroundColor: AppColors.buttonColorBg,
                                textColor: AppColors.buttonColorSite,
                                onPressed: () {
                                  Navigator.pop(context);
                                },
                              ),
                            ),
                            getWidth(8),
                            Expanded(
                              child: ArrowButton(
                                text: "Submit",
                                isLeftArrow: false,
                                backgroundColor: AppColors.buttonColorBackBg,
                                textColor: AppColors.buttonColorTextBg,
                                onPressed: () async {
                                  // Submit all data directly to API
                                  _submitAllData();
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Build Rectifier saved items list
  Widget _buildRectifierSavedItemsList() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.green7,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: const Text(
                    "Serial",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontFamily: fontFamilyMontserrat,
                      fontWeight: FontWeight.w400,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: const Text(
                    "Scanned",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontFamily: fontFamilyMontserrat,
                      fontWeight: FontWeight.w400,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: const Text(
                    "Photo",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontFamily: fontFamilyMontserrat,
                      fontWeight: FontWeight.w400,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              // Expanded(
              //   child: Container(
              //     padding: const EdgeInsets.symmetric(horizontal: 4),
              //     child: const Text(
              //       "Capacity",
              //       textAlign: TextAlign.center,
              //       style: TextStyle(
              //         color: Colors.white,
              //         fontSize: 14,
              //         fontFamily: fontFamilyMontserrat,
              //         fontWeight: FontWeight.w400,
              //       ),
              //       maxLines: 1,
              //       overflow: TextOverflow.ellipsis,
              //     ),
              //   ),
              // ),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: const Text(
                    "Status",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontFamily: fontFamilyMontserrat,
                      fontWeight: FontWeight.w400,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: const Text(
                    "Edit",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontFamily: fontFamilyMontserrat,
                      fontWeight: FontWeight.w400,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
          getHeight(10),
          // Debug information
          Container(
            padding: const EdgeInsets.all(8),
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: Colors.blue.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue, size: 16),
                getWidth(8),
                Expanded(
                  child: Text(
                    'Saved Items: ${savedRectifierItems.length} | Current Scanned: $currentScannedItems | Total Expected: $totalRectifierItems',
                    style: TextStyle(
                      color: Colors.blue,
                      fontSize: 12,
                      fontFamily: fontFamilyMontserrat,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (savedRectifierItems.isNotEmpty)
            ...savedRectifierItems
                .map(
                  (item) => Container(
                    margin: const EdgeInsets.symmetric(vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Text(
                              item['serialNumber'] ?? 'N/A',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 14,
                                fontFamily: fontFamilyMontserrat,
                                fontWeight: FontWeight.w400,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Icon(
                              item['isQRCodeScanned'] == true
                                  ? Icons.check
                                  : Icons.close,
                              color: item['isQRCodeScanned'] == true
                                  ? Colors.green
                                  : Colors.red,
                              size: 20,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: _buildPhotoColumn(item),
                          ),
                        ),
                        // Expanded(
                        //   child: Container(
                        //     padding: const EdgeInsets.symmetric(horizontal: 4),
                        //     child: Text(
                        //       item['capacity'] ?? 'N/A',
                        //       textAlign: TextAlign.center,
                        //       style: const TextStyle(
                        //         color: Colors.black,
                        //         fontSize: 14,
                        //         fontFamily: fontFamilyMontserrat,
                        //         fontWeight: FontWeight.w400,
                        //       ),
                        //       maxLines: 1,
                        //       overflow: TextOverflow.ellipsis,
                        //     ),
                        //   ),
                        // ),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Text(
                              item['assetStatus'] ?? 'N/A',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 14,
                                fontFamily: fontFamilyMontserrat,
                                fontWeight: FontWeight.w400,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: IconButton(
                              onPressed: () =>
                                  _editSavedItem(item, 'rectifier'),
                              icon: const Icon(
                                Icons.edit,
                                color: AppColors.blue,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList()
          else
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.symmetric(vertical: 5),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(5),
                border: Border.all(color: Colors.grey.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.grey, size: 16),
                  getWidth(8),
                  Expanded(
                    child: Text(
                      'No saved items found. Items will appear here after they are saved with complete data (serial, photo, status).',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                        fontFamily: fontFamilyMontserrat,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // Build MPPT saved items list
  // Widget _buildMPPTSavedItemsList() {
  //   return Container(
  //     margin: const EdgeInsets.symmetric(vertical: 10),
  //     padding: const EdgeInsets.all(16),
  //     decoration: BoxDecoration(
  //       color: AppColors.green7,
  //       borderRadius: BorderRadius.circular(5),
  //     ),
  //     child: Column(
  //       crossAxisAlignment: CrossAxisAlignment.start,
  //       children: [
  //         Row(
  //           children: [
  //             Expanded(
  //               child: Container(
  //                 padding: const EdgeInsets.symmetric(horizontal: 4),
  //                 child: const Text(
  //                   "Serial",
  //                   textAlign: TextAlign.center,
  //                   style: TextStyle(
  //                     color: Colors.white,
  //                     fontSize: 14,
  //                     fontFamily: fontFamilyMontserrat,
  //                     fontWeight: FontWeight.w400,
  //                   ),
  //                   maxLines: 1,
  //                   overflow: TextOverflow.ellipsis,
  //                 ),
  //               ),
  //             ),
  //             Expanded(
  //               child: Container(
  //                 padding: const EdgeInsets.symmetric(horizontal: 4),
  //                 child: const Text(
  //                   "Scanned",
  //                   textAlign: TextAlign.center,
  //                   style: TextStyle(
  //                     color: Colors.white,
  //                     fontSize: 14,
  //                     fontFamily: fontFamilyMontserrat,
  //                     fontWeight: FontWeight.w400,
  //                   ),
  //                   maxLines: 1,
  //                   overflow: TextOverflow.ellipsis,
  //                 ),
  //               ),
  //             ),
  //             Expanded(
  //               child: Container(
  //                 padding: const EdgeInsets.symmetric(horizontal: 4),
  //                 child: const Text(
  //                   "Photo",
  //                   textAlign: TextAlign.center,
  //                   style: TextStyle(
  //                     color: Colors.white,
  //                     fontSize: 14,
  //                     fontFamily: fontFamilyMontserrat,
  //                     fontWeight: FontWeight.w400,
  //                   ),
  //                   maxLines: 1,
  //                   overflow: TextOverflow.ellipsis,
  //                 ),
  //               ),
  //             ),
  //             Expanded(
  //               child: Container(
  //                 padding: const EdgeInsets.symmetric(horizontal: 4),
  //                 child: const Text(
  //                   "Capacity",
  //                   textAlign: TextAlign.center,
  //                   style: TextStyle(
  //                     color: Colors.white,
  //                     fontSize: 14,
  //                     fontFamily: fontFamilyMontserrat,
  //                     fontWeight: FontWeight.w400,
  //                   ),
  //                   maxLines: 1,
  //                   overflow: TextOverflow.ellipsis,
  //                 ),
  //               ),
  //             ),
  //             Expanded(
  //               child: Container(
  //                 padding: const EdgeInsets.symmetric(horizontal: 4),
  //                 child: const Text(
  //                   "Status",
  //                   textAlign: TextAlign.center,
  //                   style: TextStyle(
  //                     color: Colors.white,
  //                     fontSize: 14,
  //                     fontFamily: fontFamilyMontserrat,
  //                     fontWeight: FontWeight.w400,
  //                   ),
  //                   maxLines: 1,
  //                   overflow: TextOverflow.ellipsis,
  //                 ),
  //               ),
  //             ),
  //             Expanded(
  //               child: Container(
  //                 padding: const EdgeInsets.symmetric(horizontal: 4),
  //                 child: const Text(
  //                   "Edit",
  //                   textAlign: TextAlign.center,
  //                   style: TextStyle(
  //                     color: Colors.white,
  //                     fontSize: 14,
  //                     fontFamily: fontFamilyMontserrat,
  //                     fontWeight: FontWeight.w400,
  //                   ),
  //                   maxLines: 1,
  //                   overflow: TextOverflow.ellipsis,
  //                 ),
  //               ),
  //             ),
  //               ],
  //             ),
  //           ],
  //         ),
  //         getHeight(10),
  //         // Debug information
  //         Container(
  //           padding: const EdgeInsets.all(8),
  //           margin: const EdgeInsets.only(bottom: 10),
  //           decoration: BoxDecoration(
  //             color: Colors.blue.withOpacity(0.1),
  //             borderRadius: BorderRadius.circular(5),
  //             border: Border.all(color: Colors.blue.withOpacity(0.3)),
  //           ),
  //           child: Row(
  //             children: [
  //               Icon(Icons.info_outline, color: Colors.blue, size: 16),
  //               getWidth(8),
  //               Expanded(
  //                 child: Text(
  //                   'Saved Items: ${savedMPPTItems.length} | Current Scanned: $currentScannedItems | Total Expected: $totalRectifierItems',
  //                   style: TextStyle(
  //                     color: Colors.blue,
  //                     fontSize: 12,
  //                     fontFamily: fontFamilyMontserrat,
  //                   ),
  //                 ),
  //               ),
  //             ],
  //           ),
  //         ),
  //        ...(savedMPPTItems.isNotEmpty
  //           ? savedMPPTItems
  //               .map(
  //                 (item) => Container(
  //                   margin: const EdgeInsets.symmetric(vertical: 5),
  //                   decoration: BoxDecoration(
  //                     color: Colors.white,
  //                     borderRadius: BorderRadius.circular(5),
  //                   ),
  //                   child: Row(
  //                     children: [
  //                       Expanded(
  //                         child: Container(
  //                           padding: const EdgeInsets.symmetric(horizontal: 4),
  //                           child: Text(
  //                             item['serialNumber'] ?? 'N/A',
  //                             textAlign: TextAlign.center,
  //                             style: const TextStyle(
  //                               color: Colors.black,
  //                               fontSize: 14,
  //                               fontFamily: fontFamilyMontserrat,
  //                               fontWeight: FontWeight.w400,
  //                             ),
  //                             maxLines: 1,
  //                             overflow: TextOverflow.ellipsis,
  //                           ),
  //                         ),
  //                       ),
  //                       Expanded(
  //                         child: Container(
  //                           padding: const EdgeInsets.symmetric(horizontal: 4),
  //                           child: Icon(
  //                             item['isQRCodeScanned'] == true
  //                                 ? Icons.check
  //                                 : Icons.close,
  //                             color: item['isQRCodeScanned'] == true
  //                                 ? Colors.green
  //                                 : Colors.red,
  //                             size: 20,
  //                           ),
  //                         ),
  //                       ),
  //                       Expanded(
  //                         child: Container(
  //                           padding: const EdgeInsets.symmetric(horizontal: 4),
  //                           child: item['photo'] != null || item['photoId'] != null
  //                               ? const Icon(
  //                                   Icons.photo_camera,
  //                                   color: AppColors.green7,
  //                                   size: 20,
  //                                 )
  //                               : Icon(
  //                                   Icons.photo_camera_outlined,
  //                                   color: AppColors.greyColor,
  //                                   size: 20,
  //                                 ),
  //                         ),
  //                       ),
  //                       Expanded(
  //                         child: Container(
  //                           padding: const EdgeInsets.symmetric(horizontal: 4),
  //                           child: Text(
  //                             item['capacity'] ?? 'N/A',
  //                             textAlign: TextAlign.center,
  //                             style: const TextStyle(
  //                               color: Colors.black,
  //                               fontSize: 14,
  //                               fontFamily: fontFamilyMontserrat,
  //                               fontWeight: FontWeight.w400,
  //                             ),
  //                             maxLines: 1,
  //                             overflow: TextOverflow.ellipsis,
  //                           ),
  //                         ),
  //                       ),
  //                       Expanded(
  //                         child: Container(
  //                           padding: const EdgeInsets.symmetric(horizontal: 4),
  //                           child: Text(
  //                             item['status'] ?? 'N/A',
  //                             textAlign: TextAlign.center,
  //                             style: const TextStyle(
  //                               color: Colors.black,
  //                               fontSize: 14,
  //                               fontFamily: fontFamilyMontserrat,
  //                               fontWeight: FontWeight.w400,
  //                             ),
  //                             maxLines: 1,
  //                             overflow: TextOverflow.ellipsis,
  //                           ),
  //                         ),
  //                       ),
  //                       Expanded(
  //                         child: Container(
  //                           padding: const EdgeInsets.symmetric(horizontal: 4),
  //                           child: IconButton(
  //                             onPressed: () => _editSavedItem(item, 'mppt'),
  //                             icon: const Icon(
  //                               Icons.edit,
  //                               color: AppColors.blue,
  //                               size: 20,
  //                             ),
  //                           ),
  //                         ),
  //                       ),
  //                     ],
  //                   ),
  //                 ),
  //               )
  //               .toList()
  //           : [])
  //   );
  // }

  // Build MPPT saved items list
  Widget _buildMPPTSavedItemsList() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.green7,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: const Text(
                    "Serial",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontFamily: fontFamilyMontserrat,
                      fontWeight: FontWeight.w400,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: const Text(
                    "Scanned",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontFamily: fontFamilyMontserrat,
                      fontWeight: FontWeight.w400,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: const Text(
                    "Photo",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontFamily: fontFamilyMontserrat,
                      fontWeight: FontWeight.w400,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              // Expanded(
              //   child: Container(
              //     padding: const EdgeInsets.symmetric(horizontal: 4),
              //     child: const Text(
              //       "Capacity",
              //       textAlign: TextAlign.center,
              //       style: TextStyle(
              //         color: Colors.white,
              //         fontSize: 14,
              //         fontFamily: fontFamilyMontserrat,
              //         fontWeight: FontWeight.w400,
              //       ),
              //       maxLines: 1,
              //       overflow: TextOverflow.ellipsis,
              //     ),
              //   ),
              // ),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: const Text(
                    "Status",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontFamily: fontFamilyMontserrat,
                      fontWeight: FontWeight.w400,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: const Text(
                    "Edit",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontFamily: fontFamilyMontserrat,
                      fontWeight: FontWeight.w400,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
          getHeight(10),
          // Debug information
          Container(
            padding: const EdgeInsets.all(8),
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: Colors.blue.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.blue, size: 16),
                getWidth(8),
                Expanded(
                  child: Text(
                    'Saved Items: ${savedMPPTItems.length} | Current Scanned: $currentScannedItems | Total Expected: $totalRectifierItems',
                    style: const TextStyle(
                      color: Colors.blue,
                      fontSize: 12,
                      fontFamily: fontFamilyMontserrat,
                    ),
                  ),
                ),
              ],
            ),
          ),
          ...(savedMPPTItems.isNotEmpty
              ? savedMPPTItems
                    .map(
                      (item) => Container(
                        margin: const EdgeInsets.symmetric(vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                child: Text(
                                  item['serialNumber'] ?? 'N/A',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontSize: 14,
                                    fontFamily: fontFamilyMontserrat,
                                    fontWeight: FontWeight.w400,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                child: Icon(
                                  item['isQRCodeScanned'] == true
                                      ? Icons.check
                                      : Icons.close,
                                  color: item['isQRCodeScanned'] == true
                                      ? Colors.green
                                      : Colors.red,
                                  size: 20,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                child:
                                    item['photo'] != null ||
                                        item['photoId'] != null
                                    ? const Icon(
                                        Icons.photo_camera,
                                        color: AppColors.green7,
                                        size: 20,
                                      )
                                    : const Icon(
                                        Icons.photo_camera_outlined,
                                        color: AppColors.greyColor,
                                        size: 20,
                                      ),
                              ),
                            ),
                            // Expanded(
                            //   child: Container(
                            //     padding: const EdgeInsets.symmetric(
                            //       horizontal: 4,
                            //     ),
                            //     child: Text(
                            //       item['capacity'] ?? 'N/A',
                            //       textAlign: TextAlign.center,
                            //       style: const TextStyle(
                            //         color: Colors.black,
                            //         fontSize: 14,
                            //         fontFamily: fontFamilyMontserrat,
                            //         fontWeight: FontWeight.w400,
                            //       ),
                            //       maxLines: 1,
                            //       overflow: TextOverflow.ellipsis,
                            //     ),
                            //   ),
                            // ),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                child: Text(
                                  item['assetStatus'] ?? 'N/A',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontSize: 14,
                                    fontFamily: fontFamilyMontserrat,
                                    fontWeight: FontWeight.w400,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                child: IconButton(
                                  onPressed: () => _editSavedItem(item, 'mppt'),
                                  icon: const Icon(
                                    Icons.edit,
                                    color: AppColors.blue,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList()
              : []),
        ],
      ),
    );
  }

  // Build ACDB saved items list
  Widget _buildACDBSavedItemsList() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.green7,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: const Text(
                    "Serial",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontFamily: fontFamilyMontserrat,
                      fontWeight: FontWeight.w400,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: const Text(
                    "Scanned",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontFamily: fontFamilyMontserrat,
                      fontWeight: FontWeight.w400,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: const Text(
                    "Photo",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontFamily: fontFamilyMontserrat,
                      fontWeight: FontWeight.w400,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              // Expanded(
              //   child: Container(
              //     padding: const EdgeInsets.symmetric(horizontal: 4),
              //     child: const Text(
              //       "Capacity",
              //       textAlign: TextAlign.center,
              //       style: TextStyle(
              //         color: Colors.white,
              //         fontSize: 14,
              //         fontFamily: fontFamilyMontserrat,
              //         fontWeight: FontWeight.w400,
              //       ),
              //       maxLines: 1,
              //       overflow: TextOverflow.ellipsis,
              //     ),
              //   ),
              // ),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: const Text(
                    "Status",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontFamily: fontFamilyMontserrat,
                      fontWeight: FontWeight.w400,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: const Text(
                    "Edit",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontFamily: fontFamilyMontserrat,
                      fontWeight: FontWeight.w400,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
          getHeight(10),
          // Debug information
          Container(
            padding: const EdgeInsets.all(8),
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: Colors.blue.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue, size: 16),
                getWidth(8),
                Expanded(
                  child: Text(
                    'Saved Items: ${savedACDBItems.length} | Current Scanned: $currentScannedItems | Total Expected: $totalRectifierItems',
                    style: TextStyle(
                      color: Colors.blue,
                      fontSize: 12,
                      fontFamily: fontFamilyMontserrat,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (savedACDBItems.isNotEmpty)
            ...savedACDBItems
                .map(
                  (item) => Container(
                    margin: const EdgeInsets.symmetric(vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Text(
                              item['serialNumber'] ?? 'N/A',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 14,
                                fontFamily: fontFamilyMontserrat,
                                fontWeight: FontWeight.w400,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Icon(
                              item['isQRCodeScanned'] == true
                                  ? Icons.check
                                  : Icons.close,
                              color: item['isQRCodeScanned'] == true
                                  ? Colors.green
                                  : Colors.red,
                              size: 20,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child:
                                item['photo'] != null || item['photoId'] != null
                                ? const Icon(
                                    Icons.photo_camera,
                                    color: AppColors.green7,
                                    size: 20,
                                  )
                                : Icon(
                                    Icons.photo_camera_outlined,
                                    color: AppColors.greyColor,
                                    size: 20,
                                  ),
                          ),
                        ),
                        // Expanded(
                        //   child: Container(
                        //     padding: const EdgeInsets.symmetric(horizontal: 4),
                        //     child: Text(
                        //       item['capacity'] ?? 'N/A',
                        //       textAlign: TextAlign.center,
                        //       style: const TextStyle(
                        //         color: Colors.black,
                        //         fontSize: 14,
                        //         fontFamily: fontFamilyMontserrat,
                        //         fontWeight: FontWeight.w400,
                        //       ),
                        //       maxLines: 1,
                        //       overflow: TextOverflow.ellipsis,
                        //     ),
                        //   ),
                        // ),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Text(
                              item['assetStatus'] ?? 'N/A',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 14,
                                fontFamily: fontFamilyMontserrat,
                                fontWeight: FontWeight.w400,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: IconButton(
                              onPressed: () => _editSavedItem(item, 'acdb'),
                              icon: const Icon(
                                Icons.edit,
                                color: AppColors.blue,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList()
          else
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.symmetric(vertical: 5),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(5),
                border: Border.all(color: Colors.grey.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.grey, size: 16),
                  getWidth(8),
                  Expanded(
                    child: Text(
                      'No saved items found. Items will appear here after they are saved with complete data (serial, photo, status).',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                        fontFamily: fontFamilyMontserrat,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // Build LSPU saved items list
  Widget _buildLSPUSavedItemsList() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.green7,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: const Text(
                    "Serial",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontFamily: fontFamilyMontserrat,
                      fontWeight: FontWeight.w400,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: const Text(
                    "Scanned",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontFamily: fontFamilyMontserrat,
                      fontWeight: FontWeight.w400,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: const Text(
                    "Photo",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontFamily: fontFamilyMontserrat,
                      fontWeight: FontWeight.w400,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              // Expanded(
              //   child: Container(
              //     padding: const EdgeInsets.symmetric(horizontal: 4),
              //     child: const Text(
              //       "Capacity",
              //       textAlign: TextAlign.center,
              //       style: TextStyle(
              //         color: Colors.white,
              //         fontSize: 14,
              //         fontFamily: fontFamilyMontserrat,
              //         fontWeight: FontWeight.w400,
              //       ),
              //       maxLines: 1,
              //       overflow: TextOverflow.ellipsis,
              //     ),
              //   ),
              // ),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: const Text(
                    "Status",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontFamily: fontFamilyMontserrat,
                      fontWeight: FontWeight.w400,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: const Text(
                    "Edit",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontFamily: fontFamilyMontserrat,
                      fontWeight: FontWeight.w400,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),

          getHeight(10),

          // Debug info
          Container(
            padding: const EdgeInsets.all(8),
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: Colors.blue.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.blue, size: 16),
                getWidth(8),
                Expanded(
                  child: Text(
                    'Saved Items: ${savedLSPUItems.length} | Current Scanned: $currentScannedItems | Total Expected: $totalRectifierItems',
                    style: const TextStyle(
                      color: Colors.blue,
                      fontSize: 12,
                      fontFamily: fontFamilyMontserrat,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Saved items list
          ...(savedLSPUItems.isNotEmpty
              ? savedLSPUItems
                    .map(
                      (item) => Container(
                        margin: const EdgeInsets.symmetric(vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                child: Text(
                                  item['serialNumber'] ?? 'N/A',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontSize: 14,
                                    fontFamily: fontFamilyMontserrat,
                                    fontWeight: FontWeight.w400,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                child: Icon(
                                  item['isQRCodeScanned'] == true
                                      ? Icons.check
                                      : Icons.close,
                                  color: item['isQRCodeScanned'] == true
                                      ? Colors.green
                                      : Colors.red,
                                  size: 20,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                child:
                                    item['photo'] != null ||
                                        item['photoId'] != null
                                    ? const Icon(
                                        Icons.photo_camera,
                                        color: AppColors.green7,
                                        size: 20,
                                      )
                                    : const Icon(
                                        Icons.photo_camera_outlined,
                                        color: AppColors.greyColor,
                                        size: 20,
                                      ),
                              ),
                            ),
                            // Expanded(
                            //   child: Container(
                            //     padding: const EdgeInsets.symmetric(
                            //       horizontal: 4,
                            //     ),
                            //     child: Text(
                            //       item['capacity'] ?? 'N/A',
                            //       textAlign: TextAlign.center,
                            //       style: const TextStyle(
                            //         color: Colors.black,
                            //         fontSize: 14,
                            //         fontFamily: fontFamilyMontserrat,
                            //         fontWeight: FontWeight.w400,
                            //       ),
                            //       maxLines: 1,
                            //       overflow: TextOverflow.ellipsis,
                            //     ),
                            //   ),
                            // ),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                child: Text(
                                  item['assetStatus'] ?? 'N/A',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontSize: 14,
                                    fontFamily: fontFamilyMontserrat,
                                    fontWeight: FontWeight.w400,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                child: IconButton(
                                  onPressed: () => _editSavedItem(item, 'lspu'),
                                  icon: const Icon(
                                    Icons.edit,
                                    color: AppColors.blue,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList()
              : [
                  // No items fallback
                  Container(
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.symmetric(vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(color: Colors.grey.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline,
                          color: Colors.grey,
                          size: 16,
                        ),
                        getWidth(8),
                        const Expanded(
                          child: Text(
                            'No saved items found. Items will appear here after they are saved with complete data (serial, photo, status).',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                              fontFamily: fontFamilyMontserrat,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ]),
        ],
      ),
    );
  }

  /// Edit a saved item based on its type
  void _editSavedItem(Map<String, dynamic> item, String itemType) {
    // Debug: Print the item data to see what's actually stored
    print('=== EDITING $itemType ITEM ===');
    print('Item data: $item');
    print('Serial Number: ${item['serialNumber']}');
    print('Status: ${item['assetStatus']}');
    print('Photo: ${item['photo']}');
    print('Photo ID: ${item['photoId']}');
    print('=============================');

    setState(() {
      // Populate the form fields with the item's data for editing
      switch (itemType) {
        case 'rectifier':
          // Populate rectifier form with item data
          rectifierSerialController.text = item['serialNumber'] ?? '';
          rectifierSerialNumber = item['serialNumber'] ?? '';
          rectifierStatus = item['assetStatus'] ?? 'OK';
          rectifierPhotoId = item['photoId'];
          rectifierPhoto = item['photo'];

          // Remove the item from saved list since it's now in the form for editing
          savedRectifierItems.remove(item);
          currentScannedItems--;
          break;

        case 'mppt':
          // Populate MPPT form with item data
          mpptSerialController.text = item['serialNumber'] ?? '';
          mpptSerialNumber = item['serialNumber'] ?? '';
          mpptStatus = item['assetStatus'] ?? 'OK';
          mpptPhotoId = item['photoId'];
          mpptPhoto = item['photo'];

          // Remove the item from saved list since it's now in the form for editing
          savedMPPTItems.remove(item);
          currentScannedItems--;
          break;

        case 'acdb':
          // Populate ACDB form with item data
          acdbSerialController.text = item['serialNumber'] ?? '';
          acdbSerialNumber = item['serialNumber'] ?? '';
          acdbStatus = item['assetStatus'] ?? 'OK';
          acdbPhotoId = item['photoId'];
          acdbPhoto = item['photo'];

          // Remove the item from saved list since it's now in the form for editing
          savedACDBItems.remove(item);
          currentScannedItems--;
          break;

        case 'lspu':
          // Populate LSPU form with item data
          lspuSerialController.text = item['serialNumber'] ?? '';
          lspuSerialNumber = item['serialNumber'] ?? '';
          lspuStatus = item['assetStatus'] ?? 'OK';
          lspuPhotoId = item['photoId'];
          lspuPhoto = item['photo'];

          // Remove the item from saved list since it's now in the form for editing
          savedLSPUItems.remove(item);
          currentScannedItems--;
          break;
      }

      // Mark that there are unsaved changes
      hasUnsavedChanges = true;

      // Show a message to the user
      showCustomToast(
        context,
        'Item loaded for editing. Make your changes and save.',
      );
    });
  }
}
