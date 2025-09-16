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
import '../../../models/asset_audit_model.dart';
import '../../home_screen.dart';
import '../../../utils/asset_audit_post_helper.dart';

class WMSScreen extends StatefulWidget {
  final String siteType;
  final String auditSchId;
  final String siteAuditSchId;
  final AssetAuditModel? assetAuditData; // Complete asset audit data

  const WMSScreen({
    super.key,
    required this.siteType,
    required this.auditSchId,
    required this.siteAuditSchId,
    this.assetAuditData, // Complete asset audit data
  });

  @override
  State<WMSScreen> createState() => _WMSScreenState();
}

class _WMSScreenState extends State<WMSScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController serialController = TextEditingController();
  bool hasUnsavedChanges = false;
  bool showValidationErrors = false;

  // WMS field values
  String? wmsSerialNumber;
  String? wmsPhoto;
  String? wmsStatus;
  final remarksController = TextEditingController();
  int wmsCardKey = 0;
  List<Map<String, dynamic>> savedWmsItems = [];
  bool isQRCodeScanned =
      false; // Track if serial was scanned or manually entered

  // API integration fields
  String? displayedImageBase64;
  bool isLoadingImage = false;
  StreamSubscription? _getImageSubscription;

  // Image loading tracking to prevent repeated processing
  String? _currentRequestedImageId;
  bool _isRequestingImage = false;

  // Controllers for CustomInfoCard
  final TextEditingController wmsSerialController = TextEditingController();

  // Get WMS data from API
  int get totalWmsItems {
    if (widget.assetAuditData?.responseData.categories['WMS']?.assets != null) {
      return widget
          .assetAuditData!
          .responseData
          .categories['WMS']!
          .assets
          .length;
    }
    return 0;
  }

  // Get WMS category data
  CategoryData? get wmsCategoryData {
    return widget.assetAuditData?.responseData.categories['WMS'];
  }

  @override
  void initState() {
    super.initState();
    serialController.addListener(_onFormChanged);
    wmsSerialController.addListener(_onFormChanged);
    _setupGetImageListener();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    print('=== WMS didChangeDependencies called ===');

    context.read<AssetAuditCubit>().getAssetAuditData(
      siteType: widget.siteType,
      auditSchId: widget.auditSchId,
      siteAuditSchId: widget.siteAuditSchId,
    );

    // Initialize total items and saved items from API data
    if (widget.assetAuditData != null) {
      final wmsData = widget.assetAuditData!.responseData.categories['WMS'];
      if (wmsData != null) {
        setState(() {
          print('WMS total items from API: ${wmsData.assets.length}');
          print('WMS data received: ${wmsData.assets.length} assets');
          if (wmsData.assets.isNotEmpty) {
            print('First WMS asset: ${wmsData.assets.first.oemName}');
            print('First WMS asset type: ${wmsData.assets.first.itemType}');
            print('First WMS asset capacity: ${wmsData.assets.first.capacity}');

            // Load items that have been successfully posted to API AND have user interaction
            // (either photo taken or serial number entered - regardless of QR scan or manual entry)
            final postedItems = wmsData.assets
                .where(
                  (asset) =>
                      asset.assetAuditSiteRespId != null &&
                      asset.photoId != null,
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

            // Update savedWmsItems with posted items
            savedWmsItems = postedItems;

            // Only initialize remarks from API if user hasn't made changes
            if (wmsData.remarks.isNotEmpty && remarksController.text.isEmpty) {
              remarksController.text =
                  wmsData.remarks.first.itemTypeRemark ?? '';
              print(
                'Setting remarksController.text: ${wmsData.remarks.first.itemTypeRemark ?? ''}',
              );
            }
          } else {
            print('No WMS assets found in API data');
          }
        });
      } else {
        print('WMS category not found in asset audit data!');
      }
    } else {
      print('Asset audit data is null!');
    }
  }

  @override
  void dispose() {
    serialController.removeListener(_onFormChanged);
    wmsSerialController.removeListener(_onFormChanged);
    serialController.dispose();
    wmsSerialController.dispose();
    remarksController.dispose();
    _getImageSubscription?.cancel();
    super.dispose();
  }

  void _onFormChanged() {
    setState(() {
      final hasLocalPhoto = wmsPhoto != null && wmsPhoto!.isNotEmpty;
      final hasImageData =
          displayedImageBase64 != null && displayedImageBase64!.isNotEmpty;

      hasUnsavedChanges =
          serialController.text.isNotEmpty ||
          wmsSerialController.text.isNotEmpty ||
          hasLocalPhoto ||
          hasImageData ||
          savedWmsItems.isNotEmpty ||
          remarksController.text.isNotEmpty;

      if (showValidationErrors &&
          (serialController.text.isNotEmpty ||
              wmsSerialController.text.isNotEmpty)) {
        showValidationErrors = false;
      }
    });
  }

  void _saveFormDataToHive() {
    // No Hive storage - data is only stored in memory and posted to API
  }

  bool _validateSerialNumber(String serialNumber) {
    if (widget.assetAuditData == null) return false;

    print('=== WMS Serial Number Validation Debug ===');
    print('Validating serial number: "$serialNumber"');

    final wmsData = widget.assetAuditData!.responseData.categories['WMS'];
    if (wmsData == null) return false;

    final allItems = wmsData.assets;
    print('WMS items available: ${allItems.length}');

    if (allItems.isNotEmpty) {
      print('WMS items details:');
      for (var item in allItems) {
        print(
          '  - Item: ${item.itemType} | nexgenSerialNo: "${item.nexgenSerialNo}" | mfgSerialNo: "${item.mfgSerialNo}"',
        );
      }
    }

    bool isValid = allItems.any(
      (item) =>
          item.mfgSerialNo?.toLowerCase() == serialNumber.toLowerCase() ||
          item.nexgenSerialNo?.toLowerCase() == serialNumber.toLowerCase(),
    );

    if (!isValid) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showCustomToast(
          context,
          '❌ Invalid serial number! Not found in system.',
        );
      });
    }

    return isValid;
  }

  Future<void> _postWMSData() async {
    try {
      final assetAuditState = context.read<AssetAuditCubit>().state;
      if (assetAuditState is AssetAuditLoaded &&
          assetAuditState.assetAuditData.pageHeader.isNotEmpty) {
        List<Map<String, dynamic>> allItemsToPost = [];

        if (savedWmsItems.isNotEmpty) {
          final enhancedItems = AssetAuditPostHelper.enhanceSavedItems(
            savedItems: savedWmsItems,
            screenName: 'wms',
          );
          allItemsToPost.addAll(enhancedItems);
        }

        if (remarksController.text.isNotEmpty) {
          String? remarksAssetAuditSiteRespId =
              _getRemarksAssetAuditSiteRespId();

          if (remarksAssetAuditSiteRespId != null) {
            Map<String, dynamic> remarksData = {
              'itemType': 'WMS',
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
            print(
              'WMS Screen: Added user remarks to post with ID: $remarksAssetAuditSiteRespId, text: "${remarksController.text}"',
            );
          } else {
            print('WMS Screen: Could not find remarks ID from backend data');
          }
        }

        if (allItemsToPost.isEmpty) {
          print('WMS Screen: No items to post');
          return;
        }

        final requests =
            await AssetAuditPostHelper.convertSavedItemsToPostRequest(
              savedItems: allItemsToPost,
              assetAuditData: assetAuditState.assetAuditData,
              itemType: 'WMS',
              itemTypeId: 5,
              // Assuming WMS has itemTypeId 5
              screenName: 'wms',
              context: context,
              auditSchId: widget.auditSchId,
            );

        if (requests.isNotEmpty) {
          context.read<AssetAuditCubit>().postAssetAuditData(
            requests: requests,
          );
        }
      } else {
        print('No WMS items to post - user can navigate without saving items');
      }
    } catch (e) {
      print('Error posting WMS data: $e');
    }
  }

  Future<void> _showPhotoViewer(
    BuildContext context,
    String? photo,
    String siteAuditSchId,
  ) async {
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

      subscription = context.read<AssetAuditGetImageCubit>().stream.listen((
        state,
      ) {
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
            children: [
              // Image container
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
                    : Image.file(File(imageData), fit: BoxFit.contain),
              ),
              // Close icon at top-right
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 30),
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
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );
      await _postWmsData();
      await _updateAuditScheduleStatus("In Progress");
      Navigator.of(context).pop();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => HomeScreen()),
      );
    } catch (e) {
      if (Navigator.canPop(context)) Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving data: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _updateAuditScheduleStatus(String status) async {
    try {
      await context.read<AuditScheduleStatusCubit>().updateStatus(
        status: status,
        siteAuditSchId: widget.siteAuditSchId,
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to update status: $e')));
    }
  }

  bool _isFormValid() {
    if (wmsSerialController.text.isEmpty) {
      return false;
    }

    if (wmsPhoto == null || wmsPhoto!.isEmpty) {
      return false;
    }

    if (!_validateSerialNumber(wmsSerialController.text)) {
      return false;
    }

    return true;
  }

  bool _validateForm() {
    setState(() {
      showValidationErrors = true;
    });

    if (wmsSerialController.text.isEmpty) {
      return false;
    }

    if (wmsPhoto == null || wmsPhoto!.isEmpty) {
      return false;
    }

    if (!_validateSerialNumber(wmsSerialController.text)) {
      return false;
    }

    return true;
  }

  Future<void> _saveWmsForm() async {
    if (savedWmsItems.length >= totalWmsItems) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Maximum number of WMS items ($totalWmsItems) already added.',
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
      String? photoImageId = wmsPhoto;

      if (wmsPhoto != null &&
          wmsPhoto!.isNotEmpty &&
          !wmsPhoto!.startsWith('http')) {
        try {
          final file = File(wmsPhoto!);
          if (file.existsSync()) {
            photoImageId = await _uploadWmsPhoto(file);
          } else {
            print('❌ WMS photo file does not exist: $wmsPhoto');
          }
        } catch (e) {
          showCustomToast(context, 'Error uploading photo: $e');
          return;
        }
      } else {
        print('ℹ️ No WMS photo to upload or already has image ID');
      }

      setState(() {
        Map<String, dynamic> currentFormData = {
          'serialNumber': wmsSerialNumber,
          'photo': photoImageId,
          'status': wmsStatus ?? "OK",
          'timestamp': DateTime.now(),
        };

        final existingItemIndex = savedWmsItems.indexWhere(
          (item) => item['serialNumber'] == wmsSerialNumber,
        );

        if (existingItemIndex >= 0) {
          savedWmsItems[existingItemIndex] = currentFormData;
          print(
            'Updated existing WMS item: ${currentFormData['serialNumber']}',
          );
        } else {
          savedWmsItems.add(currentFormData);
          print('Added new WMS item: ${currentFormData['serialNumber']}');
        }

        wmsSerialNumber = null;
        wmsPhoto = null;
        wmsStatus = null;

        wmsSerialController.clear();

        wmsCardKey++;

        hasUnsavedChanges = false;
        showValidationErrors = false;
      });

      int remainingWms = totalWmsItems - savedWmsItems.length;
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
      wmsSerialNumber = item['serialNumber'];
      wmsPhoto = item['photo'];
      wmsStatus = item['status'];
      isQRCodeScanned =
          item['isQRCodeScanned'] ?? false; // Restore QR scan status

      wmsSerialController.text = item['serialNumber'] ?? '';
      displayedImageBase64 = null; // Clear Base64 to avoid showing old image
      isLoadingImage = false; // Reset loading state

      savedWmsItems.remove(item);

      hasUnsavedChanges = true;
      wmsCardKey++;
    });

    // Load image asynchronously to avoid blocking UI
    if (wmsPhoto != null && wmsPhoto!.isNotEmpty && _isNumeric(wmsPhoto!)) {
      print('=== WMS Edit: Fetching image for photo ID: $wmsPhoto ===');
      setState(() {
        _currentRequestedImageId = wmsPhoto;
        _isRequestingImage = true;
        isLoadingImage = true;
      });

      // Use Future.microtask to load image in next frame
      Future.microtask(() {
        context.read<AssetAuditGetImageCubit>().getImage(
          imgId: wmsPhoto!,
          schId: widget.siteAuditSchId,
        );
      });
    }
  }

  // Navigation helper methods
  String? _getNextAvailableScreen() {
    return AssetAuditNavigationHelper.getNextAvailableScreen(
      widget.assetAuditData,
      'WMS',
    );
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
              print(
                '=== WMS Screen: Image fetch success for requested image ===',
              );
              print('Image data length: ${state.imageData.length}');
              print(
                'Image data preview: ${state.imageData.substring(0, state.imageData.length > 100 ? 100 : state.imageData.length)}...',
              );

              if (state.imageData.isNotEmpty) {
                String finalImageData;
                if (state.imageData.startsWith('data:image/')) {
                  finalImageData = state.imageData;
                  print('WMS: Image data is already in data URL format');
                } else {
                  finalImageData = 'data:image/jpeg;base64,${state.imageData}';
                  print('WMS: Added data URL prefix to raw base64 data');
                }

                setState(() {
                  wmsPhoto = finalImageData;
                  wmsCardKey++;
                  _isRequestingImage = false;
                  _currentRequestedImageId = null;
                });

                print('WMS photo updated with final image data');
              } else {
                print('WMS Screen: Received empty image data');
                setState(() {
                  wmsPhoto = null;
                  wmsCardKey++;
                  _isRequestingImage = false;
                  _currentRequestedImageId = null;
                });
              }
            } else if (state is AssetAuditGetImageFailure &&
                _isRequestingImage) {
              print(
                '=== WMS Screen: Image fetch failed for requested image ===',
              );
              print('Error: ${state.errorMessage}');
              setState(() {
                wmsPhoto = null;
                wmsCardKey++;
                _isRequestingImage = false;
                _currentRequestedImageId = null;
              });
            }
          },
        ),
        BlocListener<AssetAuditCubit, AssetAuditState>(
          listener: (context, state) {
            if (state is AssetAuditLoaded) {
              print('=== WMS Screen: AssetAuditLoaded ===');
              final wmsData =
                  state.assetAuditData.responseData.categories['WMS'];
              if (wmsData != null) {
                // Only update if we're not currently in the middle of a save operation
                if (!hasUnsavedChanges) {
                  setState(() {
                    // Load items that have been successfully posted to API AND have user interaction
                    // (either photo taken or serial number entered - regardless of QR scan or manual entry)
                    final postedItems = wmsData.assets
                        .where(
                          (asset) =>
                              asset.assetAuditSiteRespId != null &&
                              asset.photoId != null,
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

                    // Update savedWmsItems with posted items
                    savedWmsItems = postedItems;

                    // Only update remarks from API if user hasn't made changes
                    if (remarksController.text.isEmpty) {
                      remarksController.text = wmsData.remarks.isNotEmpty
                          ? wmsData.remarks.first.itemTypeRemark ?? ''
                          : '';
                      print(
                        'Setting remarksController.text: ${wmsData.remarks.first.itemTypeRemark ?? ''}',
                      );
                    }
                    print(
                      'WMS Screen: Loaded posted items: ${savedWmsItems.length} items',
                    );
                  });
                  print(
                    'WMS items updated from API: ${savedWmsItems.length} items',
                  );
                } else {
                  print(
                    'WMS Screen: Skipping API update due to unsaved changes',
                  );
                }
              } else {
                print('WMS category not found in loaded data');
              }
            } else if (state is AssetAuditError) {
              showCustomToast(context, state.message);
            } else if (state is AssetAuditPostSuccess) {
              // // Only show toast if this screen initiated the post action
              if (mounted &&
                  state.responses.any((response) => response.itemTypeId == 9)) {
                print("wms saved");
              }
              // Removed automatic API refresh to prevent screen vanishing
              // context.read<AssetAuditCubit>().getAssetAuditData(
              //   siteType: widget.siteType,
              //   auditSchId: widget.auditSchId,
              //   siteAuditSchId: widget.siteAuditSchId,
              // );
            } else if (state is AssetAuditPostError) {
              print('Error posting WMS data: ${state.message}');

              showCustomToast(
                context,
                'Error saving WMS data: ${state.message}',
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
                    "Do you want to cancel the Asset Audit for Site (ID: SITE-38974)?",
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
                  builder: (context) => UnsavedChangesDialog(
                    message:
                        "Do you want to cancel the Asset Audit for Site (ID: SITE-38974)?",
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
                                CustomFormField(
                                  label: "WMS Make",
                                  hintText: "Text",
                                  isRequired: true,
                                  initialValue:
                                      wmsCategoryData?.assets.isNotEmpty == true
                                      ? wmsCategoryData!.assets.first.oemName ?? "WMS"
                                      : "WMS",
                                  isEditable: false,
                                ),

                                getHeight(15),
                                CustomFormField(
                                  label: "Count of WMS",
                                  initialValue: totalWmsItems.toString(),
                                  isRequired: false,
                                  isEditable: false,
                                ),
                                getHeight(15),
                                Text(
                                  "WMS Details",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white,
                                    fontFamily: fontFamilyMontserrat,
                                  ),
                                ),
                                getHeight(3),
                                CustomInfoCard(
                                  key: ValueKey('wms_$wmsCardKey'),
                                  serialLabel: "WMS - Serial Number",
                                  serialHintText: "WMS Serial Number *",
                                  photoLabel: "Add a Photo",
                                  statusLabel: "Status",
                                  serialController: wmsSerialController,
                                  onSave: _saveWmsForm,
                                  isStatusEditable: true,
                                  backendStatus: false,
                                  remarksLabel: 'Capacity',
                                  remarksHintText:
                                      wmsCategoryData?.assets.isNotEmpty == true
                                      ? wmsCategoryData!.assets.first.capacity ?? "5 KW"
                                      : "5 KW",
                                  remarksController: null,
                                  isRemarksEditable: false,
                                  onPhotoTap: (photoPath) {
                                    setState(() {
                                      wmsPhoto = photoPath;
                                      hasUnsavedChanges = true;
                                    });
                                  },
                                  onStatusChanged: (val) {
                                    setState(() {
                                      wmsStatus = val ? "OK" : "Not OK";
                                      hasUnsavedChanges = true;
                                    });
                                  },
                                  onSerialChanged: (serialNumber) {
                                    setState(() {
                                      wmsSerialNumber = serialNumber;
                                      hasUnsavedChanges = true;
                                    });
                                  },
                                  initialStatus: wmsStatus == "OK"
                                      ? true
                                      : (wmsStatus == "Not OK" ? false : null),
                                  initialPhotoPath: wmsPhoto,
                                  isEditable: true,
                                ),
                                getHeight(8),
                                _buildWmsSavedItemsList(),
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
                                    'WMS',
                                isLeftArrow: true,
                                backgroundColor: AppColors.buttonColorBackBg,
                                textColor: AppColors.buttonColorTextBg,
                                onPressed: () {
                                  final previousScreen =
                                      AssetAuditNavigationHelper.getPreviousAvailableScreen(
                                        widget.assetAuditData,
                                        'WMS',
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
                                  final nextScreen = _getNextAvailableScreen();
                                  if (nextScreen == null) {
                                    return ArrowButton(
                                      text: "Submit",
                                      isLeftArrow: false,
                                      backgroundColor: AppColors.buttonColorBg,
                                      textColor: AppColors.buttonColorSite,
                                      onPressed: () async {
                                        await _postWMSData();
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
                                        print(
                                          '=== WMS Navigation to $nextScreen ===',
                                        );
                                        print(
                                          'Passing asset audit data: ${widget.assetAuditData != null}',
                                        );
                                        await _postWMSData();
                                        _navigateToNextScreen(
                                          context,
                                          nextScreen,
                                        );
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

  /// Setup get image listener
  void _setupGetImageListener() {
    _getImageSubscription = context
        .read<AssetAuditGetImageCubit>()
        .stream
        .listen((state) {
          if (state is AssetAuditGetImageSuccess) {
            setState(() {
              displayedImageBase64 = state.imageData;
              isLoadingImage = false;
            });
            print('=== WMS Get Image Success ===');
          } else if (state is AssetAuditGetImageFailure) {
            setState(() {
              isLoadingImage = false;
            });
            print('=== WMS Get Image Failed: ${state.errorMessage} ===');
          } else if (state is AssetAuditGetImageLoading) {
            setState(() {
              isLoadingImage = true;
            });
            print('=== WMS Get Image Loading ===');
          }
        });
  }

  /// Check if string is numeric
  bool _isNumeric(String str) {
    return double.tryParse(str) != null;
  }

  /// Upload WMS photo and return image ID
  Future<String?> _uploadWmsPhoto(File file) async {
    try {
      print('=== WMS Photo Upload Started ===');
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
              print('✅ WMS Photo upload SUCCESS!');
              print('Response imgId: ${state.response.imgId}');
              subscription.cancel();
              completer.complete(state.response.imgId);
            } else if (state is AssetAuditPhotoUploadFailure) {
              print('❌ WMS Photo upload FAILED!');
              print('Error message: ${state.errorMessage}');
              subscription.cancel();
              completer.completeError(state.errorMessage);
            } else {
              print('📤 WMS Photo upload in progress...');
            }
          },
        );

        print('Starting WMS photo upload...');
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
      print('❌ WMS Photo upload error: $e');
      rethrow;
    }
  }

  /// Post WMS data to API
  Future<void> _postWmsData() async {
    print('=== WMS Post Data Started ===');

    if (savedWmsItems.isEmpty && remarksController.text.trim().isEmpty) {
      print('WMS Screen: No data to post');
      return;
    }

    try {
      // Collect all items and remarks
      List<Map<String, dynamic>> allItemsToPost = [];

      // Add saved WMS items with proper structure
      for (var item in savedWmsItems) {
        Map<String, dynamic> formattedItem = {
          'serialNumber': item['serialNumber'],
          'photo': item['photo'],
          'status': item['status'],
          'photoTakenTs':
              item['timestamp']?.toString() ?? DateTime.now().toString(),
          'isQRCodeScanned': item['isQRCodeScanned'] ?? false,
          'localQrCodeScannedTs':
              item['timestamp']?.toString() ?? DateTime.now().toString(),
          'localCreatedDt':
              item['timestamp']?.toString() ?? DateTime.now().toString(),
          'localModifiedDt':
              item['timestamp']?.toString() ?? DateTime.now().toString(),
        };
        allItemsToPost.add(formattedItem);
      }

      // Add user remarks if any - use the correct structure for remarks
      if (remarksController.text.trim().isNotEmpty) {
        Map<String, dynamic> remarksData = {
          'recordType': 'remarks',
          'itemType': 'WMS',
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
        print(
          'WMS Screen: Added user remarks to post, text: "${remarksController.text.trim()}"',
        );
      }

      if (allItemsToPost.isEmpty) {
        print('WMS Screen: No items to post');
        return;
      }

      // Convert to POST request format
      final requests =
          await AssetAuditPostHelper.convertSavedItemsToPostRequest(
            savedItems: allItemsToPost,
            assetAuditData: widget.assetAuditData!,
            itemType: 'WMS',
            itemTypeId: 8,
            // WMS item type ID
            screenName: 'solar_wms',
            context: context,
            auditSchId: widget.auditSchId,
          );

      // Post data
      if (requests.isNotEmpty) {
        print('WMS Screen: Posting ${requests.length} requests');

        // Store the current remarks text before posting
        final currentRemarksText = remarksController.text;
        print(
          'WMS Screen: Storing current remarks text: "$currentRemarksText"',
        );

        context.read<AssetAuditCubit>().postAssetAuditData(requests: requests);

        // Refresh the data immediately after posting
        print('Refreshing WMS data after posting...');
        context.read<AssetAuditCubit>().getAssetAuditData(
          siteType: widget.siteType,
          auditSchId: widget.auditSchId,
          siteAuditSchId: widget.siteAuditSchId,
        );

        // Restore the remarks text after refresh to ensure it's not overwritten
        if (currentRemarksText.isNotEmpty) {
          print(
            'WMS Screen: Restoring remarks text after refresh: "$currentRemarksText"',
          );
          remarksController.text = currentRemarksText;
        }
      }

      print('WMS Screen: All data posted successfully');
    } catch (e) {
      print('WMS Screen: Error posting data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error posting data: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Get remarks asset audit site resp ID
  String? _getRemarksAssetAuditSiteRespId() {
    final wmsData = widget.assetAuditData?.responseData.categories['WMS'];
    if (wmsData != null && wmsData.remarks.isNotEmpty) {
      return wmsData.remarks.first.assetAuditSiteRespId.toString();
    }
    return null;
  }

  Widget _buildWmsSavedItemsList() {
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

              if (savedWmsItems.isNotEmpty) ...[
                ...savedWmsItems.map((item) {
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
                              color:
                                  item['photo'] != null &&
                                      item['photo'].isNotEmpty
                                  ? AppColors.color555555
                                  : Colors.grey,
                            ),
                            onPressed:
                                item['photo'] != null &&
                                    item['photo'].isNotEmpty
                                ? () {
                                    _showPhotoViewer(
                                      context,
                                      item['photo'],
                                      widget.siteAuditSchId,
                                    );
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
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// class _WMSScreenState extends State<WMSScreen> {
//   final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
//   final TextEditingController serialController = TextEditingController();
//   bool hasUnsavedChanges = false;
//   bool showValidationErrors = false;
//   // WMS field values
//   String? wmsSerialNumber;
//   String? wmsPhoto;
//   String? wmsStatus;
//   final remarksController = TextEditingController();
//   int wmsCardKey = 0;
//   List<Map<String, dynamic>> savedWmsItems = [];
//
//   // Controllers for CustomInfoCard
//   final TextEditingController wmsSerialController = TextEditingController();
//
//   // Get WMS data from API
//   int get totalWmsItems {
//     if (widget.assetAuditData?.responseData.categories['WMS']?.assets != null) {
//       return widget.assetAuditData!.responseData.categories['WMS']!.assets.length;
//     }
//     return 0;
//   }
//
//   // Get WMS category data
//   CategoryData? get wmsCategoryData {
//     return widget.assetAuditData?.responseData.categories['WMS'];
//   }
//
//   @override
//   void initState() {
//     super.initState();
//     serialController.addListener(_onFormChanged);
//   }
//
//   @override
//   void dispose() {
//     serialController.removeListener(_onFormChanged);
//     serialController.dispose();
//     wmsSerialController.dispose();
//     super.dispose();
//   }
//
//   void _onFormChanged() {
//     setState(() {
//       hasUnsavedChanges = serialController.text.isNotEmpty;
//
//       if (showValidationErrors && serialController.text.isNotEmpty) {
//         showValidationErrors = false;
//       }
//     });
//   }
//
//   Future<void> _saveAndExit() async {
//     Navigator.of(context).pop();
//     if (mounted) {
//       showDialog(
//         context: context,
//         barrierDismissible: false,
//         barrierColor: Colors.black54,
//         builder: (context) => SuccessDialog(
//           ticketId: "UVORKJR00044",
//           message:
//               "Asset Audit for Site (ID: SITE-38974) has been recorded and saved.",
//           onDone: () {
//             Navigator.of(context).pop();
//             Navigator.of(context).pop();
//           },
//         ),
//       );
//     }
//   }
//
//   bool _isFormValid() {
//     if (wmsSerialController.text.isEmpty) {
//       return false;
//     }
//
//     if (wmsPhoto == null || wmsPhoto!.isEmpty) {
//       return false;
//     }
//
//     return true;
//   }
//
//   bool _validateForm() {
//     setState(() {
//       showValidationErrors = true;
//     });
//
//     if (wmsSerialController.text.isEmpty) {
//       return false;
//     }
//
//     if (wmsPhoto == null || wmsPhoto!.isEmpty) {
//       return false;
//     }
//
//     return true;
//   }
//
//   void _saveWmsForm() {
//     if (savedWmsItems.length >= totalWmsItems) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text(
//             'Maximum number of WMS items ($totalWmsItems) already added.',
//             style: const TextStyle(
//               color: Colors.white,
//               fontSize: 14,
//               fontFamily: fontFamilyMontserrat,
//             ),
//           ),
//           backgroundColor: AppColors.errorColor,
//           duration: const Duration(seconds: 3),
//         ),
//       );
//       return;
//     }
//
//     if (_isFormValid()) {
//       setState(() {
//         Map<String, dynamic> currentFormData = {
//           'serialNumber': wmsSerialNumber,
//           'photo': wmsPhoto,
//           'status': wmsStatus ?? "OK",
//           'timestamp': DateTime.now(),
//         };
//
//         savedWmsItems.add(currentFormData);
//
//         wmsSerialNumber = null;
//         wmsPhoto = null;
//         wmsStatus = null;
//
//         wmsSerialController.clear();
//
//         wmsCardKey++;
//
//         hasUnsavedChanges = false;
//         showValidationErrors = false;
//       });
//
//       int remainingWms = totalWmsItems - savedWmsItems.length;
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text(
//             'WMS item saved successfully! ${remainingWms > 0 ? '(${remainingWms} remaining)' : '(All items added)'}',
//             style: const TextStyle(
//               color: Colors.white,
//               fontSize: 14,
//               fontFamily: fontFamilyMontserrat,
//             ),
//           ),
//           backgroundColor: AppColors.primaryGreen,
//           duration: const Duration(seconds: 2),
//         ),
//       );
//     }
//   }
//
//   String _formatSerialNumber(String serialNumber) {
//     if (serialNumber.length <= 7) {
//       return serialNumber;
//     }
//     return "${serialNumber.substring(0, 5)}...";
//   }
//
//   void _editItem(Map<String, dynamic> item) {
//     setState(() {
//       wmsSerialNumber = item["serialNumber"];
//       wmsPhoto = item["photo"];
//       wmsStatus = item["status"];
//
//       wmsSerialController.text = item["serialNumber"] ?? "";
//
//       savedWmsItems.remove(item);
//
//       hasUnsavedChanges = true;
//     });
//
//     setState(() {});
//
//     ScaffoldMessenger.of(context).showSnackBar(
//       const SnackBar(
//         content: Text(
//           'Item loaded for editing. Make changes and save again.',
//           style: TextStyle(
//             color: Colors.white,
//             fontSize: 14,
//             fontFamily: fontFamilyMontserrat,
//           ),
//         ),
//         backgroundColor: AppColors.primaryGreen,
//         duration: Duration(seconds: 2),
//       ),
//     );
//   }
//
//   // Helper method to get the next available screen based on data availability
//   String? _getNextAvailableScreen() {
//     return AssetAuditNavigationHelper.getNextAvailableScreen(widget.assetAuditData, 'WMS');
//   }
//
//   // Helper method to get the previous available screen based on data availability
//   String? _getPreviousAvailableScreen() {
//     return AssetAuditNavigationHelper.getPreviousAvailableScreen(widget.assetAuditData, 'WMS');
//   }
//
//   // Helper method to navigate to the next screen based on screen name
//   void _navigateToNextScreen(BuildContext context, String screenName) {
//     AssetAuditNavigationHelper.navigateToNextScreen(
//       context,
//       screenName,
//       '', // WMS screen doesn't have siteType parameter
//       '', // WMS screen doesn't have auditSchId parameter
//       '', // WMS screen doesn't have siteAuditSchId parameter
//       widget.assetAuditData,
//     );
//   }
//
//   // Helper method to check if a string is numeric (photo ID)
//   bool _isNumeric(String str) {
//     return int.tryParse(str) != null;
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return PopScope(
//       canPop: !hasUnsavedChanges,
//       onPopInvoked: (didPop) async {
//         if (didPop) return;
//
//         if (hasUnsavedChanges) {
//           showDialog(
//             context: context,
//             barrierDismissible: false,
//             builder: (context) => UnsavedChangesDialog(
//               message:
//               "Do you want to cancel the Asset Audit for Site (ID: SITE-38974) ?",
//               onSaveAndExit: () async {
//                 await _saveAndExit();
//               },
//               onDiscard: () {
//                 Navigator.of(context).pop();
//               },
//             ),
//           );
//         }
//       },
//       child: Scaffold(
//         extendBodyBehindAppBar: true,
//         resizeToAvoidBottomInset: false,
//         appBar: CustomFormAppbar(
//           title: "Asset Audit",
//           onClose: () async {
//             if (hasUnsavedChanges) {
//               showDialog(
//                 context: context,
//                 barrierDismissible: false,
//                 builder: (context) => UnsavedChangesDialog(
//                   message:
//                   "Do you want to cancel the Asset Audit for Site (ID: SITE-38974) ?",
//                   onSaveAndExit: () async {
//                     await _saveAndExit();
//                   },
//                   onDiscard: () {
//                     Navigator.of(context).pop();
//                   },
//                 ),
//               );
//             } else {
//               Navigator.pop(context);
//             }
//           },
//         ),
//         body: Stack(
//           children: [
//             Positioned.fill(
//               child: SvgPicture.asset(
//                 AppImages.home,
//                 fit: BoxFit.cover,
//                 width: double.infinity,
//                 height: double.infinity,
//               ),
//             ),
//             SafeArea(
//               child: Form(
//                 key: _formKey,
//                 child: Column(
//                   children: [
//                     Expanded(
//                       child: SingleChildScrollView(
//                         padding: EdgeInsets.only(
//                           bottom:
//                           MediaQuery.of(context).viewInsets.bottom + 120,
//                         ),
//                         child: Container(
//                           padding: const EdgeInsets.only(
//                             top: 20,
//                             left: 16,
//                             right: 16,
//                             bottom: 20,
//                           ),
//                           child: Column(
//                             crossAxisAlignment: CrossAxisAlignment.start,
//                             children: [
//                               CustomFormField(
//                                 label: "WMS Make",
//                                 hintText: "Text",
//                                 isRequired: true,
//                                 isEditable: false,
//                               ),
//                               getHeight(15),
//                               CustomFormField(
//                                 label: "Count of WMS",
//                                 initialValue: totalWmsItems.toString(),
//                                 isRequired: false,
//                                 isEditable: false,
//                               ),
//                               getHeight(15),
//                               Text(
//                                 "WMS Details",
//                                 style: TextStyle(
//                                   fontSize: 16,
//                                   fontWeight: FontWeight.w500,
//                                   color: Colors.white,
//                                   fontFamily: fontFamilyMontserrat,
//                                 ),
//                               ),
//                               getHeight(3),
//                               CustomInfoCard(
//                                 key: ValueKey('wms_$wmsCardKey'),
//                                 serialLabel: "WMS - Serial Number",
//                                 serialHintText: "WMS Serial Number *",
//                                 photoLabel: "Add a Photo",
//                                 statusLabel: "Status",
//                                 serialController: wmsSerialController,
//                                 onSave: _saveWmsForm,
//                                 isStatusEditable: true,
//                                 backendStatus: false,
//                                 remarksLabel: wmsCategoryData?.assets.isNotEmpty == true
//                                     ? wmsCategoryData!.assets.first.oemName ?? "WMS"
//                                     : "WMS",
//                                 remarksHintText: wmsCategoryData?.assets.isNotEmpty == true
//                                     ? wmsCategoryData!.assets.first.capacity ?? "5 KW"
//                                     : "5 KW",
//                                 onPhotoTap: (photoPath) {
//                                   setState(() {
//                                     wmsPhoto = photoPath;
//                                     hasUnsavedChanges = true;
//                                   });
//                                 },
//                                 onStatusChanged: (val) {
//                                   setState(() {
//                                     wmsStatus = val ? "OK" : "Not OK";
//                                     hasUnsavedChanges = true;
//                                   });
//                                 },
//                                 onSerialChanged: (serialNumber) {
//                                   setState(() {
//                                     wmsSerialNumber = serialNumber;
//                                     hasUnsavedChanges = true;
//                                   });
//                                 },
//                                 initialStatus: wmsStatus == "OK"
//                                     ? true
//                                     : (wmsStatus == "Not OK" ? false : null),
//                                 initialPhotoPath: wmsPhoto,
//                                 isEditable: true,
//                               ),
//                               getHeight(8),
//                               _buildWmsSavedItemsList(),
//                               getHeight(15),
//                               CustomRemarksField(
//                                 label: "Add Remarks",
//                                 hintText: "Remarks",
//                                 controller: remarksController,
//                               ),
//                               if (_validateForm())
//                                 Container(
//                                   width: double.infinity,
//                                   child: ElevatedButton(
//                                     onPressed: () {
//                                       showDialog(
//                                         context: context,
//                                         barrierDismissible: false,
//                                         builder: (context) => SuccessDialog(
//                                           ticketId: "UVORKJR00044",
//                                           message:
//                                           "Asset Audit for Site (ID: SITE-38974) has been recorded and saved.",
//                                           onDone: () {
//                                             Navigator.of(context).pop();
//                                             Navigator.of(context).pop();
//                                           },
//                                         ),
//                                       );
//                                     },
//                                     style: ElevatedButton.styleFrom(
//                                       backgroundColor: AppColors.primaryGreen,
//                                       padding: const EdgeInsets.symmetric(
//                                         vertical: 12,
//                                       ),
//                                       shape: RoundedRectangleBorder(
//                                         borderRadius: BorderRadius.circular(8),
//                                       ),
//                                     ),
//                                     child: const Text(
//                                       "Save",
//                                       style: TextStyle(
//                                         color: Colors.white,
//                                         fontSize: 16,
//                                         fontWeight: FontWeight.w600,
//                                         fontFamily: fontFamilyMontserrat,
//                                       ),
//                                     ),
//                                   ),
//                                 ),
//                             ],
//                           ),
//                         ),
//                       ),
//                     ),
//
//                     Container(
//                       padding: const EdgeInsets.all(16),
//                       width: double.infinity,
//                       child: Row(
//                         children: [
//                           Expanded(
//                             child: ArrowButton(
//                               text: "VCB",
//                               isLeftArrow: true,
//                               backgroundColor: AppColors.buttonColorBackBg,
//                               textColor: AppColors.buttonColorTextBg,
//                               onPressed: () {
//                                 Navigator.pop(context);
//                               },
//                             ),
//                           ),
//                           getWidth(14),
//                           Expanded(
//                             child: ArrowButton(
//                               text: "SCADA",
//                               isLeftArrow: false,
//                               backgroundColor: AppColors.buttonColorBg,
//                               textColor: AppColors.buttonColorSite,
//                               onPressed: () {
//                                 pushPage(context, SCADAScreen(
//                                   siteType: widget.siteType,
//                                   auditSchId: widget.auditSchId,
//                                   siteAuditSchId: widget.siteAuditSchId,
//                                   assetAuditData: widget.assetAuditData,
//                                 ));
//                               },
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildWmsSavedItemsList() {
//     return Column(
//       children: [
//         Container(
//           margin: const EdgeInsets.symmetric(vertical: 10),
//           padding: const EdgeInsets.all(16),
//           decoration: BoxDecoration(
//             color: AppColors.green7,
//             borderRadius: BorderRadius.circular(5),
//           ),
//           child: Column(
//             children: [
//               Row(
//                 children: [
//                   Expanded(
//                     child: Container(
//                       padding: const EdgeInsets.symmetric(horizontal: 4),
//                       child: const Text(
//                         "Serial No.",
//                         textAlign: TextAlign.center,
//                         style: TextStyle(
//                           color: Colors.white,
//                           fontSize: 14,
//                           fontFamily: fontFamilyMontserrat,
//                           fontWeight: FontWeight.w400,
//                         ),
//                         maxLines: 1,
//                         overflow: TextOverflow.ellipsis,
//                       ),
//                     ),
//                   ),
//                   Expanded(
//                     child: Container(
//                       padding: const EdgeInsets.symmetric(horizontal: 4),
//                       child: const Text(
//                         "Status",
//                         textAlign: TextAlign.center,
//                         style: TextStyle(
//                           color: Colors.white,
//                           fontSize: 14,
//                           fontFamily: fontFamilyMontserrat,
//                           fontWeight: FontWeight.w400,
//                         ),
//                         maxLines: 1,
//                         overflow: TextOverflow.ellipsis,
//                       ),
//                     ),
//                   ),
//                   Expanded(
//                     child: Container(
//                       padding: const EdgeInsets.symmetric(horizontal: 4),
//                       child: const Text(
//                         "Scanned",
//                         textAlign: TextAlign.center,
//                         style: TextStyle(
//                           color: Colors.white,
//                           fontSize: 14,
//                           fontFamily: fontFamilyMontserrat,
//                           fontWeight: FontWeight.w400,
//                         ),
//                         maxLines: 1,
//                         overflow: TextOverflow.ellipsis,
//                       ),
//                     ),
//                   ),
//                   Expanded(
//                     child: Container(
//                       padding: const EdgeInsets.symmetric(horizontal: 4),
//                       child: const Text(
//                         "Photo",
//                         textAlign: TextAlign.center,
//                         style: TextStyle(
//                           color: Colors.white,
//                           fontSize: 14,
//                           fontFamily: fontFamilyMontserrat,
//                           fontWeight: FontWeight.w400,
//                         ),
//                         maxLines: 1,
//                         overflow: TextOverflow.ellipsis,
//                       ),
//                     ),
//                   ),
//                   Expanded(
//                     child: Container(
//                       padding: const EdgeInsets.symmetric(horizontal: 4),
//                       child: const Text(
//                         "Edit",
//                         textAlign: TextAlign.center,
//                         style: TextStyle(
//                           color: Colors.white,
//                           fontSize: 14,
//                           fontFamily: fontFamilyMontserrat,
//                           fontWeight: FontWeight.w400,
//                         ),
//                         maxLines: 1,
//                         overflow: TextOverflow.ellipsis,
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//               const SizedBox(height: 8),
//
//               if (savedWmsItems.isNotEmpty) ...[
//                 ...savedWmsItems.map((item) {
//                   return Container(
//                     margin: const EdgeInsets.only(top: 8),
//                     padding: const EdgeInsets.symmetric(
//                       horizontal: 10,
//                       vertical: 4,
//                     ),
//                     decoration: BoxDecoration(
//                       color: AppColors.white,
//                       borderRadius: BorderRadius.circular(5),
//                     ),
//                     child: Row(
//                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                       children: [
//                         Expanded(
//                           child: Text(
//                             _formatSerialNumber(item["serialNumber"] ?? ""),
//                             style: const TextStyle(
//                               color: AppColors.color555555,
//                               fontSize: 14,
//                               fontFamily: fontFamilyMontserrat,
//                               fontWeight: FontWeight.w400,
//                             ),
//                           ),
//                         ),
//                         Expanded(
//                           child: Text(
//                             item["status"] ?? "",
//                             style: const TextStyle(
//                               color: AppColors.color555555,
//                               fontSize: 14,
//                               fontFamily: fontFamilyMontserrat,
//                               fontWeight: FontWeight.w400,
//                             ),
//                           ),
//                         ),
//                         const Expanded(
//                           child: Icon(Icons.check, color: Colors.green),
//                         ),
//                         Expanded(
//                           child: IconButton(
//                             icon: const Icon(
//                               Icons.camera_alt,
//                               color: AppColors.color555555,
//                             ),
//                             onPressed: () {
//                               // handle photo click
//                             },
//                           ),
//                         ),
//                         Expanded(
//                           child: IconButton(
//                             icon: const Icon(
//                               Icons.edit_calendar_outlined,
//                               color: AppColors.color555555,
//                             ),
//                             onPressed: () {
//                               _editItem(item);
//                             },
//                           ),
//                         ),
//                       ],
//                     ),
//                   );
//                 }).toList(),
//               ],
//             ],
//           ),
//         ),
//       ],
//     );
//   }
// }
