import 'dart:io';

import 'package:app/commonWidgets/custom_form_appbar.dart';
import 'package:app/commonWidgets/custom_form_field.dart';
import 'package:app/commonWidgets/custom_image_upload_field.dart';
import 'package:app/commonWidgets/custom_remark.dart';
import 'package:app/commonWidgets/custom_submit_button_v2.dart';
import 'package:app/commonWidgets/custom_dialogs/unsaved_changes_dialog.dart';
import 'package:app/commonWidgets/loader_widget.dart';
import 'package:app/constants/app_images.dart';
import 'package:app/constants/constants_methods.dart';
import 'package:app/enum/activity_type_enum.dart';
import 'package:app/models/all_site_model.dart';
import 'package:app/screens/pulse_dashboard.dart';
import 'package:app/services/asset_audit/central_asset_audit_service.dart';
import 'package:app/services/service_locator.dart';
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
  String? _uploadedImgId;
  bool _hasFormDataChanges = false;
  String? _fetchedImageData;
  File? _selectedImage;

  @override
  void initState() {
    super.initState();
    _service = ServiceLocator().centralAssetAuditService;

    _initializeFormData();
    
    // Add listener to purpose controller to track changes
    _purposeController.addListener(() {
      if (!_hasFormDataChanges) {
        print("🔍 Purpose of visit changed - setting _hasFormDataChanges to true");
        setState(() {
          _hasFormDataChanges = true;
        });
      }
    });
  }

  void _initializeFormData() {
    // Initialize form fields with site data
    _purposeController.text =
        widget.siteData.purposeOfVisit ??
        ""; // Use existing purpose of visit if available

    // Initialize infra engineer fields with site data
    _infraEngineerController.text = widget.siteData.infraEngineerName ?? "";
    _infraEngineerContactController.text =
        widget.siteData.infraEngineerPhone ?? "";
    _ownerController.text = widget.siteData.ownerName ?? "";
    _ownerContactController.text = widget.siteData.ownerPhone ?? "";

    // Handle existing image if available
    print("🔍 visitingPersonImageId: ${widget.siteData.visitingPersonImageId}");
    print(
      "🔍 visitingPersonImageId type: ${widget.siteData.visitingPersonImageId.runtimeType}",
    );

    if (widget.siteData.visitingPersonImageId != null &&
        widget.siteData.visitingPersonImageId!.isNotEmpty) {
      _uploadedImgId = widget.siteData.visitingPersonImageId;
      print(
        "🔍 Loading image with ID: ${widget.siteData.visitingPersonImageId}",
      );
      // Load the actual image data
      _loadImage(widget.siteData.visitingPersonImageId!);
    } else {
      print("🔍 No visitingPersonImageId found or empty");
      _uploadedImgId = null; // Ensure it's null when no image
    }
  }

  Future<void> _loadImage(String imageId) async {
    try {
      print("🔍 _loadImage called with imageId: $imageId");
      print("🔍 _loadImage imageId type: ${imageId.runtimeType}");

      String? uniqueId;
      
      // Check if this is already a unique ID (offline mode) or a server ID (online mode)
      if (imageId.contains("LOCAL_IMAGE_ID")) {
        // This is already a unique ID from offline mode
        print("🔍 Detected unique ID (offline mode): $imageId");
        uniqueId = imageId;
      } else {
        // This is a server ID, try to download from server (online mode)
        print("🔍 Detected server ID (online mode): $imageId");
        uniqueId = await ServiceLocator().imageUploadService
            .downloadImageUsingServerId(
              imageId,
              ActivityTypeEnum.siteVisit,
              widget.siteData.siteId.toString(),
            );
        print("🔍 Download result - uniqueId: $uniqueId");
      }

      if (uniqueId != null) {
        // Now get the image data using the unique ID
        final imageData = await _service.getImageAsDataUrl(uniqueId);

        print(
          "🔍 Image loading result: ${imageData != null ? 'SUCCESS' : 'FAILED'}",
        );
        print("🔍 Image data length: ${imageData?.length ?? 0}");

        if (imageData != null) {
          Logger.debugLog(
            '✅ Image data received: ${imageData.length} characters',
          );
          Logger.debugLog(
            '✅ Image data preview: ${imageData.substring(0, imageData.length > 100 ? 100 : imageData.length)}...',
          );
          setState(() {
            _fetchedImageData = imageData;
          });
          Logger.debugLog('✅ Image loaded successfully and state updated');
          print("✅ Image loaded successfully and state updated");
        } else {
          Logger.errorLog(
            '❌ Failed to load image data with uniqueId $uniqueId - imageData is null',
          );
          print(
            "❌ Failed to load image data with uniqueId $uniqueId - imageData is null",
          );
        }
      } else {
        Logger.errorLog(
          '❌ Failed to get unique ID for image: $imageId',
        );
        print(
          "❌ Failed to get unique ID for image: $imageId",
        );
      }
    } catch (e) {
      Logger.errorLog('❌ Error loading image: $e');
      Logger.errorLog('❌ Stack trace: ${StackTrace.current}');
      print("❌ Error loading image: $e");
    }
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
        onClose: () => _showUnsavedChangesDialog(),
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
      final now = DateTime.now();
      final requestData = {
        "svlId":
            widget.siteData.siteVisitLogId != null &&
                widget.siteData.siteVisitLogId!.isNotEmpty
            ? int.tryParse(widget.siteData.siteVisitLogId!) ?? 0
            : 0,
        "siteId": widget.siteData.siteId,
        "visitingPersonName": "",
        "visitingPersonImageId": _uploadedImgId != null
            ? (_uploadedImgId!.contains("LOCAL_IMAGE_ID")
                  ? _uploadedImgId! // Send local ID as string for offline mode
                  : (int.tryParse(_uploadedImgId!) ??
                        0)) // Send server ID as int for online mode
            : 0,
        "visitDate": "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}.${now.millisecond.toString().padLeft(3, '0')}",
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

      print('✅ Site visit submitted successfully');
    } catch (e) {
      Logger.errorLog('❌ Error submitting site visit: $e');
      rethrow; // Re-throw the error so UnsavedChangesDialog can handle it
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
          controller: _infraEngineerController,
          isRequired: false,
          isEditable: false,
        ),
        const SizedBox(height: 15),

        // Infra Engineer Contact No.
        CustomFormField(
          label: "Infra Engineer Contact No.",
          controller: _infraEngineerContactController,
          isRequired: false,
          isEditable: false,
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 15),

        // Owner
        CustomFormField(
          label: "Owner",
          controller: _ownerController,
          isRequired: false,
          isEditable: false,
        ),
        const SizedBox(height: 15),

        // Owner Contact No.
        CustomFormField(
          label: "Owner Contact No.",
          controller: _ownerContactController,
          isRequired: false,
          isEditable: false,
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
        Builder(
          builder: (context) {
            print(
              "🔍 Building ImageUploadField - _fetchedImageData: ${_fetchedImageData != null ? 'HAS_DATA' : 'NULL'}",
            );
            print(
              "🔍 Building ImageUploadField - _fetchedImageData length: ${_fetchedImageData?.length ?? 0}",
            );
            return ImageUploadField(
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
            );
          },
        ),

        getHeight(15),
      ],
    );
  }

  void _showUnsavedChangesDialog() {
    print("🔍 _showUnsavedChangesDialog called - _hasFormDataChanges: $_hasFormDataChanges");
    if (_hasFormDataChanges) {
      print("🔍 Showing unsaved changes dialog");
      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (dialogContext) => UnsavedChangesDialog(
          siteAuditSchId: widget.siteData.siteId.toString(),
          section: "Site Visit",
          parentContext: context,
          onSaveAndExit: () async {
            _submitForm();
          },
          onDiscard: () {
            Navigator.of(context).pop();
          },
        ),
      );
    } else {
      print("🔍 No form changes detected - navigating back directly");
      Navigator.of(context).pop();
    }
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

    try {
      // Show loader
      LoaderWidget.showLoader(context);
      
      // Submit the form with already uploaded image
      await postSiteVisitLog();
      
      // Hide loader
      LoaderWidget.hideLoader();
      
      // Show success message
      showCustomToast(context, "Site visit submitted successfully");
      
      // Mark as submitted (reset changes flag)
      setState(() {
        _hasFormDataChanges = false;
      });
      
      // Navigate to home screen after a short delay
      await Future.delayed(const Duration(milliseconds: 500));
      
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => PulseDashboard(),
          ),
        );
      }
    } catch (e) {
      // Hide loader on error
      if (LoaderWidget.isShowing) {
        LoaderWidget.hideLoader();
      }
      
      Logger.errorLog('❌ Error in submit process: $e');
      
      // Show error message
      if (mounted) {
        Toastbar.showErrorToastbar(
          "Error submitting site visit: ${e.toString()}",
          context,
        );
      }
      
      // Re-throw so UnsavedChangesDialog can handle the error if called from there
      rethrow;
    }
  }
}
