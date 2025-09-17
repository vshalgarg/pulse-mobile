import 'package:app/utils/asset_audit_navigation_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import '../../../commonWidgets/custom_form_appbar.dart';
import '../../../commonWidgets/custom_dialogs/unsaved_changes_dialog.dart';
import '../../../commonWidgets/asset_audit_form_component.dart';
import '../../../commonWidgets/custom_form_field.dart';
import '../../../commonWidgets/custom_remark.dart';
import '../../../commonWidgets/asset_audit_telecom_bottom_buttons.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_images.dart';
import '../../../constants/constants_methods.dart';
import '../../../utils/logger.dart';
import '../../../services/asset_audit/central_service_initializer.dart';
import '../../../services/asset_audit/central_asset_audit_service.dart';
import '../../../services/asset_audit_post_service.dart';
import '../../../services/image_upload_service.dart';
import '../../../app_config.dart';

class SMPSV2Screen extends StatefulWidget {
  final String siteAuditSchId;
  final String siteType;
  final String auditSchId;

  const SMPSV2Screen({
    super.key,
    required this.siteAuditSchId,
    required this.siteType,
    required this.auditSchId,
  });

  @override
  State<SMPSV2Screen> createState() => _SMPSV2ScreenState();
}

class _SMPSV2ScreenState extends State<SMPSV2Screen> {
  final String _screenName = 'SMPS';

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

  @override
  void initState() {
    super.initState();
    _service = CentralAssetAuditServiceInitializer.getService();
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

      Logger.debugLog('🔄 SMPS V2: Loading data for site ${widget.siteAuditSchId}');

      final data = await _service.getAssetAuditData(
        siteType: widget.siteType,
        auditSchId: widget.auditSchId,
        siteAuditSchId: widget.siteAuditSchId,
      );

      if (data != null) {
        final smpsItems = data['responseData'][AssetAuditNavigationHelper.dataValueForPage(_screenName, 'TELECOM')]
            as Map<String, dynamic>? ?? {};

        // Parse different asset types
        final smpsAssets = smpsItems['assets'] as List<dynamic>? ?? [];
        final smpsRectifiers = smpsItems['SMPS Rectifiers'] as List<dynamic>? ?? [];
        final smpsCabinet = smpsItems['SMPS Cabinet'] as List<dynamic>? ?? [];
        final acdbAssets = smpsItems['ACDB'] as List<dynamic>? ?? [];
        final lspuAssets = smpsItems['LSPU'] as List<dynamic>? ?? [];
        final remarksData = smpsItems['remarks'] as List<dynamic>? ?? [];

        final formData = <String, dynamic>{
          'smpsMake': smpsAssets.isNotEmpty ? smpsAssets.first['oem_name']?.toString() ?? 'N/A' : 'N/A',
          'smpsCount': smpsAssets.length.toString(),
          'smpsRectifiersCount': smpsRectifiers.length.toString(),
          'smpsAssets': smpsAssets.where((obj) => obj['photo_id'] != null).toList(),
          'smpsAllAssets': smpsAssets,
          'smpsRectifiers': smpsRectifiers.where((obj) => obj['photo_id'] != null).toList(),
          'smpsRectifiersAllAssets': smpsRectifiers,
          'smpsCabinet': smpsCabinet.where((obj) => obj['photo_id'] != null).toList(),
          'smpsCabinetAllAssets': smpsCabinet,
          'acdbAssets': acdbAssets.where((obj) => obj['photo_id'] != null).toList(),
          'acdbAllAssets': acdbAssets,
          'lspuAssets': lspuAssets.where((obj) => obj['photo_id'] != null).toList(),
          'lspuAllAssets': lspuAssets,
          'remarks': remarksData.isNotEmpty ? remarksData.first['item_type_remark']?.toString() ?? '' : '',
        };

        setState(() {
          _assetAuditData = data;
          _displayFormData = formData;
          _isLoadingData = false;
        });

        _initializeFormControllers(formData);
        Logger.debugLog('✅ SMPS V2: Data loaded successfully');
      } else {
        setState(() {
          _errorMessage = 'No data available for this site';
          _isLoadingData = false;
        });
      }
    } catch (e) {
      Logger.errorLog('❌ SMPS V2: Error loading data: $e');
      setState(() {
        _errorMessage = 'Error loading data: $e';
        _isLoadingData = false;
      });
    }
  }

  void _initializeFormControllers(Map<String, dynamic> formData) {
    _remarksController.text = formData['remarks'] ?? '';
    Logger.debugLog('📝 Initialized form controllers');
    if (mounted) {
      setState(() {});
    }
  }

  // Callback methods for AssetAuditFormComponent
  void _onSMPSRectifierItemSaved(List<Map<String, dynamic>> items) {
    setState(() {
      _displayFormData?['smpsRectifiers'] = items;
      _hasFormDataChanges = true;
    });
  }

  void _onSMPSCabinetItemSaved(List<Map<String, dynamic>> items) {
    setState(() {
      _displayFormData?['smpsCabinet'] = items;
      _hasFormDataChanges = true;
    });
  }

  void _onACDBItemSaved(List<Map<String, dynamic>> items) {
    setState(() {
      _displayFormData?['acdbAssets'] = items;
      _hasFormDataChanges = true;
    });
  }

  void _onLSPUItemSaved(List<Map<String, dynamic>> items) {
    setState(() {
      _displayFormData?['lspuAssets'] = items;
      _hasFormDataChanges = true;
    });
  }

  // Validation methods
  bool _validateSMPSSerialNumber(String serialNumber, bool isQRCodeScanned) {
    if (serialNumber.isEmpty) return false;
    // For now, always return true - validation can be enhanced later
    return true;
  }

  Future<void> postCurrentScreenData() async {
    try {
      Logger.debugLog('📤 SMPS V2: Starting postCurrentScreenData');
      
      final finalData = _assetAuditData?['responseData'][AssetAuditNavigationHelper.dataValueForPage(_screenName, 'TELECOM')];
      final finalRemarks = finalData?['remarks'] as List<dynamic>? ?? [];
      final finalSMPSRectifiers = finalData?['SMPS Rectifiers'] as List<dynamic>? ?? [];
      final finalSMPSCabinet = finalData?['SMPS Cabinet'] as List<dynamic>? ?? [];
      final finalACDBAssets = finalData?['ACDB'] as List<dynamic>? ?? [];
      final finalLSPUAssets = finalData?['LSPU'] as List<dynamic>? ?? [];
      
      // Collect all modified assets
      final modifiedAssetsWithAllProperties = <dynamic>[];

      // Add SMPS Rectifiers
      final modifiedSMPSRectifiers = _displayFormData?['smpsRectifiers'] as List<dynamic>? ?? [];
      modifiedAssetsWithAllProperties.addAll(_modifyData(finalSMPSRectifiers, modifiedSMPSRectifiers));

      // Add SMPS Cabinet
      final modifiedSMPSCabinet = _displayFormData?['smpsCabinet'] as List<dynamic>? ?? [];
      modifiedAssetsWithAllProperties.addAll(_modifyData(finalSMPSCabinet, modifiedSMPSCabinet));

      // Add ACDB assets
      final modifiedACDBAssets = _displayFormData?['acdbAssets'] as List<dynamic>? ?? [];
      modifiedAssetsWithAllProperties.addAll(_modifyData(finalACDBAssets, modifiedACDBAssets));

      // Add LSPU assets
      final modifiedLSPUAssets = _displayFormData?['lspuAssets'] as List<dynamic>? ?? [];
      modifiedAssetsWithAllProperties.addAll(_modifyData(finalLSPUAssets, modifiedLSPUAssets));

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

      Logger.debugLog('📤 SMPS V2: Prepared ${postObject.length} items for posting');
      
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
      
      Logger.debugLog('✅ SMPS V2: Data posted successfully');
      
    } catch (e) {
      Logger.errorLog('❌ SMPS V2: Error in postCurrentScreenData: $e');
      rethrow;
    }
  }

  static List<dynamic> _modifyData(List<dynamic> actualData, List<dynamic> modifiedData) {
    List<dynamic> modifiedDataToReturn = [];
    for(dynamic asset in actualData) {
      try {
        final assetSerialNo = asset['mfg_serial_no']?.toString();
        final modifiedAsset = modifiedData.where((ass) =>
        ass['qr_code_scanned'] ?
        ass['nexgen_serial_no']?.toString() == assetSerialNo :
        ass['mfg_serial_no']?.toString() == assetSerialNo
        ).toList();
        if(modifiedAsset.isNotEmpty) {
          modifiedDataToReturn.add(modifiedAsset.first);
        } else {
          modifiedDataToReturn.add(asset);
        }
      } catch (e) {
        Logger.errorLog('❌ Error in _modifyData: $e');
        modifiedDataToReturn.add(asset);
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
                    child: _isLoadingData
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: AppColors.primaryGreen,
                            ),
                          )
                        : _errorMessage != null
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      _errorMessage!,
                                      style: const TextStyle(
                                        color: AppColors.white,
                                        fontSize: 16,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 20),
                                    ElevatedButton(
                                      onPressed: _loadData,
                                      child: const Text('Retry'),
                                    ),
                                  ],
                                ),
                              )
                            : SingleChildScrollView(
                                padding: EdgeInsets.only(
                                  bottom: MediaQuery.of(context).viewInsets.bottom + 100,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.only(
                                    left: 16,
                                    right: 16,
                                    top: 16,
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                        // SMPS Make (readonly)
                        CustomFormField(
                          label: "SMPS Make",
                          hintText: _displayFormData?['smpsMake'] ?? "N/A",
                          isRequired: false,
                          isEditable: false,
                        ),
                        getHeight(15),

                        // Count of SMPS (readonly)
                        CustomFormField(
                          label: "Count of SMPS",
                          hintText: _displayFormData?['smpsCount'] ?? "0",
                          isRequired: false,
                          isEditable: false,
                        ),
                        getHeight(15),

                        // SMPS Cabinet Section
                        AssetAuditFormComponent(
                          componentId: 'smps_cabinet_component',
                          serialLabel: "Cabinet - Serial Number *",
                          serialHintText: "Cabinet Serial Number *",
                          photoLabel: "Add Photo of Cabinet Serial Number",
                          serialController: TextEditingController(),
                          initialSavedItems: _displayFormData?['smpsCabinet'] as List<dynamic>? ?? [],
                          onItemSaved: _onSMPSCabinetItemSaved,
                          onStatusChanged: (status) {
                            setState(() {
                              _hasFormDataChanges = true;
                            });
                          },
                          customValidator: _validateSMPSSerialNumber,
                          customValidationErrorMessage: "Invalid SMPS Cabinet serial number. Please check and try again.",
                          siteAuditSchId: widget.siteAuditSchId,
                          showTable: true,
                          tableTitle: "SMPS Cabinet",
                        ),
                        getHeight(20),


                        // Count of SMPS Rectifiers (readonly)
                        CustomFormField(
                          label: "Count of Rectifiers",
                          hintText: _displayFormData?['smpsRectifiersCount'] ?? "0",
                          isRequired: false,
                          isEditable: false,
                        ),
                        getHeight(20),

                        // SMPS Rectifiers Section
                        AssetAuditFormComponent(
                          componentId: 'smps_rectifiers_component',
                          serialLabel: "Rectifier - Serial Number *",
                          serialHintText: "Rectifier Serial Number *",
                          photoLabel: "Add a Photo",
                          serialController: TextEditingController(),
                          initialSavedItems: _displayFormData?['smpsRectifiers'] as List<dynamic>? ?? [],
                          onItemSaved: _onSMPSRectifierItemSaved,
                          onStatusChanged: (status) {
                            setState(() {
                              _hasFormDataChanges = true;
                            });
                          },
                          customValidator: _validateSMPSSerialNumber,
                          customValidationErrorMessage: "Invalid SMPS Rectifiers serial number. Please check and try again.",
                          siteAuditSchId: widget.siteAuditSchId,
                          showTable: true,
                          tableTitle: "SMPS Rectifiers",
                        ),
                        getHeight(20),

                        // ACDB Section
                        AssetAuditFormComponent(
                          componentId: 'acdb_component',
                          serialLabel: "ACDB *",
                          serialHintText: "ACDB *",
                          photoLabel: "Add Photo of ACDB",
                          serialController: TextEditingController(),
                          initialSavedItems: _displayFormData?['acdbAssets'] as List<dynamic>? ?? [],
                          onItemSaved: _onACDBItemSaved,
                          onStatusChanged: (status) {
                            setState(() {
                              _hasFormDataChanges = true;
                            });
                          },
                          customValidator: _validateSMPSSerialNumber,
                          customValidationErrorMessage: "Invalid ACDB serial number. Please check and try again.",
                          siteAuditSchId: widget.siteAuditSchId,
                          showTable: true,
                          tableTitle: "ACDB Items",
                        ),
                        getHeight(20),

                        // LSPU Section
                        AssetAuditFormComponent(
                          componentId: 'lspu_component',
                          serialLabel: "LSPU *",
                          serialHintText: "LSPU *",
                          photoLabel: "Add Photo of LSPU",
                          serialController: TextEditingController(),
                          initialSavedItems: _displayFormData?['lspuAssets'] as List<dynamic>? ?? [],
                          onItemSaved: _onLSPUItemSaved,
                          onStatusChanged: (status) {
                            setState(() {
                              _hasFormDataChanges = true;
                            });
                          },
                          customValidator: _validateSMPSSerialNumber,
                          customValidationErrorMessage: "Invalid LSPU serial number. Please check and try again.",
                          siteAuditSchId: widget.siteAuditSchId,
                          showTable: true,
                          tableTitle: "LSPU Items",
                        ),
                        getHeight(20),

                        // Add Remarks
                        CustomRemarksField(
                          label: "Add Remarks",
                          hintText: "Remarks",
                          controller: _remarksController,
                        ),
                                        getHeight(20),
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
}
