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
import '../../../bloc/asset_audit_get_image_cubit.dart';
import '../../../bloc/audit_schedule_status_cubit.dart';

import '../../../bloc/asset_audit_state.dart';
import '../../../repositories/image_repository.dart';
import '../../../app_config.dart';
import 'dart:async';
import 'dart:io';
import 'dart:convert';

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
import '../../home_screen.dart';

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

  // Track which item type is being edited for image loading
  String? _editingItemType;

  final TextEditingController rectifierSerialController =
  TextEditingController();
  final TextEditingController mpptSerialController = TextEditingController();

  int rectifierCardKey = 0;
  int mpptCardKey = 0;

  bool _hasPostedBatteryData = false;

  late ImageRepository _imageService;
  Map<int, String> _imageCache = {};
  Set<int> _loadingImages = {};

  String _getBatteryOEMName() {
    if (widget.batteryData != null) {
      final batteryCabinetItems = widget.batteryData!.batteryCabinet ?? [];
      if (batteryCabinetItems.isNotEmpty) {
        return batteryCabinetItems.first.oemName ?? 'Delta';
      }

      final batteryAssets = widget.batteryData!.assets;
      if (batteryAssets.isNotEmpty) {
        return batteryAssets.first.oemName ?? 'Delta';
      }

      final cbmsItems = widget.batteryData!.cbms ?? [];
      if (cbmsItems.isNotEmpty) {
        return cbmsItems.first.oemName ?? 'Delta';
      }
    }

    return 'Delta';
  }

  void _loadBatteryData() {
    if (widget.batteryData == null) {
      print('Battery Debug: No battery data available');
      return;
    }

    print('Battery Debug: Loading battery data...');
    setState(() {
      // Clear existing saved items to avoid duplicates
      savedRectifierItems.clear();
      savedMPPTItems.clear();
      currentScannedItems = 0;

      // Load Battery Cabinet items (from subcategories)
      final batteryCabinetItems = widget.batteryData!.batteryCabinet ?? [];
      for (var item in batteryCabinetItems) {
        if (item.photoId != null) { // Only include items with photoId
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
        }
      }

      // Load Battery assets (general assets)
      final batteryAssets = widget.batteryData!.assets;
      for (var item in batteryAssets) {
        if (item.photoId != null) { // Only include items with photoId
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
        }
      }

      // Load CBMS items (from subcategories)
      final cbmsItems = widget.batteryData!.cbms ?? [];
      print('Battery Debug: Loading CBMS items from API: ${cbmsItems.length} items');
      for (var item in cbmsItems) {
        print('Battery Debug: CBMS item - Serial: ${item.mfgSerialNo}, PhotoId: ${item.photoId}, Status: ${item.assetStatus}');
        if (item.photoId != null) { // Only include items with photoId
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
          savedRectifierItems.add(savedItem); // Add CBMS items to rectifier list for display
          print('Battery Debug: Added CBMS item to savedRectifierItems: ${savedItem['serialNumber']}');
          currentScannedItems++;
        }
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
            break; // Use the first valid remark
          }
        }
      }

    });

    // Load images for saved items
    _loadImagesForSavedItems();
  }

  /// Load images for saved items using the image API
  void _loadImagesForSavedItems() async {
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

    if (photoIds.isEmpty) {
      return;
    }

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

      // Force a rebuild to ensure UI updates
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      setState(() {
        _loadingImages.removeAll(photoIds);
      });
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
      final completer = Completer<String?>();
      late StreamSubscription subscription;

      subscription = context.read<AssetAuditGetImageCubit>().stream.listen((state) {
        if (state is AssetAuditGetImageSuccess && state.imageData.isNotEmpty) {
          final finalImageData = state.imageData.startsWith('data:image/')
              ? state.imageData
              : 'data:image/jpeg;base64,${state.imageData}';
          completer.complete(finalImageData);
          subscription.cancel();
        } else if (state is AssetAuditGetImageFailure) {
          showCustomToast(context, 'Failed to load image: ${state.errorMessage}');
          completer.complete(null);
          subscription.cancel();
        }
      });

      context.read<AssetAuditGetImageCubit>().getImage(
        imgId: imagePath,
        schId: widget.assetAuditData?.pageHeader.first.siteAuditSchId?.toString() ?? '',
      );

      imageData = await completer.future;
    }

    if (imageData != null && imageData.isNotEmpty) {
      showDialog(
        context: context,
        builder: (context) => Dialog(
          backgroundColor: Colors.black,
          child: Stack(
            children: [
              Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.7,
                  maxWidth: MediaQuery.of(context).size.width * 0.9,
                ),
                child: imageData!.startsWith('data:image/')
                    ? Image.memory(
                        base64Decode(imageData.split(',').last),
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

  @override
  void initState() {
    super.initState();
    serialController.addListener(_onFormChanged);

    // Always initialize the screen - don't auto-navigate away
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Initialize image service
      try {
        _imageService = ImageRepository(AppConfig.of(context).apiProvider);
      } catch (e) {
      }

      batteryCapacityController.text = _getBatteryCapacity();
      _loadBatteryData();
      _hasPostedBatteryData = false;
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
      return false;
    }

    // Check if we have any assets
    final hasAssets = widget.batteryData!.assets.isNotEmpty;

    // Check if we have any subcategories with data
    final hasSubCategories = widget.batteryData!.subCategories != null &&
        widget.batteryData!.subCategories!.values.any((items) => items.isNotEmpty);
    if (widget.batteryData!.subCategories != null) {
      for (var entry in widget.batteryData!.subCategories!.entries) {
        print('Battery Debug: ${entry.key}: ${entry.value.length} items');
      }
    }

    final hasData = hasAssets || hasSubCategories;

    return hasData;
  }

  void _navigateToExtinguisherScreen() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => ExtinguisherScreen(
          extinguisherData: widget.assetAuditData?.responseData.fireExtinguisher,
          assetAuditData: widget.assetAuditData,
          showSuccessMessage: false,
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

    // Post data to API first
    try {
      await _postCurrentScreenData();
      
      // Update audit schedule status to "In Progress"
      if (mounted) {
        context.read<AuditScheduleStatusCubit>().updateStatus(
          siteAuditSchId: widget.assetAuditData?.pageHeader.first.siteAuditSchId.toString() ?? "",
          status: "IN-PROGRESS",
        );
      }
    } catch (e) {
      print('Error posting Battery data: $e');
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

  /// Validate if serial number exists in backend data
  bool _isValidSerialNumber(String serialNumber, String itemType) {
    if (widget.assetAuditData == null) {
      return false;
    }

    final batteryData = widget.assetAuditData!.responseData.battery;
    if (batteryData == null) {
      return false;
    }

    // Check in CBMS items
    if (itemType == 'CBMS') {
      final cbmsItems = batteryData.subCategories?['CBMS'] ?? [];
      for (var item in cbmsItems) {
        if (item.mfgSerialNo == serialNumber || item.nexgenSerialNo == serialNumber) {
          return true;
        }
      }
    }
    
    // Check in Battery Cabinet items
    if (itemType == 'Battery Cabinet') {
      final batteryCabinetItems = batteryData.subCategories?['Battery Cabinet'] ?? [];
      for (var item in batteryCabinetItems) {
        if (item.mfgSerialNo == serialNumber || item.nexgenSerialNo == serialNumber) {
          return true;
        }
      }
    }

    return false;
  }

  /// Check if the current form is valid for saving
  bool _isFormValidForSaving() {
    return _isFormValid();
  }

  /// Get validation error message for current form
  String? _getValidationErrorMessage() {
    if (widget.batteryData == null) {
      return null;
    }

    String? serialNumber = rectifierSerialController.text.isNotEmpty
        ? rectifierSerialController.text
        : mpptSerialController.text.isNotEmpty
        ? mpptSerialController.text
        : null;

    if (serialNumber == null || serialNumber.isEmpty) {
      return "Please enter a serial number";
    }

    // Check serial number validation
    String itemType = '';
    if (rectifierSerialController.text.isNotEmpty) {
      itemType = 'CBMS';
    } else if (mpptSerialController.text.isNotEmpty) {
      itemType = 'Battery Cabinet';
    }

    if (itemType.isNotEmpty && !_isValidSerialNumber(serialNumber, itemType)) {
      return "Invalid serial number. Please enter a valid ${itemType} serial number.";
    }

    // Check photo validation
    int? photoId = rectifierPhotoId ?? mpptPhotoId;
    if (photoId == null) {
      return "Please add a photo";
    }

    return null; // No validation errors
  }

  // Validate required fields for saved items only
  bool _isFormValid() {
    String? serialNumber = rectifierSerialController.text.isNotEmpty
        ? rectifierSerialController.text
        : mpptSerialController.text.isNotEmpty
        ? mpptSerialController.text
        : null;

    if (serialNumber == null || serialNumber.isEmpty) {
      return false;
    }

    // Validate serial number against backend data
    String itemType = '';
    if (rectifierSerialController.text.isNotEmpty) {
      itemType = 'CBMS';
    } else if (mpptSerialController.text.isNotEmpty) {
      itemType = 'Battery Cabinet';
    }

    if (itemType.isNotEmpty && !_isValidSerialNumber(serialNumber, itemType)) {
      return false; // Invalid serial number
    }

    // Check if photoId is available (photo is mandatory)
    int? photoId = rectifierPhotoId ?? mpptPhotoId;
    if (photoId == null) {
      return false;
    }

    String? status = rectifierStatus ?? mpptStatus;

    return true;
  }

  bool _validateForm() {
    setState(() {
      showValidationErrors = true;
    });

    String? serialNumber = rectifierSerialController.text.isNotEmpty
        ? rectifierSerialController.text
        : mpptSerialController.text.isNotEmpty
        ? mpptSerialController.text
        : null;

    if (serialNumber == null || serialNumber.isEmpty) {
      return false;
    }

    // Check if photoId is available
    int? photoId = rectifierPhotoId ?? mpptPhotoId;
    if (photoId == null) {
      return false;
    }

    // Note: status is not required since it comes from API
    // and is set to true by default (backendStatus: true)
    String? status = rectifierStatus ?? mpptStatus;

    return true;
  }

  // Save current form data for Rectifier (CBMS items)
  void _saveRectifierForm() {
    // Check only CBMS items for this form
    int completedCBMSCount = widget.batteryData?.subCategories?['CBMS']?.where((item) => 
        item.photoId != null && item.assetStatus != null).length ?? 0;
    int totalCBMSCount = widget.batteryData?.subCategories?['CBMS']?.length ?? 0;
    
    // Use total count as the maximum allowed for CBMS only
    int maxAllowedCBMSCount = totalCBMSCount;
    
    // Count only CBMS items in savedRectifierItems (filter by itemType)
    int savedCBMSCount = savedRectifierItems.where((item) => item['itemType'] == 'CBMS').length;

    
    if (savedCBMSCount > maxAllowedCBMSCount) {
      showCustomToast(
        context,
        'Maximum number of CBMS items ($maxAllowedCBMSCount) already added.',
      );
      return;
    }

    if (_isFormValid()) {
      if (rectifierPhotoId != null) {
        setState(() {
          Map<String, dynamic> currentFormData = {
            'serialNumber': rectifierSerialNumber,
            'photo': rectifierPhoto,
            'photoId': rectifierPhotoId,
            'photoTakenTs': DateTime.now().toString(),
            'status': rectifierStatus ?? "OK", // Default to "OK" if no status
            'timestamp': DateTime.now(),
            'isQRCodeScanned': false,
            'itemType': 'CBMS',
            'remarks': rectifierRemarksController.text.isNotEmpty ? rectifierRemarksController.text : 'CBMS Item',
            'assetStatus': rectifierStatus ?? "OK", // Default to "OK" if no status
            'assetAuditSiteRespId': _getAssetAuditSiteRespId('CBMS'),
          };
          savedRectifierItems.add(currentFormData);
          currentScannedItems++;

          // Clear AssetTypeCard form for next entry
          rectifierSerialNumber = null;
          rectifierPhoto = null;
          rectifierPhotoId = null;
          rectifierStatus = "OK"; // Reset to default status

          // Clear the controller
          rectifierSerialController.clear();

          // Force rebuild of the CustomInfoCard widget
          rectifierCardKey++;

          hasUnsavedChanges = false;
          showValidationErrors = false;
        });

        // Show success message with scanning limits info
        int remainingCBMSCount = maxAllowedCBMSCount - savedCBMSCount;
        String message = '✅ CBMS item saved successfully!';
        if (remainingCBMSCount > 0) {
          message += ' (${remainingCBMSCount} remaining)';
        } else {
          message += ' (All CBMS items added)';
        }

      }
    }
  }

  // Save current form data for MPPT (Battery items)
  void _saveMPPTForm() {
    int completedBatteryCabinetCount = widget.batteryData?.subCategories?['Battery Cabinet']?.where((item) =>
        item.photoId != null && item.assetStatus != null).length ?? 0;
    int totalBatteryCabinetCount = widget.batteryData?.subCategories?['Battery Cabinet']?.length ?? 0;
    
    // Use total count as the maximum allowed for Battery Cabinet only
    int maxAllowedBatteryCabinetCount = totalBatteryCabinetCount;
    
    // Count only Battery Cabinet items in savedMPPTItems (filter by itemType)
    int savedBatteryCabinetItems = savedMPPTItems.where((item) => item['itemType'] == 'Battery').length;


    if (savedBatteryCabinetItems > maxAllowedBatteryCabinetCount) {
      showCustomToast(
        context,
        'Maximum number of Battery Cabinet items ($maxAllowedBatteryCabinetCount) already added.',
      );
      return;
    }

    if (_isFormValid()) {
      if (mpptPhotoId != null) { // Only save if photoId is present
        setState(() {
          // Create a map of current form data
          Map<String, dynamic> currentFormData = {
            'serialNumber': mpptSerialNumber,
            'photo': mpptPhoto,
            'photoId': mpptPhotoId,
            'photoTakenTs': DateTime.now().toString(),
            'status': mpptStatus ?? "OK", // Default to "OK" if no status
            'timestamp': DateTime.now(),
            'isQRCodeScanned': false,
            'itemType': 'Battery',
            'remarks': batteryCapacityController.text.isNotEmpty ? batteryCapacityController.text : 'Battery Item',
            'assetStatus': mpptStatus ?? "OK", // Default to "OK" if no status
            'assetAuditSiteRespId': _getAssetAuditSiteRespId('Battery'),
          };

          // Add to saved MPPT items list
          savedMPPTItems.add(currentFormData);
          currentScannedItems++;

          // Clear AssetTypeCard form for next entry
          mpptSerialNumber = null;
          mpptPhoto = null;
          mpptPhotoId = null;
          mpptStatus = "OK"; // Reset to default status

          // Clear the controller
          mpptSerialController.clear();

          // Force rebuild of the CustomInfoCard widget
          mpptCardKey++;

          hasUnsavedChanges = false;
          showValidationErrors = false;
        });

        // Show success message with scanning limits info
        int remainingBatteryCabinetItems = maxAllowedBatteryCabinetCount - savedBatteryCabinetItems;
        String message = '✅ Battery Cabinet item saved successfully!';
        if (remainingBatteryCabinetItems > 0) {
          message += ' (${remainingBatteryCabinetItems} remaining)';
        } else {
          message += ' (All Battery Cabinet items added)';
        }

        
        showCustomToast(context, message);
      }
    }
  }


  List<Map<String, dynamic>> _getItemsWithPhotoAndStatus(List<Map<String, dynamic>> items) {
    return items.where((item) {
      final hasPhoto = item['photo'] != null && item['photo'].toString().isNotEmpty;
      final hasPhotoId = item['photoId'] != null;
      final hasStatus = (item['status'] != null && item['status'].toString().isNotEmpty) ||
                       (item['assetStatus'] != null && item['assetStatus'].toString().isNotEmpty);

      
      // Show all items for now - no filtering
      return true;
    }).toList();
  }

  // Check if all items are scanned (for display purposes only)
  bool _isAllItemsScanned() {
    // Check against unfiltered backend counts
    int unfilteredRectifierCount = widget.batteryData?.assets?.length ?? 0;
    int unfilteredMPPTCount = (widget.batteryData?.subCategories?['Battery Cabinet']?.length ?? 0) + (widget.batteryData?.subCategories?['CBMS']?.length ?? 0);
    return (savedRectifierItems.length >= unfilteredRectifierCount) &&
        (savedMPPTItems.length >= unfilteredMPPTCount);
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
    return '200 AH';
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
    return null;
  }

  bool _validateSerialNumber(String serialNumber, bool isQRCodeScanned) {
    if (widget.batteryData == null) return false;

    // For CBMS validation, focus on CBMS items specifically
    final cbmsItems = widget.batteryData!.cbms ?? [];

    // Check against CBMS items first (most relevant for rectifier validation)
    final cbmsValid = cbmsItems.any((item) {
      // Check nexgenSerialNo first (most common)
      if (item.nexgenSerialNo?.toLowerCase() == serialNumber.toLowerCase()) {
        return true;
      }
      // Check mfgSerialNo as fallback
      if (item.mfgSerialNo?.toLowerCase() == serialNumber.toLowerCase()) {
        return true;
      }
      return false;
    });

    if (cbmsValid) {
      return true;
    }

    // If CBMS validation fails, check other items as fallback
    final allItems = [
      ...(widget.batteryData!.batteryCabinet ?? []),
      ...(widget.batteryData!.assets ?? []),
    ];

    final otherValid = allItems.any((item) {
      if (item.nexgenSerialNo?.toLowerCase() == serialNumber.toLowerCase()) {
        return true;
      }
      if (item.mfgSerialNo?.toLowerCase() == serialNumber.toLowerCase()) {
        return true;
      }
      return false;
    });

    final finalResult = cbmsValid || otherValid;

    if (!finalResult) {
      if (isQRCodeScanned) {
        showCustomToast(context, '❌ Invalid QR Code! Serial number not found in system.');
      } else {
        showCustomToast(context, '❌ Invalid manual entry! Serial number not found in system.');
      }
    }

    return finalResult;
  }

  int? _getRemarksAssetAuditSiteRespId() {
    if (widget.batteryData == null) {
      return null;
    }

    // Check if there are remarks in the backend data
    final remarks = widget.batteryData!.remarks;
    if (remarks.isNotEmpty) {
      // First try to find a general remarks entry (Battery category is usually the main one)
      for (var remark in remarks) {
        if (remark.assetAuditSiteRespId != null &&
            remark.assetAuditSiteRespId > 0 &&
            remark.itemType == 'Battery') {
          return remark.assetAuditSiteRespId;
        }
      }

      // Fallback: find any remarks entry with a valid ID
      for (var remark in remarks) {
        if (remark.assetAuditSiteRespId != null && remark.assetAuditSiteRespId > 0) {
          return remark.assetAuditSiteRespId;
        }
      }
    }

    return null;
  }

  /// Post current screen data to API before navigating to next screen
  Future<bool> _postCurrentScreenData() async {
    if (widget.assetAuditData == null) {
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
      }

      // Add saved Battery items
      if (savedMPPTItems.isNotEmpty) {
        final enhancedBatteryItems = AssetAuditPostHelper.enhanceSavedItems(
          savedItems: savedMPPTItems,
          screenName: 'Battery',
        );
        allItemsToPost.addAll(enhancedBatteryItems);
      }

      // Add user's general remarks if entered
      if (generalRemarksController.text.isNotEmpty) {
        // Find the appropriate remarks entry from backend data
        int? remarksAssetAuditSiteRespId = _getRemarksAssetAuditSiteRespId();

        if (remarksAssetAuditSiteRespId != null) {
          Map<String, dynamic> remarksData = {
            'itemType': 'Battery',
            'remarks': generalRemarksController.text,
            'recordType': 'Remarks',
            'timestamp': DateTime.now(),
            'assetAuditSiteRespId': remarksAssetAuditSiteRespId,
            'status': 'OK',
            'serialNumber': 'REMARKS',
            'photo': null,
            'photoTakenTs': DateTime.now().toString(),
            'isQRCodeScanned': false,
            'localQrCodeScannedTs': DateTime.now().toString(),
            'localCreatedDt': DateTime.now().toString(),
            'localModifiedDt': DateTime.now().toString(),
          };
          allItemsToPost.add(remarksData);
        }
      }

      if (allItemsToPost.isEmpty) {
        return false;
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
        return false;
      }

      // Use the existing cubit to post data
      final cubit = context.read<AssetAuditCubit>();

      // Set flag BEFORE making the API call to ensure it's set when success state is received
      setState(() {
        _hasPostedBatteryData = true;
      });

      cubit.postAssetAuditData(requests: requests);

      // Return true to indicate data is being posted
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
      // Load the item data back into the form
      rectifierSerialNumber = item["serialNumber"];
      rectifierPhoto = item["photo"];
      rectifierStatus = item["status"];
      rectifierPhotoId = item["photoId"];

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
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AssetAuditGetImageCubit, AssetAuditGetImageState>(
      listener: (context, state) {
        if (state is AssetAuditGetImageSuccess) {
          // Handle successful image loading
          setState(() {
            // Update the appropriate photo variable based on editing item type
            print('Battery Debug: Image loaded successfully, editingItemType: $_editingItemType');
            if (_editingItemType == 'rectifier') {
              rectifierPhoto = state.imageData.startsWith('data:image/')
                  ? state.imageData
                  : 'data:image/jpeg;base64,${state.imageData}';
              print('Battery Debug: Updated rectifierPhoto with image data for CBMS item');
            } else if (_editingItemType == 'mppt') {
              mpptPhoto = state.imageData.startsWith('data:image/')
                  ? state.imageData
                  : 'data:image/jpeg;base64,${state.imageData}';
              print('Battery Debug: Updated mpptPhoto with image data');
            }
            // Clear the editing item type
            _editingItemType = null;
          });
        } else if (state is AssetAuditGetImageFailure) {
          print('Battery Debug: Failed to load image: ${state.errorMessage}');
          // Clear the editing item type on failure
          _editingItemType = null;
        }
      },
      child: BlocListener<AssetAuditCubit, AssetAuditState>(
      listener: (context, state) {
        if (state is AssetAuditPostSuccess) {
          // Only navigate if this Battery screen posted data (not from other screens)
          if (_hasPostedBatteryData) {
            print('Battery Debug: Navigating to ExtinguisherScreen because Battery data was posted');
            // Refresh data from API before navigating
            try {
              // Trigger a refresh of the asset audit data
              context.read<AssetAuditCubit>().getAssetAuditData(
                siteType: widget.assetAuditData?.pageHeader.first.siteDomainName ?? "",
                auditSchId: widget.assetAuditData?.pageHeader.first.siteAuditSchId.toString() ?? "",
                siteAuditSchId: widget.assetAuditData?.pageHeader.first.siteAuditSchId.toString() ?? "",
              );

              // Wait for data to refresh, then navigate
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
                    // Reset the flag after successful navigation
                    setState(() {
                      _hasPostedBatteryData = false;
                    });
                  } catch (e) {
                    print(e);
                  }
                }

            } catch (e) {
              // Fallback: navigate immediately
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
                  }
                }
            }
          }

        } else if (state is AssetAuditPostError) {
          // Only show error message if this error belongs to Battery screen data
          if (_hasPostedBatteryData) {
            // Show error message but don't block navigation completely
            showCustomToast(context, '❌ Failed to save Battery data to server. You can continue with local data.');

            // Reset the flag on error
            setState(() {
              _hasPostedBatteryData = false;
            });
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
                                      setState(() {
                                        rectifierPhoto = photoPath;
                                        hasUnsavedChanges = true;
                                      });

                                      // Upload photo immediately and get photoId
                                      if (photoPath != null && photoPath.isNotEmpty) {
                                        try {
                                          final photoFile = File(photoPath);
                                          if (await photoFile.exists()) {
                                            // Get the cubit directly
                                            final photoUploadCubit = context.read<AssetAuditPhotoUploadCubit>();

                                            // Upload photo
                                            await photoUploadCubit.uploadPhoto(
                                              file: photoFile,
                                              imgId: null,
                                              schId: widget.assetAuditData?.pageHeader.first.siteAuditSchId.toString() ?? "0",
                                            );

                                            // Check the result
                                            final state = photoUploadCubit.state;
                                            if (state is AssetAuditPhotoUploadSuccess) {
                                              final photoId = int.tryParse(state.response.imgId) ?? 0;
                                              if (photoId > 0) {
                                                setState(() {
                                                  rectifierPhotoId = photoId;
                                                });
                                              }
                                            } else if (state is AssetAuditPhotoUploadFailure) {
                                            }
                                          }
                                        } catch (e) {
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

                                      // Validate serial number if not empty
                                      if (serialNumber.isNotEmpty) {
                                        final isValid = _validateSerialNumber(serialNumber, false);
                                        if (isValid) {
                                          // Serial number is valid, keep it
                                        } else {
                                          setState(() {
                                            rectifierSerialNumber = null;
                                            hasUnsavedChanges = false;
                                          });
                                        }
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
                                                cabinetPhotoId = photoId;
                                              });
                                            }
                                          }
                                        } catch (e) {
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
                                    // remarksLabel: "Capacity",
                                    // remarksHintText: "Eg:200 AH",
                                    // remarksController: batteryCapacityController,
                                    isRemarksEditable: false,
                                    onPhotoTap: (photoPath) async {
                                      setState(() {
                                        mpptPhoto = photoPath;
                                        hasUnsavedChanges = true;
                                      });

                                      // Upload photo immediately and get photoId
                                      if (photoPath != null && photoPath.isNotEmpty) {
                                        try {
                                          final photoFile = File(photoPath);
                                          if (await photoFile.exists()) {
                                            // Get the cubit directly
                                            final photoUploadCubit = context.read<AssetAuditPhotoUploadCubit>();

                                            // Upload photo
                                            await photoUploadCubit.uploadPhoto(
                                              file: photoFile,
                                              imgId: null,
                                              schId: widget.assetAuditData?.pageHeader.first.siteAuditSchId.toString() ?? "0",
                                            );

                                            // Check the result
                                            final state = photoUploadCubit.state;
                                            if (state is AssetAuditPhotoUploadSuccess) {
                                              final photoId = int.tryParse(state.response.imgId) ?? 0;
                                              if (photoId > 0) {
                                                setState(() {
                                                  mpptPhotoId = photoId;
                                                });
                                              }
                                            }
                                          }
                                        } catch (e) {
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

                                      // Validate serial number if not empty
                                      if (serialNumber.isNotEmpty) {
                                        final isValid = _validateSerialNumber(serialNumber, false);
                                        if (isValid) {
                                          // Serial number is valid, keep it
                                        } else {
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
                                text: "Extinguisher",
                                isLeftArrow: false,
                                backgroundColor: AppColors.buttonColorBackBg,
                                textColor: AppColors.buttonColorTextBg,
                                onPressed: () async {
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

                                  // Allow navigation - no validation blocking

                                  // Post current screen data before navigating
                                  final success = await _postCurrentScreenData();

                                  if (success) {
                                    // Navigation will be handled in the BlocListener after API success
                                  } else {
                                    showCustomToast(context, 'Failed to post data. Please try again.');
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
      )
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

          // Show all items if filtered list is empty but we have items
          if (savedRectifierItems.isNotEmpty)
            ...(_getItemsWithPhotoAndStatus(savedRectifierItems).isNotEmpty 
                ? _getItemsWithPhotoAndStatus(savedRectifierItems)
                : savedRectifierItems)
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
                            Icons.edit_calendar_outlined,
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
          const SizedBox(height: 8),
          if (savedMPPTItems.isNotEmpty) ...[
            ..._getItemsWithPhotoAndStatus(savedMPPTItems)
                .map(
                  (item) {
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
                              Icons.edit_calendar_outlined,
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
          rectifierSerialNumber = item['serialNumber'] ?? '';
          rectifierStatus = item['status'] ?? 'OK';
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
            print('Battery Debug: Loading image for CBMS edit - photoId: ${rectifierPhotoId}');
            _loadImageForEdit(rectifierPhotoId.toString(), 'rectifier');
          }

          savedRectifierItems.remove(item);
          currentScannedItems--;
          break;

        case 'mppt':
          mpptSerialController.text = item['serialNumber'] ?? '';
          mpptSerialNumber = item['serialNumber'] ?? '';
          mpptStatus = item['status'] ?? 'OK';
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
            print('Battery Debug: Loading image for Battery edit - photoId: ${mpptPhotoId}');
            _loadImageForEdit(mpptPhotoId.toString(), 'mppt');
          }

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

  /// Load image for editing
  void _loadImageForEdit(String photoId, String itemType) {
    if (photoId.isNotEmpty && _isNumeric(photoId)) {
      // Set the editing item type to track which photo to update
      _editingItemType = itemType;
      
      // Request the image
      context.read<AssetAuditGetImageCubit>().getImage(
        imgId: photoId,
        schId: widget.assetAuditData?.pageHeader.first.siteAuditSchId?.toString() ?? '',
      );
      
      print(
        'Battery Debug: Loading image for edit - photoId: $photoId, itemType: $itemType',
      );
    }
  }
  
}

