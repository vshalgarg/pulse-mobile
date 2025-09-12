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

  const FencingScreen({
    super.key,
    this.fencingData,
    this.assetAuditData,
    this.showSuccessMessage = false,
    this.extinguisherItems,
    this.solarPlatesItems,
    this.surveillanceItems,
  });

  @override
  State<FencingScreen> createState() => _FencingScreenState();
}

class _FencingScreenState extends State<FencingScreen>
    with WidgetsBindingObserver {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController serialController = TextEditingController();
  String? selectedBoundaryAvailability;
  bool hasUnsavedChanges = false;
  bool showValidationErrors = false;
  int totalBoundaryItems = 1; // Only 1 fencing item needed
  int currentScannedItems = 0;
  String? uploadedPhotoPath;
  int? boundaryPhotoId; // Store the photoId from API

  // List to store saved boundary items (not needed for fencing)
  List<Map<String, dynamic>> savedBoundaryItems = [];

  // AssetTypeCard field values for Boundary
  String? boundarySerialNumber;
  String? boundaryPhoto;
  String? boundaryStatus;
  bool isBoundaryQRCodeScanned = false;

  // Controllers for CustomInfoCard
  final TextEditingController boundarySerialController =
      TextEditingController();
  final TextEditingController generalRemarksController =
      TextEditingController();

  // Keys to force rebuild of CustomInfoCard widgets
  int boundaryCardKey = 0;

  // Flag to track if Fencing screen has posted data
  bool _hasPostedFencingData = false;

  // Image loading infrastructure
  Map<int, String> _imageCache = {};
  Set<int> _loadingImages = {};

  @override
  void initState() {
    super.initState();
    serialController.addListener(_onFormChanged);
    boundarySerialController.addListener(_onFormChanged);
    generalRemarksController.addListener(_onFormChanged);

    // Check if we have data to show, if not, skip this screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_hasDataToShow()) {
        _navigateToDgScreen();
      } else {
        _loadFencingData();
        _hasPostedFencingData = false;
      }
    });
  }

  @override
  void dispose() {
    serialController.removeListener(_onFormChanged);
    boundarySerialController.removeListener(_onFormChanged);
    generalRemarksController.removeListener(_onFormChanged);
    serialController.dispose();
    boundarySerialController.dispose();
    generalRemarksController.dispose();

    _hasPostedFencingData = false;

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

  /// Navigate to next screen with current saved data
  void _navigateToNextScreen() {
    print('Fencing Screen: Navigating to next screen with saved data');
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
          fencingItems: [...savedBoundaryItems],
        ),
      ),
    );
  }

  void _loadFencingData() {
    if (widget.fencingData != null) {
      setState(() {
        print('=== Fencing Screen: Loading Boundary Data ===');
        print('fencingData type: ${widget.fencingData.runtimeType}');
        print('fencingData: ${widget.fencingData}');
        print(
          'Before loading - savedBoundaryItems count: ${savedBoundaryItems.length}',
        );

        // Clear existing saved items to avoid duplicates
        savedBoundaryItems.clear();
        currentScannedItems = 0;

        // Load Boundary assets from subCategories
        final boundaryAssets =
            widget.fencingData!.subCategories?['Boundary'] ??
            widget.fencingData!.assets;

        print('Fencing Screen: Found ${boundaryAssets.length} boundary assets');
        for (int i = 0; i < boundaryAssets.length; i++) {
          var item = boundaryAssets[i];
          print('Fencing Screen: Item $i:');
          print('  - assetAuditSiteRespId: ${item.assetAuditSiteRespId}');
          print('  - photoId: ${item.photoId}');
          print('  - assetStatus: ${item.assetStatus}');
          print('  - itemTypeRemark: ${item.itemTypeRemark}');
          print('  - recordType: ${item.recordType}');
        }

        // Find the first item with complete data to pre-populate the form
        AssetItem? completeItem;
        for (var item in boundaryAssets) {
          if (item.photoId != null && item.assetStatus != null) {
            completeItem = item;
            break; // Use the first complete item
          }
        }

        // Pre-populate form fields with the complete item data
        if (completeItem != null) {
          print('Fencing Screen: Pre-populating form with complete item data');
          print('  - photoId: ${completeItem.photoId}');
          print('  - assetStatus: ${completeItem.assetStatus}');
          print('  - itemTypeRemark: ${completeItem.itemTypeRemark}');

          // Set form field values
          boundaryPhotoId = completeItem.photoId;
          boundaryStatus = completeItem.assetStatus;
          boundarySerialNumber =
              completeItem.mfgSerialNo ??
              completeItem.nexgenSerialNo ??
              'FENCING-${DateTime.now().millisecondsSinceEpoch}';

          // Set the serial controller text
          boundarySerialController.text = boundarySerialNumber ?? '';

          // Set the remarks controller text
          if (completeItem.itemTypeRemark != null &&
              completeItem.itemTypeRemark!.isNotEmpty) {
            generalRemarksController.text = completeItem.itemTypeRemark!;
          }

          // Set the status for the form
          if (completeItem.assetStatus == "OK") {
            boundaryStatus = "OK";
          } else if (completeItem.assetStatus == "Not OK") {
            boundaryStatus = "Not OK";
          }

          // Set photo path to show existing photo (use photoId as placeholder)
          if (completeItem.photoId != null) {
            boundaryPhoto = 'photo_id_${completeItem.photoId}';
            // Load the actual photo from API
            _loadExistingPhoto(completeItem.photoId!);
          }

          // Force UI update by incrementing the card key
          boundaryCardKey++;

          print('Fencing Screen: Form pre-populated with:');
          print('  - boundaryPhotoId: $boundaryPhotoId');
          print('  - boundaryStatus: $boundaryStatus');
          print('  - boundarySerialNumber: $boundarySerialNumber');
          print('  - remarks: ${generalRemarksController.text}');
          print('  - boundaryCardKey updated to: $boundaryCardKey');
        }

        // Also store all items in savedBoundaryItems for reference
        for (var item in boundaryAssets) {
          if (item.photoId != null) {
            // Only include items with photoId
            Map<String, dynamic> savedItem = {
              'serialNumber':
                  item.mfgSerialNo ??
                  item.nexgenSerialNo ??
                  'FENCING-${DateTime.now().millisecondsSinceEpoch}',
              'photo': null,
              'photoId': item.photoId,
              'status': item.assetStatus ?? 'OK',
              'timestamp': DateTime.now(),
              'isQRCodeScanned': item.qrCodeScanned ?? false,
              'itemType': item.itemType ?? 'Boundary',
              'remarks': item.itemTypeRemark ?? 'Boundary Item',
              'assetStatus': item.assetStatus,
              'assetAuditSiteRespId': item.assetAuditSiteRespId,

              // Full API response details
              'asset_audit_site_resp_id': item.assetAuditSiteRespId,
              'site_audit_sch_id': item.siteAuditSchId,
              'item_instance_id': item.itemInstanceId,
              'oem_name': item.oemName,
              'nexgen_serial_no': item.nexgenSerialNo,
              'mfg_serial_no': item.mfgSerialNo,
              'qr_code_scanned': item.qrCodeScanned ?? false,
              'qr_code_scanned_ts': item.qrCodeScannedTs,
              'image_name': item.imageName,
              'longitude': item.longitude,
              'latitude': item.latitude,
              'item_type_group': item.itemTypeGroup,
              'record_type': item.recordType,
              'item_type_remark': item.itemTypeRemark,
            };
            savedBoundaryItems.add(savedItem);
            currentScannedItems++;
          }
        }

        // Update total count
        totalBoundaryItems = boundaryAssets.length;

        // Load remarks data from API and populate the CustomRemarksField
        final remarks = widget.fencingData!.remarks;
        if (remarks.isNotEmpty) {
          for (var remark in remarks) {
            if (remark.itemTypeRemark != null &&
                remark.itemTypeRemark!.isNotEmpty) {
              generalRemarksController.text = remark.itemTypeRemark!;
              break; // Use the first valid remark
            }
          }
        }

        print(
          'After loading - savedBoundaryItems count: ${savedBoundaryItems.length}',
        );
        print('Total boundary items from API: $totalBoundaryItems');
      });
    }
  }

  void _onFormChanged() {
    setState(() {
      hasUnsavedChanges =
          selectedBoundaryAvailability != null ||
          boundarySerialController.text.isNotEmpty ||
          generalRemarksController.text.isNotEmpty ||
          boundaryPhoto != null;

      if (showValidationErrors && _isFormValid()) {
        showValidationErrors = false;
      }
    });
  }

  void _saveAndExit() async {
    // First close the unsaved changes dialog
    Navigator.of(context).pop();

    try {
      await _postCurrentScreenData();

      // Update audit schedule status to "In Progress"
      if (mounted) {
        context.read<AuditScheduleStatusCubit>().updateStatus(
          siteAuditSchId:
              widget.assetAuditData?.pageHeader.first.siteAuditSchId
                  .toString() ??
              "",
          status: "IN-PROGRESS",
        );
      }
    } catch (e) {
      print('Error posting Extinguisher data: $e');
    }

    // Then show success dialog with a clean barrier
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => HomeScreen()),
      );
    }
  }

  // Validate required fields for saved items only
  bool _isFormValid() {
    // Only check photo for fencing (serial number is optional)
    int? photoId = boundaryPhotoId;
    if (photoId == null) {
      return false;
    }

    return true;
  }

  bool _validateForm() {
    setState(() {
      showValidationErrors = true;
    });

    // Check if photoId is available
    int? photoId = boundaryPhotoId;
    if (photoId == null) {
      return false;
    }

    return true;
  }

  // Check if user can proceed to next screen (no items required for fencing)
  bool _canProceedToNextScreen() {
    return true; // Always allow navigation for fencing
  }

  /// Get asset audit site response ID from GET API response for a specific item type
  int? _getAssetAuditSiteRespId(String itemType) {
    if (widget.assetAuditData != null) {
      final boundaryData =
          widget.assetAuditData!.responseData.categories['Boundary'];

      if (boundaryData != null) {
        if (boundaryData.assets.isNotEmpty) {
          // Use the first available Boundary asset ID
          final asset = boundaryData.assets.first;
          print(
            'Fencing Screen: Found Boundary asset ID: ${asset.assetAuditSiteRespId}',
          );
          return asset.assetAuditSiteRespId;
        }
      }
    }

    // Fallback: Use known asset IDs from API response
    print('Fencing Screen: Using fallback asset ID 1697');
    return 1697; // Use the first known asset ID from your API response
  }

  /// Check if the current success state is for Fencing screen data
  bool _isFencingScreenDataPosted() {
    return _hasPostedFencingData;
  }

  int? _getRemarksAssetAuditSiteRespId() {
    if (widget.assetAuditData == null) {
      return null;
    }

    final boundaryData =
        widget.assetAuditData!.responseData.categories['Boundary'];
    if (boundaryData != null) {
      // Check if there are remarks in the backend data
      final remarks = boundaryData.remarks;
      if (remarks.isNotEmpty) {
        // First try to find a general remarks entry (Boundary category is usually the main one)
        for (var remark in remarks) {
          if (remark.assetAuditSiteRespId != null &&
              remark.assetAuditSiteRespId > 0 &&
              remark.itemType == 'Boundary') {
            print(
              'Fencing Screen: Found Boundary remarks ID: ${remark.assetAuditSiteRespId}',
            );
            return remark.assetAuditSiteRespId;
          }
        }

        // Fallback: find any remarks entry with a valid ID
        for (var remark in remarks) {
          if (remark.assetAuditSiteRespId != null &&
              remark.assetAuditSiteRespId > 0) {
            print(
              'Fencing Screen: Found remarks ID: ${remark.assetAuditSiteRespId}',
            );
            return remark.assetAuditSiteRespId;
          }
        }
      }
    }

    print('Fencing Screen: No remarks ID found');
    return null;
  }

  /// Post current screen data to API before navigating to next screen
  Future<bool> _postCurrentScreenData() async {
    if (widget.assetAuditData == null) {
      print('Fencing Screen: No asset audit data available');
      return false;
    }

    try {
      // Create a list to hold all items to post
      List<Map<String, dynamic>> allItemsToPost = [];

      // Create fencing data from current form if we have a photo
      if (boundaryPhotoId != null) {
        // Get the asset ID directly from the API response
        int? assetId = _getAssetAuditSiteRespId('Boundary');
        print('Fencing Screen: Direct asset ID lookup: $assetId');

        Map<String, dynamic> fencingData = {
          'serialNumber':
              boundarySerialNumber ??
              'FENCING-${DateTime.now().millisecondsSinceEpoch}',
          'photo': boundaryPhoto,
          'photoId': boundaryPhotoId,
          'photoTakenTs': DateTime.now().toString(),
          'status': boundaryStatus ?? 'OK',
          'timestamp': DateTime.now(),
          'isQRCodeScanned': false,
          'itemType': 'Boundary',
          'remarks': generalRemarksController.text.isNotEmpty
              ? generalRemarksController.text
              : 'Boundary Item',
          'assetStatus': boundaryStatus ?? 'OK',
          'recordType': 'Boundary',
          'assetAuditSiteRespId': assetId, // Pass the asset ID directly
        };

        // Enhance the fencing data
        final enhancedFencingItems = AssetAuditPostHelper.enhanceSavedItems(
          savedItems: [fencingData],
          screenName: 'Boundary',
        );
        allItemsToPost.addAll(enhancedFencingItems);

        print('Fencing Screen: Created fencing data to post: $fencingData');
      }

      // Add user's general remarks if entered
      if (generalRemarksController.text.isNotEmpty) {
        // Find the appropriate remarks entry from backend data
        int? remarksAssetAuditSiteRespId = _getRemarksAssetAuditSiteRespId();

        if (remarksAssetAuditSiteRespId != null) {
          Map<String, dynamic> remarksData = {
            'itemType': 'Boundary',
            'remarks': generalRemarksController.text,
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
          print('Fencing Screen: Added remarks data to post');
        }
      }

      if (allItemsToPost.isEmpty) {
        print('Fencing Screen: No data to post');
        return false;
      }

      print('Fencing Screen: Posting ${allItemsToPost.length} items to API');

      // Convert to POST request format
      final requests =
          await AssetAuditPostHelper.convertSavedItemsToPostRequest(
            savedItems: allItemsToPost,
            assetAuditData: widget.assetAuditData!,
            itemType: 'Boundary',
            itemTypeId: AssetAuditPostHelper.getItemTypeId('Boundary'),
            screenName: 'Boundary',
            context: context,
            auditSchId: widget.assetAuditData?.pageHeader.first.siteAuditSchId
                .toString(),
          );

      if (requests.isEmpty) {
        print('Fencing Screen: No requests created');
        return false;
      }

      print('Fencing Screen: Created ${requests.length} requests to post');

      // Use the existing cubit to post data
      final cubit = context.read<AssetAuditCubit>();

      // Set flag BEFORE making the API call to ensure it's set when success state is received
      setState(() {
        _hasPostedFencingData = true;
      });
      print(
        'Fencing Screen: Set _hasPostedFencingData = true before posting data',
      );

      cubit.postAssetAuditData(requests: requests);
      print('Fencing Screen: Posted data to API');

      // Return true to indicate data is being posted
      return true;
    } catch (e) {
      print('Fencing Screen: Error posting data: $e');
      return false;
    }
  }

  // Format serial number to show first 5 digits + ...
  String _formatSerialNumber(String serialNumber) {
    if (serialNumber.length <= 7) {
      return serialNumber;
    }
    return "${serialNumber.substring(0, 5)}...";
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AssetAuditCubit, AssetAuditState>(
      listener: (context, state) {
        if (state is AssetAuditPostSuccess) {
          bool isFencingData = false;
          for (var response in state.responses) {
            // Primary check: itemTypeRemark contains Fencing-related text
            if (response.itemTypeRemark != null &&
                (response.itemTypeRemark!.contains('Boundary') ||
                    response.itemTypeRemark!.contains('Fencing'))) {
              isFencingData = true;
              break;
            }
            if (_hasPostedFencingData) {
              isFencingData = true;
              break;
            }
          }

          if (isFencingData) {
            // Refresh data from API before navigating
            try {
              context.read<AssetAuditCubit>().getAssetAuditData(
                siteType: widget.assetAuditData!.pageHeader.first.siteDomainName
                    .toString(),
                auditSchId:
                    widget.assetAuditData?.pageHeader.first.siteAuditSchId
                        .toString() ??
                    "0",
                siteAuditSchId:
                    widget.assetAuditData?.pageHeader.first.siteAuditSchId
                        .toString() ??
                    "0",
              );

              if (mounted) {
                try {
                  _navigateToNextScreen();
                  // Reset the flag after successful navigation
                  setState(() {
                    _hasPostedFencingData = false;
                  });
                } catch (e) {
                  print('Fencing Screen: Error navigating after success: $e');
                }
              }
            } catch (e) {
              if (mounted) {
                try {
                  _navigateToNextScreen();
                  setState(() {
                    _hasPostedFencingData = false;
                  });
                } catch (e) {
                  print(
                    'Fencing Screen: Error navigating after success fallback: $e',
                  );
                }
              }
            }
          }
        } else if (state is AssetAuditPostError) {
          // Only show error message if this error belongs to Fencing screen data
          if (_hasPostedFencingData) {
            // Show error message but don't block navigation completely
            showCustomToast(
              context,
              '❌ Failed to save Fencing data to server. You can continue with local data.',
            );

            // Reset the flag on error
            setState(() {
              _hasPostedFencingData = false;
            });
            print(
              'Fencing Screen: Reset _hasPostedFencingData flag to false after error',
            );
          }
        }
      },
      child: PopScope(
        canPop: !hasUnsavedChanges,
        onPopInvoked: (didPop) async {
          if (didPop) return;

          if (hasUnsavedChanges) {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => UnsavedChangesDialog(
                message:
                    "Do you want to cancel the Asset Audit for Site (ID: SITE-38974) ?",
                onSaveAndExit: () {
                  _saveAndExit();
                },
                onDiscard: () {
                  Navigator.of(context).pop();
                },
              ),
            );
          }
        },
        child: Scaffold(
          extendBodyBehindAppBar: true,
          resizeToAvoidBottomInset: false,
          appBar: CustomFormAppbar(
            title: "Asset Audit",
            onClose: () async {
              if (hasUnsavedChanges) {
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => UnsavedChangesDialog(
                    message:
                        "Do you want to cancel the Asset Audit for Site (ID: SITE-38974) ?",
                    onSaveAndExit: () {
                      _saveAndExit();
                    },
                    onDiscard: () {
                      Navigator.of(context).pop();
                    },
                  ),
                );
              } else {
                Navigator.pop(context);
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
                                if (_hasDataToShow()) ...[
                                  CustomOptionSelector(
                                    label: "Fencing/Boundary Available",
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
                                        selectedBoundaryAvailability = value;
                                        hasUnsavedChanges = true;
                                      });
                                    },
                                  ),
                                  getHeight(15),
                                  CustomInfoCard(
                                    key: ValueKey('boundary_$boundaryCardKey'),
                                    serialLabel: "Fencing / Boundary",
                                    serialHintText:
                                        "Fencing Serial Number (Optional)",
                                    photoLabel: "Add a Photo",
                                    statusLabel: "Status",
                                    serialController: boundarySerialController,
                                    isStatusEditable: true,
                                    showSaveButton: false,
                                    backendStatus: false,
                                    onPhotoTap: (photoPath) async {
                                      setState(() {
                                        boundaryPhoto = photoPath;
                                        hasUnsavedChanges = true;
                                      });

                                      // Upload photo immediately and get photoId
                                      if (photoPath != null &&
                                          photoPath.isNotEmpty) {
                                        try {
                                          final photoFile = File(photoPath);
                                          if (await photoFile.exists()) {
                                            // Get the cubit directly
                                            final photoUploadCubit = context
                                                .read<
                                                  AssetAuditPhotoUploadCubit
                                                >();

                                            // Upload photo
                                            await photoUploadCubit.uploadPhoto(
                                              file: photoFile,
                                              imgId: null,
                                              schId:
                                                  widget
                                                      .assetAuditData
                                                      ?.pageHeader
                                                      .first
                                                      .siteAuditSchId
                                                      .toString() ??
                                                  "0",
                                            );

                                            // Wait for state to update
                                            await Future.delayed(
                                              const Duration(milliseconds: 500),
                                            );

                                            // Check the result
                                            final state =
                                                photoUploadCubit.state;
                                            if (state
                                                is AssetAuditPhotoUploadSuccess) {
                                              final photoId =
                                                  int.tryParse(
                                                    state.response.imgId,
                                                  ) ??
                                                  0;
                                              if (photoId > 0) {
                                                setState(() {
                                                  boundaryPhotoId = photoId;
                                                });
                                              }
                                            } else if (state
                                                is AssetAuditPhotoUploadFailure) {
                                              print(
                                                'Fencing Screen: Photo upload failed: ${state.errorMessage}',
                                              );
                                            }
                                          }
                                        } catch (e) {
                                          print(
                                            'Fencing Screen: Error uploading photo: $e',
                                          );
                                        }
                                      }
                                    },
                                    onStatusChanged: (val) {
                                      setState(() {
                                        boundaryStatus = val ? "OK" : "Not OK";
                                        hasUnsavedChanges = true;
                                      });
                                    },
                                    onSerialChanged: (serialNumber) {
                                      setState(() {
                                        boundarySerialNumber = serialNumber;
                                        hasUnsavedChanges = true;
                                      });
                                    },
                                    initialStatus: boundaryStatus == "OK"
                                        ? true
                                        : (boundaryStatus == "Not OK"
                                              ? false
                                              : null),
                                    initialPhotoPath: boundaryPhoto,
                                    isEditable: true,
                                  ),
                                  getHeight(15),
                                  CustomRemarksField(
                                    label: "Add Remarks",
                                    hintText: "Remarks",
                                    controller: generalRemarksController,
                                  ),
                                ] else ...[
                                  _buildNoDataMessage(),
                                ],
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
                                text: "Surveillance",
                                isLeftArrow: true,
                                backgroundColor: AppColors.buttonColorBackBg,
                                textColor: AppColors.buttonColorTextBg,
                                onPressed: () {
                                  Navigator.pop(context);
                                },
                              ),
                            ),
                            getWidth(14),
                            Expanded(
                              child: ArrowButton(
                                text: _hasDataToShow() ? "DG" : "Skip Fencing",
                                isLeftArrow: false,
                                backgroundColor: AppColors.buttonColorBg,
                                textColor: AppColors.buttonColorSite,
                                onPressed: () async {
                                  // If no data to show, just navigate to next screen
                                  if (!_hasDataToShow()) {
                                    _navigateToDgScreen();
                                    return;
                                  }

                                  // No validation needed for fencing - always allow navigation

                                  // Always try to post data before navigation
                                  try {
                                    print(
                                      'Fencing Screen: Attempting to post data before navigation...',
                                    );

                                    // Set a timeout for the posting operation
                                    await Future.any([
                                      _postCurrentScreenData(),
                                      Future.delayed(Duration(seconds: 10), () {
                                        throw TimeoutException(
                                          'Posting data timed out',
                                          Duration(seconds: 10),
                                        );
                                      }),
                                    ]);

                                    // Navigation will be handled by the BlocListener on success
                                  } catch (e) {
                                    print(
                                      'Fencing Screen: Error posting data: $e',
                                    );
                                    // If posting fails or times out, still allow navigation with local data
                                    showCustomToast(
                                      context,
                                      '⚠️ Data could not be saved to server, but you can continue with local data.',
                                    );
                                    _navigateToNextScreen();
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
              // Full-screen loading overlay when posting data
              BlocBuilder<AssetAuditCubit, AssetAuditState>(
                builder: (context, state) {
                  if (state is AssetAuditPosting) {
                    return Container(
                      color: Colors.black.withOpacity(0.5),
                      child: const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
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

  /// Load existing photo from API
  Future<void> _loadExistingPhoto(int photoId) async {
    try {
      print('Fencing Screen: Loading existing photo with ID: $photoId');

      // Use the AssetAuditGetImageCubit to fetch the image
      final completer = Completer<String?>();
      late StreamSubscription subscription;

      subscription = context.read<AssetAuditGetImageCubit>().stream.listen((
        state,
      ) {
        if (state is AssetAuditGetImageSuccess && state.imageData.isNotEmpty) {
          print('Fencing Screen: Photo loaded successfully for ID: $photoId');
          final finalImageData = state.imageData.startsWith('data:image/')
              ? state.imageData
              : 'data:image/jpeg;base64,${state.imageData}';
          completer.complete(finalImageData);
          subscription.cancel();
        } else if (state is AssetAuditGetImageFailure) {
          print('Fencing Screen: Failed to load photo: ${state.errorMessage}');
          completer.complete(null);
          subscription.cancel();
        }
      });

      context.read<AssetAuditGetImageCubit>().getImage(
        imgId: photoId.toString(),
        schId:
            widget.assetAuditData?.pageHeader.first.siteAuditSchId
                ?.toString() ??
            '',
      );

      final imageData = await completer.future;

      if (imageData != null && mounted) {
        setState(() {
          boundaryPhoto = imageData;
          _imageCache[photoId] = imageData;
        });
        print('Fencing Screen: Photo set in UI: ${boundaryPhoto != null}');
      }
    } catch (e) {
      print('Fencing Screen: Error loading existing photo: $e');
    }
  }

  /// Build the "No Data" message widget
  Widget _buildNoDataMessage() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.info_outline,
            size: 64,
            color: AppColors.white.withOpacity(0.7),
          ),
          getHeight(16),
          Text(
            'No Fencing Data Available',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppColors.white,
              fontFamily: fontFamilyMontserrat,
            ),
            textAlign: TextAlign.center,
          ),
          getHeight(8),
          Text(
            'There are no Fencing items to audit for this site.',
            style: TextStyle(
              fontSize: 16,
              color: AppColors.white.withOpacity(0.8),
              fontFamily: fontFamilyMontserrat,
            ),
            textAlign: TextAlign.center,
          ),
          getHeight(16),
          Text(
            'You can proceed to the next screen or contact your administrator if you believe this is an error.',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.white.withOpacity(0.6),
              fontFamily: fontFamilyMontserrat,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
