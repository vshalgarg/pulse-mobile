import 'package:app/commonWidgets/custom_buttons/arrow_botton.dart';
import 'package:app/constants/constants_methods.dart';
import 'package:app/screens/asset_audit/asset_audit_telecom/extinguisher_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';
import '../../../models/asset_audit_model.dart';
import '../../../utils/asset_audit_post_helper.dart';
import '../../../utils/asset_audit_photo_upload_helper.dart';
import '../../../bloc/asset_audit_cubit.dart';
import '../../../bloc/asset_audit_photo_upload_cubit.dart';

import '../../../bloc/asset_audit_state.dart';
import '../../../repositories/image_repository.dart';
import '../../../app_config.dart';
import 'dart:io';

import '../../../commonWidgets/asset_type_card.dart';
import '../../../commonWidgets/custom_dialogs/success_dialog.dart';
import '../../../commonWidgets/custom_dialogs/unsaved_changes_dialog.dart';
import '../../../commonWidgets/custom_form_appbar.dart';
import '../../../commonWidgets/custom_form_field.dart';
import '../../../commonWidgets/custom_image_upload_field.dart';
import '../../../commonWidgets/custom_radio_options.dart';
import '../../../commonWidgets/custom_remark.dart';
import '../../../commonWidgets/qr_screen_form_field.dart';
import '../../../commonWidgets/base64_image_widget.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_images.dart';
import '../../../constants/constants_strings.dart';

class BatteryScreen extends StatefulWidget {
  final CategoryData? batteryData;
  final AssetAuditModel? assetAuditData;

  const BatteryScreen({
    super.key,
    this.batteryData,
    this.assetAuditData,
  });

  @override
  State<BatteryScreen> createState() => _BatteryScreenState();
}

