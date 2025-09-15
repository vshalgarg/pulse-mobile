import 'package:app/commonWidgets/custom_buttons/arrow_botton.dart';
import 'package:app/constants/constants_methods.dart';
import 'package:app/utils/asset_audit_navigation_helper.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../bloc/asset_audit_cubit.dart';
import '../../../bloc/asset_audit_state.dart';
import '../../../models/asset_audit_post_model.dart';
import '../../../commonWidgets/custom_dialogs/unsaved_changes_dialog.dart';
import '../../../commonWidgets/custom_form_appbar.dart';
import '../../../commonWidgets/custom_form_field.dart';
import '../../../commonWidgets/custom_remark.dart';
import '../../../commonWidgets/asset_audit_form_component.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_images.dart';
import '../../../constants/constants_strings.dart';
import '../../../models/asset_audit_model.dart';
import '../../home_screen.dart';

class PCUScreen extends StatefulWidget {
  final String siteType;
  final String auditSchId;
  final String siteAuditSchId;
  final AssetAuditModel? assetAuditData; // Complete asset audit data

  const PCUScreen({
    super.key,
    required this.siteType,
    required this.auditSchId,
    required this.siteAuditSchId,
    this.assetAuditData, // Complete asset audit data
  });

  @override
  State<PCUScreen> createState() => _PCUScreenState();
}

class _PCUScreenState extends State<PCUScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController serialController = TextEditingController();
  bool hasUnsavedChanges = false;
  bool showValidationErrors = false;
  final remarksController = TextEditingController();
  final ratingController = TextEditingController();
  List<Map<String, dynamic>> savedPcuItems = [];
  bool isQRCodeScanned = false;
  String? lastValidatedSerial;
  String? _pendingNavigation; // Track pending navigation after successful post

  final TextEditingController pcuSerialController = TextEditingController();

  int get totalPcuItems {
    return getPcuData(widget.assetAuditData)?.assets.length ?? 0;
  }

  CategoryData? get pcuCategoryData {
    return getPcuData(widget.assetAuditData);
  }

  static CategoryData? getPcuData(AssetAuditModel? assetAuditData) {
    CategoryData? invertorData = assetAuditData?.responseData.categories['Invertor'];
    if(invertorData != null){
      return invertorData;
    }
    CategoryData? pcuData = assetAuditData?.responseData.categories['PCU'];
    if(pcuData != null){
      return pcuData;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    serialController.addListener(_onFormChanged);
    remarksController.addListener(_onFormChanged);
    ratingController.addListener(_onFormChanged);
    pcuSerialController.addListener(_onFormChanged);
    _loadExistingData();
  }

  @override
  void dispose() {
    serialController.removeListener(_onFormChanged);
    remarksController.removeListener(_onFormChanged);
    ratingController.removeListener(_onFormChanged);
    pcuSerialController.removeListener(_onFormChanged);
    serialController.dispose();
    remarksController.dispose();
    ratingController.dispose();
    pcuSerialController.dispose();
    super.dispose();
  }

  void _loadExistingData() {
    if (widget.assetAuditData == null) return;
    
    final pcuData = getPcuData(widget.assetAuditData);
    if (pcuData == null || pcuData.assets.isEmpty) return;

    // Load saved items without unnecessary setState
    final newSavedItems = pcuData.assets
        .where((asset) => asset.photoId != null && asset.photoId.toString().isNotEmpty)
        .map((asset) => {
      'serialNumber': asset.mfgSerialNo ?? asset.nexgenSerialNo ?? '',
      'photo': asset.photoId?.toString(),
      'status': asset.assetStatus ?? 'OK',
      'rating': asset.itemTypeRemark ?? '',
      'isQRCodeScanned': asset.qrCodeScanned ?? false,
      'timestamp': DateTime.now(),
      'assetAuditSiteRespId': asset.assetAuditSiteRespId,
    }).toList();

    // Only update state if data actually changed
    if (newSavedItems.length != savedPcuItems.length) {
      setState(() {
        savedPcuItems = newSavedItems;
      });
    } else {
      savedPcuItems = newSavedItems;
    }

    // Load remarks only if needed
    if (pcuData.remarks.isNotEmpty && remarksController.text.isEmpty) {
      remarksController.text = pcuData.remarks.first.itemTypeRemark ?? '';
    }
  }

  void _onFormChanged() {
    final newHasUnsavedChanges = pcuSerialController.text.isNotEmpty ||
        ratingController.text.isNotEmpty ||
        remarksController.text.isNotEmpty;

    final newShowValidationErrors = showValidationErrors && _isFormValid() ? false : showValidationErrors;

    // Only update state if values actually changed
    if (hasUnsavedChanges != newHasUnsavedChanges || showValidationErrors != newShowValidationErrors) {
      setState(() {
        hasUnsavedChanges = newHasUnsavedChanges;
        showValidationErrors = newShowValidationErrors;
      });
    }
  }

  bool _isFormValid() {
    return pcuSerialController.text.isNotEmpty &&
        ratingController.text.isNotEmpty &&
        _validateSerialNumber(pcuSerialController.text, isQRCodeScanned);
  }

  bool _validateSerialNumber(String serialNumber, bool isQRCodeScanned) {
    if (widget.assetAuditData == null || lastValidatedSerial == serialNumber) return true;
    final pcuData = getPcuData(widget.assetAuditData);
    if (pcuData == null) return false;
    final allItems = pcuData.assets;
    bool isValid = isQRCodeScanned
        ? allItems.any((item) => item.nexgenSerialNo?.toLowerCase() == serialNumber.toLowerCase())
        : allItems.any((item) => item.mfgSerialNo?.toLowerCase() == serialNumber.toLowerCase());
    lastValidatedSerial = serialNumber;
    if (!isValid) {
      showCustomToast(context, isQRCodeScanned
          ? 'Invalid QR Code! Serial number not found.'
          : 'Invalid manual entry! Serial number not found.');
    }
    return isValid;
  }

  bool _validatePCUSerialNumber(String serialNumber, bool isQRCodeScanned) {
    return _validateSerialNumber(serialNumber, isQRCodeScanned);
  }

  void _onPCUItemSaved(List<Map<String, dynamic>> updatedItems) {
    setState(() {
      savedPcuItems = List.from(updatedItems);
      hasUnsavedChanges = true;
    });
  }

  Future<void> _saveAndExit() async {
      await _postPcuData();
  }







  String _formatDateForApi(DateTime dateTime) {
    return "${dateTime.day.toString().padLeft(2, '0')}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}";
  }

  Future<void> _postPcuData() async {
    if (savedPcuItems.isEmpty && remarksController.text.trim().isEmpty) return;
    try {
      final now = DateTime.now();
      List<Map<String, dynamic>> allItemsToPost = [];

      for (var item in savedPcuItems) {
        String? photoId = item['photo'];
        int? numericPhotoId;
        if (photoId != null) {
          // The component handles photo uploads, so we expect numeric IDs
          numericPhotoId = int.tryParse(photoId);
          if (numericPhotoId == null) continue;
        }
        allItemsToPost.add({
          'assetAuditSiteRespId': (item['assetAuditSiteRespId'] is int) ? item['assetAuditSiteRespId'] : int.tryParse(item['assetAuditSiteRespId']?.toString() ?? '0') ?? 0,
          'auditSchId': int.parse(widget.auditSchId),
          'siteAuditSchId': int.parse(widget.siteAuditSchId),
          'itemInstanceId': 0, // Default value
          'nexgenSerialNo': item['serialNumber'],
          'itemTypeId': 6,
          'qrCodeScanned': item['isQRCodeScanned'] ?? false,
          'qrCodeScannedTs': item['isQRCodeScanned'] == true ? _formatDateForApi(now) : null,
          'photoId': numericPhotoId,
          'photoTakenTs': _formatDateForApi(now),
          'assetStatus': item['status'] ?? 'OK',
          'itemTypeRemark': item['rating'] ?? '',
          'localAuditLogId': 0,
          'localQrCodeScannedTs': item['isQRCodeScanned'] == true ? _formatDateForApi(now) : null,
          'localCreatedDt': _formatDateForApi(now),
          'localModifiedDt': _formatDateForApi(now),
          'syncProcessId': 0,
          'isActive': true,
          'remarks': item['rating'] ?? '',
        });
      }

      if (remarksController.text.trim().isNotEmpty) {
        allItemsToPost.add({
          'assetAuditSiteRespId': _getRemarksAssetAuditSiteRespId() ?? 0,
          'auditSchId': int.parse(widget.auditSchId),
          'siteAuditSchId': int.parse(widget.siteAuditSchId),
          'itemInstanceId': 0,
          'nexgenSerialNo': 'REMARKS',
          'itemTypeId': 6,
          'qrCodeScanned': false,
          'qrCodeScannedTs': null,
          'photoId': null,
          'photoTakenTs': _formatDateForApi(now),
          'assetStatus': 'OK',
          'itemTypeRemark': remarksController.text.trim(),
          'localAuditLogId': 0,
          'localQrCodeScannedTs': null,
          'localCreatedDt': _formatDateForApi(now),
          'localModifiedDt': _formatDateForApi(now),
          'syncProcessId': 0,
          'isActive': true,
          'remarks': remarksController.text.trim(),
        });
      }

      if (allItemsToPost.isNotEmpty) {
        print('=== PCU Creating Requests Debug ===');
        print('allItemsToPost.length: ${allItemsToPost.length}');
        print('First item keys: ${allItemsToPost.first.keys}');
        print('First item auditSchId: ${allItemsToPost.first['auditSchId']} (${allItemsToPost.first['auditSchId'].runtimeType})');
        print('First item siteAuditSchId: ${allItemsToPost.first['siteAuditSchId']} (${allItemsToPost.first['siteAuditSchId'].runtimeType})');
        print('=== End PCU Creating Requests Debug ===');
        
        final requests = allItemsToPost.map((item) => AssetAuditPostRequest(
          assetAuditSiteRespId: (item['assetAuditSiteRespId'] is int) ? item['assetAuditSiteRespId'] as int? : int.tryParse(item['assetAuditSiteRespId']?.toString() ?? '0'),
          auditSchId: (item['auditSchId'] is int) ? item['auditSchId'] as int : int.parse(item['auditSchId'].toString()),
          siteAuditSchId: (item['siteAuditSchId'] is int) ? item['siteAuditSchId'] as int : int.parse(item['siteAuditSchId'].toString()),
          siteId: 0, // Default value
          itemInstanceId: (item['itemInstanceId'] is int) ? item['itemInstanceId'] as int? ?? 0 : int.tryParse(item['itemInstanceId']?.toString() ?? '0') ?? 0,
          nexgenSerialNo: item['nexgenSerialNo'] as String,
          itemTypeId: (item['itemTypeId'] is int) ? item['itemTypeId'] as int : int.parse(item['itemTypeId'].toString()),
          qrCodeScanned: item['qrCodeScanned'] as bool,
          qrCodeScannedTs: item['qrCodeScannedTs'] as String?,
          photoId: (item['photoId'] is int) ? item['photoId'] as int? : int.tryParse(item['photoId']?.toString() ?? ''),
          photoTakenTs: item['photoTakenTs'] as String,
          assetStatus: item['assetStatus'] as String,
          longitude: item['longitude'] as String?,
          latitude: item['latitude'] as String?,
          itemTypeRemark: item['itemTypeRemark'] as String?,
          localAuditLogId: (item['localAuditLogId'] is int) ? item['localAuditLogId'] as int : int.parse(item['localAuditLogId'].toString()),
          localQrCodeScannedTs: (item['localQrCodeScannedTs'] as String?) ?? _formatDateForApi(DateTime.now()),
          localCreatedDt: item['localCreatedDt'] as String,
          localModifiedDt: item['localModifiedDt'] as String,
          syncProcessId: (item['syncProcessId'] is int) ? item['syncProcessId'] as int : int.parse(item['syncProcessId'].toString()),
          isActive: item['isActive'] as bool,
          remarks: item['remarks'] as String?,
        )).toList();
        
        // Store the current remarks text before posting
        final currentRemarksText = remarksController.text;
        print('PCU Screen: Storing current remarks text: "$currentRemarksText"');
        
        context.read<AssetAuditCubit>().postAssetAuditData(requests: requests);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error posting PCU data: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }


  int? _getRemarksAssetAuditSiteRespId() {
    final pcuData = getPcuData(widget.assetAuditData);
    if (pcuData != null && pcuData.remarks.isNotEmpty) {
      for (var remark in pcuData.remarks) {
        if (remark.assetAuditSiteRespId != null && remark.assetAuditSiteRespId > 0 && (remark.itemType == 'Invertor' || remark.itemType == 'PCU')) {
          return remark.assetAuditSiteRespId;
        }
      }
      return pcuData.remarks.first.assetAuditSiteRespId;
    }
    return pcuCategoryData?.assets.isNotEmpty == true
        ? pcuCategoryData!.assets.first.assetAuditSiteRespId
        : null;
  }



  String? _getNextAvailableScreen() {
    return AssetAuditNavigationHelper.getNextAvailableScreen(widget.assetAuditData, 'Invertor');
  }

  String? _getPreviousAvailableScreen() {
    return AssetAuditNavigationHelper.getPreviousAvailableScreen(widget.assetAuditData, 'Invertor');
  }

  void _navigateToNextScreen(BuildContext context, String screenName) {
    print('=== PCU Navigation Debug ===');
    print('Navigating to: $screenName');
    print('auditSchId: ${widget.auditSchId} (${widget.auditSchId.runtimeType})');
    print('siteAuditSchId: ${widget.siteAuditSchId} (${widget.siteAuditSchId.runtimeType})');
    print('siteType: ${widget.siteType}');
    print('assetAuditData: ${widget.assetAuditData != null}');
    print('=== End PCU Navigation Debug ===');
    
    try {
      AssetAuditNavigationHelper.navigateToNextScreen(
        context,
        screenName,
        widget.siteType,
        widget.auditSchId,
        widget.siteAuditSchId,
        widget.assetAuditData,
      );
    } catch (e, stackTrace) {
      print('=== PCU Navigation Error ===');
      print('Error: $e');
      print('Stack trace: $stackTrace');
      print('=== End PCU Navigation Error ===');
      rethrow;
    }
  }



  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<AssetAuditCubit, AssetAuditState>(
          listener: (context, state) {
            if (state is AssetAuditLoaded) {
              _loadExistingData();
            } else if (state is AssetAuditPosting) {
              // Show loading dialog when posting data
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => const Center(
                  child: CircularProgressIndicator(),
                ),
              );
            } else if (state is AssetAuditPostSuccess) {
              // Close loading dialog when posting is successful
              if (Navigator.canPop(context)) {
                Navigator.of(context).pop();
              }
              
              // Handle pending navigation
              if (_pendingNavigation != null) {
                final navigationTarget = _pendingNavigation;
                _pendingNavigation = null; // Clear the flag
                
                if (navigationTarget == 'home') {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => HomeScreen()),
                  );
                } else {
                  _navigateToNextScreen(context, navigationTarget!);
                }
                return; // Don't refresh data if navigating away
              }
              
              context.read<AssetAuditCubit>().getAssetAuditData(
                siteType: widget.siteType,
                auditSchId: widget.auditSchId,
                siteAuditSchId: widget.siteAuditSchId,
              );
            } else if (state is AssetAuditPostError) {
              // Close loading dialog if it's open
              if (Navigator.canPop(context)) {
                Navigator.of(context).pop();
              }
              // Clear pending navigation on error
              _pendingNavigation = null;
              print("for error ${state.message}");
              showCustomToast(context, 'Error saving PCU data: ${state.message}');
            } else if (state is AssetAuditError) {
              showCustomToast(context, 'Error loading data: ${state.message}');
            }
          },
        ),
      ],
      child: PopScope(
        canPop: !hasUnsavedChanges,
        child: Scaffold(
          extendBodyBehindAppBar: true,
          resizeToAvoidBottomInset: false,
          appBar: CustomFormAppbar(
            title: "Asset Audit",
            onClose: () async {
              if (hasUnsavedChanges) {
                showDialog(
                  context: context,
                  barrierDismissible: true,
                  builder: (dialogContext) => UnsavedChangesDialog(
                    siteAuditSchId: widget.siteAuditSchId,
                    section: "Asset Audit",
                    parentContext: context, // Use the outer context (screen context)
                    onSaveAndExit: () async {
                      await _saveAndExit();
                    },
                    onDiscard: () {
                    },
                  ),
                );
              } else {
                // Add safety checks to prevent Navigator lock
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                      builder: (context) => HomeScreen()
                  ),
                );
              }
            },
          ),
          body: Stack(
            children: [
              Positioned.fill(
                child: SvgPicture.asset(
                  AppImages.home,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                ),
              ),
              SafeArea(
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 120),
                          child: Container(
                            padding: const EdgeInsets.only(top: 20, left: 16, right: 16, bottom: 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CustomFormField(
                                  label: "Inverter Make",
                                  hintText: "Text",
                                  isRequired: true,
                                  isEditable: false,
                                  initialValue: pcuCategoryData?.assets.isNotEmpty == true
                                      ? pcuCategoryData!.assets.first.oemName ?? "N/A"
                                      : "N/A",
                                ),
                                getHeight(15),
                                CustomFormField(
                                  label: "Capacity of Inverter",
                                  hintText: "Text",
                                  isRequired: false,
                                  isEditable: false,
                                  initialValue: pcuCategoryData?.assets.isNotEmpty == true
                                      ? pcuCategoryData!.assets.first.capacity ?? "N/A"
                                      : "N/A",
                                ),
                                getHeight(15),
                                CustomFormField(
                                  label: "Count of PCU",
                                  initialValue: totalPcuItems.toString(),
                                  isRequired: false,
                                  isEditable: false,
                                ),
                                getHeight(15),
                                Text(
                                  "Inverter Details",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white,
                                    fontFamily: fontFamilyMontserrat,
                                  ),
                                ),
                                getHeight(3),
                                AssetAuditFormComponent(
                                  componentId: 'pcu_component',
                                  serialLabel: "Inverter - Serial Number *",
                                  serialHintText: "Inverter Serial Number *",
                                  photoLabel: "Add a Photo",
                                  disabledFieldLabel: pcuCategoryData?.assets.isNotEmpty == true
                                      ? "Inverter (${pcuCategoryData!.assets.first.oemName ?? 'N/A'})"
                                      : "N/A",
                                  disabledFieldValue: pcuCategoryData?.assets.isNotEmpty == true
                                      ? pcuCategoryData!.assets.first.oemName ?? "N/A"
                                      : "N/A",
                                  serialController: pcuSerialController,
                                  initialSavedItems: savedPcuItems,
                                  onItemSaved: _onPCUItemSaved,
                                  onStatusChanged: (status) {
                                    // Handle status change if needed
                                  },
                                  customValidator: _validatePCUSerialNumber,
                                  customValidationErrorMessage: isQRCodeScanned
                                      ? 'Invalid QR Code! Serial number not found in system.'
                                      : 'Invalid serial number! Please check and try again.',
                                  siteAuditSchId: widget.siteAuditSchId,
                                  showTable: true,
                                  tableTitle: "Saved Inverter Items",
                                  imageHeight: 150,
                                  enableImageCompression: true,
                                ),
                                getHeight(15),
                                CustomRemarksField(
                                  label: "Add Remarks",
                                  hintText: "Remarks",
                                  controller: remarksController,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(16),
                        width: double.infinity,
                        child: Row(
                          children: [
                            Expanded(
                              child: ArrowButton(
                                text: _getPreviousAvailableScreen() ?? "Back",
                                isLeftArrow: true,
                                backgroundColor: AppColors.buttonColorBackBg,
                                textColor: AppColors.buttonColorTextBg,
                                onPressed: () {
                                  final previousScreen = _getPreviousAvailableScreen();
                                  if (previousScreen != null) {
                                    _navigateToNextScreen(context, previousScreen);
                                  } else {
                                    Navigator.pop(context);
                                  }
                                },
                              ),
                            ),
                            getWidth(14),
                            Expanded(
                              child: Builder(
                                builder: (context) {
                                  final nextScreen = _getNextAvailableScreen();
                                  return ArrowButton(
                                    text: nextScreen ?? "Submit",
                                    isLeftArrow: false,
                                    backgroundColor: AppColors.buttonColorBg,
                                    textColor: AppColors.buttonColorSite,
                                    onPressed: () async {
                                      // POST data to API before navigation
                                      await _postPcuData();

                                      // Navigate to the next available screen
                                      _navigateToNextScreen(
                                          context, nextScreen ?? 'HOME');
                                    },
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

}
