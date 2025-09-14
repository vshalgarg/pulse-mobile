import 'package:app/commonWidgets/custom_buttons/arrow_botton.dart';
import 'package:app/constants/constants_methods.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

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

class TransformerScreen extends StatefulWidget {
  final String siteType;
  final String auditSchId;
  final String siteAuditSchId;
  final AssetAuditModel? assetAuditData; // Complete asset audit data

  const TransformerScreen({
    super.key,
    required this.siteType,
    required this.auditSchId,
    required this.siteAuditSchId,
    this.assetAuditData, // Complete asset audit data
  });

  @override
  State<TransformerScreen> createState() => _TransformerScreenState();
}

class _TransformerScreenState extends State<TransformerScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController serialController = TextEditingController();
  bool hasUnsavedChanges = false;
  bool showValidationErrors = false;
  int totalItemsToScan = 6;
  int currentScannedItems = 0;
  List<Map<String, dynamic>> savedItems = [];

  // Transformer field values
  String? transformerSerialNumber;
  String? transformerPhoto;
  String? transformerStatus;
  final remarksController = TextEditingController();
  int transCardKey = 0;
  List<Map<String, dynamic>> _savedTransItems = [];
  
  // Getter and setter for savedTransItems with debug logging
  List<Map<String, dynamic>> get savedTransItems => _savedTransItems;
  set savedTransItems(List<Map<String, dynamic>> value) {
    _savedTransItems = value;
  }
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
  final TextEditingController transSerialController = TextEditingController();

  // Get Transformer data from API
  int totalTransItems = 0; // Total Transformer items from API

  // Get Transformer category data
  CategoryData? get TransformerCategoryData {
    return widget.assetAuditData?.responseData.categories['Transformer'];
  }

  @override
  void initState() {
    super.initState();
    serialController.addListener(_onFormChanged);
    remarksController.addListener(_onFormChanged);
    _setupGetImageListener();
    // Clear serial number field to prevent showing data when clicked
    transSerialController.clear();

    _loadExistingData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    print('🔄 Transformer: didChangeDependencies called');
    print('🔄 Transformer: Current savedTransItems length: ${savedTransItems.length}');

    // Sync initial data from widget.assetAuditData
    if (widget.assetAuditData != null) {
      final transformerData = widget.assetAuditData!.responseData.categories['Transformer'];
      if (transformerData != null) {
        setState(() {
          totalTransItems = transformerData.assets.length;
          
          // Only load API data if savedTransItems is empty (preserve user-saved items)
          if (savedTransItems.isEmpty) {
            print('🔄 Transformer: Loading API data (savedTransItems is empty)');
            // Only show items that have been interacted with by the user (have photo_id and qr_code_scanned is not null)
            savedTransItems = transformerData.assets
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
            print('🔄 Transformer: Loaded ${savedTransItems.length} items from API');
          } else {
            print('🔄 Transformer: Preserving user-saved items (${savedTransItems.length} items)');
          }
          // Only load remarks from API if user hasn't made changes
          if (remarksController.text.isEmpty) {
            remarksController.text = transformerData.remarks.isNotEmpty
                ? transformerData.remarks.first.itemTypeRemark ?? ''
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
    transSerialController.dispose();
    _getImageSubscription?.cancel();
    _assetAuditSubscription?.cancel();
    super.dispose();
  }

  void _loadExistingData() async {
    // Load existing Transformer data from API
    print('Transformer screen: Loading existing data from API');

    final assetAuditState = context.read<AssetAuditCubit>().state;
    if (assetAuditState is AssetAuditLoaded && assetAuditState.assetAuditData.responseData.categories.isNotEmpty) {
      final transformerData = assetAuditState.assetAuditData.responseData.categories['Transformer'];

      if (transformerData != null && transformerData.assets.isNotEmpty) {
        print('Transformer screen: Found ${transformerData.assets.length} Transformer assets');

        // Load photos for Transformer assets that have them
        for (var asset in transformerData.assets) {
          if (asset.photoId != null && asset.photoId! > 0) {
            print('Transformer screen: Loading image for asset ${asset.assetAuditSiteRespId} with photoId ${asset.photoId}');
            _imageQueue.add({'photoId': asset.photoId.toString(), 'key': 'transformer_${asset.assetAuditSiteRespId}'});
          }
        }

        if (_imageQueue.isNotEmpty) {
          _fetchNextImage();
        } else {
          print('Transformer screen: No Transformer assets with photos found');
        }
      } else {
        print('Transformer screen: No Transformer data found');
      }
    }
  }

  void _onFormChanged() {
    print('🔄 Transformer: _onFormChanged called');
    print('🔄 Transformer: serialController.text: "${serialController.text}"');
    print('🔄 Transformer: remarksController.text: "${remarksController.text}"');
    
    final newHasUnsavedChanges = serialController.text.isNotEmpty || remarksController.text.isNotEmpty;
    
    // Only call setState if hasUnsavedChanges actually changed
    if (hasUnsavedChanges != newHasUnsavedChanges) {
      print('🔄 Transformer: hasUnsavedChanges changed from $hasUnsavedChanges to $newHasUnsavedChanges');
      setState(() {
        hasUnsavedChanges = newHasUnsavedChanges;

        if (showValidationErrors && serialController.text.isNotEmpty) {
          showValidationErrors = false;
        }
      });
    } else {
      print('🔄 Transformer: hasUnsavedChanges unchanged ($hasUnsavedChanges), skipping setState');
    }
  }

  Future<void> _saveAndExit() async {
    try {
      showDialog(context: context, barrierDismissible: false, builder: (context) => const Center(child: CircularProgressIndicator()));
      await _postTransformerData();
      await _updateAuditScheduleStatus("In Progress");
      Navigator.of(context).pop();
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => HomeScreen()));
    } catch (e) {
      if (Navigator.canPop(context)) Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving data: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _updateAuditScheduleStatus(String status) async {
    try {
      await context.read<AuditScheduleStatusCubit>().updateStatus(status: status, siteAuditSchId: widget.siteAuditSchId);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update status: $e')));
    }
  }

  bool _isFormValid() {

    if (transSerialController.text.isEmpty) {
      print('=== Transformer VALIDATION: Serial number is empty ===');
      return false;
    }

    if (transformerPhoto == null || transformerPhoto!.isEmpty) {
      print('=== Transformer VALIDATION: Photo is null or empty ===');
      return false;
    }

    print('=== Transformer VALIDATION: Form is valid ===');
    return true;
  }

  bool _validateForm() {
    if (transSerialController.text.isEmpty) {
      return false;
    }

    if (transformerPhoto == null || transformerPhoto!.isEmpty) {
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
    return AssetAuditNavigationHelper.getNextAvailableScreen(widget.assetAuditData, 'Transformer');
  }

  // Helper method to get the previous available screen based on data availability
  String? _getPreviousAvailableScreen() {
    return AssetAuditNavigationHelper.getPreviousAvailableScreen(widget.assetAuditData, 'Transformer');
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

  Future<String?> _uploadTransformerPhoto(File file) async {
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
            subscription.cancel();
            completer.complete(state.response.imgId);
          } else if (state is AssetAuditPhotoUploadFailure) {
            subscription.cancel();
            completer.completeError(state.errorMessage);
          }
        });

        context.read<AssetAuditPhotoUploadCubit>().uploadPhoto(
          file: file,
          imgId: imgIdToUse,
          schId: schId,
        );

        final result = await completer.future.timeout(
          const Duration(seconds: 30),
          onTimeout: () {
            print('⏰ Transformer Photo upload TIMEOUT after 30 seconds');
            subscription.cancel();
            throw TimeoutException('Photo upload timeout', const Duration(seconds: 30));
          },
        );

        print('✅ Transformer Photo upload completed with result: $result');
        return result;
      } else {
        print('❌ Transformer Photo upload failed: AssetAuditCubit state is not AssetAuditLoaded or pageHeader is empty');
        throw Exception('AssetAuditCubit state is not ready');
      }
    } catch (e) {
      print('❌ Transformer Photo upload error: $e');
      rethrow;
    }
  }

  void _fetchNextImage() {
    if (_fetchingImage || _imageQueue.isEmpty) return;

    _fetchingImage = true;

    final image = _imageQueue.removeAt(0);
    final photoId = image['photoId']!;
    final key = image['key']!;

    print('Loading Transformer image for photoId: $photoId, key: $key, retry count: ${_retryCounts[photoId] ?? 0}');
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
      print('Retrying Transformer image load for photoId: $photoId, key: $key, attempt: ${_retryCounts[photoId]} of $maxRetries');
      await Future.delayed(retryDelay);
      _imageQueue.insert(0, {'photoId': photoId, 'key': key});
      _fetchNextImage();
    } else {
      print('Max retries reached for Transformer photoId: $photoId, key: $key');
      _retryCounts.remove(photoId);
    }
  }

  String? _getRemarksAssetAuditSiteRespId() {
    final transformerData = widget.assetAuditData?.responseData.categories['Transformer'];
    if (transformerData != null && transformerData.remarks.isNotEmpty) {
      return transformerData.remarks.first.assetAuditSiteRespId.toString();
    }
    print('No valid remarks ID found in backend data');
    return null;
  }

  void _setupGetImageListener() {
    _getImageSubscription = context.read<AssetAuditGetImageCubit>().stream.listen((state) async {
      if (state is AssetAuditGetImageSuccess) {
        print('Image loaded for Transformer photoId: $_lastRequestedPhotoId, data length: ${state.imageData.length}');

        if (state.imageData.isNotEmpty) {
          setState(() {
            fetchedImageData = state.imageData;
            _hasFormDataChanges = true;
          });

          _fetchingImage = false;
          _fetchNextImage();
        } else {
          print('Empty image data received for Transformer photoId: $_lastRequestedPhotoId');
          await _handleImageLoadRetry(_lastRequestedPhotoId ?? '', 'transformer');
        }
      } else if (state is AssetAuditGetImageFailure) {
        print('Failed to load Transformer image for photoId: $_lastRequestedPhotoId, error: ${state.errorMessage}');
        await _handleImageLoadRetry(_lastRequestedPhotoId ?? '', 'transformer');
      } else if (state is AssetAuditGetImageLoading) {
        setState(() {
          isLoadingImage = true;
        });
        print('=== Transformer Get Image Loading ===');
      }
    });
  }




  void _saveTransformerForm() async {
    print('=== Transformer SAVE: Starting save form ===');
    print('Current savedTransformerItems count: ${savedTransItems.length}');
    print('Total Transformer items: $totalTransItems');
    print('Serial number: $transformerSerialNumber');
    print('Photo: $transformerPhoto');
    print('Status: $transformerStatus');

    if (savedTransItems.length >= totalTransItems) {
      print('=== Transformer SAVE: Maximum items reached ===');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Maximum number of SPV items ($totalTransItems) already added.',
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
      print('=== Transformer SAVE: Form is valid, proceeding ===');
      String? photoImageId = transformerPhoto;

      // If photo is a file path, upload it and get image ID
      if (transformerPhoto != null && transformerPhoto!.isNotEmpty && !transformerPhoto!.startsWith('http')) {
        try {
          final file = File(transformerPhoto!);
          if (await file.exists()) {
            print(' Uploading Transformer photo: ${transformerPhoto}');
            photoImageId = await _uploadTransformerPhoto(file);
            print('✅ Transformer photo uploaded successfully, image ID: $photoImageId');
          } else {
            print('❌ Transformer photo file does not exist: ${transformerPhoto}');
          }
        } catch (e) {
          print('❌ Error uploading Transformer photo: $e');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error uploading photo: $e'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
      } else {
        print('ℹ️ No Transformer photo to upload or already has image ID');
      }

      setState(() {
        Map<String, dynamic> currentFormData = {
          'serialNumber': transformerSerialNumber,
          'photo': photoImageId, // Use image ID instead of file path
          'status': transformerStatus ?? "OK",
          'timestamp': DateTime.now(),
          'isQRCodeScanned': false, // Add this field
          'photoTakenTs': DateTime.now().toString(), // Add this field
          'localQrCodeScannedTs': DateTime.now().toString(), // Add this field
          'localCreatedDt': DateTime.now().toString(), // Add this field
          'localModifiedDt': DateTime.now().toString(), // Add this field
        };

        savedTransItems.add(currentFormData);
        currentScannedItems++;

        print('=== Transformer SAVE: Item added to savedTransformerItems ===');
        print('New savedTransformerItems count: ${savedTransItems.length}');
        print('Added item: $currentFormData');
        print('✅ Transformer item saved successfully! Total items: ${savedTransItems.length}');
        print('✅ After save - savedTransItems length: ${savedTransItems.length}');
        print('✅ After save - savedTransItems content: $savedTransItems');

        transformerSerialNumber = null;
        transformerPhoto = null;
        transformerStatus = null;

        transSerialController.clear();

        transCardKey++;

        hasUnsavedChanges = false;
        showValidationErrors = false;
      });

      int remainingSpv = totalTransItems - savedTransItems.length;
    } else {
      print('=== Transformer SAVE: Form validation failed ===');
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
      transformerSerialNumber = item["serialNumber"];
      transformerPhoto = item["photo"];
      transformerStatus = item["status"];
      isQRCodeScanned = item["isQRCodeScanned"] ?? false; // Restore QR scan status

      transSerialController.text = item["serialNumber"] ?? "";
      displayedImageBase64 = null; // Clear Base64 to avoid showing old image
      isLoadingImage = false; // Reset loading state

      savedTransItems.remove(item);

      hasUnsavedChanges = true;

      // Force rebuild of the CustomInfoCard to show restored values
      transCardKey++;
    });

    // Load image asynchronously to avoid blocking UI
    if (transformerPhoto != null && transformerPhoto!.isNotEmpty && _isNumeric(transformerPhoto!)) {
      print('=== Transformer Edit: Fetching image for photo ID: $transformerPhoto ===');
      setState(() {
        isLoadingImage = true;
      });

      // Use Future.microtask to load image in next frame
      Future.microtask(() {
        context.read<AssetAuditGetImageCubit>().getImage(
          imgId: transformerPhoto!,
          schId: widget.siteAuditSchId,
        );
      });
    }


    // If the photo is a photo ID (numeric), fetch the image from API
    if (transformerPhoto != null && transformerPhoto!.isNotEmpty && _isNumeric(transformerPhoto!)) {
      print('=== Transformer Edit: Fetching image for photo ID: $transformerPhoto ===');
      context.read<AssetAuditGetImageCubit>().getImage(
        imgId: transformerPhoto!,
        schId: widget.siteAuditSchId,
      );
    }
  }


  /// Check if string is numeric
  bool _isNumeric(String str) {
    return double.tryParse(str) != null;
  }



  /// Post Transformer data to API
  Future<void> _postTransformerData() async {
    print('=== Transformer Post Data Started ===');

    if (savedTransItems.isEmpty && remarksController.text.trim().isEmpty) {
      print('Transformer Screen: No data to post');
      return;
    }

    try {
      // Collect all items and remarks
      List<Map<String, dynamic>> allItemsToPost = [];

      // Add saved Transformer items with proper structure
      for (var item in savedTransItems) {
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
        print('Transformer Screen: Added user remarks to post, text: "${remarksController.text.trim()}"');
      }

      if (allItemsToPost.isEmpty) {
        print('Transformer Screen: No items to post');
        return;
      }

      // Convert to POST request format
      final requests = await AssetAuditPostHelper.convertSavedItemsToPostRequest(
        savedItems: allItemsToPost,
        assetAuditData: widget.assetAuditData!,
          itemType: 'Transformer',
        itemTypeId: 9, // Transformer item type ID
        screenName: 'solar_dcba',
        context: context,
        auditSchId: widget.auditSchId,
      );

      // Post data
      if (requests.isNotEmpty) {
        print('Transformer Screen: Posting ${requests.length} requests');
        
        // Store the current remarks text before posting
        final currentRemarksText = remarksController.text;
        print('Transformer Screen: Storing current remarks text: "$currentRemarksText"');
        
        context.read<AssetAuditCubit>().postAssetAuditData(requests: requests);
        
        // Refresh the data immediately after posting
        print('Refreshing Transformer data after posting...');
        context.read<AssetAuditCubit>().getAssetAuditData(
          siteType: widget.siteType,
          auditSchId: widget.auditSchId,
          siteAuditSchId: widget.siteAuditSchId,
        );
        
        // Restore the remarks text after refresh to ensure it's not overwritten
        if (currentRemarksText.isNotEmpty) {
          print('Transformer Screen: Restoring remarks text after refresh: "$currentRemarksText"');
          remarksController.text = currentRemarksText;
        }
      }

      print('Transformer Screen: All data posted successfully');
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
  //   final transformerData = widget.assetAuditData?.responseData.categories['DCDB'];
  //   if (transformerData != null && transformerData.remarks.isNotEmpty) {
  //     return transformerData.remarks.first.assetAuditSiteRespId.toString();
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
                transCardKey++;
              });
            } else if (state is AssetAuditGetImageFailure) {
              setState(() {
                displayedImageBase64 = null;
                isLoadingImage = false;
                transCardKey++;
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
              print('🔄 Transformer: BlocListener AssetAuditLoaded received');
              print('🔄 Transformer: Current savedTransItems length: ${savedTransItems.length}');
              
              final transformerData = state.assetAuditData.responseData.categories['Transformer'];
              if (transformerData != null) {
                setState(() {
                  totalTransItems = transformerData.assets.length;
                  
                  // Only load API data if savedTransItems is empty (preserve user-saved items)
                  if (savedTransItems.isEmpty) {
                    print('🔄 Transformer: BlocListener loading API data (savedTransItems is empty)');
                    // Only show items that have been interacted with by the user (have photo_id and qr_code_scanned is not null)
                    savedTransItems = transformerData.assets
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
                    print('🔄 Transformer: BlocListener loaded ${savedTransItems.length} items from API');
                  } else {
                    print('🔄 Transformer: BlocListener preserving user-saved items (${savedTransItems.length} items)');
                  }
                  
                  // Only load remarks from API if user hasn't made changes
                  if (remarksController.text.isEmpty) {
                    remarksController.text = transformerData.remarks.isNotEmpty
                        ? transformerData.remarks.first.itemTypeRemark ?? ''
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
                  builder: (context) =>
                      UnsavedChangesDialog(
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
                                  initialValue: TransformerCategoryData?.assets.first.oemName,
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
                                  key: ValueKey('tarns $transCardKey'),
                                  serialLabel: TransformerCategoryData?.assets.isNotEmpty == true
                                      ? "Transformer (${TransformerCategoryData?.assets.first.oemName ?? 'N/A'}) - Serial Number"
                                      : "Transformer - Serial Number",
                                  serialHintText: "Transformer Serial Number *",
                                  photoLabel: "Add a Photo",
                                  statusLabel: "Status",
                                  serialController: transSerialController,
                                  onSave: _saveTransformerForm,
                                  isStatusEditable: true,
                                  backendStatus: false,
                                  showSaveButton: true,
                                  remarksLabel: 'Transformer (Capacity)',
                                  remarksHintText: TransformerCategoryData?.assets.isNotEmpty == true
                                      ? TransformerCategoryData?.assets.first.capacity ?? 'N/A'
                                      : 'N/A',
                                  remarksController: null,
                                  isRemarksEditable: false,
                                  onPhotoTap: (photoPath) {
                                    setState(() {
                                      transformerPhoto = photoPath;
                                      displayedImageBase64 = null;
                                      hasUnsavedChanges = true;
                                    });
                                  },
                                  onStatusChanged: (val) {
                                    setState(() {
                                      transformerStatus = val ? "OK" : "Not OK";
                                      hasUnsavedChanges = true;
                                    });
                                  },
                                  onSerialChanged: (serialNumber) {
                                    setState(() {
                                      transformerSerialNumber = serialNumber;
                                      isQRCodeScanned = false; // Manual entry
                                      hasUnsavedChanges = true;
                                    });
                                  },
                                  initialStatus: transformerStatus == "OK"
                                      ? true
                                      : (transformerStatus == "Not OK" ? false : null),
                                  initialPhotoPath: transformerPhoto,
                                  isEditable: true,
                                ),
                                getHeight(8),
                                _buildTransformerSavedItemsList(),
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
                                text: AssetAuditNavigationHelper.getSolarPreviousScreenName('Transformer'),
                                isLeftArrow: true,
                                backgroundColor: AppColors.buttonColorBackBg,
                                textColor: AppColors.buttonColorTextBg,
                                onPressed: () {
                                  final previousScreen = AssetAuditNavigationHelper.getPreviousAvailableScreen(widget.assetAuditData, 'Transformer');
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
                                        await _postTransformerData();
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
                                            '=== Transformer Navigation to $nextScreen ===');
                                        print(
                                            'Passing asset audit data: ${widget
                                                .assetAuditData != null}');

                                        // POST data to API  navigation
                                        await _postTransformerData();

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


  Widget _buildTransformerSavedItemsList() {
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

              if (savedTransItems.isNotEmpty) ...[
                ...savedTransItems.map((item) {
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
