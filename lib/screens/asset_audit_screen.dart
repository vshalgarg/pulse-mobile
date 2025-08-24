import 'package:app/commonWidgets/custom_buttons/arrow_botton.dart';
import 'package:app/constants/constants_methods.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

import '../commonWidgets/asset_type_card.dart';
import '../commonWidgets/custom_form_appbar.dart';
import '../commonWidgets/custom_form_dropdown.dart';
import '../commonWidgets/custom_form_field.dart';
import '../commonWidgets/custom_radio_options.dart';
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
  int totalItemsToScan = 6; // Total items to scan
  int currentScannedItems = 0; // Number of items already scanned
  List<Map<String, dynamic>> savedItems = []; // List to store saved items
  Map<String, dynamic> currentFormData = {}; // Current form data

  // AssetTypeCard field values
  String? assetCardSerialNumber;
  String? assetCardPhoto;
  String? assetCardStatus;

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

  // Validate required fields for saved items only
  bool _isFormValid() {
    print('=== Form Validation Debug ===');
    
    // Only check serial number and photo for saved items
    // Type, battery status, and file are not required for individual item saving
    
    // Check if serial number is entered in the CustomInfoCard
    print('cctvSerialController.text: "${cctvSerialController.text}"');
    if (cctvSerialController.text.isEmpty) {
      print('❌ Serial number validation failed');
      return false;
    } else {
      print('✅ Serial number validation passed');
    }

    // Check if photo is added
    print('assetCardPhoto: $assetCardPhoto');
    if (assetCardPhoto == null || assetCardPhoto!.isEmpty) {
      print('❌ Photo validation failed');
      return false;
    } else {
      print('✅ Photo validation passed');
    }

    // Note: assetCardStatus is not required since it comes from API
    // and is set to true by default (backendStatus: true)
    print('assetCardStatus: $assetCardStatus (not required)');

    print('✅ All validations passed!');
    return true;
  }

  bool _validateForm() {
    setState(() {
      showValidationErrors = true;
    });

    print('=== Form Validation Debug (_validateForm) ===');

    // Only check serial number and photo for saved items
    // Type, battery status, and file are not required for individual item saving
    
    // Check if serial number is entered in the CustomInfoCard
    print('cctvSerialController.text: "${cctvSerialController.text}"');
    if (cctvSerialController.text.isEmpty) {
      print('❌ Serial number validation failed');
      return false;
    } else {
      print('✅ Serial number validation passed');
    }

    // Check if photo is added
    print('assetCardPhoto: $assetCardPhoto');
    if (assetCardPhoto == null || assetCardPhoto!.isEmpty) {
      print('❌ Photo validation failed');
      return false;
    } else {
      print('✅ Photo validation passed');
    }

    // Note: assetCardStatus is not required since it comes from API
    // and is set to true by default (backendStatus: true)
    print('assetCardStatus: $assetCardStatus (not required)');

    print('Final validation result: true');
    return true;
  }

  // Save current form data
  void _saveCurrentForm() {
    print('Attempting to save form...');
    print('Form validation result: ${_isFormValid()}');
    print('cctvSerialController text: "${cctvSerialController.text}"');
    print('assetCardSerialNumber: $assetCardSerialNumber');
    print('assetCardPhoto: $assetCardPhoto');
    print('assetCardStatus: $assetCardStatus');
    
    if (_isFormValid()) {
      setState(() {
        // Create a map of current form data
        Map<String, dynamic> currentFormData = {
          'serialNumber': assetCardSerialNumber,
          'photo': assetCardPhoto,
          'status': assetCardStatus ?? "OK", // Default to "OK" if null (since it comes from API)
          'timestamp': DateTime.now(),
        };

        print('Saving item: $currentFormData');
        print('Current savedItems count: ${savedItems.length}');

        // Add to saved items list
        savedItems.add(currentFormData);
        currentScannedItems++;

        print('After saving - savedItems count: ${savedItems.length}');
        print('currentScannedItems: $currentScannedItems');

        // Clear AssetTypeCard form for next entry
        assetCardSerialNumber = null;
        assetCardPhoto = null;
        assetCardStatus = null;

        // Clear the controller
        cctvSerialController.clear();

        hasUnsavedChanges = false;
        showValidationErrors = false;
      });

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Item saved successfully!',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontFamily: fontFamilyMontserrat,
            ),
          ),
          backgroundColor: AppColors.primaryGreen,
          duration: Duration(seconds: 2),
        ),
      );
    } else {
      print('Form validation failed - cannot save item');
    }
  }

  // Check if all items are scanned
  bool _isAllItemsScanned() {
    return currentScannedItems >= totalItemsToScan;
  }

  // Format serial number to show first 5 digits + ...
  String _formatSerialNumber(String serialNumber) {
    if (serialNumber.length <= 7) {
      return serialNumber;
    }
    return "${serialNumber.substring(0, 5)}...";
  }

  // Edit a specific item from the saved list
  void _editItem(Map<String, dynamic> item) {
    setState(() {
      // Load the item data back into the form
      assetCardSerialNumber = item["serialNumber"];
      assetCardPhoto = item["photo"];
      assetCardStatus = item["status"];

      // Set the serial controller text
      cctvSerialController.text = item["serialNumber"] ?? "";

      // Remove the item from saved items
      savedItems.remove(item);
      currentScannedItems--;

      hasUnsavedChanges = true;
    });

    // Force rebuild to update CustomInfoCard with new initial values
    setState(() {});

    // Show message to user
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Item loaded for editing. Make changes and save again.',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontFamily: fontFamilyMontserrat,
          ),
        ),
        backgroundColor: AppColors.primaryGreen,
        duration: Duration(seconds: 2),
      ),
    );
  }

  // final List<FieldConfig> cardFields = [
  //   // FieldConfig(
  //   //   type: FieldType.textField,
  //   //   label: "Circle",
  //   //   initialValue: "Haryana",
  //   //   isRequired: true,
  //   //   isEditable: false,
  //   // ),
  //   // FieldConfig(
  //   //   type: FieldType.textField,
  //   //   label: "Cluster",
  //   //   initialValue: "Haryana",
  //   //   isRequired: false,
  //   //   isEditable: true,
  //   // ),
  //   FieldConfig(
  //     type: FieldType.serial,
  //     label: "ACDB - Serial Number",
  //     controller: TextEditingController(),
  //   ),
  //   FieldConfig(
  //     type: FieldType.upload,
  //     label: "Customer Photo",
  //     isRequired: true,
  //   ),
  //   FieldConfig(
  //     type: FieldType.optionSelector,
  //     label: "Battery ODC Lock status",
  //     isRequired: true,
  //     options: [
  //       OptionItem(
  //         value: "yes",
  //         label: "Yes",
  //         selectedIcon: Icons.check_circle,
  //         unselectedIcon: Icons.circle_outlined,
  //       ),
  //       OptionItem(
  //         value: "no",
  //         label: "No",
  //         selectedIcon: Icons.cancel,
  //         unselectedIcon: Icons.circle_outlined,
  //       ),
  //     ],
  //   ),
  // ];

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
                              if (showValidationErrors && selectedType == null)
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
                              // Count Field
                              CustomFormField(
                                label:
                                    "Number of ${selectedType ?? 'Batteries'}",
                                initialValue: totalItemsToScan.toString(),
                                isRequired: true,
                                isEditable: true,
                                onChanged: (value) {
                                  setState(() {
                                    totalItemsToScan = int.tryParse(value) ?? 6;
                                    hasUnsavedChanges = true;
                                  });
                                },
                              ),
                              getHeight(10),
                              CustomInfoCard(
                                serialLabel: "CCTV - Serial Number",
                                photoLabel: "Add a Photo",
                                statusLabel: "Status",
                                serialController: cctvSerialController,
                                onSave: _saveCurrentForm,
                                isStatusEditable: false,
                                backendStatus: true,
                                onPhotoTap: (photoPath) {
                                  setState(() {
                                    assetCardPhoto = photoPath;
                                    hasUnsavedChanges = true;
                                  });
                                },
                                onStatusChanged: (val) {
                                  setState(() {
                                    assetCardStatus = val ? "OK" : "Not OK";
                                    hasUnsavedChanges = true;
                                  });
                                },
                                onSerialChanged: (serialNumber) {
                                  setState(() {
                                    assetCardSerialNumber = serialNumber;
                                    hasUnsavedChanges = true;
                                  });
                                },
                                initialStatus: assetCardStatus == "OK"
                                    ? true
                                    : (assetCardStatus == "Not OK"
                                          ? false
                                          : null),
                                initialPhotoPath: assetCardPhoto,
                                isEditable: true,
                              ),

                              // if (!_isAllItemsScanned() &&
                              //     savedItems.isNotEmpty)
                              //   Align(
                              //     alignment: Alignment.centerRight,
                              //     child: Container(
                              //       width:150,
                              //       child: ElevatedButton(
                              //         onPressed: () {
                              //           // Clear form for next scan
                              //           setState(() {
                              //             serialController.clear();
                              //             selectedType = null;
                              //             selectedBatteryStatus = null;
                              //             selectedFile = null;
                              //             hasUnsavedChanges = false;
                              //             showValidationErrors = false;
                              //           });
                              //         },
                              //         style: ElevatedButton.styleFrom(
                              //           backgroundColor: Color(0xFFDBE2F0),
                              //           padding: const EdgeInsets.symmetric(
                              //             vertical: 12,
                              //           ),
                              //           shape: RoundedRectangleBorder(
                              //             borderRadius: BorderRadius.circular(8),
                              //           ),
                              //         ),
                              //         child: Text(
                              //           // (${currentScannedItems}/${totalItemsToScan})
                              //           "Scan More",
                              //           style: const TextStyle(
                              //             color:Color(0xFF2D426E),
                              //             fontSize: 16,
                              //             fontWeight: FontWeight.w600,
                              //             fontFamily: fontFamilyMontserrat,
                              //           ),
                              //         ),
                              //       ),
                              //     ),
                              //   ),
                              if (savedItems.isNotEmpty) ...[
                                _buildSavedItemsList(),
                                getHeight(20),
                              ],

                              getHeight(20),

                              // Save Button
                              if (_validateForm())
                                Container(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: () {
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
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primaryGreen,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: const Text(
                                      "Save",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        fontFamily: fontFamilyMontserrat,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
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

  // Build saved items list
  Widget _buildSavedItemsList() {
    return Column(
      children: [
        // Header Row
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

              ...savedItems
                  .map(
                    (item) {
                      print('Building item row for: $item');
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
                            const Expanded(
                              child: Icon(Icons.check, color: Colors.green),
                            ),
                            Expanded(
                              child: IconButton(
                                icon: const Icon(
                                  Icons.camera_alt,
                                  color: AppColors.color555555,
                                ),
                                onPressed: () {
                                  // handle photo click
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
                                  // handle edit click for this item
                                  _editItem(item);
                                },
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  )
                  .toList(),
            ],
          ),
        ),
      ],
    );
  }
}
