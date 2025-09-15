import 'package:app/commonWidgets/custom_buttons/arrow_botton.dart';
import 'package:app/constants/constants_methods.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../bloc/asset_audit_cubit.dart';
import '../../../bloc/asset_audit_state.dart';
import '../../../commonWidgets/custom_dialogs/unsaved_changes_dialog.dart';
import '../../../commonWidgets/custom_form_appbar.dart';
import '../../../commonWidgets/custom_remark.dart';
import '../../../commonWidgets/asset_audit_form_component.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_images.dart';
import '../../../constants/constants_strings.dart';
import '../../../models/asset_audit_model.dart';
import '../../home_screen.dart';
import '../../../utils/asset_audit_navigation_helper.dart';
import '../../../utils/asset_audit_post_helper.dart';

class SolarSurveillanceScreen extends StatefulWidget {
  final String siteType;
  final String auditSchId;
  final String siteAuditSchId;
  final AssetAuditModel? assetAuditData;

  const SolarSurveillanceScreen({
    super.key,
    required this.siteType,
    required this.auditSchId,
    required this.siteAuditSchId,
    this.assetAuditData,
  });

  @override
  State<SolarSurveillanceScreen> createState() => _SolarSurveillanceScreenState();
}

class _SolarSurveillanceScreenState extends State<SolarSurveillanceScreen> {
  bool hasUnsavedChanges = false;
  final remarksController = TextEditingController();
  List<Map<String, dynamic>> _savedSolarSurvellianceItems = [];
  
  List<Map<String, dynamic>> get savedSolarSurvellianceItems => _savedSolarSurvellianceItems;
  set savedSolarSurvellianceItems(List<Map<String, dynamic>> value) {
    _savedSolarSurvellianceItems = value;
  }
  
  final TextEditingController solarSurvellianceSerialController = TextEditingController();
  String? lastValidatedSerial;
  String? _pendingNavigation;

  @override
  void initState() {
    super.initState();
    solarSurvellianceSerialController.addListener(_onFormChanged);
    remarksController.addListener(_onFormChanged);
  }

  @override
  void dispose() {
    solarSurvellianceSerialController.removeListener(_onFormChanged);
    remarksController.removeListener(_onFormChanged);
    solarSurvellianceSerialController.dispose();
    remarksController.dispose();
    super.dispose();
  }

  void _onFormChanged() {
    final newHasUnsavedChanges = solarSurvellianceSerialController.text.isNotEmpty ||
        remarksController.text.isNotEmpty;

    if (newHasUnsavedChanges != hasUnsavedChanges) {
      setState(() {
        hasUnsavedChanges = newHasUnsavedChanges;
      });
    }
  }

  void _onSolarSurvellianceItemSaved(List<Map<String, dynamic>> updatedItems) {
    setState(() {
      savedSolarSurvellianceItems = List.from(updatedItems);
      hasUnsavedChanges = true;
    });
  }

  bool _validateSolarSurvellianceSerialNumber(String serialNumber, bool isQRCodeScanned) {
    if (widget.assetAuditData == null) return false;
    
    final solarSurvellianceData = widget.assetAuditData!.responseData.categories['Solar Surveillance'];
    if (solarSurvellianceData == null) return false;

    final allItems = solarSurvellianceData.assets;
    
    if (isQRCodeScanned) {
      return allItems.any((item) => item.nexgenSerialNo?.toLowerCase() == serialNumber.toLowerCase());
    } else {
      return allItems.any((item) => item.mfgSerialNo?.toLowerCase() == serialNumber.toLowerCase());
    }
  }

  Future<void> _saveAndExit() async {
    await _postSolarSurvellianceData();
  }

  Future<void> _postSolarSurvellianceData() async {
    try {
      final assetAuditState = context.read<AssetAuditCubit>().state;
      if (assetAuditState is AssetAuditLoaded && assetAuditState.assetAuditData.pageHeader.isNotEmpty) {
        List<Map<String, dynamic>> allItemsToPost = [];

        if (savedSolarSurvellianceItems.isNotEmpty) {
          allItemsToPost.addAll(savedSolarSurvellianceItems);
        }

        if (remarksController.text.isNotEmpty) {
            Map<String, dynamic> remarksData = {
            'itemType': 'Solar Surveillance',
            'remarks': remarksController.text,
              'recordType': 'Remarks',
              'timestamp': DateTime.now(),
              'status': 'OK',
              'serialNumber': 'REMARKS',
            };
            allItemsToPost.add(remarksData);
        }

        if (allItemsToPost.isNotEmpty) {
        final requests = await AssetAuditPostHelper.convertSavedItemsToPostRequest(
          savedItems: allItemsToPost,
          assetAuditData: assetAuditState.assetAuditData,
            itemType: 'Solar Surveillance',
            itemTypeId: 7,
            screenName: 'solar_survelliance',
          context: context,
          auditSchId: widget.auditSchId,
        );

        if (requests.isNotEmpty) {
            context.read<AssetAuditCubit>().postAssetAuditData(requests: requests);
          }
        }
      }
    } catch (e) {
      print('Error posting Solar Surveillance data: $e');
    }
  }

