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

class SCADAScreen extends StatefulWidget {
  final String siteType;
  final String auditSchId;
  final String siteAuditSchId;
  final AssetAuditModel? assetAuditData;

  const SCADAScreen({
    super.key,
    required this.siteType,
    required this.auditSchId,
    required this.siteAuditSchId,
    this.assetAuditData,
  });

  @override
  State<SCADAScreen> createState() => _SCADAScreenState();
}

class _SCADAScreenState extends State<SCADAScreen> {
  bool hasUnsavedChanges = false;
  final remarksController = TextEditingController();
  List<Map<String, dynamic>> _savedScadaItems = [];
  
  List<Map<String, dynamic>> get savedScadaItems => _savedScadaItems;
  set savedScadaItems(List<Map<String, dynamic>> value) {
    _savedScadaItems = value;
  }
  
  final TextEditingController scadaSerialController = TextEditingController();
  String? lastValidatedSerial;
  String? _pendingNavigation;

  @override
  void initState() {
    super.initState();
    scadaSerialController.addListener(_onFormChanged);
    remarksController.addListener(_onFormChanged);
  }

  @override
  void dispose() {
    scadaSerialController.removeListener(_onFormChanged);
    remarksController.removeListener(_onFormChanged);
    scadaSerialController.dispose();
    remarksController.dispose();
    super.dispose();
  }

  void _onFormChanged() {
    final newHasUnsavedChanges = scadaSerialController.text.isNotEmpty ||
        remarksController.text.isNotEmpty;

    if (newHasUnsavedChanges != hasUnsavedChanges) {
      setState(() {
        hasUnsavedChanges = newHasUnsavedChanges;
      });
    }
  }

  void _onScadaItemSaved(List<Map<String, dynamic>> updatedItems) {
    setState(() {
      savedScadaItems = List.from(updatedItems);
      hasUnsavedChanges = true;
    });
  }

  bool _validateScadaSerialNumber(String serialNumber, bool isQRCodeScanned) {
    if (widget.assetAuditData == null) return false;
    
    final scadaData = widget.assetAuditData!.responseData.categories['SCADA'];
    if (scadaData == null) return false;

    final allItems = scadaData.assets;
    
    if (isQRCodeScanned) {
      return allItems.any((item) => item.nexgenSerialNo?.toLowerCase() == serialNumber.toLowerCase());
    } else {
      return allItems.any((item) => item.mfgSerialNo?.toLowerCase() == serialNumber.toLowerCase());
    }
  }

  Future<void> _saveAndExit() async {
    await _postScadaData();
  }

  Future<void> _postScadaData() async {
    try {
      print('=== _postScadaData Started ===');
      final assetAuditState = context.read<AssetAuditCubit>().state;
      print('Asset audit state: ${assetAuditState.runtimeType}');
      
      if (assetAuditState is AssetAuditLoaded && assetAuditState.assetAuditData.pageHeader.isNotEmpty) {
        print('Asset audit data loaded successfully');
        List<Map<String, dynamic>> allItemsToPost = [];

        if (savedScadaItems.isNotEmpty) {
          allItemsToPost.addAll(savedScadaItems);
        }

        if (remarksController.text.isNotEmpty) {
          Map<String, dynamic> remarksData = {
            'itemType': 'SCADA',
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
            itemType: 'SCADA',
            itemTypeId: 4,
            screenName: 'solar_scada',
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
      print('Error posting SCADA data: $e');
    }
  }

  String? _getNextAvailableScreen() {
    return AssetAuditNavigationHelper.getNextAvailableScreen(widget.assetAuditData, 'SCADA');
  }

  String? _getPreviousAvailableScreen() {
    return AssetAuditNavigationHelper.getPreviousAvailableScreen(widget.assetAuditData, 'SCADA');
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
    final scadaData = widget.assetAuditData?.responseData.categories['SCADA'];
    
    return MultiBlocListener(
      listeners: [
        BlocListener<AssetAuditCubit, AssetAuditState>(
          listener: (context, state) {
            print('=== SCADA BlocListener State Changed ===');
            print('State type: ${state.runtimeType}');
            print('Pending navigation: $_pendingNavigation');
            
            if (state is AssetAuditPosting) {
              print('SCADA Asset audit posting started');
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => const Center(
                  child: CircularProgressIndicator(),
                ),
              );
            } else if (state is AssetAuditPostSuccess) {
              print('SCADA Asset audit post success');
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
              showCustomToast(context, 'Error saving SCADA data: ${state.message}');
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
                                componentId: 'scada',
                                serialLabel: scadaData?.assets.isNotEmpty == true
                                    ? "SCADA (${scadaData?.assets.first.oemName ?? 'N/A'}) - Serial Number"
                                    : "SCADA - Serial Number",
                                serialHintText: "SCADA Serial Number *",
                                photoLabel: "Add a Photo",
                                disabledFieldLabel: 'SCADA (Capacity)',
                                disabledFieldValue: scadaData?.assets.isNotEmpty == true
                                    ? scadaData?.assets.first.capacity ?? 'N/A'
                                    : 'N/A',
                                serialController: scadaSerialController,
                                siteAuditSchId: widget.siteAuditSchId,
                                initialSavedItems: savedScadaItems,
                                onItemSaved: _onScadaItemSaved,
                                onStatusChanged: (status) {},
                                customValidator: _validateScadaSerialNumber,
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
                                    print('=== SCADA Next Screen Button Pressed ===');
                                    print('Next screen: $nextScreen');
                                    
                                    if (nextScreen != null) {
                                      _pendingNavigation = nextScreen;
                                      print('Set pending navigation to: $nextScreen');
                                    } else {
                                      _pendingNavigation = 'home';
                                      print('Set pending navigation to: home');
                                    }
                                    
                                    print('Calling _postScadaData()...');
                                    await _postScadaData();
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