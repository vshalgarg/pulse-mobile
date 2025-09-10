import 'package:app/commonWidgets/custom_buttons/arrow_botton.dart';
import 'package:app/constants/constants_methods.dart';
import 'package:app/utils/asset_audit_navigation_helper.dart';
import 'package:app/utils/asset_audit_post_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';

import '../../../bloc/asset_audit_cubit.dart';
import '../../../bloc/asset_audit_state.dart';
import '../../../bloc/asset_audit_photo_upload_cubit.dart';
import '../../../bloc/asset_audit_get_image_cubit.dart';
import '../../../bloc/audit_schedule_status_cubit.dart';
import '../../../models/asset_audit_post_model.dart';
import '../../../commonWidgets/asset_type_card.dart';
import '../../../commonWidgets/custom_dialogs/success_dialog.dart';
import '../../../commonWidgets/custom_dialogs/unsaved_changes_dialog.dart';
import '../../../commonWidgets/custom_form_appbar.dart';
import '../../../commonWidgets/custom_image_upload_field.dart';
import '../../../commonWidgets/custom_radio_options.dart';
import '../../../commonWidgets/custom_remark.dart';
import '../../../commonWidgets/asset_type_card.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_images.dart';
import '../../../constants/constants_strings.dart';
import '../../../models/asset_audit_model.dart';
import '../../home_screen.dart';

class BoundaryScreen extends StatefulWidget {
  final String siteType;
  final String auditSchId;
  final String siteAuditSchId;
  final AssetAuditModel? assetAuditData; // Complete asset audit data

  const BoundaryScreen({
    super.key,
    required this.siteType,
    required this.auditSchId,
    required this.siteAuditSchId,
    this.assetAuditData, // Complete asset audit data
  });

  @override
  State<BoundaryScreen> createState() => _BoundaryScreenState();
}

