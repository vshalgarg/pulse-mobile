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
import '../../../commonWidgets/asset_audit_form_component.dart';

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

  // DCBA field values
  final remarksController = TextEditingController();
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

  // Loading state for getAssetAuditData API
  bool _isLoadingAssetData = false;
  
  // Loading state for postAssetAuditData API
  bool _isPostingData = false;

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
    setState(() {
      _isLoadingAssetData = true;
    });
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
      // Check if there are unsaved items in savedDcbaItems (items without assetAuditSiteRespId)
      final hasUnsavedItems = savedDcbaItems.any((item) => item['assetAuditSiteRespId'] == null);
      
      hasUnsavedChanges = serialController.text.isNotEmpty || 
                         remarksController.text.isNotEmpty ||
                         hasUnsavedItems; // Include unsaved items in the check

      if (showValidationErrors && serialController.text.isNotEmpty) {
        showValidationErrors = false;
      }
    });
  }

  Future<void> _saveAndExit() async {

      // Post DCBA data to API first
      await _postDcbaData();
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

  int? _getRemarksAssetAuditSiteRespId() {
    final dcbaData = widget.assetAuditData?.responseData.categories['DCDB'];
    if (dcbaData != null && dcbaData.remarks.isNotEmpty) {
      return dcbaData.remarks.first.assetAuditSiteRespId;
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





  String _formatSerialNumber(String serialNumber) {
    if (serialNumber.length <= 7) {
      return serialNumber;
    }
    return "${serialNumber.substring(0, 5)}...";
  }



  /// Check if string is numeric
  bool _isNumeric(String str) {
    return double.tryParse(str) != null;
  }

  // Custom validation function for the AssetAuditFormComponent
  bool _validateDCBASerialNumber(String serialNumber, bool isQRCodeScanned) {
    if (widget.assetAuditData == null) return false;

    final dcbaData = widget.assetAuditData!.responseData.categories['DCDB'];
    if (dcbaData == null) return false;

    final allItems = dcbaData.assets;
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

  // Simplified save method - component handles all logic, just receives updated list
  void _onDCBAItemSaved(List<Map<String, dynamic>> updatedItems) {
    setState(() {
      savedDcbaItems.clear();
      savedDcbaItems.addAll(updatedItems);
      hasUnsavedChanges = true;
      print('DCBA items updated: ${updatedItems.length} items');
    });
  }



  /// Post DCBA data to API
  Future<void> _postDcbaData() async {
    try {
      final assetAuditState = context.read<AssetAuditCubit>().state;
      if (assetAuditState is AssetAuditLoaded && assetAuditState.assetAuditData.pageHeader.isNotEmpty) {
        List<Map<String, dynamic>> allItemsToPost = [];

        if (savedDcbaItems.isNotEmpty) {
          final enhancedItems = AssetAuditPostHelper.enhanceSavedItems(
            savedItems: savedDcbaItems,
            screenName: 'solar_dcba',
          );
          allItemsToPost.addAll(enhancedItems);
        }

        if (remarksController.text.isNotEmpty) {
          int? remarksAssetAuditSiteRespId = _getRemarksAssetAuditSiteRespId();

          if (remarksAssetAuditSiteRespId != null) {
            Map<String, dynamic> remarksData = {
              'itemType': 'DCDB',
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
            print('DCBA Screen: Added user remarks to post with ID: $remarksAssetAuditSiteRespId, text: "${remarksController.text}"');
          } else {
            print('DCBA Screen: Could not find remarks ID from backend data');
          }
        } else {
          print('DCBA Screen: No remarks to post - remarksController.text is empty');
        }

        if (allItemsToPost.isEmpty) {
          print('DCBA Screen: No items to post');
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
          final currentRemarksText = remarksController.text;
          print('DCBA Screen: Storing current remarks text: "$currentRemarksText"');
          
          setState(() {
            _isPostingData = true;
          });
          context.read<AssetAuditCubit>().postAssetAuditData(requests: requests);
        }
      } else {
        print('No DCBA items to post - user can navigate without saving items');
      }
    } catch (e) {
      print('Error posting DCBA data: $e');
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
              });
            } else if (state is AssetAuditGetImageFailure) {
              setState(() {
                displayedImageBase64 = null;
                isLoadingImage = false;
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
              setState(() {
                _isLoadingAssetData = false;
              });
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
              setState(() {
                _isLoadingAssetData = false;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message ?? 'Error loading data'),
                  backgroundColor: Colors.red,
                  duration: const Duration(seconds: 3),
                ),
              );
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
              setState(() {
                _isPostingData = false;
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
              setState(() {
                _isPostingData = false;
              });
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
              // Add safety checks to prevent Navigator lock
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
                              AssetAuditFormComponent(
                                componentId: 'dcba_component',
                                serialLabel: "DCBA - Serial Number *",
                                serialHintText: "DCBA Serial Number *",
                                photoLabel: "Add a Photo",
                                disabledFieldLabel: dcbaCategoryData?.assets.isNotEmpty == true
                                    ? "DCBA (${dcbaCategoryData?.assets.first.capacity ?? 'N/A'})"
                                    : "DCBA (Capacity)",
                                disabledFieldValue: dcbaCategoryData?.assets.isNotEmpty == true
                                    ? dcbaCategoryData?.assets.first.capacity ?? "N/A"
                                    : "N/A",
                                serialController: dcbaSerialController,
                                initialSavedItems: savedDcbaItems,
                                onItemSaved: _onDCBAItemSaved,
                                onStatusChanged: (status) {
                                  // Handle status change if needed
                                },
                                customValidator: _validateDCBASerialNumber,
                                customValidationErrorMessage: isQRCodeScanned 
                                    ? 'Invalid QR Code! Serial number not found in system.'
                                    : 'Invalid serial number! Please check and try again.',
                                siteAuditSchId: widget.siteAuditSchId,
                                showTable: true,
                                tableTitle: "Saved DCBA Items",
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
                                        await _postDcbaData();
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

                                        // POST data to API before navigation
                                        await _postDcbaData();

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


}
