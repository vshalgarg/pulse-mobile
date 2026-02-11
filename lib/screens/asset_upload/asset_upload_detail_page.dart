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
import 'package:app/repositories/asset_upload_respository.dart';
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
  final String? preloadedSelfieImageId;
  final List<Map<String, dynamic>>? preloadedAssetItems;
  final int? preloadedAuId;
  final CMScreenModeEnum mode;
  /// When opening from a downloaded ticket, pass the same key used to load the ticket
  /// so that persist updates that row (e.g. ticket.siteAuditSchId or ticket.ticketSchId).
  final String? siteAuditSchIdForStorage;

  const AssetUploadDetailPage({
    super.key,
    required this.siteData,
    this.parentContext,
    this.preloadedSelfieImageId,
    this.preloadedAssetItems,
    this.preloadedAuId,
    this.mode = CMScreenModeEnum.create,
    this.siteAuditSchIdForStorage,
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
  late AssetUploadRepository _assetUploadRepository;
  bool _hasFormDataChanges = false;

  // Selfie related variables
  String? _selfieImgId;
  String? _fetchedSelfieImageData;
  File? _selectedSelfieImage;

  // Actual mode - override to edit if au_id is not null
  late CMScreenModeEnum _actualMode;

  @override
  void initState() {
    super.initState();
   
    // If preloadedAuId is not null, treat as edit mode even if mode is create
    _actualMode = (widget.preloadedAuId != null && widget.preloadedAuId! > 0)
        ? CMScreenModeEnum.edit
        : widget.mode;
    
    print('📋 AssetUploadDetailPage - Mode: ${widget.mode}, Actual Mode: $_actualMode, preloadedAuId: ${widget.preloadedAuId}');
    Logger.debugLog('📋 AssetUploadDetailPage - Received preloaded data:');
    Logger.debugLog('📋   preloadedSelfieImageId: ${widget.preloadedSelfieImageId}');
    Logger.debugLog('📋   preloadedAuId: ${widget.preloadedAuId}');
    Logger.debugLog('📋   preloadedAssetItems: ${widget.preloadedAssetItems != null ? widget.preloadedAssetItems!.length : "null"}');
    _service = ServiceLocator().centralAssetAuditService;
    _assetUploadRepository = AssetUploadRepository(
      ServiceLocator().apiService,
    );
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

    // Check if we have preloaded data from API (when coming from ticket screen)
    final hasPreloadedData = (widget.preloadedAuId != null && widget.preloadedAuId! > 0) ||
                            (widget.preloadedSelfieImageId != null && 
                             widget.preloadedSelfieImageId!.isNotEmpty &&
                             widget.preloadedSelfieImageId != "0" &&
                             widget.preloadedSelfieImageId != "null") ||
                            (widget.preloadedAssetItems != null && widget.preloadedAssetItems!.isNotEmpty);

    if (hasPreloadedData) {
      // We have preloaded data from API - use it directly, don't fetch from SQLite
      Logger.debugLog('✅ Using preloaded data from API');
      
      // Load selfie if available
      if (widget.preloadedSelfieImageId != null && 
          widget.preloadedSelfieImageId!.isNotEmpty &&
          widget.preloadedSelfieImageId != "0" &&
          widget.preloadedSelfieImageId != "null") {
        _selfieImgId = widget.preloadedSelfieImageId;
        _loadSelfieImage(widget.preloadedSelfieImageId!);
        Logger.debugLog('✅ Loaded preloaded selfie image ID: ${widget.preloadedSelfieImageId}');
      }
      
      // Asset items will be passed to AUScanUploadScreen via widget.preloadedAssetItems
      // No need to load from SQLite - we have fresh data from API
      Logger.debugLog('✅ Preloaded asset items: ${widget.preloadedAssetItems?.length ?? 0}');
      
      // Update state to show the loaded data
      if (mounted) {
        setState(() {});
      }
    } else {
      // No preloaded data - fetch from API or load from SQLite based on mode
      if (_actualMode == CMScreenModeEnum.create) {
        _fetchAssetUploadDataFromAPI();
      } else {
        // In edit mode without preloaded data, load from local storage
      _loadExistingAssetData();
      _loadStoredSelfie();
      }
    }
  }

  /// Fetches asset upload data from API in create mode
  Future<void> _fetchAssetUploadDataFromAPI() async {
    try {
      Logger.debugLog('📡 Fetching asset upload data from API for siteId: ${widget.siteData.siteId}');
      
      final result = await _assetUploadRepository.getUploadedAssets(
        siteId: widget.siteData.siteId,
      );

      if (result.isSuccess && result.data != null) {
        final data = result.data!;
        Logger.debugLog('✅ Successfully fetched asset upload data: ${data.keys.toList()}');
        
        // Populate form fields from API response
        if (data['assetName'] != null) {
          _assetNameController.text = data['assetName'].toString();
        }
        if (data['assetSerialNumber'] != null) {
          _assetSerialNumberController.text = data['assetSerialNumber'].toString();
        }
        if (data['assetMake'] != null) {
          _assetMakeController.text = data['assetMake'].toString();
        }
        if (data['assetModel'] != null) {
          _assetModelController.text = data['assetModel'].toString();
        }
        if (data['assetCapacity'] != null) {
          _assetCapacityController.text = data['assetCapacity'].toString();
        }
        if (data['assetLocation'] != null) {
          _assetLocationController.text = data['assetLocation'].toString();
        }

        // Load selfie image if available
        final makerSelfieImageId = data['makerSelfieImageId'] ?? 
                                   data['maker_selfie_image_id'];
        if (makerSelfieImageId != null) {
          final selfieImageIdStr = makerSelfieImageId.toString();
          // Check if it's not 0 or "0" or "null"
          if (selfieImageIdStr.isNotEmpty && 
              selfieImageIdStr != "0" && 
              selfieImageIdStr != "null" &&
              selfieImageIdStr.toLowerCase() != "null") {
            _selfieImgId = selfieImageIdStr;
            _loadSelfieImage(selfieImageIdStr);
            Logger.debugLog('✅ Loaded selfie image ID from API: $selfieImageIdStr');
          }
        }

        // Update state to reflect loaded data
        if (mounted) {
          setState(() {});
        }
      } else {
        Logger.debugLog('⚠️ No asset upload data found or fetch failed: ${result.errorMessage}');
        // If no data, still load selfie from stored data as fallback
        _loadStoredSelfie();
      }
    } catch (e) {
      Logger.errorLog('❌ Error fetching asset upload data from API: $e');
      // If API call fails, fallback to loading from stored data
      _loadStoredSelfie();
    }
  }

  Future<void> _loadStoredSelfie() async {
    try {
      // First check if preloaded selfie image ID is available
      if (widget.preloadedSelfieImageId != null && 
          widget.preloadedSelfieImageId!.isNotEmpty) {
        final preloadedId = widget.preloadedSelfieImageId!;
        if (preloadedId != "0" && preloadedId != "null") {
          _selfieImgId = preloadedId;
          _loadSelfieImage(preloadedId);
          Logger.debugLog('✅ Loaded preloaded selfie image ID: $preloadedId');
          return;
        }
      }

      // Fallback to loading from database
      final service = ServiceLocator().centralAssetAuditService;
      final storedData = await service.getActualDataFromSqlite(
        siteAuditSchId: widget.siteData.siteId.toString(),
      );

      if (storedData != null) {
        // Check assetUpload data structure first (for create mode)
        final assetUpload = storedData['assetUpload'];
        if (assetUpload != null && assetUpload is Map<String, dynamic>) {
          final makerSelfieImageId = assetUpload['makerSelfieImageId'] ?? 
                                     assetUpload['maker_selfie_image_id'];
          if (makerSelfieImageId != null) {
            final selfieImageIdStr = makerSelfieImageId.toString();
            // Check if it's not 0 or "0" or "null"
            if (selfieImageIdStr.isNotEmpty && 
                selfieImageIdStr != "0" && 
                selfieImageIdStr != "null" &&
                selfieImageIdStr.toLowerCase() != "null") {
              _selfieImgId = selfieImageIdStr;
              _loadSelfieImage(selfieImageIdStr);
              Logger.debugLog('✅ Loaded selfie image ID from assetUpload: $selfieImageIdStr');
              return;
            }
          }
        }

        // Fallback to pageHeader (for edit mode)
        final pageHeaders = storedData['pageHeader'] as List<dynamic>?;
        final pageHeader = pageHeaders?.isNotEmpty == true
            ? pageHeaders!.first as Map<String, dynamic>?
            : null;

        if (pageHeader != null && pageHeader['maker_selfie_image_id'] != null) {
          final selfieImageId = pageHeader['maker_selfie_image_id'].toString();
          // Check if it's not 0 or "0" or "null"
          if (selfieImageId.isNotEmpty && 
              selfieImageId != "0" && 
              selfieImageId != "null" &&
              selfieImageId.toLowerCase() != "null") {
            _selfieImgId = selfieImageId;
            _loadSelfieImage(selfieImageId);
            Logger.debugLog('✅ Loaded selfie image ID from pageHeader: $selfieImageId');
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
      Logger.debugLog('📸 Loading selfie image with ID: $imageId');
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
        Logger.debugLog('✅ Successfully loaded selfie image data (length: ${imageData.length})');
        setState(() {
          _fetchedSelfieImageData = imageData;
        });
      } else {
        Logger.debugLog('⚠️ Selfie image data is null or empty');
      }
    } catch (e) {
      Logger.errorLog('❌ Error loading selfie image: $e');
      Logger.errorLog('❌ Stack trace: ${StackTrace.current}');
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
        Logger.debugLog('✅ Selfie uploaded successfully with imgId: $imgId');
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
        Logger.errorLog('❌ Failed to get selfie image ID - imgId is null or empty');
        showCustomToast(context, 'Failed to upload selfie');
        throw Exception('Failed to get selfie image ID');
      }
    } catch (e) {
      Logger.errorLog('❌ Error uploading selfie: $e');
    }
  }



  Future<void> postAssetUpload() async {
    try {
      // maker_selfie_image_id must be a valid server-side image_mst id.
      // Sending 0 causes a FK violation on the backend.
      final parsedSelfieId =
          (_selfieImgId != null && _selfieImgId!.isNotEmpty)
              ? int.tryParse(_selfieImgId!)
              : null;
      if (parsedSelfieId == null || parsedSelfieId <= 0) {
        Toastbar.showErrorToastbar(
          'Selfie is required. Please upload the selfie again before submitting.',
          context,
        );
        return;
      }

      final requestData = {
        "siteId": widget.siteData.siteId,
        "assetName": _assetNameController.text.trim(),
        "assetSerialNumber": _assetSerialNumberController.text.trim(),
        "assetMake": _assetMakeController.text.trim(),
        "assetModel": _assetModelController.text.trim(),
        "assetCapacity": _assetCapacityController.text.trim(),
        "assetLocation": _assetLocationController.text.trim(),
        "maker_selfie_image_id": parsedSelfieId,
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

  /// Persist current form and selfie to the downloaded ticket row so it stays in sync.
  Future<void> _persistDetailPageToSqlite() async {
    final storageKey = widget.siteAuditSchIdForStorage;
    if (storageKey == null || storageKey.isEmpty) return;
    try {
      final dataService = ServiceLocator().centralAssetAuditDataService;
      final row = await dataService.getRawApiData(storageKey);
      if (row == null) return;
      final apiData = Map<String, dynamic>.from(row.apiData);
      // Merge site_details (snake_case)
      final siteDetails = (apiData['site_details'] ?? apiData['siteDetails'] ?? {}) as Map<String, dynamic>?;
      final siteDetailsMap = siteDetails != null ? Map<String, dynamic>.from(siteDetails) : <String, dynamic>{};
      siteDetailsMap['infra_district_engineer_name'] = _infraEngineerController.text.trim().isEmpty ? null : _infraEngineerController.text.trim();
      siteDetailsMap['infra_district_engineer_contact_no'] = _infraEngineerContactController.text.trim().isEmpty ? null : _infraEngineerContactController.text.trim();
      siteDetailsMap['owner_name'] = _ownerController.text.trim().isEmpty ? null : _ownerController.text.trim();
      siteDetailsMap['owner_contact_no'] = _ownerContactController.text.trim().isEmpty ? null : _ownerContactController.text.trim();
      apiData['site_details'] = siteDetailsMap;
      apiData['siteDetails'] = siteDetailsMap;
      // Merge maker_selfie_image_id into asset_upload
      if (_selfieImgId != null && _selfieImgId!.isNotEmpty) {
        final au = (apiData['asset_upload'] ?? apiData['assetUpload'] ?? {}) as Map<String, dynamic>?;
        final auMap = au != null ? Map<String, dynamic>.from(au) : <String, dynamic>{};
        auMap['maker_selfie_image_id'] = _selfieImgId;
        auMap['makerSelfieImageId'] = _selfieImgId;
        apiData['asset_upload'] = auMap;
        apiData['assetUpload'] = auMap;
      }
      await dataService.updateRawApiData(siteAuditSchId: storageKey, apiData: apiData);
      Logger.debugLog('✅ Asset upload detail page persisted to SQLite for key: $storageKey');
    } catch (e) {
      Logger.errorLog('❌ _persistDetailPageToSqlite: $e');
    }
  }

  void _showUnsavedChangesDialog() {
    if (_hasFormDataChanges) {
      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (dialogContext) => UnsavedChangesDialog(
          siteAuditSchId: widget.siteAuditSchIdForStorage ?? widget.siteData.siteId.toString(),
          section: "Asset Upload",
          parentContext: widget.parentContext ?? context,
          onSaveAndExit: () async {
            await _submitForm(navigateOnSuccess: false);
          },
          onDiscard: () {
            navigateBackOrToHome(
              context,
              targetContext: widget.parentContext ?? context,
            );
          },
          onDiscardAsync: () async {
            await _persistDetailPageToSqlite();
          },
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
    // Validation - Check if selfie exists
    // Selfie can exist in one of these forms:
    // 1. Has an uploaded image ID (_selfieImgId)
    // 2. Has a selected image file (_selectedSelfieImage)
    // 3. Has fetched image data (_fetchedSelfieImageData)
    final hasSelfie = (_selfieImgId != null && _selfieImgId!.isNotEmpty) ||
        _selectedSelfieImage != null ||
        (_fetchedSelfieImageData != null && _fetchedSelfieImageData!.isNotEmpty);

    if (!hasSelfie) {
      // Show error if selfie is not present
      Toastbar.showErrorToastbar(
        "Please add a selfie before proceeding",
        context,
      );
      return;
    }

    // If validation passed but we shouldn't navigate (e.g., from unsaved changes dialog)
    if (!navigateOnSuccess) {
      return;
    }

    // Navigate to scan upload screen without calling any API
    // Pass the selfie image ID and preloaded asset items if available
    // Prefer current _selfieImgId (e.g. just uploaded) so save on scan screen uses latest selfie
    final selfieImageIdToPass = _selfieImgId ?? widget.preloadedSelfieImageId;
    
    Logger.debugLog('📸 ========== NAVIGATING TO SCAN UPLOAD ==========');
    Logger.debugLog('📸 selfieImageIdToPass: $selfieImageIdToPass');
    Logger.debugLog('📸 widget.preloadedSelfieImageId: ${widget.preloadedSelfieImageId}');
    Logger.debugLog('📸 _selfieImgId: $_selfieImgId');
    Logger.debugLog('📦 Preloaded asset items count: ${widget.preloadedAssetItems?.length ?? 0}');
    Logger.debugLog('📦 Preloaded auId: ${widget.preloadedAuId}');
    Logger.debugLog('📦 Actual mode: $_actualMode');
    Logger.debugLog('📸 ==============================================');
    
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AUScanUploadScreen(
            siteData: widget.siteData,
            parentContext: widget.parentContext ?? context,
            preloadedSelfieImageId: selfieImageIdToPass, // Pass the selfie image ID (prefer preloaded)
            preloadedAssets: widget.preloadedAssetItems, // Pass preloaded asset items
            preloadedAuId: widget.preloadedAuId, // Pass auId for update
            mode: _actualMode, // Pass the actual mode (may be overridden if au_id is not null)
            siteAuditSchIdForStorage: widget.siteAuditSchIdForStorage,
          ),
        ),
      );
    }
  }
}