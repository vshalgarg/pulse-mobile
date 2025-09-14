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

class TransformerScreen extends StatefulWidget {
  final String siteType;
  final String auditSchId;
  final String siteAuditSchId;
  final AssetAuditModel? assetAuditData;

  const TransformerScreen({
    super.key,
    required this.siteType,
    required this.auditSchId,
    required this.siteAuditSchId,
    this.assetAuditData,
  });

  @override
  State<TransformerScreen> createState() => _TransformerScreenState();
}

class _TransformerScreenState extends State<TransformerScreen> {
  bool hasUnsavedChanges = false;
  final remarksController = TextEditingController();
  List<Map<String, dynamic>> _savedTransItems = [];
  
  List<Map<String, dynamic>> get savedTransItems => _savedTransItems;
  set savedTransItems(List<Map<String, dynamic>> value) {
    _savedTransItems = value;
  }
  
  final TextEditingController transSerialController = TextEditingController();
  String? lastValidatedSerial;
  String? _pendingNavigation; // Track pending navigation after successful post

  @override
  void initState() {
    super.initState();
    transSerialController.addListener(_onFormChanged);
    remarksController.addListener(_onFormChanged);
  }

  @override
  void dispose() {
    transSerialController.removeListener(_onFormChanged);
    remarksController.removeListener(_onFormChanged);
    transSerialController.dispose();
    remarksController.dispose();
    super.dispose();
  }

  void _onFormChanged() {
    final newHasUnsavedChanges = transSerialController.text.isNotEmpty ||
        remarksController.text.isNotEmpty;

    if (newHasUnsavedChanges != hasUnsavedChanges) {
      setState(() {
        hasUnsavedChanges = newHasUnsavedChanges;
      });
    }
  }

  // Callback methods for AssetAuditFormComponent
  void _onTransformerItemSaved(List<Map<String, dynamic>> updatedItems) {
    setState(() {
      savedTransItems = List.from(updatedItems);
      hasUnsavedChanges = true;
    });
  }

  bool _validateTransformerSerialNumber(String serialNumber, bool isQRCodeScanned) {
    if (widget.assetAuditData == null) return false;
    
    final transformerData = widget.assetAuditData!.responseData.categories['Transformer'];
    if (transformerData == null) return false;

    final allItems = transformerData.assets;
    
    if (isQRCodeScanned) {
      return allItems.any((item) => item.nexgenSerialNo?.toLowerCase() == serialNumber.toLowerCase());
    } else {
      return allItems.any((item) => item.mfgSerialNo?.toLowerCase() == serialNumber.toLowerCase());
    }
  }

  Future<void> _saveAndExit() async {
    await _postTransformerData();
  }

  Future<void> _postTransformerData() async {
    try {
      print('=== _postTransformerData Started ===');
      final assetAuditState = context.read<AssetAuditCubit>().state;
      print('Asset audit state: ${assetAuditState.runtimeType}');
      
      if (assetAuditState is AssetAuditLoaded && assetAuditState.assetAuditData.pageHeader.isNotEmpty) {
        print('Asset audit data loaded successfully');
        List<Map<String, dynamic>> allItemsToPost = [];

        if (savedTransItems.isNotEmpty) {
          allItemsToPost.addAll(savedTransItems);
        }

        if (remarksController.text.isNotEmpty) {
          Map<String, dynamic> remarksData = {
            'itemType': 'Transformer',
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
            itemType: 'Transformer',
            itemTypeId: 1,
            screenName: 'solar_transformer',
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
      print('Error posting Transformer data: $e');
    }
  }

  String? _getNextAvailableScreen() {
    return AssetAuditNavigationHelper.getNextAvailableScreen(widget.assetAuditData, 'Transformer');
  }

  String? _getPreviousAvailableScreen() {
    return AssetAuditNavigationHelper.getPreviousAvailableScreen(widget.assetAuditData, 'Transformer');
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
    final transformerData = widget.assetAuditData?.responseData.categories['Transformer'];
    
    return MultiBlocListener(
      listeners: [
        BlocListener<AssetAuditCubit, AssetAuditState>(
          listener: (context, state) {
            print('=== BlocListener State Changed ===');
            print('State type: ${state.runtimeType}');
            print('Pending navigation: $_pendingNavigation');
            
            if (state is AssetAuditPosting) {
              print('Asset audit posting started');
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => const Center(
                  child: CircularProgressIndicator(),
                ),
              );
            } else if (state is AssetAuditPostSuccess) {
              print('Asset audit post success');
              // Close loading dialog when posting is successful
              if (Navigator.canPop(context)) {
                Navigator.of(context).pop();
              }
              
              // Handle pending navigation
              if (_pendingNavigation != null) {
                final navigationTarget = _pendingNavigation;
                _pendingNavigation = null; // Clear the flag
                
                print('Navigating to: $navigationTarget');
                
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
              
              // If no pending navigation, refresh data
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
              showCustomToast(context, 'Error saving Transformer data: ${state.message}');
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
                                componentId: 'transformer',
                                serialLabel: transformerData?.assets.isNotEmpty == true
                                    ? "Transformer (${transformerData?.assets.first.oemName ?? 'N/A'}) - Serial Number"
                                    : "Transformer - Serial Number",
                                serialHintText: "Transformer Serial Number *",
                                photoLabel: "Add a Photo",
                                disabledFieldLabel: 'Transformer (Capacity)',
                                disabledFieldValue: transformerData?.assets.isNotEmpty == true
                                    ? transformerData?.assets.first.capacity ?? 'N/A'
                                    : 'N/A',
                                serialController: transSerialController,
                                siteAuditSchId: widget.siteAuditSchId,
                                initialSavedItems: savedTransItems,
                                onItemSaved: _onTransformerItemSaved,
                                onStatusChanged: (status) {
                                  // Status change handled by component
                                },
                                customValidator: _validateTransformerSerialNumber,
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
                                    print('=== Next Screen Button Pressed ===');
                                    print('Next screen: $nextScreen');
                                    
                                    if (nextScreen != null) {
                                      _pendingNavigation = nextScreen;
                                      print('Set pending navigation to: $nextScreen');
                                    } else {
                                      _pendingNavigation = 'home';
                                      print('Set pending navigation to: home');
                                    }
                                    
                                    print('Calling _postTransformerData()...');
                                    await _postTransformerData();
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