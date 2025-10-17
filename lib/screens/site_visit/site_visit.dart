import 'dart:convert';
import 'dart:io';

import 'package:app/commonWidgets/custom_form_appbar.dart';
import 'package:app/commonWidgets/custom_form_field.dart';
import 'package:app/commonWidgets/custom_image_upload_field.dart';
import 'package:app/commonWidgets/custom_remark.dart';
import 'package:app/commonWidgets/custom_submit_button_v2.dart';
import 'package:app/commonWidgets/loader_widget.dart';
import 'package:app/constants/app_images.dart';
import 'package:app/constants/constants_methods.dart';
import 'package:app/enum/activity_type_enum.dart';
import 'package:app/models/all_site_model.dart';
import 'package:app/services/asset_audit/central_asset_audit_service.dart';
import 'package:app/services/asset_audit_post_service.dart';
import 'package:app/services/service_locator.dart';
import 'package:app/services/api_service.dart';
import 'package:app/utils/logger.dart';
import 'package:app/utils/toastbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

class SiteVisitScreen extends StatefulWidget {
  final AllSiteModel siteData;

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

  late CentralAssetAuditService _service;
  bool _isSubmitting = false;
  String? _selfieImagePath;

  String? customerPhotoByteData;
  String? _uploadedImgId;
  bool _hasFormDataChanges = false;
  String? _fetchedImageData;
  File? _selectedImage;

  @override
  void initState() {
    super.initState();
    _service = ServiceLocator().centralAssetAuditService;
    _initializeFormData();
  }

  void _initializeFormData() {
    // Initialize form fields with site data

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
                  child: CustomSubmitButtonV2(
                    text: "Submit",
                    onPressed: _submitForm,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _uploadSelfie() async {
    try {
      if (_selectedImage == null) {
        Toastbar.showErrorToastbar('Please select an image first', context);
        return;
      }

      // Internet connected - upload to server
      final imgId = await _service.uploadImage(
        siteAuditSchId: widget.siteData.siteId.toString(),
        imageFile: _selectedImage!,
        isSelfie: false,
        activityType: ActivityTypeEnum.siteVisit,
      );

      print("imgId: after upload $imgId");

      // Update the database with the new image ID
      final dbData = await _service.getActualDataFromSqlite(
        siteAuditSchId: widget.siteData.siteId.toString(),
      );
      if (dbData != null) {
        final pageHeaders = dbData['pageHeader'] as List<dynamic>?;
        final pageHeader = pageHeaders?.isNotEmpty == true
            ? pageHeaders!.first as Map<String, dynamic>
            : null;
        if (pageHeader != null) {
          pageHeader['maker_selfie_image_id'] = imgId;

          // Save the updated data back to the database
          await _service.updateDataInSqlite(
            siteAuditSchId: widget.siteData.siteId.toString(),
            updatedData: dbData,
          );
        }
      }

      if (imgId != null && imgId.isNotEmpty) {
        setState(() {
          _uploadedImgId = imgId;
          print('uploadedImgId: $_uploadedImgId, $imgId');
          _hasFormDataChanges = true;
        });

        // Show appropriate message based on whether it's server or local ID
        if (imgId.contains("LOCAL_IMAGE_ID")) {
          showCustomToast(context, 'Selfie saved locally (offline mode)');
        } else {
          showCustomToast(context, 'Selfie uploaded successfully');
        }
      } else {
        showCustomToast(context, 'Failed to upload selfie');
        throw Exception('Failed to get image ID');
      }
    } catch (e) {
      Logger.errorLog('❌ Error uploading selfie: $e');
    }
  }

  Future<void> postSiteVisitLog() async {
    try {
      LoaderWidget.showLoader(context);

      final requestData = {
        "svlId": 0,
        "siteId": widget.siteData.siteId,
        "visitingPersonName": "",
        "visitingPersonImageId": _uploadedImgId != null
            ? (_uploadedImgId!.contains("LOCAL_IMAGE_ID") 
                ? _uploadedImgId!  // Send local ID as string for offline mode
                : (int.tryParse(_uploadedImgId!) ?? 0))  // Send server ID as int for online mode
            : 0,
        "visitDate":
            "${DateTime.now().day.toString().padLeft(2, '0')}/${DateTime.now().month.toString().padLeft(2, '0')}/${DateTime.now().year}",
        "purposeOfVisit": _purposeController.text.trim(),
        "isActive": true,
        "remarks": "",
      };

      print('requestData: $requestData');

      await ServiceLocator().assetAuditPostService
          .postAssetAuditDataWithPhotoReplacement(
            requests: [requestData],
            activityType: ActivityTypeEnum.siteVisit,
            isLastPage: true,
          );

      Navigator.of(context).pop();
    } catch (e) {
      Logger.errorLog('❌ Error submitting site visit: $e');
      showCustomToast(context, "Error submitting site visit: $e");
    } finally {
      LoaderWidget.hideLoader();
    }
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
          initialValue: widget.siteData.infraEngineerName ?? "N/A",
          isRequired: false,
          isEditable: true,
        ),
        const SizedBox(height: 15),

        // Infra Engineer Contact No.
        CustomFormField(
          label: "Infra Engineer Contact No.",
          initialValue: widget.siteData.infraEngineerPhone ?? "N/A",
          isRequired: false,
          isEditable: true,
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 15),

        // Owner
        CustomFormField(
          label: "Owner",
          initialValue: widget.siteData.ownerName ?? "N/A",
          isRequired: false,
          isEditable: true,
        ),
        const SizedBox(height: 15),

        // Owner Contact No.
        CustomFormField(
          label: "Owner Contact No.",
          initialValue: widget.siteData.ownerPhone ?? "N/A",
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
          isRequired: true,
          externalImageUrl: _fetchedImageData,
          onImageSelected: (file) {
            if (file != null) {
              debugPrint("Selected image path: ${file.path}");
              setState(() {
                _selectedImage = file;
                _hasFormDataChanges = true;
              });
              // Upload selfie to server

              _uploadSelfie();
            } else {
              setState(() {
                _selectedImage = null;
                _uploadedImgId = null;
                _fetchedImageData = null;
              });
            }
          },
        ),

        getHeight(15),
      ],
    );
  }

  void _submitForm() async {
    if (_purposeController.text.trim().isEmpty) {
      showCustomToast(context, "Please enter purpose of visit");
      return;
    }

    if (_selectedImage == null) {
      showCustomToast(context, "Please add a selfie");
      return;
    }

    // Check if image has been uploaded (either to server or locally)
    if (_uploadedImgId == null || _uploadedImgId!.isEmpty) {
      showCustomToast(context, "Please wait for image upload to complete");
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      // Submit the form with already uploaded image
      await postSiteVisitLog();
    } catch (e) {
      Logger.errorLog('❌ Error in submit process: $e');
      showCustomToast(context, "Error submitting site visit: $e");
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }
}