  String? _getNextAvailableScreen() {
    return AssetAuditNavigationHelper.getNextAvailableScreen(widget.assetAuditData, 'Solar Surveillance');
  }

  String? _getPreviousAvailableScreen() {
    return AssetAuditNavigationHelper.getPreviousAvailableScreen(widget.assetAuditData, 'Solar Surveillance');
  }

  void _navigateToNextScreen(BuildContext context, String screenName) {
    AssetAuditNavigationHelper.navigateToNextScreen(
      context,
      screenName,
      widget.siteType,
      widget.auditSchId,
      widget.siteAuditSchId,
      widget.assetAuditData,
    );
  }

  @override
  Widget build(BuildContext context) {
    final solarSurvellianceData = widget.assetAuditData?.responseData.categories['Solar Surveillance'];
    
    return MultiBlocListener(
      listeners: [
        BlocListener<AssetAuditCubit, AssetAuditState>(
          listener: (context, state) {
            if (state is AssetAuditPosting) {
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => const Center(
                  child: CircularProgressIndicator(),
                ),
              );
            } else if (state is AssetAuditPostSuccess) {
              if (Navigator.canPop(context)) {
                Navigator.of(context).pop();
              }
              
              if (_pendingNavigation != null) {
                final navigationTarget = _pendingNavigation;
                _pendingNavigation = null;
                
                if (navigationTarget == 'home') {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => HomeScreen()),
                  );
              } else {
                  _navigateToNextScreen(context, navigationTarget!);
              }
                return;
              }
              
              context.read<AssetAuditCubit>().getAssetAuditData(
                siteType: widget.siteType,
                auditSchId: widget.auditSchId,
                siteAuditSchId: widget.siteAuditSchId,
              );
            } else if (state is AssetAuditPostError) {
              if (Navigator.canPop(context)) {
                Navigator.of(context).pop();
              }
              _pendingNavigation = null;
              showCustomToast(context, 'Error saving Solar Surveillance data: ${state.message}');
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
                    parentContext: context,
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
                              children: [
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Text(
                                      solarSurvellianceData?.assets.isNotEmpty == true
                                          ? "Solar Surveillance (${solarSurvellianceData?.assets.first.oemName ?? 'N/A'}) - Serial Number"
                                          : "Solar Surveillance - Serial Number",
                                      style: const TextStyle(
                                        color: AppColors.color555555,
                                    fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                    fontFamily: fontFamilyMontserrat,
                                  ),
                                ),
                                getHeight(3),
                                    AssetAuditFormComponent(
                                      componentId: 'solar_survelliance',
                                      serialLabel: solarSurvellianceData?.assets.isNotEmpty == true
                                          ? "Solar Surveillance (${solarSurvellianceData?.assets.first.oemName ?? 'N/A'}) - Serial Number"
                                          : "Solar Surveillance - Serial Number",
                                      serialHintText: "Solar Surveillance Serial Number *",
                                  photoLabel: "Add a Photo",
                                      disabledFieldLabel: 'Solar Surveillance (Capacity)',
                                      disabledFieldValue: solarSurvellianceData?.assets.isNotEmpty == true
                                          ? solarSurvellianceData?.assets.first.capacity ?? 'N/A'
                                          : 'N/A',
                                      serialController: solarSurvellianceSerialController,
                                      siteAuditSchId: widget.siteAuditSchId,
                                      initialSavedItems: savedSolarSurvellianceItems,
                                      onItemSaved: _onSolarSurvellianceItemSaved,
                                      onStatusChanged: (status) {},
                                      customValidator: _validateSolarSurvellianceSerialNumber,
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
                                      if (nextScreen != null) {
                                      _pendingNavigation = nextScreen;
                                      } else {
                                      _pendingNavigation = 'home';
                                      }
                                    await _postSolarSurvellianceData();
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
            ],
          ),
        ),
      ),
    );
  }
}