import 'dart:convert';
import 'dart:io';

import 'package:app/commonWidgets/custom_form_appbar.dart';
import 'package:app/commonWidgets/custom_form_field.dart';
import 'package:app/commonWidgets/custom_image_upload_field.dart';
import 'package:app/commonWidgets/custom_submit_button_v2.dart';
import 'package:app/commonWidgets/custom_dialogs/unsaved_changes_dialog.dart';
import 'package:app/constants/app_images.dart';
import 'package:app/constants/constants_methods.dart';
import 'package:app/enum/activity_type_enum.dart';
import 'package:app/enum/corrective_maintenance_screen_mode_enum.dart';
import 'package:app/models/all_site_model.dart';
import 'package:app/models/gen_ins_checklist_model.dart';
import 'package:app/repositories/general_inspection_repository.dart';
import 'package:app/routes/route_generator.dart';
import 'package:app/services/service_locator.dart';
import 'package:app/utils/logger.dart';
import 'package:app/utils/toastbar.dart';
import 'package:app/commonWidgets/loader_widget.dart';
import 'package:app/constants/app_colors.dart';
import 'package:flutter/material.dart';
import 'gi_checklist_screen.dart';
import 'package:app/commonWidgets/safe_svg_picture.dart';

class GInspectionDetailScreen extends StatefulWidget {
  final AllSiteModel siteData;
  final CMScreenModeEnum mode;
  final Map<String, dynamic>? apiResponseData; // Add API response data
  final BuildContext? parentContext;

  const GInspectionDetailScreen({
    super.key,
    required this.siteData,
    required this.mode,
    this.apiResponseData,
    this.parentContext,
  });

  /// GI rows use ticket/schedule id for local DB keys; `genInspection` POST must send the
  /// physical site id from the downloaded payload (`siteId` / `site_id`), not `giId`.
  static int resolvedPhysicalSiteIdForApi({
    Map<String, dynamic>? apiResponseData,
    required int storageAlignedSiteId,
  }) {
    if (apiResponseData != null) {
      final v = apiResponseData['siteId'] ?? apiResponseData['site_id'];
      final parsed = int.tryParse(v?.toString() ?? '');
      if (parsed != null && parsed > 0) {
        return parsed;
      }
    }
    return storageAlignedSiteId;
  }

  @override
  State<GInspectionDetailScreen> createState() =>
      _GInspectionDetailScreenState();
}

class _GInspectionDetailScreenState extends State<GInspectionDetailScreen> {
  final TextEditingController _infraEngineerController =
      TextEditingController();
  final TextEditingController _infraEngineerContactController =
      TextEditingController();
  final TextEditingController _clusterInchargeController =
      TextEditingController();
  final TextEditingController _clusterInchargeContactController =
      TextEditingController();
  final TextEditingController _ownerController = TextEditingController();
  final TextEditingController _ownerContactController = TextEditingController();

  String? _uploadedImgId;
  String? _fetchedImageData;
  File? _selectedImage;
  bool _hasFormDataChanges = false;

  // Checklist data
  bool _isLoadingChecklist = true;
  String? _checklistError;
  List<GenInsCheckListData> _checklistItems = [];
  Map<int, Map<String, dynamic>> _existingChecklistResponses =
      {}; // Store existing responses for edit mode
  late GeneralInspectionRepository _repository;

  @override
  void initState() {
    super.initState();

    _repository = GeneralInspectionRepository(ServiceLocator().apiService);
    _initializeFormData(); // Initialize form fields with existing data
    _loadChecklistData();

    // Add listeners to track form changes
    _infraEngineerController.addListener(() {
      if (!_hasFormDataChanges) {
        setState(() {
          _hasFormDataChanges = true;
        });
      }
    });

    _infraEngineerContactController.addListener(() {
      if (!_hasFormDataChanges) {
        setState(() {
          _hasFormDataChanges = true;
        });
      }
    });

    _ownerController.addListener(() {
      if (!_hasFormDataChanges) {
        setState(() {
          _hasFormDataChanges = true;
        });
      }
    });

    _ownerContactController.addListener(() {
      if (!_hasFormDataChanges) {
        setState(() {
          _hasFormDataChanges = true;
        });
      }
    });

    _clusterInchargeController.addListener(() {
      if (!_hasFormDataChanges) {
        setState(() {
          _hasFormDataChanges = true;
        });
      }
    });

    _clusterInchargeContactController.addListener(() {
      if (!_hasFormDataChanges) {
        setState(() {
          _hasFormDataChanges = true;
        });
      }
    });
  }

