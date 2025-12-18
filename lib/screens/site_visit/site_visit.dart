import 'dart:io';

import 'package:app/commonWidgets/custom_form_appbar.dart';
import 'package:app/commonWidgets/custom_form_field.dart';
import 'package:app/commonWidgets/custom_form_dropdown.dart';
import 'package:app/commonWidgets/custom_image_upload_field.dart';
import 'package:app/commonWidgets/custom_remark.dart';
import 'package:app/commonWidgets/custom_submit_button_v2.dart';
import 'package:app/commonWidgets/custom_dialogs/unsaved_changes_dialog.dart';
import 'package:app/commonWidgets/loader_widget.dart';
import 'package:app/constants/app_images.dart';
import 'package:app/constants/constants_methods.dart';
import 'package:app/enum/activity_type_enum.dart';
import 'package:app/models/all_site_model.dart';
import 'package:app/routes/route_generator.dart';
import 'package:app/services/asset_audit/central_asset_audit_service.dart';
import 'package:app/services/service_locator.dart';
import 'package:app/utils/logger.dart';
import 'package:app/utils/toastbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

class SiteVisitScreen extends StatefulWidget {
  final AllSiteModel siteData;
  final BuildContext? parentContext;
  final List<Map<String, dynamic>>? preloadedOrganisationList;

  const SiteVisitScreen({
    super.key,
    required this.siteData,
    this.parentContext,
    this.preloadedOrganisationList,
  });

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

  final TextEditingController _visitorNameController = TextEditingController();
  final TextEditingController _visitorContactNoController = TextEditingController();
  final TextEditingController _roleDesignationController = TextEditingController();
  final TextEditingController _reportingManagerController = TextEditingController();

  // Organization Name dropdown
  int? _selectedOrganizationId;
  List<Map<String, dynamic>> _organizationList = [];
  List<String> _organizationOptions = [];

  late CentralAssetAuditService _service;
  String? _uploadedImgId;
  bool _hasFormDataChanges = false;
  String? _fetchedImageData;
  File? _selectedImage;

  // Official ID Card
  String? _officialIdImageId;
  String? _fetchedOfficialIdImageData;
  File? _selectedOfficialIdImage;

  // Aadhar Card
  String? _aadharCardImageId;
  String? _fetchedAadharCardImageData;
  File? _selectedAadharCardImage;

  // Status of site at time of leaving
  String? _leavingStatusImageId;
  String? _fetchedLeavingStatusImageData;
  File? _selectedLeavingStatusImage;

  @override
  void initState() {
    super.initState();
    _service = ServiceLocator().centralAssetAuditService;

    _initializeFormData();
    _loadOrganisationList();

    // Add listener to purpose controller to track changes
    _purposeController.addListener(() {
      if (!_hasFormDataChanges) {

        setState(() {
          _hasFormDataChanges = true;
        });
      }
    });

    // Add listeners to visitor field controllers to track changes
    _visitorNameController.addListener(() {
      if (!_hasFormDataChanges) {
        setState(() {
          _hasFormDataChanges = true;
        });
      }
    });
    _visitorContactNoController.addListener(() {
      if (!_hasFormDataChanges) {
        setState(() {
          _hasFormDataChanges = true;
        });
      }
    });
    _roleDesignationController.addListener(() {
      if (!_hasFormDataChanges) {
        setState(() {
          _hasFormDataChanges = true;
        });
      }
    });
    _reportingManagerController.addListener(() {
      if (!_hasFormDataChanges) {
        setState(() {
          _hasFormDataChanges = true;
        });
      }
    });
  }

