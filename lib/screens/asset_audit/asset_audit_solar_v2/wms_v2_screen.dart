import 'dart:io';
import 'dart:convert';
import 'package:app/commonWidgets/custom_remark.dart';
import 'package:app/screens/home_screen.dart';
import 'package:app/utils/asset_audit_navigation_helper.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_svg/svg.dart';
import '../../../commonWidgets/custom_form_appbar.dart';
import '../../../commonWidgets/custom_form_field.dart';
import '../../../commonWidgets/custom_image_upload_field.dart';
import '../../../commonWidgets/custom_buttons/arrow_botton.dart';
import '../../../commonWidgets/custom_dialogs/unsaved_changes_dialog.dart';
import '../../../commonWidgets/asset_audit_form_component.dart';
import '../../../commonWidgets/asset_audit_solar_bottom_buttons.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_images.dart';
import '../../../constants/constants_methods.dart';
import '../../../utils/logger.dart';
import '../../../models/asset_audit_model.dart';
import '../../../services/asset_audit/central_service_initializer.dart';
import '../../../services/asset_audit/central_asset_audit_service.dart';
import '../../../services/asset_audit_post_service.dart';
import '../../../services/image_upload_service.dart';
import '../../../enum/image_activity_type_enum.dart';
import '../../../app_config.dart';

class WMSV2Screen extends StatefulWidget {
  final String siteAuditSchId;
  final String siteType;
  final String auditSchId;

  const WMSV2Screen({
    super.key,
    required this.siteAuditSchId,
    required this.siteType,
    required this.auditSchId,
  });

  @override
  State<WMSV2Screen> createState() => _WMSV2ScreenState();
}

class _WMSV2ScreenState extends State<WMSV2Screen> {
  final String _screenName = 'WMS';
  
  // Service
  late CentralAssetAuditService _service;
  
  // Data
  Map<String, dynamic>? _assetAuditData;
  Map<String, dynamic>? _displayFormData;
  
  // Controllers
  final TextEditingController _wmsSerialController = TextEditingController();
  final TextEditingController _remarksController = TextEditingController();
  
  // State
  bool _isLoadingData = false;
  String? _errorMessage;
  bool _hasFormDataChanges = false;

  @override
  void initState() {
    super.initState();
    _service = CentralAssetAuditServiceInitializer.getService();
    _loadData();
    
    // Add listeners for form changes
    _wmsSerialController.addListener(_onFormChanged);
    _remarksController.addListener(_onFormChanged);
  }

  @override
  void dispose() {
    _wmsSerialController.dispose();
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

      Logger.debugLog('🔄 WMS V2: Loading data for site ${widget.siteAuditSchId}');
      
      final data = await _service.getAssetAuditData(
        siteType: widget.siteType,
        auditSchId: widget.auditSchId,
        siteAuditSchId: widget.siteAuditSchId,
      );

      if (data != null) {
        final wmsItems = data['responseData'][AssetAuditNavigationHelper.dataValueForPage(_screenName, 'SOLAR')]
        as Map<String, dynamic>? ?? {};

        if (wmsItems.isNotEmpty) {
          final firstItem = wmsItems['assets'].first;
          final formData = <String, dynamic>{
            'wmsMake': firstItem['oem_name']?.toString() ?? "N/A",
            'totalItems': wmsItems['assets'].length.toString(),
            'remarks': wmsItems['remarks'].first['item_type_remark']?.toString() ?? "",
            'assets': wmsItems['assets'].where((obj) => obj['photo_id'] != null).toList(),
            'allAssets': wmsItems['assets'],
          };

          setState(() {
            _isLoadingData = false;
            _assetAuditData = data;
            _displayFormData = formData;
          });

          WidgetsBinding.instance.addPostFrameCallback((_) {
            _initializeFormControllers(formData);
          });
        } else {
          setState(() {
            _isLoadingData = false;
            _errorMessage = 'No WMS data found';
          });
        }
      } else {
        setState(() {
          _isLoadingData = false;
          _errorMessage = 'Failed to load WMS data';
        });
      }
    } catch (e) {
      Logger.errorLog('❌ WMS V2: Error loading data: $e');
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

  // Callback when WMS item is saved
  void _onWMSItemSaved(List<Map<String, dynamic>> items) {
    _displayFormData?['assets'] = [...items];
    setState(() {
      _hasFormDataChanges = true;
    });
  }

  // Validate WMS serial number
  bool _validateWMSSerialNumber(String serialNumber, bool isQRCodeScanned) {
    final savedWMSItems = _displayFormData?['allAssets'] as List<dynamic>? ?? [];
    if (savedWMSItems.isEmpty) return false;

    final isValid = savedWMSItems.any((item) {
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
      Logger.debugLog('📤 WMS V2: Starting postCurrentScreenData');
      
      final modifiedAssets = _displayFormData?['assets'] as List<dynamic>? ?? [];
      final modifiedAssetsWithAllProperties = [];
      final finalData = _assetAuditData?['responseData'][AssetAuditNavigationHelper.dataValueForPage(_screenName, 'SOLAR')];
      final finalAssets = finalData?['assets'] as List<dynamic>? ?? [];
      final finalRemarks = finalData?['remarks'] as List<dynamic>? ?? [];
      
      Logger.debugLog('📊 Data counts - Modified: ${modifiedAssets.length}, Final: ${finalAssets.length}, Remarks: ${finalRemarks.length}');
      
      // Update assets with modified data
      for(dynamic asset in finalAssets) {
        try {
          final assetSerialNo = asset['mfg_serial_no']?.toString();
          final modifiedAsset = modifiedAssets.where((ass) => 
            ass['mfg_serial_no']?.toString() == assetSerialNo
          ).firstOrNull;
          
          if (modifiedAsset != null) {
            asset['qr_code_scanned'] = modifiedAsset['qr_code_scanned'];
            asset['qr_code_scanned_ts'] = modifiedAsset['qr_code_scanned_ts'];
            asset['photo_id'] = modifiedAsset['photo_id'];
            asset['longitude'] = 'Tobechanged';
            asset['latitude'] = 'Tobechanged';
            asset['asset_status'] = modifiedAsset['asset_status'];
            modifiedAssetsWithAllProperties.add(asset);
            Logger.debugLog('✅ Updated asset: $assetSerialNo');
          } else {
            Logger.debugLog('⚠️ No modified asset found for serial: $assetSerialNo');
          }
        } catch (e) {
          Logger.errorLog('❌ Error updating asset: $e');
        }
      }
      
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

      Logger.debugLog('📤 WMS V2: Prepared ${postObject.length} items for posting');
      
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
      
      Logger.debugLog('✅ WMS V2: Data posted successfully');
      
    } catch (e) {
      Logger.errorLog('❌ WMS V2: Error in postCurrentScreenData: $e');
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
            await postCurrentScreenData();
          },
          onDiscard: () {
          },
        ),
      );
    } else {
      AssetAuditNavigationHelper.navigateToHomeScreen(context);
    }
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
                                      'Loading WMS data...',
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
                                  'No WMS data available',
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
                AssetAuditSolarBottomButtons(
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
        // WMS Make
        CustomFormField(
          label: "WMS Make",
          initialValue: _displayFormData?['wmsMake']?.toString() ?? "N/A",
          isRequired: false,
          isEditable: false,
        ),
        getHeight(15),

        // WMS Details Section
        const Text(
          "WMS Details",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.white,
          ),
        ),
        getHeight(15),
        
        // WMS Form Component
        AssetAuditFormComponent(
          componentId: 'wms_component',
          serialLabel: "WMS - Serial Number *",
          serialHintText: "WMS Serial Number *",
          photoLabel: "Add a Photo",
          serialController: _wmsSerialController,
          initialSavedItems: _displayFormData?['assets'] as List<dynamic>? ?? [],
          onItemSaved: _onWMSItemSaved,
          onStatusChanged: (status) {
            setState(() {
              _hasFormDataChanges = true;
            });
          },
          customValidator: _validateWMSSerialNumber,
          customValidationErrorMessage: "Invalid WMS serial number. Please check and try again.",
          siteAuditSchId: widget.siteAuditSchId,
          showTable: true,
          tableTitle: "WMS Items",
        ),
        getHeight(15),

        // Remarks
        CustomRemarksField(
          label: "Add Remarks",
          hintText: "Remarks",
          controller: _remarksController,
          initialValue: _displayFormData?['remarks'] ?? '',
        ),
      ],
    );
  }
}
