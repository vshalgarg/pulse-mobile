import 'package:app/commonWidgets/custom_buttons/arrow_botton.dart';
import 'package:app/constants/constants_methods.dart';
import 'package:app/screens/asset_audit/asset_audit_telecom/dg_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';
import '../../../bloc/asset_audit_photo_upload_cubit.dart';
import '../../../models/asset_audit_model.dart';
import '../../../utils/asset_audit_post_helper.dart';
import '../../../utils/asset_audit_photo_upload_helper.dart';
import '../../../bloc/asset_audit_cubit.dart';
import '../../../bloc/asset_audit_state.dart';
import '../../../bloc/asset_audit_get_image_cubit.dart';
import '../../../bloc/audit_schedule_status_cubit.dart';
import 'dart:async';
import 'dart:io';
import 'dart:convert';

import '../../../commonWidgets/asset_type_card.dart';
import '../../../commonWidgets/custom_dialogs/success_dialog.dart';
import '../../../commonWidgets/custom_dialogs/unsaved_changes_dialog.dart';
import '../../../commonWidgets/custom_form_appbar.dart';
import '../../../commonWidgets/custom_radio_options.dart';
import '../../../commonWidgets/custom_remark.dart';
import '../../../commonWidgets/asset_audit_form_component.dart';
import '../../../models/asset_audit_post_model.dart';
import '../../../utils/asset_audit_navigation_helper.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_images.dart';
import '../../../constants/constants_strings.dart';
import '../../home_screen.dart';

class FencingScreen extends StatefulWidget {
  final CategoryData? fencingData;
  final AssetAuditModel? assetAuditData;
  final bool showSuccessMessage;

  final List<Map<String, dynamic>>? extinguisherItems;
  final List<Map<String, dynamic>>? solarPlatesItems;
  final List<Map<String, dynamic>>? surveillanceItems;

  // Navigation parameters
  final String? siteType;
  final String? auditSchId;
  final String? siteAuditSchId;

  const FencingScreen({
    super.key,
    this.fencingData,
    this.assetAuditData,
    this.showSuccessMessage = false,
    this.extinguisherItems,
    this.solarPlatesItems,
    this.surveillanceItems,
    this.siteType,
    this.auditSchId,
    this.siteAuditSchId,
  });

  @override
  State<FencingScreen> createState() => _FencingScreenState();
}

class _FencingScreenState extends State<FencingScreen>
    with WidgetsBindingObserver {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController generalRemarksController = TextEditingController();
  
  // Controllers for AssetAuditFormComponent
  final TextEditingController fencingSerialController = TextEditingController();
  
  // Saved items lists
  List<Map<String, dynamic>> savedFencingItems = [];
  
  // Validation methods
  bool _validateFencingSerialNumber(String serialNumber, bool isQRCodeScanned) {
    if (widget.fencingData == null) return false;
    
    final allItems = widget.fencingData!.assets ?? [];
    return allItems.any((item) => 
      item.mfgSerialNo?.toLowerCase() == serialNumber.toLowerCase() ||
      item.nexgenSerialNo?.toLowerCase() == serialNumber.toLowerCase()
    );
  }
  
  // Callback methods for AssetAuditFormComponent
  void _onFencingItemSaved(List<Map<String, dynamic>> items) {
    setState(() {
      savedFencingItems.addAll(items);
    });
  }
  
  // Check if there are unsaved changes
  bool get _hasChanges {
    return generalRemarksController.text.isNotEmpty || savedFencingItems.isNotEmpty;
  }

  @override
  void initState() {
    super.initState();
    
    // Load remarks if available
    if (widget.fencingData?.remarks.isNotEmpty == true) {
      final remarks = widget.fencingData!.remarks;
      for (var remark in remarks) {
        if (remark.itemTypeRemark != null && remark.itemTypeRemark!.isNotEmpty) {
          generalRemarksController.text = remark.itemTypeRemark!;
          break;
        }
      }
    }
    
    // Check if we have data to show, if not, skip this screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_hasDataToShow()) {
        _navigateToDgScreen();
      }
    });
  }
  
  // Navigation methods
  void _navigateToNextScreen(BuildContext context, String? nextScreen) {
    if (nextScreen != null) {
      AssetAuditNavigationHelper.navigateToNextTelecomScreenDeprecated(
        context,
        nextScreen,
        widget.siteType ?? '',
        widget.auditSchId ?? '',
        widget.siteAuditSchId ?? '',
        widget.assetAuditData,
      );
    } else {
      // No next screen available, go to home
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => HomeScreen()),
      );
    }
  }

  // Helper method to get the next available screen based on data availability
  String? _getNextAvailableScreen() {
    return AssetAuditNavigationHelper.getNextAvailableTelecomScreen(widget.assetAuditData, 'Fencing');
  }

  // Helper method to get the previous available screen based on data availability
  String? _getPreviousAvailableScreen() {
    return AssetAuditNavigationHelper.getPreviousAvailableTelecomScreen(widget.assetAuditData, 'Fencing');
  }
  
  // Post current screen data to API
  Future<bool> _postCurrentScreenData() async {
    if (widget.assetAuditData == null) {
      print('Fencing Screen: No asset audit data available for posting');
      return false;
    }

    try {
      // Convert saved items to POST request format
      final requests = await AssetAuditPostHelper.convertSavedItemsToPostRequest(
        savedItems: savedFencingItems,
        assetAuditData: widget.assetAuditData!,
        itemType: 'Fencing',
        itemTypeId: AssetAuditPostHelper.getItemTypeId('Fencing'),
        screenName: 'Fencing',
        context: context,
      );

      if (requests.isEmpty) {
        print('Fencing Screen: No items to post');
        return false;
      }

      // Add remarks if available
      if (generalRemarksController.text.isNotEmpty) {
        final remarksRequest = AssetAuditPostRequest(
          assetAuditSiteRespId: widget.fencingData?.assets.isNotEmpty == true 
              ? widget.fencingData!.assets.first.assetAuditSiteRespId ?? 0
              : 0,
          auditSchId: int.tryParse(widget.auditSchId ?? '0') ?? 0,
          siteAuditSchId: int.tryParse(widget.siteAuditSchId ?? '0') ?? 0,
          siteId: widget.assetAuditData?.pageHeader.first.siteId ?? 0,
          itemInstanceId: 0,
          nexgenSerialNo: 'REMARKS',
          itemTypeId: AssetAuditPostHelper.getItemTypeId('Fencing'),
          qrCodeScanned: false,
          qrCodeScannedTs: null,
          photoId: null,
          photoTakenTs: DateTime.now().toString(),
          assetStatus: 'OK',
          longitude: '37.4219983',
          latitude: '-122.084',
          itemTypeRemark: generalRemarksController.text,
          localAuditLogId: DateTime.now().millisecondsSinceEpoch,
          localQrCodeScannedTs: DateTime.now().toString(),
          localCreatedDt: DateTime.now().toString(),
          localModifiedDt: DateTime.now().toString(),
          syncProcessId: DateTime.now().millisecondsSinceEpoch,
          isActive: true,
          remarks: generalRemarksController.text,
        );
        requests.add(remarksRequest);
      }

      // Post data using the cubit
      context.read<AssetAuditCubit>().postAssetAuditData(requests: requests);
      return true;
    } catch (e) {
      print('Fencing Screen: Error preparing data: $e');
      return false;
    }
  }
  
  Future<void> _saveAndExit() async {
    try {
      await _postCurrentScreenData();
    } catch (e) {
      print('Error posting Fencing data: $e');
    }
  }

  @override
  void dispose() {
    fencingSerialController.dispose();
    generalRemarksController.dispose();
    super.dispose();
  }

  /// Check if there is data to show on the screen
  bool _hasDataToShow() {
    if (widget.fencingData == null) {
      print('Fencing Screen: fencingData is null');
      return false;
    }

    print('Fencing Screen: _hasDataToShow() called');
    print('  - fencingData type: ${widget.fencingData.runtimeType}');
    print('  - fencingData: ${widget.fencingData}');

    // Check if we have any assets
    final hasAssets = widget.fencingData!.assets.isNotEmpty;
    print('  - assets count: ${widget.fencingData!.assets.length}');
    print('  - hasAssets: $hasAssets');

    // Check if we have any subcategories with data
    final hasSubCategories =
        widget.fencingData!.subCategories != null &&
        widget.fencingData!.subCategories!.values.any(
          (items) => items.isNotEmpty,
        );
    print('  - subCategories: ${widget.fencingData!.subCategories}');
    print('  - hasSubCategories: $hasSubCategories');

    // Specifically check for Boundary data in subCategories
    final hasBoundaryData =
        widget.fencingData!.subCategories?['Boundary']?.isNotEmpty ?? false;
    print('  - hasBoundaryData: $hasBoundaryData');
    print(
      '  - boundary count: ${widget.fencingData!.subCategories?['Boundary']?.length ?? 0}',
    );

    final hasData = hasAssets || hasSubCategories || hasBoundaryData;
    print('  - Has data to show: $hasData');

    return hasData;
  }

  void _navigateToDgScreen() {
    print('Fencing Screen: Navigating to DG screen');
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => DgScreen(
          dgData: widget.assetAuditData?.responseData.dg,
          assetAuditData: widget.assetAuditData,
          showSuccessMessage: false,
          extinguisherItems: widget.extinguisherItems ?? [],
          solarPlatesItems: widget.solarPlatesItems ?? [],
          surveillanceItems: widget.surveillanceItems ?? [],
          fencingItems: [],
        ),
      ),
    );
  }





  @override
  Widget build(BuildContext context) {
    return BlocListener<AssetAuditCubit, AssetAuditState>(
      listener: (context, state) {
        if (state is AssetAuditPostSuccess) {
          final nextScreen = _getNextAvailableScreen();
          _navigateToNextScreen(context, nextScreen);
        }
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
                child: Form(
                  key: _formKey,
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
                                // Fencing Form Component
                                AssetAuditFormComponent(
                                  componentId: 'fencing',
                                  serialLabel: "Fencing - Serial Number *",
                                  serialHintText: "Fencing Serial Number",
                                  photoLabel: "Add a Photo",
                                  disabledFieldLabel: "Type",
                                  disabledFieldValue: "Fencing/Boundary",
                                  serialController: fencingSerialController,
                                  initialSavedItems: savedFencingItems,
                                  onItemSaved: _onFencingItemSaved,
                                  onStatusChanged: (bool? status) {
                                    // Handle status change if needed
                                  },
                                  customValidator: _validateFencingSerialNumber,
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
                                text: _getPreviousAvailableScreen() ?? 'BACK',
                                isLeftArrow: true,
                                backgroundColor: AppColors.buttonColorBg,
                                textColor: AppColors.buttonColorSite,
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
                              child: ArrowButton(
                                text: _getNextAvailableScreen() ?? 'SUBMIT',
                                isLeftArrow: false,
                                backgroundColor: AppColors.buttonColorBackBg,
                                textColor: AppColors.buttonColorTextBg,
                                onPressed: () async {
                                  await _postCurrentScreenData();
                                  final nextScreen = _getNextAvailableScreen();
                                  _navigateToNextScreen(context, nextScreen);
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

              // Loading overlay
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
