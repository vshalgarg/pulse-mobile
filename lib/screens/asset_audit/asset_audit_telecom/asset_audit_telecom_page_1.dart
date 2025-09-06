import 'package:app/commonWidgets/custom_buttons/arrow_botton.dart';
import 'package:app/commonWidgets/custom_image_upload_field.dart';
import 'package:app/constants/constants_methods.dart';
import 'package:app/screens/asset_audit/asset_audit_telecom/site_info_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';
import 'dart:io';

import '../../../bloc/asset_audit_cubit.dart';
import '../../../bloc/asset_audit_state.dart';
import '../../../bloc/selfie_upload_cubit.dart';
import '../../../bloc/asset_audit_get_image_cubit.dart';
import '../../../commonWidgets/custom_dialogs/success_dialog.dart';
import '../../../hive_local_database/hive_db.dart';
import '../../../utils/asset_audit_form_persistence_helper.dart';
import '../../../commonWidgets/custom_dialogs/unsaved_changes_dialog.dart';
import '../../../commonWidgets/custom_dialogs/custom_dialog.dart';
import '../../../commonWidgets/custom_form_appbar.dart';
import '../../../commonWidgets/custom_form_field.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_images.dart';
import '../../../models/asset_audit_model.dart';

class AssetAuditTelecomScreen extends StatefulWidget {
  final String siteType;
  final String auditSchId;
  final String siteAuditSchId;

  const AssetAuditTelecomScreen({
    super.key,
    required this.siteType,
    required this.auditSchId,
    required this.siteAuditSchId,
  });

  @override
  State<AssetAuditTelecomScreen> createState() =>
      _AssetAuditTelecomScreenState();
}


