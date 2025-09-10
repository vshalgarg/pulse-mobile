import 'package:app/commonWidgets/custom_buttons/arrow_botton.dart';
import 'package:app/constants/constants_methods.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

import '../../../commonWidgets/asset_type_card.dart';
import '../../../commonWidgets/custom_dialogs/success_dialog.dart';
import '../../../commonWidgets/custom_dialogs/unsaved_changes_dialog.dart';
import '../../../commonWidgets/custom_form_appbar.dart';
import '../../../commonWidgets/custom_form_field.dart';
import '../../../commonWidgets/custom_remark.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_images.dart';
import '../../../constants/constants_strings.dart';
import '../../../hive_local_database/hive_db.dart';
import '../../../models/asset_audit_model.dart';
import '../../home_screen.dart';
import '../../../bloc/asset_audit_cubit.dart';
import '../../../bloc/asset_audit_state.dart';
import '../../../bloc/asset_audit_photo_upload_cubit.dart';
import '../../../bloc/asset_audit_get_image_cubit.dart';
import '../../../bloc/audit_schedule_status_cubit.dart';
import '../../../utils/asset_audit_navigation_helper.dart';
import '../../../utils/asset_audit_post_helper.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:io';
import 'dart:async';
import 'dart:convert';

class LTDBScreen extends StatefulWidget {
  final String siteType;
  final String auditSchId;
  final String siteAuditSchId;
  final AssetAuditModel? assetAuditData; // Complete asset audit data

  const LTDBScreen({
    super.key,
    required this.siteType,
    required this.auditSchId,
    required this.siteAuditSchId,
    this.assetAuditData, // Complete asset audit data
  });

  @override
  State<LTDBScreen> createState() => _LTDBScreenState();
}