  Future<void> _loadOrganisationList() async {
    try {
      List<Map<String, dynamic>> organisations;
      
      // Use preloaded organisation list if available, otherwise fetch it
      if (widget.preloadedOrganisationList != null && widget.preloadedOrganisationList!.isNotEmpty) {
        organisations = widget.preloadedOrganisationList!;
        Logger.debugLog('✅ Using preloaded organisation list: ${organisations.length} organisations');
      } else {
        final repository = ServiceLocator().sitesRepository;
        organisations = await repository.getOrganisationList();
        Logger.debugLog('✅ Fetched organisation list: ${organisations.length} organisations');
      }
      
      setState(() {
        _organizationList = organisations;
        _organizationOptions = organisations.map((org) => org['org_name'] as String).toList();
      });

      // After loading, initialize the selected organization ID
      // First try to use orgId directly from siteData (most reliable)
      if (widget.siteData.orgId != null) {
        setState(() {
          _selectedOrganizationId = widget.siteData.orgId;
        });
        Logger.debugLog('✅ Set selected organization ID from siteData: ${widget.siteData.orgId}');
      } else if (widget.siteData.organisationName != null && widget.siteData.organisationName!.isNotEmpty) {
        // Fallback: try to find by organisationName from siteData
        try {
          final matchingOrg = _organizationList.firstWhere(
            (org) => org['org_name'] == widget.siteData.organisationName,
          );
          setState(() {
            _selectedOrganizationId = matchingOrg['org_id'] as int?;
          });
          Logger.debugLog('✅ Set selected organization ID from organisationName: ${matchingOrg['org_id']}');
        } catch (e) {
          // Organization name not found in list, keep _selectedOrganizationId as null
          Logger.debugLog('⚠️ Organization "${widget.siteData.organisationName}" not found in list');
        }
      }
    } catch (e) {
      Logger.errorLog('❌ Error loading organisation list: $e');
      // Keep empty list on error
    }
  }

  String? _getOrganizationNameById(int? orgId) {
    if (orgId == null || _organizationList.isEmpty) return null;
    try {
      final org = _organizationList.firstWhere(
        (org) => org['org_id'] == orgId,
      );
      return org['org_name'] as String?;
    } catch (e) {
      return null;
    }
  }

  void _initializeFormData() {
    // Initialize form fields with site data
    _purposeController.text =
        widget.siteData.purposeOfVisit ??
        ""; // Use existing purpose of visit if available

    _visitorNameController.text = widget.siteData.visitorName ?? "";
    _visitorContactNoController.text = widget.siteData.visitorContactNo ?? "";
    // Organization ID will be set in _loadOrganisationList after list is loaded
    _roleDesignationController.text = widget.siteData.roleDesignation ?? "";
    _reportingManagerController.text = widget.siteData.reportingManager ?? "";

    // Initialize infra engineer fields with site data
    _infraEngineerController.text = widget.siteData.infraEngineerName ?? "";
    _infraEngineerContactController.text =
        widget.siteData.infraEngineerPhone ?? "";
    _ownerController.text = widget.siteData.ownerName ?? "";
    _ownerContactController.text = widget.siteData.ownerPhone ?? "";
   
    // Handle existing image if available

    if (widget.siteData.visitingPersonImageId != null &&
        widget.siteData.visitingPersonImageId!.isNotEmpty) {
      _uploadedImgId = widget.siteData.visitingPersonImageId;

      // Load the actual image data
      _loadImage(widget.siteData.visitingPersonImageId!, isSelfie: true);
    } else {

      _uploadedImgId = null; // Ensure it's null when no image
    }

    // Load Official ID Card image if available
    if (widget.siteData.officialIdImageId != null &&
        widget.siteData.officialIdImageId!.isNotEmpty) {
      _officialIdImageId = widget.siteData.officialIdImageId;

      _loadImage(widget.siteData.officialIdImageId!, isSelfie: false, imageType: 'officialId');
    }

    // Load Aadhar Card image if available
    if (widget.siteData.aadharCardImageId != null &&
        widget.siteData.aadharCardImageId!.isNotEmpty) {
      _aadharCardImageId = widget.siteData.aadharCardImageId;

      _loadImage(widget.siteData.aadharCardImageId!, isSelfie: false, imageType: 'aadharCard');
    }

    // Load Leaving Status image if available
    if (widget.siteData.leavingStatusImageId != null &&
        widget.siteData.leavingStatusImageId!.isNotEmpty) {
      _leavingStatusImageId = widget.siteData.leavingStatusImageId;

      _loadImage(widget.siteData.leavingStatusImageId!, isSelfie: false, imageType: 'leavingStatus');
    }
  }

  Future<void> _loadImage(String imageId, {bool isSelfie = true, String? imageType}) async {
    try {

      String? uniqueId;
      String? imageData;

      // Check if this is already a unique ID (offline mode) or a server ID (online mode)
      if (imageId.contains("LOCAL_IMAGE_ID")) {
        // This is already a unique ID from offline mode
        uniqueId = imageId;
        
        // For LOCAL_IMAGE_ID, try to get image directly from ImageUploadService
        imageData = await ServiceLocator().imageUploadService.getImageUsingUniqueId(uniqueId);
        
        // If direct lookup failed, try through getImageAsDataUrl as fallback
        if (imageData == null || imageData.isEmpty) {

          imageData = await _service.getImageAsDataUrl(uniqueId);
        }
      } else {
        // This is a server ID, check local SQLite first by server_id
        
        // First try to get from local SQLite by server_id (might already be cached)
        final imageModel = await ServiceLocator().imageUploadService.getImagesByServerId(imageId);
        if (imageModel != null && imageModel.imageData != null && imageModel.imageData!.isNotEmpty) {
          imageData = imageModel.imageData;
          uniqueId = imageModel.uniqueId;
        } else {

          // Also try by unique_id (in case server_id wasn't set but unique_id matches)
          imageData = await ServiceLocator().imageUploadService.getImageUsingUniqueId(imageId);
          if (imageData != null && imageData.isNotEmpty) {
            uniqueId = imageId;
          } else {

            // Only try to download if we have internet connection
            // Check connectivity before attempting download
            try {
              uniqueId = await ServiceLocator().imageUploadService
                  .downloadImageUsingServerId(
                    imageId,
                    ActivityTypeEnum.siteVisit,
                    widget.siteData.siteId.toString(),
                  );

              // After download, get the image data
              if (uniqueId != null) {
                imageData = await ServiceLocator().imageUploadService.getImageUsingUniqueId(uniqueId);
              } else {
              }
            } catch (e) {
              Logger.errorLog('❌ Error downloading image from server (likely offline): $e');
              // Don't throw error, just log it - image will remain null
            }
          }
        }
      }

      if (imageData != null && imageData.isNotEmpty) {
        Logger.debugLog(
          '✅ Image data received: ${imageData.length} characters',
        );
        Logger.debugLog(
          '✅ Image data preview: ${imageData.substring(0, imageData.length > 100 ? 100 : imageData.length)}...',
        );
        setState(() {
          if (isSelfie) {
            _fetchedImageData = imageData;

          } else {
            switch (imageType) {
              case 'officialId':
                _fetchedOfficialIdImageData = imageData;

                break;
              case 'aadharCard':
                _fetchedAadharCardImageData = imageData;

                break;
              case 'leavingStatus':
                _fetchedLeavingStatusImageData = imageData;

                break;
              default:

            }
          }
        });
        Logger.debugLog('✅ Image loaded successfully and state updated');

      } else {
        Logger.errorLog(
          '❌ Failed to load image data with imageId $imageId, uniqueId: $uniqueId - imageData is null or empty',
        );

      }
    } catch (e) {
      Logger.errorLog('❌ Error loading image: $e');
      Logger.errorLog('❌ Stack trace: ${StackTrace.current}');

    }
  }

