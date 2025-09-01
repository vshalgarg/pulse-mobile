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
import 'dart:io';

import '../../../commonWidgets/asset_type_card.dart';
import '../../../commonWidgets/custom_dialogs/success_dialog.dart';
import '../../../commonWidgets/custom_dialogs/unsaved_changes_dialog.dart';
import '../../../commonWidgets/custom_form_appbar.dart';
import '../../../commonWidgets/custom_form_field.dart';
import '../../../commonWidgets/custom_radio_options.dart';
import '../../../commonWidgets/custom_remark.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_images.dart';
import '../../../constants/constants_strings.dart';

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
  final cctvCapacityController = TextEditingController(); // Read-only controller for capacity

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

  @override
  void initState() {
    super.initState();
    serialController.addListener(_onFormChanged);

    // Check if we have data to show, if not, skip this screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_hasDataToShow()) {
        print('Surveillance Screen: No data to show, skipping to Fencing screen');
        _navigateToFencingScreen();
      } else {
        // Pre-fill capacity field with data from API
        cctvCapacityController.text = _getCCTVCapacity();

        // Load CCTV data if available
        _loadCCTVData();
        
        // Show success message if coming from Solar Plates Screen
        if (widget.showSuccessMessage) {
          showCustomToast(context, '✅ Solar Plates data saved successfully!');
        }
        
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
    final hasSubCategories = widget.cctvData!.subCategories != null && 
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
          fencingData: widget.assetAuditData?.responseData.boundary,
          assetAuditData: widget.assetAuditData,
          showSuccessMessage: false, // Don't show success message when skipping surveillance screen
          extinguisherItems: widget.extinguisherItems ?? [],
          solarPlatesItems: widget.solarPlatesItems ?? [],
          surveillanceItems: [],
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
        print('cctvAssets: $cctvAssets');
        print('cctvAssets length: ${cctvAssets.length}');
        
        if (cctvAssets.isNotEmpty) {
          // Process CCTV assets for count only
          for (int i = 0; i < cctvAssets.length; i++) {
            var item = cctvAssets[i];
            print('CCTV Asset Item $i:');
            print('  - itemType: ${item.itemType}');
            print('  - itemTypeRemark: ${item.itemTypeRemark}');
            print('  - nexgenSerialNo: ${item.nexgenSerialNo}');
            print('  - mfgSerialNo: ${item.mfgSerialNo}');
            print('  - capacity: ${item.capacity}');
            print('  - itemTypeGroup: ${item.itemTypeGroup}');
            print('  - assetAuditSiteRespId: ${item.assetAuditSiteRespId}');
          }
        } else {
          print('No CCTV assets found in CategoryData.assets');
        }

        // Check if there are subcategories
        if (widget.cctvData!.subCategories != null) {
          print('Checking subcategories...');
          widget.cctvData!.subCategories!.forEach((key, items) {
            print('Subcategory $key: ${items.length} items');
            if (items.isNotEmpty) {
              var firstItem = items.first;
              print('First item in $key:');
              print('  - itemType: ${firstItem.itemType}');
              print('  - assetAuditSiteRespId: ${firstItem.assetAuditSiteRespId}');
            }
          });
        } else {
          print('No subcategories found');
        }

        // Load remarks and populate the CustomRemarksField
        final remarks = widget.cctvData!.remarks;
        print('cctvRemarks: $remarks');
        print('cctvRemarks length: ${remarks.length}');
        
        if (remarks.isNotEmpty) {
          // Process remarks and populate the CustomRemarksField
          for (int i = 0; i < remarks.length; i++) {
            var remark = remarks[i];
            print('CCTV Remark $i:');
            print('  - itemType: ${remark.itemType}');
            print('  - recordType: ${remark.recordType}');
            print('  - assetAuditSiteRespId: ${remark.assetAuditSiteRespId}');
            
            // Populate the CustomRemarksField with the first valid remark
            if (remark.itemTypeRemark != null &&
                remark.itemTypeRemark!.isNotEmpty) {
              generalRemarksController.text = remark.itemTypeRemark!;
              print('Surveillance Screen: Loaded remark from API: ${remark.itemTypeRemark}');
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
      
      print('Surveillance Screen: Found ${cctvAssets.length} CCTV assets in main array');
      
      // Also check subcategories for CCTV items
      if (subCategories != null) {
        print('Surveillance Screen: Checking subcategories for CCTV items...');
        subCategories.forEach((key, items) {
          print('Surveillance Screen: Subcategory $key has ${items.length} items');
          if (items.isNotEmpty) {
            var firstItem = items.first;
            print('Surveillance Screen: First item in $key:');
            print('  - mfgSerialNo: ${firstItem.mfgSerialNo}');
            print('  - photoId: ${firstItem.photoId}');
            print('  - assetStatus: ${firstItem.assetStatus}');
          }
        });
      }
      
      // Debug: Print each item's data to see what's available
      for (int i = 0; i < cctvAssets.length; i++) {
        var item = cctvAssets[i];
        print('Surveillance Screen: Item $i:');
        print('  - mfgSerialNo: ${item.mfgSerialNo}');
        print('  - photoId: ${item.photoId}');
        print('  - assetStatus: ${item.assetStatus}');
        print('  - Has complete data: ${item.mfgSerialNo != null && item.photoId != null && item.assetStatus != null}');
      }
      
      // Process items from main assets array
      for (var item in cctvAssets) {
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
          print('Surveillance Screen: Added CCTV item: ${savedItem['serialNumber']}');
        }
      }

      // Process items from subcategories
      if (subCategories != null) {
        print('Surveillance Screen: Processing subcategory items...');
        subCategories.forEach((key, items) {
          print('Surveillance Screen: Processing subcategory $key with ${items.length} items');
          
          for (var item in items) {
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
              print('Surveillance Screen: Added CCTV item from subcategory $key: ${savedItem['serialNumber']}');
            }
          }
        });
      }

      print('Surveillance Screen: Loaded ${savedCCTVItems.length} CCTV items total');
      print('Surveillance Screen: Current scanned items: $currentScannedItems');
    });
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
      showCustomToast(
        context,
        'Maximum number of CCTV items ($totalCCTVItems) already added.',
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
        print('Surveillance Screen: Retrieved assetAuditSiteRespId: $assetAuditSiteRespId for CCTV');
            
        Map<String, dynamic> currentFormData = {
          'serialNumber': actualSerialNumber, // Use the actual serial number from controller
          'photo': cctvPhoto,
          'photoId': cctvPhotoId, // Include the photoId from API
          'photoTakenTs': DateTime.now().toString(),
          'itemType': 'CCTV', // Include item type
          'remarks': 'CCTV Item', // Include remarks
          'assetStatus': cctvStatus ?? "OK", // Use assetStatus instead of status
          'assetAuditSiteRespId': assetAuditSiteRespId, // Include asset audit site resp ID
          'timestamp': DateTime.now(),
          'isQRCodeScanned': false,
          // Track if this was QR scanned or manual entry (false for manual entry)
        };

        print('Saving CCTV item: $currentFormData');
        print('Current savedCCTVItems count: ${savedCCTVItems.length}');

        savedCCTVItems.add(currentFormData);
        currentScannedItems++;

        print('After saving - savedCCTVItems count: ${savedCCTVItems.length}');
        print('currentScannedItems: $currentScannedItems');

        // Clear form for next entry
        cctvSerialNumber = null;
        cctvPhoto = null;
        cctvStatus = null;
        cctvPhotoId = null; // Clear photoId as well

        cctvSerialController.clear();
        cctvCardKey++;

        hasUnsavedChanges = false;
        showValidationErrors = false;
      });

      int remainingCCTVs = totalCCTVItems - savedCCTVItems.length;
      showCustomToast(
        context,
        'CCTV item saved successfully! ${remainingCCTVs > 0 ? '(${remainingCCTVs} remaining)' : '(All items added)'}',
      );
    }
  }

  // Check if all items are scanned (for display purposes only)
  bool _isAllItemsScanned() {
    return savedCCTVItems.length >= totalCCTVItems;
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
    print('=== Surveillance Screen: Getting AssetAuditSiteRespId for $itemType ===');
    
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
          print('Found $itemType in assets with ID: ${asset.assetAuditSiteRespId}');
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
          print('Item in $key: ${item.itemType} - ID: ${item.assetAuditSiteRespId}');
          if (item.itemType == itemType) {
            print('Found $itemType in subcategory $key with ID: ${item.assetAuditSiteRespId}');
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
          print('Using first available asset ID: ${firstAsset.assetAuditSiteRespId}');
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
      final allItems = widget.cctvData!.assets ?? [];

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

      // Add user's general remarks if entered
      if (generalRemarksController.text.isNotEmpty) {
        // Find the appropriate remarks entry from backend data
        int? remarksAssetAuditSiteRespId = _getRemarksAssetAuditSiteRespId();
        
        if (remarksAssetAuditSiteRespId != null) {
          Map<String, dynamic> remarksData = {
            'itemType': 'CCTV', // Use the main screen category
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
          print('Surveillance Screen: Added user remarks to post with ID: $remarksAssetAuditSiteRespId, text: "${generalRemarksController.text}"');
        } else {
          print('Surveillance Screen: Could not find remarks ID from backend data');
        }
      }

      if (allItemsToPost.isEmpty) {
        print('Surveillance Screen: No enhanced items to post');
        return false;
      }

      print('Surveillance Screen: Enhanced items before conversion: $enhancedItems');
      
      // Debug: Check if assetAuditSiteRespId is preserved in enhanced items
      for (int i = 0; i < enhancedItems.length; i++) {
        var item = enhancedItems[i];
        print('Surveillance Screen: Enhanced item $i:');
        print('  - assetAuditSiteRespId: ${item['assetAuditSiteRespId']}');
        print('  - serialNumber: ${item['serialNumber']}');
        print('  - itemType: ${item['itemType']}');
      }

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

      print('Surveillance Screen: Final POST requests: $requests');
      
      // Debug: Check if assetAuditSiteRespId is preserved in final requests
      for (int i = 0; i < requests.length; i++) {
        var request = requests[i];
        print('Surveillance Screen: Final request $i:');
        print('  - assetAuditSiteRespId: ${request.assetAuditSiteRespId}');
        print('  - nexgenSerialNo: ${request.nexgenSerialNo}');
        print('  - itemTypeId: ${request.itemTypeId}');
        print('  - itemTypeRemark: ${request.itemTypeRemark}');
      }

      // Set flag BEFORE making the API call to ensure it's set when success state is received
      setState(() {
        _hasPostedSurveillanceData = true;
      });
      print('Surveillance Screen: Set _hasPostedSurveillanceData flag to true BEFORE API call');
      print('Surveillance Screen: Flag value after setting: $_hasPostedSurveillanceData');
      
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

    showCustomToast(
      context,
      'CCTV item loaded for editing. Make changes and save again.',
    );
  }

  // Edit a specific saved item from the list
  void _editSavedItem(Map<String, dynamic> item, String itemType) {
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

    showCustomToast(
      context,
      'CCTV item loaded for editing. Make changes and save again.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AssetAuditCubit, AssetAuditState>(
      listener: (context, state) {
        print('Surveillance Screen: BlocListener received state: $state');
        print('Surveillance Screen: State type: ${state.runtimeType}');
        
        if (state is AssetAuditPostSuccess) {
          print('Surveillance Screen: AssetAuditPostSuccess received!');
          print('Surveillance Screen: State details: $state');
          print('Surveillance Screen: _hasPostedSurveillanceData flag: $_hasPostedSurveillanceData');
          
          // Check if this success state contains Surveillance-related items
          bool isSurveillanceData = false;
          print('Surveillance Screen: Total responses received: ${state.responses.length}');
          for (var response in state.responses) {
            print('Surveillance Screen: Full response object: $response');
            print('Surveillance Screen: Checking response itemTypeRemark: ${response.itemTypeRemark}');
            print('Surveillance Screen: Checking response itemTypeId: ${response.itemTypeId}');
            print('Surveillance Screen: Checking response nexgenSerialNo: ${response.nexgenSerialNo}');
            print('Surveillance Screen: Checking response assetStatus: ${response.assetStatus}');
            print('Surveillance Screen: Checking response remarks: ${response.remarks}');
            
            // Primary check: itemTypeRemark contains Surveillance-related text
            if (response.itemTypeRemark != null && 
                (response.itemTypeRemark!.contains('CCTV') || 
                 response.itemTypeRemark!.contains('Surveillance') ||
                 response.itemTypeRemark!.contains('Camera'))) {
              isSurveillanceData = true;
              print('Surveillance Screen: Found Surveillance-related item by itemTypeRemark: ${response.itemTypeRemark}');
              break;
            }
            
            // Fallback check: Check if this is a response to Surveillance screen data by looking at the flag
            if (_hasPostedSurveillanceData) {
              isSurveillanceData = true;
              print('Surveillance Screen: Found Surveillance-related item by flag check (fallback)');
              break;
            }
            
            print('Surveillance Screen: itemTypeRemark "${response.itemTypeRemark}" does not match Surveillance patterns');
          }
          
          // Only process this success state if it contains Surveillance screen data
          if (isSurveillanceData) {
            print('Surveillance Screen: Confirmed this is Surveillance screen data, proceeding with data refresh...');
            
            // Show success message
            showCustomToast(context, '✅ Surveillance data saved successfully!');

            // Refresh data from API before navigating
            print('Surveillance Screen: Refreshing data from API...');
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
                  print('Surveillance Screen: Data refreshed, navigating to next screen...');
                  pushPage(
                    context,
                    FencingScreen(
                      fencingData: widget.assetAuditData?.responseData.boundary, // Use boundary instead of fencing
                      assetAuditData: widget.assetAuditData,
                      showSuccessMessage: false, // Don't show success message when skipping surveillance screen
                      extinguisherItems: widget.extinguisherItems ?? [],
                      solarPlatesItems: widget.solarPlatesItems ?? [],
                      surveillanceItems: [
                        ...savedCCTVItems,
                      ],
                    ),
                  );
                  
                  // Reset the flag after successful navigation
                  setState(() {
                    _hasPostedSurveillanceData = false;
                  });
                  print('Surveillance Screen: Reset _hasPostedSurveillanceData flag to false after navigation');
                }
              });
            } catch (e) {
              print('Surveillance Screen: Error refreshing data: $e');
              // Fallback: navigate anyway after delay
              Future.delayed(const Duration(seconds: 2), () {
                if (mounted) {
                  pushPage(
                    context,
                    FencingScreen(
                      fencingData: widget.assetAuditData?.responseData.boundary,
                      assetAuditData: widget.assetAuditData,
                      showSuccessMessage: false,
                      extinguisherItems: widget.extinguisherItems ?? [],
                      solarPlatesItems: widget.solarPlatesItems ?? [],
                      surveillanceItems: [
                        ...savedCCTVItems,
                      ],
                    ),
                  );
                  setState(() {
                    _hasPostedSurveillanceData = false;
                  });
                }
              });
            }
          } else {
            print('Surveillance Screen: Success state received but not for Surveillance screen data, ignoring...');
            print('Surveillance Screen: _hasPostedSurveillanceData flag: $_hasPostedSurveillanceData');
          }
        } else if (state is AssetAuditPostError) {
          // Only show error message if this error belongs to Surveillance screen data
          if (_hasPostedSurveillanceData) {
            print('Surveillance Screen: AssetAuditPostError received for Surveillance data');
            // Show error message and block navigation
            showCustomToast(
              context,
              '❌ Failed to save Surveillance data. Please try again.',
            );
            
            // Reset the flag on error
            setState(() {
              _hasPostedSurveillanceData = false;
            });
            print('Surveillance Screen: Reset _hasPostedSurveillanceData flag to false after error');
          } else {
            print('Surveillance Screen: AssetAuditPostError received but not for Surveillance data, ignoring...');
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
                                      totalCCTVItems = int.tryParse(value) ?? 6;
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
                                  remarksLabel: "Camera Capacity",
                                  remarksHintText: "Eg: 1080p, 4K",
                                  remarksController: cctvCapacityController,
                                  isRemarksEditable: false, // Make capacity non-editable
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
                                text: "Surveillance",
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
                                          fencingData: widget.assetAuditData?.responseData.boundary,
                                          assetAuditData: widget.assetAuditData,
                                          showSuccessMessage: false,
                                          extinguisherItems: widget.extinguisherItems ?? [],
                                          solarPlatesItems: widget.solarPlatesItems ?? [],
                                          surveillanceItems: [],
                                        ),
                                      ),
                                    );
                                    return;
                                  }
                                  
                                  // Navigate to next screen with accumulated data
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => FencingScreen(
                                        fencingData: widget.assetAuditData?.responseData.boundary,
                                        assetAuditData: widget.assetAuditData,
                                        showSuccessMessage: false,
                                        extinguisherItems: widget.extinguisherItems ?? [],
                                        solarPlatesItems: widget.solarPlatesItems ?? [],
                                        surveillanceItems: [
                                          ...savedCCTVItems,
                                        ],
                                      ),
                                    ),
                                  );
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
