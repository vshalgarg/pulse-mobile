import 'package:app/commonWidgets/custom_buttons/arrow_botton.dart';
import 'package:app/constants/constants_methods.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

import '../commonWidgets/custom_form_appbar.dart';
import '../commonWidgets/custom_form_dropdown.dart';
import '../commonWidgets/custom_form_field.dart';
import '../commonWidgets/custom_radio_options.dart';
import '../commonWidgets/dynamic_form_card.dart';
import '../commonWidgets/qr_screen_form_field.dart';
import '../constants/app_colors.dart';
import '../constants/app_images.dart';
import '../commonWidgets/custom_dialogs/unsaved_changes_dialog.dart';
import '../commonWidgets/custom_dialogs/success_dialog.dart';
import '../constants/constants_strings.dart';
import '../models/form_fields_model.dart';

class AssetAuditScreen extends StatefulWidget {
  const AssetAuditScreen({super.key});

  @override
  State<AssetAuditScreen> createState() => _AssetAuditScreenState();
}

class _AssetAuditScreenState extends State<AssetAuditScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController serialController = TextEditingController();
  String? selectedFile;
  String? selectedStatus;
  String? selectedBatteryStatus;
  String? selectedType;
  bool hasUnsavedChanges = false;
  bool showValidationErrors = false; // Control when to show validation errors
  int batteryCount = 3;

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
      hasUnsavedChanges =
          selectedFile != null ||
          selectedStatus != null ||
          selectedBatteryStatus != null ||
          selectedType != null ||
          serialController.text.isNotEmpty;

      // Hide validation errors when user starts filling the form
      if (showValidationErrors &&
          selectedFile != null &&
          selectedBatteryStatus != null &&
          selectedType != null &&
          serialController.text.isNotEmpty) {
        showValidationErrors = false;
      }
    });
  }

  void _saveAndExit() {
    // First close the unsaved changes dialog
    Navigator.of(context).pop();
    
    // Then show success dialog
    showDialog(
      context: context,
      barrierDismissible: false,
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

  bool _validateForm() {
    setState(() {
      showValidationErrors = true;
    });

    // Validate required fields
    bool isValid = true;

    // Check if type is selected
    if (selectedType == null) {
      isValid = false;
    }

    // Check if battery status is selected
    if (selectedBatteryStatus == null) {
      isValid = false;
    }

    // Check if file is uploaded
    if (selectedFile == null) {
      isValid = false;
    }

    // Check if serial number is entered
    if (serialController.text.isEmpty) {
      isValid = false;
    }

    return isValid;
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
        appBar: CustomFormAppbar(
          title: "Asset Audit",
          onClose: () async {
            if (hasUnsavedChanges) {
              // Show unsaved changes dialog
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
                                // Battery/DC Type Dropdown
                                CustomDropdown(
                                  label: "Type",
                                  items: ["Battery", "DC"],
                                  initialValue: selectedType,
                                  onChanged: (value) {
                                    setState(() {
                                      selectedType = value;
                                      hasUnsavedChanges = true;
                                    });
                                  },
                                ),
                                if (showValidationErrors &&
                                    selectedType == null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 5),
                                    child: Text(
                                      'Type selection is required',
                                      style: TextStyle(
                                        color: AppColors.errorColor,
                                        fontSize: 14,
                                        fontFamily: fontFamilyMontserrat,
                                      ),
                                    ),
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
                                // Count Dropdown
                                CustomDropdown(
                                  label:
                                      "Number of ${selectedType ?? 'Batteries'}",
                                  items: ["1", "2", "3", "4"],
                                  initialValue: batteryCount.toString(),
                                  onChanged: (value) {
                                    setState(() {
                                      batteryCount = int.parse(value!);
                                      hasUnsavedChanges = true;
                                    });
                                  },
                                ),
                                getHeight(10),
                                listItems(),
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
                          // Validate form before proceeding
                          if (_validateForm()) {
                            // Show success dialog when form is completed
                            showDialog(
                              context: context,
                              barrierDismissible: false,
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
                          } else {
                            // Show validation error message
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Please fill in all required fields',
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
  }

  final List<FieldConfig> cardFields = [
    FieldConfig(
      type: FieldType.textField,
      label: "Circle",
      initialValue: "Haryana",
      isRequired: true,
      isEditable: false,
    ),
    FieldConfig(
      type: FieldType.serial,
      label: "ACDB - Serial Number",
      controller: TextEditingController(),
    ),
    FieldConfig(
      type: FieldType.upload,
      label: "Customer Photo",
      isRequired: true,
    ),
    FieldConfig(
      type: FieldType.optionSelector,
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
    ),
  ];

  Widget listItems() {
    return Column(
      children: List.generate(batteryCount, (index) {
        // Create dynamic fields with card number in labels
        List<FieldConfig> dynamicFields = [
          // FieldConfig(
          //   type: FieldType.textField,
          //   label: "Circle",
          //   initialValue: "Haryana",
          //   isRequired: true,
          //   isEditable: false,
          // ),
          FieldConfig(
            type: FieldType.serial,
            label: "MPPT No. ${index + 1} - Serial Number",
            controller: TextEditingController(),
          ),
          FieldConfig(
            type: FieldType.upload,
            label: "Customer Photo",
            isRequired: true,
          ),
          FieldConfig(
            type: FieldType.optionSelector,
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
          ),
        ];

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: DynamicFormCard(
            index: index,
            fields: dynamicFields,
            onValueChanged: (fieldLabel, value) {
              print("Card $index -> $fieldLabel: $value");
              setState(() {
                hasUnsavedChanges = true;
              });
            },
          ),
        );
      }),
    );
  }
}
