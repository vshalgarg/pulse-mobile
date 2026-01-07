import 'dart:io';

import 'package:app/commonWidgets/custom_form_appbar.dart';
import 'package:app/commonWidgets/custom_form_field.dart';
import 'package:app/commonWidgets/custom_image_upload_field.dart';
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
import 'au_scan_upload.dart';

class AssetUploadDetailPage extends StatefulWidget {
  final AllSiteModel siteData;
  final BuildContext? parentContext;

  const AssetUploadDetailPage({
    super.key,
    required this.siteData,
    this.parentContext,
  });

  @override
  State<AssetUploadDetailPage> createState() => _AssetUploadDetailPageState();
}

class _AssetUploadDetailPageState extends State<AssetUploadDetailPage> {
  // Controllers for form fields
  final TextEditingController _infraEngineerController =
      TextEditingController();
  final TextEditingController _infraEngineerContactController =
      TextEditingController();
  final TextEditingController _ownerController = TextEditingController();
  final TextEditingController _ownerContactController = TextEditingController();

  final TextEditingController _assetNameController = TextEditingController();
  final TextEditingController _assetSerialNumberController =
      TextEditingController();
  final TextEditingController _assetMakeController = TextEditingController();
  final TextEditingController _assetModelController = TextEditingController();
  final TextEditingController _assetCapacityController =
      TextEditingController();
  final TextEditingController _assetLocationController =
      TextEditingController();

  late CentralAssetAuditService _service;
  bool _hasFormDataChanges = false;

  // Selfie related variables
  String? _selfieImgId;
  String? _fetchedSelfieImageData;
  File? _selectedSelfieImage;

  @override
  void initState() {
    super.initState();
    _service = ServiceLocator().centralAssetAuditService;
    _initializeFormData();

    // Add listeners to track form changes
    _assetNameController.addListener(_onFormChanged);
    _assetSerialNumberController.addListener(_onFormChanged);
    _assetMakeController.addListener(_onFormChanged);
    _assetModelController.addListener(_onFormChanged);
    _assetCapacityController.addListener(_onFormChanged);
    _assetLocationController.addListener(_onFormChanged);
  }

  void _onFormChanged() {
    if (!_hasFormDataChanges) {
      setState(() {
        _hasFormDataChanges = true;
      });
    }
  }

  void _initializeFormData() {
    // Initialize form fields with site data
    _infraEngineerController.text = widget.siteData.infraEngineerName ?? "";
    _infraEngineerContactController.text =
        widget.siteData.infraEngineerPhone ?? "";
    _ownerController.text = widget.siteData.ownerName ?? "";
    _ownerContactController.text = widget.siteData.ownerPhone ?? "";

    // Load existing asset data if available
    _loadExistingAssetData();

    // Load selfie from stored data if available
    _loadStoredSelfie();
  }

  Future<void> _loadStoredSelfie() async {
    try {
      final service = ServiceLocator().centralAssetAuditService;
      final storedData = await service.getActualDataFromSqlite(
        siteAuditSchId: widget.siteData.siteId.toString(),
      );

      if (storedData != null) {
        final pageHeaders = storedData['pageHeader'] as List<dynamic>?;
        final pageHeader = pageHeaders?.isNotEmpty == true
            ? pageHeaders!.first as Map<String, dynamic>?
            : null;

        if (pageHeader != null && pageHeader['maker_selfie_image_id'] != null) {
          final selfieImageId = pageHeader['maker_selfie_image_id'].toString();
          if (selfieImageId.isNotEmpty) {
            _selfieImgId = selfieImageId;
            _loadSelfieImage(selfieImageId);
          }
        }
      }
    } catch (e) {
      Logger.errorLog('❌ Error loading stored selfie: $e');
    }
  }

