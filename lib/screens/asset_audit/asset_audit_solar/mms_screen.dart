import 'package:app/commonWidgets/custom_buttons/arrow_botton.dart';
import 'package:app/constants/constants_methods.dart';
import 'package:app/utils/asset_audit_navigation_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../bloc/asset_audit_cubit.dart';
import '../../../bloc/asset_audit_state.dart';
import '../../../bloc/audit_schedule_status_cubit.dart';
import '../../../commonWidgets/custom_dialogs/unsaved_changes_dialog.dart';
import '../../../commonWidgets/custom_form_appbar.dart';
import '../../../commonWidgets/custom_form_field.dart';
import '../../../commonWidgets/custom_remark.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_images.dart';
import '../../../models/asset_audit_model.dart';
import '../../home_screen.dart';
import '../../../models/asset_audit_post_model.dart';

class MMSScreen extends StatefulWidget {
  final String siteType;
  final String auditSchId;
  final String siteAuditSchId;
  final AssetAuditModel? assetAuditData; // Complete asset audit data

  const MMSScreen({
    super.key,
    required this.siteType,
    required this.auditSchId,
    required this.siteAuditSchId,
    required this.assetAuditData,
  });

  @override
  State<MMSScreen> createState() => _MMSScreenState();
}

class _MMSScreenState extends State<MMSScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController serialController = TextEditingController();
  final remarksController = TextEditingController(); // User remarks
  int totalMmsItems = 0; // Will be set from API data
  bool hasUnsavedChanges = false;
  
  // Get MMS category data
  CategoryData? get mmsCategoryData {
    return widget.assetAuditData?.responseData.categories['MMS'];
  }

  // Get MMS assets (either from assets or subCategories)
  List<AssetItem> get mmsAssets {
    final categoryData = mmsCategoryData;
    if (categoryData == null) return [];
    
    // Check if data is in assets array
    if (categoryData.assets.isNotEmpty) {
      return categoryData.assets;
    }
    
    // Check if data is in subCategories (direct array format)
    if (categoryData.subCategories != null && categoryData.subCategories!['MMS'] != null) {
      return categoryData.subCategories!['MMS']!;
    }
    
    return [];
  }
  bool showValidationErrors = false;

  @override
  void initState() {
    super.initState();
    serialController.addListener(_onFormChanged);
    remarksController.addListener(_onFormChanged);
    _loadExistingData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    print('=== MMS didChangeDependencies called ===');

    // Initialize total items from API data
    if (widget.assetAuditData != null) {
      final mmsData = widget.assetAuditData!.responseData.categories['MMS'];
      if (mmsData != null) {
        totalMmsItems = mmsData.assets.length;
      } else {
        print('MMS category not found in asset audit data!');
      }
    } else {
      print('Asset audit data is null!');
    }
  }

  @override
  void dispose() {
    serialController.removeListener(_onFormChanged);
    remarksController.removeListener(_onFormChanged);
    serialController.dispose();
    remarksController.dispose();
    super.dispose();
  }

  void _onFormChanged() {
    setState(() {
      hasUnsavedChanges = serialController.text.isNotEmpty ||
          remarksController.text.isNotEmpty;

      if (showValidationErrors && serialController.text.isNotEmpty) {
        showValidationErrors = false;
      }
    });
  }

  void _loadExistingData() {
    // Load remarks from API data if available
    if (widget.assetAuditData != null) {
      final mmsData = widget.assetAuditData!.responseData.categories['MMS'];
      if (mmsData != null && mmsData.remarks.isNotEmpty && remarksController.text.isEmpty) {
        remarksController.text = mmsData.remarks.first.itemTypeRemark ?? '';
      }
    }
  }

  void _saveFormDataToHive() {
    // No Hive storage - data is only stored in memory and posted to API
  }

  Future<void> _saveAndExit() async {
    try {
      await _postMMSData();
      // Add a small delay before navigation to prevent Navigator lock
      await Future.delayed(const Duration(milliseconds: 100));
      
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => HomeScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving data: $e'), 
            backgroundColor: Colors.red
          )
        );
      }
    }
  }

  Future<void> _updateAuditScheduleStatus(String status) async {
    try {
      await context.read<AuditScheduleStatusCubit>().updateStatus(status: status, siteAuditSchId: widget.siteAuditSchId);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update status: $e')));
    }
  }

  /// Format date for API (dd-MM-yyyy HH:mm format)
  String _formatDateForAPI(DateTime dateTime) {
    return '${dateTime.day.toString().padLeft(2, '0')}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  /// POST MMS remarks to the existing MMS item's item_type_remark field
  Future<void> _postMMSData() async {
    try {
      final assetAuditState = context.read<AssetAuditCubit>().state;
      if (assetAuditState is AssetAuditLoaded && assetAuditState.assetAuditData.pageHeader.isNotEmpty) {
        print('vishal: ${remarksController.text}');
        print('garg: $mmsAssets');
        // Check if we have MMS data and remarks to post
        if (remarksController.text.isNotEmpty && mmsAssets.isNotEmpty) {
          final mmsAsset = mmsAssets.first;
          
          // Create the post request for updating the MMS item with remarks
          final postRequest = AssetAuditPostRequest(
            assetAuditSiteRespId: mmsAsset.assetAuditSiteRespId,
            auditSchId: int.parse(widget.auditSchId),
            siteAuditSchId: int.parse(widget.siteAuditSchId),
            siteId: 0, // Default value, may need to be adjusted based on your data
            itemInstanceId: mmsAsset.itemInstanceId ?? 0,
            nexgenSerialNo: mmsAsset.nexgenSerialNo ?? '',
            itemTypeId: 6, // MMS item type ID
            qrCodeScanned: mmsAsset.qrCodeScanned ?? false,
            qrCodeScannedTs: mmsAsset.qrCodeScannedTs,
            photoId: mmsAsset.photoId,
            photoTakenTs: _formatDateForAPI(DateTime.now()),
            assetStatus: mmsAsset.assetStatus ?? 'OK',
            longitude: mmsAsset.longitude,
            latitude: mmsAsset.latitude,
            itemTypeRemark: remarksController.text, // Post the remarks here
            localAuditLogId: 0, // Default value
            localQrCodeScannedTs: _formatDateForAPI(DateTime.now()),
            localCreatedDt: _formatDateForAPI(DateTime.now()),
            localModifiedDt: _formatDateForAPI(DateTime.now()),
            syncProcessId: 0, // Default value
            isActive: true,
            remarks: remarksController.text, // Also add to remarks field
          );

          final currentRemarksText = remarksController.text;

          await context.read<AssetAuditCubit>().postAssetAuditData(requests: [postRequest]);

          // Don't refresh the entire dataset for just saving remarks
          // This prevents unnecessary image loading
          // context.read<AssetAuditCubit>().getAssetAuditData(
          //   siteType: widget.siteType,
          //   auditSchId: widget.auditSchId,
          //   siteAuditSchId: widget.siteAuditSchId,
          // );
          
          // Keep the remarks text as is since we're not refreshing
          print('MMS Screen: Remarks saved successfully: "$currentRemarksText"');
        } else {
          print('=== MMS POST: No remarks to post or no MMS data available ===');
        }
      }
    } catch (e) {
      print('Error posting MMS data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error posting MMS data: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  // Helper method to get the next available screen based on data availability
  String? _getNextAvailableScreen() {
    return AssetAuditNavigationHelper.getNextAvailableScreen(widget.assetAuditData, 'MMS');
  }

  // Helper method to get the previous available screen based on data availability
  String? _getPreviousAvailableScreen() {
    return AssetAuditNavigationHelper.getPreviousAvailableScreen(widget.assetAuditData, 'MMS');
  }

  // Helper method to navigate to the next screen based on screen name
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
    // Debug logging for MMS data
    print('=== MMS Screen Debug ===');
    print('AssetAuditData: ${widget.assetAuditData != null}');
    if (widget.assetAuditData != null) {
      print('Categories: ${widget.assetAuditData!.responseData.categories.keys}');
      final mmsCategory = widget.assetAuditData!.responseData.categories['MMS'];
      print('MMS Category: ${mmsCategory != null}');
      if (mmsCategory != null) {
        print('MMS Assets count: ${mmsCategory.assets.length}');
        print('MMS SubCategories: ${mmsCategory.subCategories?.keys}');
        print('MMS Assets from getter: ${mmsAssets.length}');
        if (mmsAssets.isNotEmpty) {
          print('First MMS asset oemName: ${mmsAssets.first.oemName}');
          print('First MMS asset capacity: ${mmsAssets.first.capacity}');
          print('First MMS asset ID: ${mmsAssets.first.assetAuditSiteRespId}');
        }
      }
    }
    print('=== End MMS Debug ===');
    
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: CustomFormAppbar(
        title: "MMS",
        onClose: () {
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
                if (mounted && Navigator.of(context).canPop()) {
                  Future.delayed(const Duration(milliseconds: 100), () {
                    if (mounted) {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                            builder: (context) => HomeScreen()
                        ),
                      );
                    }
                  });
                }
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
                        bottom:
                            MediaQuery.of(context).viewInsets.bottom + 120,
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
                              label: "MMS Make",
                              initialValue: mmsAssets.isNotEmpty 
                                  ? mmsAssets.first.oemName ?? "N/A"
                                  : "N/A",
                              isRequired: true,
                              isEditable: false,
                            ),
                            getHeight(15),
                            CustomFormField(
                              label: "Combined Capacity of MMS",
                              initialValue: mmsAssets.isNotEmpty 
                                  ? mmsAssets.first.capacity ?? "N/A"
                                  : "N/A",
                              isRequired: true,
                              isEditable: false,
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
                            text: 'MMS',
                            isLeftArrow: true,
                            backgroundColor: AppColors.buttonColorBackBg,
                            textColor: AppColors.buttonColorTextBg,
                            onPressed: () async {
                              final previousScreen = AssetAuditNavigationHelper.getPreviousAvailableScreen(widget.assetAuditData, 'MMS');
                              if (previousScreen != null) {
                                // Add safety checks for navigation
                                if (mounted) {
                                  await Future.delayed(const Duration(milliseconds: 100));
                                  if (mounted) {
                                    _navigateToNextScreen(context, previousScreen);
                                  }
                                }
                              } else {
                                // Add safety checks for pop navigation
                                if (mounted && Navigator.of(context).canPop()) {
                                  await Future.delayed(const Duration(milliseconds: 100));
                                  if (mounted) {
                                    Navigator.pop(context);
                                  }
                                }
                              }
                            },
                          ),
                        ),
                        getWidth(14),
                        Expanded(
                          child: ArrowButton(
                            text: _getNextAvailableScreen() ?? "Submit",
                            isLeftArrow: false,
                            backgroundColor: AppColors.buttonColorBg,
                            textColor: AppColors.buttonColorSite,
                            onPressed: () async {
                              try {
                                // Show loading indicator
                                showDialog(
                                  context: context,
                                  barrierDismissible: false,
                                  builder: (context) => const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                );

                                // Post data before navigating
                                await _postMMSData();

                                // Hide loading indicator with a small delay to ensure it's properly dismissed
                                if (mounted) {
                                  Navigator.of(context).pop();
                                  
                                  // Add a small delay to prevent Navigator lock
                                  await Future.delayed(const Duration(milliseconds: 100));
                                  
                                  final nextScreen = _getNextAvailableScreen();
                                  if (nextScreen != null) {
                                    _navigateToNextScreen(context, nextScreen);
                                  } else {
                                    // All screens completed, show success dialog
                                    await _saveAndExit();
                                  }
                                }
                              } catch (e) {
                                // Hide loading indicator if there's an error
                                if (mounted) {
                                  Navigator.of(context).pop();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Error: $e'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
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
    );
  }
}