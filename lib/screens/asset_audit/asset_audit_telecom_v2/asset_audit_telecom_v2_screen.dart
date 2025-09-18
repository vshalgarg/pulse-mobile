import 'dart:io';
import 'package:app/commonWidgets/asset_audit_telecom_bottom_buttons.dart';
import 'package:app/screens/home_screen.dart';
import 'package:app/utils/asset_audit_navigation_helper.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_svg/svg.dart';
import '../../../commonWidgets/asset_audit_solar_bottom_buttons.dart';
import '../../../commonWidgets/custom_form_appbar.dart';
import '../../../commonWidgets/custom_form_field.dart';
import '../../../commonWidgets/custom_image_upload_field.dart';
import '../../../commonWidgets/custom_buttons/arrow_botton.dart';
import '../../../commonWidgets/custom_dialogs/unsaved_changes_dialog.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_images.dart';
import '../../../constants/constants_methods.dart';
import '../../../services/service_locator.dart';
import '../../../utils/logger.dart';
import '../../../models/asset_audit_model.dart';
import '../../../services/asset_audit/central_service_initializer.dart';
import '../../../services/asset_audit/central_asset_audit_service.dart';

class AssetAuditTelecomV2Screen extends StatefulWidget {
  final String siteType;
  final String auditSchId;
  final String siteAuditSchId;

  const AssetAuditTelecomV2Screen({
    super.key,
    required this.siteType,
    required this.auditSchId,
    required this.siteAuditSchId,
  });

  @override
  State<AssetAuditTelecomV2Screen> createState() => _AssetAuditTelecomV2ScreenState();
}

class _AssetAuditTelecomV2ScreenState extends State<AssetAuditTelecomV2Screen> {
  final String _screenName = 'GENERAL';
  late CentralAssetAuditService _service;

  // Loading states
  bool _isLoadingData = true;
  String? _errorMessage;

  // Form controllers
  final TextEditingController _serialController = TextEditingController();
  final TextEditingController _cctvSerialController = TextEditingController();

  // Form data
  bool _hasFormDataChanges = false;
  bool _showValidationErrors = false;

  // Image data
  String? _uploadedImgId;
  String? _fetchedImageData;
  File? _selectedImage;

  // Asset audit data
  Map<String, dynamic>? _assetAuditData;
  Map<String, dynamic>? _displayFormData;

  @override
  void initState() {
    super.initState();
    _initializeServices();
    _loadData();
  }

  void _initializeServices() {
    Logger.debugLog('🔧 Initializing Central Asset Audit service for Telecom');
    _service = ServiceLocator().centralAssetAuditService;

    // Check if service is initialized
    if (!CentralAssetAuditServiceInitializer.isInitialized) {
      Logger.errorLog('❌ Central service not initialized!');
      setState(() {
        _errorMessage = 'Central service not initialized. Please restart the app.';
        _isLoadingData = false;
      });
      return;
    }

    Logger.debugLog('✅ Central Asset Audit service initialized successfully for Telecom');
  }

