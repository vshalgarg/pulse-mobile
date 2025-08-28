import 'package:app/commonWidgets/custom_buttons/arrow_botton.dart';
import 'package:app/constants/constants_methods.dart';
import 'package:app/screens/asset_audit/asset_audit_solar/dcba_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

import '../../../commonWidgets/asset_type_card.dart';
import '../../../commonWidgets/custom_dialogs/success_dialog.dart';
import '../../../commonWidgets/custom_dialogs/unsaved_changes_dialog.dart';
import '../../../commonWidgets/custom_form_appbar.dart';
import '../../../commonWidgets/custom_form_field.dart';
import '../../../commonWidgets/custom_remark.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_images.dart';
import '../../../constants/constants_strings.dart';

class MMSScreen extends StatefulWidget {
  const MMSScreen({super.key});

  @override
  State<MMSScreen> createState() => _MMSScreenState();
}

class _MMSScreenState extends State<MMSScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController serialController = TextEditingController();
  bool hasUnsavedChanges = false;
  bool showValidationErrors = false;
  int totalItemsToScan = 6;
  int currentScannedItems = 0;
  List<Map<String, dynamic>> savedItems = [];

  // SPV field values
  String? spvSerialNumber;
  String? spvPhoto;
  String? spvStatus;
  final remarksController = TextEditingController();
  int spvCardKey = 0;
  List<Map<String, dynamic>> savedSpvItems = [];

  // Controllers for CustomInfoCard
  final TextEditingController spvSerialController = TextEditingController();
  int totalSpvItems = 6;

  @override
  void initState() {
    super.initState();
    serialController.addListener(_onFormChanged);
  }

  @override
  void dispose() {
    serialController.removeListener(_onFormChanged);
    serialController.dispose();
    spvSerialController.dispose();
    super.dispose();
  }

  void _onFormChanged() {
    setState(() {
      hasUnsavedChanges = serialController.text.isNotEmpty;

      if (showValidationErrors && serialController.text.isNotEmpty) {
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

  bool _isFormValid() {
    if (spvSerialController.text.isEmpty) {
      return false;
    }

    if (spvPhoto == null || spvPhoto!.isEmpty) {
      return false;
    }

    return true;
  }

  bool _validateForm() {
    setState(() {
      showValidationErrors = true;
    });

    if (spvSerialController.text.isEmpty) {
      return false;
    }

    if (spvPhoto == null || spvPhoto!.isEmpty) {
      return false;
    }

    return true;
  }

  void _saveSpvForm() {
    if (savedSpvItems.length >= totalSpvItems) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Maximum number of SPV items ($totalSpvItems) already added.',
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
          'serialNumber': spvSerialNumber,
          'photo': spvPhoto,
          'status': spvStatus ?? "OK",
          'timestamp': DateTime.now(),
        };

        savedSpvItems.add(currentFormData);
        currentScannedItems++;

        spvSerialNumber = null;
        spvPhoto = null;
        spvStatus = null;

        spvSerialController.clear();

        spvCardKey++;

        hasUnsavedChanges = false;
        showValidationErrors = false;
      });

      int remainingSpv = totalSpvItems - savedSpvItems.length;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'SPV item saved successfully! ${remainingSpv > 0 ? '(${remainingSpv} remaining)' : '(All items added)'}',
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

  String _formatSerialNumber(String serialNumber) {
    if (serialNumber.length <= 7) {
      return serialNumber;
    }
    return "${serialNumber.substring(0, 5)}...";
  }

  void _editItem(Map<String, dynamic> item) {
    setState(() {
      spvSerialNumber = item["serialNumber"];
      spvPhoto = item["photo"];
      spvStatus = item["status"];

      spvSerialController.text = item["serialNumber"] ?? "";

      savedItems.remove(item);
      currentScannedItems--;

      hasUnsavedChanges = true;
    });

    setState(() {});

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
                                label: "Types of MMS",
                                hintText: 'Text',
                                isRequired: true,
                                isEditable: false,
                              ),
                              getHeight(15),
                              CustomFormField(
                                label: "Combined Capacity of MMS",
                                hintText: 'Text',
                                isRequired: true,
                                isEditable: false,
                              ),
                              getHeight(15),
                              CustomRemarksField(
                                label: "Add Remarks",
                                hintText: "Remarks",
                                controller: remarksController,
                              ),

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
                      width: double.infinity,
                      child: Row(
                        children: [
                          Expanded(
                            child: ArrowButton(
                              text: "SPV",
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
                              text: "DCDB",
                              isLeftArrow: false,
                              backgroundColor: AppColors.buttonColorBg,
                              textColor: AppColors.buttonColorSite,
                              onPressed: () {
                                pushPage(context, DCBAScreen());
                                // Navigation to MMS screen
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
