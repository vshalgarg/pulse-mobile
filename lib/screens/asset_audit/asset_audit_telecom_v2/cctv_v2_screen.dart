import 'package:app/app_config.dart';
import 'package:app/commonWidgets/asset_audit_form_component.dart';
import 'package:app/commonWidgets/asset_audit_telecom_bottom_buttons.dart';
import 'package:app/commonWidgets/custom_dialogs/unsaved_changes_dialog.dart';
import 'package:app/commonWidgets/custom_form_appbar.dart';
import 'package:app/commonWidgets/custom_form_field.dart';
import 'package:app/commonWidgets/custom_remark.dart';
import 'package:app/constants/app_colors.dart';
import 'package:app/constants/app_images.dart';
import 'package:app/constants/constants_methods.dart';
import 'package:app/services/asset_audit/central_asset_audit_service.dart';
import 'package:app/services/asset_audit/central_service_initializer.dart';
import 'package:app/services/asset_audit_post_service.dart';
import 'package:app/services/image_upload_service.dart';
import 'package:app/utils/asset_audit_navigation_helper.dart';
import 'package:app/utils/logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

class CCTVV2Screen extends StatefulWidget {
  final String siteAuditSchId;
  final String siteType;
  final String auditSchId;

  const CCTVV2Screen({
    super.key,
    required this.siteAuditSchId,
    required this.siteType,
    required this.auditSchId,
  });

  @override
  State<CCTVV2Screen> createState() => _CCTVV2ScreenState();
}

class _CCTVV2ScreenState extends State<CCTVV2Screen> {
  final String _screenName = 'CCTV';
  
  // Service
  late CentralAssetAuditService _service;
  
  // Data
  Map<String, dynamic>? _assetAuditData;
  Map<String, dynamic>? _displayFormData;
  
  // Controllers
  final TextEditingController _cctvSerialController = TextEditingController();
  final TextEditingController _remarksController = TextEditingController();
  
  // State
  bool _isLoadingData = false;
  String? _errorMessage;
  bool _hasFormDataChanges = false;
  
  // Section visibility states
  bool _showCCTVDetails = false;

  @override
  void initState() {
    super.initState();
    _service = CentralAssetAuditServiceInitializer.getService();
    _loadData();
    
    // Add listeners for form changes
    _cctvSerialController.addListener(_onFormChanged);
    _remarksController.addListener(_onFormChanged);
  }

  @override
  void dispose() {
    _cctvSerialController.dispose();
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

      Logger.debugLog('🔄 Surveillance V2: Loading data for site ${widget.siteAuditSchId}');
      
      final data = await _service.getAssetAuditData(
        siteType: widget.siteType,
        auditSchId: widget.auditSchId,
        siteAuditSchId: widget.siteAuditSchId,
      );

      if (data != null) {
        final cctvItems = data['responseData'][AssetAuditNavigationHelper.dataValueForPage(_screenName, 'TELECOM')]
        as Map<String, dynamic>? ?? {};

        // Parse CCTV data
        final cctvAssets = cctvItems['assets'] as List<dynamic>? ?? [];
        final remarksData = cctvItems['remarks'] as List<dynamic>? ?? [];

        final formData = <String, dynamic>{
          'cctvAvailable': cctvAssets.isNotEmpty ? "Yes" : "No",
          'cctvCount': cctvAssets.length.toString(),
          'cctvAssets': cctvAssets.where((obj) => obj['photo_id'] != null).toList(),
          'cctvAllAssets': cctvAssets,
          'remarks': remarksData.isNotEmpty ? remarksData.first['item_type_remark']?.toString() ?? "" : "",
        };

        setState(() {
          _isLoadingData = false;
          _assetAuditData = data;
          _displayFormData = formData;
          _showCCTVDetails = cctvAssets.isNotEmpty;
        });

        WidgetsBinding.instance.addPostFrameCallback((_) {
          _initializeFormControllers(formData);
        });
      } else {
        setState(() {
          _isLoadingData = false;
          _errorMessage = 'Failed to load Surveillance data';
        });
      }
    } catch (e) {
      Logger.errorLog('❌ Surveillance V2: Error loading data: $e');
      setState(() {
        _isLoadingData = false;
        _errorMessage = 'Error loading data: $e';
      });
    }
  }

  void _initializeFormControllers(Map<String, dynamic> formData) {
    final remarks = formData['remarks'] ?? "";
    _remarksController.text = remarks;
    Logger.debugLog('📝 Initialized remarks controller with: $remarks');
    if (mounted) {
      setState(() {});
    }
  }

  // Callback method for AssetAuditFormComponent
  void _onCCTVItemSaved(List<Map<String, dynamic>> items) {
    _displayFormData?['cctvAssets'] = [...items];
    setState(() {
      _hasFormDataChanges = true;
    });
  }

  // Validation method
  bool _validateCCTVSerialNumber(String serialNumber, bool isQRCodeScanned) {
    final savedItems = _displayFormData?['cctvAllAssets'] as List<dynamic>? ?? [];
    if (savedItems.isEmpty) return false;

    final isValid = savedItems.any((item) {
      if (isQRCodeScanned) {
        return item['nexgen_serial_no']?.toString().toLowerCase() ==
            serialNumber.toLowerCase();
      } else {
        return item['mfg_serial_no']?.toString().toLowerCase() ==
            serialNumber.toLowerCase();
      }
    });

    return isValid;
  }

  Future<void> postCurrentScreenData() async {
    try {
      Logger.debugLog('📤 Surveillance V2: Starting postCurrentScreenData');
      
      final finalData = _assetAuditData?['responseData'][AssetAuditNavigationHelper.dataValueForPage(_screenName, 'TELECOM')];
      final finalRemarks = finalData?['remarks'] as List<dynamic>? ?? [];
      final finalCCTVAssets = finalData['assets'] as List<dynamic>? ?? [];
      
      // Collect modified assets
      final modifiedAssetsWithAllProperties = <dynamic>[];
      
      // Add CCTV assets
      final modifiedCCTVAssets = _displayFormData?['cctvAssets'] as List<dynamic>? ?? [];
      modifiedAssetsWithAllProperties.addAll(_modifyData(finalCCTVAssets, modifiedCCTVAssets));

      // Update remarks
      final String remark = _remarksController.text;
      if(remark.isNotEmpty && finalRemarks.isNotEmpty){
        try {
          finalRemarks.first['item_type_remark'] = remark;
          Logger.debugLog('✅ Updated remarks: $remark');
        } catch (e) {
          Logger.errorLog('❌ Error updating remarks: $e');
        }
      }
      
      // Update local data
      _service.updateDataInSqlite(siteAuditSchId: widget.siteAuditSchId, updatedData: _assetAuditData ?? {});

      // Prepare data for posting
      final postObject = [
        ...modifiedAssetsWithAllProperties,
        ...finalRemarks
      ];

      Logger.debugLog('📤 Surveillance V2: Prepared ${postObject.length} items for posting');
      
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
      );
      
      Logger.debugLog('✅ Surveillance V2: Data posted successfully');
      
    } catch (e) {
      Logger.errorLog('❌ Surveillance V2: Error in postCurrentScreenData: $e');
      rethrow;
    }
  }

  static List<dynamic> _modifyData(List<dynamic> actualData, List<dynamic> modifiedData) {
    List<dynamic> modifiedDataToReturn = [];
    for(dynamic asset in actualData) {
      try {
        final assetSerialNo = asset['mfg_serial_no']?.toString();
        final modifiedAsset = modifiedData.where((ass) =>
        ass['mfg_serial_no']?.toString() == assetSerialNo
        ).firstOrNull;

        if (modifiedAsset != null) {
          asset['qr_code_scanned'] = modifiedAsset['qr_code_scanned'];
          asset['qr_code_scanned_ts'] = modifiedAsset['qr_code_scanned_ts'];
          asset['photo_id'] = modifiedAsset['photo_id'];
          asset['longitude'] = 'Tobechanged';
          asset['latitude'] = 'Tobechanged';
          asset['asset_status'] = modifiedAsset['asset_status'];
          modifiedDataToReturn.add(asset);
          Logger.debugLog('✅ Updated asset: $assetSerialNo');
        } else {
          Logger.debugLog('⚠️ No modified asset found for serial: $assetSerialNo');
        }
      } catch (e) {
        Logger.errorLog('❌ Error updating asset: $e');
      }
    }
    return modifiedDataToReturn;
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
    required Function(String?) onChanged,
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
                                      'Loading Surveillance data...',
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
                                  'No Surveillance data available',
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
                    if(_hasFormDataChanges) {
                      await postCurrentScreenData();
                    }
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
        // CCTV Available
        _buildRadioButtonField(
          label: "CCTV Available",
          isRequired: true,
          groupValue: _displayFormData?['cctvAvailable'] ?? "No",
          onChanged: (value) {
            setState(() {
              _displayFormData?['cctvAvailable'] = value;
              _hasFormDataChanges = true;
            });
          },
        ),
        getHeight(15),

        // CCTV Details Section (only show if available)
        if (_showCCTVDetails) ...[
          // Count of CCTV
          CustomFormField(
            label: "Count of CCTV",
            initialValue: _displayFormData?['cctvCount']?.toString() ?? "0",
            isRequired: false,
            isEditable: false,
          ),
          getHeight(15),

          const Text(
            "CCTV Details",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.white,
            ),
          ),
          getHeight(15),
          
          // CCTV Form Component
          AssetAuditFormComponent(
            componentId: 'cctv_component',
            serialLabel: "CCTV - Serial Number *",
            serialHintText: "CCTV Serial Number *",
            photoLabel: "Add a Photo",
            serialController: _cctvSerialController,
            initialSavedItems: _displayFormData?['cctvAssets'] as List<dynamic>? ?? [],
            onItemSaved: _onCCTVItemSaved,
            onStatusChanged: (status) {
              setState(() {
                _hasFormDataChanges = true;
              });
            },
            customValidator: _validateCCTVSerialNumber,
            customValidationErrorMessage: "Invalid CCTV serial number. Please check and try again.",
            siteAuditSchId: widget.siteAuditSchId,
            showTable: true,
            tableTitle: "CCTV Items",
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
