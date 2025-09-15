import 'package:app/commonWidgets/custom_buttons/arrow_botton.dart';
import 'package:app/constants/constants_methods.dart';
import 'package:app/screens/asset_audit/asset_audit_telecom/ccu_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import '../../../models/asset_audit_model.dart';
import '../../../utils/asset_audit_navigation_helper.dart';

import '../../../commonWidgets/custom_dialogs/success_dialog.dart';
import '../../../commonWidgets/custom_dialogs/unsaved_changes_dialog.dart';
import '../../../commonWidgets/custom_form_appbar.dart';
import '../../../commonWidgets/custom_form_field.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_images.dart';
import '../../home_screen.dart';

class SiteInfoScreen extends StatefulWidget {
  final String siteName;
  final String siteTypeName;
  final String indoorOutdoor;
  final String ebNonEb;
  final String op1Name;
  final String op2Name;
  final AssetAuditModel? assetAuditData;
  final String siteType;
  final String auditSchId;
  final String siteAuditSchId;

  const SiteInfoScreen({
    super.key,
    required this.siteName,
    required this.siteTypeName,
    required this.indoorOutdoor,
    required this.ebNonEb,
    required this.op1Name,
    required this.op2Name,
    this.assetAuditData,
    required this.siteType,
    required this.auditSchId,
    required this.siteAuditSchId,
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

  void _navigateToNextScreen() {
    final nextScreen = AssetAuditNavigationHelper.getNextAvailableTelecomScreen(
      widget.assetAuditData, 
      'Site Info'
    );
    
    if (nextScreen != null) {
      AssetAuditNavigationHelper.navigateToNextTelecomScreen(
        context,
        nextScreen,
        widget.siteType,
        widget.auditSchId,
        widget.siteAuditSchId,
        widget.assetAuditData,
      );
    } else {
      // Navigate to home if no next screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => HomeScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !hasUnsavedChanges,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        resizeToAvoidBottomInset: false,
        appBar: CustomFormAppbar(
          title: "Asset Audit",
          onClose: () async {
            if (hasUnsavedChanges) {
              showDialog(
                context: context,
                barrierDismissible: true,
                builder: (dialogContext) => UnsavedChangesDialog(
                  siteAuditSchId: widget.siteAuditSchId,
                  section: "Asset Audit",
                  parentContext: context, // Use the outer context (screen context)
                  onSaveAndExit: () async {
                  },
                  onDiscard: () {
                  },
                ),
              );
            } else {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                    builder: (context) => HomeScreen()
                ),
              );
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
                              getHeight(15),

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
                              text: AssetAuditNavigationHelper.getPreviousAvailableTelecomScreen(
                                widget.assetAuditData, 
                                'Site Info'
                              ) ?? 'BACK',
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
                              text: AssetAuditNavigationHelper.getNextAvailableTelecomScreen(
                                widget.assetAuditData, 
                                'Site Info'
                              ) ?? 'SUBMIT',
                              isLeftArrow: false,
                              backgroundColor: AppColors.buttonColorBackBg,
                              textColor: AppColors.buttonColorTextBg,
                              onPressed: () {
                                _navigateToNextScreen();
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
