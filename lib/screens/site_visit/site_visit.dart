import 'dart:convert';
import 'dart:io';

import 'package:app/commonWidgets/custom_buttons/custom_rounded_button.dart';
import 'package:app/commonWidgets/custom_form_appbar.dart';
import 'package:app/commonWidgets/custom_form_field.dart';
import 'package:app/commonWidgets/custom_image_upload_field.dart';
import 'package:app/commonWidgets/custom_remark.dart';
import 'package:app/commonWidgets/custom_submit_button_v2.dart';
import 'package:app/constants/app_colors.dart';
import 'package:app/constants/app_images.dart';
import 'package:app/constants/constants_methods.dart';
import 'package:app/constants/constants_strings.dart';
import 'package:app/models/cm_site_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

class SiteVisitScreen extends StatefulWidget {
  final CMSite siteData;
 

  const SiteVisitScreen({super.key, required this.siteData});

  @override
  State<SiteVisitScreen> createState() => _SiteVisitScreenState();
}

class _SiteVisitScreenState extends State<SiteVisitScreen> {
  final TextEditingController _purposeController = TextEditingController();
  final TextEditingController _infraEngineerController =
      TextEditingController();
  final TextEditingController _infraEngineerContactController =
      TextEditingController();
  final TextEditingController _ownerController = TextEditingController();
  final TextEditingController _ownerContactController = TextEditingController();

  bool _isSubmitting = false;
  String? _selfieImagePath;
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
    _infraEngineerContactController.text =
        "9327490188"; // Default value as shown in image
    _ownerController.text = "Prashant"; // Default value as shown in image
    _ownerContactController.text =
        "9327490188"; // Default value as shown in image
    _purposeController.text = ""; // Default value as shown in image
  }

  @override
  void dispose() {
    _purposeController.dispose();
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
        title: "Site Visit",
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
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
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
                    child: CustomSubmitButtonV2(text: "Submit", onPressed: _submitForm),
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
          isEditable: true,
        ),
        const SizedBox(height: 15),

        // Infra Engineer Contact No.
        CustomFormField(
          label: "Infra Engineer Contact No.",
          controller: _infraEngineerContactController,
          isRequired: false,
          isEditable: true,
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 15),

        // Owner
        CustomFormField(
          label: "Owner",
          controller: _ownerController,
          isRequired: false,
          isEditable: true,
        ),
        const SizedBox(height: 15),

        // Owner Contact No.
        CustomFormField(
          label: "Owner Contact No.",
          controller: _ownerContactController,
          isRequired: false,
          isEditable: true,
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 15),

        // Purpose of Visit (Multi-line)
        CustomRemarksField(
          label: "Purpose of Visit",
          hintText: "",
          controller: _purposeController,
          isDisabled: false,
        ),
        getHeight(20),

        // Add a Selfie Section
        ImageUploadField(
          label: "Add a Selfie",
          placeholder: "Selfie",
          isRequired: false,
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
          isDisabled: false,
        ),
        getHeight(15),

        
      ],
    );
  }

  void _submitForm() {
    if (_purposeController.text.trim().isEmpty) {
      showCustomToast(context, "Please enter purpose of visit");
      return;
    }

    if (_selfieImagePath == null) {
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
      showCustomToast(context, "Site visit submitted successfully");
      Navigator.of(context).pop();
    });
  }
}
