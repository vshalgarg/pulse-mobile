import 'dart:async';
import 'dart:io';
import 'dart:convert';

import 'package:app/commonWidgets/custom_buttons/arrow_botton.dart';
import 'package:app/constants/constants_methods.dart';
import 'package:app/screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';
import '../../../models/asset_audit_model.dart';
import '../../../models/asset_audit_post_model.dart';
import '../../../utils/asset_audit_post_helper.dart';
import '../../../utils/asset_audit_photo_upload_helper.dart';
import '../../../utils/asset_audit_navigation_helper.dart';
import '../../../bloc/asset_audit_cubit.dart';
import '../../../bloc/asset_audit_state.dart';
import '../../../bloc/asset_audit_get_image_cubit.dart';
import '../../../bloc/audit_schedule_status_cubit.dart';

import '../../../commonWidgets/asset_type_card.dart';
import '../../../commonWidgets/asset_audit_form_component.dart';
import '../../../commonWidgets/custom_dialogs/success_dialog.dart';
import '../../../commonWidgets/custom_dialogs/unsaved_changes_dialog.dart';
import '../../../commonWidgets/custom_form_appbar.dart';
import '../../../commonWidgets/custom_form_field.dart';
import '../../../commonWidgets/custom_remark.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_images.dart';
import '../../../constants/constants_strings.dart';
import '../../../commonWidgets/base64_image_widget.dart';
import '../../../repositories/image_repository.dart';
import '../../../app_config.dart';

class SMPSScreen extends StatefulWidget {
  final CategoryData? smpsData;
  final AssetAuditModel? assetAuditData;
  final bool showSuccessMessage;
  final String? ticketId;
  final String? siteType;
  final String? auditSchId;
  final String? siteAuditSchId;

  // Data from previous screens in the flow
  final List<Map<String, dynamic>>? extinguisherItems;
  final List<Map<String, dynamic>>? fencingItems;
  final List<Map<String, dynamic>>? dgItems;
  final List<Map<String, dynamic>>? solarPlatesItems;

  const SMPSScreen({
    super.key,
    this.smpsData,
    this.assetAuditData,
    this.showSuccessMessage = false,
    this.ticketId,
    this.siteType,
    this.auditSchId,
    this.siteAuditSchId,
    this.extinguisherItems,
    this.fencingItems,
    this.dgItems,
    this.solarPlatesItems,
  });

  @override
  State<SMPSScreen> createState() => _SMPSScreenState();
}

class _SMPSScreenState extends State<SMPSScreen> {
  // Controllers for each form component
  final TextEditingController rectifierSerialController = TextEditingController();
  final TextEditingController mpptSerialController = TextEditingController();
  final TextEditingController acdbSerialController = TextEditingController();
  final TextEditingController lspuSerialController = TextEditingController();
  final TextEditingController generalRemarksController = TextEditingController();

  // Saved items for each component
  List<Map<String, dynamic>> savedRectifierItems = [];
  List<Map<String, dynamic>> savedMPPTItems = [];
  List<Map<String, dynamic>> savedACDBItems = [];
  List<Map<String, dynamic>> savedLSPUItems = [];

  // Additional SMPS-specific fields
  String? selectedFile;
  String? selectedStatus;
  String? selectedBatteryStatus;
  String? selectedType;
  String? uploadedPhotoPath;

  // Image service for fetching images from API
  late ImageRepository _imageService;

  // Cache for storing fetched images
  Map<int, String> _imageCache = {};

  @override
  void initState() {
    super.initState();
    _imageService = ImageRepository(AppConfig.of(context).apiProvider);
    _loadInitialData();
  }

  @override
  void dispose() {
    rectifierSerialController.dispose();
    mpptSerialController.dispose();
    acdbSerialController.dispose();
    lspuSerialController.dispose();
    generalRemarksController.dispose();
    super.dispose();
  }

