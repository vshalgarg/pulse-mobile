import 'package:app/commonWidgets/custom_buttons/arrow_botton.dart';
import 'package:app/constants/constants_methods.dart';
import 'package:app/screens/asset_audit/asset_audit_telecom/fencing_screen.dart';
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
import '../../../commonWidgets/custom_radio_options.dart';
import '../../../commonWidgets/custom_remark.dart';
import '../../../commonWidgets/base64_image_widget.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_images.dart';
import '../../../constants/constants_strings.dart';
import '../../home_screen.dart';

class SurveillianceScreen extends StatefulWidget {
  final CategoryData? cctvData;
  final AssetAuditModel? assetAuditData;
  final bool showSuccessMessage; // Flag to show success message

  // Data from previous screens in the flow
  final List<Map<String, dynamic>>? extinguisherItems;
  final List<Map<String, dynamic>>? solarPlatesItems;

  const SurveillianceScreen({
    super.key,
    this.cctvData,
    this.assetAuditData,
    this.showSuccessMessage = false, // Default to false
    this.extinguisherItems,
    this.solarPlatesItems,
  });

  @override
  State<SurveillianceScreen> createState() => _SurveillianceScreenState();
}

class _SurveillianceScreenState extends State<SurveillianceScreen> {
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
  final cctvCapacityController =
      TextEditingController(); // Read-only controller for capacity

  // AssetTypeCard field values for CCTV
  String? cctvSerialNumber;
  String? cctvPhoto;
  int? cctvPhotoId; // Store the photoId from API
  String? cctvStatus;

  // Controllers for CustomInfoCard
  final TextEditingController cctvSerialController = TextEditingController();

  // Keys to force rebuild of CustomInfoCard widgets
  int cctvCardKey = 0;

  // Flag to track if Surveillance screen has posted data
  bool _hasPostedSurveillanceData = false;

  // Image loading and edit tracking
  String?
  _editingItemType; // Track which item type is being edited for image loading
  bool isEditingItem = false; // Track if we're currently editing an item

  // ===== IMAGE LOADING INFRASTRUCTURE =====
  late ImageRepository _imageService;
  Map<int, String> _imageCache = {};
  Set<int> _loadingImages = {};

  // ===== END IMAGE LOADING INFRASTRUCTURE =====

