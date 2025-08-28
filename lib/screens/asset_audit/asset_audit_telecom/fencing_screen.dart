import 'package:app/commonWidgets/custom_buttons/arrow_botton.dart';
import 'package:app/constants/constants_methods.dart';
import 'package:app/screens/asset_audit/asset_audit_telecom/battery_screen.dart';
import 'package:app/screens/asset_audit/asset_audit_telecom/dg_screen.dart';
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
import '../../../constants/app_colors.dart';
import '../../../constants/app_images.dart';
import '../../../constants/constants_strings.dart';

class FencingScreen extends StatefulWidget {
  const FencingScreen({super.key});

  @override
  State<FencingScreen> createState() => _FencingScreenState();
}

class _FencingScreenState extends State<FencingScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController serialController = TextEditingController();
  String? selectedCCTVAvailability;
  bool hasUnsavedChanges = false;
  bool showValidationErrors = false;
  int totalCCTVItems = 6;
  int currentScannedItems = 0;
  String? uploadedPhotoPath;
  List<Map<String, dynamic>> savedCCTVItems = [];
  final remarksController = TextEditingController();

  // AssetTypeCard field values for CCTV
  String? cctvSerialNumber;
  String? cctvPhoto;
  String? cctvStatus;

  // Controllers for CustomInfoCard
  final TextEditingController cctvSerialController = TextEditingController();

  // Keys to force rebuild of CustomInfoCard widgets
  int cctvCardKey = 0;

  @override
  void initState() {
    super.initState();
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
      hasUnsavedChanges = selectedCCTVAvailability != null || serialController.text.isNotEmpty;

      if (showValidationErrors && selectedCCTVAvailability != null && serialController.text.isNotEmpty) {
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

  bool _isFormValid() {
    String? serialNumber = cctvSerialController.text.isNotEmpty ? cctvSerialController.text : null;

    if (serialNumber == null || serialNumber.isEmpty) {
      return false;
    }

    String? photo = cctvPhoto;
    if (photo == null || photo.isEmpty) {
      return false;
    }

    return true;
  }

  bool _validateForm() {
    setState(() {
      showValidationErrors = true;
    });

    String? serialNumber = cctvSerialController.text.isNotEmpty ? cctvSerialController.text : null;

    if (serialNumber == null || serialNumber.isEmpty) {
      return false;
    }

    String? photo = cctvPhoto;
    if (photo == null || photo.isEmpty) {
      return false;
    }

    return true;
  }

  // Save current form data for CCTV
  void _saveCCTVForm() {
    if (savedCCTVItems.length >= totalCCTVItems) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Maximum number of CCTV items ($totalCCTVItems) already added.',
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
        Map<String, dynamic> currentFormData = {
          'serialNumber': cctvSerialNumber,
          'photo': cctvPhoto,
          'status': cctvStatus ?? "OK",
          'timestamp': DateTime.now(),
        };

        savedCCTVItems.add(currentFormData);
        currentScannedItems++;

        // Clear form for next entry
        cctvSerialNumber = null;
        cctvPhoto = null;
        cctvStatus = null;
        cctvSerialController.clear();
        cctvCardKey++;

        hasUnsavedChanges = false;
        showValidationErrors = false;
      });

      int remainingCCTVs = totalCCTVItems - savedCCTVItems.length;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'CCTV item saved successfully! ${remainingCCTVs > 0 ? '(${remainingCCTVs} remaining)' : '(All items added)'}',
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
    }
  }

  // Check if all items are scanned
  bool _isAllItemsScanned() {
    return savedCCTVItems.length >= totalCCTVItems;
  }

  // Format serial number to show first 5 digits + ...
  String _formatSerialNumber(String serialNumber) {
    if (serialNumber.length <= 7) {
      return serialNumber;
    }
    return "${serialNumber.substring(0, 5)}...";
  }

  // Edit a specific CCTV item from the saved list
  void _editItem(Map<String, dynamic> item) {
    setState(() {
      cctvSerialNumber = item["serialNumber"];
      cctvPhoto = item["photo"];
      cctvStatus = item["status"];
      cctvSerialController.text = item["serialNumber"] ?? "";
      savedCCTVItems.remove(item);
      currentScannedItems--;
      cctvCardKey++;
      hasUnsavedChanges = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'CCTV item loaded for editing. Make changes and save again.',
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
                              CustomOptionSelector(
                                label: "Boundary/Fencing",
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
                                  setState(() {
                                    selectedCCTVAvailability = value;
                                    hasUnsavedChanges = true;
                                  });
                                },
                              ),
                              // getHeight(15),
                              // CustomFormField(
                              //   label: "Count of CCTV",
                              //   initialValue: totalCCTVItems.toString(),
                              //   isRequired: false,
                              //   isEditable: false,
                              //   onChanged: (value) {
                              //     setState(() {
                              //       totalCCTVItems = int.tryParse(value) ?? 6;
                              //       hasUnsavedChanges = true;
                              //     });
                              //   },
                              // ),
                              getHeight(15),
                              CustomInfoCard(
                                key: ValueKey('cctv_$cctvCardKey'),
                                serialLabel: "Fencing / Boundary",
                                serialHintText: "Fencing",
                                photoLabel: "Add a Photo",
                                statusLabel: "Status",
                                serialController: cctvSerialController,
                                // onSave: _saveCCTVForm,
                                showSaveButton: false,
                                isStatusEditable: true,
                                backendStatus: false,
                                onPhotoTap: (photoPath) {
                                  setState(() {
                                    cctvPhoto = photoPath;
                                    hasUnsavedChanges = true;
                                  });
                                },
                                onStatusChanged: (val) {
                                  setState(() {
                                    cctvStatus = val ? "OK" : "Not OK";
                                    hasUnsavedChanges = true;
                                  });
                                },
                                onSerialChanged: (serialNumber) {
                                  setState(() {
                                    cctvSerialNumber = serialNumber;
                                    hasUnsavedChanges = true;
                                  });
                                },
                                initialStatus: cctvStatus == "OK"
                                    ? true
                                    : (cctvStatus == "Not OK" ? false : null),
                                initialPhotoPath: cctvPhoto,
                                isEditable: true,
                              ),
                              // getHeight(8),
                              // _buildCCTVSavedItemsList(),
                              getHeight(15),
                              ImageUploadField(
                                label: "Overall Site Photos/Videos",
                                placeholder: "Add Photo",
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
                                  } else {
                                    setState(() {
                                      uploadedPhotoPath = null;
                                    });
                                  }
                                },
                              ),
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
                              text: "Surveillance",
                              isLeftArrow: true,
                              backgroundColor: AppColors.buttonColorBackBg,
                              textColor: AppColors.buttonColorTextBg,
                              onPressed: () {
                                Navigator.pop(context);
                              },
                            ),
                          ),
                          getWidth(14),
                          Expanded(
                            child: ArrowButton(
                              text: "DG",
                              isLeftArrow: false,
                              backgroundColor: AppColors.buttonColorBg,
                              textColor: AppColors.buttonColorSite,
                              onPressed: () {
                                pushPage(context, DgScreen());
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

  // Build CCTV saved items list
  Widget _buildCCTVSavedItemsList() {
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
              if (savedCCTVItems.isNotEmpty) ...[
                ...savedCCTVItems.map((item) {
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
