import 'dart:io';

import 'package:app/commonWidgets/custom_buttons/arrow_botton.dart';
import 'package:app/constants/constants_methods.dart';
import 'package:app/screens/asset_audit/asset_audit_telecom/battery_screen.dart';
import 'package:app/screens/asset_audit/asset_audit_telecom/fencing_screen.dart';
import 'package:app/screens/asset_audit/asset_audit_telecom/smps_screen.dart';
import 'package:app/screens/asset_audit/asset_audit_telecom/survelliance_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';
import '../../../constants/constants_strings.dart';
import '../../../models/asset_audit_model.dart';
import '../../../models/asset_audit_post_model.dart';
import '../../../utils/asset_audit_post_helper.dart';
import '../../../utils/asset_audit_photo_upload_helper.dart';
import '../../../bloc/asset_audit_cubit.dart';
import '../../../bloc/asset_audit_state.dart';
import '../../../repositories/image_repository.dart';
import '../../../app_config.dart';

import '../../../commonWidgets/asset_type_card.dart';
import '../../../commonWidgets/custom_dialogs/success_dialog.dart';
import '../../../commonWidgets/custom_dialogs/unsaved_changes_dialog.dart';
import '../../../commonWidgets/custom_form_appbar.dart';
import '../../../commonWidgets/custom_form_field.dart';
import '../../../commonWidgets/custom_image_upload_field.dart';
import '../../../commonWidgets/custom_radio_options.dart';
import '../../../commonWidgets/custom_remark.dart';
import '../../../commonWidgets/base64_image_widget.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_images.dart';


class DgScreen extends StatefulWidget {
  final CategoryData? dgData;
  final AssetAuditModel? assetAuditData;
  final bool showSuccessMessage; // Flag to show success message
  
  // Data from previous screens in the flow
  final List<Map<String, dynamic>>? extinguisherItems;
  final List<Map<String, dynamic>>? solarPlatesItems;
  final List<Map<String, dynamic>>? surveillanceItems;
  final List<Map<String, dynamic>>? fencingItems;

  const DgScreen({
    super.key,
    this.dgData,
    this.assetAuditData,
    this.showSuccessMessage = false, // Default to false
    this.extinguisherItems,
    this.solarPlatesItems,
    this.surveillanceItems,
    this.fencingItems,
  });

  @override
  State<DgScreen> createState() => _DgScreenState();
}

