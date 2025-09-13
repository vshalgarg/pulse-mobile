import 'dart:convert';

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
import '../../../commonWidgets/asset_type_card.dart';
import '../../../commonWidgets/custom_dialogs/unsaved_changes_dialog.dart';
import '../../../commonWidgets/custom_form_appbar.dart';
import '../../../commonWidgets/custom_form_field.dart';
import '../../../commonWidgets/custom_remark.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_images.dart';
import '../../../constants/constants_strings.dart';
import '../../../hive_local_database/hive_db.dart';
import '../../../utils/asset_audit_post_helper.dart';
import '../../../models/asset_audit_model.dart';
import '../../home_screen.dart';

class SPVScreen extends StatefulWidget {
  final String siteType;
  final String auditSchId;
  final String siteAuditSchId;
  final AssetAuditModel? assetAuditData; // Complete asset audit data

  const SPVScreen({
    super.key,
    required this.siteType,
    required this.auditSchId,
    required this.siteAuditSchId,
    this.assetAuditData, // Complete asset audit data
  });

  @override
  State<SPVScreen> createState() => _SPVScreenState();
}


class _SPVScreenState extends State<SPVScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController serialController = TextEditingController();
  bool hasUnsavedChanges = false;
  bool showValidationErrors = false;
  bool _isFormInitialized = false;
  bool _shouldUpdateFromAPI = true; // Flag to control when to update from API
  int totalItemsToScan = 6;
  List<Map<String, dynamic>> savedItems = [];

  // SPV field values
  String? spvSerialNumber;
  String? spvPhoto;
  String? spvStatus;
  final remarksController = TextEditingController(); // User remarks
  int spvCardKey = 0;
  List<Map<String, dynamic>> savedSpvItems = [];

  // Controllers for CustomInfoCard
  final TextEditingController spvSerialController = TextEditingController();
  int totalSpvItems = 0; // Will be set from API data
  bool isQRCodeScanned = false; // Track if serial was scanned or manually entered

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

  @override
  void initState() {
    super.initState();
    serialController.addListener(_onFormChanged);
    spvSerialController.addListener(_onFormChanged);
    remarksController.addListener(_onFormChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    print('=== SPV didChangeDependencies called ===');

    context.read<AssetAuditCubit>().getAssetAuditData(
      siteType: widget.siteType,
      auditSchId: widget.auditSchId,
      siteAuditSchId: widget.siteAuditSchId,
    );

    // Initialize total items and saved items from API data
    if (widget.assetAuditData != null) {
      final spvData = widget.assetAuditData!.responseData.categories['SPV'];
      if (spvData != null) {
        totalSpvItems = spvData.assets.length;
        print('SPV total items from API: $totalSpvItems');
        print('SPV data received: ${spvData.assets.length} assets');
        if (spvData.assets.isNotEmpty) {

          // Load items that have been successfully posted to API AND have user interaction
          // (either photo taken or serial number entered - regardless of QR scan or manual entry)
          setState(() {
            final postedItems = spvData.assets.where((asset) => 
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
            
            // Only update if this is the initial load or if we should update from API
            if (savedSpvItems.isEmpty || _shouldUpdateFromAPI) {
              // Preserve locally saved items that haven't been posted to API yet
              final localItems = savedSpvItems.where((item) => 
                item['assetAuditSiteRespId'] == null
              ).toList();
              
              // Combine API items with local items
              savedSpvItems = [...postedItems, ...localItems];
            }

            // Initialize remarks from API only if user hasn't made changes
            if (spvData.remarks.isNotEmpty && remarksController.text.isEmpty) {
              remarksController.text = spvData.remarks.first.itemTypeRemark ?? '';
            }
          });
        } else {
          print('No SPV assets found in API data');
        }
      } else {
        print('SPV category not found in asset audit data!');
      }
    } else {
      print('Asset audit data is null!');
    }

    // Check page header for additional data
    _checkPageHeaderForData();
    
    // Mark form as initialized after data loading
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _isFormInitialized = true;
      print('SPV Form initialized - change tracking enabled');
    });
  }

  @override
  void dispose() {
    serialController.removeListener(_onFormChanged);
    spvSerialController.removeListener(_onFormChanged);
    remarksController.removeListener(_onFormChanged);
    serialController.dispose();
    spvSerialController.dispose();
    remarksController.dispose();
    super.dispose();
  }

  void _onFormChanged() {
    setState(() {
      final hasLocalPhoto = uploadedPhotoPath != null && uploadedPhotoPath!.isNotEmpty;
      final hasServerImage = uploadedImgId != null && uploadedImgId!.isNotEmpty && uploadedImgId != "0";
      final hasImageData = fetchedImageData != null && fetchedImageData!.isNotEmpty;

      // Only set hasUnsavedChanges to true if there are actual unsaved changes in the current form
      // and the form has been initialized (to avoid false positives during initialization)
      if (_isFormInitialized) {
        hasUnsavedChanges = serialController.text.isNotEmpty ||
            spvSerialController.text.isNotEmpty ||
            hasLocalPhoto ||
            hasServerImage ||
            hasImageData ||
            remarksController.text.isNotEmpty;
      }

      _hasFormDataChanges = true;
      if (showValidationErrors && (serialController.text.isNotEmpty || spvSerialController.text.isNotEmpty)) {
        showValidationErrors = false;
      }
    });
  }

  void _saveFormDataToHive() {
    // No Hive storage - data is only stored in memory and posted to API
    _hasFormDataChanges = false;
  }

  String _getCancelMessage() {
    return "Do you want to cancel the Asset Audit for Site (ID: SITE-38974)?";
  }

  void _checkPageHeaderForData() {
    final assetAuditState = context.read<AssetAuditCubit>().state;
    if (assetAuditState is AssetAuditLoaded && assetAuditState.assetAuditData.pageHeader.isNotEmpty) {
      final pageHeader = assetAuditState.assetAuditData.pageHeader.first;

      if (pageHeader.makerSelfieImageId != null && pageHeader.makerSelfieImageId! > 0) {
        setState(() {
          uploadedImgId = pageHeader.makerSelfieImageId.toString();
          fetchedImageData = null;
        });
        _onFormChanged();

        _imageQueue.add({'photoId': pageHeader.makerSelfieImageId.toString(), 'key': 'spv'});
        _fetchNextImage();
      }
    }
  }

  void _fetchNextImage() {
    if (_fetchingImage || _imageQueue.isEmpty) return;

    _fetchingImage = true;

    final image = _imageQueue.removeAt(0);
    final photoId = image['photoId']!;
    final key = image['key']!;

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
      await Future.delayed(retryDelay);
      _imageQueue.insert(0, {'photoId': photoId, 'key': key});
      _fetchNextImage();
    } else {
      _retryCounts.remove(photoId);
    }
  }

  Future<String?> _uploadSpvPhoto(File file) async {
    try {

      final assetAuditState = context.read<AssetAuditCubit>().state;
      if (assetAuditState is AssetAuditLoaded && assetAuditState.assetAuditData.pageHeader.isNotEmpty) {
        final schId = assetAuditState.assetAuditData.pageHeader.first.siteAuditSchId.toString();

        final imgIdToUse = "0";

        final completer = Completer<String?>();

        late StreamSubscription subscription;
        subscription = context.read<AssetAuditPhotoUploadCubit>().stream.listen((state) {

          if (state is AssetAuditPhotoUploadSuccess) {
            print('✅ SPV Photo upload SUCCESS!');
            print('Response imgId: ${state.response.imgId}');
            subscription.cancel();
            completer.complete(state.response.imgId);
          } else if (state is AssetAuditPhotoUploadFailure) {
            print('❌ SPV Photo upload FAILED!');
            print('Error message: ${state.errorMessage}');
            subscription.cancel();
            completer.completeError(state.errorMessage);
          } else {
            print('📤 SPV Photo upload in progress...');
          }
        });

        print('Starting SPV photo upload...');
        context.read<AssetAuditPhotoUploadCubit>().uploadPhoto(
          file: file,
          imgId: imgIdToUse,
          schId: schId,
        );

        print('Waiting for SPV photo upload result...');
        final result = await completer.future.timeout(
          const Duration(seconds: 30),
          onTimeout: () {
            print('⏰ SPV Photo upload TIMEOUT after 30 seconds');
            subscription.cancel();
            throw Exception('Photo upload timeout');
          },
        );

        print('=== SPV Photo Upload Completed ===');
        print('Final result: $result');
        return result;
      } else {
        print('❌ Site data not loaded for SPV photo upload');
        throw Exception('Site data not loaded');
      }
    } catch (e) {
      print('❌ Error uploading SPV photo: $e');
      rethrow;
    }
  }

  bool _validateSerialNumber(String serialNumber, bool isQRCodeScanned) {
    if (widget.assetAuditData == null) return false;

    final spvData = widget.assetAuditData!.responseData.categories['SPV'];
    if (spvData == null) return false;

    final allItems = spvData.assets;
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
    }
  }


  void _saveAndExit() async {
      await _postSPVData();
  }

  int? _getRemarksAssetAuditSiteRespId() {
    print('=== SPV Screen: Getting Remarks AssetAuditSiteRespId ===');

    if (widget.assetAuditData == null) {
      print('assetAuditData is null, cannot get remarks ID');
      return null;
    }

    final spvData = widget.assetAuditData!.responseData.categories['SPV'];
    if (spvData == null) {
      print('SPV category data is null');
      return null;
    }

    final remarks = spvData.remarks;
    if (remarks.isNotEmpty) {
      print('Found ${remarks.length} remarks in backend data');

      for (var remark in remarks) {
        if (remark.assetAuditSiteRespId != null &&
            remark.assetAuditSiteRespId > 0 &&
            remark.itemType == 'SPV') {
          print('Using SPV remarks ID: ${remark.assetAuditSiteRespId}');
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


  Future<void> _postSPVData() async {
    try {
      final assetAuditState = context.read<AssetAuditCubit>().state;
      if (assetAuditState is AssetAuditLoaded && assetAuditState.assetAuditData.pageHeader.isNotEmpty) {
        List<Map<String, dynamic>> allItemsToPost = [];

        if (savedSpvItems.isNotEmpty) {
          final enhancedItems = AssetAuditPostHelper.enhanceSavedItems(
            savedItems: savedSpvItems,
            screenName: 'solar_spv',
          );
          allItemsToPost.addAll(enhancedItems);
        }

        if (remarksController.text.isNotEmpty) {
          int? remarksAssetAuditSiteRespId = _getRemarksAssetAuditSiteRespId();

          if (remarksAssetAuditSiteRespId != null) {
            Map<String, dynamic> remarksData = {
              'itemType': 'SPV',
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
            print('SPV Screen: Added user remarks to post with ID: $remarksAssetAuditSiteRespId, text: "${remarksController.text}"');
          } else {
            print('SPV Screen: Could not find remarks ID from backend data');
          }
        } else {
          print('SPV Screen: No remarks to post - remarksController.text is empty');
        }

        if (allItemsToPost.isEmpty) {
          print('SPV Screen: No items to post');
          return;
        }

        final requests = await AssetAuditPostHelper.convertSavedItemsToPostRequest(
          savedItems: allItemsToPost,
          assetAuditData: assetAuditState.assetAuditData,
          itemType: 'SPV',
          itemTypeId: 4,
          screenName: 'solar_spv',
          context: context,
          auditSchId: widget.auditSchId,
        );

        if (requests.isNotEmpty) {

          final currentRemarksText = remarksController.text;
          print('SPV Screen: Storing current remarks text: "$currentRemarksText"');

          context.read<AssetAuditCubit>().postAssetAuditData(requests: requests);

        }
      } else {
        print('No SPV items to post - user can navigate without saving items');
      }
    } catch (e) {
      print('Error posting SPV data: $e');
    }
  }

  bool _isFormValid() {
    if (spvSerialController.text.isEmpty) {
      return false;
    }

    if (spvPhoto == null || spvPhoto!.isEmpty) {
      return false;
    }

    if(spvStatus == null || spvStatus!.isEmpty) {
      return false;
    }

    if (!_validateSerialNumber(spvSerialController.text, isQRCodeScanned)) {
      return false;
    }

    return true;
  }

  void _saveSpvForm() async {
    if (!_isFormInitialized) {
      showCustomToast(context, '❌ Form is still loading, please wait...');
      return;
    }
    
    if (_isFormValid()) {
      String? photoImageId = spvPhoto;

      if (spvPhoto != null && spvPhoto!.isNotEmpty && !spvPhoto!.startsWith('http')) {
        try {
          final file = File(spvPhoto!);
          if (await file.exists()) {
            photoImageId = await _uploadSpvPhoto(file);
          } else {
            return;
          }
        } catch (e) {
          return;
        }
      }

      setState(() {
        final currentFormData = {
          'serialNumber': spvSerialController.text, // Use controller text instead of spvSerialNumber
          'photo': photoImageId,
          'status': spvStatus ?? 'OK',
          'timestamp': DateTime.now(),
          'isQRCodeScanned': isQRCodeScanned,
        };

        final existingItemIndex = savedSpvItems.indexWhere(
              (item) => item['serialNumber'] == spvSerialController.text,
        );

        if (existingItemIndex >= 0) {
          savedSpvItems[existingItemIndex] = currentFormData;
        } else {
          savedSpvItems.add(currentFormData);
        }

        spvSerialNumber = null;
        spvPhoto = null;
        spvStatus = null;
        spvSerialController.clear();
        spvCardKey++;
        hasUnsavedChanges = false;
        showValidationErrors = false;
        _isFormInitialized = false; // Reset initialization flag
        _onFormChanged();
      });

      // Re-initialize form after reset
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _isFormInitialized = true;
      });
    } else {
      // Show validation errors to user
      setState(() {
        showValidationErrors = true;
      });
      
      // Show specific error messages
      if (spvSerialController.text.isEmpty) {
        showCustomToast(context, '❌ Please enter a serial number');
      } else if (spvPhoto == null || spvPhoto!.isEmpty) {
        showCustomToast(context, '❌ Please take a photo');
      } else if (spvStatus == null || spvStatus!.isEmpty) {
        showCustomToast(context, '❌ Please select status');
      } else if (!_validateSerialNumber(spvSerialController.text, isQRCodeScanned)) {
        showCustomToast(context, isQRCodeScanned 
            ? '❌ Invalid QR Code! Serial number not found in system.'
            : '❌ Invalid serial number! Please check and try again.');
      }
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
      spvSerialNumber = item['serialNumber'];
      spvPhoto = item['photo'];
      spvStatus = item['status'];
      isQRCodeScanned = item['isQRCodeScanned'] ?? false;
      spvSerialController.text = item['serialNumber'] ?? '';
      displayedImageBase64 = null; // Clear Base64 to avoid showing old image
      isLoadingImage = false; // Reset loading state
      savedSpvItems.remove(item); // Remove item from saved list when editing
      // Don't set hasUnsavedChanges = true here - let _onFormChanged handle it
      spvCardKey++;
    });
    _onFormChanged();

    // Load image asynchronously to avoid blocking UI
    if (spvPhoto != null && spvPhoto!.isNotEmpty && _isNumeric(spvPhoto!)) {
      print('=== SPV Edit: Fetching image for photo ID: $spvPhoto ===');
      setState(() {
        _currentRequestedImageId = spvPhoto;
        _isRequestingImage = true;
        isLoadingImage = true;
      });
      
      // Use Future.microtask to load image in next frame
      Future.microtask(() {
        context.read<AssetAuditGetImageCubit>().getImage(
          imgId: spvPhoto!,
          schId: widget.siteAuditSchId,
        );
      });
    }



  }

  bool _isNumeric(String str) {
    return int.tryParse(str) != null;
  }

  String? _getNextAvailableScreen() {
    return AssetAuditNavigationHelper.getNextAvailableScreen(widget.assetAuditData, 'SPV');
  }

  String? _getPreviousAvailableScreen() {
    return AssetAuditNavigationHelper.getPreviousAvailableScreen(widget.assetAuditData, 'SPV');
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
    return MultiBlocListener(
      listeners: [
        BlocListener<AssetAuditGetImageCubit, AssetAuditGetImageState>(
          listener: (context, state) {
            // Only handle images requested by this screen to prevent repeated processing
            if (state is AssetAuditGetImageSuccess && 
                _isRequestingImage && 
                _currentRequestedImageId != null) {
              print('=== SPV Screen: Image fetch success for requested image ===');
              print('Image data length: ${state.imageData.length}');
              print('Image data preview: ${state.imageData.substring(0, state.imageData.length > 100 ? 100 : state.imageData.length)}...');

              if (state.imageData.isNotEmpty) {
                String finalImageData;
                if (state.imageData.startsWith('data:image/')) {
                  finalImageData = state.imageData;
                  print('SPV: Image data is already in data URL format');
                } else {
                  finalImageData = 'data:image/jpeg;base64,${state.imageData}';
                  print('SPV: Added data URL prefix to raw base64 data');
                }

                setState(() {
                  spvPhoto = finalImageData;
                  spvCardKey++;
                  _isRequestingImage = false;
                  _currentRequestedImageId = null;
                });
                _onFormChanged();

                print('SPV photo updated with final image data');
              } else {
                print('SPV Screen: Received empty image data');
                setState(() {
                  spvPhoto = null;
                  spvCardKey++;
                  _isRequestingImage = false;
                  _currentRequestedImageId = null;
                });
                _onFormChanged();
              }
            } else if (state is AssetAuditGetImageFailure && _isRequestingImage) {
              print('=== SPV Screen: Image fetch failed for requested image ===');
              print('Error: ${state.errorMessage}');
              setState(() {
                spvPhoto = null;
                spvCardKey++;
                _isRequestingImage = false;
                _currentRequestedImageId = null;
              });
              _onFormChanged();
            }
          },
        ),
        BlocListener<AssetAuditCubit, AssetAuditState>(
          listener: (context, state) {
            if (state is AssetAuditLoaded) {
              print('=== SPV Screen: AssetAuditLoaded ===');
              final spvData = state.assetAuditData.responseData.categories['SPV'];
              if (spvData != null) {
                setState(() {
                  totalSpvItems = spvData.assets.length;
                  
                  // Load items that have been successfully posted to API AND have user interaction
                  // (either photo taken or serial number entered - regardless of QR scan or manual entry)
                  final postedItems = spvData.assets.where((asset) => 
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
                  
                  // Only update savedSpvItems if we should update from API
                  if (_shouldUpdateFromAPI) {
                    // Preserve locally saved items that haven't been posted to API yet
                    final localItems = savedSpvItems.where((item) => 
                      item['assetAuditSiteRespId'] == null
                    ).toList();
                    
                    // Combine API items with local items
                    savedSpvItems = [...postedItems, ...localItems];

                    // Set flag to false to prevent further updates unless explicitly needed
                    _shouldUpdateFromAPI = false;
                  }
                  
                  // Only update remarks if user hasn't made changes
                  if (remarksController.text.isEmpty) {
                    remarksController.text = spvData.remarks.isNotEmpty
                        ? spvData.remarks.first.itemTypeRemark ?? ''
                        : '';
                  }
                });
             } else {
                print('SPV category not found in loaded data');
              }
            } else if (state is AssetAuditError) {
              showCustomToast(context, state.message);
            } else if (state is AssetAuditPostSuccess) {
              // Allow update from API after successful post
              _shouldUpdateFromAPI = true;
              context.read<AssetAuditCubit>().getAssetAuditData(
                siteType: widget.siteType,
                auditSchId: widget.auditSchId,
                siteAuditSchId: widget.siteAuditSchId,
              );
            } else if (state is AssetAuditPostError) {
              print('Error posting SPV data: ${state.message}');
              // Only show toast if this screen initiated the post action
              if (mounted) {
                showCustomToast(context, 'Error saving SPV data: ${state.message}');
              }
            }
          },
        ),
        BlocListener<AssetAuditGetImageCubit, AssetAuditGetImageState>(
          listener: (context, state) async {
            if (state is AssetAuditGetImageSuccess) {
              print('SPV Image loaded for photoId: $_lastRequestedPhotoId, data length: ${state.imageData.length}');
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
                  _onFormChanged();

                  _fetchingImage = false;
                  _fetchNextImage();
                } else {
                  print('Empty image data received for SPV photoId: $_lastRequestedPhotoId');
                  await _handleImageLoadRetry(_lastRequestedPhotoId ?? '', 'spv');
                }
              } else {
                print('AssetAuditCubit state is not AssetAuditLoaded or pageHeader is empty');
                _fetchingImage = false;
                _fetchNextImage();
              }
            } else if (state is AssetAuditGetImageFailure) {
              print('Failed to load SPV image for photoId: $_lastRequestedPhotoId, error: ${state.errorMessage}');
              await _handleImageLoadRetry(_lastRequestedPhotoId ?? '', 'spv');
            }
          },
        ),
      ],
      child: PopScope(
        canPop: !hasUnsavedChanges,
        child: Scaffold(
          extendBodyBehindAppBar: true,
          resizeToAvoidBottomInset: false,
          appBar: CustomFormAppbar(
            title: "Asset Audit",
            onClose: () async {
              if (hasUnsavedChanges) {
                showDialog(
                  context: context,
                  barrierDismissible: true,
                  builder: (dialogContext) => UnsavedChangesDialog(
                    siteAuditSchId: widget.siteAuditSchId,
                    section: "Asset Audit",
                    parentContext: context, // Use the outer context (screen context)
                    onSaveAndExit: () {
                      _saveAndExit();
                    },
                    onDiscard: () {
                    },
                  ),
                );
              } else {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                      builder: (context) => HomeScreen()
                  ),
                );
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
                                  label: "SPV Make",
                                  initialValue: widget.assetAuditData?.responseData.categories['SPV']?.assets.isNotEmpty == true
                                      ? widget.assetAuditData!.responseData.categories['SPV']!.assets.first.oemName ?? "N/A"
                                      : "N/A",
                                  isRequired: true,
                                  isEditable: false,
                                ),
                                getHeight(15),
                                CustomFormField(
                                  label: "Type of SPV",
                                  initialValue: widget.assetAuditData?.responseData.categories['SPV']?.assets.isNotEmpty == true
                                      ? widget.assetAuditData!.responseData.categories['SPV']!.assets.first.itemType ?? "N/A"
                                      : "N/A",
                                  isRequired: false,
                                  isEditable: false,
                                ),
                                getHeight(15),
                                CustomFormField(
                                  label: "Count of SPV",
                                  initialValue: widget.assetAuditData?.responseData.categories['SPV']?.assets.length.toString() ?? "0",
                                  isRequired: false,
                                  isEditable: false,
                                ),
                                getHeight(15),
                                Text(
                                  "SPV Details",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white,
                                    fontFamily: fontFamilyMontserrat,
                                  ),
                                ),
                                getHeight(3),
                                CustomInfoCard(
                                  key: ValueKey('spv_$spvCardKey'),
                                  serialLabel: "SPV - Serial Number",
                                  serialHintText: "SPV Serial Number *",
                                  photoLabel: "Add a Photo",
                                  statusLabel: "Status",
                                  serialController: spvSerialController,
                                  onSave: _saveSpvForm,
                                  isStatusEditable: true,
                                  backendStatus: false,
                                  remarksLabel: widget.assetAuditData?.responseData.categories['SPV']?.assets.isNotEmpty == true
                                      ? "SPV (${widget.assetAuditData!.responseData.categories['SPV']!.assets.first.capacity ?? 'N/A'})"
                                      : "SPV (Capacity)",
                                  remarksHintText: widget.assetAuditData?.responseData.categories['SPV']?.assets.isNotEmpty == true
                                      ? widget.assetAuditData!.responseData.categories['SPV']!.assets.first.capacity ?? "N/A"
                                      : "N/A",
                                  remarksController: null,
                                  isRemarksEditable: false,
                                  onPhotoTap: (photoPath) {
                                    setState(() {
                                      spvPhoto = photoPath;
                                    });
                                    _onFormChanged();
                                  },
                                  onStatusChanged: (val) {
                                    setState(() {
                                      spvStatus = val ? "OK" : "Not OK";
                                    });
                                    _onFormChanged();
                                  },
                                  onSerialChanged: (serialNumber) {
                                    setState(() {
                                      spvSerialNumber = serialNumber;
                                      isQRCodeScanned = false;
                                    });
                                    _onFormChanged();
                                  },
                                  initialStatus: spvStatus == "OK"
                                      ? true
                                      : (spvStatus == "Not OK" ? false : null),
                                  initialPhotoPath: spvPhoto,
                                  isEditable: true,
                                ),
                                getHeight(8),
                                _buildSpvSavedItemsList(),
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
                                text: AssetAuditNavigationHelper.getSolarPreviousScreenName('SPV'),
                                isLeftArrow: true,
                                backgroundColor: AppColors.buttonColorBackBg,
                                textColor: AppColors.buttonColorTextBg,
                                onPressed: () {
                                  final previousScreen = AssetAuditNavigationHelper.getPreviousAvailableScreen(widget.assetAuditData, 'SPV');
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
                                        await _postSPVData();

                                      },
                                    );
                                  } else {
                                    return ArrowButton(
                                      text: nextScreen,
                                      isLeftArrow: false,
                                      backgroundColor: AppColors.buttonColorBg,
                                      textColor: AppColors.buttonColorSite,
                                      onPressed: () async {
                                        await _postSPVData();
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

  Widget _buildSpvSavedItemsList() {
    if (savedSpvItems.isEmpty) {
      return Container(); // Return empty container if no items
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
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Column(
              children: [
                Row(
                  children: [
                  Container(
                    width: 200,
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
                    ),
                  ),
                  Container(
                    width: 80,
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
                    ),
                  ),
                  Container(
                    width: 80,
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
                    ),
                  ),
                  Container(
                    width: 80,
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
                  Container(
                    width: 80,
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
                ],
              ),
              const SizedBox(height: 8),

              if (savedSpvItems.isNotEmpty) ...[
                ...savedSpvItems.map((item) {
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
                        Container(
                          width: 200,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            item["serialNumber"] ?? "",
                            style: const TextStyle(
                              color: AppColors.color555555,
                              fontSize: 14,
                              fontFamily: fontFamilyMontserrat,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                        Container(
                          width: 80,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
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
                        Container(
                          width: 80,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Icon(
                            item['isQRCodeScanned'] == true
                                ? Icons.qr_code_scanner
                                : Icons.close,
                            color: item['isQRCodeScanned'] == true
                                ? Colors.blue
                                : Colors.red,
                          ),
                        ),
                        Container(
                          width: 80,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
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
                        Container(
                          width: 80,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
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
        ),
      ],
    );
  }
}