  void _populateExistingResponses() {
    if (widget.mode == CMScreenModeEnum.edit &&
        widget.apiResponseData != null) {
      final genInspectionSiteRespList =
          widget.apiResponseData!['genInspectionSiteRespList']
              as List<dynamic>?;
      if (genInspectionSiteRespList != null) {
        for (final response in genInspectionSiteRespList) {
          if (response is! Map) continue;
          final row = Map<String, dynamic>.from(response);
          final giclmId = row['giclmId'] is int
              ? row['giclmId'] as int
              : int.tryParse(row['giclmId']?.toString() ?? '') ??
                  int.tryParse(row['giclm_id']?.toString() ?? '');
          if (giclmId != null) {
            // Find the corresponding checklist item to determine response type
            GenInsCheckListData? checklistItem;
            try {
              checklistItem = _checklistItems.firstWhere(
                (item) => item.giclmId == giclmId,
              );
            } catch (e) {
              // Skip this response if no matching checklist item is found
              continue;
            }

            final gispRaw = row['gispId'] ?? row['gisp_id'];
            final gispId = gispRaw is int
                ? gispRaw
                : int.tryParse(gispRaw?.toString() ?? '');

            Map<String, dynamic> responseData = {
              'giId': widget.apiResponseData!['giId']
                  ?.toString(), // Include giId
              if (gispId != null) 'gispId': gispId,
            };

              // Set the appropriate response value based on the checklist item type
              if (checklistItem.respType.contains('RADIO')) {
                // Map the resp value using respTypeValueMap to get the correct display value
                final respValue = row['resp']?.toString();
                if (respValue != null &&
                    respValue.isNotEmpty &&
                    checklistItem.respTypeValueMap != null) {
                  try {
                    final Map<String, dynamic> decodedMap = json.decode(
                      checklistItem.respTypeValueMap!.value,
                    );
                    String? displayValue;
                    decodedMap.forEach((key, value) {
                      if (value.toString().toLowerCase() ==
                          respValue.toLowerCase()) {
                        displayValue = value.toString();
                      }
                    });
                    responseData['radio_value'] = displayValue ?? respValue;
                  } catch (e) {
                    responseData['radio_value'] = respValue;
                  }
                } else {
                  responseData['radio_value'] = respValue;
                }
              } else if (checklistItem.respType.contains('DROPDOWN')) {
                final respValue = row['resp']?.toString();
                responseData['radio_value'] =
                    respValue; // Dropdown uses same key as radio
              } else if (checklistItem.respType.contains('TEXT')) {
                responseData['text_value'] = row['resp']?.toString();
              }

              // Handle image ID - API may send camelCase or snake_case
              final dynamic photoRaw = row['respPhotoId'] ?? row['resp_photo_id'];
              final respPhotoId = photoRaw?.toString();
              if (respPhotoId != null &&
                  respPhotoId.isNotEmpty &&
                  respPhotoId != "0") {
                if (checklistItem.respType.contains('IMG')) {
                  // Main field has IMG type, so respPhotoId is for the main field
                  responseData['image_id'] = respPhotoId;
                } else {
                  // Main field doesn't have IMG, so respPhotoId might be for dependent IMG elements
                  // Store it for dependent elements
                  responseData['dependent_image_id'] = respPhotoId;
                }
              }

              // Extract remarks from API response for dependent REMARKS elements
              final remarksValue = row['remarks']?.toString();
              if (remarksValue != null &&
                  remarksValue.isNotEmpty &&
                  remarksValue != "null") {
                responseData['dependent_remarks'] = remarksValue;
              }

            _existingChecklistResponses[giclmId] = responseData;
          }
        }
      }
    }
  }