class _BatteryScreenState extends State<BatteryScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController serialController = TextEditingController();
  String? selectedFile;
  String? selectedStatus;
  String? selectedBatteryStatus;
  String? selectedType;
  bool hasUnsavedChanges = false;
  bool showValidationErrors = false;
  int totalRectifierItems = 6;
  int totalMPPTItems = 6;
  int currentScannedItems = 0;
  List<Map<String, dynamic>> savedRectifierItems = [];
  List<Map<String, dynamic>> savedMPPTItems = [];
  Map<String, dynamic> currentFormData = {};
  String? uploadedPhotoPath;
  int? cabinetPhotoId;

  String? rectifierSerialNumber;
  String? rectifierPhoto;
  int? rectifierPhotoId;
  String? rectifierStatus;
  final mpptRemarksController = TextEditingController();
  final rectifierRemarksController = TextEditingController();
  final generalRemarksController = TextEditingController();
  final batteryCapacityController = TextEditingController();

  String? mpptSerialNumber;
  String? mpptPhoto;
  int? mpptPhotoId;
  String? mpptStatus;

  final TextEditingController rectifierSerialController =
      TextEditingController();
  final TextEditingController mpptSerialController = TextEditingController();

  int rectifierCardKey = 0;
  int mpptCardKey = 0;
  
  bool _hasPostedBatteryData = false;

  // ===== IMAGE LOADING INFRASTRUCTURE =====
  late ImageRepository _imageService;
  Map<int, String> _imageCache = {};
  Set<int> _loadingImages = {};
  // ===== END IMAGE LOADING INFRASTRUCTURE =====

  String _getBatteryOEMName() {
    if (widget.batteryData != null) {
      print('Battery Screen: Getting OEM name from battery data');
      print('Battery Screen: batteryCabinet items: ${widget.batteryData!.batteryCabinet?.length ?? 0}');
      print('Battery Screen: assets count: ${widget.batteryData!.assets.length}');
      print('Battery Screen: cbms items: ${widget.batteryData!.cbms?.length ?? 0}');
      
      final batteryCabinetItems = widget.batteryData!.batteryCabinet ?? [];
      if (batteryCabinetItems.isNotEmpty) {
        print('Battery Screen: Using OEM from Battery Cabinet: ${batteryCabinetItems.first.oemName}');
        return batteryCabinetItems.first.oemName ?? 'Delta';
      }
      
      final batteryAssets = widget.batteryData!.assets;
      if (batteryAssets.isNotEmpty) {
        print('Battery Screen: Using OEM from Battery Assets: ${batteryAssets.first.oemName}');
        return batteryAssets.first.oemName ?? 'Delta';
      }
      
      final cbmsItems = widget.batteryData!.cbms ?? [];
      if (cbmsItems.isNotEmpty) {
        print('Battery Screen: Using OEM from CBMS: ${cbmsItems.first.oemName}');
        return cbmsItems.first.oemName ?? 'Delta';
      }
    }
    
    print('Battery Screen: No OEM found, using default: Delta');
    return 'Delta';
  }
  
  /// Load Battery data from API response
  void _loadBatteryData() {
    if (widget.batteryData == null) {
      print('Battery Screen: No battery data available');
      return;
    }
    
    print('Battery Screen: Loading battery data...');
    print('Battery Screen: Assets count: ${widget.batteryData!.assets.length}');
    print('Battery Screen: Remarks count: ${widget.batteryData!.remarks.length}');
    print('Battery Screen: Subcategories: ${widget.batteryData!.subCategories?.keys.toList()}');
    
    setState(() {
      // Clear existing saved items to avoid duplicates
      savedRectifierItems.clear();
      savedMPPTItems.clear();
      currentScannedItems = 0;
      
      // Load Battery Cabinet items (from subcategories)
      final batteryCabinetItems = widget.batteryData!.batteryCabinet ?? [];
      print('Battery Screen: Found ${batteryCabinetItems.length} Battery Cabinet items');
      for (var item in batteryCabinetItems) {
        Map<String, dynamic> savedItem = {
          'serialNumber': item.mfgSerialNo ?? item.nexgenSerialNo ?? 'Unknown',
          'photo': null,
          'photoId': item.photoId,
          'status': item.assetStatus ?? 'OK',
          'timestamp': DateTime.now(),
          'isQRCodeScanned': item.qrCodeScanned ?? false,
          'itemType': item.itemType ?? 'Battery Cabinet',
          'remarks': item.itemTypeRemark ?? 'Battery Cabinet Item',
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
        print('Battery Screen: Added Battery Cabinet item: ${savedItem['serialNumber']}');
      }
      
      // Load Battery assets (general assets)
      final batteryAssets = widget.batteryData!.assets;
      print('Battery Screen: Found ${batteryAssets.length} Battery assets');
      for (var item in batteryAssets) {
        Map<String, dynamic> savedItem = {
          'serialNumber': item.mfgSerialNo ?? item.nexgenSerialNo ?? 'Unknown',
          'photo': null,
          'photoId': item.photoId,
          'status': item.assetStatus ?? 'OK',
          'timestamp': DateTime.now(),
          'isQRCodeScanned': item.qrCodeScanned ?? false,
          'itemType': item.itemType ?? 'Battery',
          'remarks': item.itemTypeRemark ?? 'Battery Item',
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
        print('Battery Screen: Added Battery asset: ${savedItem['serialNumber']}');
      }
      
      // Load CBMS items (from subcategories)
      final cbmsItems = widget.batteryData!.cbms ?? [];
      print('Battery Screen: Found ${cbmsItems.length} CBMS items');
      for (var item in cbmsItems) {
        Map<String, dynamic> savedItem = {
          'serialNumber': item.mfgSerialNo ?? item.nexgenSerialNo ?? 'Unknown',
          'photo': null,
          'photoId': item.photoId,
          'status': item.assetStatus ?? 'OK',
          'timestamp': DateTime.now(),
          'isQRCodeScanned': item.qrCodeScanned ?? false,
          'itemType': item.itemType ?? 'CBMS',
          'remarks': item.itemTypeRemark ?? 'CBMS Item',
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
        print('Battery Screen: Added CBMS item: ${savedItem['serialNumber']}');
      }
      
      // Update total counts
      totalRectifierItems = batteryAssets.length;
      totalMPPTItems = batteryCabinetItems.length + cbmsItems.length;
      
      // Load remarks data from API and populate the CustomRemarksField
      final remarks = widget.batteryData!.remarks;
      if (remarks.isNotEmpty) {
        for (var remark in remarks) {
          if (remark.itemTypeRemark != null &&
              remark.itemTypeRemark!.isNotEmpty) {
            generalRemarksController.text = remark.itemTypeRemark!;
            print('Battery Screen: Loaded remark from API: ${remark.itemTypeRemark}');
            break; // Use the first valid remark
          }
        }
      }
      
      print('Battery Screen: Loaded ${savedRectifierItems.length} cabinet items, ${savedMPPTItems.length} battery/CBMS items');
      print('Battery Screen: Total counts - Rectifier: $totalRectifierItems, MPPT: $totalMPPTItems');
      print('Battery Screen: Current scanned items: $currentScannedItems');
    });
    
    print('Battery Screen: About to call _loadImagesForSavedItems...');
    // Load images for saved items
    _loadImagesForSavedItems();
    print('Battery Screen: _loadImagesForSavedItems called successfully');
    
    // Wait a bit for images to load and then check cache
    Future.delayed(Duration(milliseconds: 500), () {
      if (mounted) {
        print('Battery Screen: After 500ms delay - checking image cache...');
        print('Battery Screen: _imageCache keys: ${_imageCache.keys.toList()}');
        print('Battery Screen: _loadingImages: $_loadingImages');
        setState(() {}); // Force UI update
      }
    });
  }

  /// Load images for saved items using the image API
  void _loadImagesForSavedItems() async {
    print('=== Battery Screen: Loading Images for Saved Items ===');
    print('Battery Screen: Method entered successfully');
    
    // Debug: Print all saved items to see their structure
    print('Battery Screen: savedRectifierItems count: ${savedRectifierItems.length}');
    for (int i = 0; i < savedRectifierItems.length; i++) {
      final item = savedRectifierItems[i];
      print('Battery Screen: Rectifier Item $i: photoId=${item['photoId']}, serial=${item['serialNumber']}');
    }
    
    print('Battery Screen: savedMPPTItems count: ${savedMPPTItems.length}');
    for (int i = 0; i < savedMPPTItems.length; i++) {
      final item = savedMPPTItems[i];
      print('Battery Screen: MPPT Item $i: photoId=${item['photoId']}, serial=${item['serialNumber']}');
    }
    
    // Collect all photo IDs from saved items
    Set<int> photoIds = {};
    
    // Add photo IDs from rectifier items
    for (var item in savedRectifierItems) {
      if (item['photoId'] != null) {
        photoIds.add(item['photoId']);
        print('Battery Screen: Added photoId ${item['photoId']} from rectifier item');
      }
    }
    
    // Add photo IDs from MPPT items
    for (var item in savedMPPTItems) {
      if (item['photoId'] != null) {
        photoIds.add(item['photoId']);
        print('Battery Screen: Added photoId ${item['photoId']} from MPPT item');
      }
    }
    
    if (photoIds.isEmpty) {
      print('Battery Screen: No photo IDs found to load images');
      return;
    }
    
    print('Battery Screen: Total photo IDs to load: ${photoIds.length}');
    print('Battery Screen: Photo IDs: $photoIds');
    
    try {
      // Mark images as loading
      setState(() {
        _loadingImages.addAll(photoIds);
      });
      print('Battery Screen: Marked images as loading: $_loadingImages');
      
      // Fetch images from API
      print('Battery Screen: Calling _imageService.fetchImagesByIds...');
      print('Battery Screen: _imageService type: ${_imageService.runtimeType}');
      
      // Test if the service is working
      final imageMap = await _imageService.fetchImagesByIds(photoIds.toList());
      print('Battery Screen: Received imageMap with ${imageMap.length} images');
      print('Battery Screen: ImageMap keys: ${imageMap.keys.toList()}');
      
      // Update cache and remove loading state
      setState(() {
        print('Battery Screen: Before adding to cache - _imageCache keys: ${_imageCache.keys.toList()}');
        _imageCache.addAll(imageMap);
        print('Battery Screen: After adding to cache - _imageCache keys: ${_imageCache.keys.toList()}');
        _loadingImages.removeAll(photoIds);
      });
      
      print('Battery Screen: Successfully loaded ${imageMap.length} images');
      print('Battery Screen: Final _imageCache keys: ${_imageCache.keys.toList()}');
      print('Battery Screen: Final _loadingImages: $_loadingImages');
      
      // Debug: Check the format of loaded image data
      if (imageMap.isNotEmpty) {
        final firstImageKey = imageMap.keys.first;
        final firstImageData = imageMap[firstImageKey];
        print('Battery Screen: First image data length: ${firstImageData?.length ?? 0}');
        print('Battery Screen: First image data starts with: ${firstImageData?.substring(0, firstImageData.length > 50 ? 50 : firstImageData.length)}');
        
        // Verify the data is actually in the cache
        final cachedData = _imageCache[firstImageKey];
        print('Battery Screen: Verification - cached data for key $firstImageKey: ${cachedData != null ? 'EXISTS' : 'MISSING'}');
        if (cachedData != null) {
          print('Battery Screen: Cached data length: ${cachedData.length}');
        }
      }
      
      // Force a rebuild to ensure UI updates
      if (mounted) {
        setState(() {});
        print('Battery Screen: Forced UI rebuild after image loading');
      }
    } catch (e) {
      print('Battery Screen: Error loading images: $e');
      print('Battery Screen: Error stack trace: ${StackTrace.current}');
      setState(() {
        _loadingImages.removeAll(photoIds);
      });
    }
    
    print('Battery Screen: _loadImagesForSavedItems method completed');
  }

  /// Build photo column for saved items list
  Widget _buildPhotoColumn(Map<String, dynamic> item) {
    final photoId = item['photoId'];
    
    print('Battery Screen: _buildPhotoColumn called for item: photoId=$photoId, serial=${item['serialNumber']}');
    print('Battery Screen: Item keys: ${item.keys.toList()}');
    print('Battery Screen: photoId type: ${photoId.runtimeType}');
    print('Battery Screen: Current _imageCache keys: ${_imageCache.keys.toList()}');
    print('Battery Screen: Current _loadingImages: $_loadingImages');
    
    if (photoId == null) {
      print('Battery Screen: photoId is null, showing grey camera icon');
      return Icon(
        Icons.photo_camera_outlined,
        color: AppColors.greyColor,
        size: 20,
      );
    }
    
    // Check if image is cached
    final imageData = _imageCache[photoId];
    print('Battery Screen: Image $photoId cached: ${imageData != null ? 'YES' : 'NO'}');
    if (imageData != null) {
      print('Battery Screen: Showing image for photoId $photoId');
      print('Battery Screen: Image data length: ${imageData.length}');
      print('Battery Screen: Image data starts with: ${imageData.substring(0, imageData.length > 20 ? 20 : imageData.length)}');
      
      try {
        print('Battery Screen: Creating Base64ImageWidget...');
        final widget = GestureDetector(
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
        print('Battery Screen: Base64ImageWidget created successfully');
        return widget;
      } catch (e) {
        print('Battery Screen: Error creating Base64ImageWidget: $e');
        print('Battery Screen: Error stack trace: ${StackTrace.current}');
        // Fallback: show a colored container
        return Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: AppColors.green7, width: 1),
            color: AppColors.green7,
          ),
          child: Icon(
            Icons.image,
            color: Colors.white,
            size: 16,
          ),
        );
      }
    }
    
    // Show camera icon if no image data
    print('Battery Screen: No image data for photoId $photoId, showing green camera icon');
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
  void initState() {
    super.initState();
    serialController.addListener(_onFormChanged);
    
    print('Battery Screen: initState called');
    print('Battery Screen: batteryData is null: ${widget.batteryData == null}');
    if (widget.batteryData != null) {
      print('Battery Screen: batteryData available');
      print('Battery Screen: Assets count: ${widget.batteryData!.assets.length}');
      print('Battery Screen: Subcategories: ${widget.batteryData!.subCategories?.keys.toList()}');
    }
    
    // Check if we have data to show, if not, skip this screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      print('Battery Screen: Post frame callback executed');
      if (!_hasDataToShow()) {
        print('Battery Screen: No data to show, skipping to Extinguisher screen');
        _navigateToExtinguisherScreen();
      } else {
        print('Battery Screen: Data available, loading battery data');
        
        // Initialize image service
        try {
          _imageService = ImageRepository(AppConfig.of(context).apiProvider);
          print('Battery Screen: Image service initialized successfully');
        } catch (e) {
          print('Battery Screen: Error initializing image service: $e');
        }
        
        batteryCapacityController.text = _getBatteryCapacity();
        _loadBatteryData();
        _hasPostedBatteryData = false;
      }
    });
  }
  
  @override
  void dispose() {
    serialController.removeListener(_onFormChanged);
    rectifierRemarksController.dispose();
    mpptRemarksController.dispose();
    generalRemarksController.dispose();
    batteryCapacityController.dispose();
    rectifierSerialController.dispose();
    mpptSerialController.dispose();
    serialController.dispose();
    
    _hasPostedBatteryData = false;
    
    super.dispose();
  }



  /// Check if there is data to show on the screen
  bool _hasDataToShow() {
    if (widget.batteryData == null) {
      print('Battery Screen: No battery data available');
      return false;
    }

    // Check if we have any assets
    final hasAssets = widget.batteryData!.assets.isNotEmpty;

    // Check if we have any subcategories with data
    final hasSubCategories = widget.batteryData!.subCategories != null &&
        widget.batteryData!.subCategories!.values.any((items) => items.isNotEmpty);

    final hasData = hasAssets || hasSubCategories;

    print('Battery Screen: Data availability check:');
    print('  - Assets: $hasAssets (${widget.batteryData!.assets.length})');
    print('  - Subcategories: $hasSubCategories');
    print('  - Has data to show: $hasData');

    return hasData;
  }

  void _navigateToExtinguisherScreen() {
    print('Battery Screen: Navigating to Extinguisher screen');
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => ExtinguisherScreen(
          extinguisherData: widget.assetAuditData?.responseData.fireExtinguisher,
          assetAuditData: widget.assetAuditData,
          showSuccessMessage: false, // Don't show success message when skipping battery screen
        ),
      ),
    );
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
            'No Battery Data Available',
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
            'There are no Battery items to audit for this site.',
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



  void _onFormChanged() {
    setState(() {
      hasUnsavedChanges =
          selectedFile != null ||
          selectedStatus != null ||
          selectedBatteryStatus != null ||
          selectedType != null ||
          serialController.text.isNotEmpty;

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
        ),
      );
    }
  }

  // Validate required fields for saved items only
  bool _isFormValid() {
    print('=== Form Validation Debug ===');

    // Only check serial number and photo for saved items
    // Type, battery status, and file are not required for individual item saving

    // Check if serial number is entered in the CustomInfoCard
    // Check both controllers to see which one has data
    String? serialNumber = rectifierSerialController.text.isNotEmpty
        ? rectifierSerialController.text
        : mpptSerialController.text.isNotEmpty
            ? mpptSerialController.text
            : null;

    print('Serial number: "$serialNumber"');
    if (serialNumber == null || serialNumber.isEmpty) {
      print(' Serial number validation failed');
      return false;
    } else {
      print('✅ Serial number validation passed');
    }

    // Check if photo is added
    // Check both photo variables to see which one has data
    String? photo = rectifierPhoto ?? mpptPhoto;
    print('Photo: $photo');
    if (photo == null || photo.isEmpty) {
      print(' Photo validation failed');
      return false;
    } else {
      print('✅ Photo validation passed');
    }

    // Note: status is not required since it comes from API
    // and is set to true by default (backendStatus: true)
    String? status = rectifierStatus ?? mpptStatus;
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
            : null;

    print('Serial number: "$serialNumber"');
    if (serialNumber == null || serialNumber.isEmpty) {
      print(' Serial number validation failed');
      return false;
    } else {
      print(' Serial number validation passed');
    }

    // Check if photo is added
    // Check both photo variables to see which one has data
    String? photo = rectifierPhoto ?? mpptPhoto;
    print('Photo: $photo');
    if (photo == null || photo.isEmpty) {
      print(' Photo validation failed');
      return false;
    } else {
      print(' Photo validation passed');
    }

    // Note: status is not required since it comes from API
    // and is set to true by default (backendStatus: true)
    String? status = rectifierStatus ?? mpptStatus;
    print('Status: $status (not required)');

    print('Final validation result: true');
    return true;
  }

  // Save current form data for Rectifier
  void _saveRectifierForm() {
    // Check if we've reached the maximum limit from backend
    if (savedRectifierItems.length >= totalRectifierItems) {
      // Maximum limit reached! You can only scan up to $totalRectifierItems Rectifier items (as per backend count)
      return;
    }

    if (_isFormValid()) {
      setState(() {
        // Create a map of current form data
        Map<String, dynamic> currentFormData = {
          'serialNumber': rectifierSerialNumber,
          'photo': rectifierPhoto,
          'photoId': rectifierPhotoId, // Include the photoId from API
          'photoTakenTs': DateTime.now().toString(), // Add photo taken timestamp
          'status': rectifierStatus ?? "OK", // Default to "OK" if null (since it comes from API)
          'timestamp': DateTime.now(),
          'isQRCodeScanned': false, // Track if this was QR scanned or manual entry (false for manual entry)
          'itemType': 'CBMS', // Add item type for better tracking
          'remarks': rectifierRemarksController.text.isNotEmpty ? rectifierRemarksController.text : 'CBMS Item', // Add remarks for API
          'assetStatus': rectifierStatus ?? "OK", // Map to assetStatus field
          'assetAuditSiteRespId': _getAssetAuditSiteRespId('CBMS'), // Get ID from GET API response
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

      // Show success message with scanning limits info
      int remainingRectifiers = totalRectifierItems - savedRectifierItems.length;
      String message = '✅ CBMS item saved successfully!';
      if (remainingRectifiers > 0) {
        message += ' (${remainingRectifiers} remaining out of $totalRectifierItems backend count)';
      } else {
        message += ' (Maximum limit reached - backend count: $totalRectifierItems)';
      }
      showCustomToast(context, message);
    } else {
      print('Form validation failed - cannot save rectifier item');
    }
  }

  // Save current form data for MPPT
  void _saveMPPTForm() {
    // Check if we've reached the maximum limit from backend
    if (savedMPPTItems.length >= totalMPPTItems) {
      // Maximum limit reached! You can only scan up to $totalMPPTItems MPPT items (as per backend count)
      return;
    }

    if (_isFormValid()) {
      setState(() {
        // Create a map of current form data
        Map<String, dynamic> currentFormData = {
          'serialNumber': mpptSerialNumber,
          'photo': mpptPhoto,
          'photoId': mpptPhotoId, // Include the photoId from API
          'photoTakenTs': DateTime.now().toString(), // Add photo taken timestamp
          'status': mpptStatus ?? "OK", // Default to "OK" if null (since it comes from API)
          'timestamp': DateTime.now(),
          'isQRCodeScanned': false, // Track if this was QR scanned or manual entry (false for manual entry)
          'itemType': 'Battery', // Add item type for better tracking
          'remarks': batteryCapacityController.text.isNotEmpty ? batteryCapacityController.text : 'Battery Item', // Add remarks for API
          'assetStatus': mpptStatus ?? "OK", // Map to assetStatus field
          'assetAuditSiteRespId': _getAssetAuditSiteRespId('Battery'), // Get ID from GET API response
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

      // Show success message with scanning limits info
      int remainingMPPTs = totalMPPTItems - savedMPPTItems.length;
      String message = '✅ Battery item saved successfully!';
      if (remainingMPPTs > 0) {
        message += ' (${remainingMPPTs} remaining out of $totalMPPTItems backend count)';
      } else {
        message += ' (Maximum limit reached - backend count: $totalMPPTItems)';
      }
      showCustomToast(context, message);
    } else {
      print('Form validation failed - cannot save MPPT item');
    }
  }

  // Check if all items are scanned (for display purposes only)
  bool _isAllItemsScanned() {
    return (savedRectifierItems.length >= totalRectifierItems) &&
        (savedMPPTItems.length >= totalMPPTItems);
  }

  // Check if user can proceed to next screen (minimum 1 item required)
  bool _canProceedToNextScreen() {
    return (savedRectifierItems.length > 0) || (savedMPPTItems.length > 0);
  }

  // Get total scanned items count
  int _getTotalScannedItems() {
    return savedRectifierItems.length + savedMPPTItems.length;
  }

  // Get total expected items from backend
  int _getTotalExpectedItems() {
    return totalRectifierItems + totalMPPTItems;
  }

  // Method to get Battery capacity from API data
  String _getBatteryCapacity() {
    if (widget.batteryData != null) {
      // Try to get capacity from Battery assets first
      final batteryAssets = widget.batteryData!.assets ?? [];
      if (batteryAssets.isNotEmpty) {
        return batteryAssets.first.capacity ?? '200 AH';
      }

      // Fallback to Battery Cabinet if assets not available
      final batteryCabinetItems = widget.batteryData!.batteryCabinet ?? [];
      if (batteryCabinetItems.isNotEmpty) {
        return batteryCabinetItems.first.capacity ?? '200 AH';
      }
    }
    return '200 AH'; // Default fallback
  }

  /// Get asset audit site response ID from GET API response for a specific item type
  int? _getAssetAuditSiteRespId(String itemType) {
    if (widget.batteryData != null) {
      switch (itemType) {
        case 'CBMS':
          final cbmsItems = widget.batteryData!.cbms ?? [];
          if (cbmsItems.isNotEmpty) {
            return cbmsItems.first.assetAuditSiteRespId;
          }
          break;
        case 'Battery':
          final batteryAssets = widget.batteryData!.assets ?? [];
          if (batteryAssets.isNotEmpty) {
            return batteryAssets.first.assetAuditSiteRespId;
          }
          break;
      }
    }
    return null; // Return null if no matching item found
  }

  bool _validateSerialNumber(String serialNumber, bool isQRCodeScanned) {
    if (widget.batteryData == null) return false;

    print('=== Serial Number Validation Debug ===');
    print('Validating serial number: "$serialNumber" (QR Scanned: $isQRCodeScanned)');

    // For CBMS validation, focus on CBMS items specifically
    final cbmsItems = widget.batteryData!.cbms ?? [];
    print('CBMS items available: ${cbmsItems.length}');

    if (cbmsItems.isNotEmpty) {
      print('CBMS items details:');
      for (var item in cbmsItems) {
        print('  - Item: ${item.itemType} | nexgenSerialNo: "${item.nexgenSerialNo}" | mfgSerialNo: "${item.mfgSerialNo}"');
      }
    }

    // Check against CBMS items first (most relevant for rectifier validation)
    final cbmsValid = cbmsItems.any((item) {
      print('Checking CBMS item: nexgenSerialNo="${item.nexgenSerialNo}", mfgSerialNo="${item.mfgSerialNo}"');

      // Check nexgenSerialNo first (most common)
      if (item.nexgenSerialNo?.toLowerCase() == serialNumber.toLowerCase()) {
        print('✅ CBMS Match found in nexgenSerialNo: ${item.nexgenSerialNo}');
        return true;
      }
      // Check mfgSerialNo as fallback
      if (item.mfgSerialNo?.toLowerCase() == serialNumber.toLowerCase()) {
        print('✅ CBMS Match found in mfgSerialNo: ${item.mfgSerialNo}');
        return true;
      }
      return false;
    });

    if (cbmsValid) {
      print('✅ CBMS validation successful');
      if (isQRCodeScanned) {
        // CBMS QR Code validated successfully
      } else {
                  // CBMS manual entry validated successfully
      }
      return true;
    }

    // If CBMS validation fails, check other items as fallback
    print('CBMS validation failed, checking other items...');
    final allItems = [
      ...(widget.batteryData!.batteryCabinet ?? []),
      ...(widget.batteryData!.assets ?? []),
    ];

    print('Other items to check against: ${allItems.length}');

    final otherValid = allItems.any((item) {
      print('Checking other item: nexgenSerialNo="${item.nexgenSerialNo}", mfgSerialNo="${item.mfgSerialNo}"');

      if (item.nexgenSerialNo?.toLowerCase() == serialNumber.toLowerCase()) {
        print('✅ Other item match found in nexgenSerialNo: ${item.nexgenSerialNo}');
        return true;
      }
      if (item.mfgSerialNo?.toLowerCase() == serialNumber.toLowerCase()) {
        print('✅ Other item match found in mfgSerialNo: ${item.mfgSerialNo}');
        return true;
      }
      return false;
    });

    final finalResult = cbmsValid || otherValid;
    print('Final validation result: $finalResult (CBMS: $cbmsValid, Other: $otherValid)');

    if (!finalResult) {
      if (isQRCodeScanned) {
        showCustomToast(context, '❌ Invalid QR Code! Serial number not found in system.');
      } else {
        showCustomToast(context, '❌ Invalid manual entry! Serial number not found in system.');
      }
    }

    return finalResult;
  }

  /// Check if the current success state is for Battery screen data
  bool _isBatteryScreenDataPosted() {
    print('Battery Screen: Checking if Battery screen data was posted...');
    print('Battery Screen: _hasPostedBatteryData flag: $_hasPostedBatteryData');
    print('Battery Screen: Has saved rectifier items: ${savedRectifierItems.isNotEmpty}');
    print('Battery Screen: Has saved MPPT items: ${savedMPPTItems.isNotEmpty}');
    print('Battery Screen: Total saved items: ${savedRectifierItems.length + savedMPPTItems.length}');

    // Use the flag to determine if this success state is for Battery screen data
    return _hasPostedBatteryData;
  }

  int? _getRemarksAssetAuditSiteRespId() {
    print('=== Battery Screen: Getting Remarks AssetAuditSiteRespId ===');

    if (widget.batteryData == null) {
      print('batteryData is null, cannot get remarks ID');
      return null;
    }

    // Check if there are remarks in the backend data
    final remarks = widget.batteryData!.remarks;
    if (remarks.isNotEmpty) {
      print('Found ${remarks.length} remarks in backend data');

      // First try to find a general remarks entry (Battery category is usually the main one)
      for (var remark in remarks) {
        if (remark.assetAuditSiteRespId != null &&
            remark.assetAuditSiteRespId > 0 &&
            remark.itemType == 'Battery') {
          print('Using Battery remarks ID: ${remark.assetAuditSiteRespId}');
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
      print('Battery Screen: No asset audit data available for posting');
      return false;
    }

    try {


      // Create a list to hold all items to post
      List<Map<String, dynamic>> allItemsToPost = [];

      // Add saved CBMS items
      if (savedRectifierItems.isNotEmpty) {
        final enhancedCBMSItems = AssetAuditPostHelper.enhanceSavedItems(
          savedItems: savedRectifierItems,
          screenName: 'CBMS',
        );
        allItemsToPost.addAll(enhancedCBMSItems);
        print(
          'Battery Screen: Added ${enhancedCBMSItems.length} CBMS items to post',
        );
      }

      // Add saved Battery items
      if (savedMPPTItems.isNotEmpty) {
        final enhancedBatteryItems = AssetAuditPostHelper.enhanceSavedItems(
          savedItems: savedMPPTItems,
          screenName: 'Battery',
        );
        allItemsToPost.addAll(enhancedBatteryItems);
        print(
          'Battery Screen: Added ${enhancedBatteryItems.length} Battery items to post',
        );
      }

      // Add user's general remarks if entered
      if (generalRemarksController.text.isNotEmpty) {
        // Find the appropriate remarks entry from backend data
        int? remarksAssetAuditSiteRespId = _getRemarksAssetAuditSiteRespId();

        if (remarksAssetAuditSiteRespId != null) {
          Map<String, dynamic> remarksData = {
            'itemType': 'Battery', // Use the main screen category
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
          print('Battery Screen: Added user remarks to post with ID: $remarksAssetAuditSiteRespId, text: "${generalRemarksController.text}"');
        } else {
          print('Battery Screen: Could not find remarks ID from backend data');
        }
      }

      if (allItemsToPost.isEmpty) {
        print('Battery Screen: No items to post');
        return false;
      }

      // Log the data being posted
      print('Battery Screen: Data to be posted:');
      for (int i = 0; i < allItemsToPost.length; i++) {
        final item = allItemsToPost[i];
        print(
          '  Item ${i + 1}: ${item['itemType']} - Serial: ${item['serialNumber']} - PhotoId: ${item['photoId']} - AssetAuditSiteRespId: ${item['assetAuditSiteRespId']}',
        );
      }

      // Convert to POST request format
      final requests = await AssetAuditPostHelper.convertSavedItemsToPostRequest(
        savedItems: allItemsToPost,
        assetAuditData: widget.assetAuditData!,
        itemType: 'Battery',
        itemTypeId: AssetAuditPostHelper.getItemTypeId('Battery'),
        screenName: 'Battery',
        context: context,
        auditSchId: widget.assetAuditData?.pageHeader.first.siteAuditSchId.toString(),
      );

      if (requests.isEmpty) {
        print('Battery Screen: Failed to create POST requests');
        return false;
      }

      // Use the existing cubit to post data
      print('Battery Screen: Posting ${requests.length} items to API...');
      print('Battery Screen: Current cubit state before posting: ${context.read<AssetAuditCubit>().state}');

      final cubit = context.read<AssetAuditCubit>();
      print('Battery Screen: Got cubit: $cubit');

      // Set flag BEFORE making the API call to ensure it's set when success state is received
      setState(() {
        _hasPostedBatteryData = true;
      });
      print('Battery Screen: Set _hasPostedBatteryData flag to true BEFORE API call');
      print('Battery Screen: Flag value after setting: $_hasPostedBatteryData');

      cubit.postAssetAuditData(requests: requests);

      print('Battery Screen: postAssetAuditData called, waiting for state change...');
      print('Battery Screen: Cubit state after posting: ${cubit.state}');

      // Return true to indicate data is being posted
      return true;
    } catch (e) {
      print('Battery Screen: Error preparing data: $e');
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
      rectifierStatus = item["status"];

      // Set the serial controller text
      rectifierSerialController.text = item["serialNumber"] ?? "";

      // Remove the item from saved rectifier items
      savedRectifierItems.remove(item);
      currentScannedItems--;

      // Force rebuild of the CustomInfoCard widget with new data
      rectifierCardKey++;

      hasUnsavedChanges = true;

      // Reset the posted data flag when editing items
      _hasPostedBatteryData = false;
    });

    // Show message to user
    showCustomToast(context, 'Rectifier item loaded for editing. Make changes and save again.');
  }

  // Edit a specific MPPT item from the saved list
  void _editMPPTItem(Map<String, dynamic> item) {
    setState(() {
      // Load the item data back into the form
      mpptSerialNumber = item["serialNumber"];
      mpptPhoto = item["photo"];
      mpptStatus = item["status"];

      // Set the serial controller text
      mpptSerialController.text = item["serialNumber"] ?? "";

      // Remove the item from saved MPPT items
      savedMPPTItems.remove(item);
      currentScannedItems--;

      // Force rebuild of the CustomInfoCard widget with new data
      mpptCardKey++;

      hasUnsavedChanges = true;

      // Reset the posted data flag when editing items
      _hasPostedBatteryData = false;
    });

    // Show message to user
    showCustomToast(context, 'MPPT item loaded for editing. Make changes and save again.');
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AssetAuditCubit, AssetAuditState>(
      listener: (context, state) {
        print('Battery Screen: BlocListener received state: $state');
        print('Battery Screen: State type: ${state.runtimeType}');
        if (state is AssetAuditPostSuccess) {
          print('Battery Screen: AssetAuditPostSuccess received!');
          print('Battery Screen: State details: $state');
          print('Battery Screen: _hasPostedBatteryData flag: $_hasPostedBatteryData');

          // Check if this success state contains Battery-related items
          bool isBatteryData = false;
          print('Battery Screen: Total responses received: ${state.responses.length}');
          for (var response in state.responses) {
            print('Battery Screen: Full response object: $response');
            print('Battery Screen: Checking response itemTypeRemark: ${response.itemTypeRemark}');
            print('Battery Screen: Checking response itemTypeId: ${response.itemTypeId}');
            print('Battery Screen: Checking response nexgenSerialNo: ${response.nexgenSerialNo}');
            print('Battery Screen: Checking response assetStatus: ${response.assetStatus}');
            print('Battery Screen: Checking response remarks: ${response.remarks}');

            // Primary check: itemTypeRemark contains Battery-related text
            if (response.itemTypeRemark != null &&
                (response.itemTypeRemark!.contains('Battery') ||
                 response.itemTypeRemark!.contains('Rectifier') ||
                 response.itemTypeRemark!.contains('MPPT'))) {
              isBatteryData = true;
              print('Battery Screen: Found Battery-related item by itemTypeRemark: ${response.itemTypeRemark}');
              break;
            }

            // Fallback check: Check if this is a response to Battery screen data by looking at the flag
            if (_hasPostedBatteryData) {
              isBatteryData = true;
              print('Battery Screen: Found Battery-related item by flag check (fallback)');
              break;
            }

            print('Battery Screen: itemTypeRemark "${response.itemTypeRemark}" does not match Battery patterns');
          }

          // Only process this success state if it contains Battery screen data
          if (isBatteryData) {
            print('Battery Screen: Confirmed this is Battery screen data, proceeding with data refresh...');

            // Refresh data from API before navigating
            print('Battery Screen: Refreshing data from API...');
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
                  print('Battery Screen: Data refreshed, navigating to next screen...');
                  try {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ExtinguisherScreen(
                          extinguisherData: widget.assetAuditData?.responseData.fireExtinguisher,
                          assetAuditData: widget.assetAuditData,
                          showSuccessMessage: false, // Don't show success message when skipping battery screen
                        ),
                      ),
                    );
                    print('Battery Screen: Navigation completed successfully');

                    // Reset the flag after successful navigation
                    setState(() {
                      _hasPostedBatteryData = false;
                    });
                    print('Battery Screen: Reset _hasPostedBatteryData flag to false after navigation');
                  } catch (e) {
                    print('Battery Screen: Navigation error: $e');
                  }
                } else {
                  print('Battery Screen: Widget not mounted, cannot navigate');
                }
              });
            } catch (e) {
              print('Battery Screen: Error refreshing data: $e');
              // Fallback: navigate anyway after delay
              Future.delayed(const Duration(seconds: 2), () {
                if (mounted) {
                  try {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ExtinguisherScreen(
                          extinguisherData: widget.assetAuditData?.responseData.fireExtinguisher,
                          assetAuditData: widget.assetAuditData,
                          showSuccessMessage: false,
                        ),
                      ),
                    );
                    setState(() {
                      _hasPostedBatteryData = false;
                    });
                  } catch (e) {
                    print('Battery Screen: Fallback navigation error: $e');
                  }
                }
              });
            }
          } else {
            print('Battery Screen: Success state received but not for Battery screen data, ignoring...');
            print('Battery Screen: _hasPostedBatteryData flag: $_hasPostedBatteryData');
          }

        } else if (state is AssetAuditPostError) {
          // Only show error message if this error belongs to Battery screen data
          if (_hasPostedBatteryData) {
            print('Battery Screen: AssetAuditPostError received for Battery data');
            // Show error message and block navigation
            showCustomToast(context, '❌ Failed to save Battery data. Please try again.');

            // Reset the flag on error
            setState(() {
              _hasPostedBatteryData = false;
            });
            print('Battery Screen: Reset _hasPostedBatteryData flag to false after error');
          } else {
            print('Battery Screen: AssetAuditPostError received but not for Battery data, ignoring...');
          }
        }
        // if (state is AssetAuditPostSuccess) {
        //   print('Battery Screen: AssetAuditPostSuccess received!');
        //   print('Battery Screen: State details: $state');
        //   pushPage(context, ExtinguisherScreen(
        //     extinguisherData: widget.assetAuditData?.responseData.fireExtinguisher,
        //     assetAuditData: widget.assetAuditData,
        //     showSuccessMessage: true,
        //   ));
        //   // Check if this success state is for Battery screen data
        //   // We need to verify that the posted data is actually from this screen
        //   // if (_isBatteryScreenDataPosted()) {
        //   //   print('Battery Screen: Confirmed this is Battery screen data, proceeding with navigation...');
        //   //
        //   //   // Navigate to next screen immediately
        //   //   if (mounted) {
        //   //     print('Battery Screen: Widget is mounted, attempting navigation...');
        //   //     try {
        //   //       pushPage(context, ExtinguisherScreen(
        //   //         extinguisherData: widget.assetAuditData?.responseData.fireExtinguisher,
        //   //         assetAuditData: widget.assetAuditData,
        //   //         showSuccessMessage: true,
        //   //       ));
        //   //       print('Battery Screen: Navigation call completed successfully');
        //   //
        //   //       // Reset the flag after successful navigation
        //   //       setState(() {
        //   //         _hasPostedBatteryData = false;
        //   //       });
        //   //     } catch (e) {
        //   //       print('Battery Screen: Navigation error: $e');
        //   //     }
        //   //   } else {
        //   //     print('Battery Screen: Widget not mounted, cannot navigate');
        //   //   }
        //   // } else {
        //   //   print('Battery Screen: Success state received but not for Battery screen data, ignoring...');
        //   // }
        // } else  (state is AssetAuditPostError) {
        //   print('Battery Screen: AssetAuditPostError received:');
        //   // Show error message and block navigation
        //   showCustomToast(context, 'Failed to save Battery data. Please try again.');
        //
        //   // Reset the flag on error
        //   setState(() {
        //     _hasPostedBatteryData = false;
        //   });
        // };
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
                                if (_hasDataToShow()) ...[
                                  CustomOptionSelector(
                                    label: "CBMS Availability",
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
                                    print("Selected: $value");
                                    setState(() {
                                      selectedBatteryStatus = value;
                                      hasUnsavedChanges = true;
                                    });
                                  },
                                ),
                                getHeight(15),
                                CustomInfoCard(
                                  key: ValueKey('rectifier_$rectifierCardKey'),
                                  serialLabel: "CBMS - Serial Number *",
                                  serialHintText: "CBMS Serial Number",
                                  photoLabel: "Add a Photo",
                                  statusLabel: "Status",
                                  serialController: rectifierSerialController,
                                  onSave: _saveRectifierForm,
                                  isStatusEditable: true,
                                  showSaveButton: true,
                                  backendStatus: false,
                                  onPhotoTap: (photoPath) async {
                                    print('Battery Screen: Photo tapped with path: $photoPath');
                                    setState(() {
                                      rectifierPhoto = photoPath;
                                      hasUnsavedChanges = true;
                                    });

                                    // Upload photo immediately and get photoId
                                    if (photoPath != null && photoPath.isNotEmpty) {
                                      print('Battery Screen: Starting photo upload for CBMS...');
                                      try {
                                        final photoFile = File(photoPath);
                                        print('Battery Screen: Photo file created: ${photoFile.path}');

                                        if (await photoFile.exists()) {
                                          print('Battery Screen: Photo file exists, calling upload API...');

                                          // Get the cubit directly
                                          final photoUploadCubit = context.read<AssetAuditPhotoUploadCubit>();
                                          print('Battery Screen: Got photo upload cubit: $photoUploadCubit');

                                          // Upload photo
                                          await photoUploadCubit.uploadPhoto(
                                            file: photoFile,
                                            imgId: null,
                                            schId: widget.assetAuditData?.pageHeader.first.siteAuditSchId.toString() ?? "0",
                                          );

                                          // Wait for state to update
                                          await Future.delayed(const Duration(milliseconds: 500));

                                          // Check the result
                                          final state = photoUploadCubit.state;
                                          print('Battery Screen: Upload state: $state');

                                          if (state is AssetAuditPhotoUploadSuccess) {
                                            final photoId = int.tryParse(state.response.imgId) ?? 0;
                                            print('Battery Screen: Upload API response - photoId: $photoId');

                                            if (photoId > 0) {
                                              setState(() {
                                                rectifierPhotoId = photoId;
                                              });
                                              print('Battery Screen: CBMS Photo uploaded successfully, photoId: $photoId');
                                              print('Battery Screen: rectifierPhotoId set to: $rectifierPhotoId');
                                            } else {
                                              print('Battery Screen: ERROR - photoId is 0 or invalid');
                                            }
                                          } else if (state is AssetAuditPhotoUploadFailure) {
                                            print('Battery Screen: ERROR - Photo upload failed: ${state.errorMessage}');
                                          } else {
                                            print('Battery Screen: ERROR - Upload still in progress or unknown state: $state');
                                          }
                                        } else {
                                          print('Battery Screen: ERROR - Photo file does not exist at path: ${photoFile.path}');
                                        }
                                      } catch (e) {
                                        print('Battery Screen: Error uploading CBMS photo: $e');
                                        print('Battery Screen: Error stack trace: ${StackTrace.current}');
                                      }
                                    } else {
                                      print('Battery Screen: ERROR - photoPath is null or empty');
                                    }
                                  },
                                  onStatusChanged: (val) {
                                    setState(() {
                                      rectifierStatus = val ? "OK" : "Not OK";
                                      hasUnsavedChanges = true;
                                    });
                                  },
                                  onSerialChanged: (serialNumber) {
                                    print('Battery Screen: onSerialChanged called with: "$serialNumber"');

                                    setState(() {
                                      rectifierSerialNumber = serialNumber;
                                      hasUnsavedChanges = true;
                                    });

                                    // Validate serial number if not empty
                                    if (serialNumber.isNotEmpty) {
                                      print('Battery Screen: Serial number not empty, starting validation...');
                                      // For now, assume manual entry (we'll need to add QR code detection later)
                                      final isValid = _validateSerialNumber(serialNumber, false);
                                      print('Battery Screen: Validation result: $isValid');

                                      // Update the saved item to track validation result
                                      if (isValid) {
                                        print('Battery Screen: Serial number is valid, keeping it');
                                        // Serial number is valid, keep it
                                      } else {
                                        print('Battery Screen: Serial number is invalid, clearing it');
                                        // Serial number is invalid, clear it
                                        setState(() {
                                          rectifierSerialNumber = null;
                                          hasUnsavedChanges = false;
                                        });
                                      }
                                    } else {
                                      print('Battery Screen: Serial number is empty, skipping validation');
                                    }
                                  },
                                  initialStatus: rectifierSerialNumber == "OK"
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
                                  label: "Battery Make",
                                  initialValue: _getBatteryOEMName(),
                                  isRequired: false,
                                  isEditable: false,
                                ),
                                getHeight(15),
                                SerialNumberField(
                                  label: "Battery Cabinet Serial Number",
                                  controller: serialController,
                                ),
                                getHeight(15),
                                ImageUploadField(
                                  label: "Add Photo of Battery Modules *",
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

                                      // Upload photo immediately and get photoId for Battery Cabinet
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
                                              cabinetPhotoId = photoId; // Store the photoId for Battery Cabinet
                                            });
                                            print('Battery Screen: Cabinet Photo uploaded successfully, photoId: $photoId');
                                          }
                                        }
                                      } catch (e) {
                                        print('Battery Screen: Error uploading Cabinet photo: $e');
                                      }
                                    } else {
                                      setState(() {
                                        uploadedPhotoPath = null;
                                        cabinetPhotoId = null;
                                      });
                                    }
                                  },
                                ),
                                getHeight(15),
                                CustomFormField(
                                  label: "Count of Battery Modules ",
                                  // "Number of ${selectedType ?? 'Batteries'}",
                                  initialValue: totalRectifierItems.toString(),
                                  isRequired: true,
                                  isEditable: true,
                                  onChanged: (value) {
                                    setState(() {
                                      totalRectifierItems =
                                          int.tryParse(value) ?? 6;
                                      hasUnsavedChanges = true;
                                    });
                                  },
                                ),
                                getHeight(15),
                                Text(
                                  "Battery Module Details",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white,
                                    fontFamily: fontFamilyMontserrat,
                                  ),
                                ),
                                getHeight(3),
                                CustomInfoCard(
                                  key: ValueKey('mppt_$mpptCardKey'),
                                  serialLabel: "Battery - Serial Number",
                                  serialHintText: "Battery Serial Number",
                                  photoLabel: "Add a Photo",
                                  statusLabel: "Status",
                                  serialController: mpptSerialController,
                                  onSave: _saveMPPTForm,
                                  isStatusEditable: true,
                                  backendStatus: false,
                                  remarksLabel: "Capacity",
                                  remarksHintText: "Eg:200 AH",
                                  remarksController: batteryCapacityController,
                                  isRemarksEditable: false, // Make capacity non-editable
                                  onPhotoTap: (photoPath) async {
                                    print('Battery Screen: Photo tapped with path: $photoPath');
                                    setState(() {
                                      mpptPhoto = photoPath;
                                      hasUnsavedChanges = true;
                                    });

                                    // Upload photo immediately and get photoId
                                    if (photoPath != null && photoPath.isNotEmpty) {
                                      print('Battery Screen: Starting photo upload for Battery...');
                                      try {
                                        final photoFile = File(photoPath);
                                        print('Battery Screen: Photo file created: ${photoFile.path}');

                                        if (await photoFile.exists()) {
                                          print('Battery Screen: Photo file exists, calling upload API...');

                                          // Get the cubit directly
                                          final photoUploadCubit = context.read<AssetAuditPhotoUploadCubit>();
                                          print('Battery Screen: Got photo upload cubit: $photoUploadCubit');

                                          // Upload photo
                                          await photoUploadCubit.uploadPhoto(
                                            file: photoFile,
                                            imgId: null,
                                            schId: widget.assetAuditData?.pageHeader.first.siteAuditSchId.toString() ?? "0",
                                          );

                                          // Wait for state to update
                                          await Future.delayed(const Duration(milliseconds: 500));

                                          // Check the result
                                          final state = photoUploadCubit.state;
                                          print('Battery Screen: Upload state: $state');

                                          if (state is AssetAuditPhotoUploadSuccess) {
                                            final photoId = int.tryParse(state.response.imgId) ?? 0;
                                            print('Battery Screen: Upload API response - photoId: $photoId');

                                            if (photoId > 0) {
                                              setState(() {
                                                mpptPhotoId = photoId;
                                              });
                                              print('Battery Screen: Battery Photo uploaded successfully, photoId: $photoId');
                                              print('Battery Screen: mpptPhotoId set to: $mpptPhotoId');
                                            } else {
                                              print('Battery Screen: ERROR - photoId is 0 or invalid');
                                            }
                                          } else if (state is AssetAuditPhotoUploadFailure) {
                                            print('Battery Screen: ERROR - Photo upload failed: ${state.errorMessage}');
                                          } else {
                                            print('Battery Screen: ERROR - Upload still in progress or unknown state: $state');
                                          }
                                        } else {
                                          print('Battery Screen: ERROR - Photo file does not exist at path: ${photoFile.path}');
                                        }
                                      } catch (e) {
                                        print('Battery Screen: Error uploading Battery photo: $e');
                                        print('Battery Screen: Error stack trace: ${StackTrace.current}');
                                      }
                                    } else {
                                      print('Battery Screen: ERROR - photoPath is null or empty');
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
                                          mpptSerialNumber = null;
                                          hasUnsavedChanges = false;
                                        });
                                      }
                                    }
                                  },
                                  initialStatus: mpptStatus == "OK"
                                      ? true
                                      : (mpptStatus == "Not OK" ? false : null),
                                  initialPhotoPath: mpptPhoto,
                                  isEditable: true,
                                ),

                                getHeight(8),

                                _buildMPPTSavedItemsList(),

                                getHeight(15),
                                CustomRemarksField(
                                  label: "Add Remarks",
                                  hintText: "Remarks",
                                  controller: generalRemarksController,
                                ),
                                ] else ...[
                                  _buildNoDataMessage(),
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
                                text: "CCU",
                                isLeftArrow: true,
                                backgroundColor: AppColors.buttonColorBg,
                                textColor: AppColors.buttonColorSite,
                                onPressed: () {
                                  Navigator.pop(context);
                                },
                              ),
                            ),
                            getWidth(14),
                            Expanded(
                              child: ArrowButton(
                                text: _hasDataToShow() ? "Extinguisher" : "Skip",
                                isLeftArrow: false,
                                backgroundColor: AppColors.buttonColorBackBg,
                                textColor: AppColors.buttonColorTextBg,
                                onPressed: () async {
                                  print('Battery Screen: Extinguisher button pressed');

                                  // If no data to show, just navigate to next screen
                                  if (!_hasDataToShow()) {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => ExtinguisherScreen(
                                          extinguisherData: widget.assetAuditData?.responseData.fireExtinguisher,
                                          assetAuditData: widget.assetAuditData,
                                          showSuccessMessage: false,
                                        ),
                                      ),
                                    );
                                    return;
                                  }

                                  // Check if user has scanned at least one item
                                  if (!_canProceedToNextScreen()) {
                                    showCustomToast(context, '❌ Please scan at least 1 item before proceeding.');
                                    return;
                                  }

                                  print('Battery Screen: Can proceed to next screen, posting data...');

                                  // Post current screen data before navigating
                                  final success = await _postCurrentScreenData();
                                  print('Battery Screen: _postCurrentScreenData returned: $success');

                                  if (success) {
                                    print('Battery Screen: Data posted successfully, waiting for API response...');
                                    // Navigation will be handled in the BlocListener after API success
                                  } else {
                                    print('Battery Screen: Failed to post data');
                                    showCustomToast(context, '❌ Failed to post data. Please try again.');
                                  }
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
              // Full-screen loading overlay when posting data
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
          // Header Row - Always show
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
          const SizedBox(height: 8),

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
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Saved Items: ${savedRectifierItems.length} | Current Scanned: $currentScannedItems | Total Expected: $totalRectifierItems',
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

          // Items - Only show if list is not empty
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
                              onPressed: () => _editSavedItem(item, 'rectifier'),
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
                .toList(),
        ],
      ),
    );
  }

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
          // Header Row - Always show
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
          const SizedBox(height: 8),

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
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Saved Items: ${savedMPPTItems.length} | Current Scanned: $currentScannedItems | Total Expected: $totalMPPTItems',
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

          // Items - Only show if list is not empty
              if (savedMPPTItems.isNotEmpty) ...[
                ...savedMPPTItems
                    .map(
                      (item) {
                        print('Building MPPT item row for: $item');
                        return Container(
                          margin: const EdgeInsets.only(top: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.white,
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
                        );
                      },
                    )
                    .toList(),
              ],
            ],
      ),
    );
  }

  void _editSavedItem(Map<String, dynamic> item, String itemType) {

    setState(() {
      // Populate the form fields with the item's data for editing
      switch (itemType) {
        case 'rectifier':
          // Populate rectifier form with item data
          rectifierSerialController.text = item['serialNumber'] ?? '';
          rectifierSerialNumber = item['serialNumber'] ?? ''; // Also set the variable
          rectifierStatus = item['status'] ?? 'OK';
          rectifierPhotoId = item['photoId'];
          rectifierPhoto = item['photo'];
          savedRectifierItems.remove(item);
          currentScannedItems--;
          break;
          
        case 'mppt':
          mpptSerialController.text = item['serialNumber'] ?? '';
          mpptSerialNumber = item['serialNumber'] ?? '';
          mpptStatus = item['status'] ?? 'OK';
          mpptPhotoId = item['photoId'];
          mpptPhoto = item['photo'];
          savedMPPTItems.remove(item);
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