  /// Load initial data from API
  void _loadInitialData() {
    if (widget.smpsData != null) {
      // Load saved items from API data
      _loadSavedItemsFromAPI();
    }
  }

  /// Load saved items from API data
  void _loadSavedItemsFromAPI() {
    if (widget.smpsData == null) return;

    // Load items from subCategories if available
    if (widget.smpsData!.subCategories != null) {
      // Load Rectifier items
      if (widget.smpsData!.subCategories!['smpsCabinet'] != null) {
        for (var item in widget.smpsData!.subCategories!['smpsCabinet']!) {
          savedRectifierItems.add({
            'serialNumber': item.nexgenSerialNo ?? '',
            'photoId': item.photoId,
            'assetStatus': item.assetStatus ?? 'OK',
            'remarks': '',
            'isQRCodeScanned': item.qrCodeScanned ?? false,
            'qrCodeScannedTs': item.qrCodeScannedTs,
            'photoTakenTs': DateTime.now().toIso8601String(),
            'longitude': item.longitude,
            'latitude': item.latitude,
            'itemInstanceId': item.itemInstanceId ?? 0,
            'assetAuditSiteRespId': item.assetAuditSiteRespId ?? 0,
          });
        }
      }

      // Load MPPT items
      if (widget.smpsData!.subCategories!['smpsRectifier'] != null) {
        for (var item in widget.smpsData!.subCategories!['smpsRectifier']!) {
          savedMPPTItems.add({
            'serialNumber': item.nexgenSerialNo ?? '',
            'photoId': item.photoId,
            'assetStatus': item.assetStatus ?? 'OK',
            'remarks': '',
            'isQRCodeScanned': item.qrCodeScanned ?? false,
            'qrCodeScannedTs': item.qrCodeScannedTs,
            'photoTakenTs': DateTime.now().toIso8601String(),
            'longitude': item.longitude,
            'latitude': item.latitude,
            'itemInstanceId': item.itemInstanceId ?? 0,
            'assetAuditSiteRespId': item.assetAuditSiteRespId ?? 0,
          });
        }
      }

      // Load ACDB items
      if (widget.smpsData!.subCategories!['smpsACDB'] != null) {
        for (var item in widget.smpsData!.subCategories!['smpsACDB']!) {
          savedACDBItems.add({
            'serialNumber': item.nexgenSerialNo ?? '',
            'photoId': item.photoId,
            'assetStatus': item.assetStatus ?? 'OK',
            'remarks': '',
            'isQRCodeScanned': item.qrCodeScanned ?? false,
            'qrCodeScannedTs': item.qrCodeScannedTs,
            'photoTakenTs': DateTime.now().toIso8601String(),
            'longitude': item.longitude,
            'latitude': item.latitude,
            'itemInstanceId': item.itemInstanceId ?? 0,
            'assetAuditSiteRespId': item.assetAuditSiteRespId ?? 0,
          });
        }
      }

      // Load LSPU items
      if (widget.smpsData!.subCategories!['smpsLSPU'] != null) {
        for (var item in widget.smpsData!.subCategories!['smpsLSPU']!) {
          savedLSPUItems.add({
            'serialNumber': item.nexgenSerialNo ?? '',
            'photoId': item.photoId,
            'assetStatus': item.assetStatus ?? 'OK',
            'remarks': '',
            'isQRCodeScanned': item.qrCodeScanned ?? false,
            'qrCodeScannedTs': item.qrCodeScannedTs,
            'photoTakenTs': DateTime.now().toIso8601String(),
            'longitude': item.longitude,
            'latitude': item.latitude,
            'itemInstanceId': item.itemInstanceId ?? 0,
            'assetAuditSiteRespId': item.assetAuditSiteRespId ?? 0,
          });
        }
      }
    }
  }

  /// Check if there are unsaved changes
  bool get _hasChanges {
    return generalRemarksController.text.isNotEmpty ||
        savedRectifierItems.isNotEmpty ||
        savedMPPTItems.isNotEmpty ||
        savedACDBItems.isNotEmpty ||
        savedLSPUItems.isNotEmpty;
  }

