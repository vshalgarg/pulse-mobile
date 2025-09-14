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

  // Form submission loading state
  bool isSubmittingForm = false;

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

  Future<void> _saveAndExit() async {
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
    if (isSubmittingForm) return; // Prevent multiple submissions

    setState(() {
      isSubmittingForm = true;
    });

    try {
      // Post Boundary data to API first
      final success = await _postBoundaryData();

      if (success) {
        // Update audit schedule status to Complete
        await _updateAuditScheduleStatus("Complete");

        // Clear loading state before showing success dialog
        setState(() {
          isSubmittingForm = false;
        });

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
      } else {
        // Posting failed
        setState(() {
          isSubmittingForm = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save data. Please try again.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      setState(() {
        isSubmittingForm = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving data: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  bool _isFormValid() {
    if (selectedCCTVAvailability == null) {
      return false;
    }

    // If user selected "No" for fencing availability, no photo required
    if (selectedCCTVAvailability == "no") {
      return true;
    }

    // If user selected "Yes" for fencing availability, photo is required
    if (selectedCCTVAvailability == "yes") {
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
    }

    return true;
  }

  Future<bool> _postBoundaryData() async {
    try {
      print('=== _postBoundaryData() START ===');
      print('selectedCCTVAvailability: $selectedCCTVAvailability');
      print('cctvPhoto: $cctvPhoto');
      print('uploadedPhotoId: $uploadedPhotoId');

      if (!_isFormValid()) {
        print('❌ Form validation failed');
        setState(() {
          showValidationErrors = true;
        });
        return false;
      }
      print('✅ Form validation passed');

      // If user selected "No" for fencing availability, no need to post boundary data
      if (selectedCCTVAvailability == "no") {
        print('✅ Fencing not available - skipping boundary data posting');
        return true; // Return true to allow navigation
      }
      print('✅ Fencing available - proceeding with data posting');

      // Use widget's assetAuditData instead of cubit state
      if (widget.assetAuditData == null || widget.assetAuditData!.pageHeader.isEmpty) {
        print('❌ Widget assetAuditData is null or pageHeader is empty');
        return false;
      }
      print('✅ Widget assetAuditData loaded');

      final siteData = widget.assetAuditData!.pageHeader.first;
      print('✅ Site data loaded: ${siteData.siteId}');

      final now = DateTime.now();
      print('✅ Getting current position...');
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      print('✅ Position obtained: ${position.latitude}, ${position.longitude}');

      String? photoId = uploadedPhotoId;
      print('✅ Initial photoId: $photoId');

      if (cctvPhoto != null && cctvPhoto!.isNotEmpty && !_isNumeric(cctvPhoto!)) {
        print('✅ Processing photo: ${cctvPhoto!.substring(0, cctvPhoto!.length > 50 ? 50 : cctvPhoto!.length)}...');

        if (cctvPhoto!.startsWith('data:image/')) {
          print('✅ Uploading base64 photo...');
          // Handle base64 image data
          photoId = await _uploadBase64Photo(cctvPhoto!);
          if (photoId == null) {
            print('❌ Failed to upload base64 photo');
            return false;
          }
          print('✅ Base64 photo uploaded successfully: $photoId');
        } else {
          print('✅ Uploading file photo...');
          // Handle file path
          final photoFile = File(cctvPhoto!);
          if (await photoFile.exists()) {
            photoId = await _uploadPhoto(photoFile);
            if (photoId == null) {
              print('❌ Failed to upload file photo');
              return false;
            }
            print('✅ File photo uploaded successfully: $photoId');
          } else {
            print('❌ Photo file does not exist: ${cctvPhoto}');
            return false;
          }
        }
      } else {
        print('✅ Using existing photoId or no photo processing needed');
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

      print('✅ Posting boundary data to API...');
      print('✅ Number of requests: ${requests.length}');
      print('✅ First request data: ${requests.first.nexgenSerialNo}');

      context.read<AssetAuditCubit>().postAssetAuditData(requests: requests);

      print('✅ Waiting for API response...');
      final result = await completer.future.timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          print('❌ API call timed out after 60 seconds');
          subscription.cancel();
          return false;
        },
      );

      print('✅ API call result: $result');

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

      print('=== _postBoundaryData() FINAL RESULT: $result ===');
      return result;
    } catch (e) {
      print('=== _postBoundaryData() ERROR: $e ===');
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
    return null;
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
                  await _saveAndExit();
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
                      await _saveAndExit();
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
                                text: isSubmittingForm ? "Submitting..." : (_getNextAvailableScreen() ?? "Submit"),
                                isLeftArrow: false,
                                backgroundColor: isSubmittingForm
                                    ? AppColors.buttonColorBg.withOpacity(0.6)
                                    : AppColors.buttonColorBg,
                                textColor: AppColors.buttonColorSite,
                                onPressed: isSubmittingForm ? null : () async {
                                  // Prevent multiple submissions
                                  if (isSubmittingForm) return;

                                  // Validate form first
                                  if (!_isFormValid()) {
                                    setState(() {
                                      showValidationErrors = true;
                                    });
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(selectedCCTVAvailability == "yes"
                                            ? 'Please add a photo of the fencing/boundary'
                                            : 'Please select fencing/boundary availability'),
                                        backgroundColor: Colors.red,
                                        duration: const Duration(seconds: 3),
                                      ),
                                    );
                                    return;
                                  }

                                  // Set loading state immediately
                                  setState(() {
                                    isSubmittingForm = true;
                                  });

                                  try {
                                    print('=== SUBMIT BUTTON: Calling _postBoundaryData() ===');
                                    final success = await _postBoundaryData();
                                    print('=== SUBMIT BUTTON: _postBoundaryData() returned: $success ===');

                                    if (success) {
                                      // Clear loading state before navigation
                                      setState(() {
                                        isSubmittingForm = false;
                                      });

                                      final nextScreen = _getNextAvailableScreen();
                                      if (nextScreen != null) {
                                        _navigateToNextScreen(context, nextScreen);
                                      } else {
                                        _submitAndComplete();
                                      }
                                    } else {
                                      // API call failed
                                      print('=== SUBMIT BUTTON: API call failed, showing error ===');
                                      setState(() {
                                        isSubmittingForm = false;
                                      });
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Failed to save data. Please try again.'),
                                          backgroundColor: Colors.red,
                                          duration: Duration(seconds: 3),
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    setState(() {
                                      isSubmittingForm = false;
                                    });
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Error submitting form: $e'),
                                        backgroundColor: Colors.red,
                                        duration: const Duration(seconds: 3),
                                      ),
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
              // Full-screen loading overlay
              if (isSubmittingForm)
                Container(
                  color: Colors.black.withOpacity(0.5),
                  child: const Center(
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 3,
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