  Future<void> _loadData() async {
    try {
      setState(() {
        _isLoadingData = true;
        _errorMessage = null;
      });

      Logger.debugLog('🔄 Loading telecom asset audit data for site ${widget.siteAuditSchId}');

      // Use the actual service to load data
      final data = await _service.getActualDataFromSqlite(
        siteAuditSchId: widget.siteAuditSchId,
      );

      if (data != null) {
        Logger.debugLog('📊 Received telecom data from service');
        Logger.debugLog('📊 Data keys: ${data.keys.toList()}');
        Logger.debugLog('📊 Full data: $data');
        Logger.debugLog('📊 Categories: ${data['categories']}');

        // Extract page header data for form fields
        final pageHeaders = data['pageHeader'] as List<dynamic>?;
        final pageHeader = pageHeaders?.isNotEmpty == true ? pageHeaders!.first as Map<String, dynamic> : null;
        final formData = <String, String>{};

        if (pageHeader != null) {
          // Telecom specific fields
          formData['circle'] = pageHeader['circle']?.toString() ?? "N/A";
          formData['cluster'] = pageHeader['cluster']?.toString() ?? "N/A";
          formData['indoorOutdoor'] = pageHeader['indoor_outdoor']?.toString() ?? "N/A";
          formData['ebNonEb'] = pageHeader['eb_non_eb']?.toString() ?? "N/A";
          formData['op1Name'] = pageHeader['op1_name']?.toString() ?? "N/A";
          formData['op2Name'] = pageHeader['op2_name']?.toString() ?? "N/A";
          formData['siteId'] = pageHeader['site_id']?.toString() ?? "N/A";
          
          // Common fields
          formData['district'] = pageHeader['district']?.toString() ?? "N/A";
          formData['clientName'] = pageHeader['client_name']?.toString() ?? "N/A";
          formData['siteCode'] = pageHeader['site_code']?.toString() ?? "N/A";
          formData['siteName'] = pageHeader['site_name']?.toString() ?? "N/A";
          formData['siteType'] = pageHeader['site_type_name']?.toString() ?? "N/A";
          formData['status'] = pageHeader['status']?.toString() ?? "N/A";
        } else {
          Logger.errorLog('❌ No page header data found!');
        }

        setState(() {
          _isLoadingData = false;
          _assetAuditData = data; // Store the full asset audit data for navigation
          _displayFormData = formData; // Store the extracted form data for display
        });
        Logger.debugLog('✅ Telecom asset audit data loaded successfully');
        Logger.debugLog('📊 Form data: $formData');

        // Load image if we have an image ID from the page header
        if (pageHeader != null && pageHeader['maker_selfie_image_id'] != null) {
          Logger.debugLog('🖼️ Found makerSelfieImageId: ${pageHeader['maker_selfie_image_id']}');
          await _loadImage(pageHeader['maker_selfie_image_id'].toString());
        } else {
          Logger.debugLog('⚠️ No makerSelfieImageId found in page header');
          Logger.debugLog('📋 Page header keys: ${pageHeader?.keys.toList()}');
        }
      } else {
        setState(() {
          _isLoadingData = false;
          _errorMessage = 'No data available for this site';
        });
        Logger.errorLog('❌ No data available for site ${widget.siteAuditSchId}');
      }
    } catch (e) {
      Logger.errorLog('❌ Error loading telecom data: $e');
      setState(() {
        _isLoadingData = false;
        _errorMessage = 'Failed to load data: $e';
      });
    }
  }

  Future<void> _loadImage(String imageId) async {
    try {
      // Use the actual service to load image
      final imageData = await _service.getImageAsDataUrl(imageId);

      if (imageData != null) {
        Logger.debugLog('✅ Image data received: ${imageData.length} characters');
        Logger.debugLog('✅ Image data preview: ${imageData.substring(0, imageData.length > 100 ? 100 : imageData.length)}...');
        setState(() {
          _fetchedImageData = imageData;
        });
        Logger.debugLog('✅ Image loaded successfully and state updated');
      } else {
        Logger.errorLog('❌ Failed to load image $imageId - imageData is null');
      }
    } catch (e) {
      Logger.errorLog('❌ Error loading image: $e');
      Logger.errorLog('❌ Stack trace: ${StackTrace.current}');
    }
  }

  Future<void> _uploadSelfie() async {
    try {
      if (_selectedImage == null) {
        showCustomToast(context, 'Please select an image first');
        return;
      }

      // Use the actual service to upload selfie
      final imgId = await _service.uploadImage(
        siteAuditSchId: widget.siteAuditSchId,
        imageFile: _selectedImage!,
      );

      final dbData = await _service.getActualDataFromSqlite(
        siteAuditSchId: widget.siteAuditSchId,
      );
      if(dbData != null) {
        final pageHeaders = dbData['pageHeader'] as List<dynamic>?;
        final pageHeader = pageHeaders?.isNotEmpty == true ? pageHeaders!.first as Map<String, dynamic> : null;
        if(pageHeader != null) {
          pageHeader['maker_selfie_image_id'] = imgId;
        }
      }
      if (imgId != null) {
        setState(() {
          _uploadedImgId = imgId;
          _hasFormDataChanges = true;
        });

        showCustomToast(context, 'Selfie uploaded successfully');
        Logger.debugLog('✅ Selfie uploaded with ID: $imgId');
      } else {
        showCustomToast(context, 'Failed to upload selfie');
        Logger.errorLog('❌ Failed to upload selfie');
      }
    } catch (e) {
      Logger.errorLog('❌ Error uploading selfie: $e');
      showCustomToast(context, 'Failed to upload selfie: $e');
    }
  }

