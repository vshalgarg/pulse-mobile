import 'package:app/commonWidgets/custom_buttons/arrow_botton.dart';
import 'package:app/constants/constants_methods.dart';
import 'package:app/screens/asset_audit/asset_audit_telecom/battery_screen.dart';
import 'package:app/screens/asset_audit/asset_audit_telecom/solar_plates.dart';
import 'package:app/screens/asset_audit/asset_audit_telecom/smps_screen.dart';
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
import '../../../commonWidgets/custom_image_upload_field.dart';
import '../../../commonWidgets/custom_radio_options.dart';
import '../../../commonWidgets/custom_remark.dart';
import '../../../commonWidgets/qr_screen_form_field.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_images.dart';
import '../../../constants/constants_strings.dart';

class ExtinguisherScreen extends StatefulWidget {
  final CategoryData? extinguisherData;
  final AssetAuditModel? assetAuditData;
  final bool showSuccessMessage; // Flag to show success message

  const ExtinguisherScreen({
    super.key,
    this.extinguisherData,
    this.assetAuditData,
    this.showSuccessMessage = false, // Default to false
  });

  @override
  State<ExtinguisherScreen> createState() => _ExtinguisherScreenState();
}

class _ExtinguisherScreenState extends State<ExtinguisherScreen> {
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
  List<Map<String, dynamic>> savedRectifierItems = [];
  List<Map<String, dynamic>> savedMPPTItems = [];
  List<Map<String, dynamic>> savedFloodLightItems = [];
  List<Map<String, dynamic>> savedFireExtinguisherItems = [];
  Map<String, dynamic> currentFormData = {}; // Current form data
  String? uploadedPhotoPath;

  // AssetTypeCard field values for Rectifier
  String? rectifierSerialNumber;
  String? rectifierPhoto;
  int? rectifierPhotoId;
  String? rectifierStatus;
  
  // AssetTypeCard field values for Fire Extinguisher (separate from Rectifier)
  String? fireExtinguisherSerialNumber;
  String? fireExtinguisherPhoto;
  int? fireExtinguisherPhotoId;
  String? fireExtinguisherStatus;
  
  // Separate controllers for each section to avoid conflicts
  final rectifierRemarksController = TextEditingController();
  final mpptRemarksController = TextEditingController();
  final generalRemarksController = TextEditingController();
  final extinguisherCapacityController = TextEditingController();
  final floodLightCapacityController = TextEditingController();
  final sandBucketCapacityController = TextEditingController();

  // AssetTypeCard field values for MPPT
  String? mpptSerialNumber;
  String? mpptPhoto;
  int? mpptPhotoId; // Store the photoId from API
  String? mpptStatus;

  // AssetTypeCard field values for Flood Light
  String? floodLightSerialNumber;
  String? floodLightPhoto;
  int? floodLightPhotoId; // Store the photoId from API
  String? floodLightStatus;

  // Controllers for CustomInfoCard
  final TextEditingController rectifierSerialController =
      TextEditingController();
  final TextEditingController mpptSerialController = TextEditingController();
  final TextEditingController floodLightSerialController =
      TextEditingController();
  final TextEditingController fireExtinguisherSerialController =
      TextEditingController();

  // Keys to force rebuild of CustomInfoCard widgets
  int rectifierCardKey = 0;
  int mpptCardKey = 0;
  int floodLightCardKey = 0;
  int fireExtinguisherCardKey = 0;
  
  // Flag to track if Extinguisher screen has posted data
  bool _hasPostedExtinguisherData = false;