  @override
  void dispose() {
    _purposeController.dispose();
    _infraEngineerController.dispose();
    _infraEngineerContactController.dispose();
    _ownerController.dispose();
    _ownerContactController.dispose();
    _visitorNameController.dispose();
    _visitorContactNoController.dispose();
    _roleDesignationController.dispose();
    _reportingManagerController.dispose();
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

  Future<void> _uploadOfficialIdCard() async {
    try {
      if (_selectedOfficialIdImage == null) {
        Toastbar.showErrorToastbar('Please select an image first', context);
        return;
      }

      final imgId = await _service.uploadImage(
        siteAuditSchId: widget.siteData.siteId.toString(),
        imageFile: _selectedOfficialIdImage!,
        isSelfie: false,
        activityType: ActivityTypeEnum.siteVisit,
      );

      if (imgId != null && imgId.isNotEmpty) {
        setState(() {
          _officialIdImageId = imgId;
          _hasFormDataChanges = true;
        });

        if (imgId.contains("LOCAL_IMAGE_ID")) {
          showCustomToast(context, 'Official ID Card saved locally (offline mode)');
        } else {
          showCustomToast(context, 'Official ID Card uploaded successfully');
        }
      } else {
        showCustomToast(context, 'Failed to upload Official ID Card');
        throw Exception('Failed to get image ID');
      }
    } catch (e) {
      Logger.errorLog('❌ Error uploading official ID card: $e');
    }
  }

  Future<void> _uploadAadharCard() async {
    try {
      if (_selectedAadharCardImage == null) {
        Toastbar.showErrorToastbar('Please select an image first', context);
        return;
      }

      final imgId = await _service.uploadImage(
        siteAuditSchId: widget.siteData.siteId.toString(),
        imageFile: _selectedAadharCardImage!,
        isSelfie: false,
        activityType: ActivityTypeEnum.siteVisit,
      );

      if (imgId != null && imgId.isNotEmpty) {
        setState(() {
          _aadharCardImageId = imgId;
          _hasFormDataChanges = true;
        });

        if (imgId.contains("LOCAL_IMAGE_ID")) {
          showCustomToast(context, 'Aadhar Card saved locally (offline mode)');
        } else {
          showCustomToast(context, 'Aadhar Card uploaded successfully');
        }
      } else {
        showCustomToast(context, 'Failed to upload Aadhar Card');
        throw Exception('Failed to get image ID');
      }
    } catch (e) {
      Logger.errorLog('❌ Error uploading aadhar card: $e');
    }
  }

  Future<void> _uploadLeavingStatus() async {
    try {
      if (_selectedLeavingStatusImage == null) {
        Toastbar.showErrorToastbar('Please select an image first', context);
        return;
      }

      final imgId = await _service.uploadImage(
        siteAuditSchId: widget.siteData.siteId.toString(),
        imageFile: _selectedLeavingStatusImage!,
        isSelfie: false,
        activityType: ActivityTypeEnum.siteVisit,
      );

      if (imgId != null && imgId.isNotEmpty) {
        setState(() {
          _leavingStatusImageId = imgId;
          _hasFormDataChanges = true;
        });

        if (imgId.contains("LOCAL_IMAGE_ID")) {
          showCustomToast(context, 'Leaving status saved locally (offline mode)');
        } else {
          showCustomToast(context, 'Leaving status uploaded successfully');
        }
      } else {
        showCustomToast(context, 'Failed to upload leaving status');
        throw Exception('Failed to get image ID');
      }
    } catch (e) {
      Logger.errorLog('❌ Error uploading leaving status: $e');
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
        "visitDate":
            "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}.${now.millisecond.toString().padLeft(3, '0')}",
        "purposeOfVisit": _purposeController.text.trim(),
        "visitorName": _visitorNameController.text.trim(),
        "visitorContactNo": _visitorContactNoController.text.trim(),
        "orgId": _selectedOrganizationId ?? 0,
        "roleDesignation": _roleDesignationController.text.trim(),
        "reportingManager": _reportingManagerController.text.trim(),
        "officialIdImageId": _officialIdImageId != null
            ? (_officialIdImageId!.contains("LOCAL_IMAGE_ID")
                  ? _officialIdImageId! // Send local ID as string for offline mode
                  : (int.tryParse(_officialIdImageId!) ?? 0)) // Send server ID as int for online mode
            : 0,
        "aadharCardImageId": _aadharCardImageId != null
            ? (_aadharCardImageId!.contains("LOCAL_IMAGE_ID")
                  ? _aadharCardImageId! // Send local ID as string for offline mode
                  : (int.tryParse(_aadharCardImageId!) ?? 0)) // Send server ID as int for online mode
            : 0,
        "leavingStatusImageId": _leavingStatusImageId != null
            ? (_leavingStatusImageId!.contains("LOCAL_IMAGE_ID")
                  ? _leavingStatusImageId! // Send local ID as string for offline mode
                  : (int.tryParse(_leavingStatusImageId!) ?? 0)) // Send server ID as int for online mode
            : 0,
        "isActive": true,
        "remarks": "",
      };

      await ServiceLocator().assetAuditPostService
          .postAssetAuditDataWithPhotoReplacement(
            requests: [requestData],
            activityType: ActivityTypeEnum.siteVisit,
            isLastPage: true,
          );

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

        // Visitor Name
        CustomFormField(
          label: "Visitor Name",
          controller: _visitorNameController,
          isRequired: false,
          isEditable: true,
        ),
        const SizedBox(height: 15),

        // Visitor Contact No.
        CustomFormField(
          label: "Visitor Contact No.",
          controller: _visitorContactNoController,
          isRequired: false,
          isEditable: true,
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 15),

        // Organization Name
        CustomDropdown(
          label: "Organization Name",
          items: _organizationOptions,
          initialValue: _getOrganizationNameById(_selectedOrganizationId),
          onChanged: (value) {
            if (!_hasFormDataChanges) {
              setState(() {
                _hasFormDataChanges = true;
              });
            }
            if (value != null) {
              final selectedOrg = _organizationList.firstWhere(
                (org) => org['org_name'] == value,
                orElse: () => {},
              );
              setState(() {
                _selectedOrganizationId = selectedOrg.isNotEmpty
                    ? selectedOrg['org_id'] as int?
                    : null;
              });
            } else {
              setState(() {
                _selectedOrganizationId = null;
              });
            }
          },
        ),
        const SizedBox(height: 15),

        // Role/Designation
        CustomFormField(
          label: "Role/Designation",
          controller: _roleDesignationController,
          isRequired: false,
          isEditable: true,
          keyboardType: TextInputType.text,
        ),
        const SizedBox(height: 15),

        // Reporting Manager
        CustomFormField(
          label: "Reporting Manager",
          controller: _reportingManagerController,
          isRequired: false,
          isEditable: true,
          keyboardType: TextInputType.text,
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

        // Official ID Card Section
        Builder(
          builder: (context) {
            return ImageUploadField(
              label: "Official ID Card",
              placeholder: "Official ID Card",
              isRequired: false,
              externalImageUrl: _fetchedOfficialIdImageData,
              onImageSelected: (file) {
                if (file != null) {
                  debugPrint("Selected official ID card image path: ${file.path}");
                  setState(() {
                    _selectedOfficialIdImage = file;
                    _hasFormDataChanges = true;
                  });
                  _uploadOfficialIdCard();
                } else {
                  setState(() {
                    _selectedOfficialIdImage = null;
                    _officialIdImageId = null;
                    _fetchedOfficialIdImageData = null;
                  });
                }
              },
            );
          },
        ),
        getHeight(15),

        // Aadhar Card Section
        Builder(
          builder: (context) {
            return ImageUploadField(
              label: "Aadhar Card",
              placeholder: "Aadhar Card",
              isRequired: false,
              externalImageUrl: _fetchedAadharCardImageData,
              onImageSelected: (file) {
                if (file != null) {
                  debugPrint("Selected aadhar card image path: ${file.path}");
                  setState(() {
                    _selectedAadharCardImage = file;
                    _hasFormDataChanges = true;
                  });
                  _uploadAadharCard();
                } else {
                  setState(() {
                    _selectedAadharCardImage = null;
                    _aadharCardImageId = null;
                    _fetchedAadharCardImageData = null;
                  });
                }
              },
            );
          },
        ),
        getHeight(15),

        // Status of site at time of leaving Section
        Builder(
          builder: (context) {
            return ImageUploadField(
              label: "Status of site at time of leaving",
              placeholder: "Status of site at time of leaving",
              isRequired: false,
              externalImageUrl: _fetchedLeavingStatusImageData,
              onImageSelected: (file) {
                if (file != null) {
                  debugPrint("Selected leaving status image path: ${file.path}");
                  setState(() {
                    _selectedLeavingStatusImage = file;
                    _hasFormDataChanges = true;
                  });
                  _uploadLeavingStatus();
                } else {
                  setState(() {
                    _selectedLeavingStatusImage = null;
                    _leavingStatusImageId = null;
                    _fetchedLeavingStatusImageData = null;
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

    if (_hasFormDataChanges) {

      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (dialogContext) => UnsavedChangesDialog(
          siteAuditSchId: widget.siteData.siteId.toString(),
          section: "Site Visit",
          parentContext: widget.parentContext ?? context,
          onSaveAndExit: () async {
            await _submitForm(navigateOnSuccess: false);
          },
          onDiscard: () {},
        ),
      );
    } else {

      navigateBackOrToHome(
        context,
        targetContext: widget.parentContext ?? context,
      );
    }
  }

  Future<void> _submitForm({bool navigateOnSuccess = true}) async {

    if (_visitorNameController.text.trim().isEmpty) {
      showCustomToast(context, "Please enter visitor name");
      return;
    }

    if (_visitorContactNoController.text.trim().isEmpty) {
      showCustomToast(context, "Please enter visitor contact no.");
      return;
    }

    if (_selectedOrganizationId == null) {
      showCustomToast(context, "Please select organization name");
      return;
    }

    if (_roleDesignationController.text.trim().isEmpty) {
      showCustomToast(context, "Please enter role/designation");
      return;
    }

    if (_reportingManagerController.text.trim().isEmpty) {
      showCustomToast(context, "Please enter reporting manager");
      return;
    }

    if (_purposeController.text.trim().isEmpty) {
      showCustomToast(context, "Please enter purpose of visit");
      return;
    }

    // Check if we have an uploaded image ID (either from existing data or newly uploaded)
    if (_uploadedImgId == null || _uploadedImgId!.isEmpty) {
      showCustomToast(context, "Please add a selfie");
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

      if (!navigateOnSuccess) {
        return;
      }

      // Navigate back to the originating screen after a short delay
      await Future.delayed(const Duration(milliseconds: 500));

      if (mounted) {
        navigateBackOrToHome(
          context,
          targetContext: widget.parentContext ?? context,
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
