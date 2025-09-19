import 'package:app/utils/asset_audit_navigation_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import '../../../commonWidgets/asset_audit_telecom_bottom_buttons.dart';
import '../../../commonWidgets/custom_form_appbar.dart';
import '../../../commonWidgets/custom_dialogs/unsaved_changes_dialog.dart';
import '../../../commonWidgets/custom_remark.dart';
import '../../../commonWidgets/custom_asset_audit_form_section.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_images.dart';
import '../../../constants/constants_methods.dart';
import '../../../services/service_locator.dart';
import '../../../utils/logger.dart';
import '../../../services/asset_audit/central_service_initializer.dart';
import '../../../services/asset_audit/central_asset_audit_service.dart';
import '../../../services/asset_audit_post_service.dart';
import '../../../services/image_upload_service.dart';
import '../../../app_config.dart';

class BoundaryTelecomV2Screen extends StatefulWidget {
  final String siteAuditSchId;
  final String siteType;
  final String auditSchId;

  const BoundaryTelecomV2Screen({
    super.key,
    required this.siteAuditSchId,
    required this.siteType,
    required this.auditSchId,
  });

  @override
  State<BoundaryTelecomV2Screen> createState() => _BoundaryTelecomV2ScreenState();
}

class _BoundaryTelecomV2ScreenState extends State<BoundaryTelecomV2Screen> {
  final String _screenName = 'Boundary';
  
  // Service
  late CentralAssetAuditService _service;
  
  // Data
  Map<String, dynamic>? _assetAuditData;
  Map<String, dynamic>? _displayFormData;
  
  // Controllers
  final TextEditingController _remarksController = TextEditingController();
  
  // State
  bool _isLoadingData = false;
  String? _errorMessage;
  bool _hasFormDataChanges = false;
  
  
  // Photo IDs
  String? _fencingPhotoId;
  String? _overallSitePhotoId;
  
  // Radio button values
  String _fencingAvailable = "No";
  String _overallSiteAvailable = "No";
  String _fencingStatus = "Ok";

  @override
  void initState() {
    super.initState();
    _service = ServiceLocator().centralAssetAuditService;
    _loadData();
    
    // Add listeners for form changes
    _remarksController.addListener(_onFormChanged);
  }

  @override
  void dispose() {
    _remarksController.dispose();
    super.dispose();
  }

  void _onFormChanged() {
    if (!_hasFormDataChanges) {
      setState(() {
        _hasFormDataChanges = true;
      });
    }
  }

  Future<void> _loadData() async {
    try {
      setState(() {
        _isLoadingData = true;
        _errorMessage = null;
      });

      Logger.debugLog('🔄 Boundary V2: Loading data for site ${widget.siteAuditSchId}');
      
      final data = await _service.getActualDataFromSqlite(
        siteAuditSchId: widget.siteAuditSchId,
      );

      if (data != null) {
        final boundaryItems = data['responseData'][AssetAuditNavigationHelper.dataValueForPage(_screenName, 'TELECOM')]
        as Map<String, dynamic>? ?? {};

        // Parse Boundary data - it's an array
        final remarksData = boundaryItems['remarks'] as List<dynamic>;
        final assetsData = boundaryItems['assets'] as List<dynamic>;

        final boundaryData = assetsData.isNotEmpty ?assetsData.where((data) => data['record_type'] == 'Boundary').first : null;
        final overallSiteData = assetsData.isNotEmpty ?assetsData.where((data) => data['record_type'] == 'Overall Site').first : null;

        final formData = <String, dynamic>{
          'boundaryText': boundaryData['item_type']?.toString() ?? "N/A",
          'remarks': remarksData.isNotEmpty ? remarksData.first['item_type_remark']?.toString() ?? "" : "",
        };

        setState(() {
          _isLoadingData = false;
          _assetAuditData = data;
          _displayFormData = formData;
          _fencingAvailable = boundaryData != null ? 'Yes' : 'No';
          _overallSiteAvailable = overallSiteData != null ? 'Yes' : 'No';
          _fencingPhotoId = boundaryData['photo_id']?.toString() ?? null;
          _overallSitePhotoId = overallSiteData != null ? overallSiteData['photo_id']?.toString() : null;
        });

        WidgetsBinding.instance.addPostFrameCallback((_) {
          _initializeFormControllers(formData);
        });
      } else {
        setState(() {
          _isLoadingData = false;
          _errorMessage = 'Failed to load Boundary data';
        });
      }
    } catch (e) {
      Logger.errorLog('❌ Boundary V2: Error loading data: $e');
      setState(() {
        _isLoadingData = false;
        _errorMessage = 'Error loading data: $e';
      });
    }
  }

  void _initializeFormControllers(Map<String, dynamic> formData) {
    _remarksController.text = formData['remarks'] ?? "";
    Logger.debugLog('📝 Initialized form controllers');
    if (mounted) {
      setState(() {});
    }
  }

  void _onFencingStatusChanged(String? value) {
    if (value != null) {
      setState(() {
        _fencingStatus = value;
        _hasFormDataChanges = true;
      });
    }
  }

  void _onFencingImageSelected(String? imageId) {
    setState(() {
      _fencingPhotoId = imageId;
      _hasFormDataChanges = true;
    });
  }

  void _onOverallSiteImageSelected(String? imageId) {
    setState(() {
      _overallSitePhotoId = imageId;
      _hasFormDataChanges = true;
    });
  }

  Future<void> postCurrentScreenData() async {
    try {
      Logger.debugLog('📤 Boundary V2: Starting postCurrentScreenData');

      final finalBoundaryItems = _assetAuditData?['responseData'][AssetAuditNavigationHelper.dataValueForPage(_screenName, 'TELECOM')]
      as Map<String, dynamic>? ?? {};

      final modifiedData = [];

      final remarksData = finalBoundaryItems['remarks'] as List<dynamic>;
      final assetsData = finalBoundaryItems['assets'] as List<dynamic>;

      final boundaryData = assetsData.isNotEmpty ?assetsData.where((data) => data['record_type'] == 'Boundary').first : null;
      final overallSiteData = assetsData.isNotEmpty ?assetsData.where((data) => data['record_type'] == 'Overall Site').first : null;

      if(_fencingAvailable == 'Yes' && _fencingPhotoId != null) {
        boundaryData['photo_id'] = _fencingPhotoId;
        modifiedData.add(boundaryData);
      }

      if(_overallSiteAvailable == 'Yes' && _overallSitePhotoId != null) {
        overallSiteData['photo_id'] = _overallSitePhotoId;
        modifiedData.add(overallSiteData);
      }
      if(_remarksController.text.isNotEmpty) {
        remarksData.first['item_type_remark'] = _remarksController.text.toString();
        modifiedData.add(remarksData);
      }




      // Collect all data to post
      final postObject = [...modifiedData];

      // Update local data
      _service.updateDataInSqlite(siteAuditSchId: widget.siteAuditSchId, updatedData: _assetAuditData ?? {});

      // Initialize AssetAuditPostService
      final apiService = AppConfig.of(context).apiService;
      final imageUploadService = ImageUploadService(apiService: apiService);
      final postService = AssetAuditPostService(
        apiService: apiService,
        imageUploadService: imageUploadService,
      );
      
      // Post data with photo ID replacement
      await postService.postAssetAuditDataWithPhotoReplacement(
        requests: postObject,
        isLastPage: AssetAuditNavigationHelper.getTelecomNextScreenName(_assetAuditData, _screenName) == 'SUBMIT',
      );
      
      Logger.debugLog('✅ Boundary V2: Data posted successfully');
      
    } catch (e) {
      Logger.errorLog('❌ Boundary V2: Error in postCurrentScreenData: $e');
      rethrow;
    }
  }

