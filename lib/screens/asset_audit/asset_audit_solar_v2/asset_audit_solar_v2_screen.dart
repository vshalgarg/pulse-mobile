import 'dart:io';
import 'package:app/enum/activity_type_enum.dart';
import 'package:app/services/service_locator.dart';
import 'package:app/utils/asset_audit_navigation_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import '../../../commonWidgets/asset_audit_solar_bottom_buttons.dart';
import '../../../commonWidgets/custom_form_appbar.dart';
import '../../../commonWidgets/custom_form_field.dart';
import '../../../commonWidgets/custom_image_upload_field.dart';
import '../../../commonWidgets/custom_dialogs/unsaved_changes_dialog.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_images.dart';
import '../../../constants/constants_methods.dart';
import '../../../utils/logger.dart';
import '../../../services/asset_audit/central_asset_audit_service.dart';

class AssetAuditSolarV2Screen extends StatefulWidget {
  final String siteType;
  final String auditSchId;
  final String siteAuditSchId;

  const AssetAuditSolarV2Screen({
    super.key,
    required this.siteType,
    required this.auditSchId,
    required this.siteAuditSchId,
  });

  @override
  State<AssetAuditSolarV2Screen> createState() =>
      _AssetAuditSolarV2ScreenState();
}

class _AssetAuditSolarV2ScreenState extends State<AssetAuditSolarV2Screen> {
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
    Logger.debugLog('🔧 Initializing Central Asset Audit service');
    _service = ServiceLocator().centralAssetAuditService;

    Logger.debugLog('✅ Central Asset Audit service initialized successfully');
  }

  Future<void> _loadData() async {
    try {
      setState(() {
        _isLoadingData = true;
        _errorMessage = null;
      });

      Logger.debugLog(
        '🔄 Loading asset audit data for site ${widget.siteAuditSchId}',
      );

      // Use the actual service to load data
      final data = await _service.getActualDataFromSqlite(
        siteAuditSchId: widget.siteAuditSchId,
      );

      if (data != null) {
        // Extract page header data for form fields
        final pageHeaders = data['pageHeader'] as List<dynamic>?;
        final pageHeader = pageHeaders?.isNotEmpty == true
            ? pageHeaders!.first as Map<String, dynamic>
            : null;
        final formData = <String, String>{};

        if (pageHeader != null) {
          formData['state'] = pageHeader['solar_state']?.toString() ?? "N/A";
          formData['district'] =
              pageHeader['solar_district']?.toString() ?? "N/A";
          formData['clientName'] =
              pageHeader['client_name']?.toString() ?? "N/A";
          formData['siteCode'] = pageHeader['site_code']?.toString() ?? "N/A";
          formData['siteName'] = pageHeader['site_name']?.toString() ?? "N/A";
          formData['siteType'] =
              pageHeader['site_type_name']?.toString() ?? "N/A";
          formData['status'] = pageHeader['status']?.toString() ?? "N/A";

          // Format audit due date
          String formattedAuditDueDate = "N/A";
          final auditDueDt = pageHeader['audit_due_dt']?.toString();
          if (auditDueDt != null && auditDueDt.isNotEmpty) {
            try {
              final dateTime = DateTime.parse(auditDueDt);
              formattedAuditDueDate =
                  "${dateTime.day.toString().padLeft(2, '0')}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.year}";
            } catch (e) {
              formattedAuditDueDate = auditDueDt;
            }
          }
          formData['auditDueDate'] = formattedAuditDueDate;
        } else {
          Logger.errorLog('❌ No page header data found!');
        }

        setState(() {
          _isLoadingData = false;
          _assetAuditData =
              data; // Store the full asset audit data for SPV navigation
          _displayFormData =
              formData; // Store the extracted form data for display
        });
        Logger.debugLog('✅ Asset audit data loaded successfully');
        Logger.debugLog('📊 Form data: $formData');

        // Load image if we have an image ID from the page header
        if (pageHeader != null && pageHeader['maker_selfie_image_id'] != null) {
          Logger.debugLog(
            '🖼️ Found makerSelfieImageId: ${pageHeader['maker_selfie_image_id']}',
          );
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
        Logger.errorLog(
          '❌ No data available for site ${widget.siteAuditSchId}',
        );
      }
    } catch (e) {
      Logger.errorLog('❌ Error loading data: $e');
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
        isSelfie: true,
        activityType: ActivityTypeEnum.assetAudit,
      );

      // Update the database with the new image ID
      final dbData = await _service.getActualDataFromSqlite(
        siteAuditSchId: widget.siteAuditSchId,
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
            siteAuditSchId: widget.siteAuditSchId,
            updatedData: dbData,
          );
          
          Logger.debugLog('✅ Updated maker_selfie_image_id in database: $imgId');
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

  Future<void> postCurrentScreenData() async {
    try {
      if (_assetAuditData != null) {
        await _service.updateDataInSqlite(
          siteAuditSchId: widget.siteAuditSchId,
          updatedData: _assetAuditData ?? {},
        );
      }
    } catch (e) {}
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
                AssetAuditSolarBottomButtons(
                  isLoading: _isLoadingData,
                  errorMessage: _errorMessage,
                  onNextButtonClick: () async {
                    if (_hasFormDataChanges) {
                      await postCurrentScreenData();
                    }
                  },
                  assetAuditData: _assetAuditData,
                  auditSchId: widget.auditSchId,
                  siteType: widget.siteType,
                  siteAuditSchId: widget.siteAuditSchId,
                  screenName: 'GENERAL',
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
        // Site information fields (read-only)
        CustomFormField(
          label: "State (Solar)",
          initialValue: _displayFormData?['state'] ?? "N/A",
          isRequired: false,
          isEditable: false,
        ),
        getHeight(15),
        CustomFormField(
          label: "District (Solar)",
          initialValue: _displayFormData?['district'] ?? "N/A",
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
          label: "Site Code",
          initialValue: _displayFormData?['siteCode'] ?? "N/A",
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
        CustomFormField(
          label: "Site Type",
          initialValue: _displayFormData?['siteType'] ?? "N/A",
          isRequired: false,
          isEditable: false,
        ),
        getHeight(15),
        CustomFormField(
          label: "Audit Due Date",
          initialValue: _displayFormData?['auditDueDate'] ?? "N/A",
          isRequired: false,
          isEditable: false,
        ),
        getHeight(15),
        CustomFormField(
          label: "Status",
          initialValue: _displayFormData?['status'] ?? "N/A",
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
                return ImageUploadField(
                  label: "Add a Selfie",
                  placeholder: "Selfie",
                  isRequired: true,
                  externalImageUrl: _fetchedImageData,
                  onImageSelected: (file) {
                    if (file != null) {
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
                  border: Border.all(color: AppColors.errorColor, width: 1),
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
            postCurrentScreenData();
          },
          onDiscard: () {},
        ),
      );
    } else {
      AssetAuditNavigationHelper.navigateToHomeScreen(context);
    }
  }
}