  void _initializeFormData() {
    // Initialize form fields with API response data if available, otherwise use site data
    if (widget.apiResponseData != null) {
      _infraEngineerController.text =
          widget.apiResponseData!['infraDistrictEngineerName']?.toString() ??
          "";
      _infraEngineerContactController.text =
          widget.apiResponseData!['infraDistrictEngineerContactNo']
              ?.toString() ??
          "";
      _clusterInchargeController.text =
          widget.apiResponseData!['cluster_incharge_name']?.toString() ??
          widget.apiResponseData!['clusterInchargeName']?.toString() ??
          "";
      _clusterInchargeContactController.text =
          widget.apiResponseData!['cluster_incharge_contact_no']?.toString() ??
          widget.apiResponseData!['clusterInchargeContactNo']?.toString() ??
          "";
      _ownerController.text =
          widget.apiResponseData!['ownerName']?.toString() ?? "";
      _ownerContactController.text =
          widget.apiResponseData!['ownerContactNo']?.toString() ?? "";

      // Handle existing image from API response
      final visitingPersonImageId = widget
          .apiResponseData!['visitingPersonImageId']
          ?.toString();

      if (visitingPersonImageId != null && visitingPersonImageId.isNotEmpty) {
        _uploadedImgId = visitingPersonImageId;
        _loadImage(visitingPersonImageId);
      } else {
        _uploadedImgId = null;
      }
    } else {
      // Fallback to site data - check if cluster incharge data is available in siteData
      _infraEngineerController.text = widget.siteData.infraEngineerName ?? "";
      _infraEngineerContactController.text =
          widget.siteData.infraEngineerPhone ?? "";
      // Note: cluster incharge data might not be in AllSiteModel, so we'll leave it empty if not in API response
      _clusterInchargeController.text = "";
      _clusterInchargeContactController.text = "";
      _ownerController.text = widget.siteData.ownerName ?? "";
      _ownerContactController.text = widget.siteData.ownerPhone ?? "";

      // Handle existing image from site data
      if (widget.siteData.visitingPersonImageId != null &&
          widget.siteData.visitingPersonImageId!.isNotEmpty) {
        _uploadedImgId = widget.siteData.visitingPersonImageId;
        _loadImage(widget.siteData.visitingPersonImageId!);
      } else {
        _uploadedImgId = null;
      }
    }
  }

  Future<void> _submitForm() async {
    // Validate selfie - check if we have an uploaded image ID
    if (_uploadedImgId == null || _uploadedImgId!.isEmpty) {
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
      // Show error dialog with retry option
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Checklist Data Error'),
          content: Text(_checklistError!),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _loadChecklistData(); // Retry loading
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
      return;
    }

    // Check if we have checklist items
    if (_checklistItems.isEmpty) {
      showCustomToast(
        context,
        "No checklist data available. Please try downloading the data first.",
      );
      return;
    }

    // Extract giId from API response data if available
    int? giId;
    if (widget.apiResponseData != null) {
      giId = widget.apiResponseData!['giId'] as int?;
    }

    try {
      // Navigate to checklist screen with pre-loaded data
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => GIChecklistScreen(
            siteData: widget.siteData,
            physicalSiteIdForPost:
                GInspectionDetailScreen.resolvedPhysicalSiteIdForApi(
              apiResponseData: widget.apiResponseData,
              storageAlignedSiteId: widget.siteData.siteId,
            ),
            mode: widget.mode,
            visitingPersonImageId: _uploadedImgId,
            checklistItems: _checklistItems,
            existingResponses: _existingChecklistResponses.isNotEmpty
                ? _existingChecklistResponses
                : null,
            giId: giId,
            parentContext: widget.parentContext ?? context,
          ),
        ),
      );
    } catch (e) {
      Logger.errorLog('❌ Error in submit process: $e');
      rethrow; // Re-throw so UnsavedChangesDialog can handle the error
    }
  }

  Future<void> _loadImage(String imageId) async {
    try {
      String? uniqueId;

      // Check if this is already a unique ID (offline mode) or a server ID (online mode)
      if (imageId.contains("LOCAL_IMAGE_ID")) {
        // This is already a unique ID from offline mode
        uniqueId = imageId;
      } else {
        // This is a server ID, try to download from server (online mode)
        uniqueId = await ServiceLocator().imageUploadService
            .downloadImageUsingServerId(
              imageId,
              ActivityTypeEnum.generalInspection,
              widget.siteData.siteId.toString(),
            );
      }

      if (uniqueId != null) {
        // Now get the image data using the unique ID
        final imageData = await ServiceLocator().centralAssetAuditService
            .getImageAsDataUrl(uniqueId);

        if (imageData != null) {
          Logger.debugLog(
            '✅ Image data received: ${imageData.length} characters',
          );
          setState(() {
            _fetchedImageData = imageData;
          });
          Logger.debugLog('✅ Image loaded successfully and state updated');
        } else {
          Logger.errorLog(
            '❌ Failed to load image data with uniqueId $uniqueId - imageData is null',
          );
        }
      } else {
        Logger.errorLog('❌ Failed to get unique ID for image: $imageId');
      }
    } catch (e) {
      Logger.errorLog('❌ Error loading image: $e');
    }
  }

  @override
  void dispose() {
    _infraEngineerController.dispose();
    _infraEngineerContactController.dispose();
    _clusterInchargeController.dispose();
    _clusterInchargeContactController.dispose();
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
        onClose: () => _showUnsavedChangesDialog(),
      ),
      body: Stack(
        children: [
          // Background
          Positioned.fill(
            child: SafeSvgPicture.asset(
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
          label: "Infra Engineer Name",
          initialValue: widget.siteData.infraEngineerName ?? "N/A",
          isRequired: false,
          isEditable: false,
        ),
        const SizedBox(height: 15),

        // Infra Engineer Contact No.
        CustomFormField(
          label: "Infra Engineer Contact No.",
          initialValue: widget.siteData.infraEngineerPhone ?? "N/A",
          isRequired: false,
          isEditable: false,
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 15),

        // Cluster Incharge
        CustomFormField(
          label: "Cluster Incharge Name",
          initialValue: widget.siteData.clusterInchargeName ?? "N/A",
          isRequired: false,
          isEditable: false,
        ),
        const SizedBox(height: 15),

        // Cluster Incharge Contact No.
        CustomFormField(
          label: "Cluster Incharge Contact No.",
          initialValue: widget.siteData.clusterInchargeContactNo ?? "N/A",
          isRequired: false,
          isEditable: false,
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 15),

        // Owner
        CustomFormField(
          label: "Owner",
          initialValue: widget.siteData.ownerName ?? "N/A",
          isRequired: false,
          isEditable: false,
        ),
        const SizedBox(height: 15),

        // Owner Contact No.
        CustomFormField(
          label: "Owner Contact No.",
          initialValue: widget.siteData.ownerPhone ?? "N/A",
          isRequired: false,
          isEditable: false,
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 20),

        // Installed Asset Details Section
        _buildDownloadSection(
          title: "Installed Asset Details",
          displayText: "Installed Asset Details",
          onDownload: () => _downloadInstalledAssetDetails(
            ActivityTypeEnum.assetAudit,
            widget.siteData.lastAASiteAuditSchId,
          ),
          isLightBlue: true,
        ),
        const SizedBox(height: 15),

        // Last PM Details Section
        _buildDownloadSection(
          title: "Last PM Details",
          displayText: _formatDate(widget.siteData.lastPMDate ?? "N/A"),
          onDownload: () => _downloadInstalledAssetDetails(
            ActivityTypeEnum.preventiveMaintenance,
            widget.siteData.lastPMSiteAuditSchId,
          ),
          isLightBlue: false,
        ),
        const SizedBox(height: 15),

        // Last CM Details Section
        _buildDownloadSection(
          title: "Last CM Details",
          displayText: _formatDate(widget.siteData.lastCMDate ?? "N/A"),
          onDownload: () => _downloadInstalledAssetDetails(
            ActivityTypeEnum.correctiveMaintenance,
            widget.siteData.lastCMSiteReqId,
          ),
          isLightBlue: false,
        ),
        const SizedBox(height: 20),

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
                    _hasFormDataChanges = true;
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
        activityType: ActivityTypeEnum.generalInspectionSelf,
      );

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
          if (!mounted) return;
        }
      }

      if (imgId != null && imgId.isNotEmpty) {
        if (!mounted) return;
        setState(() {
          _uploadedImgId = imgId;
        });

        // Show appropriate message based on whether it's server or local ID
        if (imgId.contains("LOCAL_IMAGE_ID")) {
          if (!mounted) return;
          showCustomToast(context, 'Selfie saved locally (offline mode)');
        } else {
          if (!mounted) return;
          showCustomToast(context, 'Selfie uploaded successfully');
        }
      } else {
        if (!mounted) return;
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

      Logger.debugLog(
        'Loading checklist data for site ID: ${widget.siteData.siteId}',
      );

      // First, try to get checklist data from local database
      try {
        final localChecklistData = await ServiceLocator()
            .centralAssetAuditDataService
            .getGIChecklistData(widget.siteData.siteId);

        if (localChecklistData.isNotEmpty) {
          // Use local data if available
          Logger.debugLog(
            'Using local checklist data: ${localChecklistData.length} items',
          );
          setState(() {
            _checklistItems = localChecklistData;
            _isLoadingChecklist = false;
          });
          _populateExistingResponses(); // Populate existing responses after checklist data is loaded
          return;
        } else {
          Logger.debugLog(
            'No local checklist data found for site ID: ${widget.siteData.siteId}',
          );
        }
      } catch (localError) {
        Logger.debugLog('Local data retrieval failed: $localError');
      }

      // If no local data, try to fetch from API
      Logger.debugLog('No local data found, fetching from API...');
      try {
        final siteDomainId = 1; // Default site domain ID
        final checklistItems = await _repository.getGenInsCheckListData(
          siteDomainId,
        );

        // Sort by cl_order
        checklistItems.sort((a, b) => a.clOrder.compareTo(b.clOrder));

        setState(() {
          _checklistItems = checklistItems;
          _isLoadingChecklist = false;
        });

        Logger.debugLog(
          'Loaded ${checklistItems.length} checklist items from API',
        );
        _populateExistingResponses(); // Populate existing responses after checklist data is loaded
      } catch (apiError) {
        Logger.errorLog('API call failed: $apiError');

        // If API failed, try to get any available local data as fallback
        try {
          final fallbackData = await ServiceLocator()
              .centralAssetAuditDataService
              .getGIChecklistData(widget.siteData.siteId);

          if (fallbackData.isNotEmpty) {
            Logger.debugLog(
              'Using fallback local data: ${fallbackData.length} items',
            );
            setState(() {
              _checklistItems = fallbackData;
              _isLoadingChecklist = false;
              _checklistError = null; // Clear error since we have local data
            });
            _populateExistingResponses(); // Populate existing responses after checklist data is loaded
            return;
          }
        } catch (fallbackError) {
          Logger.errorLog('Fallback local data also failed: $fallbackError');
        }

        // If both API and local data failed, show error
        setState(() {
          _isLoadingChecklist = false;
          _checklistError =
              'Failed to load checklist data. Please check your internet connection and try downloading the data first.';
        });
      }
    } catch (e) {
      Logger.errorLog('Unexpected error loading checklist data: $e');
      setState(() {
        _isLoadingChecklist = false;
        _checklistError = 'Unexpected error: ${e.toString()}';
      });
    }
  }

  void _showUnsavedChangesDialog() {
    if (_hasFormDataChanges) {
      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (dialogContext) => UnsavedChangesDialog(
          siteAuditSchId: widget.siteData.siteId.toString(),
          section: "General Inspection",
          parentContext: widget.parentContext ?? context,
          onSaveAndExit: () async {
            await _submitForm();
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

  String _formatDate(dynamic dateValue) {
    if (dateValue == null) {
      return 'N/A';
    }

    try {
      String dateString = dateValue.toString();
      if (dateString.isEmpty || dateString == 'null') {
        return 'N/A';
      }

      // Try parsing different date formats
      DateTime? date;
      if (dateString.contains('-')) {
        // Try ISO format or DD-MM-YYYY
        try {
          date = DateTime.parse(dateString);
        } catch (e) {
          // Try DD-MM-YYYY format
          final parts = dateString.split('-');
          if (parts.length == 3) {
            date = DateTime(
              int.parse(parts[2]),
              int.parse(parts[1]),
              int.parse(parts[0]),
            );
          }
        }
      } else if (dateString.contains('/')) {
        // Try DD/MM/YYYY format
        final parts = dateString.split('/');
        if (parts.length == 3) {
          date = DateTime(
            int.parse(parts[2]),
            int.parse(parts[1]),
            int.parse(parts[0]),
          );
        }
      }

      if (date != null) {
        final months = [
          'JAN',
          'FEB',
          'MAR',
          'APR',
          'MAY',
          'JUN',
          'JUL',
          'AUG',
          'SEP',
          'OCT',
          'NOV',
          'DEC',
        ];
        final day = date.day.toString().padLeft(2, '0');
        final month = months[date.month - 1];
        final year = date.year;
        return '$day-$month-$year';
      }

      return dateString;
    } catch (e) {
      Logger.errorLog('Error formatting date: $e');
      return dateValue.toString();
    }
  }

  Widget _buildDownloadSection({
    required String title,
    required String displayText,
    required VoidCallback onDownload,
    required bool isLightBlue,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppColors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
            fontFamily: 'Poppins',
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onDownload,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: isLightBlue
                  ? const Color(0xFFE3F2FD)
                  : const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    displayText,
                    style: TextStyle(
                      color: isLightBlue
                          ? const Color(0xFF1976D2)
                          : const Color(0xFF424242),
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      fontFamily: 'Montserrat',
                    ),
                  ),
                ),
                Icon(
                  Icons.download,
                  color: isLightBlue
                      ? const Color(0xFF1976D2)
                      : const Color(0xFF424242),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _downloadInstalledAssetDetails(
    ActivityTypeEnum activityType,
    int? siteAuditSchId,
  ) async {
    try {
      if (siteAuditSchId == null) {
        Toastbar.showErrorToastbar('No Report found', context);
        return;
      }

      LoaderWidget.showLoader(context);

      // `rp_sch_id` must be the activity schedule id from the payload (e.g. last PM site audit sch id).
      final service = ServiceLocator().centralApiService;
      final filePath = await service.downloadPdfReport(
        ticketId: widget.siteData.siteCode,
        ticketSchId: siteAuditSchId.toString(),
        activityType: activityType,
      );
      if (!mounted) return;

      if (filePath != null) {
        String locationMessage;
        if (filePath.contains('/Download/')) {
          locationMessage =
              'PDF saved to Downloads folder! Open file manager → Downloads to view';
        } else {
          locationMessage =
              'PDF saved to app storage. Check Android → data → com.rapadit.flutter_template_rad → files → Downloads';
        }
        Toastbar.showSuccessToastbar(locationMessage, context);
      } else {
        Toastbar.showErrorToastbar(
          'Failed to download Installed Asset Details',
          context,
        );
      }
    } catch (e) {
      Logger.errorLog('Error downloading Installed Asset Details: $e');
      Toastbar.showErrorToastbar(
        'Error downloading Installed Asset Details',
        context,
      );
    } finally {
      LoaderWidget.hideLoader();
    }
  }
}
