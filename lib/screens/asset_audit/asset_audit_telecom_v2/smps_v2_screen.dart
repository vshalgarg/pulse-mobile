import 'package:app/enum/activity_type_enum.dart';
import 'package:app/routes/route_generator.dart';
import 'package:app/utils/asset_audit_navigation_helper.dart';
import 'package:app/utils/asset_audit_validation_helper.dart';
import 'package:app/utils/data_transformation_helper.dart';
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
import '../../../services/service_locator.dart';
import '../../../utils/logger.dart';
import '../../../services/asset_audit/central_asset_audit_service.dart';

class SMPSV2Screen extends StatefulWidget {
  final String siteAuditSchId;
  final String siteType;
  final String auditSchId;
  final BuildContext parentContext;

  const SMPSV2Screen({
    super.key,
    required this.siteAuditSchId,
    required this.siteType,
    required this.auditSchId,
    required this.parentContext,
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
    _service = ServiceLocator().centralAssetAuditService;
    _loadData();
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

      Logger.debugLog(
        '🔄 SMPS V2: Loading data for site ${widget.siteAuditSchId}',
      );

      final data = await _service.getActualDataFromSqlite(
        siteAuditSchId: widget.siteAuditSchId,
      );

      if (data != null) {
        final smpsItems =
            data['responseData'][AssetAuditNavigationHelper.dataValueForPage(
                  _screenName,
                  'TELECOM',
                )]
                as Map<String, dynamic>? ??
            {};

        // Parse different asset type

        final smpsAssets = smpsItems['assets'] as List<dynamic>? ?? [];
        final smpsRectifiers =
            smpsItems['SMPS Rectifiers'] as List<dynamic>? ?? [];
        final smpsCabinet = smpsItems['SMPS Cabinet'] as List<dynamic>? ?? [];
        final remarksData = smpsItems['remarks'] as List<dynamic>? ?? [];

        print("smpsCabinet: $smpsCabinet");

        final formData = <String, dynamic>{
          'smpsMake': smpsAssets.isNotEmpty
              ? smpsAssets.first['oem_name']?.toString() ?? 'N/A'
              : 'N/A',
          'smpsCount': smpsAssets.length.toString(),
          'smpsRectifiersCount': smpsRectifiers.length.toString(),
          'smpsAssets': smpsAssets
              .where((obj) => obj['photo_id'] != null)
              .toList(),
          'smpsAllAssets': smpsAssets,
          'smpsRectifiers': smpsRectifiers
              .where((obj) => obj['photo_id'] != null)
              .toList(),
          'smpsRectifiersAllAssets': smpsRectifiers,
          'smpsCabinet': smpsCabinet
              .where((obj) => obj['photo_id'] != null)
              .toList(),
          'smpsCabinetAvailable': smpsCabinet.isNotEmpty,
          'smpsCabinetAllAssets': smpsCabinet,
          'remarks': remarksData.isNotEmpty
              ? remarksData.first['item_type_remark']?.toString() ?? ''
              : '',
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
    // Add listeners for form changes
    _remarksController.addListener(_onFormChanged);
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


  // Validation methods
  bool _validateCabinetSerialNumber(String serialNumber, bool isQRCodeScanned) {
    final savedItems =
        _displayFormData?['smpsCabinetAllAssets'] as List<dynamic>? ?? [];
    return AssetAuditValidationHelper.validateQRCodeSerialNumber(
      serialNumber,
      savedItems,
      isQRCodeScanned,
    );
  }

  bool _validateRectifierSerialNumber(
    String serialNumber,
    bool isQRCodeScanned,
  ) {
    final savedItems =
        _displayFormData?['smpsRectifiersAllAssets'] as List<dynamic>? ?? [];
    return AssetAuditValidationHelper.validateQRCodeSerialNumber(
      serialNumber,
      savedItems,
      isQRCodeScanned,
    );
  }


  Future<void> postCurrentScreenData() async {
    try {
      Logger.debugLog('📤 SMPS V2: Starting postCurrentScreenData');

      final finalData =
          _assetAuditData?['responseData'][AssetAuditNavigationHelper.dataValueForPage(
            _screenName,
            'TELECOM',
          )];
      final finalRemarks = finalData?['remarks'] as List<dynamic>? ?? [];
      final finalSMPSRectifiers =
          finalData?['SMPS Rectifiers'] as List<dynamic>? ?? [];
      final finalSMPSCabinet =
          finalData?['SMPS Cabinet'] as List<dynamic>? ?? [];


      // Collect all modified assets
      final modifiedAssetsWithAllProperties = <dynamic>[];

      // Add SMPS Rectifiers
      final modifiedSMPSRectifiers =
          _displayFormData?['smpsRectifiers'] as List<dynamic>? ?? [];
      modifiedAssetsWithAllProperties.addAll(
        DataTransformationHelper.modifyData(
          finalSMPSRectifiers,
          modifiedSMPSRectifiers,
        ),
      );

      // Add SMPS Cabinet
      final modifiedSMPSCabinet =
          _displayFormData?['smpsCabinet'] as List<dynamic>? ?? [];
      modifiedAssetsWithAllProperties.addAll(
        DataTransformationHelper.modifyData(
          finalSMPSCabinet,
          modifiedSMPSCabinet,
        ),
      );


      // Update remarks
      final String remark = _remarksController.text;
      if (remark.isNotEmpty && finalRemarks.isNotEmpty) {
        try {
          finalRemarks.first['item_type_remark'] = remark;
          Logger.debugLog('✅ Updated remarks: $remark');
        } catch (e) {
          Logger.errorLog('❌ Error updating remarks: $e');
        }
      }

      // Update local data
      _service.updateDataInSqlite(
        siteAuditSchId: widget.siteAuditSchId,
        updatedData: _assetAuditData ?? {},
      );

      // Prepare data for posting
      final postObject = [...modifiedAssetsWithAllProperties, ...finalRemarks];

      Logger.debugLog(
        '📤 SMPS V2: Prepared ${postObject.length} items for posting',
      );


      await ServiceLocator().assetAuditPostService.postAssetAuditDataWithPhotoReplacement(
        requests: postObject,
        isLastPage: AssetAuditNavigationHelper.getTelecomNextScreenName(_assetAuditData, _screenName) == 'SUBMIT',
        activityType: ActivityTypeEnum.assetAudit,
      );
      Logger.debugLog('SMPS V2: Data posted successfully');
    } catch (e) {
      Logger.errorLog('SMPS V2: Error in postCurrentScreenData: $e');
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
        title: 'SMPS',
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
                                // SMPS Make (readonly)
                                CustomFormField(
                                  label: "SMPS Make",
                                  hintText:
                                      _displayFormData?['smpsMake'] ?? "N/A",
                                  isRequired: false,
                                  isEditable: false,
                                ),
                                getHeight(15),

                                // Count of SMPS (readonly)
                                if (_displayFormData?['smpsCount'] != "0") ...[
                                  CustomFormField(
                                    label: "Count of SMPS",
                                    hintText:
                                        _displayFormData?['smpsCount'] ?? "0",
                                    isRequired: false,
                                    isEditable: false,
                                  ),
                                  getHeight(15),
                                ],

                                if (_displayFormData?['smpsCabinetAvailable'] ??
                                    false) ...[
                                  // SMPS Cabinet Section
                                  AssetAuditFormComponent(
                                    componentId: 'smps_cabinet_component',
                                    serialLabel: "Cabinet - Serial Number *",
                                    serialHintText: "Cabinet Serial Number *",
                                    photoLabel:
                                        "Add Photo of Cabinet Serial Number",
                                    serialController: TextEditingController(),
                                    initialSavedItems:
                                        _displayFormData?['smpsCabinet']
                                            as List<dynamic>? ??
                                        [],
                                    onItemSaved: _onSMPSCabinetItemSaved,
                                    onStatusChanged: (status) {},
                                    customValidator:
                                        _validateCabinetSerialNumber,
                                    customValidationErrorMessage:
                                        "Invalid SMPS Cabinet serial number. Please check and try again.",
                                    siteAuditSchId: widget.siteAuditSchId,
                                    showTable: true,
                                    tableTitle: "SMPS Cabinet",
                                  ),
                                  getHeight(20),
                                ],

                                if (_displayFormData?['smpsRectifiersCount'] !=
                                    "0") ...[
                                  // Count of SMPS Rectifiers (readonly)
                                  CustomFormField(
                                    label: "Count of Rectifiers",
                                    hintText:
                                        _displayFormData?['smpsRectifiersCount'] ??
                                        "0",
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
                                    initialSavedItems:
                                        _displayFormData?['smpsRectifiers']
                                            as List<dynamic>? ??
                                        [],
                                    onItemSaved: _onSMPSRectifierItemSaved,
                                    onStatusChanged: (status) {},
                                    customValidator:
                                        _validateRectifierSerialNumber,
                                    customValidationErrorMessage:
                                        "Invalid SMPS Rectifiers serial number. Please check and try again.",
                                    siteAuditSchId: widget.siteAuditSchId,
                                    showTable: true,
                                    tableTitle: "SMPS Rectifiers",
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