  /// Navigate to next screen
  void _navigateToNextScreen(BuildContext context, String? nextScreen) {
    if (nextScreen == null) {
      // No next screen available, go to home
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => HomeScreen()),
      );
      return;
    }

    AssetAuditNavigationHelper.navigateToNextTelecomScreen(
      context,
      nextScreen,
      widget.siteType ?? '',
      widget.auditSchId ?? '',
      widget.siteAuditSchId ?? '',
      widget.assetAuditData,
    );
  }

  /// Get next available screen
  String? _getNextAvailableScreen() {
    return AssetAuditNavigationHelper.getNextAvailableTelecomScreen(
      widget.assetAuditData,
      'SMPS',
    );
  }

  /// Get previous available screen
  String? _getPreviousAvailableScreen() {
    return AssetAuditNavigationHelper.getPreviousAvailableTelecomScreen(
      widget.assetAuditData,
      'SMPS',
    );
  }

  /// Post current screen data to API
  Future<void> _postCurrentScreenData() async {
    if (widget.assetAuditData == null) {
      print('SMPS Screen: No asset audit data available for posting');
      return;
    }

    try {
      // Convert saved items to AssetAuditPostRequest objects
      List<AssetAuditPostRequest> requests = [];
      
      // Process Rectifier items
      for (var item in savedRectifierItems) {
        requests.add(AssetAuditPostRequest(
          siteAuditSchId: int.tryParse(widget.siteAuditSchId ?? '0') ?? 0,
          auditSchId: int.tryParse(widget.auditSchId ?? '0') ?? 0,
          siteId: 0,
          itemTypeId: 2, // Rectifier item type ID
          itemInstanceId: item['itemInstanceId'] ?? 0,
          assetAuditSiteRespId: item['assetAuditSiteRespId'] ?? 0,
          nexgenSerialNo: item['serialNumber'] ?? '',
          photoId: item['photoId'],
          assetStatus: item['assetStatus'] ?? 'OK',
          remarks: item['remarks'] ?? '',
          qrCodeScanned: item['isQRCodeScanned'] ?? false,
          qrCodeScannedTs: item['qrCodeScannedTs'],
          photoTakenTs: item['photoTakenTs'] ?? DateTime.now().toIso8601String(),
          longitude: item['longitude'],
          latitude: item['latitude'],
          localAuditLogId: DateTime.now().millisecondsSinceEpoch,
          localQrCodeScannedTs: DateTime.now().toIso8601String(),
          localCreatedDt: DateTime.now().toIso8601String(),
          localModifiedDt: DateTime.now().toIso8601String(),
          syncProcessId: 0,
          isActive: true,
        ));
      }

      // Process MPPT items
      for (var item in savedMPPTItems) {
        requests.add(AssetAuditPostRequest(
          siteAuditSchId: int.tryParse(widget.siteAuditSchId ?? '0') ?? 0,
          auditSchId: int.tryParse(widget.auditSchId ?? '0') ?? 0,
          siteId: 0,
          itemTypeId: 3, // MPPT item type ID
          itemInstanceId: item['itemInstanceId'] ?? 0,
          assetAuditSiteRespId: item['assetAuditSiteRespId'] ?? 0,
          nexgenSerialNo: item['serialNumber'] ?? '',
          photoId: item['photoId'],
          assetStatus: item['assetStatus'] ?? 'OK',
          remarks: item['remarks'] ?? '',
          qrCodeScanned: item['isQRCodeScanned'] ?? false,
          qrCodeScannedTs: item['qrCodeScannedTs'],
          photoTakenTs: item['photoTakenTs'] ?? DateTime.now().toIso8601String(),
          longitude: item['longitude'],
          latitude: item['latitude'],
          localAuditLogId: DateTime.now().millisecondsSinceEpoch,
          localQrCodeScannedTs: DateTime.now().toIso8601String(),
          localCreatedDt: DateTime.now().toIso8601String(),
          localModifiedDt: DateTime.now().toIso8601String(),
          syncProcessId: 0,
          isActive: true,
        ));
      }

      // Process ACDB items
      for (var item in savedACDBItems) {
        requests.add(AssetAuditPostRequest(
          siteAuditSchId: int.tryParse(widget.siteAuditSchId ?? '0') ?? 0,
          auditSchId: int.tryParse(widget.auditSchId ?? '0') ?? 0,
          siteId: 0,
          itemTypeId: 4, // ACDB item type ID
          itemInstanceId: item['itemInstanceId'] ?? 0,
          assetAuditSiteRespId: item['assetAuditSiteRespId'] ?? 0,
          nexgenSerialNo: item['serialNumber'] ?? '',
          photoId: item['photoId'],
          assetStatus: item['assetStatus'] ?? 'OK',
          remarks: item['remarks'] ?? '',
          qrCodeScanned: item['isQRCodeScanned'] ?? false,
          qrCodeScannedTs: item['qrCodeScannedTs'],
          photoTakenTs: item['photoTakenTs'] ?? DateTime.now().toIso8601String(),
          longitude: item['longitude'],
          latitude: item['latitude'],
          localAuditLogId: DateTime.now().millisecondsSinceEpoch,
          localQrCodeScannedTs: DateTime.now().toIso8601String(),
          localCreatedDt: DateTime.now().toIso8601String(),
          localModifiedDt: DateTime.now().toIso8601String(),
          syncProcessId: 0,
          isActive: true,
        ));
      }

      // Process LSPU items
      for (var item in savedLSPUItems) {
        requests.add(AssetAuditPostRequest(
          siteAuditSchId: int.tryParse(widget.siteAuditSchId ?? '0') ?? 0,
          auditSchId: int.tryParse(widget.auditSchId ?? '0') ?? 0,
          siteId: 0,
          itemTypeId: 5, // LSPU item type ID
          itemInstanceId: item['itemInstanceId'] ?? 0,
          assetAuditSiteRespId: item['assetAuditSiteRespId'] ?? 0,
          nexgenSerialNo: item['serialNumber'] ?? '',
          photoId: item['photoId'],
          assetStatus: item['assetStatus'] ?? 'OK',
          remarks: item['remarks'] ?? '',
          qrCodeScanned: item['isQRCodeScanned'] ?? false,
          qrCodeScannedTs: item['qrCodeScannedTs'],
          photoTakenTs: item['photoTakenTs'] ?? DateTime.now().toIso8601String(),
          longitude: item['longitude'],
          latitude: item['latitude'],
          localAuditLogId: DateTime.now().millisecondsSinceEpoch,
          localQrCodeScannedTs: DateTime.now().toIso8601String(),
          localCreatedDt: DateTime.now().toIso8601String(),
          localModifiedDt: DateTime.now().toIso8601String(),
          syncProcessId: 0,
          isActive: true,
        ));
      }

      // Add general remarks if available
      if (generalRemarksController.text.isNotEmpty) {
        requests.add(AssetAuditPostRequest(
          siteAuditSchId: int.tryParse(widget.siteAuditSchId ?? '0') ?? 0,
          auditSchId: int.tryParse(widget.auditSchId ?? '0') ?? 0,
          siteId: 0,
          itemTypeId: 1, // SMPS item type ID
          itemInstanceId: 0,
          assetAuditSiteRespId: 0,
          nexgenSerialNo: 'REMARKS',
          photoId: null,
          assetStatus: 'OK',
          remarks: generalRemarksController.text,
          qrCodeScanned: false,
          qrCodeScannedTs: null,
          photoTakenTs: DateTime.now().toIso8601String(),
          longitude: null,
          latitude: null,
          localAuditLogId: DateTime.now().millisecondsSinceEpoch,
          localQrCodeScannedTs: DateTime.now().toIso8601String(),
          localCreatedDt: DateTime.now().toIso8601String(),
          localModifiedDt: DateTime.now().toIso8601String(),
          syncProcessId: 0,
          isActive: true,
        ));
      }

      if (requests.isNotEmpty) {
        print('SMPS Screen: Posting ${requests.length} items to API...');
        context.read<AssetAuditCubit>().postAssetAuditData(requests: requests);
      }
    } catch (e) {
      print('SMPS Screen: Error posting data: $e');
    }
  }

  /// Save and exit
  Future<void> _saveAndExit() async {
    await _postCurrentScreenData();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => HomeScreen()),
    );
  }

  /// Get SMPS OEM name from backend data
  String _getSMPSOEMName() {
    if (widget.smpsData != null && widget.smpsData!.assets.isNotEmpty) {
      return widget.smpsData!.assets.first.oemName ?? 'N/A';
    }
    return 'N/A';
  }

  /// Get Rectifier serial number from backend data
  String _getRectifierSerialNumber() {
    if (widget.smpsData != null && widget.smpsData!.assets.isNotEmpty) {
      return widget.smpsData!.assets.first.nexgenSerialNo ?? '';
    }
    return '';
  }

  /// Get MPPT serial number from backend data
  String _getMPPTSerialNumber() {
    if (widget.smpsData != null && widget.smpsData!.assets.isNotEmpty) {
      return widget.smpsData!.assets.first.nexgenSerialNo ?? '';
    }
    return '';
  }

  /// Get ACDB serial number from backend data
  String _getACDBSerialNumber() {
    if (widget.smpsData != null && widget.smpsData!.assets.isNotEmpty) {
      return widget.smpsData!.assets.first.nexgenSerialNo ?? '';
    }
    return '';
  }

  /// Get LSPU serial number from backend data
  String _getLSPUSerialNumber() {
    if (widget.smpsData != null && widget.smpsData!.assets.isNotEmpty) {
      return widget.smpsData!.assets.first.nexgenSerialNo ?? '';
    }
    return '';
  }

  /// Get total count of items for display
  int get totalRectifierItems => savedRectifierItems.length;
  int get totalMPPTItems => savedMPPTItems.length;
  int get totalACDBItems => savedACDBItems.length;
  int get totalLSPUItems => savedLSPUItems.length;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_hasChanges,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        resizeToAvoidBottomInset: false,
        appBar: CustomFormAppbar(
          title: "Asset Audit",
          onClose: () async {
            if (_hasChanges) {
              showDialog(
                context: context,
                barrierDismissible: true,
                builder: (dialogContext) => UnsavedChangesDialog(
                  siteAuditSchId: widget.siteAuditSchId,
                  section: "Asset Audit",
                  parentContext: context,
                  onSaveAndExit: () async {
                    await _saveAndExit();
                  },
                  onDiscard: () {
                    // Dialog will be closed automatically
                  },
                ),
              );
            } else {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => HomeScreen()),
              );
            }
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
                        bottom: MediaQuery.of(context).viewInsets.bottom + 120,
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
                            // SMPS Make field
                            CustomFormField(
                              label: "SMPS Make",
                              initialValue: _getSMPSOEMName(),
                              isRequired: false,
                              isEditable: false,
                            ),
                            getHeight(15),
                            
                            // Count of SMPS field
                            CustomFormField(
                              label: "Count of SMPS",
                              initialValue: totalRectifierItems.toString(),
                              isRequired: false,
                              isEditable: false,
                            ),
                            getHeight(15),
                            
                            // Rectifier form component
                            AssetAuditFormComponent(
                              componentId: 'rectifier',
                              serialLabel: "Cabinet Serial Number",
                              serialHintText: "Enter Cabinet Serial Number",
                              photoLabel: "Add Photo of Cabinet",
                              serialController: rectifierSerialController,
                              disabledFieldLabel: "Cabinet Serial Number",
                              disabledFieldValue: _getRectifierSerialNumber(),
                              initialSavedItems: savedRectifierItems,
                              onStatusChanged: (status) {
                                // Handle status change if needed
                              },
                              siteAuditSchId: widget.siteAuditSchId ?? '0',
                            ),
                            getHeight(15),
                            
                            // Count of Rectifiers field
                            CustomFormField(
                              label: "Count of Rectifiers",
                              initialValue: totalMPPTItems.toString(),
                              isRequired: false,
                              isEditable: false,
                            ),
                            getHeight(15),
                            
                            // MPPT form component
                            AssetAuditFormComponent(
                              componentId: 'mppt',
                              serialLabel: "Rectifier - Serial Number",
                              serialHintText: "Enter Rectifier Serial Number",
                              photoLabel: "Add Photo of Rectifier",
                              serialController: mpptSerialController,
                              disabledFieldLabel: "Rectifier - Serial Number",
                              disabledFieldValue: _getMPPTSerialNumber(),
                              initialSavedItems: savedMPPTItems,
                              onStatusChanged: (status) {
                                // Handle status change if needed
                              },
                              siteAuditSchId: widget.siteAuditSchId ?? '0',
                            ),
                            getHeight(15),
                            
                            // ACDB form component
                            AssetAuditFormComponent(
                              componentId: 'acdb',
                              serialLabel: "ACDB",
                              serialHintText: "Enter ACDB Serial Number",
                              photoLabel: "Add Photo of ACDB",
                              serialController: acdbSerialController,
                              disabledFieldLabel: "ACDB",
                              disabledFieldValue: _getACDBSerialNumber(),
                              initialSavedItems: savedACDBItems,
                              onStatusChanged: (status) {
                                // Handle status change if needed
                              },
                              siteAuditSchId: widget.siteAuditSchId ?? '0',
                            ),
                            getHeight(15),
                            
                            // LSPU form component
                            AssetAuditFormComponent(
                              componentId: 'lspu',
                              serialLabel: "LSPU",
                              serialHintText: "Enter LSPU Serial Number",
                              photoLabel: "Add Photo of LSPU",
                              serialController: lspuSerialController,
                              disabledFieldLabel: "LSPU",
                              disabledFieldValue: _getLSPUSerialNumber(),
                              initialSavedItems: savedLSPUItems,
                              onStatusChanged: (status) {
                                // Handle status change if needed
                              },
                              siteAuditSchId: widget.siteAuditSchId ?? '0',
                            ),
                            getHeight(15),
                            
                            // General remarks field
                            CustomRemarksField(
                              label: "Add Remarks",
                              hintText: "Remarks",
                              controller: generalRemarksController,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  
                  // Navigation buttons
                  Container(
                    padding: const EdgeInsets.all(16),
                    width: double.infinity,
                    child: Row(
                      children: [
                        Expanded(
                          child: ArrowButton(
                            text: _getPreviousAvailableScreen() ?? "BACK",
                            isLeftArrow: true,
                            backgroundColor: AppColors.buttonColorBg,
                            textColor: AppColors.buttonColorSite,
                            onPressed: () {
                              final previousScreen = _getPreviousAvailableScreen();
                              if (previousScreen != null) {
                                _navigateToNextScreen(context, previousScreen);
                              } else {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(builder: (context) => HomeScreen()),
                                );
                              }
                            },
                          ),
                        ),
                        getWidth(8),
                        Expanded(
                          child: ArrowButton(
                            text: _getNextAvailableScreen() ?? "SUBMIT",
                            isLeftArrow: false,
                            backgroundColor: AppColors.buttonColorBackBg,
                            textColor: AppColors.buttonColorTextBg,
                            onPressed: () async {
                              await _postCurrentScreenData();
                              _navigateToNextScreen(context, _getNextAvailableScreen());
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
