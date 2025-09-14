import 'package:app/commonWidgets/custom_buttons/arrow_botton.dart';
import 'package:app/constants/constants_methods.dart';
import 'package:app/utils/asset_audit_navigation_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:io';
import 'dart:async';

import '../../../bloc/asset_audit_cubit.dart';
import '../../../bloc/asset_audit_state.dart';
import '../../../bloc/asset_audit_photo_upload_cubit.dart';
import '../../../bloc/asset_audit_get_image_cubit.dart';
import '../../../bloc/audit_schedule_status_cubit.dart';
import '../../../models/asset_audit_post_model.dart';
import '../../../utils/asset_audit_post_helper.dart';
import '../../../commonWidgets/asset_type_card.dart';
import '../../../commonWidgets/custom_dialogs/unsaved_changes_dialog.dart';
import '../../../commonWidgets/custom_form_appbar.dart';
import '../../../commonWidgets/custom_form_field.dart';
import '../../../commonWidgets/custom_remark.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_images.dart';
import '../../../constants/constants_strings.dart';
import '../../../models/asset_audit_model.dart';
import '../../home_screen.dart';

class ACDBScreen extends StatefulWidget {
  final String siteType;
  final String auditSchId;
  final String siteAuditSchId;
  final AssetAuditModel? assetAuditData; // Complete asset audit data

  const ACDBScreen({
    super.key,
    required this.siteType,
    required this.auditSchId,
    required this.siteAuditSchId,
    this.assetAuditData, // Complete asset audit data
  });

  @override
  State<ACDBScreen> createState() => _ACDBScreenState();
}

class _ACDBScreenState extends State<ACDBScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController serialController = TextEditingController();
  bool hasUnsavedChanges = false;
  bool showValidationErrors = false;

  // ACDB field values
  String? acdbSerialNumber;
  String? acdbPhoto;
  String? acdbStatus;
  final remarksController = TextEditingController();
  final ratingController = TextEditingController();
  int acdbCardKey = 0;
  List<Map<String, dynamic>> savedAcdbItems = [];
  bool isQRCodeScanned =
      false; // Track if serial was scanned or manually entered

  // Image loading variables
  String? _currentRequestedImageId;
  bool _isRequestingImage = false;

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

  // Controllers for CustomInfoCard
  final TextEditingController acdbSerialController = TextEditingController();

  // Get ACDB data from API (ACDB data is nested under SMPS)
  int get totalAcdbItems {
    final smpsData = widget.assetAuditData?.responseData.categories['SMPS'];
    if (smpsData?.subCategories != null &&
        smpsData!.subCategories!['ACDB'] != null) {
      // Get ACDB items from SMPS subcategories
      final acdbAssets = smpsData.subCategories!['ACDB']!;
      return acdbAssets.length;
    }
    return 0;
  }

  // Get ACDB category data (from SMPS category)
  CategoryData? get acdbCategoryData {
    final smpsData = widget.assetAuditData?.responseData.categories['SMPS'];
    if (smpsData != null) {
      // Get ACDB items from SMPS subcategories
      final acdbAssets = smpsData.subCategories?['ACDB'] ?? [];
      final acdbRemarks = smpsData.remarks
          .where((remark) => remark.itemType == 'ACDB')
          .toList();

      return CategoryData(assets: acdbAssets, remarks: acdbRemarks);
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    serialController.addListener(_onFormChanged);
    remarksController.addListener(_onFormChanged);
    ratingController.addListener(_onFormChanged);
    _setupGetImageListener();
    _loadExistingData();
  }

  @override
  void dispose() {
    serialController.removeListener(_onFormChanged);
    remarksController.removeListener(_onFormChanged);
    ratingController.removeListener(_onFormChanged);
    serialController.dispose();
    remarksController.dispose();
    ratingController.dispose();
    acdbSerialController.dispose();
    _getImageSubscription?.cancel();
    super.dispose();
  }

  String _formatDateForApi(DateTime dateTime) {
    return "${dateTime.day.toString().padLeft(2, '0')}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}";
  }

  void _loadExistingData() async {
    // Load existing ACDB data from API
    print('ACDB screen: Loading existing data from API');

    final assetAuditState = context.read<AssetAuditCubit>().state;
    if (assetAuditState is AssetAuditLoaded &&
        assetAuditState.assetAuditData.responseData.categories.isNotEmpty) {
      final smpsData =
          assetAuditState.assetAuditData.responseData.categories['SMPS'];

      if (smpsData != null &&
          smpsData.subCategories != null &&
          smpsData.subCategories!['ACDB'] != null) {
        // Get ACDB items from SMPS subcategories
        final acdbAssets = smpsData.subCategories!['ACDB']!;
        print(
          'ACDB screen: Found ${acdbAssets.length} ACDB assets in SMPS subcategories',
        );

        setState(() {
          // Only show items that have been interacted with by the user (have photo_id and qr_code_scanned is not null)
          savedAcdbItems = acdbAssets
              .where(
                (asset) => asset.photoId != null && asset.qrCodeScanned != null,
              )
              .map((asset) {
                return {
                  'serialNumber':
                      asset.mfgSerialNo ?? asset.nexgenSerialNo ?? '',
                  'photo': asset.photoId?.toString(),
                  'status': asset.assetStatus ?? 'OK',
                  'isQRCodeScanned': asset.qrCodeScanned ?? false,
                  'timestamp': DateTime.now(),
                  'assetAuditSiteRespId': asset.assetAuditSiteRespId,
                };
              })
              .toList();
        });

        // Load photos for ACDB assets that have them
        for (var asset in acdbAssets) {
          if (asset.photoId != null && asset.photoId! > 0) {
            print(
              'ACDB screen: Loading image for asset ${asset.assetAuditSiteRespId} with photoId ${asset.photoId}',
            );
            _imageQueue.add({
              'photoId': asset.photoId.toString(),
              'key': 'acdb_${asset.assetAuditSiteRespId}',
            });
          }
        }

        if (_imageQueue.isNotEmpty) {
          _fetchNextImage();
        } else {
          print('ACDB screen: No ACDB assets with photos found');
        }

        // Initialize remarks from API only if user hasn't made changes
        if (smpsData.remarks.isNotEmpty && remarksController.text.isEmpty) {
          final acdbRemarks = smpsData.remarks
              .where((remark) => remark.itemType == 'ACDB')
              .toList();
          if (acdbRemarks.isNotEmpty) {
            remarksController.text = acdbRemarks.first.itemTypeRemark ?? '';
            print(
              'ACDB screen: Loaded remarks from API: "${remarksController.text}"',
            );
          }
        }
      } else {
        print('ACDB screen: No SMPS data found');
      }
    }
  }

  void _onFormChanged() {
    setState(() {
      hasUnsavedChanges =
          serialController.text.isNotEmpty || ratingController.text.isNotEmpty;

      if (showValidationErrors &&
          (serialController.text.isNotEmpty ||
              ratingController.text.isNotEmpty)) {
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

      // Post ACDB data to API first
      await _postAcdbData();

      // Update audit schedule status
      await _updateAuditScheduleStatus("In Progress");

      // Close loading dialog
      Navigator.of(context).pop();

      // Navigate to home screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => HomeScreen()),
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to update status: $e')));
    }
  }

  bool _isFormValid() {
    print('=== ACDB VALIDATION: Checking form validity ===');
    print('Serial controller text: "${acdbSerialController.text}"');
    print('Photo: $acdbPhoto');
    print('Rating controller text: "${ratingController.text}"');

    if (acdbSerialController.text.isEmpty) {
      print('=== ACDB VALIDATION: Serial number is empty ===');
      return false;
    }

    if (acdbPhoto == null || acdbPhoto!.isEmpty) {
      print('=== ACDB VALIDATION: Photo is null or empty ===');
      return false;
    }

    if (ratingController.text.isEmpty) {
      print('=== ACDB VALIDATION: Rating is empty ===');
      return false;
    }

    print('=== ACDB VALIDATION: Form is valid ===');
    return true;
  }

  bool _validateForm() {
    if (acdbSerialController.text.isEmpty) {
      return false;
    }

    if (acdbPhoto == null || acdbPhoto!.isEmpty) {
      return false;
    }

    if (ratingController.text.isEmpty) {
      return false;
    }

    return true;
  }

  void _setValidationErrors() {
    setState(() {
      showValidationErrors = true;
    });
  }

  void _saveAcdbForm() async {
    print('=== ACDB SAVE: Starting save form ===');
    print('Current savedAcdbItems count: ${savedAcdbItems.length}');
    print('Total ACDB items: $totalAcdbItems');
    print('Serial number: $acdbSerialNumber');
    print('Photo: $acdbPhoto');
    print('Status: $acdbStatus');

    if (savedAcdbItems.length > totalAcdbItems) {
      print('=== ACDB SAVE: Maximum items reached ===');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Maximum number of ACDB items ($totalAcdbItems) already added.',
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
      String? photoImageId = acdbPhoto;

      // If photo is a file path, upload it and get image ID
      if (acdbPhoto != null &&
          acdbPhoto!.isNotEmpty &&
          !acdbPhoto!.startsWith('http')) {
        try {
          final file = File(acdbPhoto!);
          if (await file.exists()) {
            print('📤 Uploading ACDB photo: ${acdbPhoto}');
            photoImageId = await _uploadAcdbPhoto(file);
            print(
              '✅ ACDB photo uploaded successfully, image ID: $photoImageId',
            );
          } else {
            print('❌ ACDB photo file does not exist: ${acdbPhoto}');
          }
        } catch (e) {
          print('❌ Error uploading ACDB photo: $e');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error uploading photo: $e'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
      } else {
        print('ℹ️ No ACDB photo to upload or already has image ID');
      }

      setState(() {
        Map<String, dynamic> currentFormData = {
          'serialNumber': acdbSerialNumber,
          'photo': photoImageId,
          // Use image ID instead of file path
          'status': acdbStatus ?? "OK",
          'rating': ratingController.text.trim(),
          // Add rating value
          'timestamp': DateTime.now(),
          'isQRCodeScanned': isQRCodeScanned,
          // Store whether it was scanned or manual
        };

        savedAcdbItems.add(currentFormData);

        print('=== ACDB SAVE: Item added to savedAcdbItems ===');
        print('New savedAcdbItems count: ${savedAcdbItems.length}');
        print('Added item: $currentFormData');

        acdbSerialNumber = null;
        acdbPhoto = null;
        acdbStatus = null;
        isQRCodeScanned = false;

        acdbSerialController.clear();
        ratingController.clear();

        acdbCardKey++;

        hasUnsavedChanges = false;
        showValidationErrors = false;
      });

      int remainingAcdb = totalAcdbItems - savedAcdbItems.length;
    } else {
      print('=== ACDB SAVE: Form validation failed ===');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please fill in all required fields (Serial Number, Photo, and Rating)',
          ),
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
    print('=== ACDB EDIT: Restoring item data ===');
    print('Item data: $item');
    print('Serial: ${item["serialNumber"]}');
    print('Photo: ${item["photo"]}');
    print('Status: ${item["status"]}');
    print('Rating: ${item["rating"]}');

    setState(() {
      acdbSerialNumber = item["serialNumber"];
      acdbStatus = item["status"];
      isQRCodeScanned =
          item["isQRCodeScanned"] ?? false; // Restore QR scan status

      acdbSerialController.text = item["serialNumber"] ?? "";
      isLoadingImage = false; // Reset loading state

      // Set rating controller text if rating exists
      if (item["rating"] != null) {
        ratingController.text = item["rating"];
        print('=== ACDB EDIT: Rating restored to: ${item["rating"]} ===');
      }

      savedAcdbItems.remove(item);

      hasUnsavedChanges = true;

      // Force rebuild of the CustomInfoCard to show restored values
      acdbCardKey++;
    });

    // Handle photo data - check if it's base64 data or photo ID
    String? photoData = item["photo"];
    if (photoData != null && photoData.isNotEmpty) {
      if (photoData.startsWith('data:image/')) {
        // It's already base64 image data
        setState(() {
          acdbPhoto = photoData;
        });
      } else if (_isNumeric(photoData)) {
        // It's a photo ID, load the image
        setState(() {
          _currentRequestedImageId = photoData;
          _isRequestingImage = true;
        });
        context.read<AssetAuditGetImageCubit>().getImage(
          imgId: photoData,
          schId: widget.siteAuditSchId,
        );
      } else {
        // It's a file path or other format
        setState(() {
          acdbPhoto = photoData;
        });
      }
    }

    print('=== ACDB EDIT: After setState ===');
    print('acdbStatus: $acdbStatus');
    print('ratingController.text: ${ratingController.text}');

    // Load image immediately without delays (only if not already loaded)
    if (acdbPhoto != null && acdbPhoto!.isNotEmpty && _isNumeric(acdbPhoto!)) {
      // Only load if we don't already have the image data
      if (displayedImageBase64 == null || displayedImageBase64!.isEmpty) {
        print('=== ACDB Edit: Fetching image for photo ID: $acdbPhoto ===');
        setState(() {
          isLoadingImage = true;
        });

        // Load image immediately
        context.read<AssetAuditGetImageCubit>().getImage(
          imgId: acdbPhoto!,
          schId: widget.siteAuditSchId,
        );
      } else {
        print('=== ACDB Edit: Image already loaded, using cached data ===');
      }
    }
  }

  /// Setup get image listener
  void _setupGetImageListener() {
    _getImageSubscription = context.read<AssetAuditGetImageCubit>().stream.listen((
      state,
    ) async {
      if (state is AssetAuditGetImageSuccess) {
        print(
          'Image loaded for ACDB photoId: $_lastRequestedPhotoId, data length: ${state.imageData.length}',
        );

        if (state.imageData.isNotEmpty) {
          setState(() {
            fetchedImageData = state.imageData;
            _hasFormDataChanges = true;
          });

          _fetchingImage = false;
          _fetchNextImage();
        } else {
          print(
            'Empty image data received for ACDB photoId: $_lastRequestedPhotoId',
          );
          await _handleImageLoadRetry(_lastRequestedPhotoId ?? '', 'acdb');
        }
      } else if (state is AssetAuditGetImageFailure) {
        print(
          'Failed to load ACDB image for photoId: $_lastRequestedPhotoId, error: ${state.errorMessage}',
        );
        await _handleImageLoadRetry(_lastRequestedPhotoId ?? '', 'acdb');
      } else if (state is AssetAuditGetImageLoading) {
        setState(() {
          isLoadingImage = true;
        });
        print('=== ACDB Get Image Loading ===');
      }
    });
  }

  /// Check if string is numeric
  bool _isNumeric(String str) {
    return double.tryParse(str) != null;
  }

  /// Upload ACDB photo and return image ID
  Future<String?> _uploadAcdbPhoto(File file) async {
    try {
      print('=== ACDB Photo Upload Started ===');
      print('File path: ${file.path}');
      print('File exists: ${await file.exists()}');
      print('File size: ${await file.length()} bytes');

      final assetAuditState = context.read<AssetAuditCubit>().state;
      if (assetAuditState is AssetAuditLoaded &&
          assetAuditState.assetAuditData.pageHeader.isNotEmpty) {
        final schId = assetAuditState
            .assetAuditData
            .pageHeader
            .first
            .siteAuditSchId
            .toString();
        print('Site Audit Sch ID: $schId');

        final imgIdToUse = "0";
        print('Image ID to use: $imgIdToUse');

        final completer = Completer<String?>();

        late StreamSubscription subscription;
        subscription = context.read<AssetAuditPhotoUploadCubit>().stream.listen(
          (state) {
            print('=== AssetAuditPhotoUploadCubit State Changed ===');
            print('State type: ${state.runtimeType}');

            if (state is AssetAuditPhotoUploadSuccess) {
              print('✅ ACDB Photo upload SUCCESS!');
              print('Response imgId: ${state.response.imgId}');
              subscription.cancel();
              completer.complete(state.response.imgId);
            } else if (state is AssetAuditPhotoUploadFailure) {
              print('❌ ACDB Photo upload FAILED!');
              print('Error message: ${state.errorMessage}');
              subscription.cancel();
              completer.completeError(state.errorMessage);
            } else {
              print('📤 ACDB Photo upload in progress...');
            }
          },
        );

        print('Starting ACDB photo upload...');
        context.read<AssetAuditPhotoUploadCubit>().uploadPhoto(
          file: file,
          imgId: imgIdToUse,
          schId: schId,
        );

        return await completer.future;
      } else {
        throw Exception('Asset audit data not available');
      }
    } catch (e) {
      print('❌ ACDB Photo upload error: $e');
      rethrow;
    }
  }

  /// Post ACDB data to API
  // Future<void> _postAcdbData() async {
  //   print('=== ACDB Post Data Started ===');
  //
  //   print('=== ACDB POST: Starting POST data ===');
  //   print('Saved ACDB items count: ${savedAcdbItems.length}');
  //   print('Remarks text: "${remarksController.text.trim()}"');
  //
  //   if (savedAcdbItems.isEmpty && remarksController.text.trim().isEmpty) {
  //     print('=== ACDB POST: No data to post, returning ===');
  //     return;
  //   }
  //
  //   try {
  //     // Collect all items and remarks
  //     List<Map<String, dynamic>> allItemsToPost = [];
  //
  //     // Add saved ACDB items with proper structure
  //     for (var item in savedAcdbItems) {
  //       Map<String, dynamic> formattedItem = {
  //         'serialNumber': item['serialNumber'],
  //         'photo': item['photo'],
  //         'status': item['status'],
  //         'photoTakenTs': item['timestamp']?.toString() ?? DateTime.now().toString(),
  //         'isQRCodeScanned': item['isQRCodeScanned'] ?? false,
  //         'localQrCodeScannedTs': item['timestamp']?.toString() ?? DateTime.now().toString(),
  //         'localCreatedDt': item['timestamp']?.toString() ?? DateTime.now().toString(),
  //         'localModifiedDt': item['timestamp']?.toString() ?? DateTime.now().toString(),
  //       };
  //       allItemsToPost.add(formattedItem);
  //     }
  //
  //     // Add user remarks if any - use the correct structure for remarks
  //     if (remarksController.text.trim().isNotEmpty) {
  //       Map<String, dynamic> remarksData = {
  //         'recordType': 'remarks',
  //         'itemType': 'ACDB',
  //         'remarks': remarksController.text.trim(),
  //         'status': 'OK',
  //         'serialNumber': 'REMARKS',
  //         'photo': null,
  //         'photoTakenTs': DateTime.now().toString(),
  //         'isQRCodeScanned': false,
  //         'localQrCodeScannedTs': DateTime.now().toString(),
  //         'localCreatedDt': DateTime.now().toString(),
  //         'localModifiedDt': DateTime.now().toString(),
  //       };
  //       allItemsToPost.add(remarksData);
  //       print('ACDB Screen: Added user remarks to post, text: "${remarksController.text.trim()}"');
  //     }
  //
  //     if (allItemsToPost.isEmpty) {
  //       print('ACDB Screen: No items to post');
  //       return;
  //     }
  //
  //     // Convert to POST request format
  //     final requests = await AssetAuditPostHelper.convertSavedItemsToPostRequest(
  //       savedItems: allItemsToPost,
  //       assetAuditData: widget.assetAuditData!,
  //       itemType: 'ACDB',
  //       itemTypeId: 7, // ACDB item type ID
  //       screenName: 'solar_acdb',
  //       context: context,
  //       auditSchId: widget.auditSchId,
  //     );
  //
  //     // Post data
  //     if (requests.isNotEmpty) {
  //       print('ACDB Screen: Posting ${requests.length} requests');
  //       context.read<AssetAuditCubit>().postAssetAuditData(requests: requests);
  //     }
  //
  //     print('ACDB Screen: All data posted successfully');
  //   } catch (e) {
  //     print('ACDB Screen: Error posting data: $e');
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(
  //         content: Text('Error posting data: $e'),
  //         backgroundColor: Colors.red,
  //       ),
  //     );
  //   }
  // }

  // Helper method to get the next available screen based on data availability
  String? _getNextAvailableScreen() {
    return AssetAuditNavigationHelper.getNextAvailableScreen(
      widget.assetAuditData,
      'ACDB',
    );
  }

  // Helper method to get the previous available screen based on data availability
  String? _getPreviousAvailableScreen() {
    return AssetAuditNavigationHelper.getPreviousAvailableScreen(
      widget.assetAuditData,
      'ACDB',
    );
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

  void _fetchNextImage() {
    if (_fetchingImage || _imageQueue.isEmpty) return;

    _fetchingImage = true;

    final image = _imageQueue.removeAt(0);
    final photoId = image['photoId']!;
    final key = image['key']!;

    print(
      'Loading ACDB image for photoId: $photoId, key: $key, retry count: ${_retryCounts[photoId] ?? 0}',
    );
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
      print(
        'Retrying ACDB image load for photoId: $photoId, key: $key, attempt: ${_retryCounts[photoId]} of $maxRetries',
      );
      await Future.delayed(retryDelay);
      _imageQueue.insert(0, {'photoId': photoId, 'key': key});
      _fetchNextImage();
    } else {
      print('Max retries reached for ACDB photoId: $photoId, key: $key');
      _retryCounts.remove(photoId);
    }
  }

  // int? _getRemarksAssetAuditSiteRespId() {
  //   final pcuData = widget.assetAuditData?.responseData.categories['PCU'];
  //   if (pcuData != null && pcuData.remarks.isNotEmpty) {
  //     return pcuData.remarks.first.assetAuditSiteRespId;
  //   }
  //   print('No valid remarks ID found in backend data');
  //   return null;
  // }

  Future<void> _postAcdbData() async {
    try {
      final assetAuditState = context.read<AssetAuditCubit>().state;
      if (assetAuditState is AssetAuditLoaded &&
          assetAuditState.assetAuditData.pageHeader.isNotEmpty) {
        List<Map<String, dynamic>> allItemsToPost = [];

        if (savedAcdbItems.isNotEmpty) {
          print(
            '=== ACDB POST: Processing ${savedAcdbItems.length} saved items ===',
          );
          for (int i = 0; i < savedAcdbItems.length; i++) {
            print('Item $i: ${savedAcdbItems[i]}');
          }

          // Enhance saved items with rating in itemTypeRemark field
          final enhancedItems = savedAcdbItems.map((item) {
            final enhancedItem = {
              ...item,
              'itemTypeRemark': item['rating'] ?? '',
              // Add rating to itemTypeRemark field
              'remarks': item['rating'] ?? '',
              // Also add to remarks field for compatibility
            };
            print('=== ACDB POST: Enhanced item with rating ===');
            print('Original rating: ${item['rating']}');
            print('Enhanced itemTypeRemark: ${enhancedItem['itemTypeRemark']}');
            print('Enhanced remarks: ${enhancedItem['remarks']}');
            return enhancedItem;
          }).toList();

          final postItems = AssetAuditPostHelper.enhanceSavedItems(
            savedItems: enhancedItems,
            screenName: 'solar_acdb',
          );
          print('=== ACDB POST: Enhanced items count: ${postItems.length} ===');
          allItemsToPost.addAll(postItems);
        }

        if (remarksController.text.trim().isNotEmpty) {
          String? remarksAssetAuditSiteRespId =
              _getRemarksAssetAuditSiteRespId();
          if (remarksAssetAuditSiteRespId != null &&
              remarksAssetAuditSiteRespId.isNotEmpty) {
            try {
              Map<String, dynamic> remarksData = {
                'itemType': 'ACDB',
                'remarks': remarksController.text.trim(),
                'recordType': 'Remarks',
                'timestamp': DateTime.now(),
                'assetAuditSiteRespId': int.parse(remarksAssetAuditSiteRespId),
                'status': 'OK',
                'serialNumber': 'REMARKS',
                'photo': null,
                'photoTakenTs': _formatDateForApi(DateTime.now()),
                'isQRCodeScanned': false,
                'localQrCodeScannedTs': _formatDateForApi(DateTime.now()),
                'localCreatedDt': _formatDateForApi(DateTime.now()),
                'localModifiedDt': _formatDateForApi(DateTime.now()),
              };
              allItemsToPost.add(remarksData);
              print(
                'ACDB Screen: Added user remarks to post with ID: $remarksAssetAuditSiteRespId, text: "${remarksController.text.trim()}"',
              );
            } catch (e) {
              print('ACDB Screen: Error parsing remarks ID: $e');
            }
          } else {
            print('ACDB Screen: Could not find remarks ID from backend data');
          }
        }

        if (allItemsToPost.isEmpty) {
          print('ACDB Screen: No items to post');
          return;
        }

        print('=== ACDB POST: About to call AssetAuditPostHelper ===');
        print('auditSchId: "${widget.auditSchId}"');
        print('auditSchId type: ${widget.auditSchId.runtimeType}');
        print('allItemsToPost count: ${allItemsToPost.length}');
        print(
          'First item in allItemsToPost: ${allItemsToPost.isNotEmpty ? allItemsToPost.first : "No items"}',
        );

        List<AssetAuditPostRequest> requests = [];
        try {
          requests = await AssetAuditPostHelper.convertSavedItemsToPostRequest(
            savedItems: allItemsToPost,
            assetAuditData: assetAuditState.assetAuditData,
            itemType: 'ACDB',
            itemTypeId: 7,
            screenName: 'solar_acdb',
            context: context,
            auditSchId: widget.auditSchId,
          );
          print(
            '=== ACDB POST: Helper call successful, got ${requests.length} requests ===',
          );
        } catch (e, stackTrace) {
          print('=== ACDB POST: Helper call failed ===');
          print('Error: $e');
          print('Stack trace: $stackTrace');
          print('=== End ACDB POST Error ===');
          rethrow;
        }

        if (requests.isNotEmpty) {
          print(
            '=== ACDB POST: Posting ${requests.length} requests to API ===',
          );

          // Store the current remarks text before posting
          final currentRemarksText = remarksController.text;
          print(
            'ACDB Screen: Storing current remarks text: "$currentRemarksText"',
          );

          await context.read<AssetAuditCubit>().postAssetAuditData(
            requests: requests,
          );
          print('=== ACDB POST: API call completed ===');

          // Refresh the data immediately after posting
          print('Refreshing ACDB data after posting...');
          context.read<AssetAuditCubit>().getAssetAuditData(
            siteType: widget.siteType,
            auditSchId: widget.auditSchId,
            siteAuditSchId: widget.siteAuditSchId,
          );

          // Restore the remarks text after refresh to ensure it's not overwritten
          if (currentRemarksText.isNotEmpty) {
            print(
              'ACDB Screen: Restoring remarks text after refresh: "$currentRemarksText"',
            );
            remarksController.text = currentRemarksText;
          }
        } else {
          print('=== ACDB POST: No requests to post ===');
        }
      } else {
        print('ACDB Screen: AssetAuditCubit state is not ready for posting');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error posting ACDB data: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  String? _getRemarksAssetAuditSiteRespId() {
    final smpsData = widget.assetAuditData?.responseData.categories['SMPS'];
    if (smpsData != null && smpsData.remarks.isNotEmpty) {
      // Filter only ACDB remarks from SMPS category
      final acdbRemarks = smpsData.remarks
          .where((remark) => remark.itemType == 'ACDB')
          .toList();
      if (acdbRemarks.isNotEmpty) {
        return acdbRemarks.first.assetAuditSiteRespId.toString();
      }
    }
    print('No valid ACDB remarks ID found in SMPS backend data');
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<AssetAuditCubit, AssetAuditState>(
          listener: (context, state) {
            if (state is AssetAuditError) {
              showCustomToast(context, state.message);
            } else if (state is AssetAuditLoaded) {
              _loadExistingData();
            } else if (state is AssetAuditPostError) {
              showCustomToast(context, 'Error saving data: ${state.message}');
            }
          },
        ),
        BlocListener<AssetAuditPhotoUploadCubit, AssetAuditPhotoUploadState>(
          listener: (context, state) {
            if (state is AssetAuditPhotoUploadSuccess) {
              setState(() {
                uploadedImgId = state.response.imgId;
                _hasFormDataChanges = true;
              });
            } else if (state is AssetAuditPhotoUploadFailure) {
              showCustomToast(context, state.errorMessage);
            }
          },
        ),
        BlocListener<AssetAuditGetImageCubit, AssetAuditGetImageState>(
          listener: (context, state) async {
            if (state is AssetAuditGetImageSuccess) {
              print(
                'Image loaded for ACDB photoId: $_lastRequestedPhotoId, data length: ${state.imageData.length}',
              );

              // Handle edit case
              if (_isRequestingImage && _currentRequestedImageId != null) {
                final finalImageData = state.imageData.startsWith('data:image/')
                    ? state.imageData
                    : 'data:image/jpeg;base64,${state.imageData}';
                setState(() {
                  acdbPhoto = finalImageData;
                  _isRequestingImage = false;
                  _currentRequestedImageId = null;
                });
                return;
              }

              if (state.imageData.isNotEmpty) {
                setState(() {
                  fetchedImageData = state.imageData;
                  _hasFormDataChanges = true;
                });

                _fetchingImage = false;
                _fetchNextImage();
              } else {
                await _handleImageLoadRetry(
                  _lastRequestedPhotoId ?? '',
                  'acdb',
                );
              }
            } else if (state is AssetAuditGetImageFailure) {
              print(
                'Failed to load ACDB image for photoId: $_lastRequestedPhotoId, error: ${state.errorMessage}',
              );

              // Handle edit case failure
              if (_isRequestingImage && _currentRequestedImageId != null) {
                setState(() {
                  _isRequestingImage = false;
                  _currentRequestedImageId = null;
                });
                return;
              }

              await _handleImageLoadRetry(_lastRequestedPhotoId ?? '', 'acdb');
            }
          },
        ),
      ],
      child: BlocBuilder<AssetAuditCubit, AssetAuditState>(
        builder: (context, state) {
          return PopScope(
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
                                    CustomFormField(
                                      label: "ACDB Type",
                                      hintText: "Text",
                                      isRequired: false,
                                      isEditable: false,
                                      initialValue:
                                          acdbCategoryData?.assets.isNotEmpty ==
                                              true
                                          ? acdbCategoryData
                                                ?.assets
                                                .first
                                                .itemType
                                          : 'N/A',
                                    ),
                                    getHeight(15),
                                    CustomFormField(
                                      label: "ACDB Make",
                                      hintText: "Text",
                                      isRequired: true,
                                      isEditable: false,
                                      initialValue:
                                          acdbCategoryData?.assets.isNotEmpty ==
                                              true
                                          ? acdbCategoryData
                                                ?.assets
                                                .first
                                                .oemName
                                          : 'N/A',
                                    ),
                                    getHeight(15),

                                    CustomFormField(
                                      label: "Count of ACDB",
                                      initialValue: totalAcdbItems.toString(),
                                      isRequired: false,
                                      isEditable: false,
                                    ),
                                    getHeight(15),
                                    Text(
                                      "ACDB Details",
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.white,
                                        fontFamily: fontFamilyMontserrat,
                                      ),
                                    ),
                                    getHeight(3),
                                    CustomInfoCard(
                                      key: ValueKey('acdb_$acdbCardKey'),
                                      serialLabel:
                                          acdbCategoryData?.assets.isNotEmpty ==
                                              true
                                          ? "ACDB (${acdbCategoryData?.assets.first.oemName ?? 'N/A'}) - Serial Number"
                                          : "ACDB - Serial Number",
                                      serialHintText: "ACDB Serial Number *",
                                      photoLabel: "Add a Photo",
                                      statusLabel: "Status",
                                      serialController: acdbSerialController,
                                      onSave: _saveAcdbForm,
                                      isStatusEditable: true,
                                      backendStatus: false,
                                      isRemarksEditable: true,
                                      showSaveButton: true,
                                      remarksLabel: "Rating",
                                      remarksController: ratingController,
                                      remarksHintText: "Rating",
                                      onRemarksChanged: (rating) {
                                        setState(() {
                                          hasUnsavedChanges = true;
                                        });
                                      },
                                      onPhotoTap: (photoPath) {
                                        setState(() {
                                          acdbPhoto = photoPath;
                                          hasUnsavedChanges = true;
                                        });
                                      },
                                      onStatusChanged: (val) {
                                        setState(() {
                                          acdbStatus = val ? "OK" : "Not OK";
                                          hasUnsavedChanges = true;
                                        });
                                      },
                                      onSerialChanged: (serialNumber) {
                                        setState(() {
                                          acdbSerialNumber = serialNumber;
                                          isQRCodeScanned =
                                              false; // Manual entry
                                          hasUnsavedChanges = true;
                                        });
                                      },
                                      initialStatus: acdbStatus == "OK"
                                          ? true
                                          : (acdbStatus == "Not OK"
                                                ? false
                                                : null),
                                      initialPhotoPath:
                                          displayedImageBase64 != null
                                          ? displayedImageBase64
                                          : acdbPhoto,
                                      isEditable: true,
                                    ),
                                    getHeight(8),
                                    _buildAcdbSavedItemsList(),
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
                                    text:
                                        AssetAuditNavigationHelper.getSolarPreviousScreenName(
                                          'ACDB',
                                        ),
                                    isLeftArrow: true,
                                    backgroundColor:
                                        AppColors.buttonColorBackBg,
                                    textColor: AppColors.buttonColorTextBg,
                                    onPressed: () {
                                      final previousScreen =
                                          AssetAuditNavigationHelper.getPreviousAvailableScreen(
                                            widget.assetAuditData,
                                            'ACDB',
                                          );
                                      if (previousScreen != null) {
                                        _navigateToNextScreen(
                                          context,
                                          previousScreen,
                                        );
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
                                      final nextScreen =
                                          _getNextAvailableScreen();
                                      if (nextScreen == null) {
                                        return ArrowButton(
                                          text: "Submit",
                                          isLeftArrow: false,
                                          backgroundColor:
                                              AppColors.buttonColorBg,
                                          textColor: AppColors.buttonColorSite,
                                          onPressed: () async {
                                            print(
                                              '=== ACDB Submit Button Pressed ===',
                                            );
                                            print(
                                              'Serial text: "${acdbSerialController.text}"',
                                            );
                                            print('Photo: $acdbPhoto');
                                            print(
                                              'Rating text: "${ratingController.text}"',
                                            );
                                            print(
                                              'Saved items count: ${savedAcdbItems.length}',
                                            );
                                            print(
                                              'Validation result: ${_validateForm()}',
                                            );

                                            // Allow submit if there are saved items OR if current form is valid
                                            if (savedAcdbItems.isNotEmpty ||
                                                _validateForm()) {
                                              await _postAcdbData();
                                              Navigator.pop(context);
                                            } else {
                                              print(
                                                '=== ACDB Submit Validation Failed ===',
                                              );
                                              _setValidationErrors();
                                              // Show error message to user
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    'Please fill in all required fields (Serial Number, Photo, and Rating)',
                                                  ),
                                                  backgroundColor: Colors.red,
                                                ),
                                              );
                                            }
                                          },
                                        );
                                      } else {
                                        return ArrowButton(
                                          text: nextScreen,
                                          isLeftArrow: false,
                                          backgroundColor:
                                              AppColors.buttonColorBg,
                                          textColor: AppColors.buttonColorSite,
                                          onPressed: () async {
                                            print(
                                              '=== ACDB Button Pressed ===',
                                            );
                                            print(
                                              'Serial text: "${acdbSerialController.text}"',
                                            );
                                            print('Photo: $acdbPhoto');
                                            print(
                                              'Rating text: "${ratingController.text}"',
                                            );
                                            print(
                                              'Saved items count: ${savedAcdbItems.length}',
                                            );
                                            print(
                                              'Validation result: ${_validateForm()}',
                                            );

                                            // Allow navigation if there are saved items OR if current form is valid
                                            if (savedAcdbItems.isNotEmpty ||
                                                _validateForm()) {
                                              print(
                                                '=== ACDB Navigation to $nextScreen ===',
                                              );
                                              print(
                                                'Passing asset audit data: ${widget.assetAuditData != null}',
                                              );
                                              await _postAcdbData();
                                              _navigateToNextScreen(
                                                context,
                                                nextScreen,
                                              );
                                            } else {
                                              print(
                                                '=== ACDB Validation Failed ===',
                                              );
                                              _setValidationErrors();
                                              // Show error message to user
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    'Please fill in all required fields (Serial Number, Photo, and Rating)',
                                                  ),
                                                  backgroundColor: Colors.red,
                                                ),
                                              );
                                            }
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
          );
        },
      ),
    );
  }

  Widget _buildAcdbSavedItemsList() {
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
                        "Rating",
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

              if (savedAcdbItems.isNotEmpty) ...[
                ...savedAcdbItems.map((item) {
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
                          child: Text(
                            item["rating"] ?? "",
                            style: const TextStyle(
                              color: AppColors.color555555,
                              fontSize: 14,
                              fontFamily: fontFamilyMontserrat,
                              fontWeight: FontWeight.w400,
                            ),
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