  @override
  void initState() {
    super.initState();
    serialController.addListener(_onFormChanged);

    // Check if we have data to show, if not, skip this screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_hasDataToShow()) {
        print(
          'Surveillance Screen: No data to show, skipping to Fencing screen',
        );
        _navigateToFencingScreen();
      } else {
        // Pre-fill capacity field with data from API
        cctvCapacityController.text = _getCCTVCapacity();

        // Initialize image service
        _imageService = ImageRepository(AppConfig.of(context).apiProvider);

        // Load CCTV data if available
        _loadCCTVData();

        // Debug: Print the structure of cctvData
        _debugCCTVData();
      }
    });
  }

  /// Debug method to print the complete structure of cctvData
  void _debugCCTVData() {
    print('=== Surveillance Screen: Debug Data Structure ===');
    if (widget.cctvData != null) {
      print('cctvData is not null');
      print('cctvData type: ${widget.cctvData.runtimeType}');

      // Access CategoryData properties correctly
      print('assets: ${widget.cctvData!.assets}');
      print('assets length: ${widget.cctvData!.assets.length}');
      print('remarks: ${widget.cctvData!.remarks}');
      print('remarks length: ${widget.cctvData!.remarks.length}');

      if (widget.cctvData!.subCategories != null) {
        print('subCategories: ${widget.cctvData!.subCategories}');
        widget.cctvData!.subCategories!.forEach((key, items) {
          print('Subcategory $key: ${items.length} items');
        });
      } else {
        print('No subcategories found');
      }
    } else {
      print('cctvData is null');
    }
    print('================================================');
  }

  /// Check if there is data to show on the screen
  bool _hasDataToShow() {
    if (widget.cctvData == null) {
      print('Surveillance Screen: No CCTV data available');
      return false;
    }

    // Check if we have any assets
    final hasAssets = widget.cctvData!.assets.isNotEmpty;

    // Check if we have any subcategories with data
    final hasSubCategories =
        widget.cctvData!.subCategories != null &&
        widget.cctvData!.subCategories!.values.any((items) => items.isNotEmpty);

    final hasData = hasAssets || hasSubCategories;

    print('Surveillance Screen: Data availability check:');
    print('  - Assets: $hasAssets (${widget.cctvData!.assets.length})');
    print('  - Subcategories: $hasSubCategories');
    print('  - Has data to show: $hasData');

    return hasData;
  }

  void _navigateToFencingScreen() {
    print('Surveillance Screen: Navigating to Fencing screen');
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => FencingScreen(
          fencingData:
              widget.assetAuditData?.responseData.categories['Boundary'],
          assetAuditData: widget.assetAuditData,
          showSuccessMessage: false,
          // Don't show success message when skipping surveillance screen
          extinguisherItems: widget.extinguisherItems ?? [],
          solarPlatesItems: widget.solarPlatesItems ?? [],
          surveillanceItems: [],
        ),
      ),
    );
  }

  /// Navigate to next screen with current saved data
  void _navigateToNextScreen() {
    print('Surveillance Screen: Navigating to next screen with saved data');
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FencingScreen(
          fencingData:
              widget.assetAuditData?.responseData.categories['Boundary'],
          assetAuditData: widget.assetAuditData,
          showSuccessMessage: false,
          extinguisherItems: widget.extinguisherItems ?? [],
          solarPlatesItems: widget.solarPlatesItems ?? [],
          surveillanceItems: [...savedCCTVItems],
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
            'No CCTV Data Available',
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
            'There are no CCTV items to audit for this site.',
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

  void _loadCCTVData() {
    if (widget.cctvData != null) {
      setState(() {
        print('=== Surveillance Screen: Loading CCTV Data ===');
        print('cctvData type: ${widget.cctvData.runtimeType}');

        // Load CCTV assets data
        final cctvAssets = widget.cctvData!.assets;

        if (cctvAssets.isNotEmpty) {
          // Process CCTV assets for count only
          for (int i = 0; i < cctvAssets.length; i++) {
            var item = cctvAssets[i];
          }
        } else {
          print('No CCTV assets found in CategoryData.assets');
        }

        // Check if there are subcategories
        if (widget.cctvData!.subCategories != null) {
          widget.cctvData!.subCategories!.forEach((key, items) {});
        } else {
          print('No subcategories found');
        }

        // Load remarks and populate the CustomRemarksField
        final remarks = widget.cctvData!.remarks;
        if (remarks.isNotEmpty) {
          // Process remarks and populate the CustomRemarksField
          for (int i = 0; i < remarks.length; i++) {
            var remark = remarks[i];

            // Populate the CustomRemarksField with the first valid remark
            if (remark.itemTypeRemark != null &&
                remark.itemTypeRemark!.isNotEmpty) {
              generalRemarksController.text = remark.itemTypeRemark!;
              print(
                'Surveillance Screen: Loaded remark from API: ${remark.itemTypeRemark}',
              );
              break; // Use the first valid remark
            }
          }
        } else {
          print('No CCTV remarks found');
        }

        // Load saved items from API - only items with complete data
        _loadSavedItemsFromAPI();

        // Update total count based on actual data (but don't pre-populate saved items)
        totalCCTVItems = cctvAssets.length;

        print('=== Surveillance Screen: Data Summary ===');
        print('Total expected items: $totalCCTVItems');
        print('Total remarks: ${remarks.length}');
        print('==========================================');
      });
    } else {
      print('Surveillance Screen: No cctvData available');
    }
  }

  /// Load saved items from API - only items with complete data (serial, photo, status)
  void _loadSavedItemsFromAPI() {
    if (widget.cctvData == null) {
      print('Surveillance Screen: No CCTV data available');
      return;
    }

    print('Surveillance Screen: Loading saved items from API...');

    setState(() {
      // Clear existing saved items to avoid duplicates
      savedCCTVItems.clear();
      currentScannedItems = 0;

      // Load CCTV assets from both assets array and subcategories
      final cctvAssets = widget.cctvData!.assets;
      final subCategories = widget.cctvData!.subCategories;

      print(
        'Surveillance Screen: Found ${cctvAssets.length} CCTV assets in main array',
      );

      // Also check subcategories for CCTV items
      if (subCategories != null) {
        print('Surveillance Screen: Checking subcategories for CCTV items...');
        subCategories.forEach((key, items) {});
      }

      // Process items from main assets array
      for (var item in cctvAssets) {
        bool hasSerial =
            (item.mfgSerialNo != null && item.mfgSerialNo!.isNotEmpty) ||
            (item.nexgenSerialNo != null && item.nexgenSerialNo!.isNotEmpty);

        if (hasSerial && item.photoId != null && item.assetStatus != null) {
          Map<String, dynamic> savedItem = {
            'serialNumber':
                item.mfgSerialNo ?? item.nexgenSerialNo ?? 'Unknown',
            'photo': null,
            'photoId': item.photoId,
            'status': item.assetStatus ?? 'OK',
            'timestamp': DateTime.now(),
            'isQRCodeScanned': item.qrCodeScanned ?? false,
            'itemType': item.itemType ?? 'CCTV',
            'remarks': item.itemTypeRemark ?? 'CCTV Item',
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
          print(
            'Surveillance Screen: Added CCTV item: ${savedItem['serialNumber']}',
          );
        }
      }

      // Process items from subcategories
      if (subCategories != null) {
        subCategories.forEach((key, items) {
          for (var item in items) {
            bool hasSerial =
                (item.mfgSerialNo != null && item.mfgSerialNo!.isNotEmpty) ||
                (item.nexgenSerialNo != null &&
                    item.nexgenSerialNo!.isNotEmpty);

            if (hasSerial && item.photoId != null && item.assetStatus != null) {
              Map<String, dynamic> savedItem = {
                'serialNumber':
                    item.mfgSerialNo ?? item.nexgenSerialNo ?? 'Unknown',
                'photo': null,
                'photoId': item.photoId,
                'status': item.assetStatus ?? 'OK',
                'timestamp': DateTime.now(),
                'isQRCodeScanned': item.qrCodeScanned ?? false,
                'itemType': item.itemType ?? 'CCTV',
                'remarks': item.itemTypeRemark ?? 'CCTV Item',
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
              print(
                'Surveillance Screen: Added CCTV item from subcategory $key: ${savedItem['serialNumber']}',
              );
            }
          }
        });
      }
    });

    // Load images for saved items
    _loadImagesForSavedItems();
  }

  void _loadImagesForSavedItems() async {
    Set<int> photoIds = {};

    // Add photo IDs from CCTV items
    for (var item in savedCCTVItems) {
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
    } catch (e) {
      setState(() {
        _loadingImages.removeAll(photoIds);
      });
    }
  }

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
        child: const Icon(Icons.camera_alt, color: AppColors.green7, size: 16),
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

      subscription = context.read<AssetAuditGetImageCubit>().stream.listen((
        state,
      ) {
        if (state is AssetAuditGetImageSuccess && state.imageData.isNotEmpty) {
          final finalImageData = state.imageData.startsWith('data:image/')
              ? state.imageData
              : 'data:image/jpeg;base64,${state.imageData}';
          completer.complete(finalImageData);
          subscription.cancel();
        } else if (state is AssetAuditGetImageFailure) {
          print('Failed to fetch image: ${state.errorMessage}');
          showCustomToast(
            context,
            'Failed to load image: ${state.errorMessage}',
          );
          completer.complete(null);
          subscription.cancel();
        }
      });

      context.read<AssetAuditGetImageCubit>().getImage(
        imgId: imagePath,
        schId:
            widget.assetAuditData?.pageHeader.first.siteAuditSchId
                ?.toString() ??
            '',
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
                    : Image.file(File(imageData), fit: BoxFit.contain),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.red, size: 30),
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
  void dispose() {
    serialController.removeListener(_onFormChanged);
    serialController.dispose();
    cctvSerialController.dispose();
    rectifierRemarksController.dispose();
    mpptRemarksController.dispose();
    generalRemarksController.dispose();
    cctvCapacityController.dispose();
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

  Future<void> _saveAndExit() async {
    // First close the unsaved changes dialog
    Navigator.of(context).pop();

    try {
      await _postCurrentScreenData();

      // Update audit schedule status to "In Progress"
      if (mounted) {
        context.read<AuditScheduleStatusCubit>().updateStatus(
          siteAuditSchId:
              widget.assetAuditData?.pageHeader.first.siteAuditSchId
                  .toString() ??
              "",
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
        MaterialPageRoute(builder: (context) => HomeScreen()),
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

    // Check if photo ID is present (required for all items)
    int? photoId = cctvPhotoId;
    if (photo != null && photoId == null) {
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
    // Check against items that already have both photo_id and asset_status
    int completedCCTVCount =
        widget.cctvData?.assets
            ?.where((item) => item.photoId != null && item.assetStatus != null)
            .length ??
        0;
    int totalCCTVCount = widget.cctvData?.assets?.length ?? 0;

    // If there are completed items, use completed count; otherwise use total count
    int maxAllowedCCTVCount = completedCCTVCount > 0
        ? completedCCTVCount
        : totalCCTVCount;

    if (savedCCTVItems.length >= maxAllowedCCTVCount) {
      showCustomToast(
        context,
        'Maximum number of CCTV items ($maxAllowedCCTVCount) already added.',
      );
      return;
    }

    if (_isFormValid()) {
      setState(() {
        // Get the actual serial number from the controller
        String actualSerialNumber = cctvSerialController.text.isNotEmpty
            ? cctvSerialController.text
            : 'Unknown';

        // Get the assetAuditSiteRespId for CCTV
        int assetAuditSiteRespId = _getAssetAuditSiteRespId('CCTV');
        Map<String, dynamic> currentFormData = {
          'serialNumber': actualSerialNumber,
          // Use the actual serial number from controller
          'photo': cctvPhoto,
          'photoId': cctvPhotoId,
          // Include the photoId from API
          'photoTakenTs': DateTime.now().toString(),
          'itemType': 'CCTV',
          // Include item type
          'remarks': 'CCTV Item',
          // Include remarks
          'status': cctvStatus ?? "OK",
          // Set status field
          'assetStatus': cctvStatus ?? "OK",
          // Also set assetStatus field
          'assetAuditSiteRespId': assetAuditSiteRespId,
          // Include asset audit site resp ID
          'timestamp': DateTime.now(),
          'isQRCodeScanned': false,
          // Track if this was QR scanned or manual entry (false for manual entry)
        };

        if (isEditingItem) {
          savedCCTVItems.add(currentFormData);
          currentScannedItems++;

          // Clear the form after editing and reset flags
          cctvSerialNumber = null;
          cctvPhoto = null;
          cctvStatus = null;
          cctvPhotoId = null;
          cctvSerialController.clear();
          cctvCardKey++;

          isEditingItem = false;
          hasUnsavedChanges = false;
          showValidationErrors = false;
        } else {
          // We're adding a new item - add to list and clear form
          savedCCTVItems.add(currentFormData);
          currentScannedItems++;

          // Clear form for next entry
          cctvSerialNumber = null;
          cctvPhoto = null;
          cctvStatus = null;
          cctvPhotoId = null; // Clear photoId as well

          cctvSerialController.clear();
          cctvCardKey++;

          hasUnsavedChanges = false;
          showValidationErrors = false;
        }
      });

      int remainingCCTVs = maxAllowedCCTVCount - savedCCTVItems.length;
    }
  }

  // Check if all items are scanned (for display purposes only)
  // Helper method to filter items that have both photo and status
  List<Map<String, dynamic>> _getItemsWithPhotoAndStatus(
    List<Map<String, dynamic>> items,
  ) {
    return items.where((item) {
      final hasPhoto =
          item['photo'] != null && item['photo'].toString().isNotEmpty;
      final hasPhotoId = item['photoId'] != null;
      final hasStatus =
          (item['status'] != null && item['status'].toString().isNotEmpty) ||
          (item['assetStatus'] != null &&
              item['assetStatus'].toString().isNotEmpty);
      return hasPhotoId && hasStatus;
    }).toList();
  }

  bool _isAllItemsScanned() {
    // Check against items that already have both photo_id and asset_status
    int completedCCTVCount =
        widget.cctvData?.assets
            ?.where((item) => item.photoId != null && item.assetStatus != null)
            .length ??
        0;
    int totalCCTVCount = widget.cctvData?.assets?.length ?? 0;

    int maxAllowedCCTVCount = completedCCTVCount > 0
        ? completedCCTVCount
        : totalCCTVCount;

    return savedCCTVItems.length >= maxAllowedCCTVCount;
  }

  // Check if user can proceed to next screen (minimum 1 item required)
  bool _canProceedToNextScreen() {
    return savedCCTVItems.length > 0;
  }

  // Method to get CCTV capacity from API data
  String _getCCTVCapacity() {
    print('=== Surveillance Screen: Getting CCTV Capacity ===');

    if (widget.cctvData == null) {
      print('cctvData is null, returning default capacity');
      return '1080p'; // Default fallback
    }

    print('cctvData is not null, checking for capacity...');

    // Get capacity from CCTV assets
    final cctvAssets = widget.cctvData!.assets ?? [];
    if (cctvAssets.isNotEmpty) {
      print('Found ${cctvAssets.length} CCTV assets');
      final firstAsset = cctvAssets.first;
      print('First CCTV asset capacity: ${firstAsset.capacity}');
      if (firstAsset.capacity != null && firstAsset.capacity!.isNotEmpty) {
        print('Returning capacity from CCTV assets: ${firstAsset.capacity}');
        return firstAsset.capacity!;
      }
    } else {
      print('No CCTV assets found in CategoryData.assets');
    }

    print('No capacity found in CCTV assets, returning default');
    return '1080p'; // Default fallback
  }

  /// Get asset audit site response ID from GET API response for a specific item type
  int _getAssetAuditSiteRespId(String itemType) {
    print(
      '=== Surveillance Screen: Getting AssetAuditSiteRespId for $itemType ===',
    );

    if (widget.cctvData == null) {
      print('cctvData is null, returning default ID');
      return 0; // Default ID
    }

    print('cctvData is not null, searching for $itemType...');

    // First check in assets
    final cctvAssets = widget.cctvData!.assets ?? [];
    if (cctvAssets.isNotEmpty) {
      print('Found ${cctvAssets.length} assets in CategoryData.assets');
      for (var asset in cctvAssets) {
        print('Asset: ${asset.itemType} - ID: ${asset.assetAuditSiteRespId}');
        if (asset.itemType == itemType) {
          print(
            'Found $itemType in assets with ID: ${asset.assetAuditSiteRespId}',
          );
          return asset.assetAuditSiteRespId ?? 0;
        }
      }
    } else {
      print('No assets found in CategoryData.assets');
    }

    // If not found in assets, check subcategories
    if (widget.cctvData!.subCategories != null) {
      print('Checking subcategories for $itemType...');
      for (var entry in widget.cctvData!.subCategories!.entries) {
        String key = entry.key;
        List<AssetItem> items = entry.value;
        print('Subcategory $key: ${items.length} items');
        for (var item in items) {
          print(
            'Item in $key: ${item.itemType} - ID: ${item.assetAuditSiteRespId}',
          );
          if (item.itemType == itemType) {
            print(
              'Found $itemType in subcategory $key with ID: ${item.assetAuditSiteRespId}',
            );
            return item.assetAuditSiteRespId ?? 0;
          }
        }
      }
    } else {
      print('No subcategories found');
    }

    // Try specific subcategory helper methods if they exist
    try {
      // Check if there are specific helper methods for CCTV
      if (itemType == 'CCTV') {
        // Try to find CCTV in the main assets or any available structure
        final allAssets = widget.cctvData!.assets ?? [];
        if (allAssets.isNotEmpty) {
          final firstAsset = allAssets.first;
          print(
            'Using first available asset ID: ${firstAsset.assetAuditSiteRespId}',
          );
          return firstAsset.assetAuditSiteRespId ?? 0;
        }
      }
    } catch (e) {
      print('Error accessing helper methods: $e');
    }

    print('No $itemType found in any structure, returning default ID');
    return 0; // Default ID
  }

  /// Validate serial number against API data
  /// Returns true if valid, false if invalid
  bool _validateSerialNumber(String serialNumber, bool isQRCodeScanned) {
    if (widget.cctvData == null) return false;

    if (isQRCodeScanned) {
      // For QR code scans, validate against nexgen_serial_no
      final allItems = widget.cctvData!.assets ?? [];

      final isValid = allItems.any(
        (item) =>
            item.nexgenSerialNo?.toLowerCase() == serialNumber.toLowerCase(),
      );

      if (isValid) {
      } else {
        showCustomToast(
          context,
          '❌ Invalid QR Code! Serial number not found in system.',
        );
      }

      return isValid;
    } else {
      // For manual entries, validate against mfg_serial_no
      final allItems = widget.cctvData!.assets ?? [];

      final isValid = allItems.any(
        (item) => item.mfgSerialNo?.toLowerCase() == serialNumber.toLowerCase(),
      );

      if (isValid) {
        print('✅ Manual entry validated successfully!');
      } else {
        showCustomToast(
          context,
          '❌ Invalid manual entry! Serial number not found in system.',
        );
      }

      return isValid;
    }
  }

  int? _getRemarksAssetAuditSiteRespId() {
    print('=== Surveillance Screen: Getting Remarks AssetAuditSiteRespId ===');

    if (widget.cctvData == null) {
      print('cctvData is null, cannot get remarks ID');
      return null;
    }

    // Check if there are remarks in the backend data
    final remarks = widget.cctvData!.remarks;
    if (remarks.isNotEmpty) {
      print('Found ${remarks.length} remarks in backend data');

      // First try to find a general remarks entry (CCTV category is usually the main one)
      for (var remark in remarks) {
        if (remark.assetAuditSiteRespId != null &&
            remark.assetAuditSiteRespId > 0 &&
            remark.itemType == 'CCTV') {
          print('Using CCTV remarks ID: ${remark.assetAuditSiteRespId}');
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

  /// Post current screen data to API before navigating to next screen
  Future<bool> _postCurrentScreenData() async {
    if (widget.assetAuditData == null) {
      print('Surveillance Screen: No asset audit data available for posting');
      return false;
    }

    try {
      // Create a list to hold all items to post
      List<Map<String, dynamic>> allItemsToPost = [];

      // Enhance saved items with additional data
      final enhancedItems = AssetAuditPostHelper.enhanceSavedItems(
        savedItems: savedCCTVItems,
        screenName: 'Surveillance',
      );
      allItemsToPost.addAll(enhancedItems);

      if (generalRemarksController.text.isNotEmpty) {
        // Find the appropriate remarks entry from backend data
        int? remarksAssetAuditSiteRespId = _getRemarksAssetAuditSiteRespId();

        if (remarksAssetAuditSiteRespId != null) {
          Map<String, dynamic> remarksData = {
            'itemType': 'CCTV',
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
            'photoId': null,
            // No photo ID for remarks
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

            // Additional required fields for API - using correct field names
            'localCreatedBy': 1,
            // Default user ID - correct field name
            'localModifiedBy': 1,
            // Default user ID - correct field name
            'isActive': true,
            // Default active status
            'itemInstanceId': null,
            // Remarks don't have item instance ID
            'itemTypeId': AssetAuditPostHelper.getItemTypeId('CCTV'),
            // Get proper item type ID
            'itemTypeRemark': 'CCTV Item',
            // Item type remark
            'latitude': '-122.084',
            // Default latitude
            'longitude': '37.4219983',
            // Default longitude
            'localAuditLogId': DateTime.now().millisecondsSinceEpoch,
            // Local audit log ID
            'syncProcessId': DateTime.now().millisecondsSinceEpoch,
            // Sync process ID
            'nexgenSerialNo': null,
            // No serial number for remarks
            'mfgSerialNo': null,
            // No manufacturer serial for remarks
            'qrCodeScannedTs': null,
            // No QR scan timestamp for remarks
            'assetStatus': 'OK',
            // Asset status
            'capacity': null,
            // No capacity for remarks
            'itemTypeGroup': 'CCTV',
            // Item type group
            'oemName': null,
            // No OEM name for remarks
            'imageName': null,
            // No image name for remarks
          };
          allItemsToPost.add(remarksData);
          print(
            'Surveillance Screen: Added user remarks to post with ID: $remarksAssetAuditSiteRespId, text: "${generalRemarksController.text}"',
          );
        } else {
          print(
            'Surveillance Screen: Could not find remarks ID from backend data',
          );
        }
      }

      if (allItemsToPost.isEmpty) {
        print('Surveillance Screen: No enhanced items to post');
        return false;
      }

      print(
        'Surveillance Screen: Enhanced items before conversion: $enhancedItems',
      );

      // Convert to POST request format
      final requests =
          await AssetAuditPostHelper.convertSavedItemsToPostRequest(
            savedItems: allItemsToPost,
            assetAuditData: widget.assetAuditData!,
            itemType: 'Surveillance',
            itemTypeId: AssetAuditPostHelper.getItemTypeId('Surveillance'),
            screenName: 'Surveillance',
            context: context,
          );

      if (requests.isEmpty) {
        print('Surveillance Screen: Failed to create POST requests');
        return false;
      }

      // Set flag BEFORE making the API call to ensure it's set when success state is received
      setState(() {
        _hasPostedSurveillanceData = true;
      });
      print(
        'Surveillance Screen: Set _hasPostedSurveillanceData flag to true BEFORE API call',
      );
      print(
        'Surveillance Screen: Flag value after setting: $_hasPostedSurveillanceData',
      );

      // Use the existing cubit to post data
      print('Surveillance Screen: Posting ${requests.length} items to API...');
      context.read<AssetAuditCubit>().postAssetAuditData(requests: requests);

      // Return true to indicate data is being posted
      return true;
    } catch (e) {
      print('Surveillance Screen: Error preparing data: $e');
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
      cctvStatus = item["assetStatus"]; // Use assetStatus instead of status
      cctvPhotoId = item["photoId"]; // Include photoId
      cctvSerialController.text = item["serialNumber"] ?? "";
      savedCCTVItems.remove(item);
      currentScannedItems--;
      cctvCardKey++;
      hasUnsavedChanges = true;
    });
  }

  // Edit a specific saved item from the list
  void _editSavedItem(Map<String, dynamic> item, String itemType) {
    setState(() {
      // Set editing flag
      isEditingItem = true;

      cctvSerialNumber = item["serialNumber"];
      cctvStatus = item["assetStatus"]; // Use assetStatus instead of status
      cctvPhotoId = item["photoId"]; // Include photoId
      cctvSerialController.text = item["serialNumber"] ?? "";

      // Handle photo data - check if it's base64 data or photo ID
      String? photoData = item["photo"];
      if (photoData != null && photoData.isNotEmpty) {
        if (photoData.startsWith('data:image/')) {
          // It's already base64 image data
          cctvPhoto = photoData;
        } else if (_isNumeric(photoData)) {
          // It's a photo ID, load the image
          _loadImageForEdit(photoData, 'cctv');
        } else {
          // It's a file path or other format
          cctvPhoto = photoData;
        }
      }

      // Also try to load image if photoId exists (fallback)
      if (cctvPhotoId != null &&
          cctvPhotoId.toString().isNotEmpty &&
          cctvPhoto == null) {
        _loadImageForEdit(cctvPhotoId.toString(), 'cctv');
      }

      savedCCTVItems.remove(item);
      currentScannedItems--;
      cctvCardKey++;
      hasUnsavedChanges = true;
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
        schId:
            widget.assetAuditData?.pageHeader.first.siteAuditSchId
                ?.toString() ??
            '',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AssetAuditGetImageCubit, AssetAuditGetImageState>(
      listener: (context, state) {
        if (state is AssetAuditGetImageSuccess) {
          // Handle successful image loading
          final imageData = state.imageData.startsWith('data:image/')
              ? state.imageData
              : 'data:image/jpeg;base64,${state.imageData}';

          setState(() {
            // Check if we're in edit mode
            if (_editingItemType != null) {
              // Update the appropriate photo variable based on editing item type
              if (_editingItemType == 'cctv') {
                cctvPhoto = imageData;
              }
              // Clear the editing item type after setState
              _editingItemType = null;
            }
          });
        } else if (state is AssetAuditGetImageFailure) {
          // Clear the editing item type on failure
          _editingItemType = null;
        }
      },
      child: BlocListener<AssetAuditCubit, AssetAuditState>(
        listener: (context, state) {
          print('Surveillance Screen: BlocListener received state: $state');
          print('Surveillance Screen: State type: ${state.runtimeType}');

          if (state is AssetAuditPostSuccess) {
            print('Surveillance Screen: AssetAuditPostSuccess received!');
            print('Surveillance Screen: State details: $state');
            print(
              'Surveillance Screen: _hasPostedSurveillanceData flag: $_hasPostedSurveillanceData',
            );

            // Check if this success state contains Surveillance-related items
            bool isSurveillanceData = false;
            print(
              'Surveillance Screen: Total responses received: ${state.responses.length}',
            );
            for (var response in state.responses) {
              print('Surveillance Screen: Full response object: $response');
              print(
                'Surveillance Screen: Checking response itemTypeRemark: ${response.itemTypeRemark}',
              );
              print(
                'Surveillance Screen: Checking response itemTypeId: ${response.itemTypeId}',
              );
              print(
                'Surveillance Screen: Checking response nexgenSerialNo: ${response.nexgenSerialNo}',
              );
              print(
                'Surveillance Screen: Checking response assetStatus: ${response.assetStatus}',
              );
              print(
                'Surveillance Screen: Checking response remarks: ${response.remarks}',
              );

              // Primary check: itemTypeRemark contains Surveillance-related text
              if (response.itemTypeRemark != null &&
                  (response.itemTypeRemark!.contains('CCTV') ||
                      response.itemTypeRemark!.contains('Surveillance') ||
                      response.itemTypeRemark!.contains('Camera'))) {
                isSurveillanceData = true;
                print(
                  'Surveillance Screen: Found Surveillance-related item by itemTypeRemark: ${response.itemTypeRemark}',
                );
                break;
              }

              // Fallback check: Check if this is a response to Surveillance screen data by looking at the flag
              if (_hasPostedSurveillanceData) {
                isSurveillanceData = true;
                print(
                  'Surveillance Screen: Found Surveillance-related item by flag check (fallback)',
                );
                break;
              }

              print(
                'Surveillance Screen: itemTypeRemark "${response.itemTypeRemark}" does not match Surveillance patterns',
              );
            }

            // Only process this success state if it contains Surveillance screen data
            if (isSurveillanceData) {
              print('Surveillance Screen: Refreshing data from API...');
              try {
                // Trigger a refresh of the asset audit data
                context.read<AssetAuditCubit>().getAssetAuditData(
                  siteType:
                      widget.assetAuditData?.pageHeader.first.siteDomainName ??
                      "",
                  auditSchId:
                      widget.assetAuditData?.pageHeader.first.siteAuditSchId
                          .toString() ??
                      "",
                  siteAuditSchId:
                      widget.assetAuditData?.pageHeader.first.siteAuditSchId
                          .toString() ??
                      "",
                );

                // Navigate immediately after data refresh
                print(
                  'Surveillance Screen: Data refreshed, navigating to next screen...',
                );
                pushPage(
                  context,
                  FencingScreen(
                    fencingData: widget
                        .assetAuditData
                        ?.responseData
                        .categories['Boundary'],
                    // Use categories['Boundary'] for fencing data
                    assetAuditData: widget.assetAuditData,
                    showSuccessMessage: false,
                    // Don't show success message when skipping surveillance screen
                    extinguisherItems: widget.extinguisherItems ?? [],
                    solarPlatesItems: widget.solarPlatesItems ?? [],
                    surveillanceItems: [...savedCCTVItems],
                  ),
                );

                // Reset the flag after successful navigation
                setState(() {
                  _hasPostedSurveillanceData = false;
                });
                print(
                  'Surveillance Screen: Reset _hasPostedSurveillanceData flag to false after navigation',
                );
              } catch (e) {
                print('Surveillance Screen: Error refreshing data: $e');
                // Fallback: navigate anyway after delay
                Future.delayed(const Duration(seconds: 2), () {
                  if (mounted) {
                    pushPage(
                      context,
                      FencingScreen(
                        fencingData: widget
                            .assetAuditData
                            ?.responseData
                            .categories['Boundary'],
                        assetAuditData: widget.assetAuditData,
                        showSuccessMessage: false,
                        extinguisherItems: widget.extinguisherItems ?? [],
                        solarPlatesItems: widget.solarPlatesItems ?? [],
                        surveillanceItems: [...savedCCTVItems],
                      ),
                    );
                    setState(() {
                      _hasPostedSurveillanceData = false;
                    });
                  }
                });
              }
            } else {
              print(
                'Surveillance Screen: Success state received but not for Surveillance screen data, ignoring...',
              );
              print(
                'Surveillance Screen: _hasPostedSurveillanceData flag: $_hasPostedSurveillanceData',
              );
            }
          } else if (state is AssetAuditPostError) {
            // Only show error message if this error belongs to Surveillance screen data
            if (_hasPostedSurveillanceData) {
              print(
                'Surveillance Screen: AssetAuditPostError received for Surveillance data',
              );

              // Reset the flag on error
              setState(() {
                _hasPostedSurveillanceData = false;
              });
              print(
                'Surveillance Screen: Reset _hasPostedSurveillanceData flag to false after error',
              );
            } else {
              print(
                'Surveillance Screen: AssetAuditPostError received but not for Surveillance data, ignoring...',
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
                  onSaveAndExit: () async {
                    await _saveAndExit();
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
                      onSaveAndExit: () async {
                        await _saveAndExit();
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
                                  MediaQuery.of(context).viewInsets.bottom +
                                  120,
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
                                      label: "Hooter Available (Yes/No)",
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
                                    CustomOptionSelector(
                                      label: "CCTV Available (Yes/No)",
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
                                    CustomFormField(
                                      label: "Count of CCTV",
                                      initialValue: totalCCTVItems.toString(),
                                      isRequired: false,
                                      isEditable: false,
                                      onChanged: (value) {
                                        setState(() {
                                          totalCCTVItems =
                                              int.tryParse(value) ?? 6;
                                          hasUnsavedChanges = true;
                                        });
                                      },
                                    ),
                                    getHeight(15),
                                    CustomInfoCard(
                                      key: ValueKey('cctv_$cctvCardKey'),
                                      serialLabel: "CCTV - Serial Number *",
                                      serialHintText: "CCTV Serial Number",
                                      photoLabel: "Add a Photo",
                                      statusLabel: "Status",
                                      serialController: cctvSerialController,
                                      onSave: _saveCCTVForm,
                                      isStatusEditable: true,
                                      backendStatus: false,
                                      onPhotoTap: (photoPath) async {
                                        setState(() {
                                          cctvPhoto = photoPath;
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
                                                  cctvPhotoId = photoId;
                                                });
                                                print(
                                                  'Surveillance Screen: Photo uploaded successfully, photoId: $photoId',
                                                );
                                              }
                                            }
                                          } catch (e) {
                                            print(
                                              'Surveillance Screen: Error uploading photo: $e',
                                            );
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
                                          final isValid = _validateSerialNumber(
                                            serialNumber,
                                            false,
                                          );
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
                                          : (cctvStatus == "Not OK"
                                                ? false
                                                : null),
                                      initialPhotoPath: cctvPhoto,
                                      isEditable: true,
                                    ),
                                    getHeight(8),
                                    _buildCCTVSavedItemsList(),
                                    getHeight(15),
                                    // CustomRemarksField(
                                    //   label: "Add Remarks",
                                    //   hintText: "Remarks",
                                    //   controller: generalRemarksController,
                                    // ),
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
                                  text: "Solar Panel",
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
                                  text: _hasDataToShow() ? "Fencing" : "Skip",
                                  isLeftArrow: false,
                                  backgroundColor: AppColors.buttonColorBg,
                                  textColor: AppColors.buttonColorSite,
                                  onPressed: () async {
                                    // If no data to show, just navigate to next screen
                                    if (!_hasDataToShow()) {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => FencingScreen(
                                            fencingData: widget
                                                .assetAuditData
                                                ?.responseData
                                                .categories['Boundary'],
                                            assetAuditData:
                                                widget.assetAuditData,
                                            showSuccessMessage: false,
                                            extinguisherItems:
                                                widget.extinguisherItems ?? [],
                                            solarPlatesItems:
                                                widget.solarPlatesItems ?? [],
                                            surveillanceItems: [],
                                          ),
                                        ),
                                      );
                                      return;
                                    }

                                    // If there are saved items, try to post them first
                                    if (savedCCTVItems.isNotEmpty) {
                                      try {
                                        print(
                                          'Surveillance Screen: Attempting to post data before navigation...',
                                        );

                                        // Set a timeout for the posting operation
                                        await Future.any([
                                          _postCurrentScreenData(),
                                          Future.delayed(
                                            Duration(seconds: 10),
                                            () {
                                              throw TimeoutException(
                                                'Posting data timed out',
                                                Duration(seconds: 10),
                                              );
                                            },
                                          ),
                                        ]);

                                        // Navigation will be handled by the BlocListener on success
                                      } catch (e) {
                                        print(
                                          'Surveillance Screen: Error posting data: $e',
                                        );

                                        _navigateToNextScreen();
                                      }
                                    } else {
                                      // No saved items, navigate directly
                                      _navigateToNextScreen();
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
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
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
          if (savedCCTVItems.isNotEmpty)
            ..._getItemsWithPhotoAndStatus(savedCCTVItems)
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
                              onPressed: () => _editSavedItem(item, 'cctv'),
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
}
