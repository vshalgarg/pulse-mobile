import 'dart:io';

import 'package:app/commonWidgets/custom_form_appbar.dart';
import 'package:app/commonWidgets/custom_form_field.dart';
import 'package:app/commonWidgets/custom_image_upload_field.dart';
import 'package:app/commonWidgets/custom_submit_button_v2.dart';
import 'package:app/constants/app_images.dart';
import 'package:app/constants/constants_methods.dart';
import 'package:app/enum/activity_type_enum.dart';
import 'package:app/enum/corrective_maintenance_screen_mode_enum.dart';
import 'package:app/models/all_site_model.dart';
import 'package:app/models/gen_ins_checklist_model.dart';
import 'package:app/repositories/general_inspection_repository.dart';
import 'package:app/services/service_locator.dart';
import 'package:app/utils/logger.dart';
import 'package:app/utils/toastbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'gi_checklist_screen.dart';

class GInspectionDetailScreen extends StatefulWidget {
  final AllSiteModel siteData;
  final CMScreenModeEnum mode;

  const GInspectionDetailScreen({
    super.key,
    required this.siteData,
    required this.mode,
  });

  @override
  State<GInspectionDetailScreen> createState() =>
      _GInspectionDetailScreenState();
}

class _GInspectionDetailScreenState extends State<GInspectionDetailScreen> {
  final TextEditingController _infraEngineerController =
      TextEditingController();
  final TextEditingController _infraEngineerContactController =
      TextEditingController();
  final TextEditingController _ownerController = TextEditingController();
  final TextEditingController _ownerContactController = TextEditingController();

  String? _uploadedImgId;
  String? _fetchedImageData;
  File? _selectedImage;

  // Checklist data
  bool _isLoadingChecklist = true;
  String? _checklistError;
  List<GenInsCheckListData> _checklistItems = [];
  late GeneralInspectionRepository _repository;

  @override
  void initState() {
    super.initState();
    _repository = GeneralInspectionRepository(ServiceLocator().apiService);
    _loadChecklistData();
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
                    text: "Next",
                    onPressed: widget.mode == CMScreenModeEnum.view
                        ? null
                        : _submitForm,
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
          initialValue: widget.siteData.infraEngineerName ?? "N/A",
          isRequired: false,
          isEditable: widget.mode != CMScreenModeEnum.view,
        ),
        const SizedBox(height: 15),

        // Infra Engineer Contact No.
        CustomFormField(
          label: "Infra Engineer Contact No.",
          initialValue: widget.siteData.infraEngineerPhone ?? "N/A",
          isRequired: false,
          isEditable: widget.mode != CMScreenModeEnum.view,
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 15),

        // Owner
        CustomFormField(
          label: "Owner",
          initialValue: widget.siteData.ownerName ?? "N/A",
          isRequired: false,
          isEditable: widget.mode != CMScreenModeEnum.view,
        ),
        const SizedBox(height: 15),

        // Owner Contact No.
        CustomFormField(
          label: "Owner Contact No.",
          initialValue: widget.siteData.ownerPhone ?? "N/A",
          isRequired: false,
          isEditable: widget.mode != CMScreenModeEnum.view,
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 20),

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

  Future<void> _uploadSelfie() async {
    try {
      if (_selectedImage == null) {
        Toastbar.showErrorToastbar('Please select an image first', context);
        return;
      }

      // Internet connected - upload to server
      final imgId = await ServiceLocator().centralAssetAuditService.uploadImage(
        siteAuditSchId: widget.siteData.siteId.toString(),
        imageFile: _selectedImage!,
        isSelfie: false,
        activityType: ActivityTypeEnum.generalInspection,
      );

      print("imgId: after upload $imgId");

      // Update the database with the new image ID
      final dbData = await ServiceLocator().centralAssetAuditService
          .getActualDataFromSqlite(
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
          await ServiceLocator().centralAssetAuditService.updateDataInSqlite(
            siteAuditSchId: widget.siteData.siteId.toString(),
            updatedData: dbData,
          );
        }
      }

      if (imgId != null && imgId.isNotEmpty) {
        setState(() {
          _uploadedImgId = imgId;
          print('uploadedImgId: $_uploadedImgId, $imgId');
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

  Future<void> _loadChecklistData() async {
    try {
      setState(() {
        _isLoadingChecklist = true;
        _checklistError = null;
      });

      // Use default site domain ID for now (can be made configurable later)
      final siteDomainId = 1;
      
      Logger.debugLog('Loading checklist data for site domain ID: $siteDomainId');
      
      final checklistItems = await _repository.getGenInsCheckListData(siteDomainId);
      
      // Sort by cl_order
      checklistItems.sort((a, b) => a.clOrder.compareTo(b.clOrder));
      
      setState(() {
        _checklistItems = checklistItems;
        _isLoadingChecklist = false;
      });
      
      Logger.debugLog('Loaded ${checklistItems.length} checklist items');
    } catch (e) {
      Logger.errorLog('Error loading checklist data: $e');
      setState(() {
        _isLoadingChecklist = false;
        _checklistError = e.toString();
      });
    }
  }

  void _submitForm() {
    // Validate selfie
    if (_selectedImage == null) {
      showCustomToast(context, "Please add a selfie");
      return;
    }

    // Check if checklist is still loading
    if (_isLoadingChecklist) {
      showCustomToast(context, "Please wait while checklist is loading");
      return;
    }

    // Check if there was an error loading checklist
    if (_checklistError != null) {
      showCustomToast(context, "Error loading checklist: $_checklistError");
      return;
    }

    // Navigate to checklist screen with pre-loaded data
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GIChecklistScreen(
          siteData: widget.siteData,
          mode: widget.mode,
          visitingPersonImageId: _uploadedImgId,
          checklistItems: _checklistItems,
        ),
      ),
    );
  }
}
