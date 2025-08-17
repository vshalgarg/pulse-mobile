import 'package:app/commonWidgets/custom_buttons/arrow_botton.dart';
import 'package:app/constants/constants_methods.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

import '../commonWidgets/custom_form_appbar.dart';
import '../commonWidgets/custom_form_dropdown.dart';
import '../commonWidgets/custom_form_field.dart';
import '../commonWidgets/custom_image_upload_field.dart';
import '../commonWidgets/custom_radio_options.dart';
import '../commonWidgets/qr_screen_form_field.dart';
import '../constants/app_colors.dart';
import '../constants/app_images.dart';
import '../commonWidgets/custom_file_upload.dart';
import '../commonWidgets/custom_dialogs/unsaved_changes_dialog.dart';
import '../commonWidgets/custom_dialogs/success_dialog.dart';

class AssetAuditScreen extends StatefulWidget {
  const AssetAuditScreen({super.key});

  @override
  State<AssetAuditScreen> createState() => _AssetAuditScreenState();
}

class _AssetAuditScreenState extends State<AssetAuditScreen> {
  final TextEditingController serialController = TextEditingController();
  String? selectedFile;
  String? selectedStatus;
  String? selectedBatteryStatus;
  bool hasUnsavedChanges = false;

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
    super.dispose();
  }

  void _onFormChanged() {
    setState(() {
      hasUnsavedChanges = selectedFile != null || 
                         selectedStatus != null || 
                         selectedBatteryStatus != null ||
                         serialController.text.isNotEmpty;
    });
  }

  void _saveAndExit() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => SuccessDialog(
        ticketId: "UVORKJR00044",
        message: "Asset Audit for Site (ID: SITE-38974) has been recorded and saved.",
        onDone: () {
          Navigator.of(context).pop();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !hasUnsavedChanges,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        
        if (hasUnsavedChanges) {
          // Show unsaved changes dialog
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => UnsavedChangesDialog(
              title: "Unsaved Changes",
              message: "Do you want to cancel the Asset Audit for Site (ID: SITE-38974) ?",
              onSaveAndExit: () {
                // Save the data and exit
                _saveAndExit();
              },
              onDiscard: () {
                // Discard changes and exit
                Navigator.of(context).pop();
              },
            ),
          );
        }
      },
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: CustomFormAppbar(
          title: "Asset Audit",
          onClose: () async {
            if (hasUnsavedChanges) {
              // Show unsaved changes dialog
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => UnsavedChangesDialog(
                  title: "Unsaved Changes",
                  message: "Do you want to cancel the Asset Audit for Site (ID: SITE-38974) ?",
                  onSaveAndExit: () {
                    // Save the data and exit
                    _saveAndExit();
                  },
                  onDiscard: () {
                    // Discard changes and exit
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
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: Container(
                        padding: const EdgeInsets.only(
                          top: 20,
                          left: 16,
                          right: 16,
                          bottom: 20,
                        ),
                        child: IntrinsicHeight(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CustomFormField(
                                label: "Circle",
                                initialValue: "Haryana",
                                isRequired: true,
                                isEditable: false,
                              ),
                              getHeight(15),
                              CustomFormField(
                                label: "Cluster",
                                initialValue: "Haryana",
                                isRequired: false,
                                isEditable: true,
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
                                      hasUnsavedChanges = true;
                                    });
                                  }
                                },
                              ),
                              getHeight(15),
                              CustomDropdown(
                                label: "Status",
                                items: const [
                                  "OK",
                                  "Not Applicable",
                                  "Pending",
                                  "Rejected",
                                ],
                                onChanged: (value) {
                                  debugPrint("Selected: $value");
                                  setState(() {
                                    selectedStatus = value;
                                    hasUnsavedChanges = true;
                                  });
                                },
                              ),
                              getHeight(15),
                              CustomOptionSelector(
                                label: "Battery ODC Lock status",
                                isRequired: true,
                                options: [
                                  OptionItem(
                                    value: "yes",
                                    label: "Yes",
                                    selectedIcon: Icons.check_circle,
                                    unselectedIcon: Icons.circle_outlined,
                                  ),
                                  OptionItem(
                                    value: "no",
                                    label: "No",
                                    selectedIcon: Icons.cancel,
                                    unselectedIcon: Icons.circle_outlined,
                                  ),
                                ],
                                onChanged: (value) {
                                  print("Selected: $value");
                                  setState(() {
                                    selectedBatteryStatus = value;
                                    hasUnsavedChanges = true;
                                  });
                                },
                              ),
                              getHeight(15),
                              SerialNumberField(
                                label: "ACDB - Serial Number",
                                controller: serialController,
                              ),
                              getHeight(15),
                              FileUploadBox(
                                label: "Customer Photo",
                                isRequired: true,
                                onUploadTap: () async {
                                  setState(() {
                                    selectedFile = "Customer_Photo.pdf";
                                    hasUnsavedChanges = true;
                                  });
                                },
                                fileName: selectedFile,
                                onDelete: () {
                                  setState(() {
                                    selectedFile = null;
                                    hasUnsavedChanges = true;
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(16),
                    child: ArrowButton(
                      text: "Hygiene",
                      isLeftArrow: false,
                      backgroundColor: AppColors.buttonColorBg,
                      textColor: AppColors.buttonColorSite,
                      onPressed: () {
                        // Show success dialog when form is completed
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (context) => SuccessDialog(
                            ticketId: "UVORKJR00044",
                            message: "Asset Audit for Site (ID: SITE-38974) has been recorded and saved.",
                            onDone: () {
                              Navigator.of(context).pop();
                              Navigator.of(context).pop();
                            },
                          ),
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