class _DgScreenState extends State<DgScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController serialController = TextEditingController();
  String? selectedCCTVAvailability;
  bool hasUnsavedChanges = false;
  bool showValidationErrors = false;
  int totalCCTVItems = 6;
  int currentScannedItems = 0;
  List<Map<String, dynamic>> savedCCTVItems = [];
  // Separate controllers for each section to avoid conflicts
  final rectifierRemarksController = TextEditingController();
  final mpptRemarksController = TextEditingController();
  final generalRemarksController = TextEditingController();
  String? uploadedPhotoPath;
  int? dgPhotoId; // Store the photoId from API for DG
  int? dgMakePhotoId; // Store the photoId from API for DG Make

  // AssetTypeCard field values for CCTV
  String? cctvSerialNumber;
  String? cctvPhoto;
  int? cctvPhotoId; // Store the photoId from API
  String? cctvStatus;

  // Controllers for CustomInfoCard
  final TextEditingController cctvSerialController = TextEditingController();

  // Keys to force rebuild of CustomInfoCard widgets
  int cctvCardKey = 0;
  
  // Flag to track if DG screen has posted data
  bool _hasPostedDGData = false;

  // ===== IMAGE LOADING INFRASTRUCTURE =====
  late ImageRepository _imageService;
  Map<int, String> _imageCache = {};
  Set<int> _loadingImages = {};
  // ===== END IMAGE LOADING INFRASTRUCTURE =====



  // Method to get OEM name from API data
  String _getDGOEMName() {
    if (widget.dgData != null) {
      // Try to get OEM name from DG assets
      final dgAssets = widget.dgData!.assets;
      if (dgAssets.isNotEmpty) {
        return dgAssets.first.oemName ?? 'Eicher';
      }
    }
    return 'Eicher'; // Default fallback
  }

  /// Check if there is data to show on the screen
  bool _hasDataToShow() {
    if (widget.dgData == null) {
      print('DG Screen: No DG data available');
      return false;
    }
    
    // Check if we have any assets
    final hasAssets = widget.dgData!.assets.isNotEmpty;
    
    // Check if we have any subcategories with data
    final hasSubCategories = widget.dgData!.subCategories != null && 
        widget.dgData!.subCategories!.values.any((items) => items.isNotEmpty);
    
    // Check if we have any remarks
    final hasRemarks = widget.dgData!.remarks.isNotEmpty;
    
    final hasData = hasAssets || hasSubCategories || hasRemarks;
    
    print('DG Screen: Data availability check:');
    print('  - Assets: $hasAssets (${widget.dgData!.assets.length})');
    print('  - Subcategories: $hasSubCategories');
    print('  - Remarks: $hasRemarks (${widget.dgData!.remarks.length})');
    print('  - Has data to show: $hasData');
    
    return hasData;
  }

  void _navigateToSMPSScreen() {
    print('DG Screen: Navigating to SMPS screen');
    pushPage(context, SMPSScreen(
      smpsData: widget.assetAuditData?.responseData.smps,
      assetAuditData: widget.assetAuditData,
      showSuccessMessage: false, // Don't show success message when skipping DG screen
      extinguisherItems: widget.extinguisherItems ?? [],
      solarPlatesItems: widget.solarPlatesItems ?? [],
      fencingItems: widget.fencingItems ?? [],
      dgItems: [],
    ));
  }

  /// Get asset audit site response ID from GET API response for a specific item type
  int _getAssetAuditSiteRespId(String itemType) {
    print('=== DG Screen: Getting AssetAuditSiteRespId for $itemType ===');
    
    if (widget.dgData == null) {
      print('DG Screen: dgData is null, returning default ID');
      return 0; // Default ID
    }
    
    print('DG Screen: dgData is not null, searching for $itemType...');
    
    // First check in assets
    final dgAssets = widget.dgData!.assets ?? [];
    if (dgAssets.isNotEmpty) {
      print('DG Screen: Found ${dgAssets.length} assets in CategoryData.assets');
      for (var asset in dgAssets) {
        print('DG Screen: Asset: ${asset.itemType} - ID: ${asset.assetAuditSiteRespId}');
        if (asset.assetAuditSiteRespId != null && asset.assetAuditSiteRespId! > 0) {
          print('DG Screen: Found valid assetAuditSiteRespId: ${asset.assetAuditSiteRespId}');
          return asset.assetAuditSiteRespId!;
        }
      }
    } else {
      print('DG Screen: No assets found in CategoryData.assets');
    }
    
    // If not found in assets, check subcategories
    if (widget.dgData!.subCategories != null) {
      print('DG Screen: Checking subcategories for $itemType...');
      for (var entry in widget.dgData!.subCategories!.entries) {
        String key = entry.key;
        List<AssetItem> items = entry.value;
        print('DG Screen: Subcategory $key: ${items.length} items');
        for (var item in items) {
          print('DG Screen: Item in $key: ${item.itemType} - ID: ${item.assetAuditSiteRespId}');
          if (item.assetAuditSiteRespId != null && item.assetAuditSiteRespId! > 0) {
            print('DG Screen: Found valid assetAuditSiteRespId in subcategory: ${item.assetAuditSiteRespId}');
            return item.assetAuditSiteRespId!;
          }
        }
      }
    } else {
      print('DG Screen: No subcategories found');
    }
    
    // If still not found, check remarks
    final remarks = widget.dgData!.remarks;
    if (remarks.isNotEmpty) {
      print('DG Screen: Checking remarks for valid ID...');
      for (var remark in remarks) {
        print('DG Screen: Remark: ${remark.itemType} - ID: ${remark.assetAuditSiteRespId}');
        if (remark.assetAuditSiteRespId != null && remark.assetAuditSiteRespId! > 0) {
          print('DG Screen: Found valid assetAuditSiteRespId in remarks: ${remark.assetAuditSiteRespId}');
          return remark.assetAuditSiteRespId!;
        }
      }
    } else {
      print('DG Screen: No remarks found');
    }
    
    print('DG Screen: No valid assetAuditSiteRespId found, returning default ID');
    return 0; // Default ID
  }

  @override
  void initState() {
    super.initState();
    serialController.addListener(_onFormChanged);
    
    // Check if we have data to show, if not, skip this screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_hasDataToShow()) {
        print('DG Screen: No data to show, skipping to SMPS screen');
        _navigateToSMPSScreen();
      } else {
        // Load DG data if available
        _loadDGData();
        
        // Show success message if coming from Fencing Screen
        if (widget.showSuccessMessage) {
          // Fencing data saved successfully
        }
      }
    });
    
    // Initialize image service
    _imageService = ImageRepository(AppConfig.of(context).apiProvider);
  }

  void _loadDGData() {
    if (widget.dgData != null) {
      setState(() {
        print('=== DG Screen: Loading DG Data ===');
        
        // Load DG assets data
        final dgAssets = widget.dgData!.assets;
        if (dgAssets.isNotEmpty) {
          print('DG Screen: Found ${dgAssets.length} DG assets');
          // Process DG assets for count only
          for (int i = 0; i < dgAssets.length; i++) {
            var item = dgAssets[i];
            print('DG Screen: Asset $i:');
            print('  - itemType: ${item.itemType}');
            print('  - nexgenSerialNo: ${item.nexgenSerialNo}');
            print('  - mfgSerialNo: ${item.mfgSerialNo}');
            print('  - assetAuditSiteRespId: ${item.assetAuditSiteRespId}');
            print('  - oemName: ${item.oemName}');
          }
        } else {
          print('DG Screen: No DG assets found');
        }

        // Load remarks and populate the CustomRemarksField
        final remarks = widget.dgData!.remarks;
        if (remarks.isNotEmpty) {
          print('DG Screen: Found ${remarks.length} DG remarks');
          // Process remarks and populate the CustomRemarksField
          for (int i = 0; i < remarks.length; i++) {
            var remark = remarks[i];
            print('DG Screen: Remark $i:');
            print('  - itemType: ${remark.itemType}');
            print('  - recordType: ${remark.recordType}');
            print('  - assetAuditSiteRespId: ${remark.assetAuditSiteRespId}');
            
            // Populate the CustomRemarksField with the first valid remark
            if (remark.itemTypeRemark != null &&
                remark.itemTypeRemark!.isNotEmpty) {
              generalRemarksController.text = remark.itemTypeRemark!;
              print('DG Screen: Loaded remark from API: ${remark.itemTypeRemark}');
              break; // Use the first valid remark
            }
          }
        } else {
          print('DG Screen: No DG remarks found');
        }
        
        // Load saved items from API - only items with complete data
        _loadSavedItemsFromAPI();
        
        // Update total count based on actual data (but don't pre-populate saved items)
        totalCCTVItems = dgAssets.length;
        
        print('=== DG Screen: Data Summary ===');
        print('Total expected items: $totalCCTVItems');
        print('Total remarks: ${remarks.length}');
        print('==========================================');
        
        // Check if we have any data to show
        if (!_hasDataToShow()) {
          print('DG Screen: No data available, will show "No Data" message');
        }
      });
    } else {
      print('DG Screen: No dgData available');
    }
  }

  /// Load saved items from API - only items with complete data (serial, photo, status)
  void _loadSavedItemsFromAPI() {
    if (widget.dgData == null) {
      print('DG Screen: No DG data available');
      return;
    }

    print('DG Screen: Loading saved items from API...');
    
    setState(() {
      // Clear existing saved items to avoid duplicates
      savedCCTVItems.clear();
      currentScannedItems = 0;

      // Load DG assets (from assets array)
      final dgAssets = widget.dgData!.assets;
      print('DG Screen: Found ${dgAssets.length} DG assets');
      
      for (var item in dgAssets) {
        // Only add items that have complete data (serial, photo, status)
        if (item.mfgSerialNo != null && 
            item.photoId != null && 
            item.assetStatus != null) {
          Map<String, dynamic> savedItem = {
            'serialNumber': item.mfgSerialNo ?? item.nexgenSerialNo ?? 'Unknown',
            'photo': null,
            'photoId': item.photoId,
            'status': item.assetStatus ?? 'OK',
            'timestamp': DateTime.now(),
            'isQRCodeScanned': item.qrCodeScanned ?? false,
            'itemType': item.itemType ?? 'DG',
            'remarks': item.itemTypeRemark ?? 'DG Item',
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
          savedCCTVItems.add(savedItem);
          currentScannedItems++;
          print('DG Screen: Added DG item: ${savedItem['serialNumber']}');
        }
      }

      print('DG Screen: Loaded ${savedCCTVItems.length} DG items');
      print('DG Screen: Current scanned items: $currentScannedItems');
    });
    
    // Load images for saved items
    _loadImagesForSavedItems();
  }

  /// Load images for saved items using the image API
  void _loadImagesForSavedItems() async {
    print('=== DG Screen: Loading Images for Saved Items ===');
    
    // Collect all photo IDs from saved items
    Set<int> photoIds = {};
    
    // Add photo IDs from CCTV items
    for (var item in savedCCTVItems) {
      if (item['photoId'] != null) {
        photoIds.add(item['photoId']);
      }
    }
    
    if (photoIds.isEmpty) {
      print('DG Screen: No photo IDs found to load images');
      return;
    }
    
    print('DG Screen: Loading ${photoIds.length} images...');
    
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
      
      print('DG Screen: Successfully loaded ${imageMap.length} images');
    } catch (e) {
      print('DG Screen: Error loading images: $e');
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



  @override
  void dispose() {
    serialController.removeListener(_onFormChanged);
    serialController.dispose();
    cctvSerialController.dispose();
    rectifierRemarksController.dispose();
    mpptRemarksController.dispose();
    generalRemarksController.dispose();
    super.dispose();
  }

  void _onFormChanged() {
    setState(() {
      hasUnsavedChanges =
          selectedCCTVAvailability != null || serialController.text.isNotEmpty;

      if (showValidationErrors &&
          selectedCCTVAvailability != null &&
          serialController.text.isNotEmpty) {
        showValidationErrors = false;
      }
    });
  }

  void _saveAndExit() async {
    Navigator.of(context).pop();
    await Future.delayed(const Duration(milliseconds: 200));

    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.black54,
        builder: (context) => SuccessDialog(
          ticketId: "UVORKJR00044",
          message:
              "Asset Audit for Site (ID: SITE-38974) has been recorded and saved.",
          onDone: () {
            Navigator.of(context).pop();
            Navigator.of(context).pop();
          },
        ),
      );
    }
  }

  bool _isFormValid() {
    String? serialNumber = cctvSerialController.text.isNotEmpty
        ? cctvSerialController.text
        : null;

    if (serialNumber == null || serialNumber.isEmpty) {
      return false;
    }

    String? photo = cctvPhoto;
    if (photo == null || photo.isEmpty) {
      return false;
    }

    return true;
  }

  bool _validateForm() {
    setState(() {
      showValidationErrors = true;
    });

    String? serialNumber = cctvSerialController.text.isNotEmpty
        ? cctvSerialController.text
        : null;

    if (serialNumber == null || serialNumber.isEmpty) {
      return false;
    }

    String? photo = cctvPhoto;
    if (photo == null || photo.isEmpty) {
      return false;
    }

    return true;
  }

  // Save current form data for CCTV
  void _saveCCTVForm() {
    if (savedCCTVItems.length >= totalCCTVItems) {
      showCustomToast(context, 'Maximum number of CCTV items ($totalCCTVItems) already added.');
      return;
    }

    if (_isFormValid()) {
      setState(() {
        // Get the assetAuditSiteRespId before creating the form data
        int assetAuditSiteRespId = _getAssetAuditSiteRespId('DG');
        print('DG Screen: Retrieved assetAuditSiteRespId: $assetAuditSiteRespId');
        
        Map<String, dynamic> currentFormData = {
          'serialNumber': cctvSerialNumber,
          'photo': cctvPhoto,
          'photoId': cctvPhotoId, // Include the photoId from API
          'photoTakenTs': DateTime.now().toString(),
          'itemType': 'DG',
          'remarks': 'DG Item',
          'assetStatus': cctvStatus ?? "OK",
          'assetAuditSiteRespId': assetAuditSiteRespId,
          'timestamp': DateTime.now(),
          'isQRCodeScanned': false, // Track if this was QR scanned or manual entry (false for manual entry)
        };
        
        print('DG Screen: Created form data with assetAuditSiteRespId: ${currentFormData['assetAuditSiteRespId']}');

        savedCCTVItems.add(currentFormData);
        currentScannedItems++;

        // Clear form for next entry
        cctvSerialNumber = null;
        cctvPhoto = null;
        cctvStatus = null;
        cctvSerialController.clear();
        cctvCardKey++;

        hasUnsavedChanges = false;
        showValidationErrors = false;
      });

      int remainingCCTVs = totalCCTVItems - savedCCTVItems.length;
      // CCTV item saved successfully
    }
  }

  // Check if all items are scanned
  bool _isAllItemsScanned() {
    return savedCCTVItems.length >= totalCCTVItems;
  }

  /// Validate serial number against API data
  /// Returns true if valid, false if invalid
  bool _validateSerialNumber(String serialNumber, bool isQRCodeScanned) {
    if (widget.dgData == null) return false;
    
    if (isQRCodeScanned) {
      // For QR code scans, validate against nexgen_serial_no
      final allItems = widget.dgData!.assets ?? [];
      
      final isValid = allItems.any((item) => 
        item.nexgenSerialNo?.toLowerCase() == serialNumber.toLowerCase()
      );
      
      if (isValid) {
        showCustomToast(context, '✅ QR Code validated successfully!');
      } else {
        showCustomToast(context, '❌ Invalid QR Code! Serial number not found in system.');
      }
      
      return isValid;
    } else {
      // For manual entries, validate against mfg_serial_no
      final allItems = widget.dgData!.assets ?? [];
      
      final isValid = allItems.any((item) => 
        item.mfgSerialNo?.toLowerCase() == serialNumber.toLowerCase()
      );
      
      if (isValid) {
        showCustomToast(context, '✅ Manual entry validated successfully!');
      } else {
        showCustomToast(context, '❌ Invalid manual entry! Serial number not found in system.');
      }
      
      return isValid;
    }
  }

  int? _getRemarksAssetAuditSiteRespId() {
    print('=== DG Screen: Getting Remarks AssetAuditSiteRespId ===');
    
    if (widget.dgData == null) {
      print('dgData is null, cannot get remarks ID');
      return null;
    }
    
    // Check if there are remarks in the backend data
    final remarks = widget.dgData!.remarks;
    if (remarks.isNotEmpty) {
      print('Found ${remarks.length} remarks in backend data');
      
      // First try to find a general remarks entry (DG category is usually the main one)
      for (var remark in remarks) {
        if (remark.assetAuditSiteRespId != null && 
            remark.assetAuditSiteRespId > 0 && 
            remark.itemType == 'DG') {
          print('Using DG remarks ID: ${remark.assetAuditSiteRespId}');
          return remark.assetAuditSiteRespId;
        }
      }
      
      // Fallback: find any remarks entry with a valid ID
      for (var remark in remarks) {
        if (remark.assetAuditSiteRespId != null && remark.assetAuditSiteRespId > 0) {
          print('Using fallback remarks ID: ${remark.assetAuditSiteRespId} for itemType: ${remark.itemType}');
          return remark.assetAuditSiteRespId;
        }
      }
    }
    
    print('No valid remarks ID found in backend data');
    return null;
  }

  /// Post current screen data to API before navigating to next screen
  Future<bool> _postCurrentScreenData() async {
    if (widget.assetAuditData == null) {
      print('DG Screen: No asset audit data available for posting');
      return false;
    }

    try {
      // Create a list to hold all items to post
      List<Map<String, dynamic>> allItemsToPost = [];

      // Enhance saved items with additional data
      final enhancedItems = AssetAuditPostHelper.enhanceSavedItems(
        savedItems: savedCCTVItems,
        screenName: 'DG',
      );
      allItemsToPost.addAll(enhancedItems);

      // Add user's general remarks if entered
      if (generalRemarksController.text.isNotEmpty) {
        // Find the appropriate remarks entry from backend data
        int? remarksAssetAuditSiteRespId = _getRemarksAssetAuditSiteRespId();
        
        if (remarksAssetAuditSiteRespId != null) {
          Map<String, dynamic> remarksData = {
            'itemType': 'DG', // Use the main screen category
            'remarks': generalRemarksController.text, // User's actual remarks text
            'recordType': 'Remarks',
            'timestamp': DateTime.now(),
            'assetAuditSiteRespId': remarksAssetAuditSiteRespId, // Use backend remarks ID
            'status': 'OK', // Default status for remarks
            'serialNumber': 'REMARKS', // Default serial for remarks
            'photo': null, // No photo file for remarks
            'photoTakenTs': DateTime.now().toString(), // Current timestamp
            'isQRCodeScanned': false, // Remarks are not QR scanned
            'localQrCodeScannedTs': DateTime.now().toString(), // Local timestamp for QR scan
            'localCreatedDt': DateTime.now().toString(), // Local creation timestamp
            'localModifiedDt': DateTime.now().toString(), // Local modification timestamp
          };
          allItemsToPost.add(remarksData);
          print('DG Screen: Added user remarks to post with ID: $remarksAssetAuditSiteRespId, text: "${generalRemarksController.text}"');
        } else {
          print('DG Screen: Could not find remarks ID from backend data');
        }
      }

      if (allItemsToPost.isEmpty) {
        print('DG Screen: No items to post');
        return false;
      }

      // Convert to POST request format
      final requests = await AssetAuditPostHelper.convertSavedItemsToPostRequest(
        savedItems: allItemsToPost,
        assetAuditData: widget.assetAuditData!,
        itemType: 'DG',
        itemTypeId: AssetAuditPostHelper.getItemTypeId('DG'),
        screenName: 'DG',
        context: context,
      );

      if (requests.isEmpty) {
        print('DG Screen: Failed to create POST requests');
        return false;
      }

      // Use the existing cubit to post data
      print('DG Screen: Posting ${requests.length} items to API...');
      context.read<AssetAuditCubit>().postAssetAuditData(requests: requests);
      
      // Return true to indicate data is being posted
      return true;
    } catch (e) {
      print('DG Screen: Error preparing data: $e');
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

  // Edit a specific CCTV item from the saved list
  void _editItem(Map<String, dynamic> item) {
    setState(() {
      cctvSerialNumber = item["serialNumber"];
      cctvPhoto = item["photo"];
      cctvStatus = item["status"];
      cctvSerialController.text = item["serialNumber"] ?? "";
      savedCCTVItems.remove(item);
      currentScannedItems--;
              cctvCardKey++;
        hasUnsavedChanges = true;
      });

    showCustomToast(context, 'CCTV item loaded for editing. Make changes and save again.');
  }

  // Edit a specific saved item from the saved list
  void _editSavedItem(Map<String, dynamic> item, String itemType) {
    setState(() {
      cctvSerialNumber = item["serialNumber"];
      cctvPhoto = item["photo"];
      cctvStatus = item["status"];
      cctvSerialController.text = item["serialNumber"] ?? "";
      savedCCTVItems.remove(item);
      currentScannedItems--;
      cctvCardKey++;
      hasUnsavedChanges = true;
    });

    showCustomToast(context, 'CCTV item loaded for editing. Make changes and save again.');
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AssetAuditCubit, AssetAuditState>(
      listener: (context, state) {
        print('DG Screen: BlocListener received state: $state');
        print('DG Screen: State type: ${state.runtimeType}');
        
        if (state is AssetAuditPostSuccess) {
          print('DG Screen: AssetAuditPostSuccess received!');
          print('DG Screen: State details: $state');
          print('DG Screen: _hasPostedDGData flag: $_hasPostedDGData');
          
          // Check if this success state contains DG-related items
          bool isDGData = false;
          print('DG Screen: Total responses received: ${state.responses.length}');
          for (var response in state.responses) {
            print('DG Screen: Full response object: $response');
            print('DG Screen: Checking response itemTypeRemark: ${response.itemTypeRemark}');
            print('DG Screen: Checking response itemTypeId: ${response.itemTypeId}');
            print('DG Screen: Checking response nexgenSerialNo: ${response.nexgenSerialNo}');
            print('DG Screen: Checking response assetStatus: ${response.assetStatus}');
            print('DG Screen: Checking response remarks: ${response.remarks}');
            
            // Primary check: itemTypeRemark contains DG-related text
            if (response.itemTypeRemark != null && 
                (response.itemTypeRemark!.contains('DG') || 
                 response.itemTypeRemark!.contains('Diesel Generator') ||
                 response.itemTypeRemark!.contains('Generator'))) {
              isDGData = true;
              print('DG Screen: Found DG-related item by itemTypeRemark: ${response.itemTypeRemark}');
              break;
            }
            
            // Fallback check: Check if this is a response to DG screen data by looking at the flag
            if (_hasPostedDGData) {
              isDGData = true;
              print('DG Screen: Found DG-related item by flag check (fallback)');
              break;
            }
            
            print('DG Screen: itemTypeRemark "${response.itemTypeRemark}" does not match DG patterns');
          }
          
          // Only process this success state if it contains DG screen data
          if (isDGData) {
            print('DG Screen: Confirmed this is DG screen data, proceeding with data refresh...');
            
            // Show success message
            // DG data saved successfully

            // Refresh data from API before navigating
            print('DG Screen: Refreshing data from API...');
            try {
              // Trigger a refresh of the asset audit data
              context.read<AssetAuditCubit>().getAssetAuditData(
                siteType: "telecom",
                auditSchId: widget.assetAuditData?.pageHeader.first.siteAuditSchId.toString() ?? "0",
                siteAuditSchId: widget.assetAuditData?.pageHeader.first.siteAuditSchId.toString() ?? "0",
              );
              
              // Wait for data to refresh, then navigate
              Future.delayed(const Duration(seconds: 2), () {
                if (mounted) {
                  print('DG Screen: Data refreshed, navigating to next screen...');
                  pushPage(context, SMPSScreen(
                    smpsData: widget.assetAuditData?.responseData.smps,
                    assetAuditData: widget.assetAuditData,
                    showSuccessMessage: false, // Don't show success message when skipping DG screen
                    extinguisherItems: widget.extinguisherItems ?? [],
                    solarPlatesItems: widget.solarPlatesItems ?? [],
                    fencingItems: widget.fencingItems ?? [],
                    dgItems: [
                      ...savedCCTVItems,
                    ],
                  ));
                  
                  // Reset the flag after successful navigation
                  setState(() {
                    _hasPostedDGData = false;
                  });
                  print('DG Screen: Reset _hasPostedDGData flag to false after navigation');
                }
              });
            } catch (e) {
              print('DG Screen: Error refreshing data: $e');
              // Fallback: navigate anyway after delay
              Future.delayed(const Duration(seconds: 2), () {
                if (mounted) {
                  pushPage(context, SMPSScreen(
                    smpsData: widget.assetAuditData?.responseData.smps,
                    assetAuditData: widget.assetAuditData,
                    showSuccessMessage: false,
                    extinguisherItems: widget.extinguisherItems ?? [],
                    solarPlatesItems: widget.solarPlatesItems ?? [],
                    fencingItems: widget.fencingItems ?? [],
                    dgItems: [
                      ...savedCCTVItems,
                    ],
                  ));
                  setState(() {
                    _hasPostedDGData = false;
                  });
                }
              });
            }
          } else {
            print('DG Screen: Success state received but not for DG screen data, ignoring...');
            print('DG Screen: _hasPostedDGData flag: $_hasPostedDGData');
          }
        } else if (state is AssetAuditPostError) {
          // Only show error message if this error belongs to DG screen data
          if (_hasPostedDGData) {
            print('DG Screen: AssetAuditPostError received for DG data');
            // Show error message and block navigation
            showCustomToast(context, '❌ Failed to save DG data. Please try again.');
            
            // Reset the flag on error
            setState(() {
              _hasPostedDGData = false;
            });
            print('DG Screen: Reset _hasPostedDGData flag to false after error');
          } else {
            print('DG Screen: AssetAuditPostError received but not for DG data, ignoring...');
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
                                if (_hasDataToShow()) ...[
                                  CustomOptionSelector(
                                label: "DG Availability *",
                                isRequired: true,
                                options: [
                                  OptionItem(
                                    value: "yes",
                                    label: "Yes",
                                    selectedIcon: Icons.check_circle,
                                    unselectedIcon: Icons.circle_outlined,
                                  ),
                                  OptionItem(
                                    value: "no",
                                    label: "No",
                                    selectedIcon: Icons.cancel,
                                    unselectedIcon: Icons.circle_outlined,
                                  ),
                                ],
                                onChanged: (value) {
                                  setState(() {
                                    selectedCCTVAvailability = value;
                                    hasUnsavedChanges = true;
                                  });
                                },
                              ),
                              getHeight(15),
                              ImageUploadField(
                                label: "Add Photo of DG",
                                placeholder: "Add Photo",
                                isRequired: true,
                                onImageSelected: (file) async {
                                  if (file != null) {
                                    debugPrint(
                                      "Selected image path: ${file.path}",
                                    );
                                    setState(() {
                                      uploadedPhotoPath = file.path;
                                      hasUnsavedChanges = true;
                                    });
                                    
                                    // Upload photo immediately and get photoId for DG
                                    try {
                                      final photoFile = File(file.path);
                                      if (await photoFile.exists()) {
                                        final photoId = await AssetAuditPhotoUploadHelper.uploadPhotoAndGetId(
                                          photoFile: photoFile,
                                          schId: widget.assetAuditData?.pageHeader.first.siteAuditSchId.toString() ?? "0",
                                          imgId: null,
                                          context: context,
                                        );
                                        
                                        if (photoId != null) {
                                          setState(() {
                                            dgPhotoId = photoId; // Store the photoId for DG
                                          });
                                          print('DG Screen: DG Photo uploaded successfully, photoId: $photoId');
                                        }
                                      }
                                    } catch (e) {
                                      print('DG Screen: Error uploading DG photo: $e');
                                    }
                                  } else {
                                    setState(() {
                                      uploadedPhotoPath = null;
                                      dgPhotoId = null;
                                    });
                                  }
                                },
                              ),
                              getHeight(15),
                              CustomFormField(
                                label: "DG Make",
                                initialValue: _getDGOEMName(),
                                isRequired: false,
                                isEditable: false,
                              ),
                              getHeight(15),
                              ImageUploadField(
                                label: "Add Photo of DG Make",
                                placeholder: "Add Photo",
                                isRequired: true,
                                onImageSelected: (file) async {
                                  if (file != null) {
                                    debugPrint(
                                      "Selected image path: ${file.path}",
                                    );
                                    setState(() {
                                      uploadedPhotoPath = file.path;
                                      hasUnsavedChanges = true;
                                    });
                                    
                                    // Upload photo immediately and get photoId for DG Make
                                    try {
                                      final photoFile = File(file.path);
                                      if (await photoFile.exists()) {
                                        final photoId = await AssetAuditPhotoUploadHelper.uploadPhotoAndGetId(
                                          photoFile: photoFile,
                                          schId: widget.assetAuditData?.pageHeader.first.siteAuditSchId.toString() ?? "0",
                                          imgId: null,
                                          context: context,
                                        );
                                        
                                        if (photoId != null) {
                                          setState(() {
                                            dgMakePhotoId = photoId; // Store the photoId for DG Make
                                          });
                                          print('DG Screen: DG Make Photo uploaded successfully, photoId: $photoId');
                                        }
                                      }
                                    } catch (e) {
                                      print('DG Screen: Error uploading DG Make photo: $e');
                                    }
                                  } else {
                                    setState(() {
                                      uploadedPhotoPath = null;
                                      dgMakePhotoId = null;
                                    });
                                  }
                                },
                              ),
                              getHeight(15),
                              CustomFormField(
                                label: "Count of DG Set",
                                initialValue: totalCCTVItems.toString(),
                                isRequired: false,
                                isEditable: false,
                                onChanged: (value) {
                                  setState(() {
                                    totalCCTVItems = int.tryParse(value) ?? 6;
                                    hasUnsavedChanges = true;
                                  });
                                },
                              ),
                              getHeight(15),
                              CustomInfoCard(
                                key: ValueKey('cctv_$cctvCardKey'),
                                serialLabel: "DG - Serial Number *",
                                serialHintText: "DG Serial Number",
                                photoLabel: "Add a Photo",
                                statusLabel: "Status",
                                serialController: cctvSerialController,
                                onSave: _saveCCTVForm,
                                isStatusEditable: true,
                                backendStatus: false,
                                remarksLabel: "Capacity",
                                remarksHintText: "Eg: 25KVA",
                                onPhotoTap: (photoPath) async {
                                  setState(() {
                                    cctvPhoto = photoPath;
                                    hasUnsavedChanges = true;
                                  });
                                  
                                  // Upload photo immediately and get photoId
                                  if (photoPath != null && photoPath.isNotEmpty) {
                                    try {
                                      final photoFile = File(photoPath);
                                      if (await photoFile.exists()) {
                                        final photoId = await AssetAuditPhotoUploadHelper.uploadPhotoAndGetId(
                                          photoFile: photoFile,
                                          schId: widget.assetAuditData?.pageHeader.first.siteAuditSchId.toString() ?? "0",
                                          imgId: null,
                                          context: context,
                                        );
                                        
                                        if (photoId != null) {
                                          setState(() {
                                            cctvPhotoId = photoId;
                                          });
                                          print('DG Screen: Photo uploaded successfully, photoId: $photoId');
                                        }
                                      }
                                    } catch (e) {
                                      print('DG Screen: Error uploading photo: $e');
                                    }
                                  }
                                },
                                onStatusChanged: (val) {
                                  setState(() {
                                    cctvStatus = val ? "OK" : "Not OK";
                                    hasUnsavedChanges = true;
                                  });
                                },
                                onSerialChanged: (serialNumber) {
                                  setState(() {
                                    cctvSerialNumber = serialNumber;
                                    hasUnsavedChanges = true;
                                  });
                                  
                                  // Validate serial number if not empty
                                  if (serialNumber.isNotEmpty) {
                                    // For now, assume manual entry (we'll need to add QR code detection later)
                                    final isValid = _validateSerialNumber(serialNumber, false);
                                    // Update the saved item to track validation result
                                    if (isValid) {
                                      // Serial number is valid, keep it
                                    } else {
                                      // Serial number is invalid, clear it
                                      setState(() {
                                        cctvSerialNumber = null;
                                        hasUnsavedChanges = false;
                                      });
                                    }
                                  }
                                },
                                initialStatus: cctvStatus == "OK"
                                    ? true
                                    : (cctvStatus == "Not OK" ? false : null),
                                initialPhotoPath: cctvPhoto,
                                isEditable: true,
                              ),
                              getHeight(8),
                              _buildCCTVSavedItemsList(),
                              getHeight(15),
                                                              CustomRemarksField(
                                  label: "Add Remarks",
                                  hintText: "Remarks",
                                  controller: generalRemarksController,
                                ),
                                ],
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
                              text: "Fencing",
                              isLeftArrow: true,
                              backgroundColor: AppColors.buttonColorBackBg,
                              textColor: AppColors.buttonColorTextBg,
                              onPressed: () {
                                Navigator.pop(context);
                              },
                            ),
                          ),
                          getWidth(14),
                                                      Expanded(
                              child: ArrowButton(
                                text: _hasDataToShow() ? "SMPS" : "Skip DG",
                                isLeftArrow: false,
                                backgroundColor: AppColors.buttonColorBg,
                                textColor: AppColors.buttonColorSite,
                                                                onPressed: () async {
                                  // If no data to show, just navigate to next screen
                                  if (!_hasDataToShow()) {
                                    pushPage(context, SMPSScreen(
                                      smpsData: widget.assetAuditData?.responseData.smps,
                                      assetAuditData: widget.assetAuditData,
                                      showSuccessMessage: false,
                                      extinguisherItems: widget.extinguisherItems ?? [],
                                      solarPlatesItems: widget.solarPlatesItems ?? [],
                                      fencingItems: widget.fencingItems ?? [],
                                      dgItems: [],
                                    ));
                                    return;
                                  }
                                  
                                  // Navigate to next screen with accumulated data
                                  pushPage(context, SMPSScreen(
                                    smpsData: widget.assetAuditData?.responseData.smps,
                                    assetAuditData: widget.assetAuditData,
                                    showSuccessMessage: false,
                                                                          extinguisherItems: widget.extinguisherItems ?? [],
                                      solarPlatesItems: widget.solarPlatesItems ?? [],
                                      fencingItems: widget.fencingItems ?? [],
                                      dgItems: [
                                        ...savedCCTVItems,
                                      ],
                                  ));
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
        BlocBuilder<AssetAuditCubit, AssetAuditState>(
          builder: (context, state) {
            if (state is AssetAuditPosting) {
              return Container(
                color: Colors.black.withOpacity(0.5),
                child: const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              );
            }
            return const SizedBox.shrink();
          },
        ),
        ],
      ),
      ),
    ),
    );
  }

  // Build CCTV saved items list
  Widget _buildCCTVSavedItemsList() {
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
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: const Text(
                    "Capacity",
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
                    'Saved Items: ${savedCCTVItems.length} | Current Scanned: $currentScannedItems | Total Expected: $totalCCTVItems',
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
          if (savedCCTVItems.isNotEmpty)
            ...savedCCTVItems
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
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Text(
                              item['capacity'] ?? 'N/A',
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
                            child: Text(
                              item['status'] ?? 'N/A',
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
                              onPressed: () => _editSavedItem(item, 'cctv'),
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
}
