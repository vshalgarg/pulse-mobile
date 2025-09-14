import 'package:app/commonWidgets/custom_buttons/arrow_botton.dart';
import 'package:app/constants/constants_methods.dart';
import 'package:app/utils/asset_audit_navigation_helper.dart';
import 'package:app/utils/asset_audit_post_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:io';
import 'dart:async';

import '../../../bloc/asset_audit_cubit.dart';
import '../../../bloc/asset_audit_state.dart';
import '../../../bloc/asset_audit_photo_upload_cubit.dart';
import '../../../bloc/asset_audit_get_image_cubit.dart';
import '../../../bloc/audit_schedule_status_cubit.dart';
import '../../../commonWidgets/asset_type_card.dart';
import '../../../commonWidgets/custom_dialogs/unsaved_changes_dialog.dart';
import '../../../commonWidgets/custom_form_appbar.dart';
import '../../../commonWidgets/custom_form_field.dart';
import '../../../commonWidgets/custom_radio_options.dart';
import '../../../commonWidgets/custom_remark.dart';
import '../../../commonWidgets/asset_type_card.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_images.dart';
import '../../../constants/constants_strings.dart';
import '../../../models/asset_audit_model.dart';
import '../../home_screen.dart';

class FireExtinguisherScreen extends StatefulWidget {
  final String siteType;
  final String auditSchId;
  final String siteAuditSchId;
  final AssetAuditModel? assetAuditData; // Complete asset audit data

  const FireExtinguisherScreen({
    super.key,
    required this.siteType,
    required this.auditSchId,
    required this.siteAuditSchId,
    this.assetAuditData, // Complete asset audit data
  });

  @override
  State<FireExtinguisherScreen> createState() => _FireExtinguisherScreenState();
}

