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
import '../../../commonWidgets/custom_dialogs/success_dialog.dart';
import '../../../commonWidgets/custom_dialogs/unsaved_changes_dialog.dart';
import '../../../commonWidgets/custom_form_appbar.dart';
import '../../../commonWidgets/custom_form_field.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_images.dart';
import '../../../constants/constants_strings.dart';

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

  // Controllers for CustomInfoCard
  final TextEditingController cctvSerialController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Listen to form changes
    serialController.addListener(_onFormChanged);

    // Load asset audit data
    // context.read<AssetAuditCubit>().getAssetAuditData(
    //   siteType: widget.siteType,
    //   auditSchId: widget.auditSchId,
    //   siteAuditSchId: widget.siteAuditSchId,
    // );
  }

  @override
  void dispose() {
    serialController.removeListener(_onFormChanged);
    serialController.dispose();
    cctvSerialController.dispose();
    super.dispose();
  }

  void _onFormChanged() {
    setState(() {
      hasUnsavedChanges =
          selectedFile != null ||
              selectedStatus != null ||
              selectedBatteryStatus != null ||
              selectedType != null ||
              serialController.text.isNotEmpty ||
              uploadedPhotoPath != null;

      // Hide validation errors when user starts filling the form
      if (showValidationErrors && uploadedPhotoPath != null) {
        showValidationErrors = false;
      }
    });
  }

  void _saveAndExit() async {
    Navigator.of(context).pop();
    await Future.delayed(const Duration(milliseconds: 200));
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
    if (uploadedPhotoPath == null || uploadedPhotoPath!.isEmpty) {
      print(' Photo validation failed - No photo uploaded');
      return false;
    } else {
      print('Photo validation passed');
    }

    print(' All validations passed!');
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

      context.read<SelfieUploadCubit>().uploadSelfie(
        file: file,
        imgId: "0",
        schId: schId,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please wait for site data to load before uploading selfie',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontFamily: fontFamilyMontserrat,
            ),
          ),
          backgroundColor: AppColors.errorColor,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<AssetAuditCubit, AssetAuditState>(
          listener: (context, state) {
            if (state is AssetAuditError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: AppColors.errorColor,
                ),
              );
            }
          },
        ),
        BlocListener<SelfieUploadCubit, SelfieUploadState>(
          listener: (context, state) {
            if (state is SelfieUploadSuccess) {
              setState(() {
                uploadedImgId = state.response.imgId;
              });

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Selfie uploaded successfully!',
                    style: const TextStyle(
                      color: AppColors.primaryGreen,
                      fontSize: 14,
                      fontFamily: fontFamilyMontserrat,
                    ),
                  ),
                  backgroundColor: Colors.white,
                  duration: const Duration(seconds: 2),
                ),
              );
            } else if (state is SelfieUploadFailure) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    state.errorMessage,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontFamily: fontFamilyMontserrat,
                    ),
                  ),
                  backgroundColor: AppColors.errorColor,
                  duration: Duration(seconds: 3),
                ),
              );
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
                                      label: "State (Solar)",
                                      // initialValue: state
                                      //     .assetAuditData
                                      //     .pageHeader
                                      //     .first
                                      //     .circle,
                                      initialValue: "Haryana",
                                      isRequired: false,
                                      isEditable: false,
                                    ),
                                    getHeight(15),
                                    CustomFormField(
                                      label: "District (Solar)",
                                      // initialValue: state
                                      //     .assetAuditData
                                      //     .pageHeader
                                      //     .first
                                      //     .cluster,
                                      initialValue: "Rewari",
                                      isRequired: false,
                                      isEditable: false,
                                    ),
                                    getHeight(15),
                                    CustomFormField(
                                      label: "District",
                                      // initialValue:
                                      // state
                                      //     .assetAuditData
                                      //     .pageHeader
                                      //     .first
                                      //     .district ??
                                      //     "N/A",
                                      initialValue: "N/A",
                                      isRequired: false,
                                      isEditable: false,
                                    ),
                                    getHeight(15),
                                    CustomFormField(
                                      label: "Customer",
                                      // initialValue: state
                                      //     .assetAuditData
                                      //     .pageHeader
                                      //     .first
                                      //     .clientName,
                                      initialValue: "Skipper",
                                      isRequired: false,
                                      isEditable: false,
                                    ),
                                    getHeight(15),
                                    CustomFormField(
                                      label: "Site Id",
                                      // initialValue: state
                                      //     .assetAuditData
                                      //     .pageHeader
                                      //     .first
                                      //     .siteCode,
                                      initialValue: "HR-REW-101",
                                      isRequired: false,
                                      isEditable: false,
                                    ),
                                    getHeight(15),
                                    CustomFormField(
                                      label: "Site Name",
                                      // initialValue: state
                                      //     .assetAuditData
                                      //     .pageHeader
                                      //     .first
                                      //     .siteName,
                                      initialValue: "HR-REW-101",
                                      isRequired: false,
                                      isEditable: false,
                                    ),
                                    getHeight(15),
                                    ImageUploadField(
                                      label: "Add a Selfie",
                                      placeholder: "Selfie",
                                      isRequired: true,
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
                                          });
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          Container(
                            padding: const EdgeInsets.all(16),
                            child: ArrowButton(
                              text: "SPV",
                              isLeftArrow: false,
                              backgroundColor: AppColors.buttonColorBg,
                              textColor: AppColors.buttonColorSite,
                              onPressed: () {
                               pushPage(context,  SPVScreen());
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