class _LTDBScreenState extends State<LTDBScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController serialController = TextEditingController();
  bool hasUnsavedChanges = false;
  bool showValidationErrors = false;
  int totalItemsToScan = 6;
  int currentScannedItems = 0;
  List<Map<String, dynamic>> savedItems = [];

  // LTDB field values
  String? ltdbSerialNumber;
  String? ltdbPhoto;
  String? ltdbStatus;
  final remarksController = TextEditingController(); // User remarks
  int ltdbCardKey = 0;
  List<Map<String, dynamic>> _savedLtdbItems = [];
  
  List<Map<String, dynamic>> get savedLtdbItems => _savedLtdbItems;
  
  set savedLtdbItems(List<Map<String, dynamic>> value) {
    print('=== savedLtdbItems SETTER called ===');
    print('Old length: ${_savedLtdbItems.length}');
    print('New length: ${value.length}');
    print('Old content: $_savedLtdbItems');
    print('New content: $value');
    print('Stack trace: ${StackTrace.current}');
    _savedLtdbItems = value;
  }
  
  void _debugSavedLtdbItems(String operation) {
    print('=== savedLtdbItems $operation ===');
    print('Current length: ${_savedLtdbItems.length}');
    print('Current content: $_savedLtdbItems');
    print('Stack trace: ${StackTrace.current}');
  }

  // Controllers for CustomInfoCard
  final TextEditingController ltdbSerialController = TextEditingController();
  int totalLtdbItems = 0; // Will be set from API data
  bool isQRCodeScanned = false; // Track if serial was scanned or manually entered
  String? lastValidatedSerial; // Track last validated serial to prevent repeated toasts

  // API integration fields
  String? uploadedPhotoPath;
  String? uploadedImgId;
  String? fetchedImageData;
  bool _hasFormDataChanges = false;
  List<Map<String, String>> _imageQueue = [];
  bool _fetchingImage = false;
  String? _lastRequestedPhotoId;

  // Image display and loading states
  String? displayedImageBase64;
  bool isLoadingImage = false;
  Map<String, int> _retryCounts = {};
  
  // Image loading tracking to prevent repeated processing
  String? _currentRequestedImageId;
  bool _isRequestingImage = false;
  
  // Image caching for faster loading
  Map<String, String> _imageCache = {};

  @override
  void initState() {
    super.initState();
    serialController.addListener(_onFormChanged);
    ltdbSerialController.addListener(_onFormChanged);
    remarksController.addListener(() {
      print('=== Remarks controller changed: "${remarksController.text}" ===');
      print('savedLtdbItems.length: ${savedLtdbItems.length}');
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    print('=== LTDB didChangeDependencies called ===');

    context.read<AssetAuditCubit>().getAssetAuditData(
      siteType: widget.siteType,
      auditSchId: widget.auditSchId,
      siteAuditSchId: widget.siteAuditSchId,
    );

    // Initialize total items and saved items from API data
    if (widget.assetAuditData != null) {
      final ltdbData = widget.assetAuditData!.responseData.categories['LTDB'];
      if (ltdbData != null) {
        totalLtdbItems = ltdbData.assets.length;
        print('LTDB total items from API: $totalLtdbItems');
        print('LTDB data received: ${ltdbData.assets.length} assets');
        if (ltdbData.assets.isNotEmpty) {
          print('First LTDB asset: ${ltdbData.assets.first.oemName}');
          print('First LTDB asset type: ${ltdbData.assets.first.itemType}');
          print('First LTDB asset capacity: ${ltdbData.assets.first.capacity}');

          // Only load items from API if we don't have any user-saved items
          // This prevents overwriting user's saved items when the screen initializes
          if (savedLtdbItems.isEmpty) {
            // Load items that have been successfully posted to API AND have user interaction
            // (either photo taken or serial number entered - regardless of QR scan or manual entry)
            setState(() {
              final postedItems = ltdbData.assets.where((asset) =>
              asset.assetAuditSiteRespId != null &&
                  asset.photoId != null
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

              savedLtdbItems = postedItems;
              currentScannedItems = savedLtdbItems.length;
              print('LTDB: Loaded ${savedLtdbItems.length} items from API in didChangeDependencies (list was empty)');
            });
          } else {
            print('LTDB: Skipping API load in didChangeDependencies, ${savedLtdbItems.length} items already saved by user');
          }

          // Only initialize remarks from API if user hasn't made changes
          if (ltdbData.remarks.isNotEmpty && remarksController.text.isEmpty) {
            setState(() {
              remarksController.text = ltdbData.remarks.first.itemTypeRemark ?? '';
            });
          }
        } else {
          print('No LTDB assets found in API data');
        }
      } else {
        print('LTDB category not found in asset audit data!');
      }
    } else {
      print('Asset audit data is null!');
    }

    // Check page header for additional data
    _checkPageHeaderForData();
  }

  @override
  void dispose() {
    serialController.removeListener(_onFormChanged);
    ltdbSerialController.removeListener(_onFormChanged);
    // remarksController listener will be automatically removed when controller is disposed
    serialController.dispose();
    ltdbSerialController.dispose();
    remarksController.dispose();
    super.dispose();
  }

  void _onFormChanged() {
    print('=== _onFormChanged called ===');
    print('serialController.text: "${serialController.text}"');
    print('ltdbSerialController.text: "${ltdbSerialController.text}"');
    print('remarksController.text: "${remarksController.text}"');
    print('savedLtdbItems.length: ${savedLtdbItems.length}');
    print('savedLtdbItems content: $savedLtdbItems');
    
    final hasLocalPhoto = uploadedPhotoPath != null && uploadedPhotoPath!.isNotEmpty;
    final hasServerImage = uploadedImgId != null && uploadedImgId!.isNotEmpty && uploadedImgId != "0";
    final hasImageData = fetchedImageData != null && fetchedImageData!.isNotEmpty;

    final newHasUnsavedChanges = serialController.text.isNotEmpty ||
        ltdbSerialController.text.isNotEmpty ||
        hasLocalPhoto ||
        hasServerImage ||
        hasImageData;
        // remarksController.text.isNotEmpty; // Temporarily disabled to test

    print('hasUnsavedChanges: $hasUnsavedChanges, newHasUnsavedChanges: $newHasUnsavedChanges');

    // Only call setState if the value actually changed
    if (hasUnsavedChanges != newHasUnsavedChanges) {
      print('Calling setState due to hasUnsavedChanges change');
      setState(() {
        hasUnsavedChanges = newHasUnsavedChanges;
        _hasFormDataChanges = true;
      });
    } else {
      _hasFormDataChanges = true;
    }

    if (showValidationErrors && (serialController.text.isNotEmpty || ltdbSerialController.text.isNotEmpty)) {
      print('Calling setState due to showValidationErrors change');
      setState(() {
        showValidationErrors = false;
      });
    }
  }

  void _saveFormDataToHive() {
    // No Hive storage - data is only stored in memory and posted to API
    _hasFormDataChanges = false;
  }

  void _checkPageHeaderForData() {
    final assetAuditState = context.read<AssetAuditCubit>().state;
    if (assetAuditState is AssetAuditLoaded && assetAuditState.assetAuditData.pageHeader.isNotEmpty) {
      final pageHeader = assetAuditState.assetAuditData.pageHeader.first;
      print('LTDB makerSelfieImageId: ${pageHeader.makerSelfieImageId}');

      if (pageHeader.makerSelfieImageId != null && pageHeader.makerSelfieImageId! > 0) {
        setState(() {
          uploadedImgId = pageHeader.makerSelfieImageId.toString();
          fetchedImageData = null;
        });

        _imageQueue.add({'photoId': pageHeader.makerSelfieImageId.toString(), 'key': 'ltdb'});
        _fetchNextImage();
      }
    }
  }

  void _loadStoredData() async {
    // No Hive loading - start with fresh form
    print('LTDB screen: Starting with fresh form (no Hive storage)');
  }

  void _fetchNextImage() {
    if (_fetchingImage || _imageQueue.isEmpty) return;

    _fetchingImage = true;

    final image = _imageQueue.removeAt(0);
    final photoId = image['photoId']!;
    final key = image['key']!;

    print('Loading LTDB image for photoId: $photoId, key: $key, retry count: ${_retryCounts[photoId] ?? 0}');
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
      print('Retrying LTDB image load for photoId: $photoId, key: $key, attempt: ${_retryCounts[photoId]} of $maxRetries');
      await Future.delayed(retryDelay);
      _imageQueue.insert(0, {'photoId': photoId, 'key': key});
      _fetchNextImage();
    } else {
      print('Max retries reached for LTDB photoId: $photoId, key: $key');
      _retryCounts.remove(photoId);
    }
  }

  Future<String?> _uploadLtdbPhoto(File file) async {
    try {
      print('=== LTDB Photo Upload Started ===');
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
            print('Response imgId: ${state.response.imgId}');
            subscription.cancel();
            completer.complete(state.response.imgId);
          } else if (state is AssetAuditPhotoUploadFailure) {
            print('Error message: ${state.errorMessage}');
            subscription.cancel();
            completer.completeError(state.errorMessage);
          } else {
            print(' LTDB Photo upload in progress...');
          }
        });

        print('Starting LTDB photo upload...');
        context.read<AssetAuditPhotoUploadCubit>().uploadPhoto(
          file: file,
          imgId: imgIdToUse,
          schId: schId,
        );

        print('Waiting for LTDB photo upload result...');
        final result = await completer.future.timeout(
          const Duration(seconds: 30),
          onTimeout: () {
            subscription.cancel();
            throw Exception('Photo upload timeout');
          },
        );

        return result;
      } else {
        throw Exception('Site data not loaded');
      }
    } catch (e) {
      print('❌ Error uploading LTDB photo: $e');
      rethrow;
    }
  }

  bool _validateSerialNumber(String serialNumber, bool isQRCodeScanned) {
    if (widget.assetAuditData == null) return false;

    if (lastValidatedSerial == serialNumber) {
      return true;
    }

    print('=== LTDB Serial Number Validation Debug ===');
    print('Validating serial number: "$serialNumber" (QR Scanned: $isQRCodeScanned)');

    final ltdbData = widget.assetAuditData!.responseData.categories['LTDB'];
    if (ltdbData == null) return false;

    final allItems = ltdbData.assets;
    print('LTDB items available: ${allItems.length}');

    if (allItems.isNotEmpty) {
      print('LTDB items details:');
      for (var item in allItems) {
        print('  - Item: ${item.itemType} | nexgenSerialNo: "${item.nexgenSerialNo}" | mfgSerialNo: "${item.mfgSerialNo}"');
      }
    }

    bool isValid = false;

    if (isQRCodeScanned) {
      isValid = allItems.any(
            (item) => item.nexgenSerialNo?.toLowerCase() == serialNumber.toLowerCase(),
      );
    } else {
      isValid = allItems.any(
            (item) => item.mfgSerialNo?.toLowerCase() == serialNumber.toLowerCase(),
      );
    }

    lastValidatedSerial = serialNumber;
    if (!isValid) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showCustomToast(context, isQRCodeScanned
            ? '❌ Invalid QR Code! Serial number not found in system.'
            : '❌ Invalid manual entry! Serial number not found in system.');
      });
    }

    return isValid;
  }
  Future<void> _showPhotoViewer(BuildContext context, String? photo, String siteAuditSchId) async {
    if (photo == null || photo.isEmpty) {
      showCustomToast(context, 'No photo available to view.');
      return;
    }

    String? imageData;

    // Case 1: Photo is a base64 data URL
    if (photo.startsWith('data:image/')) {
      imageData = photo;
    }
    // Case 2: Photo is a local file path
    else if (await File(photo).exists()) {
      imageData = photo;
    }
    // Case 3: Photo is a photo ID (numeric) from the API
    else if (_isNumeric(photo)) {
      print('Fetching image for photo ID: $photo');
      final completer = Completer<String?>();
      late StreamSubscription subscription;

      subscription = context.read<AssetAuditGetImageCubit>().stream.listen((state) {
        if (state is AssetAuditGetImageSuccess && state.imageData.isNotEmpty) {
          print('Image fetched successfully for photo ID: $photo');
          final finalImageData = state.imageData.startsWith('data:image/')
              ? state.imageData
              : 'data:image/jpeg;base64,${state.imageData}';
          completer.complete(finalImageData);
          subscription.cancel();
        } else if (state is AssetAuditGetImageFailure) {
          print('Failed to fetch image: ${state.errorMessage}');
          showCustomToast(context, 'Failed to load image: ${state.errorMessage}');
          completer.complete(null);
          subscription.cancel();
        }
      });

      context.read<AssetAuditGetImageCubit>().getImage(
        imgId: photo,
        schId: siteAuditSchId,
      );

      imageData = await completer.future;
    }

    if (imageData != null && imageData.isNotEmpty) {
      showDialog(
        context: context,
        builder: (context) => Dialog(
          backgroundColor: Colors.black,
          child: Stack(
            // mainAxisSize: MainAxisSize.min,
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


  void _saveAndExit() async {
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // Post LTDB data to API first
      await _postLtdbData();
      
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
      print('Attempting to update status to: $status');
      await context.read<AuditScheduleStatusCubit>().updateStatus(
        status: status,
        siteAuditSchId: widget.siteAuditSchId,
      );
      print('Status update call completed');
    } catch (e) {
      print('Error updating audit schedule status: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update status: $e')),
      );
    }
  }

  int? _getRemarksAssetAuditSiteRespId() {
    print('=== LTDB Screen: Getting Remarks AssetAuditSiteRespId ===');

    if (widget.assetAuditData == null) {
      print('assetAuditData is null, cannot get remarks ID');
      return null;
    }

    final ltdbData = widget.assetAuditData!.responseData.categories['LTDB'];
    if (ltdbData == null) {
      print('LTDB category data is null');
      return null;
    }

    final remarks = ltdbData.remarks;
    if (remarks.isNotEmpty) {
      print('Found ${remarks.length} remarks in backend data');

      for (var remark in remarks) {
        if (remark.assetAuditSiteRespId != null &&
            remark.assetAuditSiteRespId > 0 &&
            remark.itemType == 'LTDB') {
          print('Using LTDB remarks ID: ${remark.assetAuditSiteRespId}');
          return remark.assetAuditSiteRespId;
        }
      }

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

  Future<void> _postLtdbData() async {
    try {
      final assetAuditState = context.read<AssetAuditCubit>().state;
      if (assetAuditState is AssetAuditLoaded && assetAuditState.assetAuditData.pageHeader.isNotEmpty) {
        List<Map<String, dynamic>> allItemsToPost = [];

        if (savedLtdbItems.isNotEmpty) {
          final enhancedItems = AssetAuditPostHelper.enhanceSavedItems(
            savedItems: savedLtdbItems,
            screenName: 'LTDB',
          );
          allItemsToPost.addAll(enhancedItems);
        }

        if (remarksController.text.isNotEmpty) {
          int? remarksAssetAuditSiteRespId = _getRemarksAssetAuditSiteRespId();

          if (remarksAssetAuditSiteRespId != null) {
            Map<String, dynamic> remarksData = {
              'itemType': 'LTDB',
              'remarks': remarksController.text,
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
            print('LTDB Screen: Added user remarks to post with ID: $remarksAssetAuditSiteRespId, text: "${remarksController.text}"');
          } else {
            print('LTDB Screen: Could not find remarks ID from backend data');
          }
        }

        if (allItemsToPost.isEmpty) {
          print('LTDB Screen: No items to post');
          return;
        }

        final requests = await AssetAuditPostHelper.convertSavedItemsToPostRequest(
          savedItems: allItemsToPost,
          assetAuditData: assetAuditState.assetAuditData,
          itemType: 'LTDB',
          itemTypeId: 4,
          screenName: 'solar_ltdb',
          context: context,
          auditSchId: widget.auditSchId,
        );

        if (requests.isNotEmpty) {
          print('Posting remaining LTDB data: ${requests.length} requests');
          
          // Store the current remarks text before posting
          final currentRemarksText = remarksController.text;
          print('LTDB Screen: Storing current remarks text: "$currentRemarksText"');
          
          context.read<AssetAuditCubit>().postAssetAuditData(requests: requests);
          
          // Refresh the data immediately after posting
          print('Refreshing LTDB data after posting...');
          context.read<AssetAuditCubit>().getAssetAuditData(
            siteType: widget.siteType,
            auditSchId: widget.auditSchId,
            siteAuditSchId: widget.siteAuditSchId,
          );
          
          // Restore the remarks text after refresh to ensure it's not overwritten
          if (currentRemarksText.isNotEmpty) {
            print('LTDB Screen: Restoring remarks text after refresh: "$currentRemarksText"');
            remarksController.text = currentRemarksText;
          }
        }
      } else {
        print('No LTDB items to post - user can navigate without saving items');
      }
    } catch (e) {
      print('Error posting LTDB data: $e');
    }
  }

  bool _isFormValid() {
    if (ltdbSerialController.text.isEmpty) {
      return false;
    }

    if (ltdbPhoto == null || ltdbPhoto!.isEmpty) {
      return false;
    }

    if (!_validateSerialNumber(ltdbSerialController.text, isQRCodeScanned)) {
      return false;
    }

    return true;
  }

  bool _validateForm() {
    setState(() {
      showValidationErrors = true;
    });

    if (ltdbSerialController.text.isEmpty) {
      return false;
    }

    if (ltdbPhoto == null || ltdbPhoto!.isEmpty) {
      return false;
    }

    if (!_validateSerialNumber(ltdbSerialController.text, isQRCodeScanned)) {
      return false;
    }

    return true;
  }

  void _saveLtdbForm() async {
    print('=== LTDB Save Form Started ===');
    print('Form valid: ${_isFormValid()}');
    print('LTDB Photo: $ltdbPhoto');
    print('LTDB Serial: $ltdbSerialNumber');
    print('LTDB Status: $ltdbStatus');

    if (_isFormValid()) {
      String? photoImageId = ltdbPhoto;

      if (ltdbPhoto != null && ltdbPhoto!.isNotEmpty && !ltdbPhoto!.startsWith('http')) {
        try {
          final file = File(ltdbPhoto!);
          if (await file.exists()) {
            print('📤 Uploading LTDB photo: ${ltdbPhoto}');
            photoImageId = await _uploadLtdbPhoto(file);
            print('✅ LTDB photo uploaded successfully, image ID: $photoImageId');
          } else {
            print('❌ LTDB photo file does not exist: ${ltdbPhoto}');
          }
        } catch (e) {
          print('❌ Error uploading LTDB photo: $e');
          showCustomToast(context, 'Error uploading photo: $e');
          return;
        }
      } else {
        print('ℹ️ No LTDB photo to upload or already has image ID');
      }

      setState(() {
        final currentFormData = {
          'serialNumber': ltdbSerialNumber,
          'photo': photoImageId,
          'status': ltdbStatus ?? 'OK',
          'timestamp': DateTime.now(),
          'isQRCodeScanned': isQRCodeScanned,
        };

        final existingItemIndex = savedLtdbItems.indexWhere(
              (item) => item['serialNumber'] == ltdbSerialNumber,
        );

        if (existingItemIndex >= 0) {
          _debugSavedLtdbItems('BEFORE UPDATE');
          savedLtdbItems[existingItemIndex] = currentFormData;
          _debugSavedLtdbItems('AFTER UPDATE');
          print('Updated existing LTDB item: ${currentFormData['serialNumber']}');
        } else {
          _debugSavedLtdbItems('BEFORE ADD');
          savedLtdbItems.add(currentFormData);
          _debugSavedLtdbItems('AFTER ADD');
          currentScannedItems++;
          print('Added new LTDB item: ${currentFormData['serialNumber']}');
        }

        print('Building LTDB saved items list with ${savedLtdbItems.length} items');
        savedLtdbItems.forEach((item) => print('Item: $item'));

        ltdbSerialNumber = null;
        ltdbPhoto = null;
        ltdbStatus = null;
        lastValidatedSerial = null;
        ltdbSerialController.clear();
        ltdbCardKey++;
        hasUnsavedChanges = false;
        showValidationErrors = false;
      });

      print('✅ LTDB item saved successfully! Total items: ${savedLtdbItems.length}');
      print('✅ After save - savedLtdbItems length: ${savedLtdbItems.length}');
      print('✅ After save - savedLtdbItems content: $savedLtdbItems');
    } else {
      print('❌ LTDB form validation failed');
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
      ltdbSerialNumber = item['serialNumber'];
      ltdbPhoto = item['photo'];
      ltdbStatus = item['status'];
      isQRCodeScanned = item['isQRCodeScanned'] ?? false;
      ltdbSerialController.text = item['serialNumber'] ?? '';
      displayedImageBase64 = null; // Clear Base64 to avoid showing old image
      isLoadingImage = false; // Reset loading state
      savedLtdbItems.remove(item);
      currentScannedItems--;
      hasUnsavedChanges = true;
      ltdbCardKey++;
    });

    // Load image with caching for faster loading
    if (ltdbPhoto != null && ltdbPhoto!.isNotEmpty && _isNumeric(ltdbPhoto!)) {
      // Check if image is already cached
      if (_imageCache.containsKey(ltdbPhoto!)) {
        setState(() {
          displayedImageBase64 = _imageCache[ltdbPhoto!];
          isLoadingImage = false;
        });
        print('LTDB: Using cached image for photoId: $ltdbPhoto');
      } else {
        // Load from API if not cached
        print('=== LTDB Edit: Fetching image for photo ID: $ltdbPhoto ===');
        setState(() {
          _currentRequestedImageId = ltdbPhoto;
          _isRequestingImage = true;
          isLoadingImage = true;
        });

        context.read<AssetAuditGetImageCubit>().getImage(
          imgId: ltdbPhoto!,
          schId: widget.siteAuditSchId,
        );
      }
    } else {
      setState(() {
        displayedImageBase64 = null;
        isLoadingImage = false;
      });
    }



  }

  bool _isNumeric(String str) {
    return int.tryParse(str) != null;
  }

  String? _getNextAvailableScreen() {
    return AssetAuditNavigationHelper.getNextAvailableScreen(widget.assetAuditData, 'LTDB');
  }

  String? _getPreviousAvailableScreen() {
    return AssetAuditNavigationHelper.getPreviousAvailableScreen(widget.assetAuditData, 'LTDB');
  }

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

  @override
  Widget build(BuildContext context) {
    print('=== LTDBScreen build() called ===');
    print('savedLtdbItems.length: ${savedLtdbItems.length}');
    print('hasUnsavedChanges: $hasUnsavedChanges');
    
    return MultiBlocListener(
      listeners: [
        BlocListener<AssetAuditGetImageCubit, AssetAuditGetImageState>(
          listener: (context, state) {
            // Only handle images for the main form, not for saved items
            // This listener should only be triggered when editing an item from the main form
            if (state is AssetAuditGetImageSuccess && 
                _isRequestingImage && 
                _currentRequestedImageId != null) {
              print('=== LTDB Screen: Image fetch success for requested image ===');
              print('Image data length: ${state.imageData.length}');
              print('Image data preview: ${state.imageData.substring(0, state.imageData.length > 100 ? 100 : state.imageData.length)}...');

              if (state.imageData.isNotEmpty) {
                String finalImageData;
                if (state.imageData.startsWith('data:image/')) {
                  finalImageData = state.imageData;
                  print('LTDB: Image data is already in data URL format');
                } else {
                  finalImageData = 'data:image/jpeg;base64,${state.imageData}';
                  print('LTDB: Added data URL prefix to raw base64 data');
                }

                // Cache the image for future use
                _imageCache[_currentRequestedImageId!] = finalImageData;
                
                setState(() {
                  ltdbPhoto = finalImageData;
                  ltdbCardKey++;
                  _isRequestingImage = false;
                  _currentRequestedImageId = null;
                });

                print('LTDB photo updated with final image data and cached');
              } else {
                print('LTDB Screen: Received empty image data');
                setState(() {
                  ltdbPhoto = null;
                  ltdbCardKey++;
                  _isRequestingImage = false;
                  _currentRequestedImageId = null;
                });
              }
            } else if (state is AssetAuditGetImageFailure && _isRequestingImage) {
              print('=== LTDB Screen: Image fetch failed for requested image ===');
              print('Error: ${state.errorMessage}');
              setState(() {
                ltdbPhoto = null;
                ltdbCardKey++;
                _isRequestingImage = false;
                _currentRequestedImageId = null;
              });
            }
          },
        ),
        BlocListener<AssetAuditCubit, AssetAuditState>(
          listener: (context, state) {
            if (state is AssetAuditLoaded) {
              print('=== LTDB Screen: AssetAuditLoaded ===');
              final ltdbData = state.assetAuditData.responseData.categories['LTDB'];
                if (ltdbData != null) {
                  setState(() {
                    totalLtdbItems = ltdbData.assets.length;

                    // Only load items from API if we don't have any user-saved items
                    // This prevents overwriting user's saved items when the BlocListener fires
                    if (savedLtdbItems.isEmpty) {
                      // Load items that have been successfully posted to API AND have user interaction
                      // (either photo taken or serial number entered - regardless of QR scan or manual entry)
                      final postedItems = ltdbData.assets.where((asset) =>
                      asset.assetAuditSiteRespId != null &&
                          asset.photoId != null
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

                      savedLtdbItems = postedItems;
                      currentScannedItems = savedLtdbItems.length;
                      print('LTDB: Loaded ${savedLtdbItems.length} items from API (list was empty)');
                    } else {
                      print('LTDB: Skipping API load, ${savedLtdbItems.length} items already saved by user');
                    }
                    
                    // Only update remarks from API if user hasn't made changes
                    if (ltdbData.remarks.isNotEmpty && remarksController.text.isEmpty) {
                      remarksController.text = ltdbData.remarks.first.itemTypeRemark ?? '';
                    }
                  });
                print('LTDB items updated from API: ${savedLtdbItems.length} items');
                print('LTDB savedLtdbItems: $savedLtdbItems');
                print('LTDB total assets: ${ltdbData.assets.length}');
                print('LTDB assets with photoId: ${ltdbData.assets.where((asset) => asset.photoId != null).length}');
                print('LTDB assets with assetAuditSiteRespId: ${ltdbData.assets.where((asset) => asset.assetAuditSiteRespId != null).length}');
              } else {
                print('LTDB category not found in loaded data');
              }
            } else if (state is AssetAuditError) {
              showCustomToast(context, state.message);
            } else if (state is AssetAuditPostSuccess) {
              print('LTDB data posted successfully: ${state.responses.length} responses');
              // Only show toast if this screen initiated the post action
              if (mounted && state.responses.any((response) => response.itemTypeId == 5)) {
                showCustomToast(context, 'LTDB data saved successfully!');
              }
              context.read<AssetAuditCubit>().getAssetAuditData(
                siteType: widget.siteType,
                auditSchId: widget.auditSchId,
                siteAuditSchId: widget.siteAuditSchId,
              );
            } else if (state is AssetAuditPostError) {
              print('Error posting LTDB data: ${state.message}');
              // Only show toast if this screen initiated the post action
              if (mounted) {
                showCustomToast(context, 'Error saving LTDB data: ${state.message}');
              }
            }
          },
        ),
        BlocListener<AssetAuditGetImageCubit, AssetAuditGetImageState>(
          listener: (context, state) async {
            if (state is AssetAuditGetImageSuccess) {
              print('LTDB Image loaded for photoId: $_lastRequestedPhotoId, data length: ${state.imageData.length}');
              final assetAuditState = context.read<AssetAuditCubit>().state;
              if (assetAuditState is AssetAuditLoaded && assetAuditState.assetAuditData.pageHeader.isNotEmpty) {
                final schId = assetAuditState.assetAuditData.pageHeader.first.siteAuditSchId.toString();

                if (state.imageData.isNotEmpty) {
                  HiveDB.updateAssetAuditSelfie(
                    siteAuditSchId: schId,
                    newImageId: _lastRequestedPhotoId ?? '',
                    newImageData: state.imageData,
                  );

                  setState(() {
                    fetchedImageData = state.imageData;
                    _hasFormDataChanges = true;
                  });

                  _fetchingImage = false;
                  _fetchNextImage();
                } else {
                  print('Empty image data received for LTDB photoId: $_lastRequestedPhotoId');
                  await _handleImageLoadRetry(_lastRequestedPhotoId ?? '', 'ltdb');
                }
              } else {
                print('AssetAuditCubit state is not AssetAuditLoaded or pageHeader is empty');
                _fetchingImage = false;
                _fetchNextImage();
              }
            } else if (state is AssetAuditGetImageFailure) {
              print('Failed to load LTDB image for photoId: $_lastRequestedPhotoId, error: ${state.errorMessage}');
              await _handleImageLoadRetry(_lastRequestedPhotoId ?? '', 'ltdb');
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
                message: "Do you want to cancel the Asset Audit for Site (ID: SITE-38974)?",
                onSaveAndExit: () async {
                  Navigator.of(context).pop();
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
                    message: "Do you want to cancel the Asset Audit for Site (ID: SITE-38974)?",
                    onSaveAndExit: () async {
                      Navigator.of(context).pop();
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
                            bottom: MediaQuery.of(context).viewInsets.bottom + 120,
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
                                  label: "LTDB Make",
                                  initialValue: widget.assetAuditData?.responseData.categories['LTDB']?.assets.isNotEmpty == true
                                      ? widget.assetAuditData!.responseData.categories['LTDB']!.assets.first.oemName ?? "N/A"
                                      : "N/A",
                                  isRequired: true,
                                  isEditable: false,
                                ),
                                getHeight(15),
                                CustomFormField(
                                  label: "Type of LTDB",
                                  initialValue: widget.assetAuditData?.responseData.categories['LTDB']?.assets.isNotEmpty == true
                                      ? widget.assetAuditData!.responseData.categories['LTDB']!.assets.first.itemType ?? "N/A"
                                      : "N/A",
                                  isRequired: false,
                                  isEditable: false,
                                ),
                                getHeight(15),
                                CustomFormField(
                                  label: "Count of LTDB",
                                  initialValue: widget.assetAuditData?.responseData.categories['LTDB']?.assets.length.toString() ?? "0",
                                  isRequired: false,
                                  isEditable: false,
                                ),
                                getHeight(15),
                                Text(
                                  "LTDB Details",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white,
                                    fontFamily: fontFamilyMontserrat,
                                  ),
                                ),
                                getHeight(3),
                                CustomInfoCard(
                                  key: ValueKey('ltdb_$ltdbCardKey'),
                                  serialLabel: "LTDB - Serial Number",
                                  serialHintText: "LTDB Serial Number *",
                                  photoLabel: "Add a Photo",
                                  statusLabel: "Status",
                                  serialController: ltdbSerialController,
                                  onSave: _saveLtdbForm,
                                  isStatusEditable: true,
                                  backendStatus: false,
                                  remarksLabel: widget.assetAuditData?.responseData.categories['LTDB']?.assets.isNotEmpty == true
                                      ? "LTDB (${widget.assetAuditData!.responseData.categories['LTDB']!.assets.first.capacity ?? 'N/A'})"
                                      : "LTDB (Capacity)",
                                  remarksHintText: widget.assetAuditData?.responseData.categories['LTDB']?.assets.isNotEmpty == true
                                      ? widget.assetAuditData!.responseData.categories['LTDB']!.assets.first.capacity ?? "N/A"
                                      : "N/A",
                                  remarksController: null,
                                  isRemarksEditable: false,
                                  onPhotoTap: (photoPath) {
                                    setState(() {
                                      ltdbPhoto = photoPath;
                                      hasUnsavedChanges = true;
                                    });
                                  },
                                  onStatusChanged: (val) {
                                    setState(() {
                                      ltdbStatus = val ? "OK" : "Not OK";
                                      hasUnsavedChanges = true;
                                    });
                                  },
                                  onSerialChanged: (serialNumber) {
                                    setState(() {
                                      ltdbSerialNumber = serialNumber;
                                      isQRCodeScanned = false;
                                      hasUnsavedChanges = true;
                                    });
                                  },
                                  initialStatus: ltdbStatus == "OK"
                                      ? true
                                      : (ltdbStatus == "Not OK" ? false : null),
                                  initialPhotoPath: ltdbPhoto,
                                  isEditable: true,
                                ),
                                getHeight(8),
                                Builder(
                                  builder: (context) {
                                    print('=== Builder for saved items list called ===');
                                    print('savedLtdbItems.length: ${savedLtdbItems.length}');
                                    return Container(
                                      key: ValueKey('saved_items_${savedLtdbItems.length}'),
                                      child: _buildLtdbSavedItemsList(),
                                    );
                                  },
                                ),
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
                                text: AssetAuditNavigationHelper.getSolarPreviousScreenName('LTDB'),
                                isLeftArrow: true,
                                backgroundColor: AppColors.buttonColorBackBg,
                                textColor: AppColors.buttonColorTextBg,
                                onPressed: () {
                                  final previousScreen = AssetAuditNavigationHelper.getPreviousAvailableScreen(widget.assetAuditData, 'LTDB');
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
                                    return ArrowButton(
                                      text: "Submit",
                                      isLeftArrow: false,
                                      backgroundColor: AppColors.buttonColorBg,
                                      textColor: AppColors.buttonColorSite,
                                      onPressed: () async {
                                        await _postLtdbData();
                                        Navigator.pop(context);
                                      },
                                    );
                                  } else {
                                    return ArrowButton(
                                      text: nextScreen,
                                      isLeftArrow: false,
                                      backgroundColor: AppColors.buttonColorBg,
                                      textColor: AppColors.buttonColorSite,
                                      onPressed: () async {
                                        print('=== LTDB Navigation to $nextScreen ===');
                                        print('Passing asset audit data: ${widget.assetAuditData != null}');
                                        await _postLtdbData();
                                        _navigateToNextScreen(context, nextScreen);
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

  Widget _buildLtdbSavedItemsList() {
    savedLtdbItems.forEach((item) => print('Item: $item'));

    // Always show the header, even when list is empty
    if (savedLtdbItems.isEmpty) {
      print('LTDB savedLtdbItems is EMPTY - showing header only');
    }

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

              if (savedLtdbItems.isNotEmpty) ...[
                ...savedLtdbItems.map((item) {
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
                            icon: Icon(
                              Icons.camera_alt,
                              color: item['photo'] != null && item['photo'].isNotEmpty
                                  ? AppColors.color555555
                                  : Colors.grey,
                            ),
                            onPressed: item['photo'] != null && item['photo'].isNotEmpty
                                ? () {
                              _showPhotoViewer(context, item['photo'], widget.siteAuditSchId);
                            }
                                : null,
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
              ]
            ],
          ),
        ),
      ],
    );
  }
}
