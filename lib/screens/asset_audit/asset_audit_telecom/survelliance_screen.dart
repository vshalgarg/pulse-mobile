import 'package:app/commonWidgets/custom_buttons/arrow_botton.dart';
import 'package:app/constants/constants_methods.dart';
import 'package:app/screens/asset_audit/asset_audit_telecom/fencing_screen.dart';
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
import '../../../repositories/image_repository.dart';
import '../../../app_config.dart';
import 'dart:async';
import 'dart:io';
import 'dart:convert';

import '../../../commonWidgets/asset_type_card.dart';
import '../../../commonWidgets/custom_dialogs/success_dialog.dart';
import '../../../commonWidgets/custom_dialogs/unsaved_changes_dialog.dart';
import '../../../commonWidgets/custom_form_appbar.dart';
import '../../../commonWidgets/custom_form_field.dart';
import '../../../commonWidgets/custom_radio_options.dart';
import '../../../commonWidgets/custom_remark.dart';
import '../../../commonWidgets/base64_image_widget.dart';
import '../../../commonWidgets/asset_audit_form_component.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_images.dart';
import '../../../constants/constants_strings.dart';
import '../../home_screen.dart';

class SurveillianceScreen extends StatefulWidget {
  final CategoryData? cctvData;
  final AssetAuditModel? assetAuditData;
  final bool showSuccessMessage; // Flag to show success message

  // Data from previous screens in the flow
  final List<Map<String, dynamic>>? extinguisherItems;
  final List<Map<String, dynamic>>? solarPlatesItems;

  // Navigation parameters
  final String? siteType;
  final String? auditSchId;
  final String? siteAuditSchId;

  const SurveillianceScreen({
    super.key,
    this.cctvData,
    this.assetAuditData,
    this.showSuccessMessage = false, // Default to false
    this.extinguisherItems,
    this.solarPlatesItems,
    this.siteType,
    this.auditSchId,
    this.siteAuditSchId,
  });

  @override
  State<SurveillianceScreen> createState() => _SurveillianceScreenState();
}

class _SurveillianceScreenState extends State<SurveillianceScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController generalRemarksController = TextEditingController();
  
  // Controllers for AssetAuditFormComponent
  final TextEditingController cctvSerialController = TextEditingController();
  
  // Saved items lists
  List<Map<String, dynamic>> savedCCTVItems = [];
  
  // Validation methods
  bool _validateCCTVSerialNumber(String serialNumber, bool isQRCodeScanned) {
    if (widget.cctvData == null) return false;
    
    final allItems = widget.cctvData!.assets ?? [];
    return allItems.any((item) => 
      item.mfgSerialNo?.toLowerCase() == serialNumber.toLowerCase() ||
      item.nexgenSerialNo?.toLowerCase() == serialNumber.toLowerCase()
    );
  }
  
  // Callback methods for AssetAuditFormComponent
  void _onCCTVItemSaved(List<Map<String, dynamic>> items) {
    setState(() {
      savedCCTVItems.addAll(items);
    });
  }
  
  // Check if there are unsaved changes
  bool get _hasChanges {
    return generalRemarksController.text.isNotEmpty || savedCCTVItems.isNotEmpty;
  }

  @override
  void initState() {
    super.initState();
    
    // Load remarks if available
    if (widget.cctvData?.remarks.isNotEmpty == true) {
      final remarks = widget.cctvData!.remarks;
      for (var remark in remarks) {
        if (remark.itemTypeRemark != null && remark.itemTypeRemark!.isNotEmpty) {
          generalRemarksController.text = remark.itemTypeRemark!;
          break;
        }
      }
    }
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
    return AssetAuditNavigationHelper.getNextAvailableTelecomScreen(widget.assetAuditData, 'CCTV');
  }

  // Helper method to get the previous available screen based on data availability
  String? _getPreviousAvailableScreen() {
    return AssetAuditNavigationHelper.getPreviousAvailableTelecomScreen(widget.assetAuditData, 'CCTV');
  }
  
  Future<void> _saveAndExit() async {
    try {
      await _postCurrentScreenData();
    } catch (e) {
      print('Error posting Surveillance data: $e');
    }
  }
  
  // Post current screen data to API
  Future<bool> _postCurrentScreenData() async {
    if (widget.assetAuditData == null) {
      print('Surveillance Screen: No asset audit data available for posting');
      return false;
    }

    try {
      // Convert saved items to POST request format
      final requests = await AssetAuditPostHelper.convertSavedItemsToPostRequest(
        savedItems: savedCCTVItems,
        assetAuditData: widget.assetAuditData!,
        itemType: 'CCTV',
        itemTypeId: AssetAuditPostHelper.getItemTypeId('CCTV'),
        screenName: 'Surveillance',
        context: context,
      );

      if (requests.isEmpty) {
        print('Surveillance Screen: No items to post');
        return false;
      }

      // Add remarks if available
      if (generalRemarksController.text.isNotEmpty) {
        final remarksRequest = AssetAuditPostRequest(
          assetAuditSiteRespId: widget.cctvData?.assets.isNotEmpty == true 
              ? widget.cctvData!.assets.first.assetAuditSiteRespId ?? 0
              : 0,
          auditSchId: int.tryParse(widget.auditSchId ?? '0') ?? 0,
          siteAuditSchId: int.tryParse(widget.siteAuditSchId ?? '0') ?? 0,
          siteId: widget.assetAuditData?.pageHeader.first.siteId ?? 0,
          itemInstanceId: 0,
          nexgenSerialNo: 'REMARKS',
          itemTypeId: AssetAuditPostHelper.getItemTypeId('CCTV'),
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
      print('Surveillance Screen: Error preparing data: $e');
      return false;
    }
  }





  @override
  void dispose() {
    cctvSerialController.dispose();
    generalRemarksController.dispose();
    super.dispose();
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
                    parentContext: context, // Use the outer context (screen context)
                    onSaveAndExit: () async {
                      await _saveAndExit();
                    },
                    onDiscard: () {
                    },
                  ),
                );
              } else {
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
                                // CCTV Form Component
                                AssetAuditFormComponent(
                                  componentId: 'cctv',
                                  serialLabel: "CCTV - Serial Number *",
                                  serialHintText: "CCTV Serial Number",
                                  photoLabel: "Add a Photo",
                                  disabledFieldLabel: "Capacity",
                                  disabledFieldValue: "1080p",
                                  serialController: cctvSerialController,
                                  initialSavedItems: savedCCTVItems,
                                  onItemSaved: _onCCTVItemSaved,
                                  onStatusChanged: (bool? status) {
                                    // Handle status change if needed
                                  },
                                  customValidator: _validateCCTVSerialNumber,
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
                              child: ArrowButton(
                                text: _getNextAvailableScreen() ?? 'SUBMIT',
                                isLeftArrow: false,
                                backgroundColor: AppColors.buttonColorBg,
                                textColor: AppColors.buttonColorSite,
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
