import 'package:app/enum/activity_type_enum.dart';
import 'package:app/routes/route_generator.dart';
import 'package:app/utils/asset_audit_navigation_helper.dart';
import 'package:app/utils/asset_audit_validation_helper.dart';
import 'package:app/utils/data_transformation_helper.dart';
import 'package:flutter/material.dart';
import '../../../commonWidgets/custom_form_appbar.dart';
import '../../../commonWidgets/custom_dialogs/unsaved_changes_dialog.dart';
import '../../../commonWidgets/asset_audit_form_component.dart';
import '../../../commonWidgets/custom_remark.dart';
import '../../../commonWidgets/asset_audit_telecom_bottom_buttons.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_images.dart';
import '../../../constants/constants_methods.dart';
import '../../../services/service_locator.dart';
import '../../../utils/logger.dart';
import '../../../services/asset_audit/central_asset_audit_service.dart';
import 'package:app/commonWidgets/safe_svg_picture.dart';

class ElectricalScreen extends StatefulWidget {
  final String siteAuditSchId;
  final String siteType;
  final String auditSchId;
  final BuildContext parentContext;

  const ElectricalScreen({
    super.key,
    required this.siteAuditSchId,
    required this.siteType,
    required this.auditSchId,
    required this.parentContext,
  });

  @override
  State<ElectricalScreen> createState() => _ElectricalScreenState();
}

class _ElectricalScreenState extends State<ElectricalScreen> {
  final String _screenName = 'Electrical';

  // Service
  late CentralAssetAuditService _service;

  // Data
  Map<String, dynamic>? _assetAuditData;
  Map<String, dynamic>? _displayFormData;

  // Controllers
  final TextEditingController _remarksController = TextEditingController();

  final TextEditingController _acdbSerialController =
      TextEditingController();
  final TextEditingController _lspuSerialController =
      TextEditingController();
  final TextEditingController _aviationLampSerialController =
      TextEditingController();

  List<Map<String, dynamic>> _savedACDBs = [];
  List<Map<String, dynamic>> _savedLSPUs = [];
  List<Map<String, dynamic>> _savedAviationLamps = [];

  // State
  bool _isLoadingData = false;
  String? _errorMessage;
  bool _hasFormDataChanges = false;

  String _normalizeSerial(dynamic value) =>
      value?.toString().trim().toUpperCase() ?? '';

  void _applySavedItemsToAssets(
    List<dynamic> finalAssets,
    List<Map<String, dynamic>> savedItems,
  ) {
    for (final asset in finalAssets) {
      final assetSerial = _normalizeSerial(asset['mfg_serial_no']);
      if (assetSerial.isEmpty) continue;

      Map<String, dynamic>? modifiedAsset;
      for (final saved in savedItems) {
        if (_normalizeSerial(saved['mfg_serial_no']) == assetSerial) {
          modifiedAsset = saved;
          break;
        }
      }
      if (modifiedAsset == null) continue;

      asset['qr_code_scanned'] = modifiedAsset['qr_code_scanned'];
      asset['qr_code_scanned_ts'] = modifiedAsset['qr_code_scanned_ts'];
      asset['photo_id'] = modifiedAsset['photo_id'];
      asset['asset_status'] = modifiedAsset['asset_status'];
    }
  }

  @override
  void initState() {
    super.initState();
    _service = ServiceLocator().centralAssetAuditService;
    _loadData();
  }

  @override
  void dispose() {
    _remarksController.dispose();
    _acdbSerialController.dispose();
    _lspuSerialController.dispose();
    _aviationLampSerialController.dispose();
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

      Logger.debugLog(
        '🔄 Electrical: Loading data for site ${widget.siteAuditSchId}',
      );

      final data = await _service.getActualDataFromSqlite(
        siteAuditSchId: widget.siteAuditSchId,
      );

      if (data != null) {
        final electricalItems =
            data['responseData'][AssetAuditNavigationHelper.dataValueForPage(
                  _screenName,
                  'TELECOM',
                )]
                as Map<String, dynamic>? ??
            {};

        // Parse different asset types
        final acdbAssets = electricalItems['ACDB'] as List<dynamic>? ?? [];
        final lspuAssets = electricalItems['LSPU'] as List<dynamic>? ?? [];
        final aviationLampAssets = electricalItems['Aviation Lamp'] as List<dynamic>? ?? [];
        final remarksData = electricalItems['remarks'] as List<dynamic>? ?? [];

        final formData = <String, dynamic>{
          'acdbAssets': acdbAssets
              .where((obj) => obj['photo_id'] != null)
              .toList(),
          'acdbAllAssets': acdbAssets,
          'lspuAssets': lspuAssets
              .where((obj) => obj['photo_id'] != null)
              .toList(),
          'lspuAllAssets': lspuAssets,
          'aviationLampAssets': aviationLampAssets
              .where((obj) => obj['photo_id'] != null)
              .toList(),
          'aviationLampAllAssets': aviationLampAssets,
          'aviationLampAvailable': aviationLampAssets.isNotEmpty,
          'remarks': remarksData.isNotEmpty
              ? remarksData.first['item_type_remark']?.toString() ?? ''
              : '',
        };

         // Initialize saved items
          _savedACDBs = List<Map<String, dynamic>>.from(
            formData['acdbAssets'] ?? [],
          );
          _savedLSPUs = List<Map<String, dynamic>>.from(
            formData['lspuAssets'] ?? [],
          );
          _savedAviationLamps = List<Map<String, dynamic>>.from(
            formData['aviationLampAssets'] ?? [],
          );

        setState(() {
          _assetAuditData = data;
          _displayFormData = formData;
          _isLoadingData = false;
        });

        _initializeFormControllers(formData);
        Logger.debugLog('✅ Electrical: Data loaded successfully');
      } else {
        setState(() {
          _errorMessage = 'No data available for this site';
          _isLoadingData = false;
        });
      }
    } catch (e) {
      Logger.errorLog('❌ Electrical: Error loading data: $e');
      setState(() {
        _errorMessage = 'Error loading data: $e';
        _isLoadingData = false;
      });
    }
  }

  void _initializeFormControllers(Map<String, dynamic> formData) {
    _remarksController.text = formData['remarks'] ?? '';
    Logger.debugLog('📝 Initialized form controllers');
    // Add listeners for form changes
    _remarksController.addListener(_onFormChanged);
    if (mounted) {
      setState(() {});
    }
  }

  // Callback methods for AssetAuditFormComponent
  void _onACDBItemSaved(List<Map<String, dynamic>> items) {
    setState(() {
      _savedACDBs = items;
      _displayFormData?['acdbAssets'] = items;
      _hasFormDataChanges = true;
    });
  }

  void _onLSPUItemSaved(List<Map<String, dynamic>> items) {
    setState(() {
      _savedLSPUs = items;
      _displayFormData?['lspuAssets'] = items;
      _hasFormDataChanges = true;
    });
  }

  void _onAviationLampItemSaved(List<Map<String, dynamic>> items) {
    setState(() {
      _savedAviationLamps = items;
      _displayFormData?['aviationLampAssets'] = items;
      _hasFormDataChanges = true;
    });
  }

  // Validation methods
  bool _validateAcdbSerialNumber(String serialNumber, bool isQRCodeScanned) {
    final savedItems =
        _displayFormData?['acdbAllAssets'] as List<dynamic>? ?? [];
    return AssetAuditValidationHelper.validateQRCodeSerialNumber(
      serialNumber,
      savedItems,
      isQRCodeScanned,
    );
  }

  bool _validateLspuSerialNumber(String serialNumber, bool isQRCodeScanned) {
    final savedItems =
        _displayFormData?['lspuAllAssets'] as List<dynamic>? ?? [];
    return AssetAuditValidationHelper.validateQRCodeSerialNumber(
      serialNumber,
      savedItems,
      isQRCodeScanned,
    );
  }

  bool _validateAviationLampSerialNumber(String serialNumber, bool isQRCodeScanned) {
    final savedItems =
        _displayFormData?['aviationLampAllAssets'] as List<dynamic>? ?? [];
    return AssetAuditValidationHelper.validateQRCodeSerialNumber(
      serialNumber,
      savedItems,
      isQRCodeScanned,
    );
  }

  Future<void> postCurrentScreenData() async {
    try {
      Logger.debugLog('📤 Electrical: Starting postCurrentScreenData');

      final finalData =
          _assetAuditData?['responseData'][AssetAuditNavigationHelper.dataValueForPage(
            _screenName,
            'TELECOM',
          )];
      final finalRemarks = finalData?['remarks'] as List<dynamic>? ?? [];
      final finalACDBAssets = finalData?['ACDB'] as List<dynamic>? ?? [];
      final finalLSPUAssets = finalData?['LSPU'] as List<dynamic>? ?? [];
      final finalAviationLampAssets = finalData?['Aviation Lamp'] as List<dynamic>? ?? [];

      // Collect all modified assets
      final modifiedAssetsWithAllProperties = <dynamic>[];

      // ===== ACDB Assets =====
      modifiedAssetsWithAllProperties.addAll(
        DataTransformationHelper.modifyData(
          finalACDBAssets,
          _savedACDBs,
        ),
      );

      // ===== LSPU Assets =====
      modifiedAssetsWithAllProperties.addAll(
        DataTransformationHelper.modifyData(
          finalLSPUAssets,
          _savedLSPUs,
        ),
      );

      // ===== Aviation Lamp Assets =====
      modifiedAssetsWithAllProperties.addAll(
        DataTransformationHelper.modifyData(
          finalAviationLampAssets,
          _savedAviationLamps,
        ),
      );

      // ===== Remarks =====
      if (finalRemarks.isNotEmpty) {
        final finalRemarksMap = Map<String, dynamic>.from(finalRemarks.first);
        final String remark = _remarksController.text;
        if (remark.isNotEmpty) {
          finalRemarksMap['item_type_remark'] = remark;
          modifiedAssetsWithAllProperties.add(finalRemarksMap);
        }
      }

      // ===== Update _assetAuditData with modified data before saving =====
      _applySavedItemsToAssets(finalACDBAssets, _savedACDBs);
      _applySavedItemsToAssets(finalLSPUAssets, _savedLSPUs);
      _applySavedItemsToAssets(finalAviationLampAssets, _savedAviationLamps);

      // Update Remarks in _assetAuditData
      if (finalRemarks.isNotEmpty) {
        final String remark = _remarksController.text;
        if (remark.isNotEmpty) {
          finalRemarks.first['item_type_remark'] = remark;
        }
      }

      // ===== Update local SQLite with modified data =====
      final updated = await _service.updateDataInSqlite(
        siteAuditSchId: widget.siteAuditSchId,
        updatedData: _assetAuditData ?? {},
      );
      if (!updated) {
        throw Exception('Failed to update local SQLite data');
      }

      // Prepare data for posting
      final postObject = [...modifiedAssetsWithAllProperties];

      Logger.debugLog(
        '📤 Electrical: Prepared ${postObject.length} items for posting',
      );

      await ServiceLocator().assetAuditPostService.postAssetAuditDataWithPhotoReplacement(
        requests: postObject,
        isLastPage: AssetAuditNavigationHelper.getTelecomNextScreenName(_assetAuditData, _screenName) == 'SUBMIT',
        activityType: ActivityTypeEnum.assetAudit,
      );
      Logger.debugLog('✅ Electrical: Data posted successfully');
    } catch (e) {
      Logger.errorLog('❌ Electrical: Error in postCurrentScreenData: $e');
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
          parentContext: widget.parentContext,
          onSaveAndExit: () async {
            if (_hasFormDataChanges) {
              await postCurrentScreenData();
            }
          },
          onDiscard: () {},
        ),
      );
    } else {
      navigateBackOrToHome(
        context,
        targetContext: widget.parentContext,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      resizeToAvoidBottomInset: true,
      appBar: CustomFormAppbar(
        title: 'Electrical',
        onClose: () {
          _showUnsavedChangesDialog();
        },
      ),
      body: Stack(
        children: [
          // Background image
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
                            bottom:
                                MediaQuery.of(context).viewInsets.bottom + 100,
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
                                // ACDB Section
                                AssetAuditFormComponent(
                                  componentId: 'acdb_component',
                                  serialLabel: "ACDB",
                                  serialHintText: "ACDB",
                                  photoLabel: "Add Photo of ACDB",
                                  serialController: _acdbSerialController,
                                  initialSavedItems: _savedACDBs,
                                  onItemSaved: _onACDBItemSaved,
                                  onStatusChanged: (status) {
                                    setState(() {
                                      _hasFormDataChanges = true;
                                    });
                                  },
                                  customValidator: _validateAcdbSerialNumber,
                                  customValidationErrorMessage:
                                      "Invalid ACDB serial number. Please check and try again.",
                                  siteAuditSchId: widget.siteAuditSchId,
                                  showTable: true,
                                  tableTitle: "ACDB Items",
                                ),
                                getHeight(20),

                                // LSPU Section
                                AssetAuditFormComponent(
                                  componentId: 'lspu_component',
                                  serialLabel: "LSPU",
                                  serialHintText: "LSPU",
                                  photoLabel: "Add Photo of LSPU",
                                  serialController: _lspuSerialController,
                                  initialSavedItems: _savedLSPUs,
                                  onItemSaved: _onLSPUItemSaved,
                                  onStatusChanged: (status) {
                                    setState(() {
                                      _hasFormDataChanges = true;
                                    });
                                  },
                                  customValidator: _validateLspuSerialNumber,
                                  customValidationErrorMessage:
                                      "Invalid LSPU serial number. Please check and try again.",
                                  siteAuditSchId: widget.siteAuditSchId,
                                  showTable: true,
                                  tableTitle: "LSPU Items",
                                ),
                                getHeight(20),

                                // Aviation Lamp Section (only show if Aviation Lamp data exists)
                                if (_displayFormData?['aviationLampAvailable'] == true) ...[
                                  AssetAuditFormComponent(
                                    componentId: 'aviation_lamp_component',
                                    serialLabel: "Aviation Lamp",
                                    serialHintText: "Aviation Lamp",
                                    photoLabel: "Add Photo of Aviation Lamp",
                                    serialController: _aviationLampSerialController,
                                    initialSavedItems: _savedAviationLamps,
                                    onItemSaved: _onAviationLampItemSaved,
                                    onStatusChanged: (status) {
                                      setState(() {
                                        _hasFormDataChanges = true;
                                      });
                                    },
                                    customValidator: _validateAviationLampSerialNumber,
                                    customValidationErrorMessage:
                                        "Invalid Aviation Lamp serial number. Please check and try again.",
                                    siteAuditSchId: widget.siteAuditSchId,
                                    showTable: true,
                                    tableTitle: "Aviation Lamp Items",
                                  ),
                                  getHeight(20),
                                ],

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
                    if (_hasFormDataChanges) {
                      await postCurrentScreenData();
                    }
                  },
                  assetAuditData: _assetAuditData,
                  auditSchId: widget.auditSchId,
                  siteType: widget.siteType,
                  siteAuditSchId: widget.siteAuditSchId,
                  screenName: _screenName,
                  parentContext: widget.parentContext,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}