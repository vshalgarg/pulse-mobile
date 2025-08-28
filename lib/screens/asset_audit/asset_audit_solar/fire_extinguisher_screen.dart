import 'package:app/commonWidgets/custom_buttons/arrow_botton.dart';
import 'package:app/constants/constants_methods.dart';
import 'package:app/screens/asset_audit/asset_audit_solar/solar_survelliance_screen.dart';
import 'package:app/screens/asset_audit/asset_audit_telecom/battery_screen.dart';
import 'package:app/screens/asset_audit/asset_audit_telecom/solar_plates.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

import '../../../commonWidgets/asset_type_card.dart';
import '../../../commonWidgets/custom_dialogs/success_dialog.dart';
import '../../../commonWidgets/custom_dialogs/unsaved_changes_dialog.dart';
import '../../../commonWidgets/custom_form_appbar.dart';
import '../../../commonWidgets/custom_form_field.dart';
import '../../../commonWidgets/custom_image_upload_field.dart';
import '../../../commonWidgets/custom_radio_options.dart';
import '../../../commonWidgets/custom_remark.dart';
import '../../../commonWidgets/qr_screen_form_field.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_images.dart';
import '../../../constants/constants_strings.dart';

class FireExtinguisherScreen extends StatefulWidget {
  const FireExtinguisherScreen({super.key});

  @override
  State<FireExtinguisherScreen> createState() => _FireExtinguisherScreenState();
}