class _FireExtinguisherScreenState extends State<FireExtinguisherScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController serialController = TextEditingController();
  String? selectedFile;
  String? selectedStatus;
  String? selectedBatteryStatus;
  String? selectedType;
  bool hasUnsavedChanges = false;
  bool showValidationErrors = false; // Control when to show validation errors
  bool _isSavingItem = false; // Flag to control listener behavior during save
  int totalRectifierItems = 0; // Total rectifier items to scan (will be set from API)
  int totalMPPTItems = 0; // Total MPPT items to scan (will be set from API)
  int totalFloodLightItems = 0; // Total flood light items to scan (will be set from API)
  int currentScannedItems = 0; // Number of items already scanned
  List<Map<String, dynamic>> savedRectifierItems = []; // List to store saved rectifier items
  List<Map<String, dynamic>> savedMPPTItems = []; // List to store saved MPPT items
  List<Map<String, dynamic>> savedFireExtinguisherItems = []; // List to store saved fire extinguisher items
  List<Map<String, dynamic>> savedFloodLightItems = []; // List to store saved flood light items
  Map<String, dynamic> currentFormData = {}; // Current form data
  String? uploadedPhotoPath;
  // AssetTypeCard field values for Rectifier
  String? rectifierSerialNumber;
  String? rectifierPhoto;
  String? rectifierStatus;
  bool isRectifierQRCodeScanned = false;
  final remarksController = TextEditingController();
  // AssetTypeCard field values for MPPT
  String? mpptSerialNumber;
  String? mpptPhoto;
  String? mpptStatus;
  bool isMPPTQRCodeScanned = false;
  
  // AssetTypeCard field values for Flood Light
  String? floodLightSerialNumber;
  String? floodLightPhoto;
  String? floodLightStatus;
  bool isFloodLightQRCodeScanned = false;
  
  // Photo upload and image display
  String? uploadedPhotoId;
  String? displayedImageBase64;
  bool isUploadingPhoto = false;
  bool isLoadingImage = false;
  Map<String, String> _imageCache = {}; // Cache for faster image loading
  
  // Image loading tracking to prevent repeated processing
  String? _currentRequestedImageId;
  bool _isRequestingImage = false;
  
  // Stream subscriptions
  StreamSubscription<AssetAuditPhotoUploadState>? _photoUploadSubscription;
  StreamSubscription<AssetAuditGetImageState>? _getImageSubscription;
  
  // Get Fire Extinguisher data from API
  int totalFireExtinguisherItems = 0; // Total fire extinguisher items from API
  
  // Get Fire Extinguisher category data
  CategoryData? get fireExtinguisherCategoryData {
    return widget.assetAuditData?.responseData.categories['Fire Extinguisher'];
  }

  // Controllers for CustomInfoCard
  final TextEditingController rectifierSerialController = TextEditingController();
  final TextEditingController mpptSerialController = TextEditingController();
  final TextEditingController floodLightSerialController = TextEditingController();

  // Keys to force rebuild of CustomInfoCard widgets
  int rectifierCardKey = 0;
  int mpptCardKey = 0;
  int fireExtinguisherCardKey = 0;
  int floodLightCardKey = 0;

  @override
  void initState() {
    super.initState();
    // Listen to form changes
    serialController.addListener(_onFormChanged);
    rectifierSerialController.addListener(_onFormChanged);
    mpptSerialController.addListener(_onFormChanged);
    floodLightSerialController.addListener(_onFormChanged);
    remarksController.addListener(_onFormChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Sync initial data from widget.assetAuditData (only if not currently saving)
    if (widget.assetAuditData != null && !_isSavingItem) {
      final fireExtinguisherData = widget.assetAuditData!.responseData.categories['Fire Extinguisher'];
      if (fireExtinguisherData != null) {
        setState(() {
          // Load Fire Extinguisher items that have been posted AND have user interaction (photo OR QR scanned)
          final fireExtinguisherAssets = fireExtinguisherData.assets.where((asset) =>
            asset.assetAuditSiteRespId != null &&
            (asset.photoId != null || asset.qrCodeScanned == true)
          ).map((asset) {
            return {
              'serialNumber': asset.mfgSerialNo ?? asset.nexgenSerialNo ?? '',
              'photo': asset.photoId?.toString(),
              'status': asset.assetStatus ?? 'OK',
              'isQRCodeScanned': asset.qrCodeScanned ?? false,
              'timestamp': DateTime.now(),
              'assetAuditSiteRespId': asset.assetAuditSiteRespId,
            };
          }).toList();
          
          // Load Flood Light items from subCategories that have been posted AND have user interaction (photo/QR)
          final floodLightAssets = <Map<String, dynamic>>[];
          if (fireExtinguisherData.subCategories != null && fireExtinguisherData.subCategories!['Flood Light'] != null) {
            floodLightAssets.addAll(fireExtinguisherData.subCategories!['Flood Light']!.where((asset) =>
              asset.assetAuditSiteRespId != null &&
              (asset.photoId != null || asset.qrCodeScanned == true)
            ).map((asset) {
              return {
                'serialNumber': asset.mfgSerialNo ?? asset.nexgenSerialNo ?? '',
                'photo': asset.photoId?.toString(),
                'status': asset.assetStatus ?? 'OK',
                'isQRCodeScanned': asset.qrCodeScanned ?? false,
                'timestamp': DateTime.now(),
                'assetAuditSiteRespId': asset.assetAuditSiteRespId,
              };
            }).toList());
          }
          
          // Load Sand Bucket items from subCategories that have been posted AND have user interaction (photo/QR)
          final sandBucketAssets = <Map<String, dynamic>>[];
          if (fireExtinguisherData.subCategories != null && fireExtinguisherData.subCategories!['Sand Bucket'] != null) {
            sandBucketAssets.addAll(fireExtinguisherData.subCategories!['Sand Bucket']!.where((asset) =>
              asset.assetAuditSiteRespId != null &&
              (asset.photoId != null || asset.qrCodeScanned == true)
            ).map((asset) {
              return {
                'serialNumber': asset.mfgSerialNo ?? asset.nexgenSerialNo ?? '',
                'photo': asset.photoId?.toString(),
                'status': asset.assetStatus ?? 'OK',
                'isQRCodeScanned': asset.qrCodeScanned ?? false,
                'timestamp': DateTime.now(),
                'assetAuditSiteRespId': asset.assetAuditSiteRespId,
              };
            }).toList());
          }
          
          // Merge API data with local unsaved items to preserve local changes
          final localUnsavedRectifierItems = savedRectifierItems.where((item) => item['assetAuditSiteRespId'] == null).toList();
          final localUnsavedFloodLightItems = savedFloodLightItems.where((item) => item['assetAuditSiteRespId'] == null).toList();
          final localUnsavedMPPTItems = savedMPPTItems.where((item) => item['assetAuditSiteRespId'] == null).toList();
          
          // Combine API data with local unsaved items
          savedRectifierItems = [...fireExtinguisherAssets, ...localUnsavedRectifierItems];
          savedFloodLightItems = [...floodLightAssets, ...localUnsavedFloodLightItems];
          savedMPPTItems = [...sandBucketAssets, ...localUnsavedMPPTItems]; // Using MPPT list for Sand Buckets
          
          // Count items by type from API data
          totalFireExtinguisherItems = fireExtinguisherData.assets.length; // Fire Extinguisher items are in the main assets array
          totalRectifierItems = fireExtinguisherData.assets.length; // Fire Extinguisher items are in the main assets array
          totalMPPTItems = fireExtinguisherData.subCategories?['Sand Bucket']?.length ?? 0; // Sand Bucket items are in subCategories
          totalFloodLightItems = fireExtinguisherData.subCategories?['Flood Light']?.length ?? 0; // Flood Light items are in subCategories
          
          // Only load remarks from API if user hasn't made changes
          if (remarksController.text.isEmpty) {
            remarksController.text = fireExtinguisherData.remarks.isNotEmpty
                ? fireExtinguisherData.remarks.first.itemTypeRemark ?? ''
                : '';
          }
        });
      }
    }

    // Only load fresh data if we don't already have it
    if (widget.assetAuditData == null) {
      context.read<AssetAuditCubit>().getAssetAuditData(
        siteType: widget.siteType,
        auditSchId: widget.auditSchId,
        siteAuditSchId: widget.siteAuditSchId,
      );
    }
  }

  @override
  void dispose() {
    serialController.removeListener(_onFormChanged);
    rectifierSerialController.removeListener(_onFormChanged);
    mpptSerialController.removeListener(_onFormChanged);
    floodLightSerialController.removeListener(_onFormChanged);
    remarksController.removeListener(_onFormChanged);
    serialController.dispose();
    rectifierSerialController.dispose();
    mpptSerialController.dispose();
    floodLightSerialController.dispose();
    remarksController.dispose();
    super.dispose();
  }

  void _onFormChanged() {
    setState(() {
      final hasLocalPhoto = rectifierPhoto != null && rectifierPhoto!.isNotEmpty ||
          mpptPhoto != null && mpptPhoto!.isNotEmpty ||
          floodLightPhoto != null && floodLightPhoto!.isNotEmpty;
      final hasImageData = displayedImageBase64 != null && displayedImageBase64!.isNotEmpty;

      hasUnsavedChanges =
          selectedFile != null ||
          selectedStatus != null ||
          selectedBatteryStatus != null ||
          selectedType != null ||
          serialController.text.isNotEmpty ||
          rectifierSerialController.text.isNotEmpty ||
          mpptSerialController.text.isNotEmpty ||
          floodLightSerialController.text.isNotEmpty ||
          hasLocalPhoto ||
          hasImageData ||
          savedRectifierItems.isNotEmpty ||
          savedMPPTItems.isNotEmpty ||
          savedFloodLightItems.isNotEmpty ||
          remarksController.text.isNotEmpty;

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



  Future<void> _saveAndExit() async {
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // Post Fire Extinguisher data to API first
      await _postFireExtinguisherData();
      
      // Update audit schedule status
      await _updateAuditScheduleStatus("In Progress");

      // Close loading dialog
      Navigator.of(context).pop();

      // Navigate to home screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
            builder: (context) => HomeScreen()
        ),
      );
    } catch (e) {
      // Close loading dialog if it's open
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
      
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving data: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _updateAuditScheduleStatus(String status) async {
    try {
      print('Attempting to update status to: $status'); // Added for debugging
      await context.read<AuditScheduleStatusCubit>().updateStatus(
        status: status,
        siteAuditSchId: widget.siteAuditSchId,
      );
      print('Status update call completed'); // Added for debugging
    } catch (e) {
      print('Error updating audit schedule status: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update status: $e')),
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

    // Check if either photo is provided OR item is QR scanned
    // Check both photo variables to see which one has data
    String? photo = rectifierPhoto ?? mpptPhoto;
    bool hasPhoto = photo != null && photo.isNotEmpty;
    bool isQRScanned = isRectifierQRCodeScanned || isMPPTQRCodeScanned; // true for QR scanned, false for manual entry
    
    print('Photo: $photo');
    print('Has Photo: $hasPhoto');
    print('Is QR Scanned: $isQRScanned');
    
    // Allow saving if serial number is provided (photo and QR scan are optional)
    // The photo/QR validation is only for displaying items in the saved list
    print('✅ Validation passed: Serial number provided');

    // Note: status is not required since it comes from API
    // and is set to true by default (backendStatus: true)
    String? status = rectifierStatus ?? mpptStatus;
    print('Status: $status (not required)');

    print(' All validations passed!');
    return true;
  }

  // Serial number validation
  bool _validateSerialNumber(String serialNumber, bool isQrScanned) {
    if (fireExtinguisherCategoryData?.assets == null || fireExtinguisherCategoryData!.assets.isEmpty) {
      return false;
    }

    for (var asset in fireExtinguisherCategoryData!.assets) {
      if (isQrScanned) {
        // For QR scanned, compare with nexgen_serial_no
        if (asset.nexgenSerialNo == serialNumber) {
          return true;
        }
      } else {
        // For manual entry, compare with mfg_serial_no
        if (asset.mfgSerialNo == serialNumber) {
          return true;
        }
      }
    }
    return false;
  }

  // Upload photo and return photo ID
  Future<String?> _uploadPhoto(File file) async {
    try {
      print('=== Fire Extinguisher Photo Upload Started ===');
      print('File path: ${file.path}');
      print('File exists: ${await file.exists()}');
      print('File size: ${await file.length()} bytes');

      final assetAuditState = context.read<AssetAuditCubit>().state;
      if (assetAuditState is AssetAuditLoaded && assetAuditState.assetAuditData.pageHeader.isNotEmpty) {
        final schId = assetAuditState.assetAuditData.pageHeader.first.siteAuditSchId.toString();
        print('Site Audit Sch ID: $schId');

        final imgIdToUse = "0";
        print('Image ID to use: $imgIdToUse');

        final completer = Completer<String?>();
        
        late StreamSubscription subscription;
        subscription = context.read<AssetAuditPhotoUploadCubit>().stream.listen((state) {
          print('=== AssetAuditPhotoUploadCubit State Changed ===');
          print('State type: ${state.runtimeType}');
          
          if (state is AssetAuditPhotoUploadSuccess) {
            print('✅ Fire Extinguisher Photo upload successful: ${state.response.imgId}');
            subscription.cancel();
            completer.complete(state.response.imgId);
          } else if (state is AssetAuditPhotoUploadFailure) {
            print('❌ Fire Extinguisher Photo upload failed: ${state.errorMessage}');
            subscription.cancel();
            // Return null instead of throwing error to continue without photo upload
            completer.complete(null);
          } else if (state is AssetAuditPhotoUploadLoading) {
            print('⏳ Fire Extinguisher Photo upload in progress...');
          }
        });

        print('📤 Starting Fire Extinguisher photo upload...');
        
        // Reset the photo upload cubit state before uploading
        context.read<AssetAuditPhotoUploadCubit>().reset();
        
        context.read<AssetAuditPhotoUploadCubit>().uploadPhoto(
          file: file,
          imgId: imgIdToUse,
          schId: schId,
        );

        return await completer.future.timeout(
          const Duration(seconds: 30),
          onTimeout: () {
            print('⏰ Photo upload timeout after 30 seconds');
            subscription.cancel();
            return null;
          },
        );
      } else {
        print('❌ No asset audit data available for photo upload');
        return null;
      }
    } catch (e) {
      print('❌ Error uploading Fire Extinguisher photo: $e');
      return null;
    }
  }

  // Check if string is numeric (photo ID)
  bool _isNumeric(String str) {
    return int.tryParse(str) != null;
  }

  // POST Fire Extinguisher data to API
  Future<bool> _postFireExtinguisherData() async {
    try {
      print('Fire Extinguisher Screen: Starting to post Fire Extinguisher data...');
      
      // Get current location
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      final assetAuditState = context.read<AssetAuditCubit>().state;
      if (assetAuditState is! AssetAuditLoaded) {
        print('Fire Extinguisher Screen: Asset audit data not loaded');
        return false;
      }
      
      final siteData = assetAuditState.assetAuditData?.pageHeader.first;
      if (siteData == null) {
        print('Fire Extinguisher Screen: Site data is null');
        return false;
      }

      // Prepare all items to post (including remarks)
      final List<Map<String, dynamic>> allItemsToPost = [];

      // Add saved Fire Extinguisher items
      if (savedRectifierItems.isNotEmpty || savedMPPTItems.isNotEmpty || savedFloodLightItems.isNotEmpty) {
        // Prepare items with their respective item types
        final List<Map<String, dynamic>> allSavedItems = [];
        
        // Add Fire Extinguisher items
        for (var item in savedRectifierItems) {
          allSavedItems.add({
            ...item,
            'itemType': 'Fire Extinguisher',
          });
        }
        
        // Add Flood Light items
        for (var item in savedFloodLightItems) {
          allSavedItems.add({
            ...item,
            'itemType': 'Flood Light',
          });
        }
        
        // Add Sand Bucket items (using MPPT list)
        for (var item in savedMPPTItems) {
          allSavedItems.add({
            ...item,
            'itemType': 'Sand Bucket',
          });
        }
        
        // Convert each item type separately to ensure proper asset matching
        if (savedRectifierItems.isNotEmpty) {
          print('Fire Extinguisher Screen: Processing ${savedRectifierItems.length} Fire Extinguisher items');
          for (var item in savedRectifierItems) {
            print('Fire Extinguisher item: serialNumber=${item['serialNumber']}, photo=${item['photo']}, status=${item['status']}');
            print('Full item data: $item');
          }
          
          // Enhance saved items like other screens do
          final enhancedItems = AssetAuditPostHelper.enhanceSavedItems(
            savedItems: savedRectifierItems,
            screenName: 'solar_fire_extinguisher',
          );
          
          final fireExtinguisherRequests = await AssetAuditPostHelper.convertSavedItemsToPostRequest(
            savedItems: enhancedItems,
            assetAuditData: widget.assetAuditData!,
            itemType: 'Fire Extinguisher',
            itemTypeId: AssetAuditPostHelper.getItemTypeId('fire_extinguisher'),
            screenName: 'solar_fire_extinguisher',
            context: context,
            auditSchId: widget.auditSchId,
          );
          allItemsToPost.addAll(fireExtinguisherRequests.map((request) => request.toJson()).toList());
        }
        
        if (savedFloodLightItems.isNotEmpty) {
          print('Fire Extinguisher Screen: Processing ${savedFloodLightItems.length} Flood Light items');
          for (var item in savedFloodLightItems) {
            print('Flood Light item: serialNumber=${item['serialNumber']}, photo=${item['photo']}, status=${item['status']}');
          }
          
          // Enhance saved items like other screens do
          final enhancedItems = AssetAuditPostHelper.enhanceSavedItems(
            savedItems: savedFloodLightItems,
            screenName: 'solar_fire_extinguisher',
          );
          
          final floodLightRequests = await AssetAuditPostHelper.convertSavedItemsToPostRequest(
            savedItems: enhancedItems,
            assetAuditData: widget.assetAuditData!,
            itemType: 'Flood Light',
            itemTypeId: AssetAuditPostHelper.getItemTypeId('flood_light'),
            screenName: 'solar_fire_extinguisher',
            context: context,
            auditSchId: widget.auditSchId,
          );
          allItemsToPost.addAll(floodLightRequests.map((request) => request.toJson()).toList());
        }
        
        if (savedMPPTItems.isNotEmpty) {
          print('Fire Extinguisher Screen: Processing ${savedMPPTItems.length} Sand Bucket items');
          for (var item in savedMPPTItems) {
            print('Sand Bucket item: serialNumber=${item['serialNumber']}, photo=${item['photo']}, status=${item['status']}');
          }
          
          // Enhance saved items like other screens do
          final enhancedItems = AssetAuditPostHelper.enhanceSavedItems(
            savedItems: savedMPPTItems,
            screenName: 'solar_fire_extinguisher',
          );
          
          final sandBucketRequests = await AssetAuditPostHelper.convertSavedItemsToPostRequest(
            savedItems: enhancedItems,
            assetAuditData: widget.assetAuditData!,
            itemType: 'Sand Bucket',
            itemTypeId: AssetAuditPostHelper.getItemTypeId('sand_bucket'),
            screenName: 'solar_fire_extinguisher',
            context: context,
            auditSchId: widget.auditSchId,
          );
          allItemsToPost.addAll(sandBucketRequests.map((request) => request.toJson()).toList());
        }
      }

      // Add remarks as a separate item if any
      if (remarksController.text.trim().isNotEmpty) {
        final remarksAssetAuditSiteRespId = _getRemarksAssetAuditSiteRespId();
        if (remarksAssetAuditSiteRespId != null) {
          Map<String, dynamic> remarksData = {
            'recordType': 'remarks',
            'itemType': 'Fire Extinguisher',
            'remarks': remarksController.text.trim(),
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

      // Convert to AssetAuditPostRequest
      final requests = await AssetAuditPostHelper.convertSavedItemsToPostRequest(
        savedItems: allItemsToPost,
        assetAuditData: assetAuditState.assetAuditData,
        itemType: 'Fire Extinguisher',
        itemTypeId: 9, // Fire Extinguisher item type ID
        screenName: 'solar_fire_extinguisher',
        context: context,
        auditSchId: widget.auditSchId,
      );

      print('Fire Extinguisher Screen: Converted ${requests.length} items to post requests');

      // Post each request
      if (requests.isNotEmpty) {
        // Use Completer to wait for API response
        final completer = Completer<bool>();
        
        // Set up a one-time listener for the API response
        late StreamSubscription subscription;
        subscription = context.read<AssetAuditCubit>().stream.listen((state) {
          if (state is AssetAuditPostSuccess) {
            subscription.cancel();
            print('Fire Extinguisher Screen: All Fire Extinguisher data posted successfully');
            completer.complete(true);
          } else if (state is AssetAuditPostError) {
            subscription.cancel();
            print('Fire Extinguisher Screen: Error posting data: ${state.message}');
            completer.complete(false);
          }
        });
        
        // Store the current remarks text before posting
        final currentRemarksText = remarksController.text;
        print('Fire Extinguisher Screen: Storing current remarks text: "$currentRemarksText"');

        // Start the API call
        context.read<AssetAuditCubit>().postAssetAuditData(requests: requests);
        
        // Wait for the response with a timeout
        final result = await completer.future.timeout(
          const Duration(seconds: 30),
          onTimeout: () {
            subscription.cancel();
            print('Fire Extinguisher Screen: API call timed out');
            return false;
          },
        );

        // If posting was successful, refresh data and restore remarks
        if (result) {
          print('Refreshing Fire Extinguisher data after posting...');
          context.read<AssetAuditCubit>().getAssetAuditData(
            siteType: widget.siteType,
            auditSchId: widget.auditSchId,
            siteAuditSchId: widget.siteAuditSchId,
          );
          
          // Restore the remarks text after refresh to ensure it's not overwritten
          if (currentRemarksText.isNotEmpty) {
            print('Fire Extinguisher Screen: Restoring remarks text after refresh: "$currentRemarksText"');
            remarksController.text = currentRemarksText;
          }
        }

        return result;
      } else {
        print('Fire Extinguisher Screen: No data to post');
        return true; // Return true if no data to post (not an error)
      }
    } catch (e) {
      print('Fire Extinguisher Screen: Error posting data: $e');
      return false; // Return false to indicate error
    }
  }

  // Helper method to get remarks asset audit site resp ID
  String? _getRemarksAssetAuditSiteRespId() {
    final fireExtinguisherData = widget.assetAuditData?.responseData.categories['Fire Extinguisher'];
    if (fireExtinguisherData != null && fireExtinguisherData.remarks.isNotEmpty) {
      for (var remark in fireExtinguisherData.remarks) {
        if (remark.assetAuditSiteRespId != null &&
            remark.assetAuditSiteRespId > 0 &&
            (remark.itemType == 'Fire Extinguisher' || remark.itemType == null)) {
          return remark.assetAuditSiteRespId.toString();
        }
      }
      if (fireExtinguisherData.remarks.isNotEmpty) {
        return fireExtinguisherData.remarks.first.assetAuditSiteRespId?.toString();
      }
    }
    if (fireExtinguisherCategoryData?.assets.isNotEmpty == true) {
      return fireExtinguisherCategoryData!.assets.first.assetAuditSiteRespId?.toString();
    }
    return null;
  }

  // Helper method to get the next available screen based on data availability
  String? _getNextAvailableScreen() {
    return AssetAuditNavigationHelper.getNextAvailableScreen(widget.assetAuditData, 'Fire Extinguisher');
  }

  // Helper method to get the previous available screen based on data availability
  String? _getPreviousAvailableScreen() {
    return AssetAuditNavigationHelper.getPreviousAvailableScreen(widget.assetAuditData, 'Fire Extinguisher');
  }

  // Helper method to navigate to the next screen based on screen name
  void _navigateToNextScreen(BuildContext context, String screenName) {
    AssetAuditNavigationHelper.navigateToNextScreen(
      context,
      screenName,
      widget.siteType,
      widget.auditSchId,
      widget.siteAuditSchId,
      widget.assetAuditData,
    );
  }


  void _saveRectifierForm() async {
    // Check if we've reached the limit for rectifier items (only count items that meet display criteria)
    final validRectifierItems = savedRectifierItems.where((item) {
      bool hasPhoto = item['photo'] != null && item['photo'].toString().isNotEmpty;
      bool isQRScanned = item['isQRCodeScanned'] == true;
      bool isPosted = item['assetAuditSiteRespId'] != null;
      return isPosted || (hasPhoto || isQRScanned);
    }).length;
    
    if (validRectifierItems >= totalRectifierItems) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Maximum number of Rectifier items ($totalRectifierItems) already added.',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontFamily: fontFamilyMontserrat,
            ),
          ),
          backgroundColor: AppColors.errorColor,
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    if (_isFormValid()) {
      _isSavingItem = true; // Set flag to prevent listener conflicts
      
      // Upload photo if it exists and is a file path
      String? photoId = rectifierPhoto;
      if (rectifierPhoto != null && rectifierPhoto!.isNotEmpty && !rectifierPhoto!.startsWith('http') && !_isNumeric(rectifierPhoto!)) {
        try {
          final file = File(rectifierPhoto!);
          if (await file.exists()) {
            print('📤 Uploading Fire Extinguisher photo: ${rectifierPhoto}');
            photoId = await _uploadPhoto(file);
            print('✅ Fire Extinguisher photo uploaded successfully, image ID: $photoId');
          } else {
            print('❌ Fire Extinguisher photo file does not exist: ${rectifierPhoto}');
            photoId = null; // Set to null if file doesn't exist
          }
        } catch (e) {
          print('❌ Error uploading Fire Extinguisher photo: $e');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error uploading photo: $e'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
          _isSavingItem = false;
          return;
        }
      }
      
      setState(() {
        // Create a map of current form data
        Map<String, dynamic> currentFormData = {
          'serialNumber': rectifierSerialNumber,
          'photo': photoId, // Store photoId instead of file path
          'status': rectifierStatus ?? "OK", // Default to "OK" if null (since it comes from API)
          'isQRCodeScanned': isRectifierQRCodeScanned, // true for QR scanned, false for manual entry
          'timestamp': DateTime.now(),
        };

        print('Saving Rectifier item: $currentFormData');
        print('Photo ID being stored: $photoId');
        print('Serial number being stored: ${rectifierSerialNumber}');
        print('Controller text: ${rectifierSerialController.text}');
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

      // Reset flag immediately
      _isSavingItem = false;

      // Show success message
      int remainingRectifiers = totalRectifierItems - validRectifierItems;
    } else {
      print('Form validation failed - cannot save rectifier item');
    }
  }

  // Save current form data for MPPT
  void _saveMPPTForm() async {
    // Check if we've reached the limit for MPPT items (only count items that meet display criteria)
    final validMPPTItems = savedMPPTItems.where((item) {
      bool hasPhoto = item['photo'] != null && item['photo'].toString().isNotEmpty;
      bool isQRScanned = item['isQRCodeScanned'] == true;
      bool isPosted = item['assetAuditSiteRespId'] != null;
      return isPosted || (hasPhoto || isQRScanned);
    }).length;
    
    if (validMPPTItems >= totalMPPTItems) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Maximum number of MPPT items ($totalMPPTItems) already added.',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontFamily: fontFamilyMontserrat,
            ),
          ),
          backgroundColor: AppColors.errorColor,
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    if (_isFormValid()) {
      _isSavingItem = true; // Set flag to prevent listener conflicts
      
      // Upload photo if it exists and is a file path
      String? photoId = mpptPhoto;
      if (mpptPhoto != null && mpptPhoto!.isNotEmpty && !mpptPhoto!.startsWith('http') && !_isNumeric(mpptPhoto!)) {
        try {
          final file = File(mpptPhoto!);
          if (await file.exists()) {
            print('📤 Uploading Sand Bucket photo: ${mpptPhoto}');
            photoId = await _uploadPhoto(file);
            print('✅ Sand Bucket photo uploaded successfully, image ID: $photoId');
          } else {
            print('❌ Sand Bucket photo file does not exist: ${mpptPhoto}');
            photoId = null; // Set to null if file doesn't exist
          }
        } catch (e) {
          print('❌ Error uploading Sand Bucket photo: $e');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error uploading photo: $e'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
          _isSavingItem = false;
          return;
        }
      }
      
      setState(() {
        // Create a map of current form data
        Map<String, dynamic> currentFormData = {
          'serialNumber': mpptSerialNumber,
          'photo': photoId, // Store photoId instead of file path
          'status': mpptStatus ?? "OK", // Default to "OK" if null (since it comes from API)
          'isQRCodeScanned': isMPPTQRCodeScanned, // true for QR scanned, false for manual entry
          'timestamp': DateTime.now(),
        };

        print('Saving MPPT item: $currentFormData');
        print('Photo ID being stored: $photoId');
        print('Serial number being stored: ${mpptSerialNumber}');
        print('Controller text: ${mpptSerialController.text}');
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

      // Reset flag immediately
      _isSavingItem = false;

      // Show success message
      int remainingMPPTs = totalMPPTItems - validMPPTItems;
    } else {
      print('Form validation failed - cannot save MPPT item');
    }
  }

  // Check if all items are scanned
  bool _isAllItemsScanned() {
    // Count only items that meet display criteria (posted OR have photo/QR)
    final validRectifierItems = savedRectifierItems.where((item) {
      bool hasPhoto = item['photo'] != null && item['photo'].toString().isNotEmpty;
      bool isQRScanned = item['isQRCodeScanned'] == true;
      bool isPosted = item['assetAuditSiteRespId'] != null;
      return isPosted || (hasPhoto || isQRScanned);
    }).length;
    
    final validMPPTItems = savedMPPTItems.where((item) {
      bool hasPhoto = item['photo'] != null && item['photo'].toString().isNotEmpty;
      bool isQRScanned = item['isQRCodeScanned'] == true;
      bool isPosted = item['assetAuditSiteRespId'] != null;
      return isPosted || (hasPhoto || isQRScanned);
    }).length;
    
    return (validRectifierItems >= totalRectifierItems) &&
        (validMPPTItems >= totalMPPTItems);
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

    // Load image with caching for faster loading
    if (rectifierPhoto != null && rectifierPhoto!.isNotEmpty && _isNumeric(rectifierPhoto!)) {
      // Check cache first
      if (_imageCache.containsKey(rectifierPhoto!)) {
        setState(() {
          displayedImageBase64 = _imageCache[rectifierPhoto!];
          isLoadingImage = false;
        });
      } else {
        // Fetch from API if not in cache
        setState(() {
          _currentRequestedImageId = rectifierPhoto;
          _isRequestingImage = true;
          isLoadingImage = true;
        });
        context.read<AssetAuditGetImageCubit>().getImage(
          imgId: rectifierPhoto!,
          schId: widget.siteAuditSchId,
        );
      }
    }
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

    // Load image with caching for faster loading
    if (mpptPhoto != null && mpptPhoto!.isNotEmpty && _isNumeric(mpptPhoto!)) {
      // Check cache first
      if (_imageCache.containsKey(mpptPhoto!)) {
        setState(() {
          displayedImageBase64 = _imageCache[mpptPhoto!];
          isLoadingImage = false;
        });
      } else {
        // Fetch from API if not in cache
        setState(() {
          _currentRequestedImageId = mpptPhoto;
          _isRequestingImage = true;
          isLoadingImage = true;
        });
        context.read<AssetAuditGetImageCubit>().getImage(
          imgId: mpptPhoto!,
          schId: widget.siteAuditSchId,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<AssetAuditGetImageCubit, AssetAuditGetImageState>(
          listener: (context, state) {
            // Only handle images for the main form, not for saved items
            // This listener should only be triggered when editing an item from the main form
            if (state is AssetAuditGetImageSuccess && 
                _isRequestingImage && 
                _currentRequestedImageId != null) {
              String finalImageData = state.imageData.startsWith('data:image/')
                  ? state.imageData
                  : 'data:image/jpeg;base64,${state.imageData}';
              
              // Cache the image for faster loading
              _imageCache[_currentRequestedImageId!] = finalImageData;
              
              setState(() {
                displayedImageBase64 = finalImageData;
                isLoadingImage = false;
                fireExtinguisherCardKey++;
                _isRequestingImage = false;
                _currentRequestedImageId = null;
              });
            } else if (state is AssetAuditGetImageFailure && _isRequestingImage) {
              setState(() {
                displayedImageBase64 = null;
                isLoadingImage = false;
                fireExtinguisherCardKey++;
                _isRequestingImage = false;
                _currentRequestedImageId = null;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Failed to load image: ${state.errorMessage}'),
                  backgroundColor: Colors.red,
                  duration: const Duration(seconds: 3),
                ),
              );
            } else if (state is AssetAuditGetImageLoading && _isRequestingImage) {
              setState(() {
                isLoadingImage = true;
              });
            }
          },
        ),
        BlocListener<AssetAuditCubit, AssetAuditState>(
          listener: (context, state) {
            if (state is AssetAuditLoaded && !_isSavingItem) {
              final fireExtinguisherData = state.assetAuditData.responseData.categories['Fire Extinguisher'];
              if (fireExtinguisherData != null) {
                setState(() {
                  // Load Fire Extinguisher items that have been posted AND have user interaction (photo/QR)
                  final fireExtinguisherAssets = fireExtinguisherData.assets.where((asset) =>
                    asset.assetAuditSiteRespId != null &&
                    (asset.photoId != null || asset.qrCodeScanned == true)
                  ).map((asset) {
                    return {
                      'serialNumber': asset.mfgSerialNo ?? asset.nexgenSerialNo ?? '',
                      'photo': asset.photoId?.toString(),
                      'status': asset.assetStatus ?? 'OK',
                      'isQRCodeScanned': asset.qrCodeScanned ?? false,
                      'timestamp': DateTime.now(),
                      'assetAuditSiteRespId': asset.assetAuditSiteRespId,
                    };
                  }).toList();
                  
                  // Load Flood Light items from subCategories that have been posted AND have user interaction (photo/QR)
                  final floodLightAssets = <Map<String, dynamic>>[];
                  if (fireExtinguisherData.subCategories != null && fireExtinguisherData.subCategories!['Flood Light'] != null) {
                    floodLightAssets.addAll(fireExtinguisherData.subCategories!['Flood Light']!.where((asset) =>
                      asset.assetAuditSiteRespId != null &&
                      (asset.photoId != null || asset.qrCodeScanned == true)
                    ).map((asset) {
                      return {
                        'serialNumber': asset.mfgSerialNo ?? asset.nexgenSerialNo ?? '',
                        'photo': asset.photoId?.toString(),
                        'status': asset.assetStatus ?? 'OK',
                        'isQRCodeScanned': asset.qrCodeScanned ?? false,
                        'timestamp': DateTime.now(),
                        'assetAuditSiteRespId': asset.assetAuditSiteRespId,
                      };
                    }).toList());
                  }
                  
                  // Load Sand Bucket items from subCategories that have been posted AND have user interaction (photo/QR)
                  final sandBucketAssets = <Map<String, dynamic>>[];
                  if (fireExtinguisherData.subCategories != null && fireExtinguisherData.subCategories!['Sand Bucket'] != null) {
                    sandBucketAssets.addAll(fireExtinguisherData.subCategories!['Sand Bucket']!.where((asset) =>
                      asset.assetAuditSiteRespId != null &&
                      (asset.photoId != null || asset.qrCodeScanned == true)
                    ).map((asset) {
                      return {
                        'serialNumber': asset.mfgSerialNo ?? asset.nexgenSerialNo ?? '',
                        'photo': asset.photoId?.toString(),
                        'status': asset.assetStatus ?? 'OK',
                        'isQRCodeScanned': asset.qrCodeScanned ?? false,
                        'timestamp': DateTime.now(),
                        'assetAuditSiteRespId': asset.assetAuditSiteRespId,
                      };
                    }).toList());
                  }
                  
                  // Merge API data with local unsaved items
                  // Keep local unsaved items (those without assetAuditSiteRespId)
                  final localUnsavedRectifierItems = savedRectifierItems.where((item) => item['assetAuditSiteRespId'] == null).toList();
                  final localUnsavedFloodLightItems = savedFloodLightItems.where((item) => item['assetAuditSiteRespId'] == null).toList();
                  final localUnsavedMPPTItems = savedMPPTItems.where((item) => item['assetAuditSiteRespId'] == null).toList();
                  
                  // Combine API data with local unsaved items
                  savedRectifierItems = [...fireExtinguisherAssets, ...localUnsavedRectifierItems];
                  savedFloodLightItems = [...floodLightAssets, ...localUnsavedFloodLightItems];
                  savedMPPTItems = [...sandBucketAssets, ...localUnsavedMPPTItems]; // Using MPPT list for Sand Buckets
                  
                  // Count items by type from API data
                  totalFireExtinguisherItems = fireExtinguisherData.assets.length; // Fire Extinguisher items are in the main assets array
                  totalRectifierItems = fireExtinguisherData.assets.length; // Fire Extinguisher items are in the main assets array
                  totalMPPTItems = fireExtinguisherData.subCategories?['Sand Bucket']?.length ?? 0; // Sand Bucket items are in subCategories
                  totalFloodLightItems = fireExtinguisherData.subCategories?['Flood Light']?.length ?? 0; // Flood Light items are in subCategories
                  
                  // Only load remarks from API if user hasn't made changes
                  if (remarksController.text.isEmpty) {
                    remarksController.text = fireExtinguisherData.remarks.isNotEmpty
                        ? fireExtinguisherData.remarks.first.itemTypeRemark ?? ''
                        : '';
                  }
                });
              }
            } else if (state is AssetAuditPostSuccess) {
              // Only refresh data if there are no local unsaved items
              final hasLocalUnsavedItems = savedRectifierItems.any((item) => item['assetAuditSiteRespId'] == null) ||
                                         savedFloodLightItems.any((item) => item['assetAuditSiteRespId'] == null) ||
                                         savedMPPTItems.any((item) => item['assetAuditSiteRespId'] == null);
              
              if (!hasLocalUnsavedItems) {
                context.read<AssetAuditCubit>().getAssetAuditData(
                  siteType: widget.siteType,
                  auditSchId: widget.auditSchId,
                  siteAuditSchId: widget.siteAuditSchId,
                );
              }
            } else if (state is AssetAuditError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message ?? 'Error loading data'),
                  backgroundColor: Colors.red,
                  duration: const Duration(seconds: 3),
                ),
              );
            } else if (state is AssetAuditPostSuccess) {
              context.read<AssetAuditCubit>().getAssetAuditData(
                siteType: widget.siteType,
                auditSchId: widget.auditSchId,
                siteAuditSchId: widget.siteAuditSchId,
              );
            } else if (state is AssetAuditPostError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message ?? 'Error saving data'),
                  backgroundColor: Colors.red,
                  duration: const Duration(seconds: 3),
                ),
              );
            }
          },
        ),
      ],
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
                Navigator.of(context).pop(); // Close the dialog first
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
                    Navigator.of(context).pop(); // Close the dialog first
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
                              CustomOptionSelector(
                                label: "Fire Extinguisher Availability (Yes/No)",
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
                                label:"Count of Fire Extinguisher",
                                // "Number of ${selectedType ?? 'Batteries'}",
                                initialValue: totalRectifierItems.toString(),
                                isRequired: true,
                                isEditable: true,
                                onChanged: (value) {
                                  setState(() {
                                    totalRectifierItems = int.tryParse(value) ?? 0;
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
                                key: ValueKey('fire_extinguisher_$rectifierCardKey'),
                                serialLabel: "Fire Extinguisher - Serial Number *",
                                serialHintText: "Fire Extinguisher Serial Number",
                                photoLabel: "Add a Photo",
                                statusLabel: "Status",
                                serialController: rectifierSerialController,
                                // showSaveButton: false,
                                onSave: _saveRectifierForm,
                                isStatusEditable: true,
                                backendStatus: false,
                                remarksLabel: fireExtinguisherCategoryData?.assets.isNotEmpty == true
                                    ? 'Fire Extinguisher (${fireExtinguisherCategoryData!.assets.first.capacity ?? 'N/A'})'
                                    : 'Fire Extinguisher (Capacity)',
                                remarksHintText: fireExtinguisherCategoryData?.assets.isNotEmpty == true
                                    ? fireExtinguisherCategoryData!.assets.first.capacity ?? "N/A"
                                    : "N/A",
                                remarksController: null,
                                isRemarksEditable: false,
                                onPhotoTap: (photoPath) {
                                  setState(() {
                                    rectifierPhoto = photoPath;
                                    hasUnsavedChanges = true;
                                  });
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
                              CustomFormField(
                                label:"Count of Flood Light",
                                initialValue: totalFloodLightItems.toString(),
                                isRequired: true,
                                isEditable: true,
                                onChanged: (value) {
                                  setState(() {
                                    totalFloodLightItems = int.tryParse(value) ?? 0;
                                    hasUnsavedChanges = true;
                                  });
                                },
                              ),
                              getHeight(15),
                              CustomInfoCard(
                                key: ValueKey('flood_light_$floodLightCardKey'),
                                serialLabel: "Flood Light - Serial Number",
                                serialHintText: "Flood Light Serial Number",
                                photoLabel: "Add a Photo",
                                statusLabel: "Status",
                                serialController: floodLightSerialController,
                                showSaveButton: true,
                                onSave: _saveFloodLightForm,
                                isStatusEditable: true,
                                backendStatus: false,
                                remarksLabel: "Capacity of Fire Extinguisher (In Kg)",
                                remarksHintText: "Eg:200 kg",
                                remarksController: remarksController,
                                onPhotoTap: (photoPath) {
                                  setState(() {
                                    floodLightPhoto = photoPath;
                                    hasUnsavedChanges = true;
                                  });
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
                                label:"Count of Sand Buckets ",
                                // "Number of ${selectedType ?? 'Batteries'}",
                                initialValue: totalMPPTItems.toString(),
                                isRequired: true,
                                isEditable: true,
                                onChanged: (value) {
                                  setState(() {
                                    totalMPPTItems = int.tryParse(value) ?? 0;
                                    hasUnsavedChanges = true;
                                  });
                                },
                              ),
                              getHeight(15),
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
                                // remarksLabel: "Capacity",
                                // remarksHintText: "Eg:200",
                                // remarksController: remarksController,
                                onPhotoTap: (photoPath) {
                                  setState(() {
                                    mpptPhoto = photoPath;
                                    hasUnsavedChanges = true;
                                  });
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
                                    : (mpptStatus == "Not OK"
                                    ? false
                                    : null),
                                initialPhotoPath: mpptPhoto,
                                isEditable: true,
                              ),
                              getHeight(8),
                              _buildMPPTSavedItemsList(),
                              getHeight(15),
                              CustomRemarksField(
                                label: "Add Remarks",
                                hintText: "Remarks",
                                controller: remarksController,
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
                              text: _getPreviousAvailableScreen() ?? "Back",
                              isLeftArrow: true,
                              backgroundColor: AppColors.buttonColorBackBg,
                              textColor: AppColors.buttonColorTextBg,
                              onPressed: () {
                                final previousScreen = _getPreviousAvailableScreen();
                                if (previousScreen != null) {
                                  _navigateToNextScreen(context, previousScreen);
                                } else {
                                  Navigator.pop(context);
                                }
                              },
                            ),
                          ),
                          getWidth(14),
                          Expanded(
                            child: ArrowButton(
                              text: _getNextAvailableScreen() ?? "Submit",
                              isLeftArrow: false,
                              backgroundColor: AppColors.buttonColorBg,
                              textColor: AppColors.buttonColorSite,
                              onPressed: () async {
                                // Show loading indicator
                                showDialog(
                                  context: context,
                                  barrierDismissible: false,
                                  builder: (context) => const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                );
                                
                                try {
                                  // Post data before navigating
                                  final success = await _postFireExtinguisherData();
                                  
                                  // Hide loading indicator
                                  Navigator.of(context).pop();
                                  
                                  if (success) {
                                    // Data posted successfully, proceed with navigation
                                    final nextScreen = _getNextAvailableScreen();
                                    if (nextScreen != null) {
                                      _navigateToNextScreen(context, nextScreen);
                                    } else {
                                      // All screens completed, show success dialog
                                      await _saveAndExit();
                                    }
                                  } else {
                                    // Data posting failed, show error message
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Failed to save data. Please try again.',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                            fontFamily: fontFamilyMontserrat,
                                          ),
                                        ),
                                        backgroundColor: Colors.red,
                                        duration: Duration(seconds: 3),
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  // Hide loading indicator
                                  Navigator.of(context).pop();
                                  
                                  // Show error message
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Error saving data: $e',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontFamily: fontFamilyMontserrat,
                                        ),
                                      ),
                                      backgroundColor: Colors.red,
                                      duration: const Duration(seconds: 3),
                                    ),
                                  );
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
          ],
        ),
      ),
      )
    );
  }



  // Build Rectifier saved items list
  Widget _buildRectifierSavedItemsList() {
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

              // Items - Show posted items OR local items with photo/QR
              if (savedRectifierItems.where((item) {
                // Show items that are either posted OR have photo/QR scanned
                bool hasPhoto = item['photo'] != null && item['photo'].toString().isNotEmpty;
                bool isQRScanned = item['isQRCodeScanned'] == true;
                bool isPosted = item['assetAuditSiteRespId'] != null;
                return isPosted || (hasPhoto || isQRScanned);
              }).isNotEmpty) ...[
                ...savedRectifierItems.where((item) {
                  // Show items that are either posted OR have photo/QR scanned
                  bool hasPhoto = item['photo'] != null && item['photo'].toString().isNotEmpty;
                  bool isQRScanned = item['isQRCodeScanned'] == true;
                  bool isPosted = item['assetAuditSiteRespId'] != null;
                  return isPosted || (hasPhoto || isQRScanned);
                }).map((item) {
                    print('Building item row for: $item');
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
                                  ? Icons.qr_code_scanner 
                                  : Icons.close,
                              color: item["isQRCodeScanned"] == true 
                                  ? Colors.blue 
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
                                _editItem(item);
                              },
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

              // Items - Show posted items OR local items with photo/QR
              if (savedMPPTItems.where((item) {
                // Show items that are either posted OR have photo/QR scanned
                bool hasPhoto = item['photo'] != null && item['photo'].toString().isNotEmpty;
                bool isQRScanned = item['isQRCodeScanned'] == true;
                bool isPosted = item['assetAuditSiteRespId'] != null;
                return isPosted || (hasPhoto || isQRScanned);
              }).isNotEmpty) ...[
                ...savedMPPTItems.where((item) {
                  // Show items that are either posted OR have photo/QR scanned
                  bool hasPhoto = item['photo'] != null && item['photo'].toString().isNotEmpty;
                  bool isQRScanned = item['isQRCodeScanned'] == true;
                  bool isPosted = item['assetAuditSiteRespId'] != null;
                  return isPosted || (hasPhoto || isQRScanned);
                }).map((item) {
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
                                  ? Icons.qr_code_scanner 
                                  : Icons.close,
                              color: item["isQRCodeScanned"] == true 
                                  ? Colors.blue 
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
                  },
                )
                    .toList(),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // Save Flood Light form
  void _saveFloodLightForm() async {
    if (floodLightSerialController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter Flood Light serial number'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    _isSavingItem = true; // Set flag to prevent listener conflicts
    
    // Upload photo if it exists and is a file path
    String? photoId = floodLightPhoto;
    if (floodLightPhoto != null && floodLightPhoto!.isNotEmpty && !floodLightPhoto!.startsWith('http') && !_isNumeric(floodLightPhoto!)) {
      try {
        final file = File(floodLightPhoto!);
        if (await file.exists()) {
          print('📤 Uploading Flood Light photo: ${floodLightPhoto}');
          photoId = await _uploadPhoto(file);
          print('✅ Flood Light photo uploaded successfully, image ID: $photoId');
        } else {
          print('❌ Flood Light photo file does not exist: ${floodLightPhoto}');
          photoId = null; // Set to null if file doesn't exist
        }
      } catch (e) {
        print('❌ Error uploading Flood Light photo: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading photo: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
        _isSavingItem = false;
        return;
      }
    }
    
    setState(() {
      Map<String, dynamic> currentFormData = {
        'serialNumber': floodLightSerialNumber,
        'photo': photoId, // Store photoId instead of file path
        'status': floodLightStatus ?? "OK",
        'isQRCodeScanned': isFloodLightQRCodeScanned,
        'timestamp': DateTime.now(),
      };

      print('Saving Flood Light item: $currentFormData');
      print('Photo ID being stored: $photoId');
      print('Serial number being stored: ${floodLightSerialNumber}');
      print('Controller text: ${floodLightSerialController.text}');
      
      savedFloodLightItems.add(currentFormData);

      // Clear form
      floodLightSerialNumber = null;
      floodLightPhoto = null;
      floodLightStatus = null;
      floodLightSerialController.clear();
      floodLightCardKey++;

      hasUnsavedChanges = false;
    });

    // Reset flag immediately
    _isSavingItem = false;

  }

  // Build Flood Light saved items list
  Widget _buildFloodLightSavedItemsList() {
    return Column(
      children: [
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

              // Items - Show posted items OR local items with photo/QR
              if (savedFloodLightItems.where((item) {
                // Show items that are either posted OR have photo/QR scanned
                bool hasPhoto = item['photo'] != null && item['photo'].toString().isNotEmpty;
                bool isQRScanned = item['isQRCodeScanned'] == true;
                bool isPosted = item['assetAuditSiteRespId'] != null;
                return isPosted || (hasPhoto || isQRScanned);
              }).isNotEmpty) ...[
                ...savedFloodLightItems.where((item) {
                  // Show items that are either posted OR have photo/QR scanned
                  bool hasPhoto = item['photo'] != null && item['photo'].toString().isNotEmpty;
                  bool isQRScanned = item['isQRCodeScanned'] == true;
                  bool isPosted = item['assetAuditSiteRespId'] != null;
                  return isPosted || (hasPhoto || isQRScanned);
                }).map((item) {
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
                                ? Icons.qr_code_scanner 
                                : Icons.close,
                            color: item["isQRCodeScanned"] == true 
                                ? Colors.blue 
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
              ] else ...[
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.all(12),
                  child: const Text(
                    'No items added yet.',
                    style: TextStyle(
                      color: AppColors.color555555,
                      fontSize: 14,
                      fontFamily: fontFamilyMontserrat,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // Edit Flood Light item
  void _editFloodLightItem(Map<String, dynamic> item) {
    setState(() {
      floodLightSerialNumber = item["serialNumber"];
      floodLightPhoto = item["photo"];
      floodLightStatus = item["status"];
      isFloodLightQRCodeScanned = item["isQRCodeScanned"] ?? false;
      floodLightSerialController.text = item["serialNumber"] ?? "";
      savedFloodLightItems.remove(item);
      hasUnsavedChanges = true;
      floodLightCardKey++;
    });

    // Load image with caching for faster loading
    if (floodLightPhoto != null && floodLightPhoto!.isNotEmpty && _isNumeric(floodLightPhoto!)) {
      // Check cache first
      if (_imageCache.containsKey(floodLightPhoto!)) {
        setState(() {
          displayedImageBase64 = _imageCache[floodLightPhoto!];
          isLoadingImage = false;
        });
      } else {
        // Fetch from API if not in cache
        setState(() {
          _currentRequestedImageId = floodLightPhoto;
          _isRequestingImage = true;
          isLoadingImage = true;
        });
        context.read<AssetAuditGetImageCubit>().getImage(
          imgId: floodLightPhoto!,
          schId: widget.siteAuditSchId,
        );
      }
    }
  }


}
