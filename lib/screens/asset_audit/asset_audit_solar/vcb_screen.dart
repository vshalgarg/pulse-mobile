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

class VCBScreen extends StatefulWidget {
  final String siteType;
  final String auditSchId;
  final String siteAuditSchId;
  final AssetAuditModel? assetAuditData;

  const VCBScreen({
    super.key,
    required this.siteType,
    required this.auditSchId,
    required this.siteAuditSchId,
    this.assetAuditData,
  });

  @override
  State<VCBScreen> createState() => _VCBScreenState();
}

class _VCBScreenState extends State<VCBScreen> {
  bool hasUnsavedChanges = false;
  final remarksController = TextEditingController();
  List<Map<String, dynamic>> _savedVcbItems = [];
  
  List<Map<String, dynamic>> get savedVcbItems => _savedVcbItems;
  set savedVcbItems(List<Map<String, dynamic>> value) {
    _savedVcbItems = value;
  }
  
  final TextEditingController vcbSerialController = TextEditingController();
  String? lastValidatedSerial;
  String? _pendingNavigation;

  @override
  void initState() {
    super.initState();
    vcbSerialController.addListener(_onFormChanged);
    remarksController.addListener(_onFormChanged);
  }

  @override
  void dispose() {
    vcbSerialController.removeListener(_onFormChanged);
    remarksController.removeListener(_onFormChanged);
    vcbSerialController.dispose();
    remarksController.dispose();
    super.dispose();
  }

  void _onFormChanged() {
    final newHasUnsavedChanges = vcbSerialController.text.isNotEmpty ||
        remarksController.text.isNotEmpty;

    if (newHasUnsavedChanges != hasUnsavedChanges) {
      setState(() {
        hasUnsavedChanges = newHasUnsavedChanges;
      });
    }
  }

  void _onVcbItemSaved(List<Map<String, dynamic>> updatedItems) {
    setState(() {
      savedVcbItems = List.from(updatedItems);
      hasUnsavedChanges = true;
    });
  }

  bool _validateVcbSerialNumber(String serialNumber, bool isQRCodeScanned) {
    if (widget.assetAuditData == null) return false;
    
    final vcbData = widget.assetAuditData!.responseData.categories['VCB'];
    if (vcbData == null) return false;

    final allItems = vcbData.assets;
    
    if (isQRCodeScanned) {
      return allItems.any((item) => item.nexgenSerialNo?.toLowerCase() == serialNumber.toLowerCase());
    } else {
      return allItems.any((item) => item.mfgSerialNo?.toLowerCase() == serialNumber.toLowerCase());
    }
  }

  Future<void> _saveAndExit() async {
    await _postVcbData();
  }