class _FireExtinguisherScreenState extends State<FireExtinguisherScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController serialController = TextEditingController();
  String? selectedFile;
  String? selectedStatus;
  String? selectedBatteryStatus;
  String? selectedType;
  bool hasUnsavedChanges = false;
  bool showValidationErrors = false; // Control when to show validation errors
  int totalRectifierItems = 6; // Total rectifier items to scan
  int totalMPPTItems = 6; // Total MPPT items to scan
  int currentScannedItems = 0; // Number of items already scanned
  List<Map<String, dynamic>> savedRectifierItems = []; // List to store saved rectifier items
  List<Map<String, dynamic>> savedMPPTItems = []; // List to store saved MPPT items
  Map<String, dynamic> currentFormData = {}; // Current form data
  String? uploadedPhotoPath;
  // AssetTypeCard field values for Rectifier
  String? rectifierSerialNumber;
  String? rectifierPhoto;
  String? rectifierStatus;
  final remarksController = TextEditingController();
  // AssetTypeCard field values for MPPT
  String? mpptSerialNumber;
  String? mpptPhoto;
  String? mpptStatus;

  // Controllers for CustomInfoCard
  final TextEditingController rectifierSerialController = TextEditingController();
  final TextEditingController mpptSerialController = TextEditingController();

  // Keys to force rebuild of CustomInfoCard widgets
  int rectifierCardKey = 0;
  int mpptCardKey = 0;

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
    rectifierSerialController.dispose();
    mpptSerialController.dispose();
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
    // Check both controllers to see which one has data
    String? serialNumber = rectifierSerialController.text.isNotEmpty
        ? rectifierSerialController.text
        : mpptSerialController.text.isNotEmpty
        ? mpptSerialController.text
        : null;

    print('Serial number: "$serialNumber"');
    if (serialNumber == null || serialNumber.isEmpty) {
      print(' Serial number validation failed');
      return false;
    } else {
      print('✅ Serial number validation passed');
    }

    // Check if photo is added
    // Check both photo variables to see which one has data
    String? photo = rectifierPhoto ?? mpptPhoto;
    print('Photo: $photo');
    if (photo == null || photo.isEmpty) {
      print(' Photo validation failed');
      return false;
    } else {
      print('Photo validation passed');
    }

    // Note: status is not required since it comes from API
    // and is set to true by default (backendStatus: true)
    String? status = rectifierStatus ?? mpptStatus;
    print('Status: $status (not required)');

    print(' All validations passed!');
    return true;
  }

  bool _validateForm() {
    setState(() {
      showValidationErrors = true;
    });

    print('=== Form Validation Debug (_validateForm) ===');
    String? serialNumber = rectifierSerialController.text.isNotEmpty
        ? rectifierSerialController.text
        : mpptSerialController.text.isNotEmpty
        ? mpptSerialController.text
        : null;

    print('Serial number: "$serialNumber"');
    if (serialNumber == null || serialNumber.isEmpty) {
      print(' Serial number validation failed');
      return false;
    } else {
      print(' Serial number validation passed');
    }

    // Check if photo is added
    // Check both photo variables to see which one has data
    String? photo = rectifierPhoto ?? mpptPhoto;
    print('Photo: $photo');
    if (photo == null || photo.isEmpty) {
      print(' Photo validation failed');
      return false;
    } else {
      print(' Photo validation passed');
    }

    // Note: status is not required since it comes from API
    // and is set to true by default (backendStatus: true)
    String? status = rectifierStatus ?? mpptStatus;
    print('Status: $status (not required)');

    print('Final validation result: true');
    return true;
  }

  // Save current form data for Rectifier
  void _saveRectifierForm() {
    // Check if we've reached the limit for rectifier items
    if (savedRectifierItems.length >= totalRectifierItems) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Maximum number of Rectifier items ($totalRectifierItems) already added.',
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
      setState(() {
        // Create a map of current form data
        Map<String, dynamic> currentFormData = {
          'serialNumber': rectifierSerialNumber,
          'photo': rectifierPhoto,
          'status': rectifierStatus ?? "OK", // Default to "OK" if null (since it comes from API)
          'timestamp': DateTime.now(),
        };

        print('Saving Rectifier item: $currentFormData');
        print('Current savedRectifierItems count: ${savedRectifierItems.length}');

        // Add to saved rectifier items list
        savedRectifierItems.add(currentFormData);
        currentScannedItems++;

        print('After saving - savedRectifierItems count: ${savedRectifierItems.length}');
        print('currentScannedItems: $currentScannedItems');

        // Clear AssetTypeCard form for next entry
        rectifierSerialNumber = null;
        rectifierPhoto = null;
        rectifierStatus = null;

        // Clear the controller
        rectifierSerialController.clear();

        // Force rebuild of the CustomInfoCard widget
        rectifierCardKey++;

        hasUnsavedChanges = false;
        showValidationErrors = false;
      });

      // Show success message
      int remainingRectifiers = totalRectifierItems - savedRectifierItems.length;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Rectifier item saved successfully! ${remainingRectifiers > 0 ? '(${remainingRectifiers} remaining)' : '(All items added)'}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontFamily: fontFamilyMontserrat,
            ),
          ),
          backgroundColor: AppColors.primaryGreen,
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      print('Form validation failed - cannot save rectifier item');
    }
  }

  // Save current form data for MPPT
  void _saveMPPTForm() {
    // Check if we've reached the limit for MPPT items
    if (savedMPPTItems.length >= totalMPPTItems) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Maximum number of MPPT items ($totalMPPTItems) already added.',
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
      setState(() {
        // Create a map of current form data
        Map<String, dynamic> currentFormData = {
          'serialNumber': mpptSerialNumber,
          'photo': mpptPhoto,
          'status': mpptStatus ?? "OK", // Default to "OK" if null (since it comes from API)
          'timestamp': DateTime.now(),
        };

        print('Saving MPPT item: $currentFormData');
        print('Current savedMPPTItems count: ${savedMPPTItems.length}');

        // Add to saved MPPT items list
        savedMPPTItems.add(currentFormData);
        currentScannedItems++;

        print('After saving - savedMPPTItems count: ${savedMPPTItems.length}');
        print('currentScannedItems: $currentScannedItems');

        // Clear AssetTypeCard form for next entry
        mpptSerialNumber = null;
        mpptPhoto = null;
        mpptStatus = null;

        // Clear the controller
        mpptSerialController.clear();

        // Force rebuild of the CustomInfoCard widget
        mpptCardKey++;

        hasUnsavedChanges = false;
        showValidationErrors = false;
      });

      // Show success message
      int remainingMPPTs = totalMPPTItems - savedMPPTItems.length;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'MPPT item saved successfully! ${remainingMPPTs > 0 ? '(${remainingMPPTs} remaining)' : '(All items added)'}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontFamily: fontFamilyMontserrat,
            ),
          ),
          backgroundColor: AppColors.primaryGreen,
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      print('Form validation failed - cannot save MPPT item');
    }
  }

  // Check if all items are scanned
  bool _isAllItemsScanned() {
    return (savedRectifierItems.length >= totalRectifierItems) &&
        (savedMPPTItems.length >= totalMPPTItems);
  }

  // Format serial number to show first 5 digits + ...
  String _formatSerialNumber(String serialNumber) {
    if (serialNumber.length <= 7) {
      return serialNumber;
    }
    return "${serialNumber.substring(0, 5)}...";
  }

  // Edit a specific Rectifier item from the saved list
  void _editItem(Map<String, dynamic> item) {
    setState(() {
      // Load the item data back into the form
      rectifierSerialNumber = item["serialNumber"];
      rectifierPhoto = item["photo"];
      rectifierStatus = item["status"];

      // Set the serial controller text
      rectifierSerialController.text = item["serialNumber"] ?? "";

      // Remove the item from saved rectifier items
      savedRectifierItems.remove(item);
      currentScannedItems--;

      // Force rebuild of the CustomInfoCard widget with new data
      rectifierCardKey++;

      hasUnsavedChanges = true;
    });

    // Show message to user
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Rectifier item loaded for editing. Make changes and save again.',
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

  // Edit a specific MPPT item from the saved list
  void _editMPPTItem(Map<String, dynamic> item) {
    setState(() {
      // Load the item data back into the form
      mpptSerialNumber = item["serialNumber"];
      mpptPhoto = item["photo"];
      mpptStatus = item["status"];

      // Set the serial controller text
      mpptSerialController.text = item["serialNumber"] ?? "";

      // Remove the item from saved MPPT items
      savedMPPTItems.remove(item);
      currentScannedItems--;

      // Force rebuild of the CustomInfoCard widget with new data
      mpptCardKey++;

      hasUnsavedChanges = true;
    });

    // Show message to user
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'MPPT item loaded for editing. Make changes and save again.',
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
                              CustomOptionSelector(
                                label: "Fire Extinguisher Availability (Yes/No)",
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
                              CustomFormField(
                                label:"Count of Fire Extinguisher",
                                // "Number of ${selectedType ?? 'Batteries'}",
                                initialValue: totalMPPTItems.toString(),
                                isRequired: true,
                                isEditable: true,
                                onChanged: (value) {
                                  setState(() {
                                    totalMPPTItems = int.tryParse(value) ?? 6;
                                    hasUnsavedChanges = true;
                                  });
                                },
                              ),
                              getHeight(15),
                              Text(
                                "Fire Extinguisher Details",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white,
                                  fontFamily: fontFamilyMontserrat,
                                ),
                              ),
                              getHeight(3),
                              CustomInfoCard(
                                key: ValueKey('fire_extinguisher_$rectifierCardKey'),
                                serialLabel: "Fire Extinguisher - Serial Number *",
                                serialHintText: "Fire Extinguisher Serial Number",
                                photoLabel: "Add a Photo",
                                statusLabel: "Status",
                                serialController: rectifierSerialController,
                                // showSaveButton: false,
                                onSave: _saveRectifierForm,
                                isStatusEditable: true,
                                backendStatus: false,
                                remarksLabel: "Capacity of Fire Extinguisher (In Kg)",
                                remarksHintText: "Eg:200 kg",
                                remarksController: remarksController,
                                onPhotoTap: (photoPath) {
                                  setState(() {
                                    rectifierPhoto = photoPath;
                                    hasUnsavedChanges = true;
                                  });
                                },
                                onStatusChanged: (val) {
                                  setState(() {
                                    rectifierStatus = val ? "OK" : "Not OK";
                                    hasUnsavedChanges = true;
                                  });
                                },
                                onSerialChanged: (serialNumber) {
                                  setState(() {
                                    rectifierSerialNumber = serialNumber;
                                    hasUnsavedChanges = true;
                                  });
                                },
                                initialStatus: rectifierStatus == "OK"
                                    ? true
                                    : (rectifierStatus == "Not OK"
                                    ? false
                                    : null),
                                initialPhotoPath: rectifierPhoto,
                                isEditable: true,
                              ),
                              getHeight(8),
                              _buildRectifierSavedItemsList(),
                              CustomOptionSelector(
                                label: "Flood Light Availability",
                                isRequired: false,
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
                              CustomInfoCard(
                                key: ValueKey('flood_light_$rectifierCardKey'),
                                serialLabel: "Flood Light - Serial Number",
                                serialHintText: "Flood Light Serial Number",
                                photoLabel: "Add a Photo",
                                statusLabel: "Status",
                                serialController: rectifierSerialController,
                                showSaveButton: false,
                                // onSave: _saveRectifierForm,
                                isStatusEditable: true,
                                backendStatus: false,
                                remarksLabel: "Capacity of Fire Extinguisher (In Kg)",
                                remarksHintText: "Eg:200 kg",
                                remarksController: remarksController,
                                onPhotoTap: (photoPath) {
                                  setState(() {
                                    rectifierPhoto = photoPath;
                                    hasUnsavedChanges = true;
                                  });
                                },
                                onStatusChanged: (val) {
                                  setState(() {
                                    rectifierStatus = val ? "OK" : "Not OK";
                                    hasUnsavedChanges = true;
                                  });
                                },
                                onSerialChanged: (serialNumber) {
                                  setState(() {
                                    rectifierSerialNumber = serialNumber;
                                    hasUnsavedChanges = true;
                                  });
                                },
                                initialStatus: rectifierStatus == "OK"
                                    ? true
                                    : (rectifierStatus == "Not OK"
                                    ? false
                                    : null),
                                initialPhotoPath: rectifierPhoto,
                                isEditable: true,
                              ),
                              getHeight(15),
                              CustomFormField(
                                label:"Count of Sand Buckets ",
                                // "Number of ${selectedType ?? 'Batteries'}",
                                initialValue: totalMPPTItems.toString(),
                                isRequired: true,
                                isEditable: true,
                                onChanged: (value) {
                                  setState(() {
                                    totalMPPTItems = int.tryParse(value) ?? 6;
                                    hasUnsavedChanges = true;
                                  });
                                },
                              ),
                              getHeight(15),
                              // Text(
                              //   "MPPT Details",
                              //   style: TextStyle(
                              //     fontSize: 16,
                              //     fontWeight: FontWeight.w500,
                              //     color: Colors.white,
                              //     fontFamily: fontFamilyMontserrat,
                              //   ),
                              // ),
                              // getHeight(3),
                              CustomInfoCard(
                                key: ValueKey('mppt_$mpptCardKey'),
                                serialLabel: "Sand Buckets - Serial Number",
                                serialHintText: "Sand Buckets Serial Number",
                                photoLabel: "Add a Photo",
                                statusLabel: "Status",
                                serialController: mpptSerialController,
                                onSave: _saveMPPTForm,
                                isStatusEditable: true,
                                backendStatus: false,
                                // remarksLabel: "Capacity",
                                // remarksHintText: "Eg:200",
                                // remarksController: remarksController,
                                onPhotoTap: (photoPath) {
                                  setState(() {
                                    mpptPhoto = photoPath;
                                    hasUnsavedChanges = true;
                                  });
                                },
                                onStatusChanged: (val) {
                                  setState(() {
                                    mpptStatus = val ? "OK" : "Not OK";
                                    hasUnsavedChanges = true;
                                  });
                                },
                                onSerialChanged: (serialNumber) {
                                  setState(() {
                                    mpptSerialNumber = serialNumber;
                                    hasUnsavedChanges = true;
                                  });
                                },
                                initialStatus: mpptStatus == "OK"
                                    ? true
                                    : (mpptStatus == "Not OK"
                                    ? false
                                    : null),
                                initialPhotoPath: mpptPhoto,
                                isEditable: true,
                              ),
                              getHeight(8),
                              _buildMPPTSavedItemsList(),
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
                              text: "SCADA",
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
                              text: "Surveillance",
                              isLeftArrow: false,
                              backgroundColor: AppColors.buttonColorBackBg,
                              textColor: AppColors.buttonColorTextBg,
                              onPressed: () {
                                pushPage(context, SolarSurveillanceScreen());
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



  // Build Rectifier saved items list
  Widget _buildRectifierSavedItemsList() {
    return Column(
      children: [
        // Header Row - Always show
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

              // Items - Only show if list is not empty
              if (savedRectifierItems.isNotEmpty) ...[
                ...savedRectifierItems
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
            ],
          ),
        ),
      ],
    );
  }

  // Build MPPT saved items list
  Widget _buildMPPTSavedItemsList() {
    return Column(
      children: [
        // Header Row - Always show
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

              // Items - Only show if list is not empty
              if (savedMPPTItems.isNotEmpty) ...[
                ...savedMPPTItems
                    .map(
                      (item) {
                    print('Building MPPT item row for: $item');
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
                                _editMPPTItem(item);
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
            ],
          ),
        ),
      ],
    );
  }
}
