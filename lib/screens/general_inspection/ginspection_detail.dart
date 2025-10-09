import 'dart:convert';
import 'dart:io';

import 'package:app/commonWidgets/custom_form_appbar.dart';
import 'package:app/commonWidgets/custom_form_field.dart';
import 'package:app/commonWidgets/custom_image_upload_field.dart';
import 'package:app/commonWidgets/custom_remark.dart';
import 'package:app/commonWidgets/custom_submit_button_v2.dart';
import 'package:app/constants/app_colors.dart';
import 'package:app/constants/app_images.dart';
import 'package:app/constants/constants_methods.dart';
import 'package:app/constants/constants_strings.dart';
import 'package:app/enum/corrective_maintenance_screen_mode_enum.dart';
import 'package:app/models/all_site_model.dart';
import 'package:app/models/cm_site_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

class GInspectionDetailScreen extends StatefulWidget {
  final AllSiteModel siteData;
  final CMScreenModeEnum mode;

  const GInspectionDetailScreen({
    super.key,
    required this.siteData,
    required this.mode,
  });

  @override
  State<GInspectionDetailScreen> createState() => _GInspectionDetailScreenState();
}

class _GInspectionDetailScreenState extends State<GInspectionDetailScreen> {
  final TextEditingController _infraEngineerController = TextEditingController();
  final TextEditingController _infraEngineerContactController = TextEditingController();
  final TextEditingController _ownerController = TextEditingController();
  final TextEditingController _ownerContactController = TextEditingController();

  bool _isSubmitting = false;
  File? customerPhoto;
  String? customerPhotoByteData;

  @override
  void initState() {
    super.initState();
    _initializeFormData();
  }

  void _initializeFormData() {
    // Initialize form fields with site data
    _infraEngineerController.text = "Suresh"; // Default value as shown in image
    _infraEngineerContactController.text = "9327490188"; // Default value as shown in image
    _ownerController.text = "Prashant"; // Default value as shown in image
    _ownerContactController.text = "9327490188"; // Default value as shown in image
  }

  @override
  void dispose() {
    _infraEngineerController.dispose();
    _infraEngineerContactController.dispose();
    _ownerController.dispose();
    _ownerContactController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      resizeToAvoidBottomInset: true,
      appBar: CustomFormAppbar(
        title: "General Inspection",
        onClose: () => Navigator.of(context).pop(),
      ),
      body: Stack(
        children: [
          // Background
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
                    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.of(context).viewInsets.bottom + 100,
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [_buildFormFields()],
                      ),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  child: CustomSubmitButtonV2(
                    text: "Next",
                    onPressed: widget.mode == CMScreenModeEnum.view ? null : _submitForm,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormFields() {
    return Column(
      children: [
        // Circle/State
        CustomFormField(
          label: "Circle/State",
          initialValue: widget.siteData.circleStateName,
          isRequired: false,
          isEditable: false,
        ),
        const SizedBox(height: 15),

        // Cluster/District
        CustomFormField(
          label: "Cluster/District",
          initialValue: widget.siteData.clusterDistrictName,
          isRequired: false,
          isEditable: false,
        ),
        const SizedBox(height: 15),

        // Site Code
        CustomFormField(
          label: "Site Code",
          initialValue: widget.siteData.siteCode,
          isRequired: false,
          isEditable: false,
        ),
        const SizedBox(height: 15),

        // Site Name
        CustomFormField(
          label: "Site Name",
          initialValue: widget.siteData.siteName,
          isRequired: false,
          isEditable: false,
        ),
        const SizedBox(height: 15),

        // Customer
        CustomFormField(
          label: "Customer",
          initialValue: widget.siteData.clientName ?? "N/A",
          isRequired: false,
          isEditable: false,
        ),
        const SizedBox(height: 15),

        // Infra Engineer
        CustomFormField(
          label: "Infra Engineer",
          controller: _infraEngineerController,
          isRequired: false,
          isEditable: widget.mode != CMScreenModeEnum.view,
        ),
        const SizedBox(height: 15),

        // Infra Engineer Contact No.
        CustomFormField(
          label: "Infra Engineer Contact No.",
          controller: _infraEngineerContactController,
          isRequired: false,
          isEditable: widget.mode != CMScreenModeEnum.view,
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 15),

        // Owner
        CustomFormField(
          label: "Owner",
          controller: _ownerController,
          isRequired: false,
          isEditable: widget.mode != CMScreenModeEnum.view,
        ),
        const SizedBox(height: 15),

        // Owner Contact No.
        CustomFormField(
          label: "Owner Contact No.",
          controller: _ownerContactController,
          isRequired: false,
          isEditable: widget.mode != CMScreenModeEnum.view,
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 20),

        // Add a Selfie Section
        ImageUploadField(
          label: "Add a Selfie",
          placeholder: "Selfie",
          isRequired: true,
          onImageSelected: (File? file) async {
            if (file != null) {
              setState(() async {
                customerPhoto = file;
                customerPhotoByteData = await file.readAsBytes().then(
                  (bytes) => base64Encode(bytes),
                );
              });
            }
          },
          externalImageUrl: customerPhotoByteData,
          isDisabled: widget.mode == CMScreenModeEnum.view,
        ),
        getHeight(15),
      ],
    );
  }

  void _submitForm() {
    if (customerPhoto == null) {
      showCustomToast(context, "Please add a selfie");
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    // TODO: Implement form submission logic
    Future.delayed(const Duration(seconds: 2), () {
      setState(() {
        _isSubmitting = false;
      });
      showCustomToast(context, "General inspection data saved successfully");
      Navigator.of(context).pop();
    });
  }
}
