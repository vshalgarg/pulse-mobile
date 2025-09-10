import 'package:app/commonWidgets/custom_buttons/arrow_botton.dart';
import 'package:app/constants/constants_methods.dart';
import 'package:app/utils/asset_audit_navigation_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../bloc/asset_audit_cubit.dart';
import '../../../bloc/asset_audit_state.dart';
import '../../../bloc/asset_audit_photo_upload_cubit.dart';
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
import '../../../utils/asset_audit_post_helper.dart';
import '../../../models/asset_audit_model.dart';
import '../../home_screen.dart';
import 'dart:io';
import 'dart:async';

class DCBAScreen extends StatefulWidget {
  final String siteType;
  final String auditSchId;
  final String siteAuditSchId;
  final AssetAuditModel? assetAuditData; // Complete asset audit data

  const DCBAScreen({
    super.key,
    required this.siteType,
    required this.auditSchId,
    required this.siteAuditSchId,
    this.assetAuditData, // Complete asset audit data
  });

  @override
  State<DCBAScreen> createState() => _DCBAScreenState();
}

class _DCBAScreenState extends State<DCBAScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController serialController = TextEditingController();
  bool hasUnsavedChanges = false;
  bool showValidationErrors = false;
  int totalItemsToScan = 6;
  int currentScannedItems = 0;
  List<Map<String, dynamic>> savedItems = [];

  // DCBA field values
  String? dcbaSerialNumber;
  String? dcbaPhoto;
  String? dcbaStatus;
  final remarksController = TextEditingController();
  int dcbaCardKey = 0;
  List<Map<String, dynamic>> savedDcbaItems = [];
  bool isQRCodeScanned = false; // Track if serial was scanned or manually entered

  // API integration fields
  String? uploadedPhotoPath;
  String? uploadedImgId;
  String? fetchedImageData;
  bool _hasFormDataChanges = false;
  List<Map<String, String>> _imageQueue = [];
  bool _fetchingImage = false;
  String? _lastRequestedPhotoId;
  Map<String, int> _retryCounts = {};

  // Image display and loading states
  String? displayedImageBase64;
  bool isLoadingImage = false;
  StreamSubscription? _getImageSubscription;
  StreamSubscription? _assetAuditSubscription;

  // Controllers for CustomInfoCard
  final TextEditingController dcbaSerialController = TextEditingController();

  // Get DCBA data from API
  int totalDcbaItems = 0; // Total DCBA items from API

  // Get DCBA category data
  CategoryData? get dcbaCategoryData {
    return widget.assetAuditData?.responseData.categories['DCDB'];
  }

  @override
  void initState() {
    super.initState();
    serialController.addListener(_onFormChanged);
    remarksController.addListener(_onFormChanged);
    _setupGetImageListener();
    // Clear serial number field to prevent showing data when clicked
    dcbaSerialController.clear();

    _loadExistingData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Sync initial data from widget.assetAuditData
    if (widget.assetAuditData != null) {
      final dcbaData = widget.assetAuditData!.responseData.categories['DCDB'];
      if (dcbaData != null) {
        setState(() {
          totalDcbaItems = dcbaData.assets.length;
          // Only show items that have been interacted with by the user (have photo_id and qr_code_scanned is not null)
          savedDcbaItems = dcbaData.assets
              .where((asset) => asset.photoId != null && asset.qrCodeScanned != null)
              .map((asset) {
            return {
              'serialNumber': asset.mfgSerialNo ?? asset.nexgenSerialNo ?? '',
              'photo': asset.photoId?.toString(),
              'status': asset.assetStatus ?? 'OK',
              'isQRCodeScanned': asset.qrCodeScanned ?? false,
              'timestamp': DateTime.now(),
              'assetAuditSiteRespId': asset.assetAuditSiteRespId,
            };
          }).toList();
          // Only load remarks from API if user hasn't made changes
          if (remarksController.text.isEmpty) {
            remarksController.text = dcbaData.remarks.isNotEmpty
                ? dcbaData.remarks.first.itemTypeRemark ?? ''
                : '';
          }
        });
      }
    }

    // Load fresh data into cubit
    context.read<AssetAuditCubit>().getAssetAuditData(
      siteType: widget.siteType,
      auditSchId: widget.auditSchId,
      siteAuditSchId: widget.siteAuditSchId,
    );
  }


  @override
  void dispose() {
    serialController.removeListener(_onFormChanged);
    remarksController.removeListener(_onFormChanged);
    serialController.dispose();
    remarksController.dispose();
    dcbaSerialController.dispose();
    _getImageSubscription?.cancel();
    _assetAuditSubscription?.cancel();
    super.dispose();
  }

  void _loadExistingData() async {
    // Load existing DCBA data from API
    print('DCBA screen: Loading existing data from API');

    final assetAuditState = context.read<AssetAuditCubit>().state;
    if (assetAuditState is AssetAuditLoaded && assetAuditState.assetAuditData.responseData.categories.isNotEmpty) {
      final dcbaData = assetAuditState.assetAuditData.responseData.categories['DCDB'];

      if (dcbaData != null && dcbaData.assets.isNotEmpty) {
        print('DCBA screen: Found ${dcbaData.assets.length} DCBA assets');

        // Load photos for DCBA assets that have them
        for (var asset in dcbaData.assets) {
          if (asset.photoId != null && asset.photoId! > 0) {
            print('DCBA screen: Loading image for asset ${asset.assetAuditSiteRespId} with photoId ${asset.photoId}');
            _imageQueue.add({'photoId': asset.photoId.toString(), 'key': 'dcba_${asset.assetAuditSiteRespId}'});
          }
        }

        if (_imageQueue.isNotEmpty) {
          _fetchNextImage();
        } else {
          print('DCBA screen: No DCBA assets with photos found');
        }
      } else {
        print('DCBA screen: No DCBA data found');
      }
    }
  }

  void _onFormChanged() {
    setState(() {
      hasUnsavedChanges = serialController.text.isNotEmpty || remarksController.text.isNotEmpty;

      if (showValidationErrors && serialController.text.isNotEmpty) {
        showValidationErrors = false;
      }
    });
  }

  void _saveAndExit() async {
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // Post DCBA data to API first
      await _postDcbaData();
      
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

  bool _isFormValid() {
    print('=== DCBA VALIDATION: Checking form validity ===');
    print('Serial controller text: "${dcbaSerialController.text}"');
    print('Photo: $dcbaPhoto');

    if (dcbaSerialController.text.isEmpty) {
      print('=== DCBA VALIDATION: Serial number is empty ===');
      return false;
    }

    if (dcbaPhoto == null || dcbaPhoto!.isEmpty) {
      print('=== DCBA VALIDATION: Photo is null or empty ===');
      return false;
    }

    print('=== DCBA VALIDATION: Form is valid ===');
    return true;
  }

  bool _validateForm() {
    if (dcbaSerialController.text.isEmpty) {
      return false;
    }

    if (dcbaPhoto == null || dcbaPhoto!.isEmpty) {
      return false;
    }

    return true;
  }

  void _setValidationErrors() {
    setState(() {
      showValidationErrors = true;
    });
  }

  // Helper method to get the next available screen based on data availability
  String? _getNextAvailableScreen() {
    return AssetAuditNavigationHelper.getNextAvailableScreen(widget.assetAuditData, 'DCDB');
  }

  // Helper method to get the previous available screen based on data availability
  String? _getPreviousAvailableScreen() {
    return AssetAuditNavigationHelper.getPreviousAvailableScreen(widget.assetAuditData, 'DCDB');
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

  Future<String?> _uploadDcbaPhoto(File file) async {
    try {
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
            print('✅ DCBA Photo upload SUCCESS!');
            print('Response imgId: ${state.response.imgId}');
            subscription.cancel();
            completer.complete(state.response.imgId);
          } else if (state is AssetAuditPhotoUploadFailure) {
            print('❌ DCBA Photo upload FAILED!');
            print('Error message: ${state.errorMessage}');
            subscription.cancel();
            completer.completeError(state.errorMessage);
          } else {
            print('📤 DCBA Photo upload in progress...');
          }
        });

        print('Starting DCBA photo upload...');
        context.read<AssetAuditPhotoUploadCubit>().uploadPhoto(
          file: file,
          imgId: imgIdToUse,
          schId: schId,
        );

        print('Waiting for DCBA photo upload result...');
        final result = await completer.future.timeout(
          const Duration(seconds: 30),
          onTimeout: () {
            print('⏰ DCBA Photo upload TIMEOUT after 30 seconds');
            subscription.cancel();
            throw TimeoutException('Photo upload timeout', const Duration(seconds: 30));
          },
        );

        print('✅ DCBA Photo upload completed with result: $result');
        return result;
      } else {
        print('❌ DCBA Photo upload failed: AssetAuditCubit state is not AssetAuditLoaded or pageHeader is empty');
        throw Exception('AssetAuditCubit state is not ready');
      }
    } catch (e) {
      print('❌ DCBA Photo upload error: $e');
      rethrow;
    }
  }

  void _fetchNextImage() {
    if (_fetchingImage || _imageQueue.isEmpty) return;

    _fetchingImage = true;

    final image = _imageQueue.removeAt(0);
    final photoId = image['photoId']!;
    final key = image['key']!;

    print('Loading DCBA image for photoId: $photoId, key: $key, retry count: ${_retryCounts[photoId] ?? 0}');
    _lastRequestedPhotoId = photoId;
    _retryCounts[photoId] = _retryCounts[photoId] ?? 0;
    context.read<AssetAuditGetImageCubit>().getImage(
      imgId: photoId,
      schId: widget.siteAuditSchId,
    );
  }

  Future<void> _handleImageLoadRetry(String photoId, String key) async {
    const maxRetries = 5;
    const retryDelay = Duration(seconds: 3);

    final currentRetryCount = _retryCounts[photoId] ?? 0;
    if (currentRetryCount < maxRetries) {
      _retryCounts[photoId] = currentRetryCount + 1;
      print('Retrying DCBA image load for photoId: $photoId, key: $key, attempt: ${_retryCounts[photoId]} of $maxRetries');
      await Future.delayed(retryDelay);
      _imageQueue.insert(0, {'photoId': photoId, 'key': key});
      _fetchNextImage();
    } else {
      print('Max retries reached for DCBA photoId: $photoId, key: $key');
      _retryCounts.remove(photoId);
    }
  }

  String? _getRemarksAssetAuditSiteRespId() {
    final dcbaData = widget.assetAuditData?.responseData.categories['DCDB'];
    if (dcbaData != null && dcbaData.remarks.isNotEmpty) {
      return dcbaData.remarks.first.assetAuditSiteRespId.toString();
    }
    print('No valid remarks ID found in backend data');
    return null;
  }

  void _setupGetImageListener() {
    _getImageSubscription = context.read<AssetAuditGetImageCubit>().stream.listen((state) async {
      if (state is AssetAuditGetImageSuccess) {
        print('Image loaded for DCBA photoId: $_lastRequestedPhotoId, data length: ${state.imageData.length}');

        if (state.imageData.isNotEmpty) {
          setState(() {
            fetchedImageData = state.imageData;
            _hasFormDataChanges = true;
          });

          _fetchingImage = false;
          _fetchNextImage();
        } else {
          print('Empty image data received for DCBA photoId: $_lastRequestedPhotoId');
          await _handleImageLoadRetry(_lastRequestedPhotoId ?? '', 'dcba');
        }
      } else if (state is AssetAuditGetImageFailure) {
        print('Failed to load DCBA image for photoId: $_lastRequestedPhotoId, error: ${state.errorMessage}');
        await _handleImageLoadRetry(_lastRequestedPhotoId ?? '', 'dcba');
      } else if (state is AssetAuditGetImageLoading) {
        setState(() {
          isLoadingImage = true;
        });
        print('=== DCBA Get Image Loading ===');
      }
    });
  }


  // POST DCBA data to API
  Future<void> _postDCBAData() async {
    print('=== DCBA POST: Starting POST data ===');
    print('Saved DCBA items count: ${savedDcbaItems.length}');
    print('Remarks text: "${remarksController.text.trim()}"');

    if (savedDcbaItems.isEmpty && remarksController.text.trim().isEmpty) {
      print('=== DCBA POST: No data to post, returning ===');
      return;
    }

    try {
      final assetAuditState = context.read<AssetAuditCubit>().state;
      if (assetAuditState is AssetAuditLoaded && assetAuditState.assetAuditData.pageHeader.isNotEmpty) {
        List<Map<String, dynamic>> allItemsToPost = [];

        if (savedDcbaItems.isNotEmpty) {
          print('=== DCBA POST: Processing ${savedDcbaItems.length} saved items ===');
          for (int i = 0; i < savedDcbaItems.length; i++) {
            print('Item $i: ${savedDcbaItems[i]}');
          }

          final enhancedItems = AssetAuditPostHelper.enhanceSavedItems(
            savedItems: savedDcbaItems,
            screenName: 'solar_dcba',
          );
          print('=== DCBA POST: Enhanced items count: ${enhancedItems.length} ===');
          allItemsToPost.addAll(enhancedItems);
        }

        if (remarksController.text.trim().isNotEmpty) {
          String? remarksAssetAuditSiteRespId = _getRemarksAssetAuditSiteRespId();
          if (remarksAssetAuditSiteRespId != null) {
            Map<String, dynamic> remarksData = {
              'itemType': 'DCDB',
              'remarks': remarksController.text.trim(),
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
          return;
        }

        final requests = await AssetAuditPostHelper.convertSavedItemsToPostRequest(
          savedItems: allItemsToPost,
          assetAuditData: assetAuditState.assetAuditData,
          itemType: 'DCDB',
          itemTypeId: 5,
          screenName: 'solar_dcba',
          context: context,
          auditSchId: widget.auditSchId,
        );

        if (requests.isNotEmpty) {
          print('=== DCBA POST: Posting ${requests.length} requests to API ===');
          await context.read<AssetAuditCubit>().postAssetAuditData(requests: requests);
          print('=== DCBA POST: API call completed ===');
        } else {
          print('=== DCBA POST: No requests to post ===');
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error posting DCBA data: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }


  void _saveDcbaForm() async {
    print('=== DCBA SAVE: Starting save form ===');
    print('Current savedDcbaItems count: ${savedDcbaItems.length}');
    print('Total DCBA items: $totalDcbaItems');
    print('Serial number: $dcbaSerialNumber');
    print('Photo: $dcbaPhoto');
    print('Status: $dcbaStatus');

    if (savedDcbaItems.length >= totalDcbaItems) {
      print('=== DCBA SAVE: Maximum items reached ===');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Maximum number of SPV items ($totalDcbaItems) already added.',
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
      print('=== DCBA SAVE: Form is valid, proceeding ===');
      String? photoImageId = dcbaPhoto;

      // If photo is a file path, upload it and get image ID
      if (dcbaPhoto != null && dcbaPhoto!.isNotEmpty && !dcbaPhoto!.startsWith('http')) {
        try {
          final file = File(dcbaPhoto!);
          if (await file.exists()) {
            print(' Uploading DCBA photo: ${dcbaPhoto}');
            photoImageId = await _uploadDcbaPhoto(file);
            print('✅ DCBA photo uploaded successfully, image ID: $photoImageId');
          } else {
            print('❌ DCBA photo file does not exist: ${dcbaPhoto}');
          }
        } catch (e) {
          print('❌ Error uploading DCBA photo: $e');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error uploading photo: $e'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
      } else {
        print('ℹ️ No DCBA photo to upload or already has image ID');
      }

      setState(() {
        Map<String, dynamic> currentFormData = {
          'serialNumber': dcbaSerialNumber,
          'photo': photoImageId, // Use image ID instead of file path
          'status': dcbaStatus ?? "OK",
          'timestamp': DateTime.now(),
          'isQRCodeScanned': false, // Add this field
          'photoTakenTs': DateTime.now().toString(), // Add this field
          'localQrCodeScannedTs': DateTime.now().toString(), // Add this field
          'localCreatedDt': DateTime.now().toString(), // Add this field
          'localModifiedDt': DateTime.now().toString(), // Add this field
        };

        savedDcbaItems.add(currentFormData);
        currentScannedItems++;

        print('=== DCBA SAVE: Item added to savedDcbaItems ===');
        print('New savedDcbaItems count: ${savedDcbaItems.length}');
        print('Added item: $currentFormData');

        dcbaSerialNumber = null;
        dcbaPhoto = null;
        dcbaStatus = null;

        dcbaSerialController.clear();

        dcbaCardKey++;

        hasUnsavedChanges = false;
        showValidationErrors = false;
      });

      int remainingSpv = totalDcbaItems - savedDcbaItems.length;
    } else {
      print('=== DCBA SAVE: Form validation failed ===');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please fill in all required fields (Serial Number and Photo)'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  String _formatSerialNumber(String serialNumber) {
    if (serialNumber.length <= 7) {
      return serialNumber;
    }
    return "${serialNumber.substring(0, 5)}...";
  }

  void _editItem(Map<String, dynamic> item) {
    setState(() {
      dcbaSerialNumber = item["serialNumber"];
      dcbaPhoto = item["photo"];
      dcbaStatus = item["status"];
      isQRCodeScanned = item["isQRCodeScanned"] ?? false; // Restore QR scan status

      dcbaSerialController.text = item["serialNumber"] ?? "";
      displayedImageBase64 = null; // Clear Base64 to avoid showing old image
      isLoadingImage = false; // Reset loading state

      savedDcbaItems.remove(item);

      hasUnsavedChanges = true;

      // Force rebuild of the CustomInfoCard to show restored values
      dcbaCardKey++;
    });

    // Load image asynchronously to avoid blocking UI
    if (dcbaPhoto != null && dcbaPhoto!.isNotEmpty && _isNumeric(dcbaPhoto!)) {
      print('=== DCBA Edit: Fetching image for photo ID: $dcbaPhoto ===');
      setState(() {
        isLoadingImage = true;
      });

      // Use Future.microtask to load image in next frame
      Future.microtask(() {
        context.read<AssetAuditGetImageCubit>().getImage(
          imgId: dcbaPhoto!,
          schId: widget.siteAuditSchId,
        );
      });
    }


    // If the photo is a photo ID (numeric), fetch the image from API
    if (dcbaPhoto != null && dcbaPhoto!.isNotEmpty && _isNumeric(dcbaPhoto!)) {
      print('=== DCBA Edit: Fetching image for photo ID: $dcbaPhoto ===');
      context.read<AssetAuditGetImageCubit>().getImage(
        imgId: dcbaPhoto!,
        schId: widget.siteAuditSchId,
      );
    }
  }


  /// Check if string is numeric
  bool _isNumeric(String str) {
    return double.tryParse(str) != null;
  }



  /// Post DCBA data to API
  Future<void> _postDcbaData() async {
    print('=== DCBA Post Data Started ===');

    if (savedDcbaItems.isEmpty && remarksController.text.trim().isEmpty) {
      print('DCBA Screen: No data to post');
      return;
    }

    try {
      // Collect all items and remarks
      List<Map<String, dynamic>> allItemsToPost = [];

      // Add saved DCBA items with proper structure
      for (var item in savedDcbaItems) {
        Map<String, dynamic> formattedItem = {
          'serialNumber': item['serialNumber'],
          'photo': item['photo'],
          'status': item['status'],
          'photoTakenTs': item['timestamp']?.toString() ?? DateTime.now().toString(),
          'isQRCodeScanned': item['isQRCodeScanned'] ?? false,
          'localQrCodeScannedTs': item['timestamp']?.toString() ?? DateTime.now().toString(),
          'localCreatedDt': item['timestamp']?.toString() ?? DateTime.now().toString(),
          'localModifiedDt': item['timestamp']?.toString() ?? DateTime.now().toString(),
        };
        allItemsToPost.add(formattedItem);
      }

      // Add user remarks if any - use the correct structure for remarks
      if (remarksController.text.trim().isNotEmpty) {
        Map<String, dynamic> remarksData = {
          'recordType': 'remarks',
          'itemType': 'DCDB',
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
        print('DCBA Screen: Added user remarks to post, text: "${remarksController.text.trim()}"');
      }

      if (allItemsToPost.isEmpty) {
        print('DCBA Screen: No items to post');
        return;
      }

      // Convert to POST request format
      final requests = await AssetAuditPostHelper.convertSavedItemsToPostRequest(
        savedItems: allItemsToPost,
        assetAuditData: widget.assetAuditData!,
        itemType: 'DCDB',
        itemTypeId: 9, // DCBA item type ID
        screenName: 'solar_dcba',
        context: context,
        auditSchId: widget.auditSchId,
      );

      // Post data
      if (requests.isNotEmpty) {
        print('DCBA Screen: Posting ${requests.length} requests');
        
        // Store the current remarks text before posting
        final currentRemarksText = remarksController.text;
        print('DCBA Screen: Storing current remarks text: "$currentRemarksText"');
        
        context.read<AssetAuditCubit>().postAssetAuditData(requests: requests);
        
        // Refresh the data immediately after posting
        print('Refreshing DCBA data after posting...');
        context.read<AssetAuditCubit>().getAssetAuditData(
          siteType: widget.siteType,
          auditSchId: widget.auditSchId,
          siteAuditSchId: widget.siteAuditSchId,
        );
        
        // Restore the remarks text after refresh to ensure it's not overwritten
        if (currentRemarksText.isNotEmpty) {
          print('DCBA Screen: Restoring remarks text after refresh: "$currentRemarksText"');
          remarksController.text = currentRemarksText;
        }
      }

      print('DCBA Screen: All data posted successfully');
    } catch (e) {
      print('DCBA Screen: Error posting data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error posting data: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // /// Get remarks asset audit site resp ID
  // String? _getRemarksAssetAuditSiteRespId() {
  //   final dcbaData = widget.assetAuditData?.responseData.categories['DCDB'];
  //   if (dcbaData != null && dcbaData.remarks.isNotEmpty) {
  //     return dcbaData.remarks.first.assetAuditSiteRespId.toString();
  //   }
  //   return null;
  // }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<AssetAuditGetImageCubit, AssetAuditGetImageState>(
          listener: (context, state) {
            if (state is AssetAuditGetImageSuccess) {
              String finalImageData = state.imageData.startsWith('data:image/')
                  ? state.imageData
                  : 'data:image/jpeg;base64,${state.imageData}';
              setState(() {
                displayedImageBase64 = finalImageData;
                isLoadingImage = false;
                dcbaCardKey++;
              });
            } else if (state is AssetAuditGetImageFailure) {
              setState(() {
                displayedImageBase64 = null;
                isLoadingImage = false;
                dcbaCardKey++;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Failed to load image: ${state.errorMessage}'),
                  backgroundColor: Colors.red,
                  duration: const Duration(seconds: 3),
                ),
              );
            } else if (state is AssetAuditGetImageLoading) {
              setState(() {
                isLoadingImage = true;
              });
            }
          },
        ),
        BlocListener<AssetAuditCubit, AssetAuditState>(
          listener: (context, state) {
            if (state is AssetAuditLoaded) {
              final dcbaData = state.assetAuditData.responseData.categories['DCDB'];
              if (dcbaData != null) {
                setState(() {
                  totalDcbaItems = dcbaData.assets.length;
                  // Only show items that have been interacted with by the user (have photo_id and qr_code_scanned is not null)
                  savedDcbaItems = dcbaData.assets
                      .where((asset) => asset.photoId != null && asset.photoId! > 0 && asset.qrCodeScanned != null)
                      .map((asset) {
                    return {
                      'serialNumber': asset.mfgSerialNo ?? asset.nexgenSerialNo ?? '',
                      'photo': asset.photoId?.toString(),
                      'status': asset.assetStatus ?? 'OK',
                      'isQRCodeScanned': asset.qrCodeScanned ?? false,
                      'timestamp': DateTime.now(),
                      'assetAuditSiteRespId': asset.assetAuditSiteRespId,
                    };
                  }).toList();
                  // Only load remarks from API if user hasn't made changes
                  if (remarksController.text.isEmpty) {
                    remarksController.text = dcbaData.remarks.isNotEmpty
                        ? dcbaData.remarks.first.itemTypeRemark ?? ''
                        : '';
                  }
                });
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
              builder: (context) =>
                  UnsavedChangesDialog(
              message:
              "Do you want to cancel the Asset Audit for Site (ID: SITE-38974) ?",
              onSaveAndExit: () async {
                Navigator.of(context).pop(); // Close the dialog first
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
                  onSaveAndExit: () async {
                    Navigator.of(context).pop(); // Close the dialog first
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
                                label: "AJB Type",
                                hintText: "Text",
                                isRequired: true,
                                isEditable: false,
                                initialValue: dcbaCategoryData?.assets.first.oemName,
                              ),
                              getHeight(15),
                              CustomFormField(
                                label: "Count of AJB",
                                initialValue: "2",
                                isRequired: false,
                                isEditable: false,
                              ),
                              getHeight(15),
                              Text(
                                "AJB Details",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white,
                                  fontFamily: fontFamilyMontserrat,
                                ),
                              ),
                              getHeight(3),
                              CustomInfoCard(
                                  key: ValueKey('dcba_$dcbaCardKey'),
                                serialLabel: dcbaCategoryData?.assets.isNotEmpty == true
                                    ? "DCBA (${dcbaCategoryData?.assets.first.oemName ?? 'N/A'}) - Serial Number"
                                    : "DCBA - Serial Number",
                                serialHintText: "DCBA Serial Number *",
                                photoLabel: "Add a Photo",
                                statusLabel: "Status",
                                  serialController: dcbaSerialController,
                                onSave: _saveDcbaForm,
                                isStatusEditable: true,
                                backendStatus: false,
                                showSaveButton: true,
                                remarksLabel: 'DCBA (Capacity)',
                                remarksHintText: dcbaCategoryData?.assets.isNotEmpty == true
                                    ? dcbaCategoryData?.assets.first.capacity ?? 'N/A'
                                    : 'N/A',
                                remarksController: null,
                                isRemarksEditable: false,
                                onPhotoTap: (photoPath) {
                                  setState(() {
                                      dcbaPhoto = photoPath;
                                      displayedImageBase64 = null;
                                    hasUnsavedChanges = true;
                                  });
                                },
                                onStatusChanged: (val) {
                                  setState(() {
                                      dcbaStatus = val ? "OK" : "Not OK";
                                    hasUnsavedChanges = true;
                                  });
                                },
                                onSerialChanged: (serialNumber) {
                                  setState(() {
                                    dcbaSerialNumber = serialNumber;
                                    isQRCodeScanned = false; // Manual entry
                                    hasUnsavedChanges = true;
                                  });
                                },
                                  initialStatus: dcbaStatus == "OK"
                                    ? true
                                      : (dcbaStatus == "Not OK" ? false : null),
                                  initialPhotoPath: dcbaPhoto,
                                isEditable: true,
                              ),
                              getHeight(8),
                              _buildDcbaSavedItemsList(),
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
                              text: AssetAuditNavigationHelper.getSolarPreviousScreenName('DCDB'),
                              isLeftArrow: true,
                              backgroundColor: AppColors.buttonColorBackBg,
                              textColor: AppColors.buttonColorTextBg,
                              onPressed: () {
                                final previousScreen = AssetAuditNavigationHelper.getPreviousAvailableScreen(widget.assetAuditData, 'DCDB');
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
                              child: Builder(
                                builder: (context) {
                                  final nextScreen = _getNextAvailableScreen();
                                  if (nextScreen == null) {
                                    // No more screens with data, show Submit button
                                    return ArrowButton(
                                      text: "Submit",
                              isLeftArrow: false,
                              backgroundColor: AppColors.buttonColorBg,
                              textColor: AppColors.buttonColorSite,
                                      onPressed: () async {
                                        await _postDCBAData();
                                        // Navigate to final submission or back to main screen
                                        Navigator.pop(context);
                                      },
                                    );
                                  } else {
                                    // Show next available screen button
                                    return ArrowButton(
                                      text: nextScreen,
                                      isLeftArrow: false,
                                      backgroundColor: AppColors.buttonColorBg,
                                      textColor: AppColors.buttonColorSite,
                                      onPressed: () async {
                                        print(
                                            '=== DCBA Navigation to $nextScreen ===');
                                        print(
                                            'Passing asset audit data: ${widget
                                                .assetAuditData != null}');

                                        // POST data to API before navigation
                                        await _postDCBAData();

                                        // Navigate to the next available screen
                                        _navigateToNextScreen(
                                            context, nextScreen);
                                      },
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
      ),
    );
    }


  Widget _buildDcbaSavedItemsList() {
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

              if (savedDcbaItems.isNotEmpty) ...[
                ...savedDcbaItems.map((item) {
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
                            item['isQRCodeScanned'] == true
                                ? Icons.qr_code_scanner
                                : Icons.close,
                            color: item['isQRCodeScanned'] == true
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
                              _editItem(item);
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
}