  @override
  void dispose() {
    _serialController.dispose();
    _cctvSerialController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      resizeToAvoidBottomInset: true,
      appBar: CustomFormAppbar(
        title: 'Asset Audit',
        onClose: () {
          _showUnsavedChangesDialog();
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
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.of(context).viewInsets.bottom + 100,
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
                          // Show loading indicator
                          if (_isLoadingData)
                            Container(
                              padding: const EdgeInsets.all(20),
                              child: const Center(
                                child: Column(
                                  children: [
                                    CircularProgressIndicator(
                                      color: AppColors.primaryGreen,
                                    ),
                                    SizedBox(height: 16),
                                    Text(
                                      'Loading site data...',
                                      style: TextStyle(
                                        color: AppColors.white,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                          // Show error message
                          if (_errorMessage != null && !_isLoadingData)
                            Container(
                              margin: const EdgeInsets.only(bottom: 20),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.errorColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: AppColors.errorColor,
                                  width: 1,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.error_outline,
                                        color: AppColors.errorColor,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Failed to load site data',
                                          style: TextStyle(
                                            color: AppColors.errorColor,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _errorMessage!,
                                    style: TextStyle(
                                      color: AppColors.errorColor,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  ElevatedButton(
                                    onPressed: _loadData,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.errorColor,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 8,
                                      ),
                                    ),
                                    child: const Text('Retry'),
                                  ),
                                ],
                              ),
                            ),

                          // Show form fields only when data is loaded and no error
                          if (!_isLoadingData && _errorMessage == null)
                            _buildFormFields(),
                        ],
                      ),
                    ),
                  ),
                ),

                // Bottom button container
                AssetAuditTelecomBottomButtons(
                  isLoading: _isLoadingData,
                  errorMessage: _errorMessage,
                  onNextButtonClick:  () async {
                  },
                  assetAuditData: _assetAuditData,
                  auditSchId: widget.auditSchId,
                  siteType: widget.siteType,
                  siteAuditSchId: widget.siteAuditSchId,
                  screenName: _screenName,
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
        // Telecom specific fields
        CustomFormField(
          label: "Circle",
          initialValue: _displayFormData?['circle'] ?? "N/A",
          isRequired: false,
          isEditable: false,
        ),
        getHeight(15),
        CustomFormField(
          label: "Cluster",
          initialValue: _displayFormData?['cluster'] ?? "N/A",
          isRequired: false,
          isEditable: false,
        ),
        getHeight(15),
        CustomFormField(
          label: "District",
          initialValue: _displayFormData?['district'] ?? "N/A",
          isRequired: false,
          isEditable: false,
        ),
        getHeight(15),
        CustomFormField(
          label: "Customer",
          initialValue: _displayFormData?['clientName'] ?? "N/A",
          isRequired: false,
          isEditable: false,
        ),
        getHeight(15),
        CustomFormField(
          label: "Site Id",
          initialValue: _displayFormData?['siteId'] ?? "N/A",
          isRequired: false,
          isEditable: false,
        ),
        getHeight(15),
        CustomFormField(
          label: "Site Name",
          initialValue: _displayFormData?['siteName'] ?? "N/A",
          isRequired: false,
          isEditable: false,
        ),
        getHeight(15),
        // Image upload section
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Builder(
              builder: (context) {
                Logger.imageLog('🏗️ Building ImageUploadField widget for Telecom');
                Logger.imageLog('fetchedImageData length: ${_fetchedImageData?.length ?? 0}');
                Logger.imageLog('fetchedImageData preview: ${_fetchedImageData?.substring(0, _fetchedImageData!.length > 50 ? 50 : _fetchedImageData!.length) ?? 'null'}');
                Logger.imageLog('uploadedPhotoPath: ${_selectedImage?.path}');
                Logger.imageLog('uploadedImgId: $_uploadedImgId');
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
            // Show validation error for image upload
            if (_showValidationErrors &&
                _selectedImage == null &&
                _uploadedImgId == null &&
                _fetchedImageData == null)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.errorColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: AppColors.errorColor,
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: AppColors.errorColor,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Please upload a selfie to continue',
                        style: TextStyle(
                          color: AppColors.errorColor,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }

  bool _validateForm() {
    setState(() {
      _showValidationErrors = true;
    });

    final hasLocalPhoto = _selectedImage != null;
    final hasServerImage = _uploadedImgId != null && _uploadedImgId!.isNotEmpty && _uploadedImgId != "0";
    final hasImageData = _fetchedImageData != null && _fetchedImageData!.isNotEmpty;

    if (!hasLocalPhoto && !hasServerImage && !hasImageData) {
      Logger.debugLog('Photo validation failed - No photo uploaded');
      showCustomToast(context, 'Please upload a selfie before proceeding');
      return false;
    } else {
      Logger.debugLog('Photo validation passed');
    }

    Logger.debugLog('All validations passed!');
    return true;
  }

  void _showUnsavedChangesDialog() {
    if (_hasFormDataChanges) {
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
      AssetAuditNavigationHelper.navigateToHomeScreen(context);
    }
  }
}