  Future<void> _loadExistingAssetData() async {
    try {
      final service = ServiceLocator().centralAssetAuditService;
      final storedData = await service.getDataFromSqlite(
        siteAuditSchId: widget.siteData.siteId.toString(),
      );

      if (storedData != null && storedData.apiData.isNotEmpty) {
        final apiData = storedData.apiData;

        // Load asset data if available
        if (apiData['assetName'] != null) {
          _assetNameController.text = apiData['assetName'].toString();
        }
        if (apiData['assetSerialNumber'] != null) {
          _assetSerialNumberController.text = apiData['assetSerialNumber']
              .toString();
        }
        if (apiData['assetMake'] != null) {
          _assetMakeController.text = apiData['assetMake'].toString();
        }
        if (apiData['assetModel'] != null) {
          _assetModelController.text = apiData['assetModel'].toString();
        }
        if (apiData['assetCapacity'] != null) {
          _assetCapacityController.text = apiData['assetCapacity'].toString();
        }
        if (apiData['assetLocation'] != null) {
          _assetLocationController.text = apiData['assetLocation'].toString();
        }

        // Load selfie if available
        if (apiData['maker_selfie_image_id'] != null &&
            apiData['maker_selfie_image_id'].toString().isNotEmpty) {
          _selfieImgId = apiData['maker_selfie_image_id'].toString();
          _loadSelfieImage(_selfieImgId!);
        }
      }
    } catch (e) {
      Logger.errorLog('❌ Error loading existing asset data: $e');
    }
  }

  Future<void> _loadSelfieImage(String imageId) async {
    try {
      String? uniqueId;
      String? imageData;

      if (imageId.contains("LOCAL_IMAGE_ID")) {
        uniqueId = imageId;
        imageData = await ServiceLocator().imageUploadService
            .getImageUsingUniqueId(uniqueId);

        if (imageData == null || imageData.isEmpty) {
          imageData = await _service.getImageAsDataUrl(uniqueId);
        }
      } else {
        final imageModel = await ServiceLocator().imageUploadService
            .getImagesByServerId(imageId);
        if (imageModel != null &&
            imageModel.imageData != null &&
            imageModel.imageData!.isNotEmpty) {
          imageData = imageModel.imageData;
          uniqueId = imageModel.uniqueId;
        } else {
          imageData = await ServiceLocator().imageUploadService
              .getImageUsingUniqueId(imageId);
          if (imageData != null && imageData.isNotEmpty) {
            uniqueId = imageId;
          } else {
            try {
              uniqueId = await ServiceLocator().imageUploadService
                  .downloadImageUsingServerId(
                    imageId,
                    ActivityTypeEnum.assetUpload,
                    widget.siteData.siteId.toString(),
                  );

              if (uniqueId != null) {
                imageData = await ServiceLocator().imageUploadService
                    .getImageUsingUniqueId(uniqueId);
              }
            } catch (e) {
              Logger.errorLog(
                '❌ Error downloading selfie image from server: $e',
              );
            }
          }
        }
      }

      if (imageData != null && imageData.isNotEmpty) {
        setState(() {
          _fetchedSelfieImageData = imageData;
        });
      }
    } catch (e) {
      Logger.errorLog('❌ Error loading selfie image: $e');
    }
  }

  @override
  void dispose() {
    _infraEngineerController.dispose();
    _infraEngineerContactController.dispose();
    _ownerController.dispose();
    _ownerContactController.dispose();
    _assetNameController.dispose();
    _assetSerialNumberController.dispose();
    _assetMakeController.dispose();
    _assetModelController.dispose();
    _assetCapacityController.dispose();
    _assetLocationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      resizeToAvoidBottomInset: true,
      appBar: CustomFormAppbar(
        title: "Asset Upload",
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
                      bottom: MediaQuery.of(context).viewInsets.bottom + 20,
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
      if (_selectedSelfieImage == null) {
        Toastbar.showErrorToastbar('Please select a selfie first', context);
        return;
      }

      final imgId = await _service.uploadImage(
        siteAuditSchId: widget.siteData.siteId.toString(),
        imageFile: _selectedSelfieImage!,
        isSelfie: true,
        activityType: ActivityTypeEnum.assetUpload,
      );

      // Update the database with the new selfie image ID
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
          _selfieImgId = imgId;
          _hasFormDataChanges = true;
        });

        if (imgId.contains("LOCAL_IMAGE_ID")) {
          showCustomToast(context, 'Selfie saved locally (offline mode)');
        } else {
          showCustomToast(context, 'Selfie uploaded successfully');
        }
      } else {
        showCustomToast(context, 'Failed to upload selfie');
        throw Exception('Failed to get selfie image ID');
      }
    } catch (e) {
      Logger.errorLog('❌ Error uploading selfie: $e');
    }
  }

  Future<void> postAssetUpload() async {
    try {
      final requestData = {
        "siteId": widget.siteData.siteId,
        "assetName": _assetNameController.text.trim(),
        "assetSerialNumber": _assetSerialNumberController.text.trim(),
        "assetMake": _assetMakeController.text.trim(),
        "assetModel": _assetModelController.text.trim(),
        "assetCapacity": _assetCapacityController.text.trim(),
        "assetLocation": _assetLocationController.text.trim(),
        "maker_selfie_image_id": _selfieImgId != null
            ? (_selfieImgId!.contains("LOCAL_IMAGE_ID")
                  ? _selfieImgId!
                  : (int.tryParse(_selfieImgId!) ?? 0))
            : 0,
        "isActive": true,
        "remarks": "",
      };

      await ServiceLocator().assetAuditPostService
          .postAssetAuditDataWithPhotoReplacement(
            requests: [requestData],
            activityType: ActivityTypeEnum.assetUpload,
            isLastPage: true,
          );
    } catch (e) {
      Logger.errorLog('❌ Error submitting asset upload: $e');
      rethrow;
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
        const SizedBox(height: 12),

        // Cluster/District
        CustomFormField(
          label: "Cluster/District",
          initialValue: widget.siteData.clusterDistrictName,
          isRequired: false,
          isEditable: false,
        ),
        const SizedBox(height: 12),

        // Site Code
        CustomFormField(
          label: "Site Code",
          initialValue: widget.siteData.siteCode,
          isRequired: false,
          isEditable: false,
        ),
        const SizedBox(height: 12),

        // Site Name
        CustomFormField(
          label: "Site Name",
          initialValue: widget.siteData.siteName,
          isRequired: false,
          isEditable: false,
        ),
        const SizedBox(height: 12),

        // Customer
        CustomFormField(
          label: "Customer",
          initialValue: widget.siteData.clientName ?? "N/A",
          isRequired: false,
          isEditable: false,
        ),
        const SizedBox(height: 12),

        // Infra Engineer Name
        CustomFormField(
          label: "Infra Engineer Name",
          controller: _infraEngineerController,
          isRequired: false,
          isEditable: false,
        ),
        const SizedBox(height: 12),

        // Infra Engineer Contact No.
        CustomFormField(
          label: "Infra Engineer Contact No.",
          controller: _infraEngineerContactController,
          isRequired: false,
          isEditable: false,
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 12),

        // Add a Selfie
        Builder(
          builder: (context) {
            return ImageUploadField(
              label: "Add a Selfie",
              placeholder: "Selfie",
              isRequired: true,
              externalImageUrl: _fetchedSelfieImageData,
              onImageSelected: (file) {
                if (file != null) {
                  debugPrint("Selected selfie path: ${file.path}");
                  setState(() {
                    _selectedSelfieImage = file;
                    _hasFormDataChanges = true;
                  });
                  _uploadSelfie();
                } else {
                  setState(() {
                    _selectedSelfieImage = null;
                    _selfieImgId = null;
                    _fetchedSelfieImageData = null;
                  });
                }
              },
            );
          },
        ),
        const SizedBox(height: 12),
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
          section: "Asset Upload",
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
    // Validation - Only check for selfie
    // Check if selfie is uploaded (has ID) or selected (file exists)
    if ((_selfieImgId == null || _selfieImgId!.isEmpty) && 
        _selectedSelfieImage == null && 
        (_fetchedSelfieImageData == null || _fetchedSelfieImageData!.isEmpty)) {
      showCustomToast(context, "Please add a selfie");
      return;
    }

    try {
      LoaderWidget.showLoader(context);
      await postAssetUpload();
      LoaderWidget.hideLoader();

      showCustomToast(context, "Asset uploaded successfully");

      setState(() {
        _hasFormDataChanges = false;
      });

      if (!navigateOnSuccess) {
        return;
      }

      await Future.delayed(const Duration(milliseconds: 500));

      if (mounted) {
        // Navigate to scan upload screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AUScanUploadScreen(
              siteData: widget.siteData,
              parentContext: widget.parentContext ?? context,
            ),
          ),
        );
      }
    } catch (e) {
      if (LoaderWidget.isShowing) {
        LoaderWidget.hideLoader();
      }

      Logger.errorLog('❌ Error in submit process: $e');

      if (mounted) {
        Toastbar.showErrorToastbar(
          "Error uploading asset: ${e.toString()}",
          context,
        );
      }

      rethrow;
    }
  }
}