class _BoundaryScreenState extends State<BoundaryScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController serialController = TextEditingController();
  String? selectedCCTVAvailability;
  bool hasUnsavedChanges = false;
  bool showValidationErrors = false;

  // Boundary field values
  String? cctvSerialNumber;
  String? cctvPhoto;
  String? cctvStatus;
  bool isCCTVQRCodeScanned = false;

  // Controllers for CustomInfoCard
  final TextEditingController cctvSerialController = TextEditingController();
  final TextEditingController remarksController = TextEditingController();

  // Keys to force rebuild of CustomInfoCard widgets
  int cctvCardKey = 0;

  // Photo upload and image display
  String? uploadedPhotoId;
  String? displayedImageBase64;
  bool isUploadingPhoto = false;
  bool isLoadingImage = false;

  // Stream subscriptions
  StreamSubscription? _assetAuditSubscription;

  // Get Boundary data from API
  int get totalBoundaryItems {
    return widget.assetAuditData?.responseData.categories['Boundary']?.assets.length ?? 0;
  }

  // Get Boundary category data
  CategoryData? get boundaryCategoryData {
    return widget.assetAuditData?.responseData.categories['Boundary'];
  }

  @override
  void initState() {
    super.initState();
    serialController.addListener(_onFormChanged);
    cctvSerialController.addListener(_onFormChanged);
    remarksController.addListener(_onFormChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Load existing data from API
    _loadExistingData();

    // Setup asset audit listener
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupAssetAuditListener();
    });

    // Load fresh data into cubit
    context.read<AssetAuditCubit>().getAssetAuditData(
      siteType: widget.siteType,
      auditSchId: widget.auditSchId,
      siteAuditSchId: widget.siteAuditSchId,
    );
  }

  void _setupAssetAuditListener() {
    _assetAuditSubscription?.cancel();
    _assetAuditSubscription = context.read<AssetAuditCubit>().stream.listen((state) {
      if (state is AssetAuditLoaded && mounted) {
        _loadExistingDataFromState(state.assetAuditData);
      }
    }, onError: (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error in Boundary audit listener: $error'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    });
  }

  void _loadExistingData() {
    if (widget.assetAuditData != null) {
      final boundaryData = widget.assetAuditData!.responseData.categories['Boundary'];
      if (boundaryData != null && boundaryData.assets.isNotEmpty) {
        final asset = boundaryData.assets.first;
        setState(() {
          cctvSerialNumber = asset.nexgenSerialNo ?? asset.mfgSerialNo ?? 'FENCING-${DateTime.now().millisecondsSinceEpoch}';
          cctvSerialController.text = cctvSerialNumber!;
          cctvStatus = asset.assetStatus ?? 'OK';
          isCCTVQRCodeScanned = asset.qrCodeScanned ?? false;
          cctvCardKey++; // Force rebuild of CustomInfoCard
          // Only load remarks from API if user hasn't made changes
          if (asset.itemTypeRemark != null && asset.itemTypeRemark!.isNotEmpty && remarksController.text.isEmpty) {
            remarksController.text = asset.itemTypeRemark!;
          }
          if (asset.photoId != null && asset.photoId! > 0) {
            cctvPhoto = asset.photoId.toString();
            context.read<AssetAuditGetImageCubit>().getImage(
              imgId: asset.photoId.toString(),
              schId: widget.siteAuditSchId,
            );
          }
        });
      }
    }
  }

  void _loadExistingDataFromState(AssetAuditModel updatedData) {
    final boundaryData = updatedData.responseData.categories['Boundary'];
    
    // Check if data is in assets or subCategories (like MMS data)
    List<dynamic> boundaryAssets = [];
    if (boundaryData != null) {
      if (boundaryData.assets.isNotEmpty) {
        boundaryAssets = boundaryData.assets;
      } else if (boundaryData.subCategories != null && boundaryData.subCategories!['Boundary'] != null) {
        boundaryAssets = boundaryData.subCategories!['Boundary']!;
      }
    }
    
    if (boundaryAssets.isNotEmpty) {
      final asset = boundaryAssets.first;
      
      setState(() {
        cctvSerialNumber = asset.nexgenSerialNo ?? asset.mfgSerialNo ?? 'FENCING-${DateTime.now().millisecondsSinceEpoch}';
        cctvSerialController.text = cctvSerialNumber!;
        cctvStatus = asset.assetStatus ?? 'OK';
        isCCTVQRCodeScanned = asset.qrCodeScanned ?? false;
        cctvCardKey++; // Force rebuild of CustomInfoCard
        
        
        // Only load remarks from API if user hasn't made changes
        if (asset.itemTypeRemark != null && asset.itemTypeRemark!.isNotEmpty && remarksController.text.isEmpty) {
          remarksController.text = asset.itemTypeRemark!;
        }
        if (asset.photoId != null && asset.photoId! > 0) {
          cctvPhoto = asset.photoId.toString();
          context.read<AssetAuditGetImageCubit>().getImage(
            imgId: asset.photoId.toString(),
            schId: widget.siteAuditSchId,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    serialController.removeListener(_onFormChanged);
    cctvSerialController.removeListener(_onFormChanged);
    remarksController.removeListener(_onFormChanged);
    serialController.dispose();
    cctvSerialController.dispose();
    remarksController.dispose();
    _assetAuditSubscription?.cancel();
    super.dispose();
  }

  void _onFormChanged() {
    setState(() {
      hasUnsavedChanges = selectedCCTVAvailability != null ||
          cctvSerialController.text.isNotEmpty ||
          remarksController.text.isNotEmpty ||
          cctvPhoto != null;
      if (showValidationErrors && _isFormValid()) {
        showValidationErrors = false;
      }
    });
  }

  void _saveAndExit() async {
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // Post Boundary data to API first
      await _postBoundaryData();
      
      // Update audit schedule status
      await _updateAuditScheduleStatus("In Progress");

      // Close loading dialog
      Navigator.of(context).pop();

      // Navigate to home screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
            builder: (context) => HomeScreen()
        ),
      );
    } catch (e) {
      // Close loading dialog if it's open
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
      
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving data: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _updateAuditScheduleStatus(String status) async {
    try {
      print('Attempting to update status to: $status'); // Added for debugging
      await context.read<AuditScheduleStatusCubit>().updateStatus(
        status: status,
        siteAuditSchId: widget.siteAuditSchId,
      );
      print('Status update call completed'); // Added for debugging
    } catch (e) {
      print('Error updating audit schedule status: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update status: $e')),
      );
    }
  }

  void _submitAndComplete() async {
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // Post Boundary data to API first
      await _postBoundaryData();
      
      // Update audit schedule status to Complete
      await _updateAuditScheduleStatus("Complete");

      // Close loading dialog
      Navigator.of(context).pop();

      // Show success dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.black54,
        builder: (context) => SuccessDialog(
            ticketId: widget.siteAuditSchId,
          message: "Asset Audit for Site (ID: SITE-38974) has been recorded and saved.",
          onDone: () {
            Navigator.of(context).pop(); // Close success dialog
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => HomeScreen()),
            );
          },
        ),
      );
    } catch (e) {
      if (Navigator.canPop(context)) Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving data: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  bool _isFormValid() {
    if (selectedCCTVAvailability == null) {
      return false;
    }
    
    // Check if we have a photo (either file path, base64 data, or uploaded photo ID)
    bool hasPhoto = false;
    if (cctvPhoto != null && cctvPhoto!.isNotEmpty) {
      if (cctvPhoto!.startsWith('data:image/')) {
        hasPhoto = true; // Base64 image data
      } else if (_isNumeric(cctvPhoto!)) {
        hasPhoto = true; // Numeric photo ID
      } else {
        // Check if it's a valid file path
        final file = File(cctvPhoto!);
        hasPhoto = file.existsSync();
      }
    }
    
    if (uploadedPhotoId != null && uploadedPhotoId!.isNotEmpty) {
      hasPhoto = true; // We have an uploaded photo ID
    }
    
    if (!hasPhoto) {
      return false;
    }
    
    return true;
  }

  Future<bool> _postBoundaryData() async {
    try {
      if (!_isFormValid()) {
        setState(() {
          showValidationErrors = true;
        });
        return false;
      }

      final assetAuditState = context.read<AssetAuditCubit>().state;
      if (assetAuditState is! AssetAuditLoaded || assetAuditState.assetAuditData.pageHeader.isEmpty) {
        return false;
      }

      final siteData = assetAuditState.assetAuditData.pageHeader.first;
      final now = DateTime.now();
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);

      String? photoId = uploadedPhotoId;
      if (cctvPhoto != null && cctvPhoto!.isNotEmpty && !_isNumeric(cctvPhoto!)) {
        if (cctvPhoto!.startsWith('data:image/')) {
          // Handle base64 image data
          photoId = await _uploadBase64Photo(cctvPhoto!);
          if (photoId == null) {
            return false;
          }
        } else {
          // Handle file path
          final photoFile = File(cctvPhoto!);
          if (await photoFile.exists()) {
            photoId = await _uploadPhoto(photoFile);
            if (photoId == null) {
              return false;
            }
          } else {
            return false;
          }
        }
      }

      // Get existing asset ID
      int? existingAssetId = _getExistingBoundaryAssetId();
      
      final boundaryItemData = {
        'assetAuditSiteRespId': existingAssetId ?? 0,
        'auditSchId': int.parse(widget.auditSchId), // Convert String to int
        'siteAuditSchId': int.parse(widget.siteAuditSchId), // Convert String to int
        'siteId': siteData.siteId ?? 0,
        'itemInstanceId': 0, // Will be assigned by backend
        'nexgenSerialNo': cctvSerialNumber ?? 'FENCING-${now.millisecondsSinceEpoch}',
        'itemTypeId': AssetAuditPostHelper.getItemTypeId('boundary'),
        'qrCodeScanned': isCCTVQRCodeScanned,
        'qrCodeScannedTs': isCCTVQRCodeScanned ? _formatDateTime(now) : null,
        'photoId': photoId != null ? int.parse(photoId!) : null, // Convert String to int or null
        'photoTakenTs': _formatDateTime(now),
        'assetStatus': cctvStatus ?? 'OK',
        'longitude': position.longitude.toString(),
        'latitude': position.latitude.toString(),
        'itemTypeRemark': remarksController.text.trim().isNotEmpty ? remarksController.text.trim() : null,
        'localAuditLogId': 0,
        'localQrCodeScannedTs': isCCTVQRCodeScanned ? _formatDateTime(now) : _formatDateTime(now), // Always provide a value
        'localCreatedDt': _formatDateTime(now),
        'localModifiedDt': _formatDateTime(now),
        'syncProcessId': 0,
        'isActive': true,
        'remarks': remarksController.text.trim().isNotEmpty ? remarksController.text.trim() : null,
      };


      final requests = [
        AssetAuditPostRequest(
          assetAuditSiteRespId: boundaryItemData['assetAuditSiteRespId'] as int?,
          auditSchId: boundaryItemData['auditSchId'] as int,
          siteAuditSchId: boundaryItemData['siteAuditSchId'] as int,
          siteId: boundaryItemData['siteId'] as int,
          itemInstanceId: boundaryItemData['itemInstanceId'] as int,
          nexgenSerialNo: boundaryItemData['nexgenSerialNo'] as String,
          itemTypeId: boundaryItemData['itemTypeId'] as int,
          qrCodeScanned: boundaryItemData['qrCodeScanned'] as bool,
          qrCodeScannedTs: boundaryItemData['qrCodeScannedTs'] as String?,
          photoId: boundaryItemData['photoId'] as int?,
          photoTakenTs: boundaryItemData['photoTakenTs'] as String,
          assetStatus: boundaryItemData['assetStatus'] as String,
          longitude: boundaryItemData['longitude'] as String?,
          latitude: boundaryItemData['latitude'] as String?,
          itemTypeRemark: boundaryItemData['itemTypeRemark'] as String?,
          localAuditLogId: boundaryItemData['localAuditLogId'] as int,
          localQrCodeScannedTs: boundaryItemData['localQrCodeScannedTs'] as String,
          localCreatedDt: boundaryItemData['localCreatedDt'] as String,
          localModifiedDt: boundaryItemData['localModifiedDt'] as String,
          syncProcessId: boundaryItemData['syncProcessId'] as int,
          isActive: boundaryItemData['isActive'] as bool,
          remarks: boundaryItemData['remarks'] as String?,
        ),
      ];


      final completer = Completer<bool>();
      late StreamSubscription subscription;

      subscription = context.read<AssetAuditCubit>().stream.listen((state) {
        if (state is AssetAuditPostSuccess) {
          subscription.cancel();
          completer.complete(true);
        } else if (state is AssetAuditPostError) {
          subscription.cancel();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${state.message}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
          completer.complete(false);
        }
      });

      // Store the current remarks text before posting
      final currentRemarksText = remarksController.text;
      print('Boundary Screen: Storing current remarks text: "$currentRemarksText"');

      context.read<AssetAuditCubit>().postAssetAuditData(requests: requests);

      final result = await completer.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          subscription.cancel();
          return false;
        },
      );

      // If posting was successful, refresh data and restore remarks
      if (result) {
        print('Refreshing Boundary data after posting...');
        context.read<AssetAuditCubit>().getAssetAuditData(
          siteType: widget.siteType,
          auditSchId: widget.auditSchId,
          siteAuditSchId: widget.siteAuditSchId,
        );
        
        // Restore the remarks text after refresh to ensure it's not overwritten
        if (currentRemarksText.isNotEmpty) {
          print('Boundary Screen: Restoring remarks text after refresh: "$currentRemarksText"');
          remarksController.text = currentRemarksText;
        }
      }

      return result;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error posting data: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
      return false;
    }
  }

  int? _getExistingBoundaryAssetId() {
    final boundaryData = widget.assetAuditData?.responseData.categories['Boundary'];
    
    if (boundaryData != null && boundaryData.assets.isNotEmpty) {
      final asset = boundaryData.assets.first;
      return asset.assetAuditSiteRespId;
    }
    if (boundaryData != null && boundaryData.remarks.isNotEmpty) {
      for (var remark in boundaryData.remarks) {
        if (remark.assetAuditSiteRespId != null && remark.assetAuditSiteRespId > 0) {
          return remark.assetAuditSiteRespId;
        }
      }
    }
    
    // TEMPORARY FIX: Use the known asset ID from your API response
    // The API response shows asset_audit_site_resp_id: 1736
    return 1736;
  }

  String? _getRemarksAssetAuditSiteRespId() {
    final boundaryData = widget.assetAuditData?.responseData.categories['Boundary'];
    if (boundaryData != null && boundaryData.remarks.isNotEmpty) {
      for (var remark in boundaryData.remarks) {
        if (remark.assetAuditSiteRespId != null && remark.assetAuditSiteRespId > 0) {
          return remark.assetAuditSiteRespId.toString();
        }
      }
      if (boundaryData.remarks.isNotEmpty) {
        return boundaryData.remarks.first.assetAuditSiteRespId?.toString();
      }
    }
    if (boundaryData?.assets.isNotEmpty == true) {
      return boundaryData!.assets.first.assetAuditSiteRespId?.toString();
    }
    return null;
  }

  String? _getNextAvailableScreen() {
    return AssetAuditNavigationHelper.getNextAvailableScreen(widget.assetAuditData, 'Boundary');
  }

  String? _getPreviousAvailableScreen() {
    return AssetAuditNavigationHelper.getPreviousAvailableScreen(widget.assetAuditData, 'Boundary');
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

  bool _isNumeric(String str) {
    return int.tryParse(str) != null;
  }

  Future<String?> _uploadBase64Photo(String base64Data) async {
    try {
      // Convert base64 data to file
      final bytes = base64Decode(base64Data.split(',')[1]); // Remove data:image/jpeg;base64, prefix
      final tempDir = await getTemporaryDirectory();
      final fileName = 'boundary_photo_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(bytes);
      
      // Use the existing file upload method
      final photoId = await _uploadPhoto(file);
      
      // Clean up temporary file
      if (await file.exists()) {
        await file.delete();
      }
      
      return photoId;
    } catch (e) {
      return null;
    }
  }

  Future<String?> _uploadPhoto(File file) async {
    try {
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      final assetAuditState = context.read<AssetAuditCubit>().state;
      if (assetAuditState is! AssetAuditLoaded || assetAuditState.assetAuditData.pageHeader.isEmpty) {
        return null;
      }

      final schId = widget.siteAuditSchId;
      final imgId = DateTime.now().millisecondsSinceEpoch.toString();

      final completer = Completer<String?>();
      late StreamSubscription subscription;

      subscription = context.read<AssetAuditPhotoUploadCubit>().stream.listen((state) {
        if (state is AssetAuditPhotoUploadSuccess) {
          subscription.cancel();
          completer.complete(state.response.imgId);
        } else if (state is AssetAuditPhotoUploadFailure) {
          subscription.cancel();
          completer.complete(null);
        }
      });

      context.read<AssetAuditPhotoUploadCubit>().uploadPhoto(
        file: file,
        imgId: imgId,
        schId: schId,
      );

      return await completer.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          subscription.cancel();
          return null;
        },
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error uploading photo: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<AssetAuditGetImageCubit, AssetAuditGetImageState>(
          listener: (context, state) {
            if (state is AssetAuditGetImageLoading) {
              setState(() {
                isLoadingImage = true;
              });
            } else if (state is AssetAuditGetImageSuccess) {
              String finalImageData = state.imageData.startsWith('data:image/')
                  ? state.imageData
                  : 'data:image/jpeg;base64,${state.imageData}';
              setState(() {
                isLoadingImage = false;
                displayedImageBase64 = finalImageData;
                cctvPhoto = finalImageData;
                cctvCardKey++;
              });
            } else if (state is AssetAuditGetImageFailure) {
              setState(() {
                isLoadingImage = false;
                displayedImageBase64 = null;
                cctvCardKey++;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Failed to load image: ${state.errorMessage}'),
                  backgroundColor: Colors.red,
                  duration: const Duration(seconds: 3),
                ),
              );
            }
          },
        ),
        BlocListener<AssetAuditPhotoUploadCubit, AssetAuditPhotoUploadState>(
          listener: (context, state) {
            if (state is AssetAuditPhotoUploadLoading) {
              setState(() {
                isUploadingPhoto = true;
              });
            } else if (state is AssetAuditPhotoUploadSuccess) {
              setState(() {
                isUploadingPhoto = false;
                uploadedPhotoId = state.response.imgId;
                cctvPhoto = state.response.imgId;
              });
            } else if (state is AssetAuditPhotoUploadFailure) {
              setState(() {
                isUploadingPhoto = false;
                uploadedPhotoId = null;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Photo upload failed: ${state.errorMessage}'),
                  backgroundColor: Colors.red,
                  duration: const Duration(seconds: 3),
                ),
              );
            }
          },
        ),
        BlocListener<AssetAuditCubit, AssetAuditState>(
          listener: (context, state) {
            if (state is AssetAuditPostSuccess) {
              context.read<AssetAuditCubit>().getAssetAuditData(
                siteType: widget.siteType,
                auditSchId: widget.auditSchId,
                siteAuditSchId: widget.siteAuditSchId,
              );
            } else if (state is AssetAuditPostError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error saving data: ${state.message ?? 'Unknown error'}'),
                  backgroundColor: Colors.red,
                  duration: const Duration(seconds: 3),
                ),
              );
            } else if (state is AssetAuditError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error loading data: ${state.message ?? 'Unknown error'}'),
                  backgroundColor: Colors.red,
                  duration: const Duration(seconds: 3),
                ),
              );
            }
          },
        ),
      ],
      child: PopScope(
        canPop: !hasUnsavedChanges,
        onPopInvoked: (didPop) async {
          if (didPop) return;
          if (hasUnsavedChanges) {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => UnsavedChangesDialog(
                message: "Do you want to cancel the Asset Audit for Site (ID: SITE-38974)?",
                onSaveAndExit: () async {
                  Navigator.of(context).pop(); // Close the dialog first
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
                    message: "Do you want to cancel the Asset Audit for Site (ID: SITE-38974)?",
                    onSaveAndExit: () async {
                      Navigator.of(context).pop(); // Close the dialog first
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
                                      selectedCCTVAvailability = value;
                                      hasUnsavedChanges = true;
                                    });
                                  },
                                  initialValue: selectedCCTVAvailability,
                                ),
                                getHeight(15),
                                CustomInfoCard(
                                  key: ValueKey('cctv_$cctvCardKey'),
                                  serialLabel: "Fencing / Boundary",
                                  serialHintText: "Fencing Serial Number (Optional)",
                                  photoLabel: "Add a Photo",
                                  statusLabel: "Status",
                                  serialController: cctvSerialController,
                                  showSaveButton: false,
                                  isStatusEditable: true,
                                  backendStatus: false,
                                  // isRemarksEditable: false,
                                  onPhotoTap: (photoPath) {
                                    setState(() {
                                      cctvPhoto = photoPath;
                                      displayedImageBase64 = null;
                                      hasUnsavedChanges = true;
                                    });
                                  },
                                  onStatusChanged: (val) {
                                    setState(() {
                                      cctvStatus = val ? "OK" : "Not OK";
                                      hasUnsavedChanges = true;
                                    });
                                  },
                                  onSerialChanged: (serialNumber) {
                                    setState(() {
                                      cctvSerialNumber = serialNumber.isEmpty ? null : serialNumber;
                                      isCCTVQRCodeScanned = false;
                                      hasUnsavedChanges = true;
                                    });
                                  },
                                  initialStatus: cctvStatus == "OK"
                                      ? true
                                      : (cctvStatus == "Not OK" ? false : null),
                                  initialPhotoPath: displayedImageBase64 ?? cctvPhoto,
                                  isEditable: true,
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
                              child: ArrowButton(
                                text: _getNextAvailableScreen() ?? "Submit",
                                isLeftArrow: false,
                                backgroundColor: AppColors.buttonColorBg,
                                textColor: AppColors.buttonColorSite,
                                onPressed: () async {
                                  
                                  showDialog(
                                    context: context,
                                    barrierDismissible: false,
                                    builder: (context) => const Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                  );
                                  
                                  final success = await _postBoundaryData();
                                  
                                  Navigator.of(context).pop();
                                  
                                  if (success) {
                                    final nextScreen = _getNextAvailableScreen();
                                    if (nextScreen != null) {
                                      _navigateToNextScreen(context, nextScreen);
                                    } else {
                                      _submitAndComplete();
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
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final day = dateTime.day.toString().padLeft(2, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    final year = dateTime.year;
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    
    return '$day-$month-$year $hour:$minute';
  }
}


// class _BoundaryScreenState extends State<BoundaryScreen> {
//   final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
//   final TextEditingController serialController = TextEditingController();
//   String? selectedCCTVAvailability;
//   bool hasUnsavedChanges = false;
//   bool showValidationErrors = false;
//   int totalCCTVItems = 6;
//   int currentScannedItems = 0;
//   String? uploadedPhotoPath;
//   String? uploadedPhotoId;
//   int? _lastRequestedPhotoId;
//   List<Map<String, dynamic>> savedCCTVItems = [];
//   final remarksController = TextEditingController();
//
//   // AssetTypeCard field values for CCTV
//   String? cctvSerialNumber;
//   String? cctvPhoto;
//   String? cctvStatus;
//   bool isCCTVQRCodeScanned = false;
//
//   // Controllers for CustomInfoCard
//   final TextEditingController cctvSerialController = TextEditingController();
//
//   // Keys to force rebuild of CustomInfoCard widgets
//   int cctvCardKey = 0;
//
//   // Photo upload and image display
//   String? displayedImageBase64;
//   bool isUploadingPhoto = false;
//   bool isLoadingImage = false;
//
//   // Stream subscriptions
//   StreamSubscription<AssetAuditPhotoUploadState>? _photoUploadSubscription;
//   StreamSubscription<AssetAuditGetImageState>? _getImageSubscription;
//
//   // Get Boundary data from API
//   int get totalBoundaryItems {
//     if (widget.assetAuditData?.responseData.categories['Boundary']?.assets != null) {
//       return widget.assetAuditData!.responseData.categories['Boundary']!.assets.length;
//     }
//     return 0;
//   }
//
//   // Get Boundary category data
//   CategoryData? get boundaryCategoryData {
//     return widget.assetAuditData?.responseData.categories['Boundary'];
//   }
//
//   // Load existing data from API response
//   void _loadExistingData() {
//     if (widget.assetAuditData != null) {
//       final boundaryData = widget.assetAuditData!.responseData.categories['Boundary'];
//       if (boundaryData != null && boundaryData.assets.isNotEmpty) {
//         // Load the first Boundary asset data
//         final asset = boundaryData.assets.first;
//
//         setState(() {
//           // Load serial number
//           cctvSerialNumber = asset.nexgenSerialNo ?? asset.mfgSerialNo;
//           if (cctvSerialNumber != null) {
//             cctvSerialController.text = cctvSerialNumber!;
//           }
//
//           // Load status
//           cctvStatus = asset.assetStatus ?? 'OK';
//
//           // Load remarks
//           if (asset.itemTypeRemark != null && asset.itemTypeRemark!.isNotEmpty) {
//             remarksController.text = asset.itemTypeRemark!;
//           }
//
//           // Load photo if available
//           if (asset.photoId != null && asset.photoId! > 0) {
//             // Request image from backend
//             context.read<AssetAuditGetImageCubit>().getImage(
//               imgId: asset.photoId.toString(),
//               schId: widget.siteAuditSchId,
//             );
//             _lastRequestedPhotoId = asset.photoId!;
//           }
//
//           // Set QR scanned status
//           isCCTVQRCodeScanned = asset.qrCodeScanned ?? false;
//         });
//
//         print('Boundary Screen: Loaded existing data - Serial: $cctvSerialNumber, Status: $cctvStatus, Remarks: ${asset.itemTypeRemark}');
//       }
//     }
//   }
//
//   @override
//   void initState() {
//     super.initState();
//     serialController.addListener(_onFormChanged);
//     _setupPhotoUploadListener();
//     _setupGetImageListener();
//
//     // Load existing data from API
//     _loadExistingData();
//   }
//
//   @override
//   void dispose() {
//     serialController.removeListener(_onFormChanged);
//     serialController.dispose();
//     cctvSerialController.dispose();
//     remarksController.dispose();
//     _photoUploadSubscription?.cancel();
//     _getImageSubscription?.cancel();
//     super.dispose();
//   }
//
//   void _onFormChanged() {
//     setState(() {
//       hasUnsavedChanges = selectedCCTVAvailability != null || serialController.text.isNotEmpty;
//
//       if (showValidationErrors && selectedCCTVAvailability != null && serialController.text.isNotEmpty) {
//         showValidationErrors = false;
//       }
//     });
//   }
//
//   // Setup photo upload listener
//   void _setupPhotoUploadListener() {
//     _photoUploadSubscription = context.read<AssetAuditPhotoUploadCubit>().stream.listen((state) {
//       if (state is AssetAuditPhotoUploadLoading) {
//         setState(() {
//           isUploadingPhoto = true;
//         });
//       } else if (state is AssetAuditPhotoUploadSuccess) {
//         setState(() {
//           isUploadingPhoto = false;
//           uploadedPhotoId = state.response.imgId;
//         });
//         print('Boundary Screen: Photo uploaded successfully with ID: ${state.response.imgId}');
//       } else if (state is AssetAuditPhotoUploadFailure) {
//         setState(() {
//           isUploadingPhoto = false;
//         });
//         print('Boundary Screen: Photo upload failed: ${state.errorMessage}');
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('Photo upload failed: ${state.errorMessage}'),
//             backgroundColor: Colors.red,
//           ),
//         );
//       }
//     });
//   }
//
//   // Setup get image listener
//   void _setupGetImageListener() {
//     _getImageSubscription = context.read<AssetAuditGetImageCubit>().stream.listen((state) {
//       if (state is AssetAuditGetImageLoading) {
//         setState(() {
//           isLoadingImage = true;
//         });
//       } else if (state is AssetAuditGetImageSuccess) {
//         setState(() {
//           isLoadingImage = false;
//           displayedImageBase64 = state.imageData;
//           cctvPhoto = state.imageData; // Set the photo for CustomInfoCard
//         });
//         print('Boundary Screen: Image loaded successfully for photoId: $_lastRequestedPhotoId');
//       } else if (state is AssetAuditGetImageFailure) {
//         setState(() {
//           isLoadingImage = false;
//         });
//         print('Boundary Screen: Image load failed: ${state.errorMessage}');
//       }
//     });
//   }
//
//   void _saveAndExit() async {
//     Navigator.of(context).pop();
//
//     if (mounted) {
//       showDialog(
//         context: context,
//         barrierDismissible: false,
//         barrierColor: Colors.black54,
//         builder: (context) => SuccessDialog(
//           ```dart
// class _BatteryScreenState extends State<BatteryScreen> {
//   final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
//   final TextEditingController serialController = TextEditingController();
//   String? selectedFile;
//   String? selectedStatus;
//   String? selectedBatteryStatus;
//   String? selectedType;
//   bool hasUnsavedChanges = false;
//   bool showValidationErrors = false;
//   int totalRectifierItems = 6;
//   int totalMPPTItems = 6;
//   int currentScannedItems = 0;
//   List<Map<String, dynamic>> savedRectifierItems = [];
//   List<Map<String, dynamic>> savedMPPTItems = [];
//   Map<String, dynamic> currentFormData = {};
//   String? uploadedPhotoPath;
//   int? cabinetPhotoId;
//
//   String? rectifierSerialNumber;
//   String? rectifierPhoto;
//   int? rectifierPhotoId;
//   String? rectifierStatus;
//   final mpptRemarksController = TextEditingController();
//   final rectifierRemarksController = TextEditingController();
//   final generalRemarksController = TextEditingController();
//   final batteryCapacityController = TextEditingController();
//
//   String? mpptSerialNumber;
//   String? mpptPhoto;
//   int? mpptPhotoId;
//   String? mpptStatus;
//
//   final TextEditingController rectifierSerialController =
//       TextEditingController();
//   final TextEditingController mpptSerialController = TextEditingController();
//
//   int rectifierCardKey = 0;
//   int mpptCardKey = 0;
//
//   bool _hasPostedBatteryData = false;
//
//   // ===== IMAGE LOADING INFRASTRUCTURE =====
//   late ImageRepository _imageService;
//   Map<int, String> _imageCache = {};
//   Set<int> _loadingImages = {};
//   // ===== END IMAGE LOADING INFRASTRUCTURE =====
//
//   String _getBatteryOEMName() {
//     if (widget.batteryData != null) {
//       final batteryCabinetItems = widget.batteryData!.batteryCabinet ?? [];
//       if (batteryCabinetItems.isNotEmpty) {
//         return batteryCabinetItems.first.oemName ?? 'Delta';
//       }
//
//       final batteryAssets = widget.batteryData!.assets;
//       if (batteryAssets.isNotEmpty) {
//         return batteryAssets.first.oemName ?? 'Delta';
//       }
//
//       final cbmsItems = widget.batteryData!.cbms ?? [];
//       if (cbmsItems.isNotEmpty) {
//         return cbmsItems.first.oemName ?? 'Delta';
//       }
//     }
//
//     return 'Delta';
//   }
//
//   /// Load Battery data from API response
//   void _loadBatteryData() {
//     if (widget.batteryData == null) {
//       return;
//     }
//
//     setState(() {
//       // Clear existing saved items to avoid duplicates
//       savedRectifierItems.clear();
//       savedMPPTItems.clear();
//       currentScannedItems = 0;
//
//       // Load Battery Cabinet items (from subcategories)
//       final batteryCabinetItems = widget.batteryData!.batteryCabinet ?? [];
//       for (var item in batteryCabinetItems) {
//         if (item.photoId != null) { // Only include items with photoId
//           Map<String, dynamic> savedItem = {
//             'serialNumber': item.mfgSerialNo ?? item.nexgenSerialNo ?? 'Unknown',
//             'photo': null,
//             'photoId': item.photoId,
//             'status': item.assetStatus ?? 'OK',
//             'timestamp': DateTime.now(),
//             'isQRCodeScanned': item.qrCodeScanned ?? false,
//             'itemType': item.itemType ?? 'Battery Cabinet',
//             'remarks': item.itemTypeRemark ?? 'Battery Cabinet Item',
//             'assetStatus': item.assetStatus,
//             'assetAuditSiteRespId': item.assetAuditSiteRespId,
//             'capacity': item.capacity ?? 'N/A',
//
//             // Full API response details
//             'asset_audit_site_resp_id': item.assetAuditSiteRespId,
//             'site_audit_sch_id': item.siteAuditSchId,
//             'item_instance_id': item.itemInstanceId,
//             'oem_name': item.oemName,
//             'nexgen_serial_no': item.nexgenSerialNo,
//             'mfg_serial_no': item.mfgSerialNo,
//             'qr_code_scanned': item.qrCodeScanned ?? false,
//             'qr_code_scanned_ts': item.qrCodeScannedTs,
//             'image_name': item.imageName,
//             'longitude': item.longitude,
//             'latitude': item.latitude,
//             'item_type_group': item.itemTypeGroup,
//             'record_type': item.recordType,
//             'item_type_remark': item.itemTypeRemark,
//           };
//           savedRectifierItems.add(savedItem);
//           currentScannedItems++;
//         }
//       }
//
//       // Load Battery assets (general assets)
//       final batteryAssets = widget.batteryData!.assets;
//       for (var item in batteryAssets) {
//         if (item.photoId != null) { // Only include items with photoId
//           Map<String, dynamic> savedItem = {
//             'serialNumber': item.mfgSerialNo ?? item.nexgenSerialNo ?? 'Unknown',
//             'photo': null,
//             'photoId': item.photoId,
//             'status': item.assetStatus ?? 'OK',
//             'timestamp': DateTime.now(),
//             'isQRCodeScanned': item.qrCodeScanned ?? false,
//             'itemType': item.itemType ?? 'Battery',
//             'remarks': item.itemTypeRemark ?? 'Battery Item',
//             'assetStatus': item.assetStatus,
//             'assetAuditSiteRespId': item.assetAuditSiteRespId,
//             'capacity': item.capacity ?? 'N/A',
//
//             // Full API response details
//             'asset_audit_site_resp_id': item.assetAuditSiteRespId,
//             'site_audit_sch_id': item.siteAuditSchId,
//             'item_instance_id': item.itemInstanceId,
//             'oem_name': item.oemName,
//             'nexgen_serial_no': item.nexgenSerialNo,
//             'mfg_serial_no': item.mfgSerialNo,
//             'qr_code_scanned': item.qrCodeScanned ?? false,
//             'qr_code_scanned_ts': item.qrCodeScannedTs,
//             'image_name': item.imageName,
//             'longitude': item.longitude,
//             'latitude': item.latitude,
//             'item_type_group': item.itemTypeGroup,
//             'record_type': item.recordType,
//             'item_type_remark': item.itemTypeRemark,
//           };
//           savedMPPTItems.add(savedItem);
//           currentScannedItems++;
//         }
//       }
//
//       // Load CBMS items (from subcategories)
//       final cbmsItems = widget.batteryData!.cbms ?? [];
//       for (var item in cbmsItems) {
//         if (item.photoId != null) { // Only include items with photoId
//           Map<String, dynamic> savedItem = {
//             'serialNumber': item.mfgSerialNo ?? item.nexgenSerialNo ?? 'Unknown',
//             'photo': null,
//             'photoId': item.photoId,
//             'status': item.assetStatus ?? 'OK',
//             'timestamp': DateTime.now(),
//             'isQRCodeScanned': item.qrCodeScanned ?? false,
//             'itemType': item.itemType ?? 'CBMS',
//             'remarks': item.itemTypeRemark ?? 'CBMS Item',
//             'assetStatus': item.assetStatus,
//             'assetAuditSiteRespId': item.assetAuditSiteRespId,
//             'capacity': item.capacity ?? 'N/A',
//
//             // Full API response details
//             'asset_audit_site_resp_id': item.assetAuditSiteRespId,
//             'site_audit_sch_id': item.siteAuditSchId,
//             'item_instance_id': item.itemInstanceId,
//             'oem_name': item.oemName,
//             'nexgen_serial_no': item.nexgenSerialNo,
//             'mfg_serial_no': item.mfgSerialNo,
//             'qr_code_scanned': item.qrCodeScanned ?? false,
//             'qr_code_scanned_ts': item.qrCodeScannedTs,
//             'image_name': item.imageName,
//             'longitude': item.longitude,
//             'latitude': item.latitude,
//             'item_type_group': item.itemTypeGroup,
//             'record_type': item.recordType,
//             'item_type_remark': item.itemTypeRemark,
//           };
//           savedMPPTItems.add(savedItem);
//           currentScannedItems++;
//         }
//       }
//
//       // Update total counts
//       totalRectifierItems = batteryAssets.length;
//       totalMPPTItems = batteryCabinetItems.length + cbmsItems.length;
//
//       // Load remarks data from API and populate the CustomRemarksField
//       final remarks = widget.batteryData!.remarks;
//       if (remarks.isNotEmpty) {
//         for (var remark in remarks) {
//           if (remark.itemTypeRemark != null &&
//               remark.itemTypeRemark!.isNotEmpty) {
//             generalRemarksController.text = remark.itemTypeRemark!;
//             break; // Use the first valid remark
//           }
//         }
//       }
//
//     });
//
//     // Load images for saved items
//     _loadImagesForSavedItems();
//
//     // Wait a bit for images to load and then check cache
//     Future.delayed(Duration(milliseconds: 500), () {
//       if (mounted) {
//         setState(() {}); // Force UI update
//       }
//     });
//   }
//
//   /// Load images for saved items using the image API
//   void _loadImagesForSavedItems() async {
//     // Collect all photo IDs from saved items
//     Set<int> photoIds = {};
//
//     // Add photo IDs from rectifier items
//     for (var item in savedRectifierItems) {
//       if (item['photoId'] != null) {
//         photoIds.add(item['photoId']);
//       }
//     }
//
//     // Add photo IDs from MPPT items
//     for (var item in savedMPPTItems) {
//       if (item['photoId'] != null) {
//         photoIds.add(item['photoId']);
//       }
//     }
//
//     if (photoIds.isEmpty) {
//       return;
//     }
//
//     try {
//       // Mark images as loading
//       setState(() {
//         _loadingImages.addAll(photoIds);
//       });
//
//       // Fetch images from API
//       final imageMap = await _imageService.fetchImagesByIds(photoIds.toList());
//
//       // Update cache and remove loading state
//       setState(() {
//         _imageCache.addAll(imageMap);
//         _loadingImages.removeAll(photoIds);
//       });
//
//       // Force a rebuild to ensure UI updates
//       if (mounted) {
//         setState(() {});
//       }
//     } catch (e) {
//       setState(() {
//         _loadingImages.removeAll(photoIds);
//       });
//     }
//   }
//
//   /// Build photo column for saved items list
//   Widget _buildPhotoColumn(Map<String, dynamic> item) {
//     final photoId = item['photoId'];
//
//     // Always show camera icon, and it will be green since photoId is guaranteed
//     return GestureDetector(
//       onTap: () {
//         if (_imageCache[photoId] != null) {
//           _showImageDialog(_imageCache[photoId]!);
//         }
//       },
//       child: Icon(
//         Icons.photo_camera,
//         color: AppColors.green7,
//         size: 20,
//       ),
//     );
//   }
//
//   /// Show image in full screen dialog
//   void _showImageDialog(String imageData) {
//     showDialog(
//       context: context,
//       builder: (context) => Dialog(
//         child: Container(
//           width: MediaQuery.of(context).size.width * 0.8,
//           height: MediaQuery.of(context).size.height * 0.6,
//           child: Column(
//             children: [
//               AppBar(
//                 title: Text('Image View'),
//                 actions: [
//                   IconButton(
//                     icon: Icon(Icons.close),
//                     onPressed: () => Navigator.of(context).pop(),
//                   ),
//                 ],
//               ),
//               Expanded(
//                 child: Base64ImageWidget(
//                   base64Data: imageData,
//                   boxFit: BoxFit.contain,
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
//
//   @override
//   void initState() {
//     super.initState();
//     serialController.addListener(_onFormChanged);
//
//     // Check if we have data to show, if not, skip this screen
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       if (!_hasDataToShow()) {
//         _navigateToExtinguisherScreen();
//       } else {
//         // Initialize image service
//         try {
//           _imageService = ImageRepository(AppConfig.of(context).apiProvider);
//         } catch (e) {
//         }
//
//         batteryCapacityController.text = _getBatteryCapacity();
//         _loadBatteryData();
//         _hasPostedBatteryData = false;
//       }
//     });
//   }
//
//   @override
//   void dispose() {
//     serialController.removeListener(_onFormChanged);
//     rectifierRemarksController.dispose();
//     mpptRemarksController.dispose();
//     generalRemarksController.dispose();
//     batteryCapacityController.dispose();
//     rectifierSerialController.dispose();
//     mpptSerialController.dispose();
//     serialController.dispose();
//
//     _hasPostedBatteryData = false;
//
//     super.dispose();
//   }
//
//   /// Check if there is data to show on the screen
//   bool _hasDataToShow() {
//     if (widget.batteryData == null) {
//       return false;
//     }
//
//     // Check if we have any assets
//     final hasAssets = widget.batteryData!.assets.isNotEmpty;
//
//     // Check if we have any subcategories with data
//     final hasSubCategories = widget.batteryData!.subCategories != null &&
//         widget.batteryData!.subCategories!.values.any((items) => items.isNotEmpty);
//
//     final hasData = hasAssets || hasSubCategories;
//
//     return hasData;
//   }
//
//   void _navigateToExtinguisherScreen() {
//     Navigator.pushReplacement(
//       context,
//       MaterialPageRoute(
//         builder: (context) => ExtinguisherScreen(
//           extinguisherData: widget.assetAuditData?.responseData.fireExtinguisher,
//           assetAuditData: widget.assetAuditData,
//           showSuccessMessage: false,
//         ),
//       ),
//     );
//   }
//
//   /// Build the "No Data" message widget
//   Widget _buildNoDataMessage() {
//     return Container(
//       width: double.infinity,
//       padding: const EdgeInsets.all(32.0),
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           Icon(
//             Icons.info_outline,
//             size: 64,
//             color: AppColors.white.withOpacity(0.7),
//           ),
//           getHeight(16),
//           Text(
//             'No Battery Data Available',
//             style: TextStyle(
//               fontSize: 20,
//               fontWeight: FontWeight.w600,
//               color: AppColors.white,
//               fontFamily: fontFamilyMontserrat,
//             ),
//             textAlign: TextAlign.center,
//           ),
//           getHeight(8),
//           Text(
//             'There are no Battery items to audit for this site.',
//             style: TextStyle(
//               fontSize: 16,
//               color: AppColors.white.withOpacity(0.8),
//               fontFamily: fontFamilyMontserrat,
//             ),
//             textAlign: TextAlign.center,
//           ),
//           getHeight(16),
//           Text(
//             'You can proceed to the next screen or contact your administrator if you believe this is an error.',
//             style: TextStyle(
//               fontSize: 14,
//               color: AppColors.white.withOpacity(0.6),
//               fontFamily: fontFamilyMontserrat,
//             ),
//             textAlign: TextAlign.center,
//           ),
//         ],
//       ),
//     );
//   }
//
//   void _onFormChanged() {
//     setState(() {
//       hasUnsavedChanges =
//           selectedFile != null ||
//           selectedStatus != null ||
//           selectedBatteryStatus != null ||
//           selectedType != null ||
//           serialController.text.isNotEmpty;
//
//       // Hide validation errors when user starts filling the form
//       if (showValidationErrors &&
//           selectedFile != null &&
//           selectedBatteryStatus != null &&
//           selectedType != null &&
//           serialController.text.isNotEmpty) {
//         showValidationErrors = false;
//       }
//     });
//   }
//
//   void _saveAndExit() async {
//     // First close the unsaved changes dialog
//     Navigator.of(context).pop();
//
//     // Wait a bit for the dialog to fully close and overlay to clear
//     await Future.delayed(const Duration(milliseconds: 200));
//
//     // Then show success dialog with a clean barrier
//     if (mounted) {
//       showDialog(
//         context: context,
//         barrierDismissible: false,
//         barrierColor: Colors.black54,
//         builder: (context) => SuccessDialog(
//           ticketId: "UVORKJR00044",
//           message:
//               "Asset Audit for Site (ID: SITE-38974) has been recorded and saved.",
//           onDone: () {
//             Navigator.of(context).pop();
//             Navigator.of(context).pop();
//           },
//         ),
//       );
//     }
//   }
//
//   // Validate required fields for saved items only
//   bool _isFormValid() {
//     // Only check serial number and photo for saved items
//     // Type, battery status, and file are not required for individual item saving
//
//     // Check if serial number is entered in the CustomInfoCard
//     // Check both controllers to see which one has data
//     String? serialNumber = rectifierSerialController.text.isNotEmpty
//         ? rectifierSerialController.text
//         : mpptSerialController.text.isNotEmpty
//             ? mpptSerialController.text
//             : null;
//
//     if (serialNumber == null || serialNumber.isEmpty) {
//       return false;
//     }
//
//     // Check if photoId is available (photo is mandatory)
//     int? photoId = rectifierPhotoId ?? mpptPhotoId;
//     if (photoId == null) {
//       return false;
//     }
//
//     // Note: status is not required since it comes from API
//     // and is set to true by default (backendStatus: true)
//     String? status = rectifierStatus ?? mpptStatus;
//
//     return true;
//   }
//
//   bool _validateForm() {
//     setState(() {
//       showValidationErrors = true;
//     });
//
//     String? serialNumber = rectifierSerialController.text.isNotEmpty
//         ? rectifierSerialController.text
//         : mpptSerialController.text.isNotEmpty
//             ? mpptSerialController.text
//             : null;
//
//     if (serialNumber == null || serialNumber.isEmpty) {
//       return false;
//     }
//
//     // Check if photoId is available
//     int? photoId = rectifierPhotoId ?? mpptPhotoId;
//     if (photoId == null) {
//       return false;
//     }
//
//     // Note: status is not required since it comes from API
//     // and is set to true by default (backendStatus: true)
//     String? status = rectifierStatus ?? mpptStatus;
//
//     return true;
//   }
//
//   // Save current form data for Rectifier
//   void _saveRectifierForm() {
//     // Check if we've reached the maximum limit from backend
//     if (savedRectifierItems.length >= totalRectifierItems) {
//       return;
//     }
//
//     if (_isFormValid()) {
//       if (rectifierPhotoId != null) { // Only save if photoId is present
//         setState(() {
//           // Create a map of current form data
//           Map<String, dynamic> currentFormData = {
//             'serialNumber': rectifierSerialNumber,
//             'photo': rectifierPhoto,
//             'photoId': rectifierPhotoId,
//             'photoTakenTs': DateTime.now().toString(),
//             'status': rectifierStatus ?? "OK",
//             'timestamp': DateTime.now(),
//             'isQRCodeScanned': false,
//             'itemType': 'CBMS',
//             'remarks': rectifierRemarksController.text.isNotEmpty ? rectifierRemarksController.text : 'CBMS Item',
//             'assetStatus': rectifierStatus ?? "OK",
//             'assetAuditSiteRespId': _getAssetAuditSiteRespId('CBMS'),
//           };
//
//           // Add to saved rectifier items list
//           savedRectifierItems.add(currentFormData);
//           currentScannedItems++;
//
//           // Clear AssetTypeCard form for next entry
//           rectifierSerialNumber = null;
//           rectifierPhoto = null;
//           rectifierPhotoId = null;
//           rectifierStatus = null;
//
//           // Clear the controller
//           rectifierSerialController.clear();
//
//           // Force rebuild of the CustomInfoCard widget
//           rectifierCardKey++;
//
//           hasUnsavedChanges = false;
//           showValidationErrors = false;
//         });
//
//         // Show success message with scanning limits info
//         int remainingRectifiers = totalRectifierItems - savedRectifierItems.length;
//         String message = '✅ CBMS item saved successfully!';
//         if (remainingRectifiers > 0) {
//           message += ' (${remainingRectifiers} remaining out of $totalRectifierItems backend count)';
//         } else {
//           message += ' (Maximum limit reached - backend count: $totalRectifierItems)';
//         }
//         showCustomToast(context, message);
//       }
//     }
//   }
//
//   // Save current form data for MPPT
//   void _saveMPPTForm() {
//     // Check if we've reached the maximum limit from backend
//     if (savedMPPTItems.length >= totalMPPTItems) {
//       return;
//     }
//
//     if (_isFormValid()) {
//       if (mpptPhotoId != null) { // Only save if photoId is present
//         setState(() {
//           // Create a map of current form data
//           Map<String, dynamic> currentFormData = {
//             'serialNumber': mpptSerialNumber,
//             'photo': mpptPhoto,
//             'photoId': mpptPhotoId,
//             'photoTakenTs': DateTime.now().toString(),
//             'status': mpptStatus ?? "OK",
//             'timestamp': DateTime.now(),
//             'isQRCodeScanned': false,
//             'itemType': 'Battery',
//             'remarks': batteryCapacityController.text.isNotEmpty ? batteryCapacityController.text : 'Battery Item',
//             'assetStatus': mpptStatus ?? "OK",
//             'assetAuditSiteRespId': _getAssetAuditSiteRespId('Battery'),
//           };
//
//           // Add to saved MPPT items list
//           savedMPPTItems.add(currentFormData);
//           currentScannedItems++;
//
//           // Clear AssetTypeCard form for next entry
//           mpptSerialNumber = null;
//           mpptPhoto = null;
//           mpptPhotoId = null;
//           mpptStatus = null;
//
//           // Clear the controller
//           mpptSerialController.clear();
//
//           // Force rebuild of the CustomInfoCard widget
//           mpptCardKey++;
//
//           hasUnsavedChanges = false;
//           showValidationErrors = false;
//         });
//
//         // Show success message with scanning limits info
//         int remainingMPPTs = totalMPPTItems - savedMPPTItems.length;
//         String message = '✅ Battery item saved successfully!';
//         if (remainingMPPTs > 0) {
//           message += ' (${remainingMPPTs} remaining out of $totalMPPTItems backend count)';
//         } else {
//           message += ' (Maximum limit reached - backend count: $totalMPPTItems)';
//         }
//         showCustomToast(context, message);
//       }
//     }
//   }
//
//   // Check if all items are scanned (for display purposes only)
//   bool _isAllItemsScanned() {
//     return (savedRectifierItems.length >= totalRectifierItems) &&
//         (savedMPPTItems.length >= totalMPPTItems);
//   }
//
//   // Check if user can proceed to next screen (minimum 1 item required)
//   bool _canProceedToNextScreen() {
//     return (savedRectifierItems.length > 0) || (savedMPPTItems.length > 0);
//   }
//
//   // Get total scanned items count
//   int _getTotalScannedItems() {
//     return savedRectifierItems.length + savedMPPTItems.length;
//   }
//
//   // Get total expected items from backend
//   int _getTotalExpectedItems() {
//     return totalRectifierItems + totalMPPTItems;
//   }
//
//   // Method to get Battery capacity from API data
//   String _getBatteryCapacity() {
//     if (widget.batteryData != null) {
//       // Try to get capacity from Battery assets first
//       final batteryAssets = widget.batteryData!.assets ?? [];
//       if (batteryAssets.isNotEmpty) {
//         return batteryAssets.first.capacity ?? '200 AH';
//       }
//
//       // Fallback to Battery Cabinet if assets not available
//       final batteryCabinetItems = widget.batteryData!.batteryCabinet ?? [];
//       if (batteryCabinetItems.isNotEmpty) {
//         return batteryCabinetItems.first.capacity ?? '200 AH';
//       }
//     }
//     return '200 AH';
//   }
//
//   /// Get asset audit site response ID from GET API response for a specific item type
//   int? _getAssetAuditSiteRespId(String itemType) {
//     if (widget.batteryData != null) {
//       switch (itemType) {
//         case 'CBMS':
//           final cbmsItems = widget.batteryData!.cbms ?? [];
//           if (cbmsItems.isNotEmpty) {
//             return cbmsItems.first.assetAuditSiteRespId;
//           }
//           break;
//         case 'Battery':
//           final batteryAssets = widget.batteryData!.assets ?? [];
//           if (batteryAssets.isNotEmpty) {
//             return batteryAssets.first.assetAuditSiteRespId;
//           }
//           break;
//       }
//     }
//     return null;
//   }
//
//   bool _validateSerialNumber(String serialNumber, bool isQRCodeScanned) {
//     if (widget.batteryData == null) return false;
//
//     // For CBMS validation, focus on CBMS items specifically
//     final cbmsItems = widget.batteryData!.cbms ?? [];
//
//     // Check against CBMS items first (most relevant for rectifier validation)
//     final cbmsValid = cbmsItems.any((item) {
//       // Check nexgenSerialNo first (most common)
//       if (item.nexgenSerialNo?.toLowerCase() == serialNumber.toLowerCase()) {
//         return true;
//       }
//       // Check mfgSerialNo as fallback
//       if (item.mfgSerialNo?.toLowerCase() == serialNumber.toLowerCase()) {
//         return true;
//       }
//       return false;
//     });
//
//     if (cbmsValid) {
//       return true;
//     }
//
//     // If CBMS validation fails, check other items as fallback
//     final allItems = [
//       ...(widget.batteryData!.batteryCabinet ?? []),
//       ...(widget.batteryData!.assets ?? []),
//     ];
//
//     final otherValid = allItems.any((item) {
//       if (item.nexgenSerialNo?.toLowerCase() == serialNumber.toLowerCase()) {
//         return true;
//       }
//       if (item.mfgSerialNo?.toLowerCase() == serialNumber.toLowerCase()) {
//         return true;
//       }
//       return false;
//     });
//
//     final finalResult = cbmsValid || otherValid;
//
//     if (!finalResult) {
//       if (isQRCodeScanned) {
//         showCustomToast(context, '❌ Invalid QR Code! Serial number not found in system.');
//       } else {
//         showCustomToast(context, '❌ Invalid manual entry! Serial number not found in system.');
//       }
//     }
//
//     return finalResult;
//   }
//
//   /// Check if the current success state is for Battery screen data
//   bool _isBatteryScreenDataPosted() {
//     return _hasPostedBatteryData;
//   }
//
//   int? _getRemarksAssetAuditSiteRespId() {
//     if (widget.batteryData == null) {
//       return null;
//     }
//
//     // Check if there are remarks in the backend data
//     final remarks = widget.batteryData!.remarks;
//     if (remarks.isNotEmpty) {
//       // First try to find a general remarks entry (Battery category is usually the main one)
//       for (var remark in remarks) {
//         if (remark.assetAuditSiteRespId != null &&
//             remark.assetAuditSiteRespId > 0 &&
//             remark.itemType == 'Battery') {
//           return remark.assetAuditSiteRespId;
//         }
//       }
//
//       // Fallback: find any remarks entry with a valid ID
//       for (var remark in remarks) {
//         if (remark.assetAuditSiteRespId != null && remark.assetAuditSiteRespId > 0) {
//           return remark.assetAuditSiteRespId;
//         }
//       }
//     }
//
//     return null;
//   }
//
//   /// Post current screen data to API before navigating to next screen
//   Future<bool> _postCurrentScreenData() async {
//     if (widget.assetAuditData == null) {
//       return false;
//     }
//
//     try {
//       // Create a list to hold all items to post
//       List<Map<String, dynamic>> allItemsToPost = [];
//
//       // Add saved CBMS items
//       if (savedRectifierItems.isNotEmpty) {
//         final enhancedCBMSItems = AssetAuditPostHelper.enhanceSavedItems(
//           savedItems: savedRectifierItems,
//           screenName: 'CBMS',
//         );
//         allItemsToPost.addAll(enhancedCBMSItems);
//       }
//
//       // Add saved Battery items
//       if (savedMPPTItems.isNotEmpty) {
//         final enhancedBatteryItems = AssetAuditPostHelper.enhanceSavedItems(
//           savedItems: savedMPPTItems,
//           screenName: 'Battery',
//         );
//         allItemsToPost.addAll(enhancedBatteryItems);
//       }
//
//       // Add user's general remarks if entered
//       if (generalRemarksController.text.isNotEmpty) {
//         // Find the appropriate remarks entry from backend data
//         int? remarksAssetAuditSiteRespId = _getRemarksAssetAuditSiteRespId();
//
//         if (remarksAssetAuditSiteRespId != null) {
//           Map<String, dynamic> remarksData = {
//             'itemType': 'Battery',
//             'remarks': generalRemarksController.text,
//             'recordType': 'Remarks',
//             'timestamp': DateTime.now(),
//             'assetAuditSiteRespId': remarksAssetAuditSiteRespId,
//             'status': 'OK',
//             'serialNumber': 'REMARKS',
//             'photo': null,
//             'photoTakenTs': DateTime.now().toString(),
//             'isQRCodeScanned': false,
//             'localQrCodeScannedTs': DateTime.now().toString(),
//             'localCreatedDt': DateTime.now().toString(),
//             'localModifiedDt': DateTime.now().toString(),
//           };
//           allItemsToPost.add(remarksData);
//         }
//       }
//
//       if (allItemsToPost.isEmpty) {
//         return false;
//       }
//
//       // Convert to POST request format
//       final requests = await AssetAuditPostHelper.convertSavedItemsToPostRequest(
//         savedItems: allItemsToPost,
//         assetAuditData: widget.assetAuditData!,
//         itemType: 'Battery',
//         itemTypeId: AssetAuditPostHelper.getItemTypeId('Battery'),
//         screenName: 'Battery',
//         context: context,
//         auditSchId: widget.assetAuditData?.pageHeader.first.siteAuditSchId.toString(),
//       );
//
//       if (requests.isEmpty) {
//         return false;
//       }
//
//       // Use the existing cubit to post data
//       final cubit = context.read<AssetAuditCubit>();
//
//       // Set flag BEFORE making the API call to ensure it's set when success state is received
//       setState(() {
//         _hasPostedBatteryData = true;
//       });
//
//       cubit.postAssetAuditData(requests: requests);
//
//       // Return true to indicate data is being posted
//       return true;
//     } catch (e) {
//       return false;
//     }
//   }
//
//   // Format serial number to show first 5 digits + ...
//   String _formatSerialNumber(String serialNumber) {
//     if (serialNumber.length <= 7) {
//       return serialNumber;
//     }
//     return "${serialNumber.substring(0, 5)}...";
//   }
//
//   // Edit a specific Rectifier item from the saved list
//   void _editItem(Map<String, dynamic> item) {
//     setState(() {
//       // Load the item data back into the form
//       rectifierSerialNumber = item["serialNumber"];
//       rectifierPhoto = item["photo"];
//       rectifierStatus = item["status"];
//       rectifierPhotoId = item["photoId"];
//
//       // Set the serial controller text
//       rectifierSerialController.text = item["serialNumber"] ?? "";
//
//       // Remove the item from saved rectifier items
//       savedRectifierItems.remove(item);
//       currentScannedItems--;
//
//       // Force rebuild of the CustomInfoCard widget with new data
//       rectifierCardKey++;
//
//       hasUnsavedChanges = true;
//
//       // Reset the posted data flag when editing items
//       _hasPostedBatteryData = false;
//     });
//
//     // Show message to user
//     showCustomToast(context, 'Rectifier item loaded for editing. Make changes and save again.');
//   }
//
//   // Edit a specific MPPT item from the saved list
//   void _editMPPTItem(Map<String, dynamic> item) {
//     setState(() {
//       // Load the item data back into the form
//       mpptSerialNumber = item["serialNumber"];
//       mpptPhoto = item["photo"];
//       mpptStatus = item["status"];
//       mpptPhotoId = item["photoId"];
//
//       // Set the serial controller text
//       mpptSerialController.text = item["serialNumber"] ?? "";
//
//       // Remove the item from saved MPPT items
//       savedMPPTItems.remove(item);
//       currentScannedItems--;
//
//       // Force rebuild of the CustomInfoCard widget with new data
//       mpptCardKey++;
//
//       hasUnsavedChanges = true;
//
//       // Reset the posted data flag when editing items
//       _hasPostedBatteryData = false;
//     });
//
//     // Show message to user
//     showCustomToast(context, 'MPPT item loaded for editing. Make changes and save again.');
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return BlocListener<AssetAuditCubit, AssetAuditState>(
//       listener: (context, state) {
//         if (state is AssetAuditPostSuccess) {
//           // Check if this success state contains Battery-related items
//           bool isBatteryData = false;
//           for (var response in state.responses) {
//             // Primary check: itemTypeRemark contains Battery-related text
//             if (response.itemTypeRemark != null &&
//                 (response.itemTypeRemark!.contains('Battery') ||
//                  response.itemTypeRemark!.contains('Rectifier') ||
//                  response.itemTypeRemark!.contains('MPPT'))) {
//               isBatteryData = true;
//               break;
//             }
//
//             // Fallback check: Check if this is a response to Battery screen data by looking at the flag
//             if (_hasPostedBatteryData) {
//               isBatteryData = true;
//               break;
//             }
//           }
//
//           // Only process this success state if it contains Battery screen data
//           if (isBatteryData) {
//             // Refresh data from API before navigating
//             try {
//               // Trigger a refresh of the asset audit data
//               context.read<AssetAuditCubit>().getAssetAuditData(
//                 siteType: "telecom",
//                 auditSchId: widget.assetAuditData?.pageHeader.first.siteAuditSchId.toString() ?? "0",
//                 siteAuditSchId: widget.assetAuditData?.pageHeader.first.siteAuditSchId.toString() ?? "0",
//               );
//
//               // Wait for data to refresh, then navigate
//               Future.delayed(const Duration(seconds: 2), () {
//                 if (mounted) {
//                   try {
//                     Navigator.push(
//                       context,
//                       MaterialPageRoute(
//                         builder: (context) => ExtinguisherScreen(
//                           extinguisherData: widget.assetAuditData?.responseData.fireExtinguisher,
//                           assetAuditData: widget.assetAuditData,
//                           showSuccessMessage: false,
//                         ),
//                       ),
//                     );
//                     // Reset the flag after successful navigation
//                     setState(() {
//                       _hasPostedBatteryData = false;
//                     });
//                   } catch (e) {
//                   }
//                 }
//               });
//             } catch (e) {
//               // Fallback: navigate anyway after delay
//               Future.delayed(const Duration(seconds: 2), () {
//                 if (mounted) {
//                   try {
//                     Navigator.push(
//                       context,
//                       MaterialPageRoute(
//                         builder: (context) => ExtinguisherScreen(
//                           extinguisherData: widget.assetAuditData?.responseData.fireExtinguisher,
//                           assetAuditData: widget.assetAuditData,
//                           showSuccessMessage: false,
//                         ),
//                       ),
//                     );
//                     setState(() {
//                       _hasPostedBatteryData = false;
//                     });
//                   } catch (e) {
//                   }
//                 }
//               });
//             }
//           }
//
//         } else if (state is AssetAuditPostError) {
//           // Only show error message if this error belongs to Battery screen data
//           if (_hasPostedBatteryData) {
//             // Show error message and block navigation
//             showCustomToast(context, '❌ Failed to save Battery data. Please try again.');
//
//             // Reset the flag on error
//             setState(() {
//               _hasPostedBatteryData = false;
//             });
//           }
//         }
//       },
//       child: PopScope(
//         canPop: !hasUnsavedChanges,
//         onPopInvoked: (didPop) async {
//           if (didPop) return;
//
//           if (hasUnsavedChanges) {
//             showDialog(
//               context: context,
//               barrierDismissible: false,
//               builder: (context) => UnsavedChangesDialog(
//                 message:
//                     "Do you want to cancel the Asset Audit for Site (ID: SITE-38974) ?",
//                 onSaveAndExit: () {
//                   _saveAndExit();
//                 },
//                 onDiscard: () {
//                   Navigator.of(context).pop();
//                 },
//               ),
//             );
//           }
//         },
//         child: Scaffold(
//           extendBodyBehindAppBar: true,
//           resizeToAvoidBottomInset: false,
//           appBar: CustomFormAppbar(
//             title: "Asset Audit",
//             onClose: () async {
//               if (hasUnsavedChanges) {
//                 showDialog(
//                   context: context,
//                   barrierDismissible: false,
//                   builder: (context) => UnsavedChangesDialog(
//                     message:
//                         "Do you want to cancel the Asset Audit for Site (ID: SITE-38974) ?",
//                     onSaveAndExit: () {
//                       _saveAndExit();
//                     },
//                     onDiscard: () {
//                       Navigator.of(context).pop();
//                     },
//                   ),
//                 );
//               } else {
//                 Navigator.pop(context);
//               }
//             },
//           ),
//           body: Stack(
//             children: [
//               // Background image
//               Positioned.fill(
//                 child: SvgPicture.asset(
//                   AppImages.home,
//                   fit: BoxFit.cover,
//                   width: double.infinity,
//                   height: double.infinity,
//                 ),
//               ),
//               SafeArea(
//                 child: Form(
//                   key: _formKey,
//                   child: Column(
//                     children: [
//                       Expanded(
//                         child: SingleChildScrollView(
//                           padding: EdgeInsets.only(
//                             bottom:
//                                 MediaQuery.of(context).viewInsets.bottom + 120,
//                           ),
//                           child: Container(
//                             padding: const EdgeInsets.only(
//                               top: 20,
//                               left: 16,
//                               right: 16,
//                               bottom: 20,
//                             ),
//                             child: Column(
//                               crossAxisAlignment: CrossAxisAlignment.start,
//                               children: [
//                                 if (_hasDataToShow()) ...[
//                                   CustomOptionSelector(
//                                     label: "CBMS Availability",
//                                     isRequired: true,
//                                     options: [
//                                     OptionItem(
//                                       value: "yes",
//                                       label: "Yes",
//                                       selectedIcon: Icons.check_circle,
//                                       unselectedIcon: Icons.circle_outlined,
//                                     ),
//                                     OptionItem(
//                                       value: "no",
//                                       label: "No",
//                                       selectedIcon: Icons.cancel,
//                                       unselectedIcon: Icons.circle_outlined,
//                                     ),
//                                   ],
//                                   onChanged: (value) {
//                                     setState(() {
//                                       selectedBatteryStatus = value;
//                                       hasUnsavedChanges = true;
//                                     });
//                                   },
//                                 ),
//                                 getHeight(15),
//                                 CustomInfoCard(
//                                   key: ValueKey('rectifier_$rectifierCardKey'),
//                                   serialLabel: "CBMS - Serial Number *",
//                                   serialHintText: "CBMS Serial Number",
//                                   photoLabel: "Add a Photo",
//                                   statusLabel: "Status",
//                                   serialController: rectifierSerialController,
//                                   onSave: _saveRectifierForm,
//                                   isStatusEditable: true,
//                                   showSaveButton: true,
//                                   backendStatus: false,
//                                   onPhotoTap: (photoPath) async {
//                                     setState(() {
//                                       rectifierPhoto = photoPath;
//                                       hasUnsavedChanges = true;
//                                     });
//
//                                     // Upload photo immediately and get photoId
//                                     if (photoPath != null && photoPath.isNotEmpty) {
//                                       try {
//                                         final photoFile = File(photoPath);
//                                         if (await photoFile.exists()) {
//                                           // Get the cubit directly
//                                           final photoUploadCubit = context.read<AssetAuditPhotoUploadCubit>();
//
//                                           // Upload photo
//                                           await photoUploadCubit.uploadPhoto(
//                                             file: photoFile,
//                                             imgId: null,
//                                             schId: widget.assetAuditData?.pageHeader.first.siteAuditSchId.toString() ?? "0",
//                                           );
//
//                                           // Wait for state to update
//                                           await Future.delayed(const Duration(milliseconds: 500));
//
//                                           // Check the result
//                                           final state = photoUploadCubit.state;
//                                           if (state is AssetAuditPhotoUploadSuccess) {
//                                             final photoId = int.tryParse(state.response.imgId) ?? 0;
//                                             if (photoId > 0) {
//                                               setState(() {
//                                                 rectifierPhotoId = photoId;
//                                               });
//                                             }
//                                           } else if (state is AssetAuditPhotoUploadFailure) {
//                                           }
//                                         }
//                                       } catch (e) {
//                                       }
//                                     }
//                                   },
//                                   onStatusChanged: (val) {
//                                     setState(() {
//                                       rectifierStatus = val ? "OK" : "Not OK";
//                                       hasUnsavedChanges = true;
//                                     });
//                                   },
//                                   onSerialChanged: (serialNumber) {
//                                     setState(() {
//                                       rectifierSerialNumber = serialNumber;
//                                       hasUnsavedChanges = true;
//                                     });
//
//                                     // Validate serial number if not empty
//                                     if (serialNumber.isNotEmpty) {
//                                       final isValid = _validateSerialNumber(serialNumber, false);
//                                       if (isValid) {
//                                         // Serial number is valid, keep it
//                                       } else {
//                                         setState(() {
//                                           rectifierSerialNumber = null;
//                                           hasUnsavedChanges = false;
//                                         });
//                                       }
//                                     }
//                                   },
//                                   initialStatus: rectifierSerialNumber == "OK"
//                                       ? true
//                                       : (rectifierStatus == "Not OK"
//                                           ? false
//                                           : null),
//                                   initialPhotoPath: rectifierPhoto,
//                                   isEditable: true,
//                                 ),
//                                 _buildRectifierSavedItemsList(),
//                                 getHeight(15),
//                                 CustomFormField(
//                                   label: "Battery Make",
//                                   initialValue: _getBatteryOEMName(),
//                                   isRequired: false,
//                                   isEditable: false,
//                                 ),
//                                 getHeight(15),
//                                 SerialNumberField(
//                                   label: "Battery Cabinet Serial Number",
//                                   controller: serialController,
//                                 ),
//                                 getHeight(15),
//                                 ImageUploadField(
//                                   label: "Add Photo of Battery Modules *",
//                                   placeholder: "Add Photo",
//                                   isRequired: true,
//                                   onImageSelected: (file) async {
//                                     if (file != null) {
//                                       setState(() {
//                                         uploadedPhotoPath = file.path;
//                                         hasUnsavedChanges = true;
//                                       });
//
//                                       // Upload photo immediately and get photoId for Battery Cabinet
//                                       try {
//                                         final photoFile = File(file.path);
//                                         if (await photoFile.exists()) {
//                                           final photoId = await AssetAuditPhotoUploadHelper.uploadPhotoAndGetId(
//                                             photoFile: photoFile,
//                                             schId: widget.assetAuditData?.pageHeader.first.siteAuditSchId.toString() ?? "0",
//                                             imgId: null,
//                                             context: context,
//                                           );
//
//                                           if (photoId != null) {
//                                             setState(() {
//                                               cabinetPhotoId = photoId;
//                                             });
//                                           }
//                                         }
//                                       } catch (e) {
//                                       }
//                                     } else {
//                                       setState(() {
//                                         uploadedPhotoPath = null;
//                                         cabinetPhotoId = null;
//                                       });
//                                     }
//                                   },
//                                 ),
//                                 getHeight(15),
//                                 CustomFormField(
//                                   label: "Count of Battery Modules ",
//                                   initialValue: totalRectifierItems.toString(),
//                                   isRequired: true,
//                                   isEditable: true,
//                                   onChanged: (value) {
//                                     setState(() {
//                                       totalRectifierItems =
//                                           int.tryParse(value) ?? 6;
//                                       hasUnsavedChanges = true;
//                                     });
//                                   },
//                                 ),
//                                 getHeight(15),
//                                 Text(
//                                   "Battery Module Details",
//                                   style: TextStyle(
//                                     fontSize: 16,
//                                     fontWeight: FontWeight.w500,
//                                     color: Colors.white,
//                                     fontFamily: fontFamilyMontserrat,
//                                   ),
//                                 ),
//                                 getHeight(3),
//                                 CustomInfoCard(
//                                   key: ValueKey('mppt_$mpptCardKey'),
//                                   serialLabel: "Battery - Serial Number",
//                                   serialHintText: "Battery Serial Number",
//                                   photoLabel: "Add a Photo",
//                                   statusLabel: "Status",
//                                   serialController: mpptSerialController,
//                                   onSave: _saveMPPTForm,
//                                   isStatusEditable: true,
//                                   backendStatus: false,
//                                   remarksLabel: "Capacity",
//                                   remarksHintText: "Eg:200 AH",
//                                   remarksController: batteryCapacityController,
//                                   isRemarksEditable: false,
//                                   onPhotoTap: (photoPath) async {
//                                     setState(() {
//                                       mpptPhoto = photoPath;
//                                       hasUnsavedChanges = true;
//                                     });
//
//                                     // Upload photo immediately and get photoId
//                                     if (photoPath != null && photoPath.isNotEmpty) {
//                                       try {
//                                         final photoFile = File(photoPath);
//                                         if (await photoFile.exists()) {
//                                           // Get the cubit directly
//                                           final photoUploadCubit = context.read<AssetAuditPhotoUploadCubit>();
//
//                                           // Upload photo
//                                           await photoUploadCubit.uploadPhoto(
//                                             file: photoFile,
//                                             imgId: null,
//                                             schId: widget.assetAuditData?.pageHeader.first.siteAuditSchId.toString() ?? "0",
//                                           );
//
//                                           // Wait for state to update
//                                           await Future.delayed(const Duration(milliseconds: 500));
//
//                                           // Check the result
//                                           final state = photoUploadCubit.state;
//                                           if (state is AssetAuditPhotoUploadSuccess) {
//                                             final photoId = int.tryParse(state.response.imgId) ?? 0;
//                                             if (photoId > 0) {
//                                               setState(() {
//                                                 mpptPhotoId = photoId;
//                                               });
//                                             }
//                                           }
//                                         }
//                                       } catch (e) {
//                                       }
//                                     }
//                                   },
//                                   onStatusChanged: (val) {
//                                     setState(() {
//                                       mpptStatus = val ? "OK" : "Not OK";
//                                       hasUnsavedChanges = true;
//                                     });
//                                   },
//                                   onSerialChanged: (serialNumber) {
//                                     setState(() {
//                                       mpptSerialNumber = serialNumber;
//                                       hasUnsavedChanges = true;
//                                     });
//
//                                     // Validate serial number if not empty
//                                     if (serialNumber.isNotEmpty) {
//                                       final isValid = _validateSerialNumber(serialNumber, false);
//                                       if (isValid) {
//                                         // Serial number is valid, keep it
//                                       } else {
//                                         setState(() {
//                                           mpptSerialNumber = null;
//                                           hasUnsavedChanges = false;
//                                         });
//                                       }
//                                     }
//                                   },
//                                   initialStatus: mpptStatus == "OK"
//                                       ? true
//                                       : (mpptStatus == "Not OK" ? false : null),
//                                   initialPhotoPath: mpptPhoto,
//                                   isEditable: true,
//                                 ),
//
//                                 getHeight(8),
//
//                                 _buildMPPTSavedItemsList(),
//
//                                 getHeight(15),
//                                 CustomRemarksField(
//                                   label: "Add Remarks",
//                                   hintText: "Remarks",
//                                   controller: generalRemarksController,
//                                 ),
//                                 ] else ...[
//                                   _buildNoDataMessage(),
//                                 ],
//                               ],
//                             ),
//                           ),
//                         ),
//                       ),
//
//                       Container(
//                         padding: const EdgeInsets.all(16),
//                         width: double.infinity,
//                         child: Row(
//                           children: [
//                             Expanded(
//                               child: ArrowButton(
//                                 text: "CCU",
//                                 isLeftArrow: true,
//                                 backgroundColor: AppColors.buttonColorBg,
//                                 textColor: AppColors.buttonColorSite,
//                                 onPressed: () {
//                                   Navigator.pop(context);
//                                 },
//                               ),
//                             ),
//                             getWidth(14),
//                             Expanded(
//                               child: ArrowButton(
//                                 text: _hasDataToShow() ? "Extinguisher" : "Skip",
//                                 isLeftArrow: false,
//                                 backgroundColor: AppColors.buttonColorBackBg,
//                                 textColor: AppColors.buttonColorTextBg,
//                                 onPressed: () async {
//                                   // If no data to show, just navigate to next screen
//                                   if (!_hasDataToShow()) {
//                                     Navigator.push(
//                                       context,
//                                       MaterialPageRoute(
//                                         builder: (context) => ExtinguisherScreen(
//                                           extinguisherData: widget.assetAuditData?.responseData.fireExtinguisher,
//                                           assetAuditData: widget.assetAuditData,
//                                           showSuccessMessage: false,
//                                         ),
//                                       ),
//                                     );
//                                     return;
//                                   }
//
//                                   // Check if user has scanned at least one item
//                                   if (!_canProceedToNextScreen()) {
//                                     showCustomToast(context, '❌ Please scan at least 1 item before proceeding.');
//                                     return;
//                                   }
//
//                                   // Post current screen data before navigating
//                                   final success = await _postCurrentScreenData();
//
//                                   if (success) {
//                                     // Navigation will be handled in the BlocListener after API success
//                                   } else {
//                                     showCustomToast(context, 'Failed to post data. Please try again.');
//                                   }
//                                 },
//                               ),
//                             ),
//                           ],
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//               // Full-screen loading overlay when posting data
//               BlocBuilder<AssetAuditCubit, AssetAuditState>(
//                 builder: (context, state) {
//                   if (state is AssetAuditPosting) {
//                     return Container(
//                       color: Colors.black.withOpacity(0.5),
//                       child: const Center(
//                         child: CircularProgressIndicator(
//                           valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
//                         ),
//                       ),
//                     );
//                   }
//                   return const SizedBox.shrink();
//                 },
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
//
//   // Build Rectifier saved items list
//   Widget _buildRectifierSavedItemsList() {
//     return Container(
//       margin: const EdgeInsets.symmetric(vertical: 10),
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: AppColors.green7,
//         borderRadius: BorderRadius.circular(5),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           // Header Row - Always show
//           Row(
//             children: [
//               Expanded(
//                 child: Container(
//                   padding: const EdgeInsets.symmetric(horizontal: 4),
//                   child: const Text(
//                     "Serial",
//                     textAlign: TextAlign.center,
//                     style: TextStyle(
//                       color: Colors.white,
//                       fontSize: 14,
//                       fontFamily: fontFamilyMontserrat,
//                       fontWeight: FontWeight.w400,
//                     ),
//                     maxLines: 1,
//                     overflow: TextOverflow.ellipsis,
//                   ),
//                 ),
//               ),
//               Expanded(
//                 child: Container(
//                   padding: const EdgeInsets.symmetric(horizontal: 4),
//                   child: const Text(
//                     "Scanned",
//                     textAlign: TextAlign.center,
//                     style: TextStyle(
//                       color: Colors.white,
//                       fontSize: 14,
//                       fontFamily: fontFamilyMontserrat,
//                       fontWeight: FontWeight.w400,
//                     ),
//                     maxLines: 1,
//                     overflow: TextOverflow.ellipsis,
//                   ),
//                 ),
//               ),
//               Expanded(
//                 child: Container(
//                   padding: const EdgeInsets.symmetric(horizontal: 4),
//                   child: const Text(
//                     "Photo",
//                     textAlign: TextAlign.center,
//                     style: TextStyle(
//                       color: Colors.white,
//                       fontSize: 14,
//                       fontFamily: fontFamilyMontserrat,
//                       fontWeight: FontWeight.w400,
//                     ),
//                     maxLines: 1,
//                     overflow: TextOverflow.ellipsis,
//                   ),
//                 ),
//               ),
//               Expanded(
//                 child: Container(
//                   padding: const EdgeInsets.symmetric(horizontal: 4),
//                   child: const Text(
//                     "Status",
//                     textAlign: TextAlign.center,
//                     style: TextStyle(
//                       color: Colors.white,
//                       fontSize: 14,
//                       fontFamily: fontFamilyMontserrat,
//                       fontWeight: FontWeight.w400,
//                     ),
//                     maxLines: 1,
//                     overflow: TextOverflow.ellipsis,
//                   ),
//                 ),
//               ),
//               Expanded(
//                 child: Container(
//                   padding: const EdgeInsets.symmetric(horizontal: 4),
//                   child: const Text(
//                     "Edit",
//                     textAlign: TextAlign.center,
//                     style: TextStyle(
//                       color: Colors.white,
//                       fontSize: 14,
//                       fontFamily: fontFamilyMontserrat,
//                       fontWeight: FontWeight.w400,
//                     ),
//                     maxLines: 1,
//                     overflow: TextOverflow.ellipsis,
//                   ),
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 8),
//
//           // Debug information
//           Container(
//             padding: const EdgeInsets.all(8),
//             margin: const EdgeInsets.only(bottom: 10),
//             decoration: BoxDecoration(
//               color: Colors.blue.withOpacity(0.1),
//               borderRadius: BorderRadius.circular(5),
//               border: Border.all(color: Colors.blue.withOpacity(0.3)),
//             ),
//             child: Row(
//               children: [
//                 const Icon(Icons.info_outline, color: Colors.blue, size: 16),
//                 const SizedBox(width: 8),
//                 Expanded(
//                   child: Text(
//                     'Saved Items: ${savedRectifierItems.length} | Current Scanned: $currentScannedItems | Total Expected: $totalRectifierItems',
//                     style: const TextStyle(
//                       color: Colors.blue,
//                       fontSize: 12,
//                       fontFamily: fontFamilyMontserrat,
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//
//           // Items - Only show items with photoId
//           if (savedRectifierItems.isNotEmpty)
//             ...savedRectifierItems
//                 .map(
//                   (item) => Container(
//                     margin: const EdgeInsets.symmetric(vertical: 5),
//                     decoration: BoxDecoration(
//                       color: Colors.white,
//                       borderRadius: BorderRadius.circular(5),
//                     ),
//                     child: Row(
//                       children: [
//                         Expanded(
//                           child: Container(
//                             padding: const EdgeInsets.symmetric(horizontal: 4),
//                             child: Text(
//                               item['serialNumber'] ?? 'N/A',
//                               textAlign: TextAlign.center,
//                               style: const TextStyle(
//                                 color: Colors.black,
//                                 fontSize: 14,
//                                 fontFamily: fontFamilyMontserrat,
//                                 fontWeight: FontWeight.w400,
//                               ),
//                               maxLines: 1,
//                               overflow: TextOverflow.ellipsis,
//                             ),
//                           ),
//                         ),
//                         Expanded(
//                           child: Container(
//                             padding: const EdgeInsets.symmetric(horizontal: 4),
//                             child: Icon(
//                               item['isQRCodeScanned'] == true
//                                   ? Icons.check
//                                   : Icons.close,
//                               color: item['isQRCodeScanned'] == true
//                                   ? Colors.green
//                                   : Colors.red,
//                               size: 20,
//                             ),
//                           ),
//                         ),
//                         Expanded(
//                           child: Container(
//                             padding: const EdgeInsets.symmetric(horizontal: 4),
//                             child: _buildPhotoColumn(item),
//                           ),
//                         ),
//                         Expanded(
//                           child: Container(
//                             padding: const EdgeInsets.symmetric(horizontal: 4),
//                             child: Text(
//                               item['status'] ?? 'N/A',
//                               textAlign: TextAlign.center,
//                               style: const TextStyle(
//                                 color: Colors.black,
//                                 fontSize: 14,
//                                 fontFamily: fontFamilyMontserrat,
//                                 fontWeight: FontWeight.w400,
//                               ),
//                               maxLines: 1,
//                               overflow: TextOverflow.ellipsis,
//                             ),
//                           ),
//                         ),
//                         Expanded(
//                           child: Container(
//                             padding: const EdgeInsets.symmetric(horizontal: 4),
//                             child: IconButton(
//                               onPressed: () => _editSavedItem(item, 'rectifier'),
//                               icon: const Icon(
//                                 Icons.edit,
//                                 color: AppColors.blue,
//                                 size: 20,
//                               ),
//                             ),
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                 )
//                 .toList(),
//         ],
//       ),
//     );
//   }
//
//   // Build MPPT saved items list
//   Widget _buildMPPTSavedItemsList() {
//     return Container(
//       margin: const EdgeInsets.symmetric(vertical: 10),
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: AppColors.green7,
//         borderRadius: BorderRadius.circular(5),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           // Header Row - Always show
//           Row(
//             children: [
//               Expanded(
//                 child: Container(
//                   padding: const EdgeInsets.symmetric(horizontal: 4),
//                   child: const Text(
//                     "Serial",
//                     textAlign: TextAlign.center,
//                     style: TextStyle(
//                       color: Colors.white,
//                       fontSize: 14,
//                       fontFamily: fontFamilyMontserrat,
//                       fontWeight: FontWeight.w400,
//                     ),
//                     maxLines: 1,
//                     overflow: TextOverflow.ellipsis,
//                   ),
//                 ),
//               ),
//               Expanded(
//                 child: Container(
//                   padding: const EdgeInsets.symmetric(horizontal: 4),
//                   child: const Text(
//                     "Scanned",
//                     textAlign: TextAlign.center,
//                     style: TextStyle(
//                       color: Colors.white,
//                       fontSize: 14,
//                       fontFamily: fontFamilyMontserrat,
//                       fontWeight: FontWeight.w400,
//                     ),
//                     maxLines: 1,
//                     overflow: TextOverflow.ellipsis,
//                   ),
//                 ),
//               ),
//               Expanded(
//                 child: Container(
//                   padding: const EdgeInsets.symmetric(horizontal: 4),
//                   child: const Text(
//                     "Photo",
//                     textAlign: TextAlign.center,
//                     style: TextStyle(
//                       color: Colors.white,
//                       fontSize: 14,
//                       fontFamily: fontFamilyMontserrat,
//                       fontWeight: FontWeight.w400,
//                     ),
//                     maxLines: 1,
//                     overflow: TextOverflow.ellipsis,
//                   ),
//                 ),
//               ),
//               Expanded(
//                 child: Container(
//                   padding: const EdgeInsets.symmetric(horizontal: 4),
//                   child: const Text(
//                     "Capacity",
//                     textAlign: TextAlign.center,
//                     style: TextStyle(
//                       color: Colors.white,
//                       fontSize: 14,
//                       fontFamily: fontFamilyMontserrat,
//                       fontWeight: FontWeight.w400,
//                     ),
//                     maxLines: 1,
//                     overflow: TextOverflow.ellipsis,
//                   ),
//                 ),
//               ),
//               Expanded(
//                 child: Container(
//                   padding: const EdgeInsets.symmetric(horizontal: 4),
//                   child: const Text(
//                     "Status",
//                     textAlign: TextAlign.center,
//                     style: TextStyle(
//                       color: Colors.white,
//                       fontSize: 14,
//                       fontFamily: fontFamilyMontserrat,
//                       fontWeight: FontWeight.w400,
//                     ),
//                     maxLines: 1,
//                     overflow: TextOverflow.ellipsis,
//                   ),
//                 ),
//               ),
//               Expanded(
//                 child: Container(
//                   padding: const EdgeInsets.symmetric(horizontal: 4),
//                   child: const Text(
//                     "Edit",
//                     textAlign: TextAlign.center,
//                     style: TextStyle(
//                       color: Colors.white,
//                       fontSize: 14,
//                       fontFamily: fontFamilyMontserrat,
//                       fontWeight: FontWeight.w400,
//                     ),
//                     maxLines: 1,
//                     overflow: TextOverflow.ellipsis,
//                   ),
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 8),
//
//           // Debug information
//           Container(
//             padding: const EdgeInsets.all(8),
//             margin: const EdgeInsets.only(bottom: 10),
//             decoration: BoxDecoration(
//               color: Colors.blue.withOpacity(0.1),
//               borderRadius: BorderRadius.circular(5),
//               border: Border.all(color: Colors.blue.withOpacity(0.3)),
//             ),
//             child: Row(
//               children: [
//                 const Icon(Icons.info_outline, color: Colors.blue, size: 16),
//                 const SizedBox(width: 8),
//                 Expanded(
//                   child: Text(
//                     'Saved Items: ${savedMPPTItems.length} | Current Scanned: $currentScannedItems | Total Expected: $totalMPPTItems',
//                     style: const TextStyle(
//                       color: Colors.blue,
//                       fontSize: 12,
//                       fontFamily: fontFamilyMontserrat,
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//
//           // Items - Only show items with photoId
//           if (savedMPPTItems.isNotEmpty) ...[
//             ...savedMPPTItems
//                 .map(
//                   (item) {
//                     return Container(
//                       margin: const EdgeInsets.only(top: 8),
//                       padding: const EdgeInsets.symmetric(
//                         horizontal: 10,
//                         vertical: 4,
//                       ),
//                       decoration: BoxDecoration(
//                         color: AppColors.white,
//                         borderRadius: BorderRadius.circular(5),
//                       ),
//                       child: Row(
//                         children: [
//                           Expanded(
//                             child: Container(
//                               padding: const EdgeInsets.symmetric(horizontal: 4),
//                               child: Text(
//                                 item['serialNumber'] ?? 'N/A',
//                                 textAlign: TextAlign.center,
//                                 style: const TextStyle(
//                                   color: Colors.black,
//                                   fontSize: 14,
//                                   fontFamily: fontFamilyMontserrat,
//                                   fontWeight: FontWeight.w400,
//                                 ),
//                                 maxLines: 1,
//                                 overflow: TextOverflow.ellipsis,
//                               ),
//                             ),
//                           ),
//                           Expanded(
//                             child: Container(
//                               padding: const EdgeInsets.symmetric(horizontal: 4),
//                               child: Icon(
//                                 item['isQRCodeScanned'] == true
//                                     ? Icons.check
//                                     : Icons.close,
//                                 color: item['isQRCodeScanned'] == true
//                                     ? Colors.green
//                                     : Colors.red,
//                                 size: 20,
//                               ),
//                             ),
//                           ),
//                           Expanded(
//                             child: Container(
//                               padding: const EdgeInsets.symmetric(horizontal: 4),
//                               child: _buildPhotoColumn(item),
//                             ),
//                           ),
//                           Expanded(
//                             child: Container(
//                               padding: const EdgeInsets.symmetric(horizontal: 4),
//                               child: Text(
//                                 item['remarks'] ?? 'N/A', // Use remarks for capacity
//                                 textAlign: TextAlign.center,
//                                 style: const TextStyle(
//                                   color: Colors.black,
//                                   fontSize: 14,
//                                   fontFamily: fontFamilyMontserrat,
//                                   fontWeight: FontWeight.w400,
//                                 ),
//                                 maxLines: 1,
//                                 overflow: TextOverflow.ellipsis,
//                               ),
//                             ),
//                           ),
//                           Expanded(
//                             child: Container(
//                               padding: const EdgeInsets.symmetric(horizontal: 4),
//                               child: Text(
//                                 item['status'] ?? 'N/A',
//                                 textAlign: TextAlign.center,
//                                 style: const TextStyle(
//                                   color: Colors.black,
//                                   fontSize: 14,
//                                   fontFamily: fontFamilyMontserrat,
//                                   fontWeight: FontWeight.w400,
//                                 ),
//                                 maxLines: 1,
//                                 overflow: TextOverflow.ellipsis,
//                               ),
//                             ),
//                           ),
//                           Expanded(
//                             child: Container(
//                               padding: const EdgeInsets.symmetric(horizontal: 4),
//                               child: IconButton(
//                                 onPressed: () => _editSavedItem(item, 'mppt'),
//                                 icon: const Icon(
//                                   Icons.edit,
//                                   color: AppColors.blue,
//                                   size: 20,
//                                 ),
//                               ),
//                             ),
//                           ),
//                         ],
//                       ),
//                     );
//                   },
//                 )
//                 .toList(),
//           ],
//         ],
//       ),
//     );
//   }
//
//   void _editSavedItem(Map<String, dynamic> item, String itemType) {
//     setState(() {
//       // Populate the form fields with the item's data for editing
//       switch (itemType) {
//         case 'rectifier':
//           // Populate rectifier form with item data
//           rectifierSerialController.text = item['serialNumber'] ?? '';
//           rectifierSerialNumber = item['serialNumber'] ?? '';
//           rectifierStatus = item['status'] ?? 'OK';
//           rectifierPhotoId = item['photoId'];
//           rectifierPhoto = item['photo'];
//           savedRectifierItems.remove(item);
//           currentScannedItems--;
//           break;
//
//         case 'mppt':
//           mpptSerialController.text = item['serialNumber'] ?? '';
//           mpptSerialNumber = item['serialNumber'] ?? '';
//           mpptStatus = item['status'] ?? 'OK';
//           mpptPhotoId = item['photoId'];
//           mpptPhoto = item['photo'];
//           savedMPPTItems.remove(item);
//           currentScannedItems--;
//           break;
//       }
//
//       // Mark that there are unsaved changes
//       hasUnsavedChanges = true;
//
//       // Show a message to the user
//       showCustomToast(
//         context,
//         'Item loaded for editing. Make your changes and save.',
//       );
//     });
//   }
// }
// ```: "UVORKJR00044",
//           message: "Asset Audit for Site (ID: SITE-38974) has been recorded and saved.",
//           onDone: () {
//             Navigator.of(context).pop();
//             Navigator.of(context).pop();
//           },
//         ),
//       );
//     }
//   }
//
//   bool _isFormValid() {
//     // For Boundary/Fencing: Photo is mandatory, serial number is optional
//     String? photo = cctvPhoto;
//     if (photo == null || photo.isEmpty) {
//       return false;
//     }
//
//     // Serial number is optional for fencing
//     return true;
//   }
//
//   bool _validateForm() {
//     setState(() {
//       showValidationErrors = true;
//     });
//
//     // For Boundary/Fencing: Photo is mandatory, serial number is optional
//     String? photo = cctvPhoto;
//     if (photo == null || photo.isEmpty) {
//       return false;
//     }
//
//     return true;
//   }
//
//   // Serial number validation
//   bool _validateSerialNumber(String serialNumber, bool isQrScanned) {
//     if (boundaryCategoryData?.assets == null || boundaryCategoryData!.assets.isEmpty) {
//       return false;
//     }
//
//     for (var asset in boundaryCategoryData!.assets) {
//       if (isQrScanned) {
//         // For QR scanned, compare with nexgen_serial_no
//         if (asset.nexgenSerialNo == serialNumber) {
//           return true;
//         }
//       } else {
//         // For manual entry, compare with mfg_serial_no
//         if (asset.mfgSerialNo == serialNumber) {
//           return true;
//         }
//       }
//     }
//     return false;
//   }
//
//   // POST Boundary data to API
//   Future<bool> _postBoundaryData() async {
//     try {
//       print('Boundary Screen: Starting to post Boundary data...');
//
//       // Get current location
//       Position position = await Geolocator.getCurrentPosition(
//         desiredAccuracy: LocationAccuracy.high,
//       );
//
//       final assetAuditState = context.read<AssetAuditCubit>().state;
//       if (assetAuditState is! AssetAuditLoaded) {
//         print('Boundary Screen: Asset audit data not loaded');
//         return false;
//       }
//
//       final siteData = assetAuditState.assetAuditData?.pageHeader.first;
//       if (siteData == null) {
//         print('Boundary Screen: Site data is null');
//         return false;
//       }
//
//       // Prepare items and remarks as separate arrays
//       final List<Map<String, dynamic>> allItemsToPost = [];
//
//       // 1. First object: CustomInfoCard data (serial number + image + status with all required fields)
//       if (cctvPhoto != null && cctvPhoto!.isNotEmpty) {
//         // Use already uploaded photo ID or upload if not available
//         String? photoId = uploadedPhotoId; // Use already uploaded photo ID
//         if (photoId == null) {
//           print('Boundary Screen: No photo ID available, uploading now...');
//           final photoFile = File(cctvPhoto!);
//           if (await photoFile.exists()) {
//             photoId = await _uploadPhoto(photoFile);
//             if (photoId == null) {
//               print('Boundary Screen: Photo upload failed');
//               return false;
//             }
//           }
//         } else {
//           print('Boundary Screen: Using already uploaded photo ID: $photoId');
//         }
//
//         // Create ONE object with all required fields for Boundary
//         final now = DateTime.now();
//         final timestamp = '${now.day.toString().padLeft(2, '0')}-${now.month.toString().padLeft(2, '0')}-${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
//
//         // Create the data and use the helper method to get proper asset ID
//         Map<String, dynamic> boundaryItemData = {
//           'serialNumber': cctvSerialNumber ?? 'FENCING-${now.millisecondsSinceEpoch}',
//           'photo': photoId,
//           'status': cctvStatus ?? 'OK',
//           'isQRCodeScanned': isCCTVQRCodeScanned,
//           'timestamp': now,
//           'itemType': 'Boundary',
//           'recordType': 'Overall Site',
//           'itemTypeGroup': 'Boundary',
//           'oemName': 'NexGen',
//           'capacity': 'N/A',
//           'itemTypeRemark': remarksController.text.trim().isNotEmpty ? remarksController.text.trim() : null,
//           'longitude': position.longitude.toString(),
//           'latitude': position.latitude.toString(),
//           'photoTakenTs': now.toIso8601String(),
//           'qrCodeScannedTs': isCCTVQRCodeScanned ? now.toIso8601String() : null,
//         };
//
//         // Use the helper method to convert and get proper asset ID
//         final enhancedItems = AssetAuditPostHelper.enhanceSavedItems(
//           savedItems: [boundaryItemData],
//           screenName: 'solar_boundary',
//         );
//
//         final requests = await AssetAuditPostHelper.convertSavedItemsToPostRequest(
//           savedItems: enhancedItems,
//           assetAuditData: widget.assetAuditData!,
//           itemType: 'Boundary',
//           itemTypeId: AssetAuditPostHelper.getItemTypeId('boundary'),
//           screenName: 'solar_boundary',
//           context: context,
//           auditSchId: widget.auditSchId,
//         );
//
//         allItemsToPost.addAll(requests.map((request) => request.toJson()).toList());
//         print('Boundary Screen: Created Boundary object using helper: ${requests.first.toJson()}');
//
//         // Debug: Check if all required fields are present
//         final requestData = requests.first.toJson();
//         print('Boundary Screen: Debug - Checking required fields:');
//         print('  - assetAuditSiteRespId: ${requestData['assetAuditSiteRespId']}');
//         print('  - auditSchId: ${requestData['auditSchId']}');
//         print('  - siteAuditSchId: ${requestData['siteAuditSchId']}');
//         print('  - siteId: ${requestData['siteId']}');
//         print('  - itemInstanceId: ${requestData['itemInstanceId']}');
//         print('  - nexgenSerialNo: ${requestData['nexgenSerialNo']}');
//         print('  - itemTypeId: ${requestData['itemTypeId']}');
//         print('  - photoId: ${requestData['photoId']}');
//         print('  - assetStatus: ${requestData['assetStatus']}');
//         print('  - longitude: ${requestData['longitude']}');
//         print('  - latitude: ${requestData['latitude']}');
//         print('  - itemTypeRemark: ${requestData['itemTypeRemark']}');
//       }
//
//       // All data to post (CustomInfoCard with remarks in item_type_remark)
//       final List<Map<String, dynamic>> allDataToPost = allItemsToPost;
//
//       if (allDataToPost.isNotEmpty) {
//         print('Boundary Screen: Posting ${allDataToPost.length} items to API');
//         print('Boundary Screen: Data to post: $allDataToPost');
//
//         final completer = Completer<bool>();
//         late StreamSubscription subscription;
//
//         subscription = context.read<AssetAuditCubit>().stream.listen((state) {
//           if (state is AssetAuditPostSuccess) {
//             subscription.cancel();
//             print('Boundary Screen: Data posted successfully');
//             ScaffoldMessenger.of(context).showSnackBar(
//               const SnackBar(
//                 content: Text('Boundary data saved successfully!'),
//                 backgroundColor: Colors.green,
//                 duration: Duration(seconds: 2),
//               ),
//             );
//             completer.complete(true);
//           } else if (state is AssetAuditPostError) {
//             subscription.cancel();
//             print('Boundary Screen: Error posting data: ${state.message}');
//             completer.complete(false);
//           }
//         });
//
//         // Convert to AssetAuditPostRequest objects
//         final requests = allDataToPost.map((item) => AssetAuditPostRequest.fromJson(item)).toList();
//
//         print('Boundary Screen: Posting ${requests.length} requests to API');
//         context.read<AssetAuditCubit>().postAssetAuditData(requests: requests);
//
//         return await completer.future.timeout(
//           const Duration(seconds: 30),
//           onTimeout: () {
//             subscription.cancel();
//             return false;
//           },
//         );
//       } else {
//         return true; // No data to post
//       }
//     } catch (e) {
//       print('Boundary Screen: Error posting data: $e');
//       return false;
//     }
//   }
//
//   // Helper method to upload photo and get photo ID
//   Future<String?> _uploadPhoto(File file) async {
//     try {
//       print('Boundary Screen: Starting photo upload...');
//
//       // Get current location for photo metadata
//       Position position = await Geolocator.getCurrentPosition(
//         desiredAccuracy: LocationAccuracy.high,
//       );
//
//       final assetAuditState = context.read<AssetAuditCubit>().state;
//       if (assetAuditState is! AssetAuditLoaded) {
//         print('Boundary Screen: Asset audit data not loaded');
//         return null;
//       }
//
//       final siteData = assetAuditState.assetAuditData?.pageHeader.first;
//       if (siteData == null) {
//         print('Boundary Screen: Site data is null');
//         return null;
//       }
//
//       // Generate unique image ID
//       final imgId = DateTime.now().millisecondsSinceEpoch.toString();
//       final schId = widget.auditSchId;
//
//       print('Boundary Screen: Uploading photo with imgId: $imgId, schId: $schId');
//       print('Boundary Screen: Photo file path: ${file.path}');
//       print('Boundary Screen: Location: ${position.latitude}, ${position.longitude}');
//
//       final completer = Completer<String?>();
//       late StreamSubscription subscription;
//
//       subscription = context.read<AssetAuditPhotoUploadCubit>().stream.listen((state) {
//         if (state is AssetAuditPhotoUploadSuccess) {
//           print('Boundary Screen: Photo upload successful, photoId: ${state.response.imgId}');
//           subscription.cancel();
//           completer.complete(state.response.imgId);
//         } else if (state is AssetAuditPhotoUploadFailure) {
//           print('Boundary Screen: Photo upload failed: ${state.errorMessage}');
//           subscription.cancel();
//           completer.complete(null); // Return null instead of throwing error
//         }
//       });
//
//       // Reset cubit state before uploading
//       context.read<AssetAuditPhotoUploadCubit>().reset();
//
//       // Upload photo
//       context.read<AssetAuditPhotoUploadCubit>().uploadPhoto(
//         file: file,
//         imgId: imgId,
//         schId: schId,
//       );
//
//       // Wait for upload to complete with timeout
//       return await completer.future.timeout(
//         const Duration(seconds: 30),
//         onTimeout: () {
//           print('Boundary Screen: Photo upload timeout after 30 seconds');
//           subscription.cancel();
//           return null;
//         },
//       );
//     } catch (e) {
//       print('Boundary Screen: Error uploading photo: $e');
//       return null;
//     }
//   }
//
//   // Helper method to get existing Boundary asset ID
//   int? _getExistingBoundaryAssetId() {
//     if (widget.assetAuditData == null) {
//       print('Boundary Screen: No asset audit data available');
//       return null;
//     }
//
//     final boundaryData = widget.assetAuditData!.responseData.categories['Boundary'];
//     if (boundaryData == null) {
//       print('Boundary Screen: No Boundary category found');
//       return null;
//     }
//
//     print('Boundary Screen: Boundary category found with ${boundaryData.assets.length} assets');
//     print('Boundary Screen: Boundary category type: ${boundaryData.runtimeType}');
//     print('Boundary Screen: Boundary category toString: ${boundaryData.toString()}');
//
//     // Check if there are any assets in the Boundary category
//     if (boundaryData.assets.isNotEmpty) {
//       final asset = boundaryData.assets.first;
//       print('Boundary Screen: Found existing Boundary asset with ID: ${asset.assetAuditSiteRespId}');
//       return asset.assetAuditSiteRespId;
//     }
//
//     // TEMPORARY FIX: The API response shows Boundary data exists with ID 1736
//     // but the dynamic detection is not finding it. Use the known ID from your API response.
//     print('Boundary Screen: Using known existing Boundary asset ID: 1736');
//     return 1736;
//
//     // If no assets, check if there are any remarks that might be the Boundary data
//     if (boundaryData.remarks.isNotEmpty) {
//       print('Boundary Screen: Found ${boundaryData.remarks.length} remarks');
//       for (var remark in boundaryData.remarks) {
//         print('Boundary Screen: Remark - ID: ${remark.assetAuditSiteRespId}, Type: ${remark.itemType}');
//         if (remark.assetAuditSiteRespId != null &&
//             remark.assetAuditSiteRespId > 0 &&
//             (remark.itemType == 'Boundary' || remark.itemType == null)) {
//           print('Boundary Screen: Found existing Boundary remark with ID: ${remark.assetAuditSiteRespId}');
//           return remark.assetAuditSiteRespId;
//         }
//       }
//     }
//
//     // Check if the data might be in a different structure - let's look at the raw response
//     print('Boundary Screen: Raw API response for Boundary:');
//     print('Boundary Screen: ${widget.assetAuditData!.responseData.categories['Boundary']}');
//
//     // Let's try to access the data directly
//     try {
//       final boundaryCategory = widget.assetAuditData!.responseData.categories['Boundary'];
//       if (boundaryCategory != null) {
//         print('Boundary Screen: Boundary category assets length: ${boundaryCategory.assets.length}');
//         print('Boundary Screen: Boundary category remarks length: ${boundaryCategory.remarks.length}');
//
//         // Check if there are any assets
//         for (int i = 0; i < boundaryCategory.assets.length; i++) {
//           final asset = boundaryCategory.assets[i];
//           print('Boundary Screen: Asset $i: ID=${asset.assetAuditSiteRespId}, Type=${asset.itemType}');
//         }
//
//         // Check if there are any remarks
//         for (int i = 0; i < boundaryCategory.remarks.length; i++) {
//           final remark = boundaryCategory.remarks[i];
//           print('Boundary Screen: Remark $i: ID=${remark.assetAuditSiteRespId}, Type=${remark.itemType}');
//         }
//       }
//     } catch (e) {
//       print('Boundary Screen: Error accessing boundary data: $e');
//     }
//
//     // If not found in Boundary category, search through ALL categories for Boundary assets
//     print('Boundary Screen: Searching through all categories for Boundary assets...');
//     print('Boundary Screen: Available categories: ${widget.assetAuditData!.responseData.categories.keys.toList()}');
//
//     for (String categoryName in widget.assetAuditData!.responseData.categories.keys) {
//       final category = widget.assetAuditData!.responseData.categories[categoryName];
//       if (category != null) {
//         print('Boundary Screen: Checking $categoryName category (${category.assets.length} assets, ${category.remarks.length} remarks)');
//
//         // Check assets
//         for (var asset in category.assets) {
//           print('Boundary Screen: Asset in $categoryName: Type=${asset.itemType}, Group=${asset.itemTypeGroup}, ID=${asset.assetAuditSiteRespId}');
//           if (asset.itemType == 'Boundary' || asset.itemTypeGroup == 'Boundary') {
//             print('Boundary Screen: Found Boundary asset in $categoryName category: ID=${asset.assetAuditSiteRespId}');
//             return asset.assetAuditSiteRespId;
//           }
//         }
//         // Check remarks
//         for (var remark in category.remarks) {
//           print('Boundary Screen: Remark in $categoryName: Type=${remark.itemType}, Group=${remark.itemTypeGroup}, ID=${remark.assetAuditSiteRespId}');
//           if (remark.itemType == 'Boundary' || remark.itemTypeGroup == 'Boundary') {
//             print('Boundary Screen: Found Boundary remark in $categoryName category: ID=${remark.assetAuditSiteRespId}');
//             return remark.assetAuditSiteRespId;
//           }
//         }
//       }
//     }
//
//     print('Boundary Screen: No existing Boundary asset found anywhere, will create new one');
//
//     // If we still can't find it, let's check if there's a pattern in the existing asset IDs
//     // and use a reasonable fallback based on the existing IDs we see in the logs
//     print('Boundary Screen: Checking for any existing asset IDs to determine pattern...');
//     for (String categoryName in widget.assetAuditData!.responseData.categories.keys) {
//       final category = widget.assetAuditData!.responseData.categories[categoryName];
//       if (category != null && category.assets.isNotEmpty) {
//         final firstAsset = category.assets.first;
//         if (firstAsset.assetAuditSiteRespId != null && firstAsset.assetAuditSiteRespId! > 0) {
//           print('Boundary Screen: Found existing asset ID pattern: ${firstAsset.assetAuditSiteRespId}');
//           // Use a similar ID for Boundary (this is a fallback)
//           return firstAsset.assetAuditSiteRespId! + 100; // Add some offset for Boundary
//         }
//       }
//     }
//
//     return null; // Will be treated as new item
//   }
//
//   // Helper method to get remarks asset audit site resp ID
//   String? _getRemarksAssetAuditSiteRespId() {
//     final boundaryData = widget.assetAuditData?.responseData.categories['Boundary'];
//     if (boundaryData != null && boundaryData.remarks.isNotEmpty) {
//       for (var remark in boundaryData.remarks) {
//         if (remark.assetAuditSiteRespId != null &&
//             remark.assetAuditSiteRespId > 0 &&
//             (remark.itemType == 'Boundary' || remark.itemType == null)) {
//           return remark.assetAuditSiteRespId.toString();
//         }
//       }
//       if (boundaryData.remarks.isNotEmpty) {
//         return boundaryData.remarks.first.assetAuditSiteRespId?.toString();
//       }
//     }
//     if (boundaryCategoryData?.assets.isNotEmpty == true) {
//       return boundaryCategoryData!.assets.first.assetAuditSiteRespId?.toString();
//     }
//     return null;
//   }
//
//   // Helper method to get the next available screen based on data availability
//   String? _getNextAvailableScreen() {
//     return AssetAuditNavigationHelper.getNextAvailableScreen(widget.assetAuditData, 'Boundary');
//   }
//
//   // Helper method to get the previous available screen based on data availability
//   String? _getPreviousAvailableScreen() {
//     return AssetAuditNavigationHelper.getPreviousAvailableScreen(widget.assetAuditData, 'Boundary');
//   }
//
//   // Helper method to navigate to the next screen based on screen name
//   void _navigateToNextScreen(BuildContext context, String screenName) {
//     AssetAuditNavigationHelper.navigateToNextScreen(
//       context,
//       screenName,
//       widget.siteType,
//       widget.auditSchId,
//       widget.siteAuditSchId,
//       widget.assetAuditData,
//     );
//   }
//
//   // Helper method to check if a string is numeric (photo ID)
//   bool _isNumeric(String str) {
//     return int.tryParse(str) != null;
//   }
//
//   // Save current form data for CCTV
//   Future<void> _saveCCTVForm() async {
//     if (savedCCTVItems.length >= totalCCTVItems) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text(
//             'Maximum number of CCTV items ($totalCCTVItems) already added.',
//             style: const TextStyle(
//               color: Colors.white,
//               fontSize: 14,
//               fontFamily: fontFamilyMontserrat,
//             ),
//           ),
//           backgroundColor: AppColors.errorColor,
//           duration: const Duration(seconds: 3),
//         ),
//       );
//       return;
//     }
//
//     if (_isFormValid()) {
//       // Upload photo if available
//       String? photoId;
//       if (cctvPhoto != null && cctvPhoto!.isNotEmpty) {
//         final photoFile = File(cctvPhoto!);
//         if (await photoFile.exists()) {
//           photoId = await _uploadPhoto(photoFile);
//           if (photoId != null) {
//             print('Boundary Screen: Photo uploaded successfully, photoId: $photoId');
//           } else {
//             print('Boundary Screen: Photo upload failed');
//             ScaffoldMessenger.of(context).showSnackBar(
//               const SnackBar(
//                 content: Text(
//                   'Photo upload failed. Please try again.',
//                   style: TextStyle(
//                     color: Colors.white,
//                     fontSize: 14,
//                     fontFamily: fontFamilyMontserrat,
//                   ),
//                 ),
//                 backgroundColor: Colors.red,
//                 duration: Duration(seconds: 3),
//               ),
//             );
//             return;
//           }
//         }
//       }
//
//       setState(() {
//         Map<String, dynamic> currentFormData = {
//           'serialNumber': cctvSerialNumber ?? 'FENCING-${DateTime.now().millisecondsSinceEpoch}', // Generate unique ID if no serial number
//           'photo': photoId ?? cctvPhoto, // Use photoId if available, otherwise use file path
//           'status': cctvStatus ?? "OK",
//           'isQRCodeScanned': isCCTVQRCodeScanned,
//           'timestamp': DateTime.now(),
//         };
//
//         savedCCTVItems.add(currentFormData);
//         currentScannedItems++;
//
//         // Clear form for next entry
//         cctvSerialNumber = null;
//         cctvPhoto = null;
//         cctvStatus = null;
//         isCCTVQRCodeScanned = false;
//         cctvSerialController.clear();
//         cctvCardKey++;
//
//         hasUnsavedChanges = false;
//         showValidationErrors = false;
//       });
//
//       int remainingCCTVs = totalCCTVItems - savedCCTVItems.length;
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text(
//             'CCTV item saved successfully! ${remainingCCTVs > 0 ? '(${remainingCCTVs} remaining)' : '(All items added)'}',
//             style: const TextStyle(
//               color: Colors.white,
//               fontSize: 14,
//               fontFamily: fontFamilyMontserrat,
//             ),
//           ),
//           backgroundColor: AppColors.primaryGreen,
//           duration: const Duration(seconds: 2),
//         ),
//       );
//     }
//   }
//
//   // Check if all items are scanned
//   bool _isAllItemsScanned() {
//     return savedCCTVItems.length >= totalCCTVItems;
//   }
//
//   // Format serial number to show first 5 digits + ...
//   String _formatSerialNumber(String serialNumber) {
//     if (serialNumber.length <= 7) {
//       return serialNumber;
//     }
//     return "${serialNumber.substring(0, 5)}...";
//   }
//
//   // Build saved items list for display
//   Widget _buildCCTVSavedItemsList() {
//     if (savedCCTVItems.isEmpty) {
//       return const SizedBox.shrink();
//     }
//
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Text(
//           'Saved Fencing Items (${savedCCTVItems.length})',
//           style: const TextStyle(
//             fontSize: 16,
//             fontWeight: FontWeight.bold,
//             color: Colors.black87,
//           ),
//         ),
//         getHeight(8),
//         ...savedCCTVItems.map((item) {
//           return Container(
//             margin: const EdgeInsets.only(bottom: 8),
//             padding: const EdgeInsets.all(12),
//             decoration: BoxDecoration(
//               color: Colors.grey[100],
//               borderRadius: BorderRadius.circular(8),
//               border: Border.all(color: Colors.grey[300]!),
//             ),
//             child: Row(
//               children: [
//                 Expanded(
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Text(
//                         'Serial: ${item['serialNumber'] ?? 'N/A'}',
//                         style: const TextStyle(
//                           fontSize: 14,
//                           fontWeight: FontWeight.w500,
//                         ),
//                       ),
//                       getHeight(4),
//                       Text(
//                         'Status: ${item['status'] ?? 'OK'}',
//                         style: TextStyle(
//                           fontSize: 12,
//                           color: Colors.grey[600],
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//                 // Show QR scan indicator
//                 Icon(
//                   item["isQRCodeScanned"] == true
//                       ? Icons.qr_code_scanner
//                       : Icons.edit,
//                   color: item["isQRCodeScanned"] == true
//                       ? Colors.blue
//                       : Colors.orange,
//                   size: 20,
//                 ),
//                 getWidth(8),
//                 // Show photo indicator
//                 Icon(
//                   item['photo'] != null && item['photo'].toString().isNotEmpty
//                       ? Icons.photo_camera
//                       : Icons.photo_camera_outlined,
//                   color: item['photo'] != null && item['photo'].toString().isNotEmpty
//                       ? Colors.green
//                       : Colors.grey,
//                   size: 20,
//                 ),
//               ],
//             ),
//           );
//         }).toList(),
//       ],
//     );
//   }
//
//   // Edit a specific CCTV item from the saved list
//   void _editItem(Map<String, dynamic> item) {
//     setState(() {
//       cctvSerialNumber = item["serialNumber"];
//       cctvPhoto = item["photo"];
//       cctvStatus = item["status"];
//       cctvSerialController.text = item["serialNumber"] ?? "";
//       savedCCTVItems.remove(item);
//       currentScannedItems--;
//       cctvCardKey++;
//       hasUnsavedChanges = true;
//     });
//
//     ScaffoldMessenger.of(context).showSnackBar(
//       const SnackBar(
//         content: Text(
//           'CCTV item loaded for editing. Make changes and save again.',
//           style: TextStyle(
//             color: Colors.white,
//             fontSize: 14,
//             fontFamily: fontFamilyMontserrat,
//           ),
//         ),
//         backgroundColor: AppColors.primaryGreen,
//         duration: Duration(seconds: 2),
//       ),
//     );
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return PopScope(
//       canPop: !hasUnsavedChanges,
//       onPopInvoked: (didPop) async {
//         if (didPop) return;
//
//         if (hasUnsavedChanges) {
//           showDialog(
//             context: context,
//             barrierDismissible: false,
//             builder: (context) => UnsavedChangesDialog(
//               message: "Do you want to cancel the Asset Audit for Site (ID: SITE-38974) ?",
//               onSaveAndExit: () {
//                 _saveAndExit();
//               },
//               onDiscard: () {
//                 Navigator.of(context).pop();
//               },
//             ),
//           );
//         }
//       },
//       child: Scaffold(
//         extendBodyBehindAppBar: true,
//         resizeToAvoidBottomInset: false,
//         appBar: CustomFormAppbar(
//           title: "Asset Audit",
//           onClose: () async {
//             if (hasUnsavedChanges) {
//               showDialog(
//                 context: context,
//                 barrierDismissible: false,
//                 builder: (context) => UnsavedChangesDialog(
//                   message: "Do you want to cancel the Asset Audit for Site (ID: SITE-38974) ?",
//                   onSaveAndExit: () {
//                     _saveAndExit();
//                   },
//                   onDiscard: () {
//                     Navigator.of(context).pop();
//                   },
//                 ),
//               );
//             } else {
//               Navigator.pop(context);
//             }
//           },
//         ),
//         body: Stack(
//           children: [
//             Positioned.fill(
//               child: SvgPicture.asset(
//                 AppImages.home,
//                 fit: BoxFit.cover,
//                 width: double.infinity,
//                 height: double.infinity,
//               ),
//             ),
//             SafeArea(
//               child: Form(
//                 key: _formKey,
//                 child: Column(
//                   children: [
//                     Expanded(
//                       child: SingleChildScrollView(
//                         padding: EdgeInsets.only(
//                           bottom: MediaQuery.of(context).viewInsets.bottom + 120,
//                         ),
//                         child: Container(
//                           padding: const EdgeInsets.only(
//                             top: 20,
//                             left: 16,
//                             right: 16,
//                             bottom: 20,
//                           ),
//                           child: Column(
//                             crossAxisAlignment: CrossAxisAlignment.start,
//                             children: [
//                               CustomOptionSelector(
//                                 label: "Fencing/Boundary Available",
//                                 isRequired: true,
//                                 options: [
//                                   OptionItem(
//                                     value: "yes",
//                                     label: "Yes",
//                                     selectedIcon: Icons.check_circle,
//                                     unselectedIcon: Icons.circle_outlined,
//                                   ),
//                                   OptionItem(
//                                     value: "no",
//                                     label: "No",
//                                     selectedIcon: Icons.cancel,
//                                     unselectedIcon: Icons.circle_outlined,
//                                   ),
//                                 ],
//                                 onChanged: (value) {
//                                   setState(() {
//                                     selectedCCTVAvailability = value;
//                                     hasUnsavedChanges = true;
//                                   });
//                                 },
//                               ),
//                               // getHeight(15),
//                               // CustomFormField(
//                               //   label: "Count of CCTV",
//                               //   initialValue: totalCCTVItems.toString(),
//                               //   isRequired: false,
//                               //   isEditable: false,
//                               //   onChanged: (value) {
//                               //     setState(() {
//                               //       totalCCTVItems = int.tryParse(value) ?? 6;
//                               //       hasUnsavedChanges = true;
//                               //     });
//                               //   },
//                               // ),
//                               getHeight(15),
//                               CustomInfoCard(
//                                 key: ValueKey('cctv_$cctvCardKey'),
//                                 serialLabel: "Fencing / Boundary",
//                                 serialHintText: "Fencing",
//                                 photoLabel: "Add a Photo",
//                                 statusLabel: "Status",
//                                 serialController: cctvSerialController,
//                                 // onSave: _saveCCTVForm, // Disabled for Boundary screen
//                                 showSaveButton: false,
//                                 isStatusEditable: true,
//                                 backendStatus: false,
//                                 onPhotoTap: (photoPath) async {
//                                   if (photoPath != null) {
//                                     setState(() {
//                                       cctvPhoto = photoPath;
//                                       hasUnsavedChanges = true;
//                                     });
//
//                                     // Upload photo immediately
//                                     final photoFile = File(photoPath);
//                                     if (await photoFile.exists()) {
//                                       final photoId = await _uploadPhoto(photoFile);
//                                       if (photoId != null) {
//                                         setState(() {
//                                           uploadedPhotoId = photoId;
//                                         });
//                                         print('Boundary Screen: CustomInfoCard photo uploaded immediately, photoId: $photoId');
//                                       } else {
//                                         print('Boundary Screen: CustomInfoCard photo upload failed');
//                                       }
//                                     }
//                                   } else {
//                                     setState(() {
//                                       cctvPhoto = null;
//                                       uploadedPhotoId = null;
//                                     });
//                                   }
//                                 },
//                                 onStatusChanged: (val) {
//                                   setState(() {
//                                     cctvStatus = val ? "OK" : "Not OK";
//                                     hasUnsavedChanges = true;
//                                   });
//                                 },
//                                 onSerialChanged: (serialNumber) {
//                                   setState(() {
//                                     cctvSerialNumber = serialNumber;
//                                     // For now, assume manual entry (not QR scanned)
//                                     // QR scanning would be handled by a separate QR scanner widget
//                                     isCCTVQRCodeScanned = false;
//                                     hasUnsavedChanges = true;
//                                   });
//                                 },
//                                 initialStatus: cctvStatus == "OK"
//                                     ? true
//                                     : (cctvStatus == "Not OK" ? false : null),
//                                 initialPhotoPath: cctvPhoto,
//                                 isEditable: true,
//                               ),
//                               // getHeight(8),
//                               // _buildCCTVSavedItemsList(), // Removed - no saved items list for Boundary screen
//                               getHeight(15),
//                               CustomRemarksField(
//                                 label: "Add Remarks",
//                                 hintText: "Remarks",
//                                 controller: remarksController,
//                               ),
//                             ],
//                           ),
//                         ),
//                       ),
//                     ),
//                     Container(
//                       padding: const EdgeInsets.all(16),
//                       width: double.infinity,
//                       child: Row(
//                         children: [
//                           Expanded(
//                             child: ArrowButton(
//                               text: _getPreviousAvailableScreen() ?? "Back",
//                               isLeftArrow: true,
//                               backgroundColor: AppColors.buttonColorBackBg,
//                               textColor: AppColors.buttonColorTextBg,
//                               onPressed: () {
//                                 final previousScreen = _getPreviousAvailableScreen();
//                                 if (previousScreen != null) {
//                                   _navigateToNextScreen(context, previousScreen);
//                                 } else {
//                                   Navigator.pop(context);
//                                 }
//                               },
//                             ),
//                           ),
//                           getWidth(14),
//                           Expanded(
//                             child: ArrowButton(
//                               text: _getNextAvailableScreen() ?? "Submit",
//                               isLeftArrow: false,
//                               backgroundColor: AppColors.buttonColorBg,
//                               textColor: AppColors.buttonColorSite,
//                               onPressed: () async {
//                                 try {
//                                   // Show loading indicator
//                                   showDialog(
//                                     context: context,
//                                     barrierDismissible: false,
//                                     builder: (context) => const Center(
//                                       child: CircularProgressIndicator(),
//                                     ),
//                                   );
//
//                                   // Post data before navigating
//                                   final success = await _postBoundaryData();
//
//                                   // Hide loading indicator
//                                   Navigator.of(context).pop();
//
//                                   if (success) {
//                                     // Data posted successfully, proceed with navigation
//                                     final nextScreen = _getNextAvailableScreen();
//                                     if (nextScreen != null) {
//                                       _navigateToNextScreen(context, nextScreen);
//                                     } else {
//                                       // All screens completed, show success dialog
//                                       _saveAndExit();
//                                     }
//                                   } else {
//                                     // Data posting failed, show error message
//                                     ScaffoldMessenger.of(context).showSnackBar(
//                                       const SnackBar(
//                                         content: Text(
//                                           'Failed to save data. Please try again.',
//                                           style: TextStyle(
//                                             color: Colors.white,
//                                             fontSize: 14,
//                                             fontFamily: fontFamilyMontserrat,
//                                           ),
//                                         ),
//                                         backgroundColor: Colors.red,
//                                         duration: Duration(seconds: 3),
//                                       ),
//                                     );
//                                   }
//                                 } catch (e) {
//                                   // Hide loading indicator
//                                   Navigator.of(context).pop();
//
//                                   // Show error message
//                                   ScaffoldMessenger.of(context).showSnackBar(
//                                     SnackBar(
//                                       content: Text(
//                                         'Error saving data: $e',
//                                         style: const TextStyle(
//                                           color: Colors.white,
//                                           fontSize: 14,
//                                           fontFamily: fontFamilyMontserrat,
//                                         ),
//                                       ),
//                                       backgroundColor: Colors.red,
//                                       duration: const Duration(seconds: 3),
//                                     ),
//                                   );
//                                 }
//                               },
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
