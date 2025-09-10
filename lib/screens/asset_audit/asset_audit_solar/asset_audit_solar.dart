import 'package:app/commonWidgets/custom_buttons/arrow_botton.dart';
import 'package:app/commonWidgets/custom_image_upload_field.dart';
import 'package:app/constants/constants_methods.dart';
import 'package:app/screens/asset_audit/asset_audit_solar/spv_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';
import 'dart:io';

import '../../../bloc/asset_audit_cubit.dart';
import '../../../bloc/asset_audit_state.dart';
import '../../../bloc/selfie_upload_cubit.dart';
import '../../../bloc/asset_audit_get_image_cubit.dart';
import '../../../commonWidgets/custom_dialogs/success_dialog.dart';
import '../../../commonWidgets/custom_dialogs/unsaved_changes_dialog.dart';
import '../../../commonWidgets/custom_dialogs/custom_dialog.dart';
import '../../../commonWidgets/custom_form_appbar.dart';
import '../../../commonWidgets/custom_form_field.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_images.dart';
import '../../../constants/constants_strings.dart';
import '../../../hive_local_database/hive_db.dart';
import '../../../utils/asset_audit_form_persistence_helper.dart';
import '../../../utils/asset_audit_post_helper.dart';
import '../../../models/asset_audit_model.dart';
import '../../../models/asset_audit_post_model.dart';

class AssetAuditSolarScreen extends StatefulWidget {
  final String siteType;
  final String auditSchId;
  final String siteAuditSchId;

  const AssetAuditSolarScreen({
    super.key,
    required this.siteType,
    required this.auditSchId,
    required this.siteAuditSchId,
  });

  @override
  State<AssetAuditSolarScreen> createState() =>
      _AssetAuditSolarScreenState();
}