  Future<void> _postVcbData() async {
    try {
      print('=== _postVcbData Started ===');
      final assetAuditState = context.read<AssetAuditCubit>().state;
      print('Asset audit state: ${assetAuditState.runtimeType}');
      
      if (assetAuditState is AssetAuditLoaded && assetAuditState.assetAuditData.pageHeader.isNotEmpty) {
        print('Asset audit data loaded successfully');
        List<Map<String, dynamic>> allItemsToPost = [];

        if (savedVcbItems.isNotEmpty) {
          allItemsToPost.addAll(savedVcbItems);
        }

        if (remarksController.text.isNotEmpty) {
          Map<String, dynamic> remarksData = {
            'itemType': 'VCB',
            'remarks': remarksController.text,
            'recordType': 'Remarks',
            'timestamp': DateTime.now(),
            'status': 'OK',
            'serialNumber': 'REMARKS',
          };
          allItemsToPost.add(remarksData);
        }

        if (allItemsToPost.isNotEmpty) {
          print('Items to post: ${allItemsToPost.length}');
          final requests = await AssetAuditPostHelper.convertSavedItemsToPostRequest(
            savedItems: allItemsToPost,
            assetAuditData: assetAuditState.assetAuditData,
            itemType: 'VCB',
            itemTypeId: 2,
            screenName: 'solar_vcb',
            context: context,
            auditSchId: widget.auditSchId,
          );

          print('Generated requests: ${requests.length}');
          if (requests.isNotEmpty) {
            print('Calling postAssetAuditData...');
            context.read<AssetAuditCubit>().postAssetAuditData(requests: requests);
          } else {
            print('No requests to post, proceeding with navigation');
            // If no data to post, proceed with navigation immediately
            if (_pendingNavigation != null) {
              final navigationTarget = _pendingNavigation;
              _pendingNavigation = null;
              print('No data to post, navigating to: $navigationTarget');
              
              if (navigationTarget == 'home') {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => HomeScreen()),
                );
              } else {
                _navigateToNextScreen(context, navigationTarget!);
              }
            }
          }
        } else {
          print('No items to post, proceeding with navigation');
          // If no data to post, proceed with navigation immediately
          if (_pendingNavigation != null) {
            final navigationTarget = _pendingNavigation;
            _pendingNavigation = null;
            print('No data to post, navigating to: $navigationTarget');
            
            if (navigationTarget == 'home') {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => HomeScreen()),
              );
            } else {
              _navigateToNextScreen(context, navigationTarget!);
            }
          }
        }
      }
    } catch (e) {
      print('Error posting VCB data: $e');
    }
  }

  String? _getNextAvailableScreen() {
    return AssetAuditNavigationHelper.getNextAvailableScreen(widget.assetAuditData, 'VCB');
  }

  String? _getPreviousAvailableScreen() {
    return AssetAuditNavigationHelper.getPreviousAvailableScreen(widget.assetAuditData, 'VCB');
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
    final vcbData = widget.assetAuditData?.responseData.categories['VCB'];
    
    return MultiBlocListener(
      listeners: [
        BlocListener<AssetAuditCubit, AssetAuditState>(
          listener: (context, state) {
            print('=== VCB BlocListener State Changed ===');
            print('State type: ${state.runtimeType}');
            print('Pending navigation: $_pendingNavigation');
            
            if (state is AssetAuditPosting) {
              print('VCB Asset audit posting started');
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => const Center(
                  child: CircularProgressIndicator(),
                ),
              );
            } else if (state is AssetAuditPostSuccess) {
              print('VCB Asset audit post success');
              if (Navigator.canPop(context)) {
                Navigator.of(context).pop();
              }
              
              if (_pendingNavigation != null) {
                final navigationTarget = _pendingNavigation;
                _pendingNavigation = null;
                
                print('Navigating to: $navigationTarget');
                
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
              
              // If no pending navigation, refresh data
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
              showCustomToast(context, 'Error saving VCB data: ${state.message}');
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
                              AssetAuditFormComponent(
                                componentId: 'vcb',
                                serialLabel: vcbData?.assets.isNotEmpty == true
                                    ? "VCB (${vcbData?.assets.first.oemName ?? 'N/A'}) - Serial Number"
                                    : "VCB - Serial Number",
                                serialHintText: "VCB Serial Number *",
                                photoLabel: "Add a Photo",
                                disabledFieldLabel: 'VCB (Capacity)',
                                disabledFieldValue: vcbData?.assets.isNotEmpty == true
                                    ? vcbData?.assets.first.capacity ?? 'N/A'
                                    : 'N/A',
                                serialController: vcbSerialController,
                                siteAuditSchId: widget.siteAuditSchId,
                                initialSavedItems: savedVcbItems,
                                onItemSaved: _onVcbItemSaved,
                                onStatusChanged: (status) {},
                                customValidator: _validateVcbSerialNumber,
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
                                    print('=== VCB Next Screen Button Pressed ===');
                                    print('Next screen: $nextScreen');
                                    
                                    if (nextScreen != null) {
                                      _pendingNavigation = nextScreen;
                                      print('Set pending navigation to: $nextScreen');
                                    } else {
                                      _pendingNavigation = 'home';
                                      print('Set pending navigation to: home');
                                    }
                                    
                                    print('Calling _postVcbData()...');
                                    await _postVcbData();
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