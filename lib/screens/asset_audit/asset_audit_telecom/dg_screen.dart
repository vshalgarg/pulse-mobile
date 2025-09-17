import 'dart:async';
import 'dart:io';
import 'dart:convert';

import 'package:app/commonWidgets/custom_buttons/arrow_botton.dart';
import 'package:app/constants/constants_methods.dart';
import 'package:app/screens/asset_audit/asset_audit_telecom/smps_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';
import '../../../constants/constants_strings.dart';
import '../../../models/asset_audit_model.dart';
import '../../../models/asset_audit_post_model.dart';
import '../../../utils/asset_audit_post_helper.dart';
import '../../../utils/asset_audit_photo_upload_helper.dart';
import '../../../utils/asset_audit_navigation_helper.dart';
import '../../../bloc/asset_audit_cubit.dart';
import '../../../bloc/asset_audit_state.dart';
import '../../../bloc/asset_audit_get_image_cubit.dart';
import '../../../bloc/audit_schedule_status_cubit.dart';
import '../../../repositories/image_repository.dart';
import '../../../app_config.dart';

import '../../../commonWidgets/asset_type_card.dart';
import '../../../commonWidgets/asset_audit_form_component.dart';
import '../../../commonWidgets/custom_dialogs/success_dialog.dart';
import '../../../commonWidgets/custom_dialogs/unsaved_changes_dialog.dart';
import '../../../commonWidgets/custom_form_appbar.dart';
import '../../../commonWidgets/custom_form_field.dart';
import '../../../commonWidgets/custom_image_upload_field.dart';
import '../../../commonWidgets/custom_radio_options.dart';
import '../../../commonWidgets/custom_remark.dart';
import '../../../commonWidgets/base64_image_widget.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_images.dart';
import '../../home_screen.dart';

class DgScreen extends StatefulWidget {
  final CategoryData? dgData;
  final AssetAuditModel? assetAuditData;
  final bool showSuccessMessage; // Flag to show success message
  final String? siteType;
  final String? auditSchId;
  final String? siteAuditSchId;

  // Data from previous screens in the flow
  final List<Map<String, dynamic>>? extinguisherItems;
  final List<Map<String, dynamic>>? solarPlatesItems;
  final List<Map<String, dynamic>>? surveillanceItems;
  final List<Map<String, dynamic>>? fencingItems;

  const DgScreen({
    super.key,
    this.dgData,
    this.assetAuditData,
    this.showSuccessMessage = false, // Default to false
    this.siteType,
    this.auditSchId,
    this.siteAuditSchId,
    this.extinguisherItems,
    this.solarPlatesItems,
    this.surveillanceItems,
    this.fencingItems,
  });

  @override
  State<DgScreen> createState() => _DgScreenState();
}

class _DgScreenState extends State<DgScreen> {
  final TextEditingController dgSerialController = TextEditingController();
  final TextEditingController generalRemarksController = TextEditingController();
  List<Map<String, dynamic>> savedDGItems = [];

  // Additional DG-specific fields
  String? selectedDGAvailability;
  String? uploadedPhotoPath;
  int? dgPhotoId; // Store the photoId from API for DG
  int? dgMakePhotoId; // Store the photoId from API for DG Make
  int totalDGItems = 6;

  late ImageRepository _imageService;
  Map<int, String> _imageCache = {};
  Set<int> _loadingImages = {};

  /// Validate DG serial number against API data
  bool _validateDGSerialNumber(String serialNumber, bool isQRCodeScanned) {
    if (widget.dgData == null) return false;

    if (isQRCodeScanned) {
      // For QR code scans, validate against nexgen_serial_no
      final allItems = widget.dgData!.assets ?? [];
      return allItems.any(
        (item) =>
            item.nexgenSerialNo?.toLowerCase() == serialNumber.toLowerCase(),
      );
    } else {
      // For manual entries, validate against mfg_serial_no
      final allItems = widget.dgData!.assets ?? [];
      return allItems.any(
        (item) => item.mfgSerialNo?.toLowerCase() == serialNumber.toLowerCase(),
      );
    }
  }

  /// Callback when DG item is saved from AssetAuditFormComponent
  void _onDGItemSaved(List<Map<String, dynamic>> items) {
    setState(() {
      savedDGItems = items;
    });
  }

  /// Check if there are unsaved changes
  bool get _hasChanges {
    return dgSerialController.text.isNotEmpty || 
           generalRemarksController.text.isNotEmpty ||
           savedDGItems.isNotEmpty;
  }

  /// Check if string is numeric
  bool _isNumeric(String str) {
    return int.tryParse(str) != null;
  }

  String _getDGOEMName() {
    if (widget.dgData != null) {
      // Try to get OEM name from DG assets
      final dgAssets = widget.dgData!.assets;
      if (dgAssets.isNotEmpty) {
        return dgAssets.first.oemName ?? 'Eicher';
      }
    }
    return 'Eicher'; // Default fallback
  }

  /// Check if there is data to show on the screen
  bool _hasDataToShow() {
    if (widget.dgData == null) {
      print('DG Screen: No DG data available');
      return false;
    }

    // Check if we have any assets
    final hasAssets = widget.dgData!.assets.isNotEmpty;

    // Check if we have any subcategories with data
    final hasSubCategories =
        widget.dgData!.subCategories != null &&
        widget.dgData!.subCategories!.values.any((items) => items.isNotEmpty);

    // Check if we have any remarks
    final hasRemarks = widget.dgData!.remarks.isNotEmpty;

    final hasData = hasAssets || hasSubCategories || hasRemarks;

    print('DG Screen: Data availability check:');
    print('  - Assets: $hasAssets (${widget.dgData!.assets.length})');
    print('  - Subcategories: $hasSubCategories');
    print('  - Remarks: $hasRemarks (${widget.dgData!.remarks.length})');
    print('  - Has data to show: $hasData');

    return hasData;
  }

  /// Navigate to next screen dynamically
  void _navigateToNextScreen(BuildContext context, String? nextScreen) {
    if (nextScreen == null) {
      // No next screen available, go to home
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => HomeScreen()),
      );
      return;
    }

    // Navigate to the next screen using AssetAuditNavigationHelper
    AssetAuditNavigationHelper.navigateToNextTelecomScreenDeprecated(
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
      'DG'
    );
  }

  /// Get previous available screen
  String? _getPreviousAvailableScreen() {
    return AssetAuditNavigationHelper.getPreviousAvailableTelecomScreen(
      widget.assetAuditData, 
      'DG'
    );
  }

  /// Get asset audit site response ID from GET API response for a specific item type
  int _getAssetAuditSiteRespId(String itemType) {
    print('=== DG Screen: Getting AssetAuditSiteRespId for $itemType ===');

    if (widget.dgData == null) {
      print('DG Screen: dgData is null, returning default ID');
      return 0; // Default ID
    }

    print('DG Screen: dgData is not null, searching for $itemType...');

    // First check in assets
    final dgAssets = widget.dgData!.assets ?? [];
    if (dgAssets.isNotEmpty) {
      print(
        'DG Screen: Found ${dgAssets.length} assets in CategoryData.assets',
      );
      for (var asset in dgAssets) {
        print(
          'DG Screen: Asset: ${asset.itemType} - ID: ${asset.assetAuditSiteRespId}',
        );
        if (asset.assetAuditSiteRespId != null &&
            asset.assetAuditSiteRespId! > 0) {
          return asset.assetAuditSiteRespId!;
        }
      }
    } else {
      print('DG Screen: No assets found in CategoryData.assets');
    }

    // If not found in assets, check subcategories
    if (widget.dgData!.subCategories != null) {
      print('DG Screen: Checking subcategories for $itemType...');
      for (var entry in widget.dgData!.subCategories!.entries) {
        String key = entry.key;
        List<AssetItem> items = entry.value;
        print('DG Screen: Subcategory $key: ${items.length} items');
        for (var item in items) {
          print(
            'DG Screen: Item in $key: ${item.itemType} - ID: ${item.assetAuditSiteRespId}',
          );
          if (item.assetAuditSiteRespId != null &&
              item.assetAuditSiteRespId! > 0) {
            print(
              'DG Screen: Found valid assetAuditSiteRespId in subcategory: ${item.assetAuditSiteRespId}',
            );
            return item.assetAuditSiteRespId!;
          }
        }
      }
    } else {
      print('DG Screen: No subcategories found');
    }

    // If still not found, check remarks
    final remarks = widget.dgData!.remarks;
    if (remarks.isNotEmpty) {
      print('DG Screen: Checking remarks for valid ID...');
      for (var remark in remarks) {
        print(
          'DG Screen: Remark: ${remark.itemType} - ID: ${remark.assetAuditSiteRespId}',
        );
        if (remark.assetAuditSiteRespId != null &&
            remark.assetAuditSiteRespId! > 0) {
          print(
            'DG Screen: Found valid assetAuditSiteRespId in remarks: ${remark.assetAuditSiteRespId}',
          );
          return remark.assetAuditSiteRespId!;
        }
      }
    } else {
      print('DG Screen: No remarks found');
    }

    print(
      'DG Screen: No valid assetAuditSiteRespId found, returning default ID',
    );
    return 0; // Default ID
  }

  @override
  void initState() {
    super.initState();
    _loadDGData();
    // Initialize image service
    _imageService = ImageRepository(AppConfig.of(context).apiProvider);
  }

  void _loadDGData() {
    if (widget.dgData != null) {
      setState(() {
        print('=== DG Screen: Loading DG Data ===');

        // Load DG assets data
        final dgAssets = widget.dgData!.assets;
        if (dgAssets.isNotEmpty) {
          print('DG Screen: Found ${dgAssets.length} DG assets');
          totalDGItems = dgAssets.length;
        } else {
          print('DG Screen: No DG assets found');
        }

        // Load remarks and populate the CustomRemarksField
        final remarks = widget.dgData!.remarks;
        if (remarks.isNotEmpty) {
          print('DG Screen: Found ${remarks.length} DG remarks');
          // Process remarks and populate the CustomRemarksField
          for (int i = 0; i < remarks.length; i++) {
            var remark = remarks[i];
            print('DG Screen: Remark $i:');
            print('  - itemType: ${remark.itemType}');
            print('  - recordType: ${remark.recordType}');
            print('  - assetAuditSiteRespId: ${remark.assetAuditSiteRespId}');

            // Populate the CustomRemarksField with the first valid remark
            if (remark.itemTypeRemark != null &&
                remark.itemTypeRemark!.isNotEmpty) {
              generalRemarksController.text = remark.itemTypeRemark!;
              print(
                'DG Screen: Loaded remark from API: ${remark.itemTypeRemark}',
              );
              break; // Use the first valid remark
            }
          }
        } else {
          print('DG Screen: No DG remarks found');
        }

        print('=== DG Screen: Data Summary ===');
        print('Total expected items: $totalDGItems');
        print('Total remarks: ${remarks.length}');
        print('==========================================');
      });
    } else {
      print('DG Screen: No dgData available');
    }
  }






  @override
  void dispose() {
    dgSerialController.dispose();
    generalRemarksController.dispose();
    super.dispose();
  }







  /// Post current screen data to API
  Future<void> _postCurrentScreenData() async {
    if (widget.assetAuditData == null) {
      print('DG Screen: No asset audit data available for posting');
      return;
    }

    try {
      // Convert saved DG items to AssetAuditPostRequest objects
      List<AssetAuditPostRequest> requests = [];
      
      for (var item in savedDGItems) {
        requests.add(AssetAuditPostRequest(
          siteAuditSchId: int.tryParse(widget.siteAuditSchId ?? '0') ?? 0,
          auditSchId: int.tryParse(widget.auditSchId ?? '0') ?? 0,
          siteId: 0, // Add required siteId
          itemTypeId: 1, // DG item type ID
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
          siteId: 0, // Add required siteId
          itemTypeId: 1, // DG item type ID
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
        print('DG Screen: Posting ${requests.length} items to API...');
        context.read<AssetAuditCubit>().postAssetAuditData(requests: requests);
      }
    } catch (e) {
      print('DG Screen: Error posting data: $e');
    }
  }

  /// Save and exit
  Future<void> _saveAndExit() async {
    await _postCurrentScreenData();
  }


  @override
  Widget build(BuildContext context) {
    return BlocListener<AssetAuditCubit, AssetAuditState>(
      listener: (context, state) {
      },
      child: PopScope(
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
                              if (_hasDataToShow()) ...[
                                // DG Availability
                                CustomOptionSelector(
                                  label: "DG Availability *",
                                  isRequired: true,
                                  options: [
                                    OptionItem(
                                      value: "yes",
                                      label: "Yes",
                                      selectedIcon: Icons.check_circle,
                                      unselectedIcon: Icons.circle_outlined,
                                    ),
                                    OptionItem(
                                      value: "no",
                                      label: "No",
                                      selectedIcon: Icons.cancel,
                                      unselectedIcon: Icons.circle_outlined,
                                    ),
                                  ],
                                  onChanged: (value) {
                                    setState(() {
                                      selectedDGAvailability = value;
                                    });
                                  },
                                ),
                                getHeight(15),
                                
                                // DG Photo
                                ImageUploadField(
                                  label: "Add Photo of DG",
                                  placeholder: "Add Photo",
                                  isRequired: true,
                                  onImageSelected: (file) async {
                                    if (file != null) {
                                      setState(() {
                                        uploadedPhotoPath = file.path;
                                      });
                                      
                                      try {
                                        final photoFile = File(file.path);
                                        if (await photoFile.exists()) {
                                          final photoId = await AssetAuditPhotoUploadHelper.uploadPhotoAndGetId(
                                            photoFile: photoFile,
                                            schId: widget.siteAuditSchId ?? "0",
                                            imgId: null,
                                            context: context,
                                          );
                                          
                                          if (photoId != null) {
                                            setState(() {
                                              dgPhotoId = photoId;
                                            });
                                          }
                                        }
                                      } catch (e) {
                                        print('DG Screen: Error uploading DG photo: $e');
                                      }
                                    } else {
                                      setState(() {
                                        uploadedPhotoPath = null;
                                        dgPhotoId = null;
                                      });
                                    }
                                  },
                                ),
                                getHeight(15),
                                
                                // DG Make
                                CustomFormField(
                                  label: "DG Make",
                                  initialValue: _getDGOEMName(),
                                  isRequired: false,
                                  isEditable: false,
                                ),
                                getHeight(15),
                                
                                // DG Make Photo
                                ImageUploadField(
                                  label: "Add Photo of DG Make",
                                  placeholder: "Add Photo",
                                  isRequired: true,
                                  onImageSelected: (file) async {
                                    if (file != null) {
                                      setState(() {
                                        uploadedPhotoPath = file.path;
                                      });
                                      
                                      try {
                                        final photoFile = File(file.path);
                                        if (await photoFile.exists()) {
                                          final photoId = await AssetAuditPhotoUploadHelper.uploadPhotoAndGetId(
                                            photoFile: photoFile,
                                            schId: widget.siteAuditSchId ?? "0",
                                            imgId: null,
                                            context: context,
                                          );
                                          
                                          if (photoId != null) {
                                            setState(() {
                                              dgMakePhotoId = photoId;
                                            });
                                          }
                                        }
                                      } catch (e) {
                                        print('DG Screen: Error uploading DG Make photo: $e');
                                      }
                                    } else {
                                      setState(() {
                                        uploadedPhotoPath = null;
                                        dgMakePhotoId = null;
                                      });
                                    }
                                  },
                                ),
                                getHeight(15),
                                
                                // Count of DG Set
                                CustomFormField(
                                  label: "Count of DG Set",
                                  initialValue: totalDGItems.toString(),
                                  isRequired: false,
                                  isEditable: false,
                                ),
                                getHeight(15),
                                
                                // AssetAuditFormComponent for DG items
                                AssetAuditFormComponent(
                                  componentId: 'dg_form',
                                  serialLabel: "DG - Serial Number *",
                                  serialHintText: "DG Serial Number",
                                  photoLabel: "Add a Photo",
                                  disabledFieldLabel: "Capacity",
                                  disabledFieldValue: "Eg: 25KVA",
                                  serialController: dgSerialController,
                                  initialSavedItems: savedDGItems,
                                  onItemSaved: _onDGItemSaved,
                                  onStatusChanged: (status) {
                                    // Handle status change if needed
                                  },
                                  customValidator: _validateDGSerialNumber,
                                  siteAuditSchId: widget.siteAuditSchId ?? '',
                                ),
                                getHeight(15),
                                
                                // General Remarks
                                CustomRemarksField(
                                  label: "Add Remarks",
                                  hintText: "Remarks",
                                  controller: generalRemarksController,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                    
                    // Navigation Buttons
                    Container(
                      padding: const EdgeInsets.all(16),
                      width: double.infinity,
                      child: Row(
                        children: [
                          Expanded(
                            child: ArrowButton(
                              text: _getPreviousAvailableScreen() ?? "BACK",
                              isLeftArrow: true,
                              backgroundColor: _getPreviousAvailableScreen() != null 
                                  ? AppColors.buttonColorBackBg 
                                  : AppColors.greyColor,
                              textColor: _getPreviousAvailableScreen() != null 
                                  ? AppColors.buttonColorTextBg 
                                  : AppColors.white,
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
                          getWidth(14),
                          Expanded(
                            child: ArrowButton(
                              text: _getNextAvailableScreen() ?? "SUBMIT",
                              isLeftArrow: false,
                              backgroundColor: _getNextAvailableScreen() != null 
                                  ? AppColors.buttonColorBg 
                                  : AppColors.green7,
                              textColor: _getNextAvailableScreen() != null 
                                  ? AppColors.buttonColorSite 
                                  : AppColors.white,
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
              
              // Loading indicator
              BlocBuilder<AssetAuditCubit, AssetAuditState>(
                builder: (context, state) {
                  if (state is AssetAuditPosting) {
                    return Container(
                      color: Colors.black.withOpacity(0.5),
                      child: const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

}
