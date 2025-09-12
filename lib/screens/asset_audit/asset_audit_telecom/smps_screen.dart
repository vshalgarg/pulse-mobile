import 'dart:async';
import 'dart:io';
import 'dart:convert';

import 'package:app/commonWidgets/custom_buttons/arrow_botton.dart';
import 'package:app/constants/constants_methods.dart';
import 'package:app/screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';
import '../../../models/asset_audit_model.dart';
import '../../../utils/asset_audit_post_helper.dart';
import '../../../utils/asset_audit_photo_upload_helper.dart';
import '../../../bloc/asset_audit_cubit.dart';
import '../../../bloc/asset_audit_state.dart';
import '../../../bloc/asset_audit_get_image_cubit.dart';
import '../../../bloc/audit_schedule_status_cubit.dart';

import '../../../commonWidgets/asset_type_card.dart';
import '../../../commonWidgets/custom_dialogs/success_dialog.dart';
import '../../../commonWidgets/custom_dialogs/unsaved_changes_dialog.dart';
import '../../../commonWidgets/custom_form_appbar.dart';
import '../../../commonWidgets/custom_form_field.dart';
import '../../../commonWidgets/custom_remark.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_images.dart';
import '../../../constants/constants_strings.dart';
import '../../../commonWidgets/base64_image_widget.dart';
import '../../../repositories/image_repository.dart';
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

  // Image loading variables
  String? _currentRequestedImageId;
  bool _isRequestingImage = false;

  // Image loading infrastructure for edit mode
  String? _editingItemType;
  bool isEditingItem = false;

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


  bool _hasPostedSMPSData = false;

  // Ticket ID from backend for final submission
  String? _ticketId;

  // Image service for fetching images from API
  late ImageRepository _imageService;

  // Cache for storing fetched images
  Map<int, String> _imageCache = {};

  void _navigateToHomeScreen() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const HomeScreen()),
          (route) => false, // Remove all previous routes
    );
  }

  /// Get asset audit site response ID from GET API response for a specific item type
  int _getAssetAuditSiteRespId(String itemType) {
    if (widget.smpsData == null) {
      return 0; // Default ID
    }

    final smpsAssets = widget.smpsData!.assets ?? [];
    if (smpsAssets.isNotEmpty) {
      for (var asset in smpsAssets) {
        if (asset.assetAuditSiteRespId != null &&
            asset.assetAuditSiteRespId! > 0) {
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

        if (firstItem.assetAuditSiteRespId != null &&
            firstItem.assetAuditSiteRespId! > 0) {
          return firstItem.assetAuditSiteRespId!;
        }
      }
    } else if (itemType == 'SMPS MPPT') {
      final smpsMpptItems = widget.smpsData!.smpsMppt;
      if (smpsMpptItems != null && smpsMpptItems.isNotEmpty) {
        final firstItem = smpsMpptItems.first;

        if (firstItem.assetAuditSiteRespId != null &&
            firstItem.assetAuditSiteRespId! > 0) {
          return firstItem.assetAuditSiteRespId!;
        }
      }
    } else if (itemType == 'SMPS Cabinet') {
      final smpsCabinetItems = widget.smpsData!.smpsCabinet;
      if (smpsCabinetItems != null && smpsCabinetItems.isNotEmpty) {
        final firstItem = smpsCabinetItems.first;
        if (firstItem.assetAuditSiteRespId != null &&
            firstItem.assetAuditSiteRespId! > 0) {
          return firstItem.assetAuditSiteRespId!;
        }
      }
    } else if (itemType == 'ACDB') {
      final acdbItems = widget.smpsData!.acdb;
      if (acdbItems != null && acdbItems.isNotEmpty) {
        final firstItem = acdbItems.first;

        if (firstItem.assetAuditSiteRespId != null &&
            firstItem.assetAuditSiteRespId! > 0) {
          return firstItem.assetAuditSiteRespId!;
        }
      }
    } else if (itemType == 'LSPU') {
      final lspuItems = widget.smpsData!.lspu;
      if (lspuItems != null && lspuItems.isNotEmpty) {
        final firstItem = lspuItems.first;

        if (firstItem.assetAuditSiteRespId != null &&
            firstItem.assetAuditSiteRespId! > 0) {
          return firstItem.assetAuditSiteRespId!;
        }
      }
    }

    final remarks = widget.smpsData!.remarks;
    if (remarks.isNotEmpty) {
      for (var remark in remarks) {
        if (remark.assetAuditSiteRespId != null &&
            remark.assetAuditSiteRespId! > 0) {
          return remark.assetAuditSiteRespId!;
        }
      }
    } else {
      print('SMPS Screen: No remarks found');
    }

    return 0; // Default ID
  }

  /// Load ticket ID from backend data for final submission
  void _loadTicketIdFromBackend() {
    if (widget.ticketId != null && widget.ticketId!.isNotEmpty) {
      _ticketId = widget.ticketId;

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
        } else {
          // Fallback to site audit schedule ID
          _ticketId = 'SITE-${pageHeader.siteAuditSchId}';
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
      'AUDIT-${now.year}${now.month.toString().padLeft(2, '0')}${now.day
          .toString().padLeft(2, '0')}-${now.hour.toString().padLeft(
          2, '0')}${now.minute.toString().padLeft(2, '0')}';
    }
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
      '${formatted.substring(0, 15)}...${formatted.substring(
          formatted.length - 15)}';
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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Initialize image service
      _imageService = ImageRepository(AppConfig
          .of(context)
          .apiProvider);

      // Load SMPS data if available
      _loadSMPSData();

      // Show success message if coming from DG Screen
      if (widget.showSuccessMessage) {
        // DG data saved successfully
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
              '    - isFilled: ${item.assetStatus != null ||
                  item.photoId != null}',
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
              '    - isFilled: ${item.assetStatus != null ||
                  item.photoId != null}',
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
              '    - isFilled: ${item.assetStatus != null ||
                  item.photoId != null}',
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
              '    - isFilled: ${item.assetStatus != null ||
                  item.photoId != null}',
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
              '    - isFilled: ${item.assetStatus != null ||
                  item.photoId != null}',
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
              '    - isFilled: ${item.assetStatus != null ||
                  item.photoId != null}',
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
      });
    } else {
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


    for (var item in savedMPPTItems) {
      if (item['photoId'] != null) {
        photoIds.add(item['photoId']);
      }
    }


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

    try {
      // Fetch images from API
      final imageMap = await _imageService.fetchImagesByIds(photoIds.toList());

      // Update cache
      setState(() {
        _imageCache.addAll(imageMap);
      });
    } catch (e) {
      print('SMPS Screen: Error loading images: $e');
    }
  }

  /// Build photo column for saved items list
  Widget _buildPhotoColumn(Map<String, dynamic> item) {
    final photoId = item['photoId'];
    final imageName = item['image_name'];

    if (photoId == null) {
      return Icon(
        Icons.photo_camera_outlined,
        color: AppColors.greyColor,
        size: 20,
      );
    }

    // Show camera icon that opens image viewer
    return GestureDetector(
      onTap: () {
        // Check if image is cached first
        final imageData = _imageCache[photoId.toString()];
        if (imageData != null) {
          _showImageDialog(imageData, imageName);
        } else {
          // Show image using photo ID
          _showImageDialog(photoId.toString(), imageName);
        }
      },
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: AppColors.green7, width: 1),
        ),
        child: const Icon(
          Icons.camera_alt,
          color: AppColors.green7,
          size: 16,
        ),
      ),
    );
  }

  /// Show image in full screen dialog
  Future<void> _showImageDialog(String? imagePath, String? imageName) async {
    if (imagePath == null && imageName == null) {
      showCustomToast(context, 'No photo available to view.');
      return;
    }

    String? imageData;

    // Case 1: Photo is a base64 data URL
    if (imagePath!.startsWith('data:image/')) {
      imageData = imagePath;
    }
    // Case 2: Photo is a local file path
    else if (await File(imagePath).exists()) {
      imageData = imagePath;
    }
    // Case 3: Photo is a photo ID (numeric) from the API
    else if (_isNumeric(imagePath)) {
      print('Fetching image for photo ID: $imagePath');
      final completer = Completer<String?>();
      late StreamSubscription subscription;

      subscription = context
          .read<AssetAuditGetImageCubit>()
          .stream
          .listen((state) {
        if (state is AssetAuditGetImageSuccess && state.imageData.isNotEmpty) {
          print('Image fetched successfully for photo ID: $imagePath');
          final finalImageData = state.imageData.startsWith('data:image/')
              ? state.imageData
              : 'data:image/jpeg;base64,${state.imageData}';
          completer.complete(finalImageData);
          subscription.cancel();
        } else if (state is AssetAuditGetImageFailure) {
          print('Failed to fetch image: ${state.errorMessage}');
          showCustomToast(
              context, 'Failed to load image: ${state.errorMessage}');
          completer.complete(null);
          subscription.cancel();
        }
      });

      context.read<AssetAuditGetImageCubit>().getImage(
        imgId: imagePath,
        schId: widget.assetAuditData?.pageHeader.first.siteAuditSchId
            ?.toString() ?? '',
      );

      imageData = await completer.future;
    }

    if (imageData != null && imageData.isNotEmpty) {
      showDialog(
        context: context,
        builder: (context) =>
            Dialog(
              backgroundColor: Colors.black,
              child: Stack(
                children: [
                  Container(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery
                          .of(context)
                          .size
                          .height * 0.7,
                      maxWidth: MediaQuery
                          .of(context)
                          .size
                          .width * 0.9,
                    ),
                    child: imageData!.startsWith('data:image/')
                        ? Image.memory(
                      base64Decode(imageData
                          .split(',')
                          .last),
                      fit: BoxFit.contain,
                    )
                        : Image.file(
                      File(imageData),
                      fit: BoxFit.contain,
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: IconButton(
                      icon: const Icon(
                        Icons.close,
                        color: Colors.red,
                        size: 30,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ],
              ),
            ),
      );
    } else {
      showCustomToast(context, 'Unable to load photo.');
    }
  }

  /// Check if string is numeric
  bool _isNumeric(String str) {
    return int.tryParse(str) != null;
  }

  /// Load image for editing
  void _loadImageForEdit(String photoId, String itemType) {
    print(
        'SMPS Debug: _loadImageForEdit called - photoId: $photoId, itemType: $itemType');
    if (photoId.isNotEmpty && _isNumeric(photoId)) {
      // Set the current requested image ID for this screen
      _currentRequestedImageId = photoId;
      _isRequestingImage = true;
      _editingItemType = itemType;

      // Request the image
      context.read<AssetAuditGetImageCubit>().getImage(
        imgId: photoId,
        schId: widget.assetAuditData?.pageHeader.first.siteAuditSchId
            ?.toString() ?? '',
      );

      print(
          'SMPS Debug: Loading image for edit - photoId: $photoId, itemType: $itemType');
    } else {
      print('SMPS Debug: PhotoId is empty or not numeric: $photoId');
    }
  }

  /// Load saved items from API - items with serial numbers (photo and status can be missing)
  void _loadSavedItemsFromAPI() {
    if (widget.smpsData == null) {
      print('SMPS Screen: No SMPS data available');
      return;
    }

    setState(() {
      // Clear existing saved items to avoid duplicates
      savedRectifierItems.clear();
      savedMPPTItems.clear();
      savedACDBItems.clear();
      savedLSPUItems.clear();
      currentScannedItems = 0;

      // Load SMPS assets (from assets array)
      final smpsAssets = widget.smpsData!.assets;

      for (var item in smpsAssets) {
        if (item.mfgSerialNo != null || item.nexgenSerialNo != null) {
          Map<String, dynamic> savedItem = {
            'serialNumber':
            item.mfgSerialNo ?? item.nexgenSerialNo ?? 'Unknown',
            'photo': null,
            'photoId': item.photoId,
            'status': item.assetStatus ?? 'Pending',
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
        } else {
          print('SMPS Screen: Skipped SMPS asset item - no serial number: ${item
              .itemType}');
        }
      }

      // Load SMPS Rectifiers (from subcategories)
      final smpsRectifiersItems = widget.smpsData!.smpsRectifiers ?? [];
      print('SMPS Screen: Found ${smpsRectifiersItems.length} SMPS Rectifiers');

      for (var item in smpsRectifiersItems) {
        // Show items that have serial numbers (even if photo or status is missing)
        if (item.mfgSerialNo != null || item.nexgenSerialNo != null) {
          Map<String, dynamic> savedItem = {
            'serialNumber':
            item.mfgSerialNo ?? item.nexgenSerialNo ?? 'Unknown',
            'photo': null,
            'photoId': item.photoId,
            'status': item.assetStatus ?? 'Pending',
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
        } else {
          print(
              'SMPS Screen: Skipped SMPS Rectifier item - no serial number: ${item
                  .itemType}');
        }
      }

      // Load SMPS MPPT (from subcategories)
      final smpsMpptItems = widget.smpsData!.smpsMppt ?? [];

      for (var item in smpsMpptItems) {
        // Show items that have serial numbers (even if photo or status is missing)
        if (item.mfgSerialNo != null || item.nexgenSerialNo != null) {
          Map<String, dynamic> savedItem = {
            'serialNumber':
            item.mfgSerialNo ?? item.nexgenSerialNo ?? 'Unknown',
            'photo': null,
            'photoId': item.photoId,
            'status': item.assetStatus ?? 'Pending',
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
        } else {
          print('SMPS Screen: Skipped SMPS MPPT item - no serial number: ${item
              .itemType}');
        }
      }

      // Load ACDB (from subcategories)
      final acdbItems = widget.smpsData!.acdb ?? [];

      for (var item in acdbItems) {
        // Show items that have serial numbers (even if photo or status is missing)
        if (item.mfgSerialNo != null || item.nexgenSerialNo != null) {
          Map<String, dynamic> savedItem = {
            'serialNumber':
            item.mfgSerialNo ?? item.nexgenSerialNo ?? 'Unknown',
            'photo': null,
            'photoId': item.photoId,
            'status': item.assetStatus ?? 'Pending',
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
        } else {
          print('SMPS Screen: Skipped ACDB item - no serial number: ${item
              .itemType}');
        }
      }

      // Load LSPU (from subcategories)
      final lspuItems = widget.smpsData!.lspu ?? [];

      for (var item in lspuItems) {
        // Show items that have serial numbers (even if photo or status is missing)
        if (item.mfgSerialNo != null || item.nexgenSerialNo != null) {
          Map<String, dynamic> savedItem = {
            'serialNumber':
            item.mfgSerialNo ?? item.nexgenSerialNo ?? 'Unknown',
            'photo': null,
            'photoId': item.photoId,
            'status': item.assetStatus ?? 'Pending',
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
        } else {
          print('SMPS Screen: Skipped LSPU item - no serial number: ${item
              .itemType}');
        }
      }

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
  }

  void _saveAndExit() async {
    // First close the unsaved changes dialog
    Navigator.of(context).pop();

    try {
      await _postCurrentScreenData();

      // Update audit schedule status to "In Progress"
      if (mounted) {
        context.read<AuditScheduleStatusCubit>().updateStatus(
          siteAuditSchId: widget.assetAuditData?.pageHeader.first.siteAuditSchId
              .toString() ?? "",
          status: "IN-PROGRESS",
        );
      }
    } catch (e) {
      print('Error posting Extinguisher data: $e');
    }

    // Then show success dialog with a clean barrier
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => HomeScreen(),
        ),
      );
    }
  }

  /// Close with In Progress status (when no unsaved changes)
  void _closeWithInProgressStatus() async {
    // Post data to API first
    try {
      await _postCurrentScreenData();

      // Update audit schedule status to "In Progress"
      if (mounted) {
        context.read<AuditScheduleStatusCubit>().updateStatus(
          siteAuditSchId: widget.assetAuditData?.pageHeader.first.siteAuditSchId
              .toString() ?? "",
          status: "IN-PROGRESS",
        );
      }
    } catch (e) {
      print('Error posting SMPS data: $e');
    }

    // Navigate back
    if (mounted) {
      Navigator.pop(context);
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

    String? photo = rectifierPhoto ?? mpptPhoto ?? acdbPhoto ?? lspuPhoto;

    if (photo == null || photo.isEmpty) {
      print(' Photo validation failed');
      return false;
    } else {
      print('Photo validation passed');
    }

    // Check if photo ID is present (required for all items)
    int? photoId = rectifierPhotoId ?? mpptPhotoId ?? acdbPhotoId ??
        lspuPhotoId;
    if (photo != null && photoId == null) {
      print('Photo ID validation failed - photo exists but no photoId');
      return false;
    } else {
      print('Photo ID validation passed');
    }

    // Note: status is not required since it comes from API
    // and is set to true by default (backendStatus: true)

    return true;
  }

  bool _validateForm() {
    showValidationErrors = true;


    String? serialNumber = rectifierSerialController.text.isNotEmpty
        ? rectifierSerialController.text
        : mpptSerialController.text.isNotEmpty
        ? mpptSerialController.text
        : acdbSerialController.text.isNotEmpty
        ? acdbSerialController.text
        : lspuSerialController.text.isNotEmpty
        ? lspuSerialController.text
        : null;


    if (serialNumber == null || serialNumber.isEmpty) {
      print(' Serial number validation failed');
      return false;
    } else {
      print(' Serial number validation passed');
    }

    String? photo = rectifierPhoto ?? mpptPhoto ?? acdbPhoto ?? lspuPhoto;

    if (photo == null || photo.isEmpty) {
      print(' Photo validation failed');
      return false;
    } else {
      print(' Photo validation passed');
    }


    return true;
  }

  // Save current form data for Rectifier
  void _saveRectifierForm() {
    // Check against SMPS Cabinet items that already have both photo_id and asset_status
    int completedRectifierCount = (widget.smpsData?.smpsCabinet?.where((item) =>
    item.photoId != null && item.assetStatus != null).length ?? 0);
    int totalRectifierCount = (widget.smpsData?.smpsCabinet?.length ?? 0);

    // If no items from API, allow adding at least 5 items
    if (totalRectifierCount == 0) {
      totalRectifierCount = 5;
    }

    // If there are completed items, use completed count; otherwise use total count
    int maxAllowedRectifierCount = completedRectifierCount > 0
        ? completedRectifierCount
        : totalRectifierCount;

    // Temporary fix: Clear the list if it has more items than expected
    if (savedRectifierItems.length > maxAllowedRectifierCount) {
      print(
          'SMPS Debug: Clearing savedRectifierItems as it has more items than expected');
      savedRectifierItems.clear();
    }

    print('SMPS Debug: completedRectifierCount = $completedRectifierCount');
    print('SMPS Debug: totalRectifierCount = $totalRectifierCount');
    print('SMPS Debug: maxAllowedRectifierCount = $maxAllowedRectifierCount');
    print('SMPS Debug: savedRectifierItems.length = ${savedRectifierItems
        .length}');
    print('SMPS Debug: savedRectifierItems content: $savedRectifierItems');

    if (savedRectifierItems.length > maxAllowedRectifierCount) {
      showCustomToast(
        context,
        'Maximum number of Rectifier items ($maxAllowedRectifierCount) already added.',
      );
      return;
    }

    if (_isFormValid()) {
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

      if (isEditingItem) {
        // We're editing an existing item - add it back to the list
        savedRectifierItems.add(currentFormData);

        // Clear all form fields after editing
        rectifierSerialNumber = null;
        rectifierPhoto = null;
        rectifierPhotoId = null;
        rectifierStatus = null;
        rectifierSerialController.clear();
        rectifierCardKey++;

        isEditingItem = false;
        hasUnsavedChanges = false;
        showValidationErrors = false;
      } else {
        // We're adding a new item - add to list and clear form
        savedRectifierItems.add(currentFormData);
        currentScannedItems++;

        rectifierSerialNumber = null;
        rectifierPhoto = null;
        rectifierPhotoId = null;
        rectifierStatus = null;
        rectifierSerialController.clear();
        rectifierCardKey++;

        hasUnsavedChanges = false;
        showValidationErrors = false;
      }

      // Show success message
      int remainingRectifiers =
          maxAllowedRectifierCount - savedRectifierItems.length;
      showCustomToast(
        context,
        'Rectifier item saved successfully! ${remainingRectifiers > 0
            ? '(${remainingRectifiers} remaining)'
            : '(All items added)'}',
      );
    } else {
      print('Form validation failed - cannot save rectifier item');
    }
  }

  // Save current form data for MPPT
  void _saveMPPTForm() {
    // Check against items that already have both photo_id and asset_status
    int completedMPPTCount = (widget.smpsData?.subCategories?['SMPS ACDB']
        ?.where((item) =>
    item.photoId != null && item.assetStatus != null).length ?? 0) +
        (widget.smpsData?.subCategories?['SMPS LSPU']?.where((item) =>
        item.photoId != null && item.assetStatus != null).length ?? 0);
    int totalMPPTCount = (widget.smpsData?.subCategories?['SMPS ACDB']
        ?.length ?? 0) +
        (widget.smpsData?.subCategories?['SMPS LSPU']?.length ?? 0);

    // If there are completed items, use completed count; otherwise use total count
    int maxAllowedMPPTCount = completedMPPTCount > 0
        ? completedMPPTCount
        : totalMPPTCount;

    print('SMPS Debug: completedMPPTCount = $completedMPPTCount');
    print('SMPS Debug: totalMPPTCount = $totalMPPTCount');
    print('SMPS Debug: maxAllowedMPPTCount = $maxAllowedMPPTCount');
    print('SMPS Debug: savedMPPTItems.length = ${savedMPPTItems.length}');

    if (savedMPPTItems.length > maxAllowedMPPTCount) {
      showCustomToast(
        context,
        'Maximum number of MPPT items ($maxAllowedMPPTCount) already added.',
      );
      return;
    }

    if (_isFormValid()) {
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

      if (isEditingItem) {
        // We're editing an existing item - add it back to the list
        savedMPPTItems.add(currentFormData);

        // Clear all form fields after editing
        mpptSerialNumber = null;
        mpptPhoto = null;
        mpptPhotoId = null;
        mpptStatus = null;
        mpptSerialController.clear();
        mpptCardKey++;

        isEditingItem = false;
        hasUnsavedChanges = false;
        showValidationErrors = false;
      } else {
        // We're adding a new item - add to list and clear form
        savedMPPTItems.add(currentFormData);
        currentScannedItems++;

        print(
            'After saving - savedMPPTItems count: ${savedMPPTItems.length}');
        print('currentScannedItems: $currentScannedItems');

        // Clear AssetTypeCard form for next entry
        mpptSerialNumber = null;
        mpptPhoto = null;
        mpptPhotoId = null;
        mpptStatus = null;
        mpptSerialController.clear();
        mpptCardKey++;

        hasUnsavedChanges = false;
        showValidationErrors = false;
      }

      // Show success message
      int remainingMPPTs = maxAllowedMPPTCount - savedMPPTItems.length;
      showCustomToast(
        context,
        'MPPT item saved successfully! ${remainingMPPTs > 0
            ? '(${remainingMPPTs} remaining)'
            : '(All items added)'}',
      );
    } else {
      print('Form validation failed - cannot save MPPT item');
    }
  }

  // Method to show image viewer dialog
  // void _showImageDialog(String imageData) {
  //   showDialog(
  //     context: context,
  //     builder: (context) => Dialog(
  //       child: Container(
  //         width: MediaQuery.of(context).size.width * 0.8,
  //         height: MediaQuery.of(context).size.height * 0.6,
  //         child: Column(
  //           children: [
  //             AppBar(
  //               title: Text('Image View'),
  //               actions: [
  //                 IconButton(
  //                   icon: Icon(Icons.close),
  //                   onPressed: () => Navigator.of(context).pop(),
  //                 ),
  //               ],
  //             ),
  //             Expanded(
  //               child: Base64ImageWidget(
  //                 base64Data: imageData,
  //                 boxFit: BoxFit.contain,
  //               ),
  //             ),
  //           ],
  //         ),
  //       ),
  //     ),
  //   );
  // }

  // Save current form data for ACDB
  void _saveACDBForm() {
    if (_isFormValid()) {
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
      if (isEditingItem) {
        // We're editing an existing item - add it back to the list
        savedACDBItems.add(currentFormData);

        // Clear all form fields after editing
        acdbSerialNumber = null;
        acdbPhoto = null;
        acdbPhotoId = null;
        acdbStatus = null;
        acdbSerialController.clear();
        acdbCardKey++;

        isEditingItem = false;
        hasUnsavedChanges = false;
        showValidationErrors = false;
      } else {
        // We're adding a new item - add to list and clear form
        savedACDBItems.add(currentFormData);
        currentScannedItems++;

        acdbSerialNumber = null;
        acdbPhoto = null;
        acdbPhotoId = null;
        acdbStatus = null;
        acdbSerialController.clear();
        acdbCardKey++;

        hasUnsavedChanges = false;
        showValidationErrors = false;
      }

      // ACDB item saved successfully
    } else {
      showCustomToast(
        context,
        'Please fill all required fields before saving',
      );
    }
  }

  // Save current form data for LSPU
  void _saveLSPUForm() {
    if (_isFormValid()) {
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

      if (isEditingItem) {
        // We're editing an existing item - add it back to the list
        savedLSPUItems.add(currentFormData);

        // Clear all form fields after editing
        lspuSerialNumber = null;
        lspuPhoto = null;
        lspuPhotoId = null;
        lspuStatus = null;
        lspuSerialController.clear();
        lspuCardKey++;

        isEditingItem = false;
        hasUnsavedChanges = false;
        showValidationErrors = false;
      } else {
        // We're adding a new item - add to list and clear form
        savedLSPUItems.add(currentFormData);
        currentScannedItems++;

        lspuSerialNumber = null;
        lspuPhoto = null;
        lspuPhotoId = null;
        lspuStatus = null;
        lspuSerialController.clear();
        lspuCardKey++;

        hasUnsavedChanges = false;
        showValidationErrors = false;
      }

      // LSPU item saved successfully
    } else {
      print('Form validation failed - cannot save LSPU item');
      showCustomToast(
        context,
        ' Please fill all required fields before saving',
      );
    }
  }

  // Check if all items are scanned
  // Helper method to filter items that have both photo and status
  List<Map<String, dynamic>> _getItemsWithPhotoAndStatus(
      List<Map<String, dynamic>> items) {
    return items.where((item) {
      final hasPhoto = item['photo'] != null && item['photo']
          .toString()
          .isNotEmpty;
      final hasPhotoId = item['photoId'] != null;
      final hasStatus = (item['status'] != null && item['status']
          .toString()
          .isNotEmpty) ||
          (item['assetStatus'] != null && item['assetStatus']
              .toString()
              .isNotEmpty);
      return hasPhotoId && hasStatus;
    }).toList();
  }

  bool _isAllItemsScanned() {
    // Check against items that already have both photo_id and asset_status
    int completedRectifierCount = (widget.smpsData?.assets?.where((item) =>
    item.photoId != null && item.assetStatus != null).length ?? 0) +
        (widget.smpsData?.subCategories?['SMPS Rectifiers']?.where((item) =>
        item.photoId != null && item.assetStatus != null).length ?? 0) +
        (widget.smpsData?.subCategories?['SMPS MPPT']?.where((item) =>
        item.photoId != null && item.assetStatus != null).length ?? 0);
    int completedMPPTCount = (widget.smpsData?.subCategories?['SMPS ACDB']
        ?.where((item) =>
    item.photoId != null && item.assetStatus != null).length ?? 0) +
        (widget.smpsData?.subCategories?['SMPS LSPU']?.where((item) =>
        item.photoId != null && item.assetStatus != null).length ?? 0);

    int totalRectifierCount = (widget.smpsData?.assets?.length ?? 0) +
        (widget.smpsData?.subCategories?['SMPS Rectifiers']?.length ?? 0) +
        (widget.smpsData?.subCategories?['SMPS MPPT']?.length ?? 0);
    int totalMPPTCount = (widget.smpsData?.subCategories?['SMPS ACDB']
        ?.length ?? 0) +
        (widget.smpsData?.subCategories?['SMPS LSPU']?.length ?? 0);

    int maxAllowedRectifierCount = completedRectifierCount > 0
        ? completedRectifierCount
        : totalRectifierCount;
    int maxAllowedMPPTCount = completedMPPTCount > 0
        ? completedMPPTCount
        : totalMPPTCount;

    return (savedRectifierItems.length >= maxAllowedRectifierCount) &&
        (savedMPPTItems.length >= maxAllowedMPPTCount);
  }

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
        // QR Code validated successfully
      } else {
        showCustomToast(
          context,
          'Invalid QR Code! Serial number not found in system.',
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
            (item) =>
        item.mfgSerialNo?.toLowerCase() == serialNumber.toLowerCase(),
      );

      if (isValid) {
        // Manual entry validated successfully
      } else {
        showCustomToast(
          context,
          'Invalid manual entry! Serial number not found in system.',
        );
      }

      return isValid;
    }
  }

  /// Submit all data directly without extra popup
  void _submitAllData() async {
    if (savedRectifierItems.isEmpty &&
        savedMPPTItems.isEmpty &&
        savedACDBItems.isEmpty &&
        savedLSPUItems.isEmpty) {
      showCustomToast(
        context,
        'Please add at least one item before final submission.',
      );
      return;
    }

    // Always use final submission to avoid duplicate API calls
    _performFinalSubmission();
  }

  /// Submit with Complete status and navigate to home
  void _submitWithCompleteStatus() async {
    if (savedRectifierItems.isEmpty &&
        savedMPPTItems.isEmpty &&
        savedACDBItems.isEmpty &&
        savedLSPUItems.isEmpty) {
      showCustomToast(
        context,
        'Please add at least one item before final submission.',
      );
      return;
    }

    // Always use final submission to avoid duplicate API calls
    _performFinalSubmissionWithCompleteStatus();
  }

  /// Perform final submission of all data
  Future<void> _performFinalSubmission() async {
    if (savedRectifierItems.isEmpty &&
        savedMPPTItems.isEmpty &&
        savedACDBItems.isEmpty &&
        savedLSPUItems.isEmpty) {
      showCustomToast(
        context,
        'Please add at least one item before final submission.',
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
        'Failed to post all flow data. Please try again.',
      );
    }
  }

  /// Perform final submission with Complete status and navigate to home
  Future<void> _performFinalSubmissionWithCompleteStatus() async {
    if (savedRectifierItems.isEmpty &&
        savedMPPTItems.isEmpty &&
        savedACDBItems.isEmpty &&
        savedLSPUItems.isEmpty) {
      showCustomToast(
        context,
        'Please add at least one item before final submission.',
      );
      return;
    }

    // Post all data from the entire flow
    final success = await _postAllFlowData();
    if (success) {
      print(
        'SMPS Screen: All flow data posted successfully, updating status to Complete...',
      );

      // Update audit schedule status to "Complete"
      if (mounted) {
        context.read<AuditScheduleStatusCubit>().updateStatus(
          siteAuditSchId: widget.assetAuditData?.pageHeader.first.siteAuditSchId
              .toString() ?? "",
          status: "COMPLETED",
        );
      }

      // Success dialog will be shown in the BlocListener after API success
      print('SMPS Screen: Status updated to Complete, waiting for API response...');
    } else {
      showCustomToast(
        context,
        'Failed to post all flow data. Please try again.',
      );
    }
  }

  /// Post all data from the entire flow to API
  Future<bool> _postAllFlowData() async {
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
        allFlowItems.addAll(widget.extinguisherItems!);
      }

      if (widget.fencingItems != null && widget.fencingItems!.isNotEmpty) {
        allFlowItems.addAll(widget.fencingItems!);
      }

      if (widget.dgItems != null && widget.dgItems!.isNotEmpty) {
        allFlowItems.addAll(widget.dgItems!);
      }

      if (widget.solarPlatesItems != null &&
          widget.solarPlatesItems!.isNotEmpty) {
        allFlowItems.addAll(widget.solarPlatesItems!);
      }

      // Add current screen data
      allFlowItems.addAll(savedRectifierItems);
      allFlowItems.addAll(savedMPPTItems);
      allFlowItems.addAll(savedACDBItems);
      allFlowItems.addAll(savedLSPUItems);
      if (allFlowItems.isEmpty) {
        return false;
      }

      // Log all flow items before enhancement
      for (int i = 0; i < allFlowItems.length; i++) {
        var item = allFlowItems[i];
      }

      // Enhance all flow items with additional data
      final enhancedItems = AssetAuditPostHelper.enhanceSavedItems(
        savedItems: allFlowItems,
        screenName: 'Complete Flow',
      );

      for (int i = 0; i < enhancedItems.length; i++) {
        var item = enhancedItems[i];
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
        context.read<AssetAuditCubit>().postAssetAuditData(
          requests: postRequests,
        );
      } else {
        return false;
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  int? _getRemarksAssetAuditSiteRespId() {
    if (widget.smpsData == null) {
      return null;
    }

    // Check if there are remarks in the backend data
    final remarks = widget.smpsData!.remarks;
    if (remarks.isNotEmpty) {
      for (var remark in remarks) {
        if (remark.assetAuditSiteRespId != null &&
            remark.assetAuditSiteRespId > 0 &&
            remark.itemType == 'SMPS') {
          return remark.assetAuditSiteRespId;
        }
      }

      for (var remark in remarks) {
        if (remark.assetAuditSiteRespId != null &&
            remark.assetAuditSiteRespId > 0) {
          return remark.assetAuditSiteRespId;
        }
      }
    }
    return null;
  }

  /// Post current screen data to API before submitting
  Future<bool> _postCurrentScreenData() async {
    if (widget.assetAuditData == null) {
      return false;
    }

    try {
      // Combine all saved items from different categories
      List<Map<String, dynamic>> allSavedItems = [];
      allSavedItems.addAll(savedRectifierItems);
      allSavedItems.addAll(savedMPPTItems);
      allSavedItems.addAll(savedACDBItems);
      allSavedItems.addAll(savedLSPUItems);

      for (int i = 0; i < allSavedItems.length; i++) {
        var item = allSavedItems[i];
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
        } else {
          print('SMPS Screen: Could not find remarks ID from backend data');
        }
      }

      if (allSavedItems.isEmpty) {
        return false;
      }

      // Enhance saved items with additional data
      final enhancedItems = AssetAuditPostHelper.enhanceSavedItems(
        savedItems: allSavedItems,
        screenName: 'SMPS',
      );

      // Log the enhanced items data

      for (int i = 0; i < enhancedItems.length; i++) {
        var item = enhancedItems[i];
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
        return false;
      }


      for (int i = 0; i < requests.length; i++) {
        var request = requests[i];
      }

      // Set flag BEFORE making the API call to ensure it's set when success state is received
      setState(() {
        _hasPostedSMPSData = true;
      });
      context.read<AssetAuditCubit>().postAssetAuditData(requests: requests);

      return true;
    } catch (e) {
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
      // Set editing flag
      isEditingItem = true;

      // Load the item data back into the form
      rectifierSerialNumber = item["serialNumber"];
      rectifierPhoto = item["photo"];
      rectifierPhotoId = item["photoId"];
      rectifierStatus = item["assetStatus"] ?? item["status"];

      // Set the serial controller text
      rectifierSerialController.text = item["serialNumber"] ?? "";

      // Handle photo data - check if it's base64 data or photo ID
      String? photoData = item["photo"];
      if (photoData != null && photoData.isNotEmpty) {
        if (photoData.startsWith('data:image/')) {
          // It's already base64 image data
          rectifierPhoto = photoData;
        } else if (_isNumeric(photoData)) {
          // It's a photo ID, load the image
          _loadImageForEdit(photoData, 'rectifier');
        } else {
          // It's a file path or other format
          rectifierPhoto = photoData;
        }
      }

      // Also try to load image if photoId exists (fallback)
      if (rectifierPhotoId != null &&
          rectifierPhotoId
              .toString()
              .isNotEmpty && rectifierPhoto == null) {
        _loadImageForEdit(rectifierPhotoId.toString(), 'rectifier');
      }

      // Remove the item from saved rectifier items
      savedRectifierItems.remove(item);
      currentScannedItems--;

      // Force rebuild of the CustomInfoCard widget with new data
      rectifierCardKey++;

      hasUnsavedChanges = true;
    });
  }

  // Edit a specific MPPT item from the saved list
  void _editMPPTItem(Map<String, dynamic> item) {
    setState(() {
      // Set editing flag
      isEditingItem = true;

      // Load the item data back into the form
      mpptSerialNumber = item["serialNumber"];
      mpptPhoto = item["photo"];
      mpptPhotoId = item["photoId"];
      mpptStatus = item["assetStatus"] ?? item["status"];

      // Set the serial controller text
      mpptSerialController.text = item["serialNumber"] ?? "";

      // Handle photo data - check if it's base64 data or photo ID
      String? photoData = item["photo"];
      if (photoData != null && photoData.isNotEmpty) {
        if (photoData.startsWith('data:image/')) {
          // It's already base64 image data
          mpptPhoto = photoData;
        } else if (_isNumeric(photoData)) {
          // It's a photo ID, load the image
          _loadImageForEdit(photoData, 'mppt');
        } else {
          // It's a file path or other format
          mpptPhoto = photoData;
        }
      }

      // Also try to load image if photoId exists (fallback)
      if (mpptPhotoId != null &&
          mpptPhotoId
              .toString()
              .isNotEmpty && mpptPhoto == null) {
        _loadImageForEdit(mpptPhotoId.toString(), 'mppt');
      }

      // Remove the item from saved MPPT items
      savedMPPTItems.remove(item);
      currentScannedItems--;

      // Force rebuild of the CustomInfoCard widget with new data
      mpptCardKey++;

      hasUnsavedChanges = true;
    });
  }

  // Edit a specific ACDB item from the saved list
  void _editACDBItem(Map<String, dynamic> item) {
    setState(() {
      // Set editing flag
      isEditingItem = true;

      // Load the item data back into the form
      acdbSerialNumber = item["serialNumber"];
      acdbPhoto = item["photo"];
      acdbPhotoId = item["photoId"];
      acdbStatus = item["assetStatus"]; // Use assetStatus from saved item

      // Set the serial controller text
      acdbSerialController.text = item["serialNumber"] ?? "";

      // Handle photo data - check if it's base64 data or photo ID
      String? photoData = item["photo"];
      if (photoData != null && photoData.isNotEmpty) {
        if (photoData.startsWith('data:image/')) {
          // It's already base64 image data
          acdbPhoto = photoData;
        } else if (_isNumeric(photoData)) {
          // It's a photo ID, load the image
          _loadImageForEdit(photoData, 'acdb');
        } else {
          // It's a file path or other format
          acdbPhoto = photoData;
        }
      }

      // Also try to load image if photoId exists (fallback)
      if (acdbPhotoId != null &&
          acdbPhotoId
              .toString()
              .isNotEmpty && acdbPhoto == null) {
        _loadImageForEdit(acdbPhotoId.toString(), 'acdb');
      }

      // Remove the item from saved ACDB items
      savedACDBItems.remove(item);
      currentScannedItems--;

      // Force rebuild of the CustomInfoCard widget with new data
      acdbCardKey++;

      hasUnsavedChanges = true;
    });
  }

  // Edit a specific LSPU item from the saved list
  void _editLSPUItem(Map<String, dynamic> item) {
    setState(() {
      // Set editing flag
      isEditingItem = true;

      // Load the item data back into the form
      lspuSerialNumber = item["serialNumber"];
      lspuPhoto = item["photo"];
      lspuPhotoId = item["photoId"];
      lspuStatus = item["assetStatus"]; // Use assetStatus from saved item

      // Set the serial controller text
      lspuSerialController.text = item["serialNumber"] ?? "";

      // Handle photo data - check if it's base64 data or photo ID
      String? photoData = item["photo"];
      if (photoData != null && photoData.isNotEmpty) {
        if (photoData.startsWith('data:image/')) {
          // It's already base64 image data
          lspuPhoto = photoData;
        } else if (_isNumeric(photoData)) {
          // It's a photo ID, load the image
          _loadImageForEdit(photoData, 'lspu');
        } else {
          // It's a file path or other format
          lspuPhoto = photoData;
        }
      }

      // Also try to load image if photoId exists (fallback)
      if (lspuPhotoId != null &&
          lspuPhotoId
              .toString()
              .isNotEmpty && lspuPhoto == null) {
        _loadImageForEdit(lspuPhotoId.toString(), 'lspu');
      }

      // Remove the item from saved LSPU items
      savedLSPUItems.remove(item);
      currentScannedItems--;

      // Force rebuild of the CustomInfoCard widget with new data
      lspuCardKey++;

      hasUnsavedChanges = true;
    });
  }


  @override
  Widget build(BuildContext context) {
    return BlocListener<AssetAuditGetImageCubit, AssetAuditGetImageState>(
      listener: (context, state) {
        if (state is AssetAuditGetImageSuccess) {
          print(
              'SMPS Screen: Image loaded successfully for ${_editingItemType}');
          setState(() {
            // Format image data with proper data URL prefix
            String formattedImageData = state.imageData.startsWith(
                'data:image/')
                ? state.imageData
                : 'data:image/jpeg;base64,${state.imageData}';

            if (_editingItemType == 'rectifier') {
              rectifierPhoto = formattedImageData;
              print('SMPS Debug: Updated rectifierPhoto with image data');
            } else if (_editingItemType == 'mppt') {
              mpptPhoto = formattedImageData;
              print('SMPS Debug: Updated mpptPhoto with image data');
            } else if (_editingItemType == 'acdb') {
              acdbPhoto = formattedImageData;
              print('SMPS Debug: Updated acdbPhoto with image data');
            } else if (_editingItemType == 'lspu') {
              lspuPhoto = formattedImageData;
              print('SMPS Debug: Updated lspuPhoto with image data');
            }
            _isRequestingImage = false;
            _currentRequestedImageId = null;
            _editingItemType = null;
          });
        } else if (state is AssetAuditGetImageFailure) {
          print('SMPS Screen: Failed to load image: ${state.errorMessage}');
          setState(() {
            _isRequestingImage = false;
            _currentRequestedImageId = null;
            _editingItemType = null;
          });
        }
      },
      child: BlocListener<AssetAuditCubit, AssetAuditState>(
        listener: (context, state) {
          if (state is AssetAuditPostSuccess) {
            for (int i = 0; i < state.responses.length; i++) {

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

                break;
              }

              // Fallback check: Check if this is a response to SMPS screen data by looking at the flag
              if (_hasPostedSMPSData) {
                isSMPSData = true;

                break;
              }
            }

            // Only process this success state if it contains SMPS screen data
            if (isSMPSData) {
              // Reset the flag immediately to prevent multiple processing
              if (mounted) {
                setState(() {
                  _hasPostedSMPSData = false;
                });
              }
              
              try {
                context.read<AssetAuditCubit>().getAssetAuditData(
                  siteType: widget.assetAuditData?.pageHeader.first
                      .siteDomainName ?? "",
                  auditSchId: widget.assetAuditData?.pageHeader.first
                      .siteAuditSchId.toString() ?? "",
                  siteAuditSchId: widget.assetAuditData?.pageHeader.first
                      .siteAuditSchId.toString() ?? "",
                );

                // Wait for data to refresh, then show success dialog
                Future.delayed(const Duration(seconds: 2), () {
                  if (mounted) {
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) =>
                          SuccessDialog(
                            ticketId: widget.ticketId ?? _formattedTicketId,
                            message:
                            "Asset Audit completed successfully!\n\nTicket ID: ${widget
                                .ticketId ?? _formattedTicketId}",
                            onDone: () {
                              Navigator.of(context)
                                  .pop(); // Close success dialog


                              Navigator.of(context).pushAndRemoveUntil(
                                MaterialPageRoute(
                                  builder: (context) => const HomeScreen(),
                                ),
                                    (
                                    route) => false, // Remove all previous routes
                              );
                            }, // Required parameter
                          ),
                    );

                    // Flag already reset at the beginning
                  }
                });
              } catch (e) {
                Future.delayed(const Duration(seconds: 2), () {
                  if (mounted) {
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) =>
                          SuccessDialog(
                            ticketId: widget.ticketId ?? _formattedTicketId,
                            message:
                            "Asset Audit completed successfully!\n\nTicket ID: ${widget
                                .ticketId ?? _formattedTicketId}",
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
                    // Flag already reset at the beginning
                  }
                });
              }
            } else {
              print(
                  'SMPS Screen: _hasPostedSMPSData flag: $_hasPostedSMPSData');
            }
          } else if (state is AssetAuditPostError) {
            // Only show error message if this error belongs to SMPS screen data
            if (_hasPostedSMPSData) {
              print('SMPS Screen: AssetAuditPostError received for SMPS data');
              // Show error message but don't block navigation completely
              showCustomToast(
                context,
                '❌ Failed to save SMPS data to server. You can continue with local data.',
              );

              _hasPostedSMPSData = false;
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
                builder: (context) =>
                    UnsavedChangesDialog(
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
                    builder: (context) =>
                        UnsavedChangesDialog(
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
                  _closeWithInProgressStatus();
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
                              MediaQuery
                                  .of(context)
                                  .viewInsets
                                  .bottom + 120,
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
                                    initialValue: totalRectifierItems
                                        .toString(),
                                    isRequired: false,
                                    isEditable: false,
                                    onChanged: (value) {
                                      totalRectifierItems =
                                          int.tryParse(value) ?? 6;
                                      hasUnsavedChanges = true;
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
                                    onSave: _saveRectifierForm,
                                    isStatusEditable: true,
                                    backendStatus: false,
                                    showSaveButton: true,
                                    onPhotoTap: (photoPath) async {
                                      rectifierPhoto = photoPath;
                                      hasUnsavedChanges = true;

                                      // Upload photo immediately and get photoId
                                      if (photoPath != null &&
                                          photoPath.isNotEmpty) {
                                        try {
                                          final photoFile = File(photoPath);
                                          if (await photoFile.exists()) {
                                            final photoId =
                                            await AssetAuditPhotoUploadHelper
                                                .uploadPhotoAndGetId(
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
                                      rectifierStatus = val ? "OK" : "Not OK";
                                      hasUnsavedChanges = true;
                                    },
                                    onSerialChanged: (serialNumber) {
                                      rectifierSerialNumber = serialNumber;
                                      hasUnsavedChanges = true;

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
                                    initialPhotoPath: null,
                                    // Always start with no photo to allow camera access
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
                                      totalMPPTItems =
                                          int.tryParse(value) ?? 6;
                                      hasUnsavedChanges = true;
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
                                      mpptPhoto = photoPath;
                                      hasUnsavedChanges = true;

                                      // Upload photo immediately and get photoId
                                      if (photoPath != null &&
                                          photoPath.isNotEmpty) {
                                        try {
                                          final photoFile = File(photoPath);
                                          if (await photoFile.exists()) {
                                            final photoId =
                                            await AssetAuditPhotoUploadHelper
                                                .uploadPhotoAndGetId(
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
                                      mpptStatus = val ? "OK" : "Not OK";
                                      hasUnsavedChanges = true;
                                    },
                                    onSerialChanged: (serialNumber) {
                                      mpptSerialNumber = serialNumber;
                                      hasUnsavedChanges = true;

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
                                      acdbPhoto = photoPath;
                                      hasUnsavedChanges = true;

                                      // Upload photo immediately and get photoId
                                      if (photoPath != null &&
                                          photoPath.isNotEmpty) {
                                        try {
                                          final photoFile = File(photoPath);
                                          if (await photoFile.exists()) {
                                            final photoId =
                                            await AssetAuditPhotoUploadHelper
                                                .uploadPhotoAndGetId(
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
                                      acdbStatus = val ? "OK" : "Not OK";
                                      hasUnsavedChanges = true;
                                    },
                                    onSerialChanged: (serialNumber) {
                                      acdbSerialNumber = serialNumber;
                                      hasUnsavedChanges = true;

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
                                        : (acdbStatus == "Not OK"
                                        ? false
                                        : null),
                                    initialPhotoPath: null,
                                    // Always start with no photo to allow camera access
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
                                      lspuPhoto = photoPath;
                                      hasUnsavedChanges = true;

                                      // Upload photo immediately and get photoId
                                      if (photoPath != null &&
                                          photoPath.isNotEmpty) {
                                        try {
                                          final photoFile = File(photoPath);
                                          if (await photoFile.exists()) {
                                            final photoId =
                                            await AssetAuditPhotoUploadHelper
                                                .uploadPhotoAndGetId(
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
                                      lspuStatus = val ? "OK" : "Not OK";
                                      hasUnsavedChanges = true;
                                    },
                                    onSerialChanged: (serialNumber) {
                                      lspuSerialNumber = serialNumber;
                                      hasUnsavedChanges = true;

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
                                        : (lspuStatus == "Not OK"
                                        ? false
                                        : null),
                                    initialPhotoPath: null,
                                    // Always start with no photo to allow camera access
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
                                    // Submit all data with Complete status and navigate to home
                                    _submitWithCompleteStatus();
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

          if (savedRectifierItems.isNotEmpty)
            ..._getItemsWithPhotoAndStatus(savedRectifierItems)
                .map(
                  (item) =>
                  Container(
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
                    'Saved Items: ${savedMPPTItems
                        .length} | Current Scanned: $currentScannedItems | Total Expected: ${(widget
                        .smpsData?.subCategories?['SMPS ACDB']?.length ?? 0) +
                        (widget.smpsData?.subCategories?['SMPS LSPU']?.length ??
                            0)}',
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
              ? _getItemsWithPhotoAndStatus(savedMPPTItems)
              .map(
                (item) =>
                Container(
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
                          child: _buildPhotoColumn(item),
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
                    'Saved Items: ${savedACDBItems
                        .length} | Current Scanned: $currentScannedItems | Total Expected: ${widget
                        .smpsData?.subCategories?['SMPS ACDB']?.length ?? 0}',
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
            ..._getItemsWithPhotoAndStatus(savedACDBItems)
                .map(
                  (item) =>
                  Container(
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
                    'Saved Items: ${savedLSPUItems
                        .length} | Current Scanned: $currentScannedItems | Total Expected: ${widget
                        .smpsData?.subCategories?['SMPS LSPU']?.length ?? 0}',
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
              ? _getItemsWithPhotoAndStatus(savedLSPUItems)
              .map(
                (item) =>
                Container(
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
                          child: _buildPhotoColumn(item),
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

  void _editSavedItem(Map<String, dynamic> item, String itemType) {

    setState(() {

      switch (itemType) {
        case 'rectifier':
        // Populate rectifier form with item data
          rectifierSerialController.text = item['serialNumber'] ?? '';
          rectifierSerialNumber = item['serialNumber'] ?? '';
          rectifierStatus = item['assetStatus'] ?? 'OK';
          rectifierPhotoId = item['photoId'];
          
          // Handle photo data - check if it's base64 data or photo ID
          String? photoData = item['photo'];
          if (photoData != null && photoData.isNotEmpty) {
            if (photoData.startsWith('data:image/')) {
              // It's already base64 image data
              rectifierPhoto = photoData;
            } else if (_isNumeric(photoData)) {
              // It's a photo ID, load the image
              _loadImageForEdit(photoData, 'rectifier');
            } else {
              // It's a file path or other format
              rectifierPhoto = photoData;
            }
          } else if (rectifierPhotoId != null && rectifierPhotoId.toString().isNotEmpty) {
            // If no photo data but photoId exists, load the image
            print('SMPS Debug: Loading image for rectifier edit - photoId: ${rectifierPhotoId}');
            _loadImageForEdit(rectifierPhotoId.toString(), 'rectifier');
          }

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
          
          // Handle photo data - check if it's base64 data or photo ID
          String? photoData = item['photo'];
          if (photoData != null && photoData.isNotEmpty) {
            if (photoData.startsWith('data:image/')) {
              // It's already base64 image data
              mpptPhoto = photoData;
            } else if (_isNumeric(photoData)) {
              // It's a photo ID, load the image
              _loadImageForEdit(photoData, 'mppt');
            } else {
              // It's a file path or other format
              mpptPhoto = photoData;
            }
          } else if (mpptPhotoId != null && mpptPhotoId.toString().isNotEmpty) {
            // If no photo data but photoId exists, load the image
            print('SMPS Debug: Loading image for mppt edit - photoId: ${mpptPhotoId}');
            _loadImageForEdit(mpptPhotoId.toString(), 'mppt');
          }

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
          
          // Handle photo data - check if it's base64 data or photo ID
          String? photoData = item['photo'];
          if (photoData != null && photoData.isNotEmpty) {
            if (photoData.startsWith('data:image/')) {
              // It's already base64 image data
              acdbPhoto = photoData;
            } else if (_isNumeric(photoData)) {
              // It's a photo ID, load the image
              _loadImageForEdit(photoData, 'acdb');
            } else {
              // It's a file path or other format
              acdbPhoto = photoData;
            }
          } else if (acdbPhotoId != null && acdbPhotoId.toString().isNotEmpty) {
            // If no photo data but photoId exists, load the image
            print('SMPS Debug: Loading image for acdb edit - photoId: ${acdbPhotoId}');
            _loadImageForEdit(acdbPhotoId.toString(), 'acdb');
          }

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
          
          // Handle photo data - check if it's base64 data or photo ID
          String? photoData = item['photo'];
          if (photoData != null && photoData.isNotEmpty) {
            if (photoData.startsWith('data:image/')) {
              // It's already base64 image data
              lspuPhoto = photoData;
            } else if (_isNumeric(photoData)) {
              // It's a photo ID, load the image
              _loadImageForEdit(photoData, 'lspu');
            } else {
              // It's a file path or other format
              lspuPhoto = photoData;
            }
          } else if (lspuPhotoId != null && lspuPhotoId.toString().isNotEmpty) {
            _loadImageForEdit(lspuPhotoId.toString(), 'lspu');
          }

          // Remove the item from saved list since it's now in the form for editing
          savedLSPUItems.remove(item);
          currentScannedItems--;
          break;
      }

      // Mark that there are unsaved changes
      hasUnsavedChanges = true;

    });
  }

}