  void _showUnsavedChangesDialog() {
    if (_hasFormDataChanges) {
      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (dialogContext) => UnsavedChangesDialog(
          siteAuditSchId: widget.siteAuditSchId,
          section: "Asset Audit",
          parentContext: context,
          onSaveAndExit: () async {
            if(_hasFormDataChanges) {
              await postCurrentScreenData();
            }
          },
          onDiscard: () {
          },
        ),
      );
    } else {
      AssetAuditNavigationHelper.navigateToHomeScreen(context);
    }
  }

  Widget _buildRadioButtonField({
    required String label,
    required bool isRequired,
    required String groupValue,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                color: AppColors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (isRequired)
              const Text(
                " *",
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 16,
                ),
              ),
          ],
        ),
        getHeight(8),
        Row(
          children: [
            Radio<String>(
              value: "Yes",
              groupValue: groupValue,
              onChanged: null,
              activeColor: AppColors.primaryGreen,
            ),
            const Text(
              "Yes",
              style: TextStyle(
                color: AppColors.white,
                fontSize: 16,
              ),
            ),
            const SizedBox(width: 20),
            Radio<String>(
              value: "No",
              groupValue: groupValue,
              onChanged: null,
              activeColor: AppColors.primaryGreen,
            ),
            const Text(
              "No",
              style: TextStyle(
                color: AppColors.white,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ],
    );
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
                                      'Loading Boundary data...',
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
                                          _errorMessage!,
                                          style: const TextStyle(
                                            color: AppColors.errorColor,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    ],
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
                          
                          // Show form when data is loaded
                          if (!_isLoadingData && _errorMessage == null && _displayFormData != null)
                            _buildFormFields(),
                          
                          // Show message when no data
                          if (!_isLoadingData && _errorMessage == null && _displayFormData == null)
                            Container(
                              padding: const EdgeInsets.all(20),
                              child: const Center(
                                child: Text(
                                  'No Boundary data available',
                                  style: TextStyle(
                                    color: AppColors.white,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                
                // Bottom buttons using your specific format
                AssetAuditTelecomBottomButtons(
                  isLoading: _isLoadingData,
                  errorMessage: _errorMessage,
                  onNextButtonClick: () async {
                    await postCurrentScreenData();
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Fencing/Boundary Available
        _buildRadioButtonField(
          label: "Fencing/Boundary Available",
          isRequired: true,
          groupValue: _fencingAvailable,
        ),
        getHeight(15),
        
        // Fencing/Boundary Details Section (only show if available)
        if (_fencingAvailable == "Yes") ...[
          CustomAssetAuditFormSection(
            sectionTitle: "Fencing/Boundary",
            showTitle: false,
            inputLabel: "Fencing/Boundary",
            inputHintText: "Fencing",
            isInputEditable: false,
            inputInitialValue: _displayFormData?['boundaryText'] ?? "",
            onInputChanged: (value) {
              setState(() {
                _hasFormDataChanges = true;
              });
            },
            photoLabel: "Add a Photo",
            isPhotoRequired: true,
            uploadedImageId: _fencingPhotoId,
            onImageSelected: _onFencingImageSelected,
            statusLabel: "Status",
            isStatusRequired: true,
            statusInitialValue: _fencingStatus,
            onStatusChanged: _onFencingStatusChanged,
            siteAuditSchId: widget.siteAuditSchId,
            showStatus: true,
          ),
          getHeight(15),
        ],
        if(_overallSiteAvailable == "Yes") ...[
          // Overall Site Photos Section
          CustomAssetAuditFormSection(
            sectionTitle: "Overall Site Photos",
            showTitle: true,
            photoLabel: "Add a Photo",
            isPhotoRequired: false,
            photoHintText: "Add a Photo",
            uploadedImageId: _overallSitePhotoId,
            onImageSelected: _onOverallSiteImageSelected,
            siteAuditSchId: widget.siteAuditSchId,
            showStatus: false,
          ),
          getHeight(15),
        ],
        
        
        // Remarks using CustomRemarksField
        CustomRemarksField(
          label: "Add Remarks",
          hintText: "Remarks",
          controller: _remarksController,
        ),
      ],
    );
  }
}
