import 'package:app/commonWidgets/custom_buttons/arrow_botton.dart';
import 'package:app/commonWidgets/custom_image_upload_field.dart';
import 'package:app/constants/constants_methods.dart';
import 'package:app/routes/routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';

import '../../../bloc/asset_audit_cubit.dart';
import '../../../bloc/asset_audit_state.dart';
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
  State<AssetAuditSolarScreen> createState() => _AssetAuditSolarScreenState();
}

class _AssetAuditSolarScreenState extends State<AssetAuditSolarScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController serialController = TextEditingController();
  bool hasUnsavedChanges = false;
  bool showValidationErrors = false;
  String? uploadedPhotoPath;

  @override
  void initState() {
    super.initState();
    serialController.addListener(_onFormChanged);
    
    // Load asset audit data
    context.read<AssetAuditCubit>().getAssetAuditData(
      siteType: widget.siteType,
      auditSchId: widget.auditSchId,
      siteAuditSchId: widget.siteAuditSchId,
    );
  }

  @override
  void dispose() {
    serialController.removeListener(_onFormChanged);
    serialController.dispose();
    super.dispose();
  }

  void _onFormChanged() {
    setState(() {
      hasUnsavedChanges = serialController.text.isNotEmpty || uploadedPhotoPath != null;

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

    if (uploadedPhotoPath == null || uploadedPhotoPath!.isEmpty) {
      return false;
    }

    return true;
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AssetAuditCubit, AssetAuditState>(
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
              title: "Asset Audit - Solar",
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
                                  if (state is AssetAuditLoaded && state.assetAuditData.pageHeader.isNotEmpty) ...[
                                    CustomFormField(
                                      label: "Circle",
                                      initialValue: state.assetAuditData.pageHeader.first.circle,
                                      isRequired: false,
                                      isEditable: false,
                                    ),
                                    getHeight(15),
                                    CustomFormField(
                                      label: "Cluster",
                                      initialValue: state.assetAuditData.pageHeader.first.cluster,
                                      isRequired: false,
                                      isEditable: false,
                                    ),
                                    getHeight(15),
                                    CustomFormField(
                                      label: "District",
                                      initialValue: state.assetAuditData.pageHeader.first.district ?? "N/A",
                                      isRequired: false,
                                      isEditable: false,
                                    ),
                                    getHeight(15),
                                    CustomFormField(
                                      label: "Customer",
                                      initialValue: state.assetAuditData.pageHeader.first.clientName,
                                      isRequired: false,
                                      isEditable: false,
                                    ),
                                    getHeight(15),
                                    CustomFormField(
                                      label: "Site Id",
                                      initialValue: state.assetAuditData.pageHeader.first.siteCode,
                                      isRequired: false,
                                      isEditable: false,
                                    ),
                                    getHeight(15),
                                    CustomFormField(
                                      label: "Site Name",
                                      initialValue: state.assetAuditData.pageHeader.first.siteName,
                                      isRequired: false,
                                      isEditable: false,
                                    ),
                                  ] else ...[
                                    CustomFormField(
                                      label: "Circle",
                                      initialValue: "Loading...",
                                      isRequired: false,
                                      isEditable: false,
                                    ),
                                    getHeight(15),
                                    CustomFormField(
                                      label: "Cluster",
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
                                      label: "Site Id",
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
                                  ],
                                  getHeight(15),
                                  ImageUploadField(
                                    label: "Add a Selfie",
                                    placeholder: "Selfie",
                                    isRequired: true,
                                    onImageSelected: (file) {
                                      if (file != null) {
                                        debugPrint("Selected image path: ${file.path}");
                                        setState(() {
                                          uploadedPhotoPath = file.path;
                                          hasUnsavedChanges = true;
                                        });
                                      } else {
                                        setState(() {
                                          uploadedPhotoPath = null;
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
                            text: "Continue",
                            isLeftArrow: false,
                            backgroundColor: AppColors.buttonColorBg,
                            textColor: AppColors.buttonColorSite,
                            onPressed: () {
                              if (_validateForm()) {
                                // Navigate to solar-specific screens
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Solar audit flow - Coming soon'),
                                    backgroundColor: AppColors.primaryGreen,
                                  ),
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      uploadedPhotoPath == null || uploadedPhotoPath!.isEmpty
                                          ? 'Please upload a selfie photo to continue'
                                          : 'Please fill in all required fields',
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
                              }
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
    );
  }
}
