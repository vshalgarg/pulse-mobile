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

class VCBScreen extends StatefulWidget {
  final String siteType;
  final String auditSchId;
  final String siteAuditSchId;
  final AssetAuditModel? assetAuditData;

  const VCBScreen({
    super.key,
    required this.siteType,
    required this.auditSchId,
    required this.siteAuditSchId,
    this.assetAuditData, // Complete asset audit data
  });

  @override
  State<VCBScreen> createState() => _VCBScreenState();
}

class _VCBScreenState extends State<VCBScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController serialController = TextEditingController();
  bool hasUnsavedChanges = false;
  bool showValidationErrors = false;
  String? vcbSerialNumber;
  String? vcbPhoto;
  String? vcbStatus;
  final remarksController = TextEditingController();
  int vcbCardKey = 0;
  List<Map<String, dynamic>> savedVcbItems = [];
  bool isQRCodeScanned = false;

  String? uploadedPhotoId;
  String? displayedImageBase64;
  bool isUploadingPhoto = false;
  bool isLoadingImage = false;
  StreamSubscription? _photoUploadSubscription;
  StreamSubscription? _getImageSubscription;
  StreamSubscription? _assetAuditSubscription;
  
  // Image caching for faster loading
  Map<String, String> _imageCache = {};
  
  // Image loading tracking to prevent repeated processing
  String? _currentRequestedImageId;
  bool _isRequestingImage = false;

  final TextEditingController vcbSerialController = TextEditingController();

  int get totalVcbItems {
    if (widget.assetAuditData?.responseData.categories['VCB']?.assets != null) {
      return widget.assetAuditData!.responseData.categories['VCB']!.assets.length;
    }
    return 0;
  }

  CategoryData? get vcbCategoryData {
    return widget.assetAuditData?.responseData.categories['VCB'];
  }

  @override
  void initState() {
    super.initState();
    serialController.addListener(_onFormChanged);
    vcbSerialController.addListener(_onFormChanged);
    remarksController.addListener(_onFormChanged);
    _setupPhotoUploadListener();
    _setupGetImageListener();
    _setupAssetAuditListener();
  }

  @override
  void dispose() {
    serialController.removeListener(_onFormChanged);
    vcbSerialController.removeListener(_onFormChanged);
    remarksController.removeListener(_onFormChanged);
    serialController.dispose();
    vcbSerialController.dispose();
    remarksController.dispose();
    _photoUploadSubscription?.cancel();
    _getImageSubscription?.cancel();
    _assetAuditSubscription?.cancel();
    super.dispose();
  }

  void _setupAssetAuditListener() {
    _assetAuditSubscription = context.read<AssetAuditCubit>().stream.listen((state) {
      if (state is AssetAuditLoaded) {
        setState(() {
          final vcbData = state.assetAuditData.responseData.categories['VCB'];
          if (vcbData != null) {
            // Load items that have been successfully posted to API AND have user interaction
            // (either photo taken or serial number entered - regardless of QR scan or manual entry)
            final postedItems = vcbData.assets.where((asset) => 
              asset.assetAuditSiteRespId != null && 
              asset.photoId != null
            ).map((asset) {
              return {
                'serialNumber': asset.mfgSerialNo ?? asset.nexgenSerialNo ?? '',
                'photo': asset.photoId?.toString(),
                'status': asset.assetStatus ?? 'OK',
                'timestamp': DateTime.now(),
                'isQRCodeScanned': asset.qrCodeScanned ?? false,
                'assetAuditSiteRespId': asset.assetAuditSiteRespId,
              };
            }).toList();
            
            // Update savedVcbItems with posted items
            savedVcbItems = postedItems;
            
            // Only load remarks from API if user hasn't made changes
            if (remarksController.text.isEmpty) {
              remarksController.text = vcbData.remarks.isNotEmpty
                  ? vcbData.remarks.first.itemTypeRemark ?? ''
                  : '';
              print('VCB Screen: Loaded remarks from API: "${remarksController.text}"');
            }
            print('VCB Screen: Loaded posted items: ${savedVcbItems.length} items');
          }
        });
      } else if (state is AssetAuditError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading updated data: ${state.message}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    });
  }

  void _onFormChanged() {
    setState(() {
      final hasLocalPhoto = vcbPhoto != null && vcbPhoto!.isNotEmpty;
      final hasImageData = displayedImageBase64 != null && displayedImageBase64!.isNotEmpty;

      hasUnsavedChanges = serialController.text.isNotEmpty ||
          vcbSerialController.text.isNotEmpty ||
          hasLocalPhoto ||
          hasImageData ||
          savedVcbItems.isNotEmpty ||
          remarksController.text.isNotEmpty;

      if (showValidationErrors && (serialController.text.isNotEmpty || vcbSerialController.text.isNotEmpty)) {
        showValidationErrors = false;
      }
    });
  }

  void _saveAndExit() async {
    try {
      showDialog(context: context, barrierDismissible: false, builder: (context) => const Center(child: CircularProgressIndicator()));
      await _postVcbData();
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
    if (vcbSerialController.text.isEmpty) {
      return false;
    }

    if (vcbPhoto == null || vcbPhoto!.isEmpty) {
      return false;
    }

    return true;
  }

  bool _validateForm() {
    setState(() {
      showValidationErrors = true;
    });

    if (vcbSerialController.text.isEmpty) {
      return false;
    }

    if (vcbPhoto == null || vcbPhoto!.isEmpty) {
      return false;
    }

    return true;
  }

  void _saveVcbForm() async {
    if (savedVcbItems.length >= totalVcbItems) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Maximum number of VCB items ($totalVcbItems) already added.',
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
      String? photoImageId = vcbPhoto;

      if (vcbPhoto != null && vcbPhoto!.isNotEmpty && !vcbPhoto!.startsWith('http') && !_isNumeric(vcbPhoto!)) {
        try {
          final file = File(vcbPhoto!);
          if (await file.exists()) {
            photoImageId = await _uploadVcbPhoto(file);
          }
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error uploading photo: $e'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
      }

      setState(() {
        Map<String, dynamic> currentFormData = {
          'serialNumber': vcbSerialNumber,
          'photo': photoImageId,
          'status': vcbStatus ?? "OK",
          'timestamp': DateTime.now(),
          'isQRCodeScanned': isQRCodeScanned,
        };

        savedVcbItems.add(currentFormData);

        vcbSerialNumber = null;
        vcbPhoto = null;
        vcbStatus = null;
        isQRCodeScanned = false;
        displayedImageBase64 = null;

        vcbSerialController.clear();

        vcbCardKey++;

        hasUnsavedChanges = false;
        showValidationErrors = false;
      });

      int remainingVcb = totalVcbItems - savedVcbItems.length;
    }
  }

  String _formatSerialNumber(String serialNumber) {
    if (serialNumber.length <= 7) {
      return serialNumber;
    }
    return "${serialNumber.substring(0, 5)}...";
  }


  void _setupPhotoUploadListener() {
    _photoUploadSubscription = context.read<AssetAuditPhotoUploadCubit>().stream.listen((state) {
      if (state is AssetAuditPhotoUploadSuccess) {
        setState(() {
          uploadedPhotoId = state.response.imgId;
          vcbPhoto = state.response.imgId;
          isUploadingPhoto = false;
        });
      } else if (state is AssetAuditPhotoUploadFailure) {
        setState(() {
          isUploadingPhoto = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Photo upload failed: ${state.errorMessage}'),
            backgroundColor: Colors.red,
          ),
        );
      } else if (state is AssetAuditPhotoUploadLoading) {
        setState(() {
          isUploadingPhoto = true;
        });
      }
    });
  }

  void _setupGetImageListener() {
    _getImageSubscription = context.read<AssetAuditGetImageCubit>().stream.listen((state) {
      // Only handle images for the main form, not for saved items
      // This listener should only be triggered when editing an item from the main form
      if (state is AssetAuditGetImageSuccess && 
          _isRequestingImage && 
          _currentRequestedImageId != null) {
        // Cache the image for future use
        _imageCache[_currentRequestedImageId!] = state.imageData;
        
        setState(() {
          displayedImageBase64 = state.imageData;
          isLoadingImage = false;
          _isRequestingImage = false;
          _currentRequestedImageId = null;
        });
        print('VCB: Image cached for photoId: $_currentRequestedImageId');
      } else if (state is AssetAuditGetImageFailure && _isRequestingImage) {
        setState(() {
          displayedImageBase64 = null;
          isLoadingImage = false;
          _isRequestingImage = false;
          _currentRequestedImageId = null;
        });
      } else if (state is AssetAuditGetImageLoading && _isRequestingImage) {
        setState(() {
          isLoadingImage = true;
        });
      }
    });
  }

  bool _isNumeric(String str) {
    return double.tryParse(str) != null;
  }

  Future<String?> _uploadVcbPhoto(File file) async {
    try {
      final assetAuditState = context.read<AssetAuditCubit>().state;
      if (assetAuditState is AssetAuditLoaded && assetAuditState.assetAuditData.pageHeader.isNotEmpty) {
        final schId = assetAuditState.assetAuditData.pageHeader.first.siteAuditSchId.toString();
        final imgIdToUse = "0";

        final completer = Completer<String?>();

        late StreamSubscription subscription;
        subscription = context.read<AssetAuditPhotoUploadCubit>().stream.listen((state) {
          if (state is AssetAuditPhotoUploadSuccess) {
            subscription.cancel();
            completer.complete(state.response.imgId);
          } else if (state is AssetAuditPhotoUploadFailure) {
            subscription.cancel();
            completer.completeError(Exception(state.errorMessage));
          }
        });

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
      rethrow;
    }
  }


  Future<void> _postVcbData() async {
    if (savedVcbItems.isEmpty && remarksController.text.trim().isEmpty) {
      return;
    }

    try {
      final assetAuditState = context.read<AssetAuditCubit>().state;
      if (assetAuditState is AssetAuditLoaded && assetAuditState.assetAuditData.pageHeader.isNotEmpty) {
        List<Map<String, dynamic>> allItemsToPost = [];

        if (savedVcbItems.isNotEmpty) {
          final enhancedItems = AssetAuditPostHelper.enhanceSavedItems(
            savedItems: savedVcbItems,
            screenName: 'solar_vcb',
          );
          allItemsToPost.addAll(enhancedItems);
        }

        if (remarksController.text.trim().isNotEmpty) {
          String? remarksAssetAuditSiteRespId = _getRemarksAssetAuditSiteRespId();
          if (remarksAssetAuditSiteRespId != null) {
            Map<String, dynamic> remarksData = {
              'itemType': 'VCB',
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
          itemType: 'VCB',
          itemTypeId: 5,
          screenName: 'solar_vcb',
          context: context,
          auditSchId: widget.auditSchId,
        );

        if (requests.isNotEmpty) {
          // Store the current remarks text before posting
          final currentRemarksText = remarksController.text;
          print('VCB Screen: Storing current remarks text: "$currentRemarksText"');
          
          await context.read<AssetAuditCubit>().postAssetAuditData(requests: requests);
          
          // Refresh the data immediately after posting
          print('Refreshing VCB data after posting...');
          context.read<AssetAuditCubit>().getAssetAuditData(
            siteType: widget.siteType,
            auditSchId: widget.auditSchId,
            siteAuditSchId: widget.siteAuditSchId,
          );
          
          // Restore the remarks text after refresh to ensure it's not overwritten
          if (currentRemarksText.isNotEmpty) {
            print('VCB Screen: Restoring remarks text after refresh: "$currentRemarksText"');
            remarksController.text = currentRemarksText;
          }
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error posting VCB data: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _editItem(Map<String, dynamic> item) {
    setState(() {
      vcbSerialNumber = item['serialNumber'];
      vcbPhoto = item['photo'];
      vcbStatus = item['status'];
      isQRCodeScanned = item['isQRCodeScanned'] ?? false;
      vcbSerialController.text = item['serialNumber'] ?? '';
      savedVcbItems.remove(item);
      hasUnsavedChanges = true;
      vcbCardKey++;
    });

    // Load image with caching for faster loading
    if (vcbPhoto != null && vcbPhoto!.isNotEmpty && _isNumeric(vcbPhoto!)) {
      // Check if image is already cached
      if (_imageCache.containsKey(vcbPhoto!)) {
        setState(() {
          displayedImageBase64 = _imageCache[vcbPhoto!];
          isLoadingImage = false;
        });
        print('VCB: Using cached image for photoId: $vcbPhoto');
      } else {
        // Load from API if not cached
        setState(() {
          _currentRequestedImageId = vcbPhoto;
          _isRequestingImage = true;
          displayedImageBase64 = null;
          isLoadingImage = true;
        });
        
        print('VCB: Loading image from API for photoId: $vcbPhoto');
        context.read<AssetAuditGetImageCubit>().getImage(
          imgId: vcbPhoto!,
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

  String? _getRemarksAssetAuditSiteRespId() {
    final vcbData = widget.assetAuditData?.responseData.categories['VCB'];
    if (vcbData != null && vcbData.remarks.isNotEmpty) {
      return vcbData.remarks.first.assetAuditSiteRespId.toString();
    }
    return null;
  }

  // Navigation helper methods
  String? _getNextAvailableScreen() {
    return AssetAuditNavigationHelper.getNextAvailableScreen(widget.assetAuditData, 'VCB');
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
    return BlocBuilder<AssetAuditCubit, AssetAuditState>(
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
                  message: "Do you want to cancel the Asset Audit for Site (ID: SITE-38974) ?",
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
                      message: "Do you want to cancel the Asset Audit for Site (ID: SITE-38974) ?",
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
                                    label: "VCB Type",
                                    hintText: "Text",
                                    isRequired: true,
                                    isEditable: false,
                                  ),
                                  getHeight(15),
                                  CustomFormField(
                                    label: "Count of VCB",
                                    initialValue: totalVcbItems.toString(),
                                    isRequired: false,
                                    isEditable: false,
                                  ),
                                  getHeight(15),
                                  Text(
                                    "VCB Details",
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white,
                                      fontFamily: fontFamilyMontserrat,
                                    ),
                                  ),
                                  getHeight(3),
                                  CustomInfoCard(
                                    key: ValueKey('vcb_$vcbCardKey'),
                                    serialLabel: "VCB - Serial Number",
                                    serialHintText: "VCB Serial Number *",
                                    photoLabel: "Add a Photo",
                                    statusLabel: "Status",
                                    serialController: vcbSerialController,
                                    onSave: _saveVcbForm,
                                    isStatusEditable: true,
                                    backendStatus: false,
                                    remarksLabel: vcbCategoryData?.assets.isNotEmpty == true
                                        ? vcbCategoryData!.assets.first.itemType ?? "VCB"
                                        : "VCB",
                                    remarksHintText: vcbCategoryData?.assets.isNotEmpty == true
                                        ? vcbCategoryData!.assets.first.capacity ?? ""
                                        : "5",
                                    remarksController: null,
                                    isRemarksEditable: false,
                                    onPhotoTap: (photoPath) {
                                      setState(() {
                                        vcbPhoto = photoPath;
                                        displayedImageBase64 = null;
                                        hasUnsavedChanges = true;
                                      });
                                    },
                                    onStatusChanged: (val) {
                                      setState(() {
                                        vcbStatus = val ? "OK" : "Not OK";
                                        hasUnsavedChanges = true;
                                      });
                                    },
                                    onSerialChanged: (serialNumber) {
                                      setState(() {
                                        vcbSerialNumber = serialNumber;
                                        isQRCodeScanned = false;
                                        hasUnsavedChanges = true;
                                      });
                                    },
                                    initialStatus: vcbStatus == "OK"
                                        ? true
                                        : (vcbStatus == "Not OK" ? false : null),
                                    initialPhotoPath: vcbPhoto ?? displayedImageBase64,
                                    isEditable: true,
                                  ),
                                  getHeight(8),
                                  _buildVcbSavedItemsList(),
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
                                  text: AssetAuditNavigationHelper.getSolarPreviousScreenName('VCB'),
                                  isLeftArrow: true,
                                  backgroundColor: AppColors.buttonColorBackBg,
                                  textColor: AppColors.buttonColorTextBg,
                                  onPressed: () {
                                    final previousScreen = AssetAuditNavigationHelper.getPreviousAvailableScreen(widget.assetAuditData, 'VCB');
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
                                          await _postVcbData();
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
                                          print('=== VCB Navigation to $nextScreen ===');
                                          print('Passing asset audit data: ${widget.assetAuditData != null}');
                                          await _postVcbData();
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
        );
      },
    );
  }

  Widget _buildVcbSavedItemsList() {
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
              if (savedVcbItems.isNotEmpty) ...[
                ...savedVcbItems.map((item) {
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
                              // Handle photo click
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

// class _VCBScreenState extends State<VCBScreen> {
//   final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
//   final TextEditingController serialController = TextEditingController();
//   bool hasUnsavedChanges = false;
//   bool showValidationErrors = false;
//   // VCB field values
//   String? vcbSerialNumber;
//   String? vcbPhoto;
//   String? vcbStatus;
//   final remarksController = TextEditingController();
//   int vcbCardKey = 0;
//   List<Map<String, dynamic>> savedVcbItems = [];
//   bool isQRCodeScanned = false; // Track if serial was scanned or manually entered
//
//   // API integration fields
//   String? uploadedPhotoId;
//   String? displayedImageBase64;
//   bool isUploadingPhoto = false;
//   bool isLoadingImage = false;
//   StreamSubscription? _photoUploadSubscription;
//   StreamSubscription? _getImageSubscription;
//
//   // Controllers for CustomInfoCard
//   final TextEditingController vcbSerialController = TextEditingController();
//
//   // Get VCB data from API
//   int get totalVcbItems {
//     if (widget.assetAuditData?.responseData.categories['VCB']?.assets != null) {
//       return widget.assetAuditData!.responseData.categories['VCB']!.assets.length;
//     }
//     return 0;
//   }
//
//   // Get VCB category data
//   CategoryData? get vcbCategoryData {
//     return widget.assetAuditData?.responseData.categories['VCB'];
//   }
//
//   @override
//   void initState() {
//     super.initState();
//     serialController.addListener(_onFormChanged);
//     _setupPhotoUploadListener();
//     _setupGetImageListener();
//   }
//
//   @override
//   void dispose() {
//     serialController.removeListener(_onFormChanged);
//     serialController.dispose();
//     vcbSerialController.dispose();
//     _photoUploadSubscription?.cancel();
//     _getImageSubscription?.cancel();
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
//   void _saveAndExit() async {
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
//     if (vcbSerialController.text.isEmpty) {
//       return false;
//     }
//
//     if (vcbPhoto == null || vcbPhoto!.isEmpty) {
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
//     if (vcbSerialController.text.isEmpty) {
//       return false;
//     }
//
//     if (vcbPhoto == null || vcbPhoto!.isEmpty) {
//       return false;
//     }
//
//     return true;
//   }
//
//   void _saveVcbForm() async {
//     if (savedVcbItems.length >= totalVcbItems) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text(
//             'Maximum number of VCB items ($totalVcbItems) already added.',
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
//       String? photoImageId = vcbPhoto;
//
//       // If photo is a file path, upload it and get image ID
//       if (vcbPhoto != null && vcbPhoto!.isNotEmpty && !vcbPhoto!.startsWith('http')) {
//         try {
//           final file = File(vcbPhoto!);
//           if (await file.exists()) {
//             print('📤 Uploading VCB photo: ${vcbPhoto}');
//             photoImageId = await _uploadVcbPhoto(file);
//             print('✅ VCB photo uploaded successfully, image ID: $photoImageId');
//           } else {
//             print('❌ VCB photo file does not exist: ${vcbPhoto}');
//           }
//         } catch (e) {
//           print('❌ Error uploading VCB photo: $e');
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(
//               content: Text('Error uploading photo: $e'),
//               backgroundColor: Colors.red,
//             ),
//           );
//           return;
//         }
//       } else {
//         print('ℹ️ No VCB photo to upload or already has image ID');
//       }
//
//       setState(() {
//         Map<String, dynamic> currentFormData = {
//           'serialNumber': vcbSerialNumber,
//           'photo': photoImageId, // Use image ID instead of file path
//           'status': vcbStatus ?? "OK",
//           'timestamp': DateTime.now(),
//           'isQRCodeScanned': isQRCodeScanned, // Store whether it was scanned or manual
//         };
//
//         savedVcbItems.add(currentFormData);
//
//         vcbSerialNumber = null;
//         vcbPhoto = null;
//         vcbStatus = null;
//         isQRCodeScanned = false;
//
//         vcbSerialController.clear();
//
//         vcbCardKey++;
//
//         hasUnsavedChanges = false;
//         showValidationErrors = false;
//       });
//
//       int remainingVcb = totalVcbItems - savedVcbItems.length;
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text(
//             'VCB item saved successfully! ${remainingVcb > 0 ? '(${remainingVcb} remaining)' : '(All items added)'}',
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
//       vcbSerialNumber = item["serialNumber"];
//       vcbPhoto = item["photo"];
//       vcbStatus = item["status"];
//       isQRCodeScanned = item["isQRCodeScanned"] ?? false; // Restore QR scan status
//
//       vcbSerialController.text = item["serialNumber"] ?? "";
//
//       savedVcbItems.remove(item);
//
//       hasUnsavedChanges = true;
//
//       // Force rebuild of the CustomInfoCard to show restored values
//       vcbCardKey++;
//     });
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
//
//     // If the photo is a photo ID (numeric), fetch the image from API
//     if (vcbPhoto != null && vcbPhoto!.isNotEmpty && _isNumeric(vcbPhoto!)) {
//       print('=== VCB Edit: Fetching image for photo ID: $vcbPhoto ===');
//       context.read<AssetAuditGetImageCubit>().getImage(
//         imgId: vcbPhoto!,
//         schId: widget.siteAuditSchId,
//       );
//     }
//   }
//
//   /// Setup photo upload listener
//   void _setupPhotoUploadListener() {
//     _photoUploadSubscription = context.read<AssetAuditPhotoUploadCubit>().stream.listen((state) {
//       if (state is AssetAuditPhotoUploadSuccess) {
//         setState(() {
//           uploadedPhotoId = state.response.imgId;
//           vcbPhoto = state.response.imgId; // Update VCB photo with image ID
//           isUploadingPhoto = false;
//         });
//         print('=== VCB Photo Upload Success: ${state.response.imgId} ===');
//       } else if (state is AssetAuditPhotoUploadFailure) {
//         setState(() {
//           isUploadingPhoto = false;
//         });
//         print('=== VCB Photo Upload Failed: ${state.errorMessage} ===');
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('Photo upload failed: ${state.errorMessage}'),
//             backgroundColor: Colors.red,
//           ),
//         );
//       } else if (state is AssetAuditPhotoUploadLoading) {
//         setState(() {
//           isUploadingPhoto = true;
//         });
//         print('=== VCB Photo Upload Loading ===');
//       }
//     });
//   }
//
//   /// Setup get image listener
//   void _setupGetImageListener() {
//     _getImageSubscription = context.read<AssetAuditGetImageCubit>().stream.listen((state) {
//       if (state is AssetAuditGetImageSuccess) {
//         setState(() {
//           displayedImageBase64 = state.imageData;
//           isLoadingImage = false;
//         });
//         print('=== VCB Get Image Success ===');
//       } else if (state is AssetAuditGetImageFailure) {
//         setState(() {
//           isLoadingImage = false;
//         });
//         print('=== VCB Get Image Failed: ${state.errorMessage} ===');
//       } else if (state is AssetAuditGetImageLoading) {
//         setState(() {
//           isLoadingImage = true;
//         });
//         print('=== VCB Get Image Loading ===');
//       }
//     });
//   }
//
//   /// Check if string is numeric
//   bool _isNumeric(String str) {
//     return double.tryParse(str) != null;
//   }
//
//   /// Upload VCB photo and return image ID
//   Future<String?> _uploadVcbPhoto(File file) async {
//     try {
//       print('=== VCB Photo Upload Started ===');
//       print('File path: ${file.path}');
//       print('File exists: ${await file.exists()}');
//       print('File size: ${await file.length()} bytes');
//
//       final assetAuditState = context.read<AssetAuditCubit>().state;
//       if (assetAuditState is AssetAuditLoaded && assetAuditState.assetAuditData.pageHeader.isNotEmpty) {
//         final schId = assetAuditState.assetAuditData.pageHeader.first.siteAuditSchId.toString();
//         print('Site Audit Sch ID: $schId');
//
//         final imgIdToUse = "0";
//         print('Image ID to use: $imgIdToUse');
//
//         final completer = Completer<String?>();
//
//         late StreamSubscription subscription;
//         subscription = context.read<AssetAuditPhotoUploadCubit>().stream.listen((state) {
//           print('=== AssetAuditPhotoUploadCubit State Changed ===');
//           print('State type: ${state.runtimeType}');
//
//           if (state is AssetAuditPhotoUploadSuccess) {
//             print('✅ VCB Photo upload successful: ${state.response.imgId}');
//             subscription.cancel();
//             completer.complete(state.response.imgId);
//           } else if (state is AssetAuditPhotoUploadFailure) {
//             print('❌ VCB Photo upload failed: ${state.errorMessage}');
//             subscription.cancel();
//             completer.completeError(Exception(state.errorMessage));
//           } else if (state is AssetAuditPhotoUploadLoading) {
//             print('📤 VCB Photo upload in progress...');
//           }
//         });
//
//         print('Starting VCB photo upload...');
//         context.read<AssetAuditPhotoUploadCubit>().uploadPhoto(
//           file: file,
//           imgId: imgIdToUse,
//           schId: schId,
//         );
//
//         return await completer.future;
//       } else {
//         throw Exception('Asset audit data not available');
//       }
//     } catch (e) {
//       print('❌ VCB Photo upload error: $e');
//       rethrow;
//     }
//   }
//
//   /// Post VCB data to API
//   Future<void> _postVcbData() async {
//     print('=== VCB Post Data Started ===');
//
//     if (savedVcbItems.isEmpty && remarksController.text.trim().isEmpty) {
//       print('VCB Screen: No data to post');
//       return;
//     }
//
//     try {
//       // Collect all items and remarks
//       List<Map<String, dynamic>> allItemsToPost = [];
//
//       // Add saved VCB items with proper structure
//       for (var item in savedVcbItems) {
//         Map<String, dynamic> formattedItem = {
//           'serialNumber': item['serialNumber'],
//           'photo': item['photo'],
//           'status': item['status'],
//           'photoTakenTs': item['timestamp']?.toString() ?? DateTime.now().toString(),
//           'isQRCodeScanned': item['isQRCodeScanned'] ?? false,
//           'localQrCodeScannedTs': item['timestamp']?.toString() ?? DateTime.now().toString(),
//           'localCreatedDt': item['timestamp']?.toString() ?? DateTime.now().toString(),
//           'localModifiedDt': item['timestamp']?.toString() ?? DateTime.now().toString(),
//         };
//         allItemsToPost.add(formattedItem);
//       }
//
//       // Add user remarks if any - use the correct structure for remarks
//       if (remarksController.text.trim().isNotEmpty) {
//         Map<String, dynamic> remarksData = {
//           'recordType': 'remarks',
//           'itemType': 'VCB',
//           'remarks': remarksController.text.trim(),
//           'status': 'OK',
//           'serialNumber': 'REMARKS',
//           'photo': null,
//           'photoTakenTs': DateTime.now().toString(),
//           'isQRCodeScanned': false,
//           'localQrCodeScannedTs': DateTime.now().toString(),
//           'localCreatedDt': DateTime.now().toString(),
//           'localModifiedDt': DateTime.now().toString(),
//         };
//         allItemsToPost.add(remarksData);
//         print('VCB Screen: Added user remarks to post, text: "${remarksController.text.trim()}"');
//       }
//
//       if (allItemsToPost.isEmpty) {
//         print('VCB Screen: No items to post');
//         return;
//       }
//
//       // Convert to POST request format
//       final requests = await AssetAuditPostHelper.convertSavedItemsToPostRequest(
//         savedItems: allItemsToPost,
//         assetAuditData: widget.assetAuditData!,
//         itemType: 'VCB',
//         itemTypeId: 5, // VCB item type ID
//         screenName: 'solar_vcb',
//         context: context,
//         auditSchId: widget.auditSchId,
//       );
//
//       // Post data
//       if (requests.isNotEmpty) {
//         print('VCB Screen: Posting ${requests.length} requests');
//         context.read<AssetAuditCubit>().postAssetAuditData(requests: requests);
//       }
//
//       print('VCB Screen: All data posted successfully');
//     } catch (e) {
//       print('VCB Screen: Error posting data: $e');
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('Error posting data: $e'),
//           backgroundColor: Colors.red,
//         ),
//       );
//     }
//   }
//
//   /// Get remarks asset audit site resp ID
//   String? _getRemarksAssetAuditSiteRespId() {
//     final vcbData = widget.assetAuditData?.responseData.categories['VCB'];
//     if (vcbData != null && vcbData.remarks.isNotEmpty) {
//       return vcbData.remarks.first.assetAuditSiteRespId.toString();
//     }
//     return null;
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
//               onSaveAndExit: () {
//                 _saveAndExit();
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
//                   onSaveAndExit: () {
//                     _saveAndExit();
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
//                                 label: "VCB Type",
//                                 hintText: "Text",
//                                 isRequired: true,
//                                 isEditable: false,
//                               ),
//                               getHeight(15),
//                               CustomFormField(
//                                 label: "Count of VCB",
//                                 initialValue: totalVcbItems.toString(),
//                                 isRequired: false,
//                                 isEditable: false,
//                               ),
//                               getHeight(15),
//                               Text(
//                                 "VCB Details",
//                                 style: TextStyle(
//                                   fontSize: 16,
//                                   fontWeight: FontWeight.w500,
//                                   color: Colors.white,
//                                   fontFamily: fontFamilyMontserrat,
//                                 ),
//                               ),
//                               getHeight(3),
//                               CustomInfoCard(
//                                 key: ValueKey('vcb_$vcbCardKey'),
//                                 serialLabel: "VCB - Serial Number",
//                                 serialHintText: "VCB Serial Number *",
//                                 photoLabel: "Add a Photo",
//                                 statusLabel: "Status",
//                                 serialController: vcbSerialController,
//                                 onSave: _saveVcbForm,
//                                 isStatusEditable: true,
//                                 backendStatus: false,
//                                 remarksLabel: vcbCategoryData?.assets.isNotEmpty == true
//                                     ? vcbCategoryData!.assets.first.itemType ?? "VCB"
//                                     : "VCB",
//                                 remarksHintText: vcbCategoryData?.assets.isNotEmpty == true
//                                     ? vcbCategoryData!.assets.first.capacity ?? ""
//                                     : "5",
//                                 remarksController: null,
//                                 isRemarksEditable: false,
//                                 onPhotoTap: (photoPath) {
//                                   setState(() {
//                                     vcbPhoto = photoPath;
//                                     hasUnsavedChanges = true;
//                                   });
//                                 },
//                                 onStatusChanged: (val) {
//                                   setState(() {
//                                     vcbStatus = val ? "OK" : "Not OK";
//                                     hasUnsavedChanges = true;
//                                   });
//                                 },
//                                 onSerialChanged: (serialNumber) {
//                                   setState(() {
//                                     vcbSerialNumber = serialNumber;
//                                     isQRCodeScanned = false; // Manual entry
//                                     hasUnsavedChanges = true;
//                                   });
//                                 },
//                                 initialStatus: vcbStatus == "OK"
//                                     ? true
//                                     : (vcbStatus == "Not OK" ? false : null),
//                                 initialPhotoPath: displayedImageBase64 != null ? displayedImageBase64 : vcbPhoto,
//                                 isEditable: true,
//                               ),
//                               getHeight(8),
//                               _buildVcbSavedItemsList(),
//                               getHeight(15),
//                               CustomRemarksField(
//                                 label: "Add Remarks",
//                                 hintText: "Remarks",
//                                 controller: remarksController,
//                               ),
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
//                               text: "SPV",
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
//                               text: "WMS",
//                               isLeftArrow: false,
//                               backgroundColor: AppColors.buttonColorBg,
//                               textColor: AppColors.buttonColorSite,
//                               onPressed: () async {
//                                 await _postVcbData();
//                                 pushPage(context, WMSScreen(
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
//   Widget _buildVcbSavedItemsList() {
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
//               if (savedVcbItems.isNotEmpty) ...[
//                 ...savedVcbItems.map((item) {
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
//                         Expanded(
//                           child: Icon(
//                             item['isQRCodeScanned'] == true
//                               ? Icons.qr_code_scanner
//                               : Icons.close,
//                             color: item['isQRCodeScanned'] == true
//                               ? Colors.blue
//                               : Colors.red,
//                           ),
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
