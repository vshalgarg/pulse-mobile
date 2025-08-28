import 'package:app/commonWidgets/custom_buttons/arrow_botton.dart';
import 'package:app/constants/constants_methods.dart';
import 'package:app/screens/asset_audit/asset_audit_telecom/ccu_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

import '../../../commonWidgets/custom_dialogs/success_dialog.dart';
import '../../../commonWidgets/custom_dialogs/unsaved_changes_dialog.dart';
import '../../../commonWidgets/custom_form_appbar.dart';
import '../../../commonWidgets/custom_form_field.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_images.dart';
import '../../../constants/constants_strings.dart';

class SiteInfoScreen extends StatefulWidget {
  final String siteName;
  final String siteTypeName;
  final String indoorOutdoor;
  final String ebNonEb;
  final String op1Name;
  final String op2Name;

  const SiteInfoScreen({
    super.key,
    required this.siteName,
    required this.siteTypeName,
    required this.indoorOutdoor,
    required this.ebNonEb,
    required this.op1Name,
    required this.op2Name,
  });

  @override
  State<SiteInfoScreen> createState() => _SiteInfoScreenState();
}

class _SiteInfoScreenState extends State<SiteInfoScreen> {
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

  // Controllers for CustomInfoCard
  final TextEditingController cctvSerialController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Listen to form changes
    serialController.addListener(_onFormChanged);
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
      if (showValidationErrors &&
          uploadedPhotoPath != null) {
        showValidationErrors = false;
      }
    });
  }

  void _saveAndExit() async {
    // First close the unsaved changes dialog
    Navigator.of(context).pop();

    // Wait a bit for the dialog to fully close and overlay to clear
    await Future.delayed(const Duration(milliseconds: 200));

    // Then show success dialog with a clean barrier
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.black54, // Ensure clean barrier
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

    // Check if photo is uploaded
    print('uploadedPhotoPath: $uploadedPhotoPath');
    if (uploadedPhotoPath == null || uploadedPhotoPath!.isEmpty) {
      print('Photo validation failed - No photo uploaded');
      return false;
    } else {
      print('Photo validation passed');
    }

    print('All validations passed!');
    return true;
  }

  @override
  Widget build(BuildContext context) {
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
                                label: "Site Type",
                                initialValue: widget.siteTypeName,
                                isRequired: false,
                                isEditable: false,
                              ),
                              getHeight(15),
                              CustomFormField(
                                label: "Indoor/Outdoor",
                                initialValue: widget.indoorOutdoor,
                                isRequired: false,
                                isEditable: false,
                              ),
                              getHeight(15),
                              CustomFormField(
                                label: "EB/N-EB",
                                initialValue: widget.ebNonEb,
                                isRequired: false,
                                isEditable: false,
                              ),
                              getHeight(15),
                              CustomFormField(
                                label: "Operator 1",
                                initialValue: widget.op1Name,
                                isRequired: false,
                                isEditable: false,
                              ),
                              getHeight(15),
                              CustomFormField(
                                label: "Operator 2",
                                initialValue: widget.op2Name,
                                isRequired: false,
                                isEditable: false,
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
                              text: "General",
                              isLeftArrow: true,
                              backgroundColor: AppColors.buttonColorBg,
                              textColor: AppColors.buttonColorSite,
                              onPressed: () {
                                Navigator.pop(context);
                              },
                            ),
                          ),
                          getWidth(14),
                          Expanded(
                            child: ArrowButton(
                              text: "CCU",
                              isLeftArrow: false,
                              backgroundColor: AppColors.buttonColorBackBg,
                              textColor: AppColors.buttonColorTextBg,
                              onPressed: () {
                                pushPage(context, CCUScreen());
                                // if (_validateForm()) {
                                //   showDialog(
                                //     context: context,
                                //     barrierDismissible: false,
                                //     builder: (context) => SuccessDialog(
                                //       ticketId: "UVORKJR00044",
                                //       message:
                                //       "Asset Audit for Site (ID: SITE-38974) has been recorded and saved.",
                                //       onDone: () {
                                //         Navigator.of(context).pop();
                                //         Navigator.of(context).pop();
                                //       },
                                //     ),
                                //   );
                                // } else {
                                //
                                //   ScaffoldMessenger.of(context).showSnackBar(
                                //     SnackBar(
                                //       content: Text(
                                //         uploadedPhotoPath == null || uploadedPhotoPath!.isEmpty
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
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

}