  @override
  void initState() {
    super.initState();
    // Listen to form changes
    serialController.addListener(_onFormChanged);

    // Check if we have data to show, if not, skip this screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_hasDataToShow()) {
        print('Extinguisher Screen: No data to show, skipping to Solar Plates screen');
        _navigateToSolarPlatesScreen();
      } else {
        // Load Extinguisher data if available
        _loadExtinguisherData();

        if (mounted) {
          _refreshCapacityFields();
        }

        if (widget.showSuccessMessage) {
          showCustomToast(context, '✅ Battery data saved successfully!');
        }
        
        // Debug: Print the structure of extinguisherData
        _debugExtinguisherData();
      }
    });
  }

  void _loadExtinguisherData() {
    if (widget.extinguisherData != null) {
      setState(() {
        print('=== Extinguisher Screen: Loading Data ===');

        final extinguisherAssets = widget.extinguisherData!.assets;
        if (extinguisherAssets.isNotEmpty) {
          print('Fire Extinguisher Assets found: ${extinguisherAssets.length}');
          // Process Fire Extinguisher assets for count
          for (int i = 0; i < extinguisherAssets.length; i++) {
            var item = extinguisherAssets[i];
          }
          
          // Update total count based on actual data
          totalRectifierItems = extinguisherAssets.length;
        } else {
          print('No Fire Extinguisher assets found in CategoryData.assets');
          
          // Check if there are subcategories
          if (widget.extinguisherData!.subCategories != null) {
            print('Checking subcategories...');
            widget.extinguisherData!.subCategories!.forEach((key, items) {
              print('Subcategory $key: ${items.length} items');
              if (key == 'Fire Extinguisher') {
                totalRectifierItems = items.length;
                print('Found Fire Extinguisher subcategory with $totalRectifierItems items');
              }
            });
          }
          
          if (totalRectifierItems == 0) {
            print('No items found in any structure');
            totalRectifierItems = 0;
          }
        }

        // Load remarks and populate the CustomRemarksField
        final remarks = widget.extinguisherData!.remarks;
        if (remarks.isNotEmpty) {
          // Process remarks and populate the CustomRemarksField
          for (int i = 0; i < remarks.length; i++) {
            var remark = remarks[i];

            // Populate the CustomRemarksField with the first valid remark
            if (remark.itemTypeRemark != null &&
                remark.itemTypeRemark!.isNotEmpty) {
              generalRemarksController.text = remark.itemTypeRemark!;
              print('Extinguisher Screen: Loaded remark from API: ${remark.itemTypeRemark}');
              break; // Use the first valid remark
            }
          }
        } else {
          print('No Fire Extinguisher remarks found');
        }
        
        // Load saved items from API - only items with complete data
        _loadSavedItemsFromAPI();

        final fireExtinguisherCapacity = _getCapacityForItemType('Fire Extinguisher');
        final floodLightCapacity = _getCapacityForItemType('Flood Light');
        final sandBucketCapacity = _getCapacityForItemType('Sand Bucket');
        _refreshCapacityFields();
      });
    } else {
      print('Extinguisher Screen: No extinguisherData available');
    }
  }

  /// Load saved items from API - only items with complete data (serial, photo, status)
  /// This method loads items from the API response and populates the saved items lists
  void _loadSavedItemsFromAPI() {
    if (widget.extinguisherData == null) {
      print('Extinguisher Screen: No extinguisher data available');
      return;
    }

    print('Extinguisher Screen: Loading saved items from API...');
    
    setState(() {
      // Clear existing saved items to avoid duplicates
      savedRectifierItems.clear();
      savedMPPTItems.clear();
      savedFloodLightItems.clear();
      savedFireExtinguisherItems.clear();
      currentScannedItems = 0;

      // Load Fire Extinguisher assets (from assets array)
      final fireExtinguisherAssets = widget.extinguisherData!.assets
          .where((item) => item.itemType == 'Fire Extinguisher')
          .toList();
      print('Extinguisher Screen: Found ${fireExtinguisherAssets.length} Fire Extinguisher assets');
      
      for (var item in fireExtinguisherAssets) {
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
            'itemType': item.itemType ?? 'Fire Extinguisher',
            'remarks': item.itemTypeRemark ?? 'Fire Extinguisher Item',
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
          savedFireExtinguisherItems.add(savedItem);
          currentScannedItems++;
          print('Extinguisher Screen: Added Fire Extinguisher item: ${savedItem['serialNumber']}');
        }
      }

      // Load Flood Light assets (from subcategories)
      final floodLightItems = widget.extinguisherData!.floodLight ?? [];
      print('Extinguisher Screen: Found ${floodLightItems.length} Flood Light items');
      
      for (var item in floodLightItems) {
        // Only add items that have complete data
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
            'itemType': item.itemType ?? 'Flood Light',
            'remarks': item.itemTypeRemark ?? 'Flood Light Item',
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
          savedFloodLightItems.add(savedItem);
          currentScannedItems++;
          print('Extinguisher Screen: Added Flood Light item: ${savedItem['serialNumber']}');
        }
      }

      // Load Sand Bucket assets (from subcategories)
      final sandBucketItems = widget.extinguisherData!.sandBucket ?? [];
      print('Extinguisher Screen: Found ${sandBucketItems.length} Sand Bucket items');
      
      for (var item in sandBucketItems) {
        // Only add items that have complete data
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
            'itemType': item.itemType ?? 'Sand Bucket',
            'remarks': item.itemTypeRemark ?? 'Sand Bucket Item',
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
          savedMPPTItems.add(savedItem); // Using MPPT list for Sand Bucket items
          currentScannedItems++;
          print('Extinguisher Screen: Added Sand Bucket item: ${savedItem['serialNumber']}');
        }
      }

      print('Extinguisher Screen: Loaded ${savedFireExtinguisherItems.length} Fire Extinguisher items, ${savedFloodLightItems.length} Flood Light items, ${savedMPPTItems.length} Sand Bucket items');
      print('Extinguisher Screen: Current scanned items: $currentScannedItems');
    });
  } // End of _loadSavedItemsFromAPI method

  /// Debug method to print the complete structure of extinguisherData
  void _debugExtinguisherData() {
    print('=== Extinguisher Screen: Debug Data Structure ===');
    if (widget.extinguisherData != null) {
      print('extinguisherData is not null');
      print('extinguisherData type: ${widget.extinguisherData.runtimeType}');
      
      // Access CategoryData properties correctly
      print('assets: ${widget.extinguisherData!.assets}');
      print('assets length: ${widget.extinguisherData!.assets.length}');
      print('remarks: ${widget.extinguisherData!.remarks}');
      print('remarks length: ${widget.extinguisherData!.remarks.length}');
      
      if (widget.extinguisherData!.subCategories != null) {
        print('subCategories: ${widget.extinguisherData!.subCategories}');
        widget.extinguisherData!.subCategories!.forEach((key, items) {
          print('Subcategory $key: ${items.length} items');
        });
      } else {
        print('No subcategories found');
      }
      
      // Try to access specific subcategories using helper methods
      try {
        print('floodLight: ${widget.extinguisherData!.floodLight?.length ?? 0} items');
        print('sandBucket: ${widget.extinguisherData!.sandBucket?.length ?? 0} items');
      } catch (e) {
        print('Error accessing helper methods: $e');
      }
    } else {
      print('extinguisherData is null');
    }
    print('================================================');
  }

  @override
  void dispose() {
    serialController.removeListener(_onFormChanged);
    serialController.dispose();
    rectifierSerialController.dispose();
    mpptSerialController.dispose();
    floodLightSerialController.dispose();
    fireExtinguisherSerialController.dispose();
    rectifierRemarksController.dispose();
    mpptRemarksController.dispose();
    generalRemarksController.dispose();
    extinguisherCapacityController.dispose();
    floodLightCapacityController.dispose();
    sandBucketCapacityController.dispose();
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
          floodLightSerialController.text.isNotEmpty;

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
    // Check all controllers to see which one has data
    String? serialNumber = rectifierSerialController.text.isNotEmpty
        ? rectifierSerialController.text
        : mpptSerialController.text.isNotEmpty
        ? mpptSerialController.text
        : floodLightSerialController.text.isNotEmpty
        ? floodLightSerialController.text
        : fireExtinguisherSerialController.text.isNotEmpty
        ? fireExtinguisherSerialController.text
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
    String? photo = rectifierPhoto ?? mpptPhoto ?? floodLightPhoto ?? fireExtinguisherPhoto;
    print('Photo: $photo');
    if (photo == null || photo.isEmpty) {
      print(' Photo validation failed');
      return false;
    } else {
      print('Photo validation passed');
    }

    // Note: status is not required since it comes from API
    // and is set to true by default (backendStatus: true)
    String? status = rectifierStatus ?? mpptStatus ?? floodLightStatus ?? fireExtinguisherStatus;
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
        : floodLightSerialController.text.isNotEmpty
        ? floodLightSerialController.text
        : fireExtinguisherSerialController.text.isNotEmpty
        ? fireExtinguisherSerialController.text
        : null;

    print('Serial number: "$serialNumber"');
    if (serialNumber == null || serialNumber.isEmpty) {
      print(' Serial number validation failed');
      return false;
    } else {
      print(' Serial number validation passed');
    }

    // Check if photo is added
    // Check all photo variables to see which one has data
    String? photo = rectifierSerialController.text.isNotEmpty
        ? rectifierPhoto
        : mpptSerialController.text.isNotEmpty
        ? mpptPhoto
        : floodLightSerialController.text.isNotEmpty
        ? floodLightPhoto
        : fireExtinguisherSerialController.text.isNotEmpty
        ? fireExtinguisherPhoto
        : null;
    print('Photo: $photo');
    if (photo == null || photo.isEmpty) {
      print(' Photo validation failed');
      return false;
    } else {
      print(' Photo validation passed');
    }

    // Note: status is not required since it comes from API
    // and is set to true by default (backendStatus: true)
    String? status = rectifierSerialController.text.isNotEmpty
        ? rectifierStatus
        : mpptSerialController.text.isNotEmpty
        ? mpptStatus
        : floodLightSerialController.text.isNotEmpty
        ? floodLightStatus
        : fireExtinguisherSerialController.text.isNotEmpty
        ? fireExtinguisherStatus
        : null;
    print('Status: $status (not required)');

    print('Final validation result: true');
    return true;
  }

  // Save current form data for Rectifier
  void _saveRectifierForm() {
    // Check if we've reached the maximum limit from backend
    if (savedRectifierItems.length >= totalRectifierItems) {
      showCustomToast(
        context,
        '❌ Maximum limit reached! You can only scan up to $totalRectifierItems Rectifier items (as per backend count).',
      );
      return;
    }

    if (_isFormValid()) {
      setState(() {
        // Get the actual serial number from the controller
        String actualSerialNumber = rectifierSerialController.text.isNotEmpty 
            ? rectifierSerialController.text 
            : 'Unknown';
            
        // Create a map of current form data
        Map<String, dynamic> currentFormData = {
          'serialNumber': actualSerialNumber, // Use the actual serial number from controller
          'photo': rectifierPhoto,
          'photoId': rectifierPhotoId,
          'photoTakenTs': DateTime.now().toString(),
          'itemType': 'Rectifier',
          'remarks': rectifierRemarksController.text.isNotEmpty ? rectifierRemarksController.text : 'Rectifier Item',
          'assetStatus': rectifierStatus ?? "OK",
          'assetAuditSiteRespId': _getAssetAuditSiteRespId('Rectifier', serialNumber: actualSerialNumber),
          'timestamp': DateTime.now(),
          'isQRCodeScanned': false,
          // Track if this was QR scanned or manual entry (false for manual entry)
        };

        print('Saving Rectifier item: $currentFormData');
        print('Current savedRectifierItems count: ${savedRectifierItems.length}');

        // Add to saved rectifier items list
        savedRectifierItems.add(currentFormData);
        currentScannedItems++;

        print('After saving - savedRectifierItems count: ${savedRectifierItems.length}');
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
    // Check if we've reached the maximum limit from backend
    if (savedMPPTItems.length >= totalMPPTItems) {
      showCustomToast(
        context,
        '❌ Maximum limit reached! You can only scan up to $totalMPPTItems MPPT items (as per backend count).',
      );
      return;
    }

    if (_isFormValid()) {
      setState(() {
        // Get the actual serial number from the controller
        String actualSerialNumber = mpptSerialController.text.isNotEmpty 
            ? mpptSerialController.text 
            : 'Unknown';
            
        // Create a map of current form data
        Map<String, dynamic> currentFormData = {
          'serialNumber': actualSerialNumber, // Use the actual serial number from controller
          'photo': mpptPhoto,
          'photoId': mpptPhotoId,
          'photoTakenTs': DateTime.now().toString(),
          'itemType': 'Sand Bucket',
          'remarks': sandBucketCapacityController.text.isNotEmpty ? sandBucketCapacityController.text : 'Sand Bucket Item',
          'assetStatus': mpptStatus ?? "OK",
          'assetAuditSiteRespId': _getAssetAuditSiteRespId('Sand Bucket', serialNumber: mpptSerialNumber),
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

  // Save current form data for Fire Extinguisher
  void _saveFireExtinguisherForm() {
    // Check if we've reached the limit for Fire Extinguisher items
    if (savedFireExtinguisherItems.length >= totalRectifierItems) {
      showCustomToast(context, 'Maximum number of Fire Extinguisher items ($totalRectifierItems) already added.');
      return;
    }

    // Enforce serial uniqueness validation specifically for Fire Extinguisher
    final String enteredFireExtinguisherSerial =
        fireExtinguisherSerialController.text.trim();
    if (!_validateSerialNumber(enteredFireExtinguisherSerial)) {
      showCustomToast(
        context,
        '❌ Serial number already exists or is invalid. Please enter a unique serial.',
      );
      return;
    }

    if (_isFormValid()) {
      setState(() {
        // Create a map of current form data
        Map<String, dynamic> currentFormData = {
          'serialNumber': fireExtinguisherSerialNumber,
          'photo': fireExtinguisherPhoto,
          'photoId': fireExtinguisherPhotoId,
          'status': fireExtinguisherStatus ?? "OK",
          'timestamp': DateTime.now(),
          'isQRCodeScanned': false,
          'itemType': 'Fire Extinguisher',
          'remarks': extinguisherCapacityController.text.isNotEmpty ? extinguisherCapacityController.text : 'Fire Extinguisher Item',
          'assetStatus': fireExtinguisherStatus ?? "OK",
          'assetAuditSiteRespId': _getAssetAuditSiteRespId('Fire Extinguisher', serialNumber: fireExtinguisherSerialNumber),
        };

        print('Saving Fire Extinguisher item: $currentFormData');
        print('Fire Extinguisher assetAuditSiteRespId: ${currentFormData['assetAuditSiteRespId']}');
        print('Current savedFireExtinguisherItems count: ${savedFireExtinguisherItems.length}');

        // Add to saved fire extinguisher items list
        savedFireExtinguisherItems.add(currentFormData);
        currentScannedItems++;

        print('After saving - savedFireExtinguisherItems count: ${savedFireExtinguisherItems.length}');
        print('currentScannedItems: $currentScannedItems');

        // Clear AssetTypeCard form for next entry
        fireExtinguisherSerialNumber = null;
        fireExtinguisherPhoto = null;
        fireExtinguisherPhotoId = null;
        fireExtinguisherStatus = null;

        // Clear the controller
        fireExtinguisherSerialController.clear();

        // Force rebuild of the CustomInfoCard widget
        fireExtinguisherCardKey++;

        hasUnsavedChanges = false;
        showValidationErrors = false;
      });

      // Show success message
      int remainingFireExtinguishers = totalRectifierItems - savedFireExtinguisherItems.length;
      showCustomToast(
        context,
        'Fire Extinguisher item saved successfully! ${remainingFireExtinguishers > 0 ? '(${remainingFireExtinguishers} remaining)' : '(All items added)'}',
      );
    } else {
      print('Form validation failed - cannot save fire extinguisher item');
    }
  }

  // Save current form data for Flood Light
  void _saveFloodLightForm() {
    // Check if we've reached the limit for Flood Light items
    if (savedFloodLightItems.length >= totalMPPTItems) {
      showCustomToast(context, 'Maximum number of Flood Light items ($totalMPPTItems) already added.');
      return;
    }

    if (_isFormValid()) {
      setState(() {
        // Create a map of current form data
        Map<String, dynamic> currentFormData = {
          'serialNumber': floodLightSerialNumber,
          'photo': floodLightPhoto,
          'photoId': floodLightPhotoId,
          'status': floodLightStatus ?? "OK",
          'timestamp': DateTime.now(),
          'isQRCodeScanned': false,
          'itemType': 'Flood Light',
          'remarks': floodLightCapacityController.text.isNotEmpty ? floodLightCapacityController.text : 'Flood Light Item',
          'assetStatus': floodLightStatus ?? "OK",
          'assetAuditSiteRespId': _getAssetAuditSiteRespId('Flood Light', serialNumber: floodLightSerialNumber),
        };

        print('Saving Flood Light item: $currentFormData');
        print('Flood Light assetAuditSiteRespId: ${currentFormData['assetAuditSiteRespId']}');
        print('Current savedFloodLightItems count: ${savedFloodLightItems.length}');

        // Add to saved flood light items list
        savedFloodLightItems.add(currentFormData);
        currentScannedItems++;

        print('After saving - savedFloodLightItems count: ${savedFloodLightItems.length}');
        print('currentScannedItems: $currentScannedItems');

        // Clear AssetTypeCard form for next entry
        floodLightSerialNumber = null;
        floodLightPhoto = null;
        floodLightPhotoId = null;
        floodLightStatus = null;

        // Clear the controller
        floodLightSerialController.clear();

        // Force rebuild of the CustomInfoCard widget
        floodLightCardKey++;

        hasUnsavedChanges = false;
        showValidationErrors = false;
      });

      // Show success message
      int remainingFloodLights = totalMPPTItems - savedFloodLightItems.length;
      showCustomToast(
        context,
        'Flood Light item saved successfully! ${remainingFloodLights> 0 ? '(${remainingFloodLights} remaining)' : '(All items added)'}',
      );
    } else {
      print('Form validation failed - cannot save Flood Light item');
    }
  }

  // Check if all items are scanned (for display purposes only)
  bool _isAllItemsScanned() {
    // If no data to show, consider all items scanned
    if (!_hasDataToShow()) {
      print('Extinguisher Screen: No data to show, considering all items scanned');
      return true;
    }
    
    return (savedRectifierItems.length >= totalRectifierItems) &&
        (savedMPPTItems.length >= totalMPPTItems) &&
        (savedFloodLightItems.length >= totalMPPTItems) && // Using same count for flood light
        (savedFireExtinguisherItems.length >= totalRectifierItems); // Using same count for fire extinguisher
  }

  // Check if user can proceed to next screen (minimum 1 item required)
  bool _canProceedToNextScreen() {
    // If no data to show, always allow proceeding
    if (!_hasDataToShow()) {
      print('Extinguisher Screen: No data to show, allowing navigation');
      return true;
    }
    
    // Check if we have at least one item saved from any category
    bool hasRectifierItems = savedRectifierItems.isNotEmpty;
    bool hasMPPTItems = savedMPPTItems.isNotEmpty;
    bool hasFloodLightItems = savedFloodLightItems.isNotEmpty;
    bool hasFireExtinguisherItems = savedFireExtinguisherItems.isNotEmpty;
    
    print('Extinguisher Screen: Checking if can proceed to next screen...');
    print('Extinguisher Screen: savedRectifierItems: ${savedRectifierItems.length}');
    print('Extinguisher Screen: savedMPPTItems: ${savedMPPTItems.length}');
    print('Extinguisher Screen: savedFloodLightItems: ${savedFloodLightItems.length}');
    print('Extinguisher Screen: savedFireExtinguisherItems: ${savedFireExtinguisherItems.length}');
    print('Extinguisher Screen: Can proceed: ${hasRectifierItems || hasMPPTItems || hasFloodLightItems || hasFireExtinguisherItems}');
    
    return hasRectifierItems || hasMPPTItems || hasFloodLightItems || hasFireExtinguisherItems;
  }

  /// Get the capacity value for a specific item type from the API data
  String _getCapacityForItemType(String itemType) {
    print('=== Extinguisher Screen: Getting Capacity for $itemType ===');
    
    if (widget.extinguisherData == null) {
      print('extinguisherData is null, returning default capacity');
      return '5 KW'; // Default capacity
    }
    
    print('extinguisherData is not null, checking for capacity for $itemType...');
    
    // First try to get capacity from assets
    final extinguisherAssets = widget.extinguisherData!.assets;
    if (extinguisherAssets.isNotEmpty) {
      print('Found ${extinguisherAssets.length} assets in CategoryData.assets');
      for (var asset in extinguisherAssets) {
        if (asset.itemType == itemType) {
          print('Found $itemType in assets with capacity: ${asset.capacity}');
          if (asset.capacity != null && asset.capacity!.isNotEmpty) {
            print('Returning capacity from assets: ${asset.capacity}');
            return asset.capacity!;
          }
        }
      }
    }
    
    // If not found in assets, check subcategories
    if (widget.extinguisherData!.subCategories != null) {
      print('Checking subcategories for $itemType capacity...');
      for (var entry in widget.extinguisherData!.subCategories!.entries) {
        String key = entry.key;
        List<AssetItem> items = entry.value;
        print('Subcategory $key: ${items.length} items');
        if (items.isNotEmpty) {
          final firstItem = items.first;
          if (firstItem.itemType == itemType) {
            print('Found $itemType in subcategory $key with capacity: ${firstItem.capacity}');
            if (firstItem.capacity != null && firstItem.capacity!.isNotEmpty) {
              print('Returning capacity from subcategory: ${firstItem.capacity}');
              return firstItem.capacity!;
            }
          }
        }
      }
    }
    
    // Try specific subcategory helper methods
    if (itemType == 'Fire Extinguisher') {
      // For Fire Extinguisher, check in assets first, then subcategories
      final fireExtinguisherAssets = widget.extinguisherData!.assets.where((asset) => asset.itemType == 'Fire Extinguisher').toList();
      if (fireExtinguisherAssets.isNotEmpty) {
        final firstItem = fireExtinguisherAssets.first;
        if (firstItem.capacity != null && firstItem.capacity!.isNotEmpty) {
          print('Returning capacity from Fire Extinguisher assets: ${firstItem.capacity}');
          return firstItem.capacity!;
        }
      }
    } else if (itemType == 'Flood Light') {
      final floodLightItems = widget.extinguisherData!.floodLight;
      if (floodLightItems != null && floodLightItems.isNotEmpty) {
        final firstItem = floodLightItems.first;
        if (firstItem.capacity != null && firstItem.capacity!.isNotEmpty) {
          print('Returning capacity from Flood Light helper method: ${firstItem.capacity}');
          return firstItem.capacity!;
        }
      }
    } else if (itemType == 'Sand Bucket') {
      final sandBucketItems = widget.extinguisherData!.sandBucket;
      if (sandBucketItems != null && sandBucketItems.isNotEmpty) {
        final firstItem = sandBucketItems.first;
        if (firstItem.capacity != null && firstItem.capacity!.isNotEmpty) {
          print('Returning capacity from Sand Bucket helper method: ${firstItem.capacity}');
          return firstItem.capacity!;
        }
      }
    }
    
    print('No capacity found for $itemType, returning default');
    return '5 KW'; // Default capacity
  }

  /// Get the capacity value for Fire Extinguisher from the API data (for backward compatibility)
  String _getExtinguisherCapacity() {
    return _getCapacityForItemType('Fire Extinguisher');
  }

  void _refreshCapacityFields() {
    if (mounted) {
      setState(() {
        extinguisherCapacityController.text = _getCapacityForItemType('Fire Extinguisher');
        floodLightCapacityController.text = _getCapacityForItemType('Flood Light');
        sandBucketCapacityController.text = _getCapacityForItemType('Sand Bucket');
      });
    }
  }


  int? _getRemarksAssetAuditSiteRespId() {
    if (widget.extinguisherData == null) {
      return null;
    }
    

    final remarks = widget.extinguisherData!.remarks;
    if (remarks.isNotEmpty) {
        for (var remark in remarks) {
        if (remark.assetAuditSiteRespId != null && 
            remark.assetAuditSiteRespId > 0 && 
            remark.itemType == 'Fire Extinguisher') {
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
    
    print('No valid remarks ID found in backend data');
    return null;
  }

  bool _hasDataToShow() {
    if (widget.extinguisherData == null) {

      return false;
    }
    final hasAssets = widget.extinguisherData!.assets.isNotEmpty;

    final hasSubCategories = widget.extinguisherData!.subCategories != null && 
        widget.extinguisherData!.subCategories!.values.any((items) => items.isNotEmpty);

    final hasData = hasAssets || hasSubCategories;
    return hasData;
  }

  void _navigateToSolarPlatesScreen() {
    print('Extinguisher Screen: Navigating to Solar Plates screen');
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => SolarPlatesScreen(
          solarPlatesData: widget.assetAuditData?.responseData.solarPlates,
          assetAuditData: widget.assetAuditData,
          showSuccessMessage: false, // Don't show success message when skipping extinguisher screen
          extinguisherItems: [
            ...savedFireExtinguisherItems,
            ...savedFloodLightItems,
            ...savedRectifierItems,
            ...savedMPPTItems,
          ],
        ),
      ),
    );
  }

  /// Get the assetAuditSiteRespId for different item types from the API data
  int _getAssetAuditSiteRespId(String itemType, {String? serialNumber}) {

    if (widget.extinguisherData == null) {
      print('extinguisherData is null, returning default ID');
      return 0; // Default ID
    }

    widget.extinguisherData!.assets.forEach((asset) {
      print('  Asset: ${asset.itemType} - ID: ${asset.assetAuditSiteRespId} - Serial: ${asset.nexgenSerialNo}');
    });
    
    // Debug: Check if we have access to subcategories
    if (widget.extinguisherData!.subCategories != null) {
      print('Available subcategories: ${widget.extinguisherData!.subCategories!.keys.toList()}');
      widget.extinguisherData!.subCategories!.forEach((key, items) {
        print('  Subcategory $key: ${items.length} items');
        items.forEach((item) {
          print('    Item: ${item.itemType} - ID: ${item.assetAuditSiteRespId} - Serial: ${item.nexgenSerialNo}');
        });
      });
    }
    
    if (widget.extinguisherData!.subCategories != null) {
      print('Available subcategories: ${widget.extinguisherData!.subCategories!.keys.toList()}');
      widget.extinguisherData!.subCategories!.forEach((key, items) {
        print('  Subcategory $key: ${items.length} items');
        items.forEach((item) {
          print('    Item: ${item.itemType} - ID: ${item.assetAuditSiteRespId} - Serial: ${item.nexgenSerialNo}');
        });
      });
    }
    
    // First check in assets
    final extinguisherAssets = widget.extinguisherData!.assets;
    for (var asset in extinguisherAssets) {
      if (asset.itemType == itemType) {
        // If we have a serial number, try to match it
        if (serialNumber != null && 
            (asset.mfgSerialNo == serialNumber)) {
          print('Found exact match for $itemType with serial $serialNumber in assets with ID: ${asset.assetAuditSiteRespId}');
          return asset.assetAuditSiteRespId;
        }
        // If no serial number specified, return first match
        if (serialNumber == null) {
          print('Found $itemType in assets with ID: ${asset.assetAuditSiteRespId}');
          return asset.assetAuditSiteRespId;
        }
      }
    }
    
    // If not found in assets, check subcategories
    if (widget.extinguisherData!.subCategories != null) {
      print('Checking subcategories for $itemType...');
      for (var entry in widget.extinguisherData!.subCategories!.entries) {
        String key = entry.key;
        List<AssetItem> items = entry.value;
        print('Subcategory $key: ${items.length} items');
        for (var item in items) {
          if (item.itemType == itemType) {
            // If we have a serial number, try to match it
            if (serialNumber != null && 
                (item.mfgSerialNo == serialNumber)) {
              print('Found exact match for $itemType with serial $serialNumber in subcategory $key with ID: ${item.assetAuditSiteRespId}');
              return item.assetAuditSiteRespId;
            }
            // If no serial number specified, return first match
            if (serialNumber == null) {
              print('Found $itemType in subcategory $key with ID: ${item.assetAuditSiteRespId}');
              return item.assetAuditSiteRespId;
            }
          }
        }
      }
    }
    
    // Try specific subcategory helper methods
    if (itemType == 'Rectifier') {
      final rectifierItems = widget.extinguisherData!.subCategories?['Rectifier'];
      if (rectifierItems != null && rectifierItems.isNotEmpty) {
        final firstItem = rectifierItems.first;
        print('Found Rectifier in subcategories with ID: ${firstItem.assetAuditSiteRespId}');
        return firstItem.assetAuditSiteRespId;
      }
    } else if (itemType == 'Fire Extinguisher') {
          // Fire Extinguisher items are in the assets array of the Fire Extinguisher category
    final fireExtinguisherAssets = widget.extinguisherData!.assets;
    print('Fire Extinguisher assets found: ${fireExtinguisherAssets.length}');
    for (var asset in fireExtinguisherAssets) {
      print('  Checking asset: ${asset.itemType} - Serial: ${asset.nexgenSerialNo} - ID: ${asset.assetAuditSiteRespId}');
      if (asset.itemType == 'Fire Extinguisher') {
        // If we have a serial number, try to match it
        if (serialNumber != null && 
            (asset.mfgSerialNo == serialNumber)) {
          print('Found exact match for Fire Extinguisher with serial $serialNumber in assets with ID: ${asset.assetAuditSiteRespId}');
          return asset.assetAuditSiteRespId;
        }
        // If no serial number specified, return first match
        if (serialNumber == null) {
          print('Found Fire Extinguisher in assets with ID: ${asset.assetAuditSiteRespId}');
          return asset.assetAuditSiteRespId;
        }
      }
    }
    } else if (itemType == 'Flood Light') {
      // Flood Light items are in subcategories under Fire Extinguisher category
      final floodLightItems = widget.extinguisherData!.subCategories?['Flood Light'];
      if (floodLightItems != null && floodLightItems.isNotEmpty) {
        print('Found ${floodLightItems.length} Flood Light items in subcategories');
        // If we have a serial number, try to match it
        if (serialNumber != null) {
          for (var item in floodLightItems) {
            print('  Checking Flood Light item: ${item.nexgenSerialNo} vs $serialNumber');
            if (item.mfgSerialNo == serialNumber) {
              print('Found exact match for Flood Light with serial $serialNumber with ID: ${item.assetAuditSiteRespId}');
              return item.assetAuditSiteRespId;
            }
          }
        }
        // If no serial number specified, return first match
        final firstItem = floodLightItems.first;
        print('Found Flood Light in subcategories with ID: ${firstItem.assetAuditSiteRespId}');
        return firstItem.assetAuditSiteRespId;
      }
    } else if (itemType == 'Sand Bucket') {
      // Sand Bucket items are in subcategories under Fire Extinguisher category
      final sandBucketItems = widget.extinguisherData!.subCategories?['Sand Bucket'];
      if (sandBucketItems != null && sandBucketItems.isNotEmpty) {
        print('Found ${sandBucketItems.length} Sand Bucket items in subcategories');
        // If we have a serial number, try to match it
        if (serialNumber != null) {
          for (var item in sandBucketItems) {
            print('  Checking Sand Bucket item: ${item.nexgenSerialNo} vs $serialNumber');
            if (item.nexgenSerialNo == serialNumber || item.mfgSerialNo == serialNumber) {
              print('Found exact match for Sand Bucket with serial $serialNumber with ID: ${item.assetAuditSiteRespId}');
              return item.assetAuditSiteRespId;
            }
          }
        }
        // If no serial number specified, return first match
        final firstItem = sandBucketItems.first;
        print('Found Sand Bucket in subcategories with ID: ${firstItem.assetAuditSiteRespId}');
        return firstItem.assetAuditSiteRespId;
      }
    }
    
    print('No $itemType found in any structure, returning default ID');
    return 0; // Default ID
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
            'No Extinguisher Data Available',
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
            'There are no Fire Extinguisher, Flood Light, or Sand Bucket items to audit for this site.',
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



  bool _validateSerialNumber(String serialNumber) {
    print('=== Extinguisher Screen: Validating Serial Number (session-only) ===');
    final String sn = serialNumber.trim();
    print('Serial number to validate: "$sn"');

    if (sn.isEmpty) {
      print('Serial number is empty, validation failed');
      return false;
    }

    for (var savedItem in savedFireExtinguisherItems) {
      if ((savedItem['serialNumber'] as String?)?.trim() == sn) {
        print('Serial number "$sn" already exists in saved Fire Extinguisher items');
        return false;
      }
    }

    // Optionally, prevent cross-category duplicates within this screen session
    for (var savedItem in savedRectifierItems) {
      if ((savedItem['serialNumber'] as String?)?.trim() == sn) {
        print('Serial number "$sn" already exists in saved Rectifier items (session)');
        return false;
      }
    }
    for (var savedItem in savedMPPTItems) {
      if ((savedItem['serialNumber'] as String?)?.trim() == sn) {
        print('Serial number "$sn" already exists in saved MPPT items (session)');
        return false;
      }
    }
    for (var savedItem in savedFloodLightItems) {
      if ((savedItem['serialNumber'] as String?)?.trim() == sn) {
        print('Serial number "$sn" already exists in saved Flood Light items (session)');
        return false;
      }
    }

    print('Serial number "$sn" is unique within session, validation passed');
    return true;
  }

  Future<bool> _postCurrentScreenData() async {
    if (widget.assetAuditData == null) {
      print('Extinguisher Screen: No asset audit data available for posting');
      return false;
    }

    try {
      // Combine all saved items from different categories
      List<Map<String, dynamic>> allSavedItems = [];
      allSavedItems.addAll(savedRectifierItems);
      allSavedItems.addAll(savedMPPTItems);
      allSavedItems.addAll(savedFloodLightItems);
      allSavedItems.addAll(savedFireExtinguisherItems);
      
      // Add user's general remarks if entered
      if (generalRemarksController.text.isNotEmpty) {
        // Find the appropriate remarks entry from backend data
        int? remarksAssetAuditSiteRespId = _getRemarksAssetAuditSiteRespId();
        
        if (remarksAssetAuditSiteRespId != null) {
          Map<String, dynamic> remarksData = {
            'itemType': 'Fire Extinguisher', // Use the main screen category
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
          allSavedItems.add(remarksData);
          print('Extinguisher Screen: Added user remarks to post with ID: $remarksAssetAuditSiteRespId, text: "${generalRemarksController.text}"');
        } else {
          print('Extinguisher Screen: Could not find remarks ID from backend data');
        }
      }

      if (allSavedItems.isEmpty) {
        print('Extinguisher Screen: No items to post');
        return false;
      }

      // Enhance saved items with additional data
      final enhancedItems = AssetAuditPostHelper.enhanceSavedItems(
        savedItems: allSavedItems,
        screenName: 'Extinguisher',
      );

      if (enhancedItems.isEmpty) {
        print('Extinguisher Screen: No enhanced items to post');
        return false;
      }

      // Convert to POST request format
      final requests =
          await AssetAuditPostHelper.convertSavedItemsToPostRequest(
            savedItems: enhancedItems,
            assetAuditData: widget.assetAuditData!,
            itemType: 'Extinguisher',
            itemTypeId: AssetAuditPostHelper.getItemTypeId('Extinguisher'),
            screenName: 'Extinguisher',
            context: context,
          );

      if (requests.isEmpty) {
        print('Extinguisher Screen: Failed to create POST requests');
        return false;
      }

      // Set flag BEFORE making the API call to ensure it's set when success state is received
      setState(() {
        _hasPostedExtinguisherData = true;
      });
      print('Extinguisher Screen: Set _hasPostedExtinguisherData flag to true BEFORE API call');
      print('Extinguisher Screen: Flag value after setting: $_hasPostedExtinguisherData');
      
      // Use the existing cubit to post data
      print('Extinguisher Screen: Posting ${requests.length} items to API...');
      context.read<AssetAuditCubit>().postAssetAuditData(requests: requests);

      // Return true to indicate data is being posted
      return true;
    } catch (e) {
      print('Extinguisher Screen: Error preparing data: $e');
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

  // Edit a specific Flood Light item from the saved list
  void _editFloodLightItem(Map<String, dynamic> item) {
    setState(() {
      // Load the item data back into the form
      floodLightSerialNumber = item["serialNumber"];
      floodLightPhoto = item["photo"];
      floodLightStatus = item["assetStatus"]; // Use assetStatus from saved item

      // Set the serial controller text
      floodLightSerialController.text = item["serialNumber"] ?? "";

      // Remove the item from saved Flood Light items
      savedFloodLightItems.remove(item);
      currentScannedItems--;

      // Force rebuild of the CustomInfoCard widget with new data
      floodLightCardKey++;

      hasUnsavedChanges = true;
    });

    // Show message to user
    showCustomToast(
      context,
      'Flood Light item loaded for editing. Make changes and save again.',
    );
  }

  // Edit a specific Fire Extinguisher item from the saved list
  void _editFireExtinguisherItem(Map<String, dynamic> item) {
    setState(() {
      // Load the item data back into the form
      fireExtinguisherSerialNumber = item["serialNumber"];
      fireExtinguisherPhoto = item["photo"];
      fireExtinguisherStatus = item["assetStatus"]; // Use assetStatus from saved item

      // Set the serial controller text
      fireExtinguisherSerialController.text = item["serialNumber"] ?? "";

      // Remove the item from saved Fire Extinguisher items
      savedFireExtinguisherItems.remove(item);
      currentScannedItems--;

      // Force rebuild of the CustomInfoCard widget with new data
      fireExtinguisherCardKey++;

      hasUnsavedChanges = true;
    });

    // Show message to user
    showCustomToast(
      context,
      'Fire Extinguisher item loaded for editing. Make changes and save again.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AssetAuditCubit, AssetAuditState>(
      listener: (context, state) {
        print('Extinguisher Screen: BlocListener received state: $state');
        print('Extinguisher Screen: State type: ${state.runtimeType}');
        
        if (state is AssetAuditPostSuccess) {

          bool isExtinguisherData = false;
          for (var response in state.responses) {
            if (response.itemTypeRemark != null && 
                (response.itemTypeRemark!.contains('Fire Extinguisher') || 
                 response.itemTypeRemark!.contains('Sand Bucket') ||
                 response.itemTypeRemark!.contains('Extinguisher'))) {
              isExtinguisherData = true;
              break;
            }
            
            // Fallback check: Check if this is a response to Extinguisher screen data by looking at the flag
            if (_hasPostedExtinguisherData) {
              isExtinguisherData = true;
              print('Extinguisher Screen: Found Extinguisher-related item by flag check (fallback)');
              break;
            }
            
          }
          if (isExtinguisherData) {
            try {
              context.read<AssetAuditCubit>().getAssetAuditData(
                siteType: "telecom",
                auditSchId: widget.assetAuditData?.pageHeader.first.siteAuditSchId.toString() ?? "0",
                siteAuditSchId: widget.assetAuditData?.pageHeader.first.siteAuditSchId.toString() ?? "0",
              );

              Future.delayed(const Duration(seconds: 2), () {
                if (mounted) {
                  pushPage(
                    context,
                    SolarPlatesScreen(
                      solarPlatesData:
                          widget.assetAuditData?.responseData.solarPlates,
                      assetAuditData: widget.assetAuditData,
                      showSuccessMessage: false,
                      extinguisherItems: [
                        ...savedFireExtinguisherItems,
                        ...savedFloodLightItems,
                        ...savedRectifierItems,
                        ...savedMPPTItems,
                      ],
                    ),
                  );
                  
                  // Reset the flag after successful navigation
                  setState(() {
                    _hasPostedExtinguisherData = false;
                  });
                  print('Extinguisher Screen: Reset _hasPostedExtinguisherData flag to false after navigation');
                }
              });
            } catch (e) {
                if (mounted) {
                  pushPage(
                    context,
                    SolarPlatesScreen(
                      solarPlatesData:
                          widget.assetAuditData?.responseData.solarPlates,
                      assetAuditData: widget.assetAuditData,
                      showSuccessMessage: false,
                      extinguisherItems: [
                        ...savedFireExtinguisherItems,
                        ...savedFloodLightItems,
                        ...savedRectifierItems,
                        ...savedMPPTItems,
                      ],
                    ),
                  );
                  setState(() {
                    _hasPostedExtinguisherData = false;
                  });
                }

            }
          } else {
            print('Extinguisher Screen: Success state received but not for Extinguisher screen data, ignoring...');
            print('Extinguisher Screen: _hasPostedExtinguisherData flag: $_hasPostedExtinguisherData');
          }
        } else if (state is AssetAuditPostError) {
          // Only show error message if this error belongs to Extinguisher screen data
          if (_hasPostedExtinguisherData) {
            print('Extinguisher Screen: AssetAuditPostError received for Extinguisher data');
            // Show error message and block navigation
            showCustomToast(
              context,
              ' Failed to save Extinguisher data. Please try again.',
            );
            
            // Reset the flag on error
            setState(() {
              _hasPostedExtinguisherData = false;
            });
          } else {
            print('Extinguisher Screen: AssetAuditPostError received but not for Extinguisher data, ignoring...');
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
                                    label:
                                        "Fire Extinguisher Availability (Yes/No)",
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
                                CustomFormField(
                                  label: "Count of Fire Extinguisher",
                                  // "Number of ${selectedType ?? 'Batteries'}",
                                  initialValue: totalMPPTItems.toString(),
                                  isRequired: true,
                                  isEditable: true,
                                  onChanged: (value) {
                                    setState(() {
                                      totalMPPTItems = int.tryParse(value) ?? 6;
                                      hasUnsavedChanges = true;
                                    });
                                  },
                                ),
                                getHeight(15),
                                Text(
                                  "Fire Extinguisher Details",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white,
                                    fontFamily: fontFamilyMontserrat,
                                  ),
                                ),
                                getHeight(3),
                                CustomInfoCard(
                                  key: ValueKey(
                                    'fire_extinguisher_$fireExtinguisherCardKey',
                                  ),
                                  serialLabel:
                                      "Fire Extinguisher - Serial Number *",
                                  serialHintText:
                                      "Fire Extinguisher Serial Number",
                                  photoLabel: "Add a Photo",
                                  statusLabel: "Status",
                                  serialController: fireExtinguisherSerialController,
                                  onSave: _saveFireExtinguisherForm,
                                  isStatusEditable: true,
                                  backendStatus: false,
                                  isRemarksEditable: false,
                                  remarksLabel:
                                      "Capacity of Fire Extinguisher (In Kg)",
                                  remarksHintText: "Eg:200 kg",
                                  remarksController: extinguisherCapacityController,
                                  onPhotoTap: (photoPath) async {
                                    setState(() {
                                      fireExtinguisherPhoto = photoPath;
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
                                              fireExtinguisherPhotoId = photoId;
                                            });
                                            print(
                                              'Extinguisher Screen: Fire Extinguisher Photo uploaded successfully, photoId: $photoId',
                                            );
                                          }
                                        }
                                      } catch (e) {
                                        print(
                                          'Extinguisher Screen: Error uploading Fire Extinguisher photo: $e',
                                        );
                                      }
                                    }
                                  },
                                  onStatusChanged: (val) {
                                    setState(() {
                                      fireExtinguisherStatus = val ? "OK" : "Not OK";
                                      hasUnsavedChanges = true;
                                    });
                                  },
                                  onSerialChanged: (serialNumber) {
                                    setState(() {
                                      fireExtinguisherSerialNumber = serialNumber;
                                      hasUnsavedChanges = true;
                                    });

                                    // Validate serial number if not empty
                                    if (serialNumber.isNotEmpty) {
                                      // For now, assume manual entry (we'll need to add QR code detection later)
                                      final isValid = _validateSerialNumber(
                                        serialNumber,
                                      );
                                      // Update the saved item to track validation result
                                      if (isValid) {
                                        // Serial number is valid, keep it
                                      } else {
                                        // Serial number is invalid: clear it, clear controller, and inform user
                                        showCustomToast(
                                          context,
                                          '❌ Serial number already exists. Please enter a unique serial.',
                                        );
                                        setState(() {
                                          fireExtinguisherSerialNumber = null;
                                          fireExtinguisherSerialController.clear();
                                          hasUnsavedChanges = false;
                                        });
                                      }
                                    }
                                  },
                                  initialStatus: fireExtinguisherStatus == "OK"
                                      ? true
                                      : (fireExtinguisherStatus == "Not OK"
                                            ? false
                                            : null),
                                  initialPhotoPath: fireExtinguisherPhoto,
                                  isEditable: true,
                                ),
                                getHeight(8),
                                _buildFireExtinguisherSavedItemsList(),
                                getHeight(15),

                                CustomOptionSelector(
                                  label: "Flood Light Availability",
                                  isRequired: false,
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
                                Text(
                                  "Flood Light Details",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white,
                                    fontFamily: fontFamilyMontserrat,
                                  ),
                                ),
                                getHeight(3),
                                CustomInfoCard(
                                  key: ValueKey(
                                    'flood_light_$floodLightCardKey',
                                  ),
                                  serialLabel: "Flood Light - Serial Number",
                                  serialHintText: "Flood Light Serial Number",
                                  photoLabel: "Add a Photo",
                                  statusLabel: "Status",
                                  serialController: floodLightSerialController,
                                  onSave: _saveFloodLightForm,
                                  isStatusEditable: true,
                                  backendStatus: false,
                                  remarksLabel:
                                      "Capacity of Flood Light (In Watts)",
                                  remarksHintText: "Eg:200W",
                                  remarksController: floodLightCapacityController,
                                  isRemarksEditable: false,
                                  onPhotoTap: (photoPath) async {
                                    setState(() {
                                      floodLightPhoto = photoPath;
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
                                              floodLightPhotoId = photoId;
                                            });
                                            print(
                                              'Extinguisher Screen: Flood Light Photo uploaded successfully, photoId: $photoId',
                                            );
                                            
                                            // Photo uploaded successfully, but don't auto-save
                                            print('Extinguisher Screen: Flood Light Photo uploaded successfully, waiting for user to click save button');
                                          }
                                        }
                                      } catch (e) {
                                        print(
                                          'Extinguisher Screen: Error uploading Flood Light photo: $e',
                                        );
                                      }
                                    }
                                  },
                                  onStatusChanged: (val) {
                                    setState(() {
                                      floodLightStatus = val ? "OK" : "Not OK";
                                      hasUnsavedChanges = true;
                                    });
                                  },
                                  onSerialChanged: (serialNumber) {
                                    setState(() {
                                      floodLightSerialNumber = serialNumber;
                                      hasUnsavedChanges = true;
                                    });
                                  },
                                  initialStatus: floodLightStatus == "OK"
                                      ? true
                                      : (floodLightStatus == "Not OK"
                                            ? false
                                            : null),
                                  initialPhotoPath: floodLightPhoto,
                                  isEditable: true,
                                ),
                                getHeight(8),
                                _buildFloodLightSavedItemsList(),
                                getHeight(15),

                                CustomFormField(
                                  label: "Count of Fire Extinguisher",
                                  // "Number of ${selectedType ?? 'Batteries'}",
                                  initialValue: totalMPPTItems.toString(),
                                  isRequired: true,
                                  isEditable: true,
                                  onChanged: (value) {
                                    setState(() {
                                      totalMPPTItems = int.tryParse(value) ?? 6;
                                      hasUnsavedChanges = true;
                                    });
                                  },
                                ),
                                getHeight(15),
                                Text(
                                  "Rectifer Details",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white,
                                    fontFamily: fontFamilyMontserrat,
                                  ),
                                ),
                                getHeight(3),
                                CustomInfoCard(
                                  key: ValueKey(
                                    'rectifier_actual_$rectifierCardKey',
                                  ),
                                  serialLabel: "Rectifier - Serial Number",
                                  serialHintText: "Rectifier Serial Number",
                                  photoLabel: "Add a Photo",
                                  statusLabel: "Status",
                                  serialController: rectifierSerialController,
                                  onSave: _saveRectifierForm,
                                  isStatusEditable: true,
                                  backendStatus: false,
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
                                              'Extinguisher Screen: Photo uploaded successfully, photoId: $photoId',
                                            );
                                          }
                                        }
                                      } catch (e) {
                                        print(
                                          'Extinguisher Screen: Error uploading photo: $e',
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
                                  label: "Count of Sand Buckets ",
                                  // "Number of ${selectedType ?? 'Batteries'}",
                                  initialValue: totalMPPTItems.toString(),
                                  isRequired: true,
                                  isEditable: true,
                                  onChanged: (value) {
                                    setState(() {
                                      totalMPPTItems = int.tryParse(value) ?? 6;
                                      hasUnsavedChanges = true;
                                    });
                                  },
                                ),
                                getHeight(15),
                                Text(
                                  "Sand Bucket Details",
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
                                  serialLabel: "Sand Buckets - Serial Number",
                                  serialHintText: "Sand Buckets Serial Number",
                                  photoLabel: "Add a Photo",
                                  statusLabel: "Status",
                                  serialController: mpptSerialController,
                                  onSave: _saveMPPTForm,
                                  isStatusEditable: true,
                                  backendStatus: false,
                                  remarksLabel: "Capacity",
                                  remarksHintText: "Eg:200",
                                  remarksController: sandBucketCapacityController,
                                  isRemarksEditable: false,
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
                                              'Extinguisher Screen: MPPT Photo uploaded successfully, photoId: $photoId',
                                            );
                                          }
                                        }
                                      } catch (e) {
                                        print(
                                          'Extinguisher Screen: Error uploading MPPT photo: $e',
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
                                text: "Battery",
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
                                text: _hasDataToShow() ? "Solar Plates" : "Skip",
                                isLeftArrow: false,
                                backgroundColor: AppColors.buttonColorBackBg,
                                textColor: AppColors.buttonColorTextBg,
                                onPressed: () async {
                                  // If no data to show, just navigate to next screen
                                  if (!_hasDataToShow()) {
                                    pushPage(
                                      context,
                                      SolarPlatesScreen(
                                        solarPlatesData:
                                            widget.assetAuditData?.responseData.solarPlates,
                                        assetAuditData: widget.assetAuditData,
                                        showSuccessMessage: false,
                                        extinguisherItems: [
                                          ...savedFireExtinguisherItems,
                                          ...savedFloodLightItems,
                                          ...savedRectifierItems,
                                          ...savedMPPTItems,
                                        ],
                                      ),
                                    );
                                    return;
                                  }
                                  
                                  // Check if user has scanned at least one item
                                  if (!_canProceedToNextScreen()) {
                                    showCustomToast(context, '❌ Please scan at least 1 item before proceeding.');
                                    return;
                                  }
                                  
                                  // Post current screen data before navigating
                                  final success =
                                      await _postCurrentScreenData();
                                  if (success) {
                                    // Navigation will be handled in the BlocListener after API success
                                  } else {
                                    showCustomToast(
                                      context,
                                      '❌ Failed to post data. Please try again.',
                                    );
                                  }
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

  // Build Fire Extinguisher saved items list
  Widget _buildFireExtinguisherSavedItemsList() {
    return Column(
      children: [
        // Header Row - Always show
        Container(
          margin: const EdgeInsets.symmetric(vertical: 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.green7,
            borderRadius: BorderRadius.circular(5),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: const Text(
                        "Serial No.",
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

              // Items - Only show if list is not empty
              if (savedFireExtinguisherItems.isNotEmpty) ...[
                ...savedFireExtinguisherItems.map((item) {
                  print('Building Fire Extinguisher item row for: $item');
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
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            _formatSerialNumber(item["serialNumber"] ?? ""),
                            style: const TextStyle(
                              color: AppColors.color555555,
                              fontSize: 14,
                              fontFamily: fontFamilyMontserrat,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            item["status"] ?? "",
                            style: const TextStyle(
                              color: AppColors.color555555,
                              fontSize: 14,
                              fontFamily: fontFamilyMontserrat,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Icon(
                            item["isQRCodeScanned"] == true
                                ? Icons.check
                                : Icons.close,
                            color: item["isQRCodeScanned"] == true
                                ? Colors.green
                                : Colors.red,
                          ),
                        ),
                        Expanded(
                          child: IconButton(
                            icon: const Icon(
                              Icons.camera_alt,
                              color: AppColors.color555555,
                            ),
                            onPressed: () {
                              // handle photo click
                            },
                          ),
                        ),
                        Expanded(
                          child: IconButton(
                            icon: const Icon(
                              Icons.edit_calendar_outlined,
                              color: AppColors.color555555,
                            ),
                            onPressed: () {
                              // handle edit click for this item
                              _editFireExtinguisherItem(item);
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // Build MPPT saved items list
  Widget _buildMPPTSavedItemsList() {
    return Column(
      children: [
        // Header Row - Always show
        Container(
          margin: const EdgeInsets.symmetric(vertical: 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.green7,
            borderRadius: BorderRadius.circular(5),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: const Text(
                        "Serial No.",
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

              // Items - Only show if list is not empty
              if (savedMPPTItems.isNotEmpty) ...[
                ...savedMPPTItems.map((item) {
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
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            _formatSerialNumber(item["serialNumber"] ?? ""),
                            style: const TextStyle(
                              color: AppColors.color555555,
                              fontSize: 14,
                              fontFamily: fontFamilyMontserrat,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            item["status"] ?? "",
                            style: const TextStyle(
                              color: AppColors.color555555,
                              fontSize: 14,
                              fontFamily: fontFamilyMontserrat,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Icon(
                            item["isQRCodeScanned"] == true
                                ? Icons.check
                                : Icons.close,
                            color: item["isQRCodeScanned"] == true
                                ? Colors.green
                                : Colors.red,
                          ),
                        ),
                        Expanded(
                          child: IconButton(
                            icon: const Icon(
                              Icons.camera_alt,
                              color: AppColors.color555555,
                            ),
                            onPressed: () {
                              // handle photo click
                            },
                          ),
                        ),
                        Expanded(
                          child: IconButton(
                            icon: const Icon(
                              Icons.edit_calendar_outlined,
                              color: AppColors.color555555,
                            ),
                            onPressed: () {
                              // handle edit click for this item
                              _editMPPTItem(item);
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // Build Flood Light saved items list
  Widget _buildFloodLightSavedItemsList() {
    return Column(
      children: [
        // Header Row - Always show
        Container(
          margin: const EdgeInsets.symmetric(vertical: 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.green7,
            borderRadius: BorderRadius.circular(5),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: const Text(
                        "Serial No.",
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

              // Items - Only show if list is not empty
              if (savedFloodLightItems.isNotEmpty) ...[
                ...savedFloodLightItems.map((item) {
                  print('Building Flood Light item row for: $item');
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
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            _formatSerialNumber(item["serialNumber"] ?? ""),
                            style: const TextStyle(
                              color: AppColors.color555555,
                              fontSize: 14,
                              fontFamily: fontFamilyMontserrat,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            item["status"] ?? "",
                            style: const TextStyle(
                              color: AppColors.color555555,
                              fontSize: 14,
                              fontFamily: fontFamilyMontserrat,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Icon(
                            item["isQRCodeScanned"] == true
                                ? Icons.check
                                : Icons.close,
                            color: item["isQRCodeScanned"] == true
                                ? Colors.green
                                : Colors.red,
                          ),
                        ),
                        Expanded(
                          child: IconButton(
                            icon: const Icon(
                              Icons.camera_alt,
                              color: AppColors.color555555,
                            ),
                            onPressed: () {
                              // handle photo click
                            },
                          ),
                        ),
                        Expanded(
                          child: IconButton(
                            icon: const Icon(
                              Icons.edit_calendar_outlined,
                              color: AppColors.color555555,
                            ),
                            onPressed: () {
                              // handle edit click for this item
                              _editFloodLightItem(item);
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ],
          ),
        ),
      ],
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
          
        case 'fireExtinguisher':
          // Populate fire extinguisher form with item data
          // Note: You'll need to add the appropriate controller and variables
          // fireExtinguisherSerialController.text = item['serialNumber'] ?? '';
          // fireExtinguisherSerialNumber = item['serialNumber'] ?? '';
          // fireExtinguisherStatus = item['status'] ?? 'OK';
          // fireExtinguisherPhotoId = item['photoId'];
          // fireExtinguisherPhoto = item['photo'];
          
          // Remove the item from saved list since it's now in the form for editing
          savedFireExtinguisherItems.remove(item);
          currentScannedItems--;
          break;
          
        case 'floodLight':
          // Populate flood light form with item data
          // Note: You'll need to add the appropriate controller and variables
          // floodLightSerialController.text = item['serialNumber'] ?? '';
          // floodLightSerialNumber = item['serialNumber'] ?? '';
          // floodLightStatus = item['status'] ?? 'OK';
          // floodLightPhotoId = item['photoId'];
          // floodLightPhoto = item['photo'];
          
          // Remove the item from saved list since it's now in the form for editing
          savedFloodLightItems.remove(item);
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