class _AssetAuditTelecomScreenState extends State<AssetAuditTelecomScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController serialController = TextEditingController();
  final TextEditingController cctvSerialController = TextEditingController();
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
  String? uploadedImgId;
  String? fetchedImageData;

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
    serialController.addListener(_onFormChanged);
    cctvSerialController.addListener(_onFormChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    print('=== didChangeDependencies called ===');

    context.read<AssetAuditCubit>().getAssetAuditData(
      siteType: widget.siteType,
      auditSchId: widget.auditSchId,
      siteAuditSchId: widget.siteAuditSchId,
    );

    AssetAuditFormPersistenceHelper.ensureHiveBoxReady().then((_) {
      _loadStoredSelfie();
      _checkPageHeaderForSelfie();
    });
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
      screenName: 'telecom_page_1',
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
      screenName: 'telecom_page_1',
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

    Future.delayed(const Duration(seconds: 5), () {
      if (uploadedImgId != null && uploadedImgId!.isNotEmpty && uploadedImgId != "0" && fetchedImageData == null) {
        print('Fallback: Re-fetching image for selfie, photoId: $uploadedImgId');
        _imageQueue.add({'photoId': uploadedImgId!, 'key': 'selfie'});
        _fetchNextImage();
      }
    });
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

  void _uploadSelfie(File file) {
    final assetAuditState = context.read<AssetAuditCubit>().state;
    if (assetAuditState is AssetAuditLoaded && assetAuditState.assetAuditData.pageHeader.isNotEmpty) {
      final schId = assetAuditState.assetAuditData.pageHeader.first.siteAuditSchId.toString();
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

  void _saveAndExit() async {
    _saveFormDataToHive();
    Navigator.of(context).pop();
    await Future.delayed(const Duration(milliseconds: 200));
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.black54,
        builder: (context) => SuccessDialog(
          ticketId: "UVORKJR00044",
          message: "Asset Audit for Site (ID: SITE-38974) has been recorded and saved.",
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
    print('fetchedImageData length: ${fetchedImageData?.length ?? 0}');

    final hasLocalPhoto = uploadedPhotoPath != null && uploadedPhotoPath!.isNotEmpty;
    final hasServerImage = uploadedImgId != null && uploadedImgId!.isNotEmpty && uploadedImgId != "0";
    final hasImageData = fetchedImageData != null && fetchedImageData!.isNotEmpty;

    if (hasLocalPhoto || hasServerImage || hasImageData) {
      print('Photo validation passed - has image available');
      return true;
    } else {
      print('Photo validation failed - no image available');
      return false;
    }
  }

  @override
  void dispose() {
    serialController.removeListener(_onFormChanged);
    cctvSerialController.removeListener(_onFormChanged);
    serialController.dispose();
    cctvSerialController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<SelfieUploadCubit, SelfieUploadState>(
          listener: (context, state) {
            if (state is SelfieUploadSuccess) {
              final assetAuditState = context.read<AssetAuditCubit>().state;
              if (assetAuditState is AssetAuditLoaded && assetAuditState.assetAuditData.pageHeader.isNotEmpty) {
                final schId = assetAuditState.assetAuditData.pageHeader.first.siteAuditSchId.toString();

                setState(() {
                  uploadedImgId = state.response.imgId;
                  _hasFormDataChanges = true;
                });

                if (state.response.imgId.isNotEmpty) {
                  HiveDB.saveAssetAuditSelfie(
                    siteAuditSchId: schId,
                    imageId: state.response.imgId,
                    imageData: '',
                  );
                  context.read<AssetAuditCubit>().updatePageHeaderSelfieImageId(state.response.imgId);
                  _imageQueue.add({'photoId': state.response.imgId, 'key': 'selfie'});
                  _fetchNextImage();
                }

                final isUpdate = uploadedImgId != null && uploadedImgId!.isNotEmpty && uploadedImgId != "0";
                showCustomToast(context, isUpdate ? 'Selfie updated successfully!' : 'Selfie uploaded successfully!');
              }
            } else if (state is SelfieUploadFailure) {
              showCustomToast(context, '${state.errorMessage}');
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

                  showCustomToast(
                    context,
                    isFromPageHeader
                        ? 'Existing selfie image loaded from server! You can replace it by uploading a new photo.'
                        : isUpdate
                        ? 'Image updated and saved successfully!'
                        : 'Image fetched and saved successfully!',
                  );
                } else {
                  print('Empty imageData for photoId: $_lastRequestedPhotoId');
                  await _handleImageLoadRetry(_lastRequestedPhotoId!, 'selfie');
                }
              }
              _lastRequestedPhotoId = null;
            } else if (state is AssetAuditGetImageFailure) {
              print('Image load failed for photoId: $_lastRequestedPhotoId, error: ${state.errorMessage}');
              showCustomToast(context, 'Failed to fetch image: ${state.errorMessage}');
              if (_lastRequestedPhotoId != null) {
                await _handleImageLoadRetry(_lastRequestedPhotoId!, 'selfie');
              }
              _lastRequestedPhotoId = null;
            }
            _fetchingImage = false;
            _fetchNextImage();
          },
        ),
        BlocListener<AssetAuditCubit, AssetAuditState>(
          listener: (context, state) {
            if (state is AssetAuditError) {
              if (state.message.contains('NO_SITE_AUDIT_SCHEDULE:')) {
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => CustomAlertDialog(
                    title: 'No Site Audit Schedule Found',
                    subTitle1: 'This ticket does not have an asset audit schedule created yet.',
                    subTitle2: 'Please contact your administrator to create the asset audit schedule before proceeding with the audit.',
                    buttonText1: 'Go Back',
                    buttonText2: 'Retry',
                    onButtonPressed1: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).pop();
                    },
                    onButtonPressed2: () {
                      Navigator.of(context).pop();
                      context.read<AssetAuditCubit>().getAssetAuditData(
                        siteType: widget.siteType,
                        auditSchId: widget.auditSchId,
                        siteAuditSchId: widget.siteAuditSchId,
                      );
                    },
                    isSuccess: false,
                  ),
                );
              } else {
                showCustomToast(context, ' ${state.message}');
              }
            }
          },
        ),
      ],
      child: BlocBuilder<AssetAuditCubit, AssetAuditState>(
        builder: (context, state) {
          if (state is AssetAuditLoading) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen));
          }
          return buildContent(context, state);
        },
      ),
    );
  }

  Widget buildContent(BuildContext context, AssetAuditState state) {
    var pageHeader = <PageHeader>[];
    if (state is AssetAuditLoaded) {
      pageHeader = state.assetAuditData.pageHeader;
    }

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
              onSaveAndExit: _saveAndExit,
              onDiscard: () {
                Navigator.of(context).pop();
              },
            ),
          );
        }
      },
      child: Scaffold(
        extendBodyBehindAppBar: true,
        resizeToAvoidBottomInset: true, // Allow resizing for keyboard
        appBar: CustomFormAppbar(
          title: "Asset Audit",
          onClose: () async {
            if (hasUnsavedChanges) {
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => UnsavedChangesDialog(
                  message: "Do you want to cancel the Asset Audit for Site (ID: SITE-38974) ?",
                  onSaveAndExit: _saveAndExit,
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
              child: SvgPicture.asset(AppImages.home, fit: BoxFit.cover),
            ),
            SafeArea(
              bottom: false, // Allow content to extend to bottom for button
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CustomFormField(
                              label: "Circle",
                              initialValue: pageHeader.isNotEmpty ? pageHeader.first.circle : "N/A",
                              isRequired: false,
                              isEditable: false,
                            ),
                            getHeight(15),
                            CustomFormField(
                              label: "Cluster",
                              initialValue: pageHeader.isNotEmpty ? pageHeader.first.cluster : "N/A",
                              isRequired: false,
                              isEditable: false,
                            ),
                            getHeight(15),
                            CustomFormField(
                              label: "District",
                              initialValue: pageHeader.isNotEmpty ? pageHeader.first.district ?? "N/A" : "N/A",
                              isRequired: false,
                              isEditable: false,
                            ),
                            getHeight(15),
                            CustomFormField(
                              label: "Customer",
                              initialValue: pageHeader.isNotEmpty ? pageHeader.first.clientName : "N/A",
                              isRequired: false,
                              isEditable: false,
                            ),
                            getHeight(15),
                            CustomFormField(
                              label: "Site Id",
                              initialValue: pageHeader.isNotEmpty ? pageHeader.first.siteCode : "N/A",
                              isRequired: false,
                              isEditable: false,
                            ),
                            getHeight(15),
                            CustomFormField(
                              label: "Site Name",
                              initialValue: pageHeader.isNotEmpty ? pageHeader.first.siteName : "N/A",
                              isRequired: false,
                              isEditable: false,
                            ),
                            getHeight(15),
                            BlocBuilder<AssetAuditCubit, AssetAuditState>(
                              builder: (context, state) {
                                if (state is AssetAuditLoaded && fetchedImageData == null) {
                                  WidgetsBinding.instance.addPostFrameCallback((_) {
                                    if (uploadedImgId == null || uploadedImgId!.isEmpty || uploadedImgId == "0") {
                                      _loadStoredSelfie();
                                    }
                                  });
                                }
                                return ImageUploadField(
                                  label: "Add a Selfie",
                                  placeholder: "Selfie",
                                  isRequired: true,
                                  externalImageUrl: fetchedImageData,
                                  onImageSelected: (file) {
                                    if (file != null) {
                                      setState(() {
                                        uploadedPhotoPath = file.path;
                                        hasUnsavedChanges = true;
                                        _hasFormDataChanges = true;
                                      });
                                      _uploadSelfie(file);
                                    } else {
                                      setState(() {
                                        uploadedPhotoPath = null;
                                        uploadedImgId = null;
                                        fetchedImageData = null;
                                      });
                                    }
                                  },
                                );
                              },
                            ),
                            getHeight(15),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(16),
                    child: BlocBuilder<AssetAuditCubit, AssetAuditState>(
                      builder: (context, state) {
                        return Row(
                          children: [
                            Expanded(
                              child: ArrowButton(
                                text: "Site Info",
                                isLeftArrow: false,
                                backgroundColor: AppColors.buttonColorBg,
                                textColor: AppColors.buttonColorSite,
                                onPressed: () {
                                  if (_validateForm()) {
                                    _saveFormDataToHive();
                                    if (state is AssetAuditLoaded && state.assetAuditData.pageHeader.isNotEmpty) {
                                      final siteData = state.assetAuditData.pageHeader.first;
                                      pushPage(
                                        context,
                                        SiteInfoScreen(
                                          siteName: siteData.siteName,
                                          siteTypeName: siteData.siteTypeName,
                                          indoorOutdoor: siteData.indoorOutdoor,
                                          ebNonEb: siteData.ebNonEb,
                                          op1Name: siteData.op1Name,
                                          op2Name: siteData.op2Name ?? "N/A",
                                          assetAuditData: state.assetAuditData,
                                        ),
                                      );
                                    } else {
                                      pushPage(
                                        context,
                                        SiteInfoScreen(
                                          siteName: "N/A",
                                          siteTypeName: "N/A",
                                          indoorOutdoor: "N/A",
                                          ebNonEb: "N/A",
                                          op1Name: "N/A",
                                          op2Name: "N/A",
                                          assetAuditData: null,
                                        ),
                                      );
                                    }
                                  } else {
                                    showCustomToast(
                                      context,
                                      uploadedPhotoPath == null || uploadedPhotoPath!.isEmpty
                                          ? 'Please upload a selfie photo to continue'
                                          : 'Please fill in all required fields',
                                    );
                                  }
                                },
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}


// class _AssetAuditTelecomScreenState extends State<AssetAuditTelecomScreen> {
//   final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
//   final TextEditingController serialController = TextEditingController();
//   String? selectedFile;
//   String? selectedStatus;
//   String? selectedBatteryStatus;
//   String? selectedType;
//   bool hasUnsavedChanges = false;
//   bool showValidationErrors = false;
//   int totalItemsToScan = 6;
//   int currentScannedItems = 0;
//   List<Map<String, dynamic>> savedItems = [];
//   Map<String, dynamic> currentFormData = {};
//
//   // AssetTypeCard field values
//   String? assetCardSerialNumber;
//   String? assetCardPhoto;
//   String? assetCardStatus;
//
//   // Track uploaded photo
//   String? uploadedPhotoPath;
//   String? uploadedImgId; // Store the uploaded image ID from API
//   String? fetchedImageData; // Store the fetched image data from API
//
//   // Form data persistence
//   bool _hasFormDataChanges = false;
//
//   // Controllers for CustomInfoCard
//   final TextEditingController cctvSerialController = TextEditingController();
//
//   /// Save current form data to Hive
//   void _saveFormDataToHive() {
//     if (!_hasFormDataChanges) {
//       return;
//     }
//
//     final Map<String, dynamic> formData = {
//       'uploadedPhotoPath': uploadedPhotoPath,
//       'uploadedImgId': uploadedImgId,
//       // Don't save large image data to form persistence, only save the ID
//       // The image data will be loaded from the assetAuditImages Hive box
//       'selectedFile': selectedFile,
//       'selectedStatus': selectedStatus,
//       'selectedBatteryStatus': selectedBatteryStatus,
//       'selectedType': selectedType,
//       'serialController': serialController.text,
//       'cctvSerialController': cctvSerialController.text,
//       'assetCardSerialNumber': assetCardSerialNumber,
//       'assetCardPhoto': assetCardPhoto,
//       'assetCardStatus': assetCardStatus,
//       'timestamp': DateTime.now().millisecondsSinceEpoch,
//     };
//
//     AssetAuditFormPersistenceHelper.saveFormData(
//       siteAuditSchId: widget.siteAuditSchId,
//       screenName: 'telecom_page_1',
//       formData: formData,
//     );
//     _hasFormDataChanges = false;
//   }
//
//
//
//   @override
//   void initState() {
//     super.initState();
//     // Listen to form changes
//     serialController.addListener(_onFormChanged);
//   }
//
//   @override
//   void didChangeDependencies() {
//     super.didChangeDependencies();
//     print('=== didChangeDependencies called ===');
//
//     // Load asset audit data after dependencies are available
//     context.read<AssetAuditCubit>().getAssetAuditData(
//       siteType: widget.siteType,
//       auditSchId: widget.auditSchId,
//       siteAuditSchId: widget.siteAuditSchId,
//     );
//
//     // Ensure Hive boxes are ready before loading data
//     AssetAuditFormPersistenceHelper.ensureHiveBoxReady().then((_) {
//       _loadStoredSelfie();
//
//       _checkPageHeaderForSelfie();
//     });
//
//     _fetchImagesForExistingItems();
//   }
//
//   void _checkPageHeaderForSelfie() {
//     final assetAuditState = context.read<AssetAuditCubit>().state;
//     if (assetAuditState is AssetAuditLoaded &&
//         assetAuditState.assetAuditData.pageHeader.isNotEmpty) {
//       final pageHeader = assetAuditState.assetAuditData.pageHeader.first;
//
//       final currentPageHeader = context
//           .read<AssetAuditCubit>()
//           .getCurrentPageHeader();
//       if (currentPageHeader != null) {
//         print('makerSelfieImageId: ${currentPageHeader.makerSelfieImageId}');
//       }
//
//       if (pageHeader.makerSelfieImageId != null &&
//           pageHeader.makerSelfieImageId! > 0) {
//         setState(() {
//           uploadedImgId = pageHeader.makerSelfieImageId.toString();
//           // Clear any existing image data to force a fresh fetch
//           fetchedImageData = null;
//         });
//
//         // Fetch the image using the AssetAuditGetImageCubit
//         try {
//           context.read<AssetAuditGetImageCubit>().getImage(
//             imgId: pageHeader.makerSelfieImageId.toString(),
//             schId: widget.siteAuditSchId,
//           );
//         } catch (e) {
//           print('=== Error sending image fetch request: $e ===');
//         }
//
//         return; // Don't load from Hive if we have a page header image ID
//       } else {}
//     } else {
//       print('assetAuditState type: ${assetAuditState.runtimeType}');
//       if (assetAuditState is AssetAuditLoaded) {
//         print(
//           'pageHeader length: ${assetAuditState.assetAuditData.pageHeader.length}',
//         );
//       }
//     }
//   }
//
//   void _loadStoredSelfie() async {
//     final formData = await AssetAuditFormPersistenceHelper.loadFormData(
//       siteAuditSchId: widget.siteAuditSchId,
//       screenName: 'telecom_page_1',
//     );
//
//     if (formData != null) {
//       setState(() {
//         uploadedImgId = formData['uploadedImgId'];
//         uploadedPhotoPath = formData['uploadedPhotoPath'];
//         selectedFile = formData['selectedFile'];
//         selectedStatus = formData['selectedStatus'];
//         selectedBatteryStatus = formData['selectedBatteryStatus'];
//         selectedType = formData['selectedType'];
//
//         // Restore controller values
//         if (formData['serialController'] != null) {
//           serialController.text = formData['serialController'];
//         }
//         if (formData['cctvSerialController'] != null) {
//           cctvSerialController.text = formData['cctvSerialController'];
//         }
//
//         assetCardSerialNumber = formData['assetCardSerialNumber'];
//         assetCardPhoto = formData['assetCardPhoto'];
//         assetCardStatus = formData['assetCardStatus'];
//       });
//
//       // Now try to load the actual image data from the assetAuditImages Hive box
//       if (formData['uploadedImgId'] != null &&
//           formData['uploadedImgId'].toString().isNotEmpty) {
//         final storedSelfie = HiveDB.getAssetAuditSelfie(widget.siteAuditSchId);
//         if (storedSelfie != null &&
//             storedSelfie['imageData'] != null &&
//             storedSelfie['imageData'].toString().isNotEmpty) {
//           setState(() {
//             fetchedImageData = storedSelfie['imageData'] as String?;
//           });
//           return; // Exit early since we have both form data and image data
//         } else {
//           // If we have the ID but no image data, fetch from server
//           context.read<AssetAuditGetImageCubit>().getImage(
//             imgId: formData['uploadedImgId'].toString(),
//             schId: widget.siteAuditSchId,
//           );
//           return; // Exit early since we're fetching the image
//         }
//       }
//
//       return; // Exit early since we restored form data
//     }
//
//     // Fallback: Load from Hive for this specific ticket (legacy method)
//     final storedSelfie = HiveDB.getAssetAuditSelfie(widget.siteAuditSchId);
//     if (storedSelfie != null) {
//       if (storedSelfie['imageData'] != null &&
//           storedSelfie['imageData'].toString().isNotEmpty) {
//         setState(() {
//           uploadedImgId = storedSelfie['imageId'] as String?;
//           fetchedImageData = storedSelfie['imageData'] as String?;
//           uploadedPhotoPath =
//               null; // Clear local path since we have stored data
//         });
//       } else {
//         // If we only have the ID, we need to fetch the image from the server
//         if (storedSelfie['imageId'] != null &&
//             storedSelfie['imageId'].toString().isNotEmpty) {
//           setState(() {
//             uploadedImgId = storedSelfie['imageId'] as String?;
//           });
//
//           // Fetch the image from server using the stored ID
//           context.read<AssetAuditGetImageCubit>().getImage(
//             imgId: storedSelfie['imageId'].toString(),
//             schId: widget.siteAuditSchId,
//           );
//         }
//       }
//     } else {
//       print(
//         '=== No stored selfie found in either persistence or legacy Hive ===',
//       );
//     }
//   }
//
//
//
//   @override
//   void dispose() {
//     serialController.removeListener(_onFormChanged);
//     serialController.dispose();
//     cctvSerialController.dispose();
//     super.dispose();
//   }
//
//   void _onFormChanged() {
//     setState(() {
//       // Check if we have any form data changes
//       final hasLocalPhoto =
//           uploadedPhotoPath != null && uploadedPhotoPath!.isNotEmpty;
//       final hasServerImage =
//           uploadedImgId != null &&
//           uploadedImgId!.isNotEmpty &&
//           uploadedImgId != "0";
//       final hasImageData =
//           fetchedImageData != null && fetchedImageData!.isNotEmpty;
//
//       hasUnsavedChanges =
//           selectedFile != null ||
//           selectedStatus != null ||
//           selectedBatteryStatus != null ||
//           selectedType != null ||
//           serialController.text.isNotEmpty ||
//           hasLocalPhoto ||
//           hasServerImage ||
//           hasImageData;
//
//       // Track form data changes for persistence
//       _hasFormDataChanges = true;
//
//       // Hide validation errors when user starts filling the form
//       if (showValidationErrors &&
//           (hasLocalPhoto || hasServerImage || hasImageData)) {
//         showValidationErrors = false;
//       }
//     });
//   }
//
//   void _saveAndExit() async {
//     // Save form data to Hive before exiting
//     _saveFormDataToHive();
//
//     Navigator.of(context).pop();
//     await Future.delayed(const Duration(milliseconds: 200));
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
//   bool _validateForm() {
//     setState(() {
//       showValidationErrors = true;
//     });
//
//     print('=== Form Validation Debug (_validateForm) ===');
//     print('uploadedPhotoPath: $uploadedPhotoPath');
//     print('uploadedImgId: $uploadedImgId');
//     print('fetchedImageData length: ${fetchedImageData?.length ?? 0}');
//
//     // Check if we have either a local photo path OR a fetched image from server
//     final hasLocalPhoto =
//         uploadedPhotoPath != null && uploadedPhotoPath!.isNotEmpty;
//     final hasServerImage =
//         uploadedImgId != null &&
//         uploadedImgId!.isNotEmpty &&
//         uploadedImgId != "0";
//     final hasImageData =
//         fetchedImageData != null && fetchedImageData!.isNotEmpty;
//
//     if (hasLocalPhoto || hasServerImage || hasImageData) {
//       print('Photo validation passed - has image available');
//       return true;
//     } else {
//       print('Photo validation failed - no image available');
//       return false;
//     }
//   }
//
//   void _uploadSelfie(File file) {
//     final assetAuditState = context.read<AssetAuditCubit>().state;
//     if (assetAuditState is AssetAuditLoaded &&
//         assetAuditState.assetAuditData.pageHeader.isNotEmpty) {
//       final schId = assetAuditState
//           .assetAuditData
//           .pageHeader
//           .first
//           .siteAuditSchId
//           .toString();
//
//       // Check if we're updating an existing image
//       final existingImgId = uploadedImgId;
//       final imgIdToUse = existingImgId != null && existingImgId.isNotEmpty
//           ? existingImgId
//           : "0";
//
//       // Mark that form data has changed
//       _hasFormDataChanges = true;
//
//       context.read<SelfieUploadCubit>().uploadSelfie(
//         file: file,
//         imgId: imgIdToUse,
//         schId: schId,
//       );
//     } else {
//       showCustomToast(
//         context,
//         'Please wait for site data to load before uploading selfie',
//       );
//     }
//   }
//
//   void _fetchImagesForExistingItems() {
//     if (uploadedImgId != null &&
//         uploadedImgId!.isNotEmpty &&
//         uploadedImgId != "0") {
//       final assetAuditState = context.read<AssetAuditCubit>().state;
//       if (assetAuditState is AssetAuditLoaded &&
//           assetAuditState.assetAuditData.pageHeader.isNotEmpty) {
//         final schId = assetAuditState
//             .assetAuditData
//             .pageHeader
//             .first
//             .siteAuditSchId
//             .toString();
//
//         // Trigger image fetch using the AssetAuditGetImageCubit
//         context.read<AssetAuditGetImageCubit>().getImage(
//           imgId: uploadedImgId!,
//           schId: schId,
//         );
//       }
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return MultiBlocListener(
//       listeners: [
//         BlocListener<SelfieUploadCubit, SelfieUploadState>(
//           listener: (context, state) {
//             if (state is SelfieUploadSuccess) {
//               final assetAuditState = context.read<AssetAuditCubit>().state;
//               if (assetAuditState is AssetAuditLoaded &&
//                   assetAuditState.assetAuditData.pageHeader.isNotEmpty) {
//                 final schId = assetAuditState
//                     .assetAuditData
//                     .pageHeader
//                     .first
//                     .siteAuditSchId
//                     .toString();
//
//                 setState(() {
//                   uploadedImgId = state.response.imgId;
//                 });
//
//                 // Save the image ID to Hive for this specific ticket
//                 if (state.response.imgId.isNotEmpty) {
//                   HiveDB.saveAssetAuditSelfie(
//                     siteAuditSchId: schId,
//                     imageId: state.response.imgId,
//                     imageData:
//                         '', // We'll update this when the image is fetched
//                   );
//                 }
//
//                 // Update the page header with the new selfie image ID
//                 if (state.response.imgId.isNotEmpty) {
//                   context.read<AssetAuditCubit>().updatePageHeaderSelfieImageId(
//                     state.response.imgId,
//                   );
//
//                   final updatedState = context.read<AssetAuditCubit>().state;
//                   if (updatedState is AssetAuditLoaded &&
//                       updatedState.assetAuditData.pageHeader.isNotEmpty) {
//                     print(
//                       'Updated page header makerSelfieImageId: ${updatedState.assetAuditData.pageHeader.first.makerSelfieImageId}',
//                     );
//                   }
//                 }
//
//                 // Check if this is an update to existing image
//                 final isUpdate =
//                     uploadedImgId != null &&
//                     uploadedImgId!.isNotEmpty &&
//                     uploadedImgId != "0";
//                 final message = isUpdate
//                     ? 'Selfie updated successfully!'
//                     : 'Selfie uploaded successfully!';
//                 showCustomToast(context, message);
//
//                 // Fetch uploaded image if ID exists
//                 if (state.response.imgId.isNotEmpty) {
//                   context.read<AssetAuditGetImageCubit>().getImage(
//                     imgId: state.response.imgId,
//                     schId: schId,
//                   );
//                 }
//               }
//             } else if (state is SelfieUploadFailure) {
//               showCustomToast(context, '${state.errorMessage}');
//             }
//           },
//         ),
//         BlocListener<AssetAuditGetImageCubit, AssetAuditGetImageState>(
//           listener: (context, state) {
//             if (state is AssetAuditGetImageSuccess) {
//                               // Debug: Analyze image data format
//                 try {
//                   if (state.imageData.startsWith('data:image')) {
//                     final base64Data = state.imageData.split(',')[1];
//                     final decodedLength = base64Data.length * 3 ~/ 4;
//                     print('Base64 data length: $base64Data.length, estimated decoded size: $decodedLength bytes');
//                   } else {
//                     final decodedLength = state.imageData.length * 3 ~/ 4;
//                     print('Raw base64 length: ${state.imageData.length}, estimated decoded size: $decodedLength bytes');
//                   }
//                 } catch (e) {
//                   print('Error analyzing image data: $e');
//                 }
//
//               final assetAuditState = context.read<AssetAuditCubit>().state;
//               if (assetAuditState is AssetAuditLoaded &&
//                   assetAuditState.assetAuditData.pageHeader.isNotEmpty) {
//                 final schId = assetAuditState
//                     .assetAuditData
//                     .pageHeader
//                     .first
//                     .siteAuditSchId
//                     .toString();
//
//                 // Check if this is an update to existing image
//                 final isUpdate =
//                     uploadedImgId != null &&
//                     uploadedImgId!.isNotEmpty &&
//                     uploadedImgId != "0";
//
//                 // Check if this is an image fetched from page header
//                 final pageHeader =
//                     assetAuditState.assetAuditData.pageHeader.first;
//                 final isFromPageHeader =
//                     pageHeader.makerSelfieImageId != null &&
//                     pageHeader.makerSelfieImageId.toString() == uploadedImgId;
//
//                 HiveDB.updateAssetAuditSelfie(
//                   siteAuditSchId: schId,
//                   newImageId: uploadedImgId ?? '',
//                   newImageData: state.imageData,
//                 );
//
//                 if (isUpdate && !isFromPageHeader) {
//                   showCustomToast(
//                     context,
//                     'Image updated and saved successfully!',
//                   );
//                 } else if (isFromPageHeader) {
//                   showCustomToast(
//                     context,
//                     'Existing selfie image loaded from server! You can replace it by uploading a new photo.',
//                   );
//                 } else {
//                   showCustomToast(
//                     context,
//                     'Image fetched and saved successfully!',
//                   );
//                 }
//
//                 setState(() {
//                   fetchedImageData = state.imageData;
//
//                   try {
//                     if (state.imageData.startsWith('data:image')) {
//                       final base64Data = state.imageData.split(',')[1];
//                       final decodedLength = base64Data.length * 3 ~/ 4;
//                     } else {
//                       final decodedLength = state.imageData.length * 3 ~/ 4;
//                     }
//                   } catch (e) {
//                     print('Error analyzing image data: $e');
//                   }
//                 });
//                 _hasFormDataChanges = true;
//               }
//             } else if (state is AssetAuditGetImageFailure) {
//               showCustomToast(
//                 context,
//                 'Failed to fetch image: ${state.errorMessage}',
//               );
//             } else if (state is AssetAuditGetImageLoading) {
//               print('=== Image fetch LOADING ===');
//             } else {
//               print('=== Image fetch UNKNOWN STATE ===');
//             }
//           },
//         ),
//         BlocListener<AssetAuditCubit, AssetAuditState>(
//           listener: (context, state) {
//             if (state is AssetAuditError) {
//               if (state.message.contains('NO_SITE_AUDIT_SCHEDULE:')) {
//                 showDialog(
//                   context: context,
//                   barrierDismissible: false,
//                   builder: (context) => CustomAlertDialog(
//                     title: 'No Site Audit Schedule Found',
//                     subTitle1:
//                         'This ticket does not have an asset audit schedule created yet.',
//                     subTitle2:
//                         'Please contact your administrator to create the asset audit schedule before proceeding with the audit.',
//                     buttonText1: 'Go Back',
//                     buttonText2: 'Retry',
//                     onButtonPressed1: () {
//                       Navigator.of(context).pop(); // Close dialog
//                       Navigator.of(context).pop();
//                     },
//                     onButtonPressed2: () {
//                       Navigator.of(context).pop();
//                       context.read<AssetAuditCubit>().getAssetAuditData(
//                         siteType: widget.siteType,
//                         auditSchId: widget.auditSchId,
//                         siteAuditSchId: widget.siteAuditSchId,
//                       );
//                     },
//                     isSuccess: false,
//                   ),
//                 );
//               } else {
//                 showCustomToast(context, ' ${state.message}');
//               }
//             }
//           },
//         ),
//       ],
//
//       child: BlocBuilder<AssetAuditCubit, AssetAuditState>(
//         builder: (context, state) {
//           if (state is AssetAuditLoading) {
//             return const Center(
//               child: CircularProgressIndicator(color: AppColors.primaryGreen),
//             );
//           }
//
//           if (state is AssetAuditLoaded) {
//             return buildContent(context, state);
//           }
//
//           // Default idle/error fallback
//           return buildContent(context, state);
//         },
//       ),
//     );
//   }
//
//   Widget buildContent(BuildContext context, AssetAuditState state) {
//     // Default values
//     var pageHeader = <PageHeader>[];
//
//     if (state is AssetAuditLoaded) {
//       pageHeader = state.assetAuditData.pageHeader;
//     }
//
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
//                   "Do you want to cancel the Asset Audit for Site (ID: SITE-38974) ?",
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
//                       "Do you want to cancel the Asset Audit for Site (ID: SITE-38974) ?",
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
//               child: SvgPicture.asset(AppImages.home, fit: BoxFit.cover),
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
//                               MediaQuery.of(context).viewInsets.bottom + 120,
//                         ),
//                         child: Container(
//                           padding: const EdgeInsets.symmetric(
//                             horizontal: 16,
//                             vertical: 20,
//                           ),
//                           child: Column(
//                             crossAxisAlignment: CrossAxisAlignment.start,
//                             children: [
//                               CustomFormField(
//                                 label: "Circle",
//                                 initialValue: pageHeader.isNotEmpty
//                                     ? pageHeader.first.circle
//                                     : "N/A",
//                                 isRequired: false,
//                                 isEditable: false,
//                               ),
//                               getHeight(15),
//                               CustomFormField(
//                                 label: "Cluster",
//                                 initialValue: pageHeader.isNotEmpty
//                                     ? pageHeader.first.cluster
//                                     : "N/A",
//                                 isRequired: false,
//                                 isEditable: false,
//                               ),
//                               getHeight(15),
//                               CustomFormField(
//                                 label: "District",
//                                 initialValue: pageHeader.isNotEmpty
//                                     ? pageHeader.first.district ?? "N/A"
//                                     : "N/A",
//                                 isRequired: false,
//                                 isEditable: false,
//                               ),
//                               getHeight(15),
//                               CustomFormField(
//                                 label: "Customer",
//                                 initialValue: pageHeader.isNotEmpty
//                                     ? pageHeader.first.clientName
//                                     : "N/A",
//                                 isRequired: false,
//                                 isEditable: false,
//                               ),
//                               getHeight(15),
//                               CustomFormField(
//                                 label: "Site Id",
//                                 initialValue: pageHeader.isNotEmpty
//                                     ? pageHeader.first.siteCode
//                                     : "N/A",
//                                 isRequired: false,
//                                 isEditable: false,
//                               ),
//                               getHeight(15),
//                               CustomFormField(
//                                 label: "Site Name",
//                                 initialValue: pageHeader.isNotEmpty
//                                     ? pageHeader.first.siteName
//                                     : "N/A",
//                                 isRequired: false,
//                                 isEditable: false,
//                               ),
//                               getHeight(15),
//                               BlocBuilder<AssetAuditCubit, AssetAuditState>(
//                                 builder: (context, state) {
//                                   // Load stored selfie when building this widget
//                                   if (state is AssetAuditLoaded &&
//                                       fetchedImageData == null) {
//                                     WidgetsBinding.instance
//                                         .addPostFrameCallback((_) {
//                                           _checkPageHeaderForSelfie();
//                                           if (uploadedImgId == null ||
//                                               uploadedImgId!.isEmpty ||
//                                               uploadedImgId == "0") {
//                                             _loadStoredSelfie();
//                                           }
//                                         });
//                                   }
//
//                                   // Force rebuild when image data changes
//                                   if (fetchedImageData != null &&
//                                       fetchedImageData!.isNotEmpty) {
//                                     print(
//                                       '=== ImageUploadField: Image data available, should display ===',
//                                     );
//                                   }
//
//                                   return ImageUploadField(
//                                     label: "Add a Selfie",
//                                     placeholder: "Selfie",
//                                     isRequired: true,
//                                     externalImageUrl:
//                                         fetchedImageData != null &&
//                                             fetchedImageData!.isNotEmpty
//                                         ? fetchedImageData! // Use the data as-is since it already has the proper format
//                                         : null,
//                                     // Show saved selfie if available
//                                     onImageSelected: (file) {
//                                       if (file != null) {
//                                         setState(() {
//                                           uploadedPhotoPath = file.path;
//                                           hasUnsavedChanges = true;
//                                           _hasFormDataChanges =
//                                               true; // Track for persistence
//                                         });
//                                         _uploadSelfie(file);
//                                       } else {
//                                         setState(() {
//                                           uploadedPhotoPath = null;
//                                           uploadedImgId = null;
//                                         });
//                                       }
//                                     },
//                                   );
//                                 },
//                               ),
//                             ],
//                           ),
//                         ),
//                       ),
//                     ),
//                     BlocBuilder<AssetAuditCubit, AssetAuditState>(
//                       builder: (context, state) {
//                         return Container(
//                           padding: const EdgeInsets.all(16),
//                           child: ArrowButton(
//                             text: "Site Info",
//                             isLeftArrow: false,
//                             backgroundColor: AppColors.buttonColorBg,
//                             textColor: AppColors.buttonColorSite,
//                             onPressed: () {
//                               if (_validateForm()) {
//                                 if (state is AssetAuditLoaded &&
//                                     state
//                                         .assetAuditData
//                                         .pageHeader
//                                         .isNotEmpty) {
//                                   final siteData =
//                                       state.assetAuditData.pageHeader.first;
//
//                                   pushPage(
//                                     context,
//                                     SiteInfoScreen(
//                                       siteName: siteData.siteName,
//                                       siteTypeName: siteData.siteTypeName,
//                                       indoorOutdoor: siteData.indoorOutdoor,
//                                       ebNonEb: siteData.ebNonEb,
//                                       op1Name: siteData.op1Name,
//                                       op2Name: siteData.op2Name ?? "N/A",
//                                       assetAuditData: state.assetAuditData,
//                                     ),
//                                   );
//                                 } else {
//                                   pushPage(
//                                     context,
//                                     SiteInfoScreen(
//                                       siteName: "N/A",
//                                       siteTypeName: "N/A",
//                                       indoorOutdoor: "N/A",
//                                       ebNonEb: "N/A",
//                                       op1Name: "N/A",
//                                       op2Name: "N/A",
//                                       assetAuditData: null,
//                                     ),
//                                   );
//                                 }
//                               } else {
//                                 showCustomToast(
//                                   context,
//                                   uploadedPhotoPath == null ||
//                                       uploadedPhotoPath!.isEmpty
//                                       ? 'Please upload a selfie photo to continue'
//                                       : 'Please fill in all required fields',
//                                 );
//                               }
//                             },
//                           ),
//                         );
//                       },
//                     ),
//
//                   ],
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