class _AssetAuditSolarScreenState extends State<AssetAuditSolarScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController serialController = TextEditingController();
  String? selectedFile;
  String? selectedStatus;
  String? selectedBatteryStatus;
  String? selectedType;
  bool hasUnsavedChanges = false;
  bool showValidationErrors = false;
  int totalItemsToScan = 6;
  int currentScannedItems = 0;
  List<Map<String, dynamic>> savedItems = [];
  Map<String, dynamic> currentFormData = {};

  // AssetTypeCard field values
  String? assetCardSerialNumber;
  String? assetCardPhoto;
  String? assetCardStatus;

  // Track uploaded photo
  String? uploadedPhotoPath;
  String? uploadedImgId; // Store the uploaded image ID from API
  String? fetchedImageData;

  // Controllers for CustomInfoCard
  final TextEditingController cctvSerialController = TextEditingController();

  // Form data persistence
  bool _hasFormDataChanges = false;

  // Image queue for serial fetching
  List<Map<String, String>> _imageQueue = [];
  bool _fetchingImage = false;
  String? _lastRequestedPhotoId;
  Map<String, int> _retryCounts = {};

  @override
  void initState() {
    super.initState();
    // Listen to form changes
    serialController.addListener(_onFormChanged);
    cctvSerialController.addListener(_onFormChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    print('=== didChangeDependencies called ===');

    // Only call getAssetAuditData if not already loaded
    final currentState = context.read<AssetAuditCubit>().state;
    if (currentState is! AssetAuditLoaded) {
      print('=== Calling getAssetAuditData from didChangeDependencies ===');
      context.read<AssetAuditCubit>().getAssetAuditData(
        siteType: widget.siteType,
        auditSchId: widget.auditSchId,
        siteAuditSchId: widget.siteAuditSchId,
      );
    } else {
      print('=== AssetAuditData already loaded, skipping getAssetAuditData call ===');
    }

    AssetAuditFormPersistenceHelper.ensureHiveBoxReady().then((_) {
      _loadStoredSelfie();
      _checkPageHeaderForSelfie();
    });
  }

  @override
  void dispose() {
    serialController.removeListener(_onFormChanged);
    cctvSerialController.removeListener(_onFormChanged);
    serialController.dispose();
    cctvSerialController.dispose();
    super.dispose();
  }

  void _onFormChanged() {
    setState(() {
      final hasLocalPhoto = uploadedPhotoPath != null && uploadedPhotoPath!.isNotEmpty;
      final hasServerImage = uploadedImgId != null && uploadedImgId!.isNotEmpty && uploadedImgId != "0";
      final hasImageData = fetchedImageData != null && fetchedImageData!.isNotEmpty;

      hasUnsavedChanges = selectedFile != null ||
          selectedStatus != null ||
          selectedBatteryStatus != null ||
          selectedType != null ||
          serialController.text.isNotEmpty ||
          cctvSerialController.text.isNotEmpty ||
          hasLocalPhoto ||
          hasServerImage ||
          hasImageData;

      _hasFormDataChanges = true;

      if (showValidationErrors && (hasLocalPhoto || hasServerImage || hasImageData)) {
        showValidationErrors = false;
      }
    });
  }

  void _saveFormDataToHive() {
    if (!_hasFormDataChanges) return;

    final Map<String, dynamic> formData = {
      'uploadedPhotoPath': uploadedPhotoPath,
      'uploadedImgId': uploadedImgId,
      'selectedFile': selectedFile,
      'selectedStatus': selectedStatus,
      'selectedBatteryStatus': selectedBatteryStatus,
      'selectedType': selectedType,
      'serialController': serialController.text,
      'cctvSerialController': cctvSerialController.text,
      'assetCardSerialNumber': assetCardSerialNumber,
      'assetCardPhoto': assetCardPhoto,
      'assetCardStatus': assetCardStatus,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    AssetAuditFormPersistenceHelper.saveFormData(
      siteAuditSchId: widget.siteAuditSchId,
      screenName: 'solar_page_1',
      formData: formData,
    );
    _hasFormDataChanges = false;
  }

  void _checkPageHeaderForSelfie() {
    final assetAuditState = context.read<AssetAuditCubit>().state;
    if (assetAuditState is AssetAuditLoaded && assetAuditState.assetAuditData.pageHeader.isNotEmpty) {
      final pageHeader = assetAuditState.assetAuditData.pageHeader.first;
      print('makerSelfieImageId: ${pageHeader.makerSelfieImageId}');

      if (pageHeader.makerSelfieImageId != null && pageHeader.makerSelfieImageId! > 0) {
        setState(() {
          uploadedImgId = pageHeader.makerSelfieImageId.toString();
          fetchedImageData = null;
        });

        _imageQueue.add({'photoId': pageHeader.makerSelfieImageId.toString(), 'key': 'selfie'});
        _fetchNextImage();
      }
    } else {
      print('assetAuditState type: ${assetAuditState.runtimeType}');
      if (assetAuditState is AssetAuditLoaded) {
        print('pageHeader length: ${assetAuditState.assetAuditData.pageHeader.length}');
      }
    }
  }

  void _loadStoredSelfie() async {
    final formData = await AssetAuditFormPersistenceHelper.loadFormData(
      siteAuditSchId: widget.siteAuditSchId,
      screenName: 'solar_page_1',
    );

    if (formData != null) {
      setState(() {
        uploadedImgId = formData['uploadedImgId'];
        uploadedPhotoPath = formData['uploadedPhotoPath'];
        selectedFile = formData['selectedFile'];
        selectedStatus = formData['selectedStatus'];
        selectedBatteryStatus = formData['selectedBatteryStatus'];
        selectedType = formData['selectedType'];
        if (formData['serialController'] != null) {
          serialController.text = formData['serialController'];
        }
        if (formData['cctvSerialController'] != null) {
          cctvSerialController.text = formData['cctvSerialController'];
        }
        assetCardSerialNumber = formData['assetCardSerialNumber'];
        assetCardPhoto = formData['assetCardPhoto'];
        assetCardStatus = formData['assetCardStatus'];
      });

      if (formData['uploadedImgId'] != null && formData['uploadedImgId'].toString().isNotEmpty) {
        final storedSelfie = HiveDB.getAssetAuditSelfie(widget.siteAuditSchId);
        if (storedSelfie != null && storedSelfie['imageData'] != null && storedSelfie['imageData'].toString().isNotEmpty) {
          setState(() {
            fetchedImageData = storedSelfie['imageData'] as String?;
          });
        } else {
          _imageQueue.add({'photoId': formData['uploadedImgId'].toString(), 'key': 'selfie'});
          _fetchNextImage();
        }
      }
    } else {
      final storedSelfie = HiveDB.getAssetAuditSelfie(widget.siteAuditSchId);
      if (storedSelfie != null) {
        if (storedSelfie['imageData'] != null && storedSelfie['imageData'].toString().isNotEmpty) {
          setState(() {
            uploadedImgId = storedSelfie['imageId'] as String?;
            fetchedImageData = storedSelfie['imageData'] as String?;
            uploadedPhotoPath = null;
          });
        } else if (storedSelfie['imageId'] != null && storedSelfie['imageId'].toString().isNotEmpty) {
          setState(() {
            uploadedImgId = storedSelfie['imageId'] as String?;
          });
          _imageQueue.add({'photoId': storedSelfie['imageId'].toString(), 'key': 'selfie'});
          _fetchNextImage();
        }
      }
    }

    // Check immediately for fallback image fetch
    if (uploadedImgId != null && uploadedImgId!.isNotEmpty && uploadedImgId != "0" && fetchedImageData == null) {
      print('Fallback: Re-fetching image for selfie, photoId: $uploadedImgId');
      _imageQueue.add({'photoId': uploadedImgId!, 'key': 'selfie'});
      _fetchNextImage();
    }
  }

  void _fetchNextImage() {
    if (_fetchingImage || _imageQueue.isEmpty) return;

    _fetchingImage = true;

    final image = _imageQueue.removeAt(0);
    final photoId = image['photoId']!;
    final key = image['key']!;

    print('Loading image for photoId: $photoId, key: $key, retry count: ${_retryCounts[photoId] ?? 0}');
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
      print('Retrying image load for photoId: $photoId, key: $key, attempt: ${_retryCounts[photoId]} of $maxRetries');
      await Future.delayed(retryDelay);
      _imageQueue.insert(0, {'photoId': photoId, 'key': key});
      _fetchNextImage();
    } else {
      print('Max retries reached for photoId: $photoId, key: $key');
      _retryCounts.remove(photoId);
    }
  }

  void _saveAndExit() async {
    _saveFormDataToHive();
    Navigator.of(context).pop();
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.black54,
        builder: (context) => SuccessDialog(
          ticketId: "UVORKJR00044",
          message:
              "Asset Audit for Site (ID: SITE-38974) has been recorded and saved.",
          onDone: () {
            Navigator.of(context).pop();
            Navigator.of(context).pop();
          },
        ),
      );
    }
  }


  bool _validateForm() {
    setState(() {
      showValidationErrors = true;
    });

    print('=== Form Validation Debug (_validateForm) ===');
    print('uploadedPhotoPath: $uploadedPhotoPath');
    print('uploadedImgId: $uploadedImgId');
    print('fetchedImageData: ${fetchedImageData != null ? 'present' : 'null'}');
    
    final hasLocalPhoto = uploadedPhotoPath != null && uploadedPhotoPath!.isNotEmpty;
    final hasServerImage = uploadedImgId != null && uploadedImgId!.isNotEmpty && uploadedImgId != "0";
    final hasImageData = fetchedImageData != null && fetchedImageData!.isNotEmpty;
    
    if (!hasLocalPhoto && !hasServerImage && !hasImageData) {
      print('Photo validation failed - No photo uploaded');
      return false;
    } else {
      print('Photo validation passed');
    }

    print('All validations passed!');
    return true;
  }


  void _uploadSelfie(File file) {
    final assetAuditState = context.read<AssetAuditCubit>().state;
    if (assetAuditState is AssetAuditLoaded &&
        assetAuditState.assetAuditData.pageHeader.isNotEmpty) {
      final schId = assetAuditState
          .assetAuditData
          .pageHeader
          .first
          .siteAuditSchId
          .toString();
      final imgIdToUse = uploadedImgId != null && uploadedImgId!.isNotEmpty ? uploadedImgId! : "0";

      _hasFormDataChanges = true;
      context.read<SelfieUploadCubit>().uploadSelfie(
        file: file,
        imgId: imgIdToUse,
        schId: schId,
      );
    } else {
      showCustomToast(context, 'Please wait for site data to load before uploading selfie');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<AssetAuditCubit, AssetAuditState>(
          listener: (context, state) {
            if (state is AssetAuditError) {
              showCustomToast(context, state.message);
            } else if (state is AssetAuditPostSuccess) {
              print('Asset audit data posted successfully: ${state.responses.length} responses');
            } else if (state is AssetAuditPostError) {
              print('Error posting asset audit data: ${state.message}');
            }
          },
        ),
        BlocListener<SelfieUploadCubit, SelfieUploadState>(
          listener: (context, state) {
            if (state is SelfieUploadSuccess) {
              setState(() {
                uploadedImgId = state.response.imgId;
                _hasFormDataChanges = true;
              });

              showCustomToast(context, 'Selfie uploaded successfully!');
            } else if (state is SelfieUploadFailure) {
              showCustomToast(context, state.errorMessage);
            }
          },
        ),
        BlocListener<AssetAuditGetImageCubit, AssetAuditGetImageState>(
          listener: (context, state) async {
            if (state is AssetAuditGetImageSuccess) {
              print('Image loaded for photoId: $_lastRequestedPhotoId, data length: ${state.imageData.length}');
              final assetAuditState = context.read<AssetAuditCubit>().state;
              if (assetAuditState is AssetAuditLoaded && assetAuditState.assetAuditData.pageHeader.isNotEmpty) {
                final schId = assetAuditState.assetAuditData.pageHeader.first.siteAuditSchId.toString();
                final isUpdate = uploadedImgId != null && uploadedImgId!.isNotEmpty && uploadedImgId != "0";
                final pageHeader = assetAuditState.assetAuditData.pageHeader.first;
                final isFromPageHeader = pageHeader.makerSelfieImageId != null && pageHeader.makerSelfieImageId.toString() == _lastRequestedPhotoId;

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
                  print('Empty image data received for photoId: $_lastRequestedPhotoId');
                  await _handleImageLoadRetry(_lastRequestedPhotoId ?? '', 'selfie');
                }
              } else {
                print('AssetAuditCubit state is not AssetAuditLoaded or pageHeader is empty');
                _fetchingImage = false;
                _fetchNextImage();
              }
            } else if (state is AssetAuditGetImageFailure) {
              print('Failed to load image for photoId: $_lastRequestedPhotoId, error: ${state.errorMessage}');
              await _handleImageLoadRetry(_lastRequestedPhotoId ?? '', 'selfie');
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
              resizeToAvoidBottomInset: true,
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
                                bottom: MediaQuery.of(context).viewInsets.bottom + 100,
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
                                    BlocBuilder<AssetAuditCubit, AssetAuditState>(
                                      builder: (context, state) {
                                        if (state is AssetAuditLoaded && state.assetAuditData.pageHeader.isNotEmpty) {
                                          final pageHeader = state.assetAuditData.pageHeader.first;
                                          return Column(
                                            children: [
                                              CustomFormField(
                                                label: "State (Solar)",
                                                initialValue: pageHeader.solarState ?? "N/A",
                                                isRequired: false,
                                                isEditable: false,
                                              ),
                                              getHeight(15),
                                              CustomFormField(
                                                label: "District (Solar)",
                                                initialValue: pageHeader.solarDistrict ?? "N/A",
                                                isRequired: false,
                                                isEditable: false,
                                              ),
                                              getHeight(15),
                                              CustomFormField(
                                                label: "District",
                                                initialValue: pageHeader.district ?? "N/A",
                                                isRequired: false,
                                                isEditable: false,
                                              ),
                                              getHeight(15),
                                              CustomFormField(
                                                label: "Customer",
                                                initialValue: pageHeader.clientName,
                                                isRequired: false,
                                                isEditable: false,
                                              ),
                                              getHeight(15),
                                              CustomFormField(
                                                label: "Site Code",
                                                initialValue: pageHeader.siteCode,
                                                isRequired: false,
                                                isEditable: false,
                                              ),
                                              getHeight(15),
                                              CustomFormField(
                                                label: "Site Name",
                                                initialValue: pageHeader.siteName,
                                                isRequired: false,
                                                isEditable: false,
                                              ),
                                              getHeight(15),
                                              CustomFormField(
                                                label: "Site Type",
                                                initialValue: pageHeader.siteTypeName,
                                                isRequired: false,
                                                isEditable: false,
                                              ),
                                              getHeight(15),
                                              CustomFormField(
                                                label: "Audit Due Date",
                                                initialValue: pageHeader.auditDueDt ?? "N/A",
                                                isRequired: false,
                                                isEditable: false,
                                              ),
                                              getHeight(15),
                                              CustomFormField(
                                                label: "Status",
                                                initialValue: pageHeader.status ?? "N/A",
                                                isRequired: false,
                                                isEditable: false,
                                              ),
                                            ],
                                          );
                                        } else {
                                          return Column(
                                            children: [
                                              CustomFormField(
                                                label: "State (Solar)",
                                                initialValue: "Loading...",
                                                isRequired: false,
                                                isEditable: false,
                                              ),
                                              getHeight(15),
                                              CustomFormField(
                                                label: "District (Solar)",
                                                initialValue: "Loading...",
                                                isRequired: false,
                                                isEditable: false,
                                              ),
                                              getHeight(15),
                                              CustomFormField(
                                                label: "District",
                                                initialValue: "Loading...",
                                                isRequired: false,
                                                isEditable: false,
                                              ),
                                              getHeight(15),
                                              CustomFormField(
                                                label: "Customer",
                                                initialValue: "Loading...",
                                                isRequired: false,
                                                isEditable: false,
                                              ),
                                              getHeight(15),
                                              CustomFormField(
                                                label: "Site Code",
                                                initialValue: "Loading...",
                                                isRequired: false,
                                                isEditable: false,
                                              ),
                                              getHeight(15),
                                              CustomFormField(
                                                label: "Site Name",
                                                initialValue: "Loading...",
                                                isRequired: false,
                                                isEditable: false,
                                              ),
                                              getHeight(15),
                                              CustomFormField(
                                                label: "Site Type",
                                                initialValue: "Loading...",
                                                isRequired: false,
                                                isEditable: false,
                                              ),
                                              getHeight(15),
                                              CustomFormField(
                                                label: "Audit Due Date",
                                                initialValue: "Loading...",
                                                isRequired: false,
                                                isEditable: false,
                                              ),
                                              getHeight(15),
                                              CustomFormField(
                                                label: "Status",
                                                initialValue: "Loading...",
                                                isRequired: false,
                                                isEditable: false,
                                              ),
                                            ],
                                          );
                                        }
                                      },
                                    ),
                                    getHeight(15),
                                    ImageUploadField(
                                      label: "Add a Selfie",
                                      placeholder: "Selfie",
                                      isRequired: true,
                                      externalImageUrl: fetchedImageData,
                                      onImageSelected: (file) {
                                        if (file != null) {
                                          debugPrint(
                                            "Selected image path: ${file.path}",
                                          );
                                          setState(() {
                                            uploadedPhotoPath = file.path;
                                            hasUnsavedChanges = true;
                                          });

                                          // Upload selfie to server
                                          _uploadSelfie(file);
                                        } else {
                                          setState(() {
                                            uploadedPhotoPath = null;
                                            uploadedImgId = null;
                                            fetchedImageData = null;
                                          });
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          // Bottom button container
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.transparent,
                            ),
                            child: ArrowButton(
                              text: "SPV",
                              isLeftArrow: false,
                              backgroundColor: AppColors.buttonColorBg,
                              textColor: AppColors.buttonColorSite,
                              onPressed: () async {
                                print('SPV button pressed');
                                if (_validateForm()) {
                                  _saveFormDataToHive();
                                  
                                  // Pass ALL asset audit data to SPV screen
                                  final assetAuditState = context.read<AssetAuditCubit>().state;
                                  AssetAuditModel? assetAuditData;
                                  if (assetAuditState is AssetAuditLoaded) {
                                    assetAuditData = assetAuditState.assetAuditData;
                                    print('=== Main Screen: Passing asset audit data to SPV ===');
                                    print('Asset audit data available: ${assetAuditData != null}');
                                    if (assetAuditData != null) {
                                      print('Categories available: ${assetAuditData.responseData.categories.keys.toList()}');
                                      final spvCategory = assetAuditData.responseData.categories['SPV'];
                                      if (spvCategory != null) {
                                        print('SPV category found with ${spvCategory.assets.length} assets');
                                        if (spvCategory.assets.isNotEmpty) {
                                          print('First SPV asset: ${spvCategory.assets.first.oemName}');
                                        }
                                      } else {
                                        print('SPV category NOT found!');
                                      }
                                    }
                                  }
                                  
                                  pushPage(context, SPVScreen(
                                    siteType: widget.siteType,
                                    auditSchId: widget.auditSchId,
                                    siteAuditSchId: widget.siteAuditSchId,
                                    assetAuditData: assetAuditData,
                                  ));
                                } else {
                                  showCustomToast(context, 'Please upload a selfie photo to continue');
                                }
                                // if (_validateForm()) {
                                //   // Get the site data from the asset audit state
                                //   final assetAuditState = context
                                //       .read<AssetAuditCubit>()
                                //       .state;
                                //   if (assetAuditState is AssetAuditLoaded &&
                                //       assetAuditState
                                //           .assetAuditData
                                //           .pageHeader
                                //           .isNotEmpty) {
                                //     final siteData = assetAuditState
                                //         .assetAuditData
                                //         .pageHeader
                                //         .first;
                                //     pushPage(
                                //       context,
                                //
                                //       // SiteInfoScreen(
                                //       //   siteName: siteData.siteName,
                                //       //   siteTypeName: siteData.siteTypeName,
                                //       //   indoorOutdoor: siteData.indoorOutdoor,
                                //       //   ebNonEb: siteData.ebNonEb,
                                //       //   op1Name: siteData.op1Name,
                                //       //   op2Name: siteData.op2Name ?? "N/A",
                                //       // ),
                                //     );
                                //   } else {
                                //     // Fallback with empty values if data is not loaded
                                //     pushPage(
                                //       context,
                                //         SPVScreen()
                                //       // SiteInfoScreen(
                                //       //   siteName: "N/A",
                                //       //   siteTypeName: "N/A",
                                //       //   indoorOutdoor: "N/A",
                                //       //   ebNonEb: "N/A",
                                //       //   op1Name: "N/A",
                                //       //   op2Name: "N/A",
                                //       // ),
                                //     );
                                //   }
                                // } else {
                                //   SPVScreen();
                                //   ScaffoldMessenger.of(context).showSnackBar(
                                //     SnackBar(
                                //       content: Text(
                                //         uploadedPhotoPath == null ||
                                //             uploadedPhotoPath!.isEmpty
                                //             ? 'Please upload a selfie photo to continue'
                                //             : 'Please fill in all required fields',
                                //         style: const TextStyle(
                                //           color: Colors.white,
                                //           fontSize: 14,
                                //           fontFamily: fontFamilyMontserrat,
                                //         ),
                                //       ),
                                //       backgroundColor: AppColors.errorColor,
                                //       duration: const Duration(seconds: 3),
                                //     ),
                                //   );
                                // }
                              },
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
}
