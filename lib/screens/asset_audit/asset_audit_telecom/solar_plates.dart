import 'package:app/commonWidgets/custom_buttons/arrow_botton.dart';
import 'package:app/constants/constants_methods.dart';
import 'package:app/screens/asset_audit/asset_audit_telecom/survelliance_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';
import '../../../models/asset_audit_model.dart';
import '../../../models/asset_audit_post_model.dart';
import '../../../utils/asset_audit_post_helper.dart';
import '../../../utils/asset_audit_photo_upload_helper.dart';
import '../../../bloc/asset_audit_cubit.dart';
import '../../../bloc/asset_audit_state.dart';
import 'dart:io';

import '../../../commonWidgets/asset_type_card.dart';
import '../../../commonWidgets/custom_dialogs/success_dialog.dart';
import '../../../commonWidgets/custom_dialogs/unsaved_changes_dialog.dart';
import '../../../commonWidgets/custom_form_appbar.dart';
import '../../../commonWidgets/custom_form_field.dart';
import '../../../commonWidgets/custom_remark.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_images.dart';
import '../../../constants/constants_strings.dart';

class SolarPlatesScreen extends StatefulWidget {
  final CategoryData? solarPlatesData;
  final AssetAuditModel? assetAuditData;
  final bool showSuccessMessage; // Flag to show success message
  
  // Data from previous screens in the flow
  final List<Map<String, dynamic>>? extinguisherItems;

  const SolarPlatesScreen({
    super.key,
    this.solarPlatesData,
    this.assetAuditData,
    this.showSuccessMessage = false, // Default to false
    this.extinguisherItems,
  });

  @override
  State<SolarPlatesScreen> createState() => _SolarPlatesScreenState();
}

class _SolarPlatesScreenState extends State<SolarPlatesScreen> {
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
  final solarPanelCapacityController = TextEditingController(); // Read-only controller for capacity

  // AssetTypeCard field values for MPPT
  String? mpptSerialNumber;
  String? mpptPhoto;
  int? mpptPhotoId; // Store the photoId from API
  String? mpptStatus;

  // Controllers for CustomInfoCard
  final TextEditingController rectifierSerialController =
      TextEditingController();
  final TextEditingController mpptSerialController = TextEditingController();

  // Keys to force rebuild of CustomInfoCard widgets
  int rectifierCardKey = 0;
  int mpptCardKey = 0;
  
  // Flag to track if Solar Plates screen has posted data
  bool _hasPostedSolarPlatesData = false;

  // Method to get OEM name from API data
  String _getSolarPlatesOEMName() {
    if (widget.solarPlatesData != null) {
      // Try to get OEM name from Solar Plates assets
      final solarPlatesAssets = widget.solarPlatesData!.assets;
      if (solarPlatesAssets.isNotEmpty) {
        return solarPlatesAssets.first.oemName ?? 'Delta';
      }
    }
    return 'Delta'; // Default fallback
  }

  /// Check if there is data to show on the screen
  bool _hasDataToShow() {
    if (widget.solarPlatesData == null) {
      print('Solar Plates Screen: No solar plates data available');
      return false;
    }
    
    // Check if we have any assets
    final hasAssets = widget.solarPlatesData!.assets.isNotEmpty;
    
    // Check if we have any subcategories with data
    final hasSubCategories = widget.solarPlatesData!.subCategories != null && 
        widget.solarPlatesData!.subCategories!.values.any((items) => items.isNotEmpty);
    
    final hasData = hasAssets || hasSubCategories;
    
    print('Solar Plates Screen: Data availability check:');
    print('  - Assets: $hasAssets (${widget.solarPlatesData!.assets.length})');
    print('  - Subcategories: $hasSubCategories');
    print('  - Has data to show: $hasData');
    
    return hasData;
  }

  void _navigateToSurveillanceScreen() {
    print('Solar Plates Screen: Navigating to Surveillance screen');
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => SurveillianceScreen(
          cctvData: widget.assetAuditData?.responseData.cctv,
          assetAuditData: widget.assetAuditData,
          showSuccessMessage: false, // Don't show success message when skipping solar plates screen
          solarPlatesItems: [],
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
            'No Solar Plates Data Available',
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
            'There are no Solar Panel or Solar Inverter items to audit for this site.',
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

  /// Get asset audit site response ID from GET API response for a specific item type
  int? _getAssetAuditSiteRespId(String itemType) {
    if (widget.solarPlatesData != null) {
      // Debug: Print available data
      print('=== Solar Plates: Getting AssetAuditSiteRespId for $itemType ===');
      print('Available assets: ${widget.solarPlatesData!.assets.length}');
      widget.solarPlatesData!.assets.forEach((asset) {
        print('  Asset: ${asset.itemType} - ID: ${asset.assetAuditSiteRespId} - Serial: ${asset.nexgenSerialNo}');
      });
      
      // Look for Solar Plates assets (the actual item_type from API is "Solar Plates")
      final solarPlatesAssets = widget.solarPlatesData!.assets;
      if (solarPlatesAssets.isNotEmpty) {
        // For both Solar Panel and Solar Inverter, use the same Solar Plates assets
        // since the API provides "Solar Plates" as the item_type
        return solarPlatesAssets.first.assetAuditSiteRespId;
      }
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    // Listen to form changes
    serialController.addListener(_onFormChanged);
    
    // Check if we have data to show, if not, skip this screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_hasDataToShow()) {
        print('Solar Plates Screen: No data to show, skipping to Surveillance screen');
        _navigateToSurveillanceScreen();
      } else {
        // Show success message if coming from Extinguisher Screen
        if (widget.showSuccessMessage) {
          showCustomToast(context, '✅ Extinguisher data saved successfully!');
        }

        // Pre-fill capacity field with data from API
        solarPanelCapacityController.text = _getSolarPanelCapacity();

        // Load Solar Plates data if available
        _loadSolarPlatesData();
      }
    });
  }

  void _loadSolarPlatesData() {
    if (widget.solarPlatesData != null) {
      setState(() {
        // Load Solar Plates assets data
        final solarPlatesAssets = widget.solarPlatesData!.assets;
        if (solarPlatesAssets.isNotEmpty) {
          // Process Solar Plates assets for count only
          for (var item in solarPlatesAssets) {
            print(
              'Solar Plates Asset Item: ${item.itemType} - ${item.nexgenSerialNo}',
            );
          }
        }

        // Load remarks and populate the CustomRemarksField
        final remarks = widget.solarPlatesData!.remarks;
        if (remarks.isNotEmpty) {
          // Process remarks and populate the CustomRemarksField
          for (var remark in remarks) {
            print(
              'Solar Plates Remark: ${remark.itemType} - ${remark.itemTypeRemark}',
            );
            
            // Populate the CustomRemarksField with the first valid remark
            if (remark.itemTypeRemark != null &&
                remark.itemTypeRemark!.isNotEmpty) {
              generalRemarksController.text = remark.itemTypeRemark!;
              print('Solar Plates Screen: Loaded remark from API: ${remark.itemTypeRemark}');
              break; // Use the first valid remark
            }
          }
        }
        
        // Load saved items from API - only items with complete data
        _loadSavedItemsFromAPI();

        // Update total count based on actual data (but don't pre-populate saved items)
        totalRectifierItems =
            solarPlatesAssets.length; // Only solar plates assets for count

        print(
          'Solar Plates Data loaded: Total expected items: $totalRectifierItems',
        );
        print('Solar Plates Assets: ${solarPlatesAssets.length}');
      });
    }
  }

  /// Load saved items from API - only items with complete data (serial, photo, status)
  void _loadSavedItemsFromAPI() {
    if (widget.solarPlatesData == null) {
      print('Solar Plates Screen: No solar plates data available');
      return;
    }

    print('Solar Plates Screen: Loading saved items from API...');
    
    setState(() {
      // Clear existing saved items to avoid duplicates
      savedRectifierItems.clear();
      savedMPPTItems.clear();
      currentScannedItems = 0;

      // Load Solar Plates assets (from assets array)
      final solarPlatesAssets = widget.solarPlatesData!.assets;
      print('Solar Plates Screen: Found ${solarPlatesAssets.length} Solar Plates assets');
      
      for (var item in solarPlatesAssets) {
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
            'itemType': item.itemType ?? 'Solar Plates',
            'remarks': item.itemTypeRemark ?? 'Solar Plates Item',
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
          print('Solar Plates Screen: Added Solar Plates item: ${savedItem['serialNumber']}');
        }
      }

      print('Solar Plates Screen: Loaded ${savedRectifierItems.length} Solar Plates items');
      print('Solar Plates Screen: Current scanned items: $currentScannedItems');
    });
  }

  @override
  void dispose() {
    serialController.removeListener(_onFormChanged);
    serialController.dispose();
    rectifierSerialController.dispose();
    mpptSerialController.dispose();
    rectifierRemarksController.dispose();
    mpptRemarksController.dispose();
    generalRemarksController.dispose();
    solarPanelCapacityController.dispose();
    super.dispose();
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
      print('Serial number validation passed');
    }

    // Check if photo is added
    // Check both photo variables to see which one has data
    String? photo = rectifierPhoto ?? mpptPhoto;
    print('Photo: $photo');
    if (photo == null || photo.isEmpty) {
      print(' Photo validation failed');
      return false;
    } else {
      print('Photo validation passed');
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
          'photoTakenTs': DateTime.now().toString(),
          'itemType': 'Solar Panel',
          'remarks': rectifierRemarksController.text.isNotEmpty ? rectifierRemarksController.text : 'Solar Panel Item',
          'assetStatus': rectifierStatus ?? "OK",
          'assetAuditSiteRespId': _getAssetAuditSiteRespId('Solar Panel'),
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
          'photoTakenTs': DateTime.now().toString(),
          'itemType': 'Solar Inverter',
          'remarks': mpptRemarksController.text.isNotEmpty ? mpptRemarksController.text : 'Solar Inverter Item',
          'assetStatus': mpptStatus ?? "OK",
          'assetAuditSiteRespId': _getAssetAuditSiteRespId('Solar Inverter'),
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

  // Check if all items are scanned (for display purposes only)
  bool _isAllItemsScanned() {
    return (savedRectifierItems.length >= totalRectifierItems) &&
        (savedMPPTItems.length >= totalMPPTItems);
  }

  // Check if user can proceed to next screen (minimum 1 item required)
  bool _canProceedToNextScreen() {
    return savedRectifierItems.length > 0;
  }

  // Method to get Solar Panel capacity from API data
  String _getSolarPanelCapacity() {
    if (widget.solarPlatesData != null) {
      final solarAssets = widget.solarPlatesData!.assets ?? [];
      if (solarAssets.isNotEmpty) {
        return solarAssets.first.capacity ?? '5 KW';
      }
    }
    return '5 KW'; // Default fallback
  }

  /// Validate serial number against API data
  /// Returns true if valid, false if invalid
  bool _validateSerialNumber(String serialNumber, bool isQRCodeScanned) {
    if (widget.solarPlatesData == null) return false;

    if (isQRCodeScanned) {
      // For QR code scans, validate against nexgen_serial_no
      final allItems = widget.solarPlatesData!.assets ?? [];

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
      final allItems = widget.solarPlatesData!.assets ?? [];

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

  int? _getRemarksAssetAuditSiteRespId() {
    print('=== Solar Plates Screen: Getting Remarks AssetAuditSiteRespId ===');
    
    if (widget.solarPlatesData == null) {
      print('solarPlatesData is null, cannot get remarks ID');
      return null;
    }
    
    // Check if there are remarks in the backend data
    final remarks = widget.solarPlatesData!.remarks;
    if (remarks.isNotEmpty) {
      print('Found ${remarks.length} remarks in backend data');
      
      // First try to find a general remarks entry (Solar Plates category is usually the main one)
      for (var remark in remarks) {
        if (remark.assetAuditSiteRespId != null && 
            remark.assetAuditSiteRespId > 0 && 
            remark.itemType == 'Solar Plates') {
          print('Using Solar Plates remarks ID: ${remark.assetAuditSiteRespId}');
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
      print('Solar Plates Screen: No asset audit data available for posting');
      return false;
    }

    try {
      // Create a list to hold all items to post
      List<Map<String, dynamic>> allItemsToPost = [];

      // Enhance saved items with additional data
      final enhancedItems = AssetAuditPostHelper.enhanceSavedItems(
        savedItems: savedRectifierItems,
        screenName: 'Solar Plates',
      );
      allItemsToPost.addAll(enhancedItems);

      // Add user's general remarks if entered
      if (generalRemarksController.text.isNotEmpty) {
        // Find the appropriate remarks entry from backend data
        int? remarksAssetAuditSiteRespId = _getRemarksAssetAuditSiteRespId();
        
        if (remarksAssetAuditSiteRespId != null) {
          Map<String, dynamic> remarksData = {
            'itemType': 'Solar Plates', // Use the main screen category
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
          print('Solar Plates Screen: Added user remarks to post with ID: $remarksAssetAuditSiteRespId, text: "${generalRemarksController.text}"');
        } else {
          print('Solar Plates Screen: Could not find remarks ID from backend data');
        }
      }

      if (allItemsToPost.isEmpty) {
        print('Solar Plates Screen: No items to post');
        return false;
      }

      // Convert to POST request format
      final requests =
          await AssetAuditPostHelper.convertSavedItemsToPostRequest(
            savedItems: allItemsToPost,
            assetAuditData: widget.assetAuditData!,
            itemType: 'Solar Plates',
            itemTypeId: AssetAuditPostHelper.getItemTypeId('Solar Plates'),
            screenName: 'Solar Plates',
            context: context,
          );

      if (requests.isEmpty) {
        print('Solar Plates Screen: Failed to create POST requests');
        return false;
      }

      // Set flag BEFORE making the API call to ensure it's set when success state is received
      setState(() {
        _hasPostedSolarPlatesData = true;
      });
      print('Solar Plates Screen: Set _hasPostedSolarPlatesData flag to true BEFORE API call');
      print('Solar Plates Screen: Flag value after setting: $_hasPostedSolarPlatesData');
      
      // Use the existing cubit to post data
      print('Solar Plates Screen: Posting ${requests.length} items to API...');
      context.read<AssetAuditCubit>().postAssetAuditData(requests: requests);

      // Return true to indicate data is being posted
      return true;
    } catch (e) {
      print('Solar Plates Screen: Error preparing data: $e');
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
      mpptStatus = item["status"];

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

  /// Edit a saved item based on its type
  void _editSavedItem(Map<String, dynamic> item, String itemType) {
    // Debug: Print the item data to see what's actually stored
    print('=== EDITING $itemType ITEM ===');
    print('Item data: $item');
    print('Serial Number: ${item['serialNumber']}');
    print('Status: ${item['status']}');
    print('Photo: ${item['photo']}');
    print('Photo ID: ${item['photoId']}');
    print('=============================');
    
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
          
          // Debug: Print what we're setting
          print('Setting rectifier form:');
          print('  - Controller text: ${rectifierSerialController.text}');
          print('  - Serial Number: $rectifierSerialNumber');
          print('  - Status: $rectifierStatus');
          print('  - Photo: $rectifierPhoto');
          print('  - Photo ID: $rectifierPhotoId');
          
          // Remove the item from saved list since it's now in the form for editing
          savedRectifierItems.remove(item);
          currentScannedItems--;
          break;
          
        case 'mppt':
          // Populate MPPT form with item data
          mpptSerialController.text = item['serialNumber'] ?? '';
          mpptSerialNumber = item['serialNumber'] ?? ''; // Also set the variable
          mpptStatus = item['status'] ?? 'OK';
          mpptPhotoId = item['photoId'];
          mpptPhoto = item['photo'];
          
          // Debug: Print what we're setting
          print('Setting MPPT form:');
          print('  - Controller text: ${mpptSerialController.text}');
          print('  - Serial Number: $mpptSerialNumber');
          print('  - Status: $mpptStatus');
          print('  - Photo: $mpptPhoto');
          print('  - Photo ID: $mpptPhotoId');
          
          // Remove the item from saved list since it's now in the form for editing
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

  @override
  Widget build(BuildContext context) {
    return BlocListener<AssetAuditCubit, AssetAuditState>(
      listener: (context, state) {
        print('Solar Plates Screen: BlocListener received state: $state');
        print('Solar Plates Screen: State type: ${state.runtimeType}');
        
        if (state is AssetAuditPostSuccess) {
          print('Solar Plates Screen: AssetAuditPostSuccess received!');
          print('Solar Plates Screen: State details: $state');
          print('Solar Plates Screen: _hasPostedSolarPlatesData flag: $_hasPostedSolarPlatesData');
          
          // Check if this success state contains Solar Plates-related items
          bool isSolarPlatesData = false;
          print('Solar Plates Screen: Total responses received: ${state.responses.length}');
          for (var response in state.responses) {
            print('Solar Plates Screen: Full response object: $response');
            print('Solar Plates Screen: Checking response itemTypeRemark: ${response.itemTypeRemark}');
            print('Solar Plates Screen: Checking response itemTypeId: ${response.itemTypeId}');
            print('Solar Plates Screen: Checking response nexgenSerialNo: ${response.nexgenSerialNo}');
            print('Solar Plates Screen: Checking response assetStatus: ${response.assetStatus}');
            print('Solar Plates Screen: Checking response remarks: ${response.remarks}');
            
            // Primary check: itemTypeRemark contains Solar Plates-related text
            if (response.itemTypeRemark != null && 
                (response.itemTypeRemark!.contains('Solar Panel') || 
                 response.itemTypeRemark!.contains('Solar Inverter') ||
                 response.itemTypeRemark!.contains('Solar'))) {
              isSolarPlatesData = true;
              print('Solar Plates Screen: Found Solar Plates-related item by itemTypeRemark: ${response.itemTypeRemark}');
              break;
            }
            
            // Fallback check: Check if this is a response to Solar Plates screen data by looking at the flag
            if (_hasPostedSolarPlatesData) {
              isSolarPlatesData = true;
              print('Solar Plates Screen: Found Solar Plates-related item by flag check (fallback)');
              break;
            }
            
            print('Solar Plates Screen: itemTypeRemark "${response.itemTypeRemark}" does not match Solar Plates patterns');
          }
          
          // Only process this success state if it contains Solar Plates screen data
          if (isSolarPlatesData) {
            print('Solar Plates Screen: Confirmed this is Solar Plates screen data, proceeding with data refresh...');
            
            // Show success message
            showCustomToast(context, '✅ Solar Plates data saved successfully!');

            // Refresh data from API before navigating
            print('Solar Plates Screen: Refreshing data from API...');
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
                  print('Solar Plates Screen: Data refreshed, navigating to next screen...');
                  pushPage(
                    context,
                    SurveillianceScreen(
                      cctvData: widget.assetAuditData?.responseData.cctv,
                      assetAuditData: widget.assetAuditData,
                      showSuccessMessage: false, // Don't show success message when skipping solar plates screen
                      extinguisherItems: widget.extinguisherItems ?? [],
                      solarPlatesItems: [
                        ...savedRectifierItems,
                        ...savedMPPTItems,
                      ],
                    ),
                  );
                  
                  // Reset the flag after successful navigation
                  setState(() {
                    _hasPostedSolarPlatesData = false;
                  });
                  print('Solar Plates Screen: Reset _hasPostedSolarPlatesData flag to false after navigation');
                }
              });
            } catch (e) {
              print('Solar Plates Screen: Error refreshing data: $e');
              // Fallback: navigate anyway after delay
              Future.delayed(const Duration(seconds: 2), () {
                if (mounted) {
                  pushPage(
                    context,
                    SurveillianceScreen(
                      cctvData: widget.assetAuditData?.responseData.cctv,
                      assetAuditData: widget.assetAuditData,
                      showSuccessMessage: false,
                      extinguisherItems: widget.extinguisherItems ?? [],
                      solarPlatesItems: [
                        ...savedRectifierItems,
                        ...savedMPPTItems,
                      ],
                    ),
                  );
                  setState(() {
                    _hasPostedSolarPlatesData = false;
                  });
                }
              });
            }
          } else {
            print('Solar Plates Screen: Success state received but not for Solar Plates screen data, ignoring...');
            print('Solar Plates Screen: _hasPostedSolarPlatesData flag: $_hasPostedSolarPlatesData');
          }
        } else if (state is AssetAuditPostError) {
          // Only show error message if this error belongs to Solar Plates screen data
          if (_hasPostedSolarPlatesData) {
            print('Solar Plates Screen: AssetAuditPostError received for Solar Plates data');
            // Show error message and block navigation
            showCustomToast(
              context,
              '❌ Failed to save Solar Plates data. Please try again.',
            );
            
            // Reset the flag on error
            setState(() {
              _hasPostedSolarPlatesData = false;
            });
            print('Solar Plates Screen: Reset _hasPostedSolarPlatesData flag to false after error');
          } else {
            print('Solar Plates Screen: AssetAuditPostError received but not for Solar Plates data, ignoring...');
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
                                  CustomFormField(
                                    label: "Solar Panel Make",
                                    initialValue: _getSolarPlatesOEMName(),
                                    isRequired: false,
                                    isEditable: false,
                                  ),
                                getHeight(15),
                                CustomFormField(
                                  label: "Count of Solar Panel",
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
                                CustomFormField(
                                  label: "Type of Solar Panel ",
                                  initialValue: "Mono",
                                  isRequired: false,
                                  isEditable: false,
                                ),

                                getHeight(15),
                                CustomInfoCard(
                                  key: ValueKey('rectifier_$rectifierCardKey'),
                                  serialLabel: "Solar Panel - Serial Number",
                                  serialHintText: "Solar Panel Serial Number",
                                  photoLabel: "Add a Photo",
                                  statusLabel: "Status",
                                  serialController: rectifierSerialController,
                                  onSave: _saveRectifierForm,
                                  isStatusEditable: true,
                                  backendStatus: false,
                                  remarksLabel: "Solar Panel (Watt)",
                                  remarksHintText: "Eg: 5",
                                  remarksController: solarPanelCapacityController,
                                  isRemarksEditable: false, // Make capacity non-editable
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
                                              'Solar Plates Screen: Photo uploaded successfully, photoId: $photoId',
                                            );
                                          }
                                        }
                                      } catch (e) {
                                        print(
                                          'Solar Plates Screen: Error uploading photo: $e',
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
                                  },
                                  initialStatus: rectifierStatus == "OK"
                                      ? true
                                      : (rectifierStatus == "Not OK"
                                            ? false
                                            : null),
                                  initialPhotoPath: rectifierPhoto,
                                  isEditable: true,
                                ),

                                getHeight(8),
                                _buildRectifierSavedItemsList(),
                                getHeight(15),
                                CustomFormField(
                                  label: "Total Capacity of Solar (Kwatt)",
                                  initialValue: "20 KW",
                                  isRequired: false,
                                  isEditable: false,
                                ),
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
                                text: "Extinguisher",
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
                                text: _hasDataToShow() ? "Surveillance" : "Skip",
                                isLeftArrow: false,
                                backgroundColor: AppColors.buttonColorBg,
                                textColor: AppColors.buttonColorSite,
                                onPressed: () async {
                                  // If no data to show, just navigate to next screen
                                  if (!_hasDataToShow()) {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => SurveillianceScreen(
                                          cctvData: widget.assetAuditData?.responseData.cctv,
                                          assetAuditData: widget.assetAuditData,
                                          showSuccessMessage: false,
                                          solarPlatesItems: [],
                                        ),
                                      ),
                                    );
                                    return;
                                  }
                                  
                                  // Navigate to next screen with accumulated data
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => SurveillianceScreen(
                                        cctvData: widget.assetAuditData?.responseData.cctv,
                                        assetAuditData: widget.assetAuditData,
                                        showSuccessMessage: false,
                                        solarPlatesItems: [
                                          ...savedRectifierItems,
                                          ...savedMPPTItems,
                                        ],
                                      ),
                                    ),
                                  );
                                  // if (_validateForm()) {
                                  //   showDialog(
                                  //     context: context,
                                  //     barrierDismissible: false,
                                  //     builder: (context) => SuccessDialog(
                                  //       ticketId: "UVORKJR00044",
                                  //       message:
                                  //       "Asset Audit for Site (ID: SITE-38974) has been recorded and saved.",
                                  //       onDone: () {
                                  //         Navigator.of(context).pop();
                                  //         Navigator.of(context).pop();
                                  //       },
                                  //     ),
                                  //   );
                                  // } else {
                                  //
                                  //   ScaffoldMessenger.of(context).showSnackBar(
                                  //     SnackBar(
                                  //       content: Text(
                                  //         uploadedPhotoPath == null || uploadedPhotoPath!.isEmpty
                                  //             ? 'Please upload a selfie photo to continue'
                                  //             : 'Please fill in all required fields',
                                  //         style: const TextStyle(
                                  //           color: Colors.white,
                                  //           fontSize: 14,
                                  //           fontFamily: fontFamilyMontserrat,
                                  //         ),
                                  //       ),
                                  //       backgroundColor: AppColors.errorColor,
                                  //       duration: const Duration(seconds: 3),
                                  //     ),
                                  //   );
                                  // }
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
                            child: item['photo'] != null || item['photoId'] != null
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
          if (savedMPPTItems.isNotEmpty)
            ...savedMPPTItems
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
                            child: item['photo'] != null || item['photoId'] != null
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
                        SizedBox(
                          width: 50,
                          child: IconButton(
                            onPressed: () => _editSavedItem(item, 'mppt'),
                            icon: const Icon(
                              Icons.edit,
                              color: AppColors.blue,
                              size: 20,
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
