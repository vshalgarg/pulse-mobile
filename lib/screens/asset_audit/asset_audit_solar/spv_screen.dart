import 'dart:convert';

import 'package:app/commonWidgets/custom_buttons/arrow_botton.dart';
import 'package:app/constants/constants_methods.dart';
import 'package:app/utils/asset_audit_navigation_helper.dart';
import 'package:app/utils/logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:io';
import 'dart:async';

import '../../../bloc/asset_audit_cubit.dart';
import '../../../bloc/asset_audit_state.dart';
import '../../../bloc/asset_audit_photo_upload_cubit.dart';
import '../../../bloc/asset_audit_get_image_cubit.dart';
import '../../../commonWidgets/custom_dialogs/unsaved_changes_dialog.dart';
import '../../../commonWidgets/custom_form_appbar.dart';
import '../../../commonWidgets/custom_form_field.dart';
import '../../../commonWidgets/custom_remark.dart';
import '../../../commonWidgets/asset_audit_form_component.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_images.dart';
import '../../../constants/constants_strings.dart';
import '../../../services/local_storage_db.dart';
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
  bool _isFormInitialized = false;
  bool _shouldUpdateFromAPI = true; // Flag to control when to update from API
  int totalItemsToScan = 6;
  List<Map<String, dynamic>> savedItems = [];

  // SPV field values
  String? spvSerialNumber;
  String? photoImageId;
  String? spvPhoto;
  String? spvStatus;
  final remarksController = TextEditingController(); // User remarks
  List<Map<String, dynamic>> savedSpvItems = [];

  // Controllers for AssetAuditFormComponent
  final TextEditingController spvSerialController = TextEditingController();
  int totalSpvItems = 0; // Will be set from API data
  bool isQRCodeScanned = false; // Track if serial was scanned or manually entered

  // API integration fields
  String? uploadedPhotoPath;
  String? uploadedImgId;
  String? fetchedImageData;
  bool _hasFormDataChanges = false;
  String? _pendingNavigation; // Track pending navigation after successful post
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
  
  // Flag to prevent repeated API calls
  bool _hasInitialized = false;
  
  // Loading state for getAssetAuditData API
  bool _isLoadingAssetData = false;
  
  // Track original values for change detection
  String? _originalSpvStatus;
  
  // Track if we're editing an existing item
  bool _isEditingExistingItem = false;
  String? _editingItemSerialNumber;

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
    Logger.debugLog('=== SPV didChangeDependencies called ===');

    // Check if data is already loaded before making API call
    final currentState = context.read<AssetAuditCubit>().state;
    if (currentState is! AssetAuditLoaded && !_hasInitialized) {
      _hasInitialized = true;
      Logger.debugLog('=== SPV: Making initial API call ===');
      setState(() {
        _isLoadingAssetData = true;
      });
      context.read<AssetAuditCubit>().getAssetAuditData(
        siteType: widget.siteType,
        auditSchId: widget.auditSchId,
        siteAuditSchId: widget.siteAuditSchId,
      );
    } else {
      Logger.debugLog('=== SPV: Skipping API call - data already loaded or already initialized ===');
    }

    // Initialize total items and saved items from API data
    if (widget.assetAuditData != null) {
      final spvData = widget.assetAuditData!.responseData.categories['SPV'];
      if (spvData != null) {
        totalSpvItems = spvData.assets.length;
        Logger.debugLog('SPV total items from API: $totalSpvItems');
        Logger.debugLog('SPV data received: ${spvData.assets.length} assets');
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
              savedSpvItems = [...postedItems,];
            }

            // Initialize remarks from API only if user hasn't made changes
            if (spvData.remarks.isNotEmpty && remarksController.text.isEmpty) {
              remarksController.text = spvData.remarks.first.itemTypeRemark ?? '';
            }
          });
        } else {
          Logger.debugLog('No SPV assets found in API data');
        }
      } else {
        Logger.debugLog('SPV category not found in asset audit data!');
      }
    } else {
      Logger.debugLog('Asset audit data is null!');
    }

    // Check page header for additional data
    _checkPageHeaderForData();
    
    // Mark form as initialized after data loading
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _isFormInitialized = true;
      Logger.debugLog('SPV Form initialized - change tracking enabled');
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
    // Add debug logging to track how often this is called
    Logger.debugLog('=== SPV: _onFormChanged called ===');
    
    setState(() {
      final hasLocalPhoto = uploadedPhotoPath != null && uploadedPhotoPath!.isNotEmpty;
      final hasServerImage = uploadedImgId != null && uploadedImgId!.isNotEmpty && uploadedImgId != "0";
      final hasImageData = fetchedImageData != null && fetchedImageData!.isNotEmpty;

      // Check if there are unsaved items in savedSpvItems (items without assetAuditSiteRespId)
      final hasUnsavedItems = savedSpvItems.any((item) => item['assetAuditSiteRespId'] == null);

      // Only set hasUnsavedChanges to true if there are actual unsaved changes in the current form
      // and the form has been initialized (to avoid false positives during initialization)
      if (_isFormInitialized) {
        // Check if status has changed from original value
        final statusChanged = _originalSpvStatus != null && spvStatus != _originalSpvStatus;
        
        if (statusChanged) {
          Logger.debugLog('=== SPV: Status changed from $_originalSpvStatus to $spvStatus ===');
        }
        
        hasUnsavedChanges = serialController.text.isNotEmpty ||
            spvSerialController.text.isNotEmpty ||
            hasLocalPhoto ||
            hasServerImage ||
            hasImageData ||
            remarksController.text.isNotEmpty ||
            statusChanged || // Include status changes
            hasUnsavedItems; // Include unsaved items in the check
      }

      _hasFormDataChanges = true;
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
            Logger.debugLog('✅ SPV Photo upload SUCCESS!');
            Logger.debugLog('Response imgId: ${state.response.imgId}');
            subscription.cancel();
            completer.complete(state.response.imgId);
          } else if (state is AssetAuditPhotoUploadFailure) {
            Logger.errorLog('❌ SPV Photo upload FAILED!');
            Logger.errorLog('Error message: ${state.errorMessage}');
            subscription.cancel();
            completer.completeError(state.errorMessage);
          } else {
            Logger.debugLog('📤 SPV Photo upload in progress...');
          }
        });

        Logger.debugLog('Starting SPV photo upload...');
        context.read<AssetAuditPhotoUploadCubit>().uploadPhoto(
          file: file,
          imgId: imgIdToUse,
          schId: schId,
        );

        Logger.debugLog('Waiting for SPV photo upload result...');
        final result = await completer.future.timeout(
          const Duration(seconds: 30),
          onTimeout: () {
            Logger.errorLog('⏰ SPV Photo upload TIMEOUT after 30 seconds');
            subscription.cancel();
            throw Exception('Photo upload timeout');
          },
        );

        Logger.debugLog('=== SPV Photo Upload Completed ===');
        Logger.debugLog('Final result: $result');
        return result;
      } else {
        Logger.errorLog('❌ Site data not loaded for SPV photo upload');
        throw Exception('Site data not loaded');
      }
    } catch (e) {
      Logger.errorLog('❌ Error uploading SPV photo: $e');
      rethrow;
    }
  }

  // Custom validation function for the AssetAuditFormComponent
  bool _validateSPVSerialNumber(String serialNumber, bool isQRCodeScanned) {
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
      Logger.debugLog('Fetching image for photo ID: $photo');
      final completer = Completer<String?>();
      late StreamSubscription subscription;

      subscription = context.read<AssetAuditGetImageCubit>().stream.listen((state) {
        if (state is AssetAuditGetImageSuccess && state.imageData.isNotEmpty) {
          Logger.debugLog('Image fetched successfully for photo ID: $photo');
          final finalImageData = state.imageData.startsWith('data:image/')
              ? state.imageData
              : 'data:image/jpeg;base64,${state.imageData}';
          completer.complete(finalImageData);
          subscription.cancel();
        } else if (state is AssetAuditGetImageFailure) {
          Logger.errorLog('Failed to fetch image: ${state.errorMessage}');
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


  Future<void> _saveAndExit() async {
    await _postSPVData();
  }

  int? _getRemarksAssetAuditSiteRespId() {
    Logger.debugLog('=== SPV Screen: Getting Remarks AssetAuditSiteRespId ===');

    if (widget.assetAuditData == null) {
      Logger.debugLog('assetAuditData is null, cannot get remarks ID');
      return null;
    }

    final spvData = widget.assetAuditData!.responseData.categories['SPV'];
    if (spvData == null) {
      Logger.debugLog('SPV category data is null');
      return null;
    }

    final remarks = spvData.remarks;
    if (remarks.isNotEmpty) {
      Logger.debugLog('Found ${remarks.length} remarks in backend data');

      for (var remark in remarks) {
        if (remark.assetAuditSiteRespId != null &&
            remark.assetAuditSiteRespId > 0 &&
            remark.itemType == 'SPV') {
          Logger.debugLog('Using SPV remarks ID: ${remark.assetAuditSiteRespId}');
          return remark.assetAuditSiteRespId;
        }
      }

      for (var remark in remarks) {
        if (remark.assetAuditSiteRespId != null && remark.assetAuditSiteRespId > 0) {
          Logger.debugLog('Using fallback remarks ID: ${remark.assetAuditSiteRespId} for itemType: ${remark.itemType}');
          return remark.assetAuditSiteRespId;
        }
      }
    }

    Logger.debugLog('No valid remarks ID found in backend data');
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
            Logger.debugLog('SPV Screen: Added user remarks to post with ID: $remarksAssetAuditSiteRespId, text: "${remarksController.text}"');
          } else {
            Logger.debugLog('SPV Screen: Could not find remarks ID from backend data');
          }
        } else {
          Logger.debugLog('SPV Screen: No remarks to post - remarksController.text is empty');
        }

        if (allItemsToPost.isEmpty) {
          Logger.debugLog('SPV Screen: No items to post');
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
          Logger.debugLog('SPV Screen: Storing current remarks text: "$currentRemarksText"');

          context.read<AssetAuditCubit>().postAssetAuditData(requests: requests);

        }
      } else {
        Logger.debugLog('No SPV items to post - user can navigate without saving items');
      }
    } catch (e) {
      Logger.errorLog('Error posting SPV data: $e');
    }
  }

  // Simplified save method - component handles all logic, just receives updated list
  void _onSPVItemSaved(List<Map<String, dynamic>> updatedItems) {
    setState(() {
      savedSpvItems.clear();
      savedSpvItems.addAll(updatedItems);
      hasUnsavedChanges = true;
      Logger.debugLog('SPV items updated: ${updatedItems.length} items');
    });
  }


  String _formatSerialNumber(String serialNumber) {
    if (serialNumber.length <= 7) {
      return serialNumber;
    }
    return "${serialNumber.substring(0, 5)}...";
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

              if (state.imageData.isNotEmpty) {
                String finalImageData;
                if (state.imageData.startsWith('data:image/')) {
                  finalImageData = state.imageData;
                } else {
                  finalImageData = 'data:image/jpeg;base64,${state.imageData}';
                }

                setState(() {
                  spvPhoto = finalImageData;
                  _isRequestingImage = false;
                  _currentRequestedImageId = null;
                });
                _onFormChanged();

              } else {
                setState(() {
                  spvPhoto = null;
                  _isRequestingImage = false;
                  _currentRequestedImageId = null;
                });
                _onFormChanged();
              }
            } else if (state is AssetAuditGetImageFailure && _isRequestingImage) {
              Logger.errorLog('=== SPV Screen: Image fetch failed for requested image ===');
              Logger.errorLog('Error: ${state.errorMessage}');
              setState(() {
                spvPhoto = null;
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
              Logger.debugLog('=== SPV Screen: AssetAuditLoaded ===');
              setState(() {
                _isLoadingAssetData = false;
              });
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
                    savedSpvItems = [...postedItems];

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
                
                // Update hasUnsavedChanges after data refresh
                _onFormChanged();
             } else {
                Logger.debugLog('SPV category not found in loaded data');
              }
            } else if (state is AssetAuditError) {
              setState(() {
                _isLoadingAssetData = false;
              });
              showCustomToast(context, state.message);
            } else if (state is AssetAuditPosting) {
              // Show loading dialog when posting data
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => const Center(
                  child: CircularProgressIndicator(),
                ),
              );
            } else if (state is AssetAuditPostSuccess) {
              // Close loading dialog when posting is successful
              if (Navigator.canPop(context)) {
                Navigator.of(context).pop();
              }
              
              // Handle pending navigation
              if (_pendingNavigation != null) {
                final navigationTarget = _pendingNavigation;
                _pendingNavigation = null; // Clear the flag
                
                if (navigationTarget == 'home') {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => HomeScreen()),
                  );
                } else {
                  _navigateToNextScreen(context, navigationTarget!);
                }
                return; // Don't refresh data if navigating away
              }
              
              // Allow update from API after successful post (only if not navigating)
              _shouldUpdateFromAPI = true;
              setState(() {
                _isLoadingAssetData = true;
              });
              context.read<AssetAuditCubit>().getAssetAuditData(
                siteType: widget.siteType,
                auditSchId: widget.auditSchId,
                siteAuditSchId: widget.siteAuditSchId,
              );
            } else if (state is AssetAuditPostError) {
              // Close loading dialog if it's open
              if (Navigator.canPop(context)) {
                Navigator.of(context).pop();
              }
              // Clear pending navigation on error
              _pendingNavigation = null;
              Logger.errorLog('Error posting SPV data: ${state.message}');
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
              Logger.debugLog('SPV Image loaded for photoId: $_lastRequestedPhotoId, data length: ${state.imageData.length}');
              final assetAuditState = context.read<AssetAuditCubit>().state;
              if (assetAuditState is AssetAuditLoaded && assetAuditState.assetAuditData.pageHeader.isNotEmpty) {
                final schId = assetAuditState.assetAuditData.pageHeader.first.siteAuditSchId.toString();

                if (state.imageData.isNotEmpty) {
                  LocalStorageDB.updateAssetAuditSelfie(
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
                  Logger.debugLog('Empty image data received for SPV photoId: $_lastRequestedPhotoId');
                  await _handleImageLoadRetry(_lastRequestedPhotoId ?? '', 'spv');
                }
              } else {
                Logger.debugLog('AssetAuditCubit state is not AssetAuditLoaded or pageHeader is empty');
                _fetchingImage = false;
                _fetchNextImage();
              }
            } else if (state is AssetAuditGetImageFailure) {
              Logger.errorLog('Failed to load SPV image for photoId: $_lastRequestedPhotoId, error: ${state.errorMessage}');
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
                    onSaveAndExit: () async {
                      await _saveAndExit();
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
              // Loading indicator for getAssetAuditData API
              if (_isLoadingAssetData)
                Container(
                  color: Colors.black.withOpacity(0.3),
                  child: const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.green7),
                    ),
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
                                AssetAuditFormComponent(
                                  componentId: 'spv_component',
                                  serialLabel: "SPV - Serial Number *",
                                  serialHintText: "SPV Serial Number *",
                                  photoLabel: "Add a Photo",
                                  disabledFieldLabel: widget.assetAuditData?.responseData.categories['SPV']?.assets.isNotEmpty == true
                                      ? "SPV (${widget.assetAuditData!.responseData.categories['SPV']!.assets.first.capacity ?? 'N/A'})"
                                      : "SPV (Capacity)",
                                  disabledFieldValue: widget.assetAuditData?.responseData.categories['SPV']?.assets.isNotEmpty == true
                                      ? widget.assetAuditData!.responseData.categories['SPV']!.assets.first.capacity ?? "N/A"
                                      : "N/A",
                                  serialController: spvSerialController,
                                  initialSavedItems: savedSpvItems,
                                  onItemSaved: _onSPVItemSaved,
                                  onStatusChanged: (status) {
                                    // Handle status change if needed
                                  },
                                  customValidator: _validateSPVSerialNumber,
                                  customValidationErrorMessage: isQRCodeScanned 
                                      ? 'Invalid QR Code! Serial number not found in system.'
                                      : 'Invalid serial number! Please check and try again.',
                                  siteAuditSchId: widget.siteAuditSchId,
                                  showTable: true,
                                  tableTitle: "Saved SPV Items",
                                  imageHeight: 150,
                                  enableImageCompression: true,
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
                                text: _getPreviousAvailableScreen() ?? 'BACK',
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
                                        _pendingNavigation = 'home';
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
                                        _pendingNavigation = nextScreen;
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

}
