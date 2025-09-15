import 'package:app/commonWidgets/custom_buttons/arrow_botton.dart';
import 'package:app/constants/constants_methods.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

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
import '../../../bloc/asset_audit_cubit.dart';
import '../../../bloc/asset_audit_state.dart';
import '../../../utils/asset_audit_navigation_helper.dart';
import '../../../utils/asset_audit_post_helper.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class LTDBScreen extends StatefulWidget {
  final String siteType;
  final String auditSchId;
  final String siteAuditSchId;
  final AssetAuditModel? assetAuditData; // Complete asset audit data

  const LTDBScreen({
    super.key,
    required this.siteType,
    required this.auditSchId,
    required this.siteAuditSchId,
    this.assetAuditData, // Complete asset audit data
  });

  @override
  State<LTDBScreen> createState() => _LTDBScreenState();
}

class _LTDBScreenState extends State<LTDBScreen> {
  bool hasUnsavedChanges = false;

  final remarksController = TextEditingController(); // User remarks
  List<Map<String, dynamic>> _savedLtdbItems = [];
  
  List<Map<String, dynamic>> get savedLtdbItems => _savedLtdbItems;
  
  set savedLtdbItems(List<Map<String, dynamic>> value) {

    _savedLtdbItems = value;
  }

  // Controllers for CustomInfoCard
  final TextEditingController ltdbSerialController = TextEditingController();
  int totalLtdbItems = 0; // Will be set from API data
  bool isQRCodeScanned = false; // Track if serial was scanned or manually entered
  String? lastValidatedSerial; // Track last validated serial to prevent repeated toasts
  String? _pendingNavigation; // Track pending navigation after successful post



  @override
  void initState() {
    super.initState();
    ltdbSerialController.addListener(_onFormChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    context.read<AssetAuditCubit>().getAssetAuditData(
      siteType: widget.siteType,
      auditSchId: widget.auditSchId,
      siteAuditSchId: widget.siteAuditSchId,
    );

    // Initialize total items and saved items from API data
    if (widget.assetAuditData != null) {
      final ltdbData = widget.assetAuditData!.responseData.categories['LTDB'];
      if (ltdbData != null) {
        totalLtdbItems = ltdbData.assets.length;
        print('LTDB total items from API: $totalLtdbItems');
        print('LTDB data received: ${ltdbData.assets.length} assets');
        if (ltdbData.assets.isNotEmpty) {

          // Only load items from API if we don't have any user-saved items
          // This prevents overwriting user's saved items when the screen initializes
          if (savedLtdbItems.isEmpty) {
            // Load items that have been successfully posted to API AND have user interaction
            // (either photo taken or serial number entered - regardless of QR scan or manual entry)
            if (mounted) {
              setState(() {
                final postedItems = ltdbData.assets.where((asset) =>
                asset.assetAuditSiteRespId != null &&
                    asset.photoId != null
                ).map((asset) {
                  return {
                    'serialNumber': asset.mfgSerialNo ?? asset.nexgenSerialNo ?? '',
                    'photo': asset.photoId?.toString(),
                    'status': asset.assetStatus ?? 'OK',
                    'isQRCodeScanned': asset.qrCodeScanned ?? false,
                    'timestamp': DateTime.now(),
                    'assetAuditSiteRespId': asset.assetAuditSiteRespId,
                  };
                }).toList();

                savedLtdbItems = postedItems;
                print('LTDB: Loaded ${savedLtdbItems.length} items from API in didChangeDependencies (list was empty)');
              });
            }
          } else {
            print('LTDB: Skipping API load in didChangeDependencies, ${savedLtdbItems.length} items already saved by user');
          }

          // Only initialize remarks from API if user hasn't made changes
          if (ltdbData.remarks.isNotEmpty && remarksController.text.isEmpty) {
            if (mounted) {
              setState(() {
                remarksController.text = ltdbData.remarks.first.itemTypeRemark ?? '';
              });
            }
          }
        } else {
          print('No LTDB assets found in API data');
        }
      } else {
        print('LTDB category not found in asset audit data!');
      }
    } else {
      print('Asset audit data is null!');
    }

  }

  @override
  void dispose() {
    ltdbSerialController.removeListener(_onFormChanged);
    ltdbSerialController.dispose();
    remarksController.dispose();
    super.dispose();
  }

  void _onFormChanged() {
    final newHasUnsavedChanges = ltdbSerialController.text.isNotEmpty ||
        remarksController.text.isNotEmpty;

    if (newHasUnsavedChanges != hasUnsavedChanges) {
      setState(() {
        hasUnsavedChanges = newHasUnsavedChanges;
      });
    }
  }




  bool _validateSerialNumber(String serialNumber, bool isQRCodeScanned) {
    if (widget.assetAuditData == null) return false;

    if (lastValidatedSerial == serialNumber) {
      return true;
    }

    print('=== LTDB Serial Number Validation Debug ===');
    print('Validating serial number: "$serialNumber" (QR Scanned: $isQRCodeScanned)');

    final ltdbData = widget.assetAuditData!.responseData.categories['LTDB'];
    if (ltdbData == null) return false;

    final allItems = ltdbData.assets;
    print('LTDB items available: ${allItems.length}');

    if (allItems.isNotEmpty) {
      print('LTDB items details:');
      for (var item in allItems) {
        print('  - Item: ${item.itemType} | nexgenSerialNo: "${item.nexgenSerialNo}" | mfgSerialNo: "${item.mfgSerialNo}"');
      }
    }

    bool isValid = false;

    if (isQRCodeScanned) {
      isValid = allItems.any(
            (item) => item.nexgenSerialNo?.toLowerCase() == serialNumber.toLowerCase(),
      );
    } else {
      isValid = allItems.any(
            (item) => item.mfgSerialNo?.toLowerCase() == serialNumber.toLowerCase(),
      );
    }

    lastValidatedSerial = serialNumber;
    if (!isValid) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showCustomToast(context, isQRCodeScanned
            ? '❌ Invalid QR Code! Serial number not found in system.'
            : '❌ Invalid manual entry! Serial number not found in system.');
      });
    }

    return isValid;
  }

  bool _validateLTDBSerialNumber(String serialNumber, bool isQRCodeScanned) {
    return _validateSerialNumber(serialNumber, isQRCodeScanned);
  }

  void _onLTDBItemSaved(List<Map<String, dynamic>> updatedItems) {
    setState(() {
      savedLtdbItems = List.from(updatedItems);
      hasUnsavedChanges = true;
    });
  }


  Future<void> _saveAndExit() async {
      // Post LTDB data to API first
      await _postLtdbData();
  }

  int? _getRemarksAssetAuditSiteRespId() {
    if (widget.assetAuditData == null) {
      return null;
    }

    final ltdbData = widget.assetAuditData!.responseData.categories['LTDB'];
    if (ltdbData == null) {
      print('LTDB category data is null');
      return null;
    }

    final remarks = ltdbData.remarks;
    if (remarks.isNotEmpty) {
      print('Found ${remarks.length} remarks in backend data');

      for (var remark in remarks) {
        if (remark.assetAuditSiteRespId != null &&
            remark.assetAuditSiteRespId > 0 &&
            remark.itemType == 'LTDB') {
          print('Using LTDB remarks ID: ${remark.assetAuditSiteRespId}');
          return remark.assetAuditSiteRespId;
        }
      }

      for (var remark in remarks) {
        if (remark.assetAuditSiteRespId != null && remark.assetAuditSiteRespId > 0) {
          print('Using fallback remarks ID: ${remark.assetAuditSiteRespId} for itemType: ${remark.itemType}');
          return remark.assetAuditSiteRespId;
        }
      }
    }

    print('No valid remarks ID found in backend data');
    return null;
  }

  Future<void> _postLtdbData() async {
    try {
      final assetAuditState = context.read<AssetAuditCubit>().state;
      if (assetAuditState is AssetAuditLoaded && assetAuditState.assetAuditData.pageHeader.isNotEmpty) {
        List<Map<String, dynamic>> allItemsToPost = [];

        if (savedLtdbItems.isNotEmpty) {
          final enhancedItems = AssetAuditPostHelper.enhanceSavedItems(
            savedItems: savedLtdbItems,
            screenName: 'LTDB',
          );
          allItemsToPost.addAll(enhancedItems);
        }

        if (remarksController.text.isNotEmpty) {
          int? remarksAssetAuditSiteRespId = _getRemarksAssetAuditSiteRespId();

          if (remarksAssetAuditSiteRespId != null) {
            Map<String, dynamic> remarksData = {
              'itemType': 'LTDB',
              'remarks': remarksController.text,
              'recordType': 'Remarks',
              'timestamp': DateTime.now(),
              'assetAuditSiteRespId': remarksAssetAuditSiteRespId,
              'status': 'OK',
              'serialNumber': 'REMARKS',
              'photo': null,
              'photoTakenTs': DateTime.now().toString(),
              'isQRCodeScanned': false,
              'localQrCodeScannedTs': DateTime.now().toString(),
              'localCreatedDt': DateTime.now().toString(),
              'localModifiedDt': DateTime.now().toString(),
            };
            allItemsToPost.add(remarksData);
            print('LTDB Screen: Added user remarks to post with ID: $remarksAssetAuditSiteRespId, text: "${remarksController.text}"');
          } else {
            print('LTDB Screen: Could not find remarks ID from backend data');
          }
        }

        if (allItemsToPost.isEmpty) {
          print('LTDB Screen: No items to post');
          return;
        }

        final requests = await AssetAuditPostHelper.convertSavedItemsToPostRequest(
          savedItems: allItemsToPost,
          assetAuditData: assetAuditState.assetAuditData,
          itemType: 'LTDB',
          itemTypeId: 4,
          screenName: 'solar_ltdb',
          context: context,
          auditSchId: widget.auditSchId,
        );

        if (requests.isNotEmpty) {
          print('Posting remaining LTDB data: ${requests.length} requests');
          
          // Store the current remarks text before posting
          final currentRemarksText = remarksController.text;
          print('LTDB Screen: Storing current remarks text: "$currentRemarksText"');
          
          context.read<AssetAuditCubit>().postAssetAuditData(requests: requests);
          
          // Refresh the data immediately after posting
          print('Refreshing LTDB data after posting...');
          context.read<AssetAuditCubit>().getAssetAuditData(
            siteType: widget.siteType,
            auditSchId: widget.auditSchId,
            siteAuditSchId: widget.siteAuditSchId,
          );
          
          // Restore the remarks text after refresh to ensure it's not overwritten
          if (currentRemarksText.isNotEmpty) {
            print('LTDB Screen: Restoring remarks text after refresh: "$currentRemarksText"');
            remarksController.text = currentRemarksText;
          }
        }
      } else {
        print('No LTDB items to post - user can navigate without saving items');
      }
    } catch (e) {
      print('Error posting LTDB data: $e');
    }
  }







  String? _getNextAvailableScreen() {
    return AssetAuditNavigationHelper.getNextAvailableScreen(widget.assetAuditData, 'LTDB');
  }

  String? _getPreviousAvailableScreen() {
    return AssetAuditNavigationHelper.getPreviousAvailableScreen(widget.assetAuditData, 'LTDB');
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
    print('=== LTDBScreen build() called ===');
    print('savedLtdbItems.length: ${savedLtdbItems.length}');
    print('hasUnsavedChanges: $hasUnsavedChanges');
    
    return MultiBlocListener(
      listeners: [
        BlocListener<AssetAuditCubit, AssetAuditState>(
          listener: (context, state) {
            if (state is AssetAuditLoaded) {
              print('=== LTDB Screen: AssetAuditLoaded ===');
              final ltdbData = state.assetAuditData.responseData.categories['LTDB'];
                if (ltdbData != null && mounted) {
                  setState(() {
                    totalLtdbItems = ltdbData.assets.length;

                    // Only load items from API if we don't have any user-saved items
                    // This prevents overwriting user's saved items when the BlocListener fires
                    if (savedLtdbItems.isEmpty) {
                      // Load items that have been successfully posted to API AND have user interaction
                      // (either photo taken or serial number entered - regardless of QR scan or manual entry)
                      final postedItems = ltdbData.assets.where((asset) =>
                      asset.assetAuditSiteRespId != null &&
                          asset.photoId != null
                      ).map((asset) {
                        return {
                          'serialNumber': asset.mfgSerialNo ?? asset.nexgenSerialNo ?? '',
                          'photo': asset.photoId?.toString(),
                          'status': asset.assetStatus ?? 'OK',
                          'isQRCodeScanned': asset.qrCodeScanned ?? false,
                          'timestamp': DateTime.now(),
                          'assetAuditSiteRespId': asset.assetAuditSiteRespId,
                        };
                      }).toList();

                      savedLtdbItems = postedItems;
                      print('LTDB: Loaded ${savedLtdbItems.length} items from API (list was empty)');
                    } else {
                      print('LTDB: Skipping API load, ${savedLtdbItems.length} items already saved by user');
                    }
                    
                    // Only update remarks from API if user hasn't made changes
                    if (ltdbData.remarks.isNotEmpty && remarksController.text.isEmpty) {
                      remarksController.text = ltdbData.remarks.first.itemTypeRemark ?? '';
                    }
                  });
                     } else {
                print('LTDB category not found in loaded data');
              }
            } else if (state is AssetAuditError) {
              showCustomToast(context, state.message);
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
              
              print('LTDB data posted successfully: ${state.responses.length} responses');
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
              print('Error posting LTDB data: ${state.message}');
              showCustomToast(context, 'Error saving LTDB data: ${state.message}');
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
                                CustomFormField(
                                  label: "LTDB Make",
                                  initialValue: widget.assetAuditData?.responseData.categories['LTDB']?.assets.isNotEmpty == true
                                      ? widget.assetAuditData!.responseData.categories['LTDB']!.assets.first.oemName ?? "N/A"
                                      : "N/A",
                                  isRequired: true,
                                  isEditable: false,
                                ),
                                getHeight(15),
                                CustomFormField(
                                  label: "Type of LTDB",
                                  initialValue: widget.assetAuditData?.responseData.categories['LTDB']?.assets.isNotEmpty == true
                                      ? widget.assetAuditData!.responseData.categories['LTDB']!.assets.first.itemType ?? "N/A"
                                      : "N/A",
                                  isRequired: false,
                                  isEditable: false,
                                ),
                                getHeight(15),
                                CustomFormField(
                                  label: "Count of LTDB",
                                  initialValue: widget.assetAuditData?.responseData.categories['LTDB']?.assets.length.toString() ?? "0",
                                  isRequired: false,
                                  isEditable: false,
                                ),
                                getHeight(15),
                                Text(
                                  "LTDB Details",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white,
                                    fontFamily: fontFamilyMontserrat,
                                  ),
                                ),
                                getHeight(3),
                                AssetAuditFormComponent(
                                  componentId: 'ltdb_component',
                                  serialLabel: "LTDB - Serial Number *",
                                  serialHintText: "LTDB Serial Number *",
                                  photoLabel: "Add a Photo",
                                  disabledFieldLabel: widget.assetAuditData?.responseData.categories['LTDB']?.assets.isNotEmpty == true
                                      ? "LTDB (${widget.assetAuditData!.responseData.categories['LTDB']!.assets.first.capacity ?? 'N/A'})"
                                      : "LTDB (Capacity)",
                                  disabledFieldValue: widget.assetAuditData?.responseData.categories['LTDB']?.assets.isNotEmpty == true
                                      ? widget.assetAuditData!.responseData.categories['LTDB']!.assets.first.capacity ?? "N/A"
                                      : "N/A",
                                  serialController: ltdbSerialController,
                                  initialSavedItems: savedLtdbItems,
                                  onItemSaved: _onLTDBItemSaved,
                                  onStatusChanged: (status) {
                                    // Handle status change if needed
                                  },
                                  customValidator: _validateLTDBSerialNumber,
                                  customValidationErrorMessage: isQRCodeScanned
                                      ? 'Invalid QR Code! Serial number not found in system.'
                                      : 'Invalid serial number! Please check and try again.',
                                  siteAuditSchId: widget.siteAuditSchId,
                                  showTable: true,
                                  tableTitle: "Saved LTDB Items",
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
                                  if (nextScreen == null) {
                                    return ArrowButton(
                                      text: "Submit",
                                      isLeftArrow: false,
                                      backgroundColor: AppColors.buttonColorBg,
                                      textColor: AppColors.buttonColorSite,
                                      onPressed: () async {
                                        _pendingNavigation = 'home';
                                        await _postLtdbData();
                                      },
                                    );
                                  } else {
                                    return ArrowButton(
                                      text: nextScreen,
                                      isLeftArrow: false,
                                      backgroundColor: AppColors.buttonColorBg,
                                      textColor: AppColors.buttonColorSite,
                                      onPressed: () async {
                                        // POST data to API before navigation
                                        await _postLtdbData();

                                        // Navigate to the next available screen
                                        _navigateToNextScreen(
                                            context, nextScreen);
                                      },
                                    );
                                  }
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
