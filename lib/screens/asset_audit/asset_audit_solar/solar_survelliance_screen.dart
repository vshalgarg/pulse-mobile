import 'package:app/commonWidgets/custom_buttons/arrow_botton.dart';
import 'package:app/constants/constants_methods.dart';
import 'package:app/utils/asset_audit_navigation_helper.dart';
import 'package:app/utils/asset_audit_post_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:io';
import 'dart:async';
import 'dart:convert';

import '../../../bloc/asset_audit_cubit.dart';
import '../../../bloc/asset_audit_state.dart';
import '../../../bloc/asset_audit_photo_upload_cubit.dart';
import '../../../bloc/asset_audit_get_image_cubit.dart';
import '../../../bloc/audit_schedule_status_cubit.dart';
import '../../../commonWidgets/asset_type_card.dart';
import '../../../commonWidgets/custom_dialogs/unsaved_changes_dialog.dart';
import '../../../commonWidgets/custom_form_appbar.dart';
import '../../../commonWidgets/custom_form_field.dart';
import '../../../commonWidgets/custom_remark.dart';
import '../../../commonWidgets/asset_type_card.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_images.dart';
import '../../../constants/constants_strings.dart';
import '../../../models/asset_audit_model.dart';
import '../../home_screen.dart';

class SolarSurveillanceScreen extends StatefulWidget {
  final String siteType;
  final String auditSchId;
  final String siteAuditSchId;
  final AssetAuditModel? assetAuditData; // Complete asset audit data

  const SolarSurveillanceScreen({
    super.key,
    required this.siteType,
    required this.auditSchId,
    required this.siteAuditSchId,
    this.assetAuditData, // Complete asset audit data
  });

  @override
  State<SolarSurveillanceScreen> createState() => _SolarSurveillanceScreenState();
}


class _SolarSurveillanceScreenState extends State<SolarSurveillanceScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController serialController = TextEditingController();
  bool hasUnsavedChanges = false;
  bool showValidationErrors = false;
  String? surveillanceSerialNumber;
  String? surveillancePhoto;
  String? surveillanceStatus;
  final remarksController = TextEditingController();
  final ratingController = TextEditingController();
  int surveillanceCardKey = 0;
  List<Map<String, dynamic>> _savedSurveillanceItems = [];
  
  // Getter and setter for savedSurveillanceItems with debug logging
  List<Map<String, dynamic>> get savedSurveillanceItems => _savedSurveillanceItems;
  set savedSurveillanceItems(List<Map<String, dynamic>> value) {
    print('🔄 Surveillance: savedSurveillanceItems being modified');
    print('🔄 Surveillance: Old length: ${_savedSurveillanceItems.length}');
    print('🔄 Surveillance: New length: ${value.length}');
    print('🔄 Surveillance: Stack trace: ${StackTrace.current}');
    _savedSurveillanceItems = value;
  }
  bool isQRCodeScanned = false;
  String? lastValidatedSerial;

  String? uploadedPhotoPath;
  String? uploadedImgId;
  String? fetchedImageData;
  bool isLoadingImage = false;
  List<Map<String, String>> _imageQueue = [];
  bool _fetchingImage = false;
  String? _lastRequestedPhotoId;
  Map<String, int> _retryCounts = {};
  
  // Image loading tracking to prevent repeated processing
  String? _currentRequestedImageId;
  bool _isRequestingImage = false;

  final TextEditingController surveillanceSerialController = TextEditingController();

  int get totalSurveillanceItems {
    return widget.assetAuditData?.responseData.categories['CCTV']?.assets.length ?? 0;
  }

  CategoryData? get surveillanceCategoryData {
    return widget.assetAuditData?.responseData.categories['CCTV'];
  }

  @override
  void initState() {
    super.initState();
    serialController.addListener(_onFormChanged);
    remarksController.addListener(_onFormChanged);
    ratingController.addListener(_onFormChanged);
    surveillanceSerialController.addListener(_onFormChanged);
    _loadExistingData();
  }

  @override
  void dispose() {
    serialController.removeListener(_onFormChanged);
    remarksController.removeListener(_onFormChanged);
    ratingController.removeListener(_onFormChanged);
    surveillanceSerialController.removeListener(_onFormChanged);
    serialController.dispose();
    remarksController.dispose();
    ratingController.dispose();
    surveillanceSerialController.dispose();
    super.dispose();
  }

  void _loadExistingData() {
    print('🔄 Surveillance: _loadExistingData called');
    print('🔄 Surveillance: Current savedSurveillanceItems length: ${savedSurveillanceItems.length}');
    
    if (widget.assetAuditData != null) {
      final surveillanceData = widget.assetAuditData!.responseData.categories['CCTV'];
      if (surveillanceData != null && surveillanceData.assets.isNotEmpty) {
        setState(() {
          // Only load API data if savedSurveillanceItems is empty (preserve user-saved items)
          if (savedSurveillanceItems.isEmpty) {
            print('🔄 Surveillance: Loading API data (savedSurveillanceItems is empty)');
            savedSurveillanceItems = surveillanceData.assets
                .where((asset) => asset.photoId != null && asset.qrCodeScanned != null)
                .map((asset) => {
              'serialNumber': asset.mfgSerialNo ?? asset.nexgenSerialNo ?? '',
              'photo': asset.photoId?.toString(),
              'status': asset.assetStatus ?? 'OK',
              'rating': asset.itemTypeRemark ?? '',
              'isQRCodeScanned': asset.qrCodeScanned ?? false,
              'timestamp': DateTime.now(),
              'assetAuditSiteRespId': asset.assetAuditSiteRespId,
            })
                .toList();
            print('🔄 Surveillance: Loaded ${savedSurveillanceItems.length} items from API');
          } else {
            print('🔄 Surveillance: Preserving user-saved items (${savedSurveillanceItems.length} items)');
          }
          
          // Only load remarks from API if user hasn't made changes
          if (surveillanceData.remarks.isNotEmpty && remarksController.text.isEmpty) {
            remarksController.text = surveillanceData.remarks.first.itemTypeRemark ?? '';
          }
          fetchedImageData = null; // Reset to prevent default image display
          surveillancePhoto = null;
        });
      }
    }
  }

  void _onFormChanged() {
    print('🔄 Surveillance: _onFormChanged called');
    print('🔄 Surveillance: surveillanceSerialController.text: "${surveillanceSerialController.text}"');
    print('🔄 Surveillance: ratingController.text: "${ratingController.text}"');
    print('🔄 Surveillance: remarksController.text: "${remarksController.text}"');
    
    final newHasUnsavedChanges = surveillanceSerialController.text.isNotEmpty ||
        ratingController.text.isNotEmpty ||
        remarksController.text.isNotEmpty ||
        surveillancePhoto != null ||
        uploadedPhotoPath != null ||
        uploadedImgId != null;
    
    // Only call setState if hasUnsavedChanges actually changed
    if (hasUnsavedChanges != newHasUnsavedChanges) {
      print('🔄 Surveillance: hasUnsavedChanges changed from $hasUnsavedChanges to $newHasUnsavedChanges');
      setState(() {
        hasUnsavedChanges = newHasUnsavedChanges;

        if (showValidationErrors && _isFormValid()) {
          showValidationErrors = false;
        }
      });
    } else {
      print('🔄 Surveillance: hasUnsavedChanges unchanged ($hasUnsavedChanges), skipping setState');
    }
  }

  bool _isFormValid() {
    return surveillanceSerialController.text.isNotEmpty &&
        surveillancePhoto != null &&
        surveillancePhoto!.isNotEmpty &&
        ratingController.text.isNotEmpty &&
        _validateSerialNumber(surveillanceSerialController.text, isQRCodeScanned);
  }

  bool _validateSerialNumber(String serialNumber, bool isQRCodeScanned) {
    if (widget.assetAuditData == null || lastValidatedSerial == serialNumber) return true;
    final pcuData = widget.assetAuditData!.responseData.categories['CCTV'];
    if (pcuData == null) return false;
    final allItems = pcuData.assets;
    bool isValid = isQRCodeScanned
        ? allItems.any((item) => item.nexgenSerialNo?.toLowerCase() == serialNumber.toLowerCase())
        : allItems.any((item) => item.mfgSerialNo?.toLowerCase() == serialNumber.toLowerCase());
    lastValidatedSerial = serialNumber;
    if (!isValid) {
      showCustomToast(context, isQRCodeScanned
          ? 'Invalid QR Code! Serial number not found.'
          : 'Invalid manual entry! Serial number not found.');
    }
    return isValid;
  }

  void _saveAndExit() async {
    try {
      showDialog(context: context, barrierDismissible: false, builder: (context) => const Center(child: CircularProgressIndicator()));
      await _postSurveillanceData();
      await _updateAuditScheduleStatus("In Progress");
      Navigator.of(context).pop();
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => HomeScreen()));
    } catch (e) {
      if (Navigator.canPop(context)) Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving data: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _updateAuditScheduleStatus(String status) async {
    try {
      await context.read<AuditScheduleStatusCubit>().updateStatus(status: status, siteAuditSchId: widget.siteAuditSchId);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update status: $e')));
    }
  }

  void _saveSurveillanceForm() async {
    if (savedSurveillanceItems.length > totalSurveillanceItems) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Maximum number of Surveillance items ($totalSurveillanceItems) already added.',
            style: const TextStyle(color: Colors.white, fontSize: 14, fontFamily: fontFamilyMontserrat),
          ),
          backgroundColor: AppColors.errorColor,
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    if (_isFormValid()) {
      String? photoImageId = surveillancePhoto;
      if (surveillancePhoto != null && !_isNumeric(surveillancePhoto!) && !surveillancePhoto!.startsWith('data:image/')) {
        try {
          final file = File(surveillancePhoto!);
          if (await file.exists()) {
            photoImageId = await _uploadPcuPhoto(file);
            if (photoImageId == null) return;
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Photo file does not exist.'),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 3),
              ),
            );
            return;
          }
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error uploading photo: $e'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
          return;
        }
      }

      setState(() {
        final currentFormData = {
          'serialNumber': surveillanceSerialNumber,
          'photo': photoImageId,
          'status': surveillanceStatus ?? "OK",
          'rating': ratingController.text.trim(),
          'timestamp': DateTime.now(),
          'isQRCodeScanned': isQRCodeScanned,
        };
        savedSurveillanceItems.add(currentFormData);
        surveillanceSerialNumber = null;
        surveillancePhoto = null;
        surveillanceStatus = null;
        isQRCodeScanned = false;
        surveillanceSerialController.clear();
        ratingController.clear();
        
        print('✅ Surveillance item saved successfully! Total items: ${savedSurveillanceItems.length}');
        print('✅ After save - savedSurveillanceItems length: ${savedSurveillanceItems.length}');
        print('✅ After save - savedSurveillanceItems content: $savedSurveillanceItems');
        uploadedPhotoPath = null;
        uploadedImgId = null;
        fetchedImageData = null;
        surveillanceCardKey++;
        hasUnsavedChanges = false;
        showValidationErrors = false;
      });

      final remainingPcu = totalSurveillanceItems - savedSurveillanceItems.length;
    } else {
      setState(() {
        showValidationErrors = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all required fields (Serial Number, Photo, and Rating)'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  String _formatSerialNumber(String serialNumber) {
    if (serialNumber.length <= 7) return serialNumber;
    return "${serialNumber.substring(0, 5)}...";
  }

  void _editItem(Map<String, dynamic> item) {
    setState(() {
      surveillanceSerialNumber = item["serialNumber"];
      surveillancePhoto = item["photo"];
      surveillanceStatus = item["status"];
      isQRCodeScanned = item["isQRCodeScanned"] ?? false;
      surveillanceSerialController.text = item["serialNumber"] ?? "";
      ratingController.text = item["rating"] ?? "";
      isLoadingImage = false;
      savedSurveillanceItems.remove(item);
      hasUnsavedChanges = true;
      surveillanceCardKey++;
      fetchedImageData = null; // Clear before fetching
    });

    if (item["photo"] != null && _isNumeric(item["photo"])) {
      setState(() {
        _currentRequestedImageId = item["photo"];
        _isRequestingImage = true;
        isLoadingImage = true;
      });
      context.read<AssetAuditGetImageCubit>().getImage(
        imgId: item["photo"],
        schId: widget.siteAuditSchId,
      );
    }

  }

  bool _isNumeric(String str) {
    return int.tryParse(str) != null;
  }

  Future<String?> _uploadPcuPhoto(File file) async {
    try {
      final imgIdToUse = "0";
      final completer = Completer<String?>();
      late StreamSubscription subscription;
      subscription = context.read<AssetAuditPhotoUploadCubit>().stream.listen((state) {
        if (state is AssetAuditPhotoUploadSuccess) {
          subscription.cancel();
          completer.complete(state.response.imgId);
        } else if (state is AssetAuditPhotoUploadFailure) {
          subscription.cancel();
          completer.completeError(state.errorMessage);
        }
      });
      context.read<AssetAuditPhotoUploadCubit>().uploadPhoto(
        file: file,
        imgId: imgIdToUse,
        schId: widget.siteAuditSchId,
      );
      return await completer.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          subscription.cancel();
          throw Exception('Photo upload timeout');
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


  Future<void> _postSurveillanceData() async {
    if (savedSurveillanceItems.isEmpty && remarksController.text.trim().isEmpty) return;
    try {
      final assetAuditState = context.read<AssetAuditCubit>().state;
      if (assetAuditState is AssetAuditLoaded && assetAuditState.assetAuditData.pageHeader.isNotEmpty) {
        List<Map<String, dynamic>> allItemsToPost = [];

        if (savedSurveillanceItems.isNotEmpty) {
          final enhancedItems = AssetAuditPostHelper.enhanceSavedItems(
            savedItems: savedSurveillanceItems,
            screenName: 'solar_cctv',
          );
          allItemsToPost.addAll(enhancedItems);
        }

        if (remarksController.text.isNotEmpty) {
          String? remarksAssetAuditSiteRespId = _getRemarksAssetAuditSiteRespId();
          if (remarksAssetAuditSiteRespId != null) {
            Map<String, dynamic> remarksData = {
              'itemType': 'CCTV',
              'remarks': remarksController.text.trim(),
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
          }
        }

        if (allItemsToPost.isEmpty) {
          return;
        }

        final requests = await AssetAuditPostHelper.convertSavedItemsToPostRequest(
          savedItems: allItemsToPost,
          assetAuditData: assetAuditState.assetAuditData,
          itemType: 'CCTV',
          itemTypeId: 6,
          screenName: 'solar_cctv',
          context: context,
          auditSchId: widget.auditSchId,
        );

        if (requests.isNotEmpty) {
          print('=== Surveillance POST: Posting ${requests.length} requests to API ===');
          
          // Store the current remarks text before posting
          final currentRemarksText = remarksController.text;
          print('Solar Surveillance Screen: Storing current remarks text: "$currentRemarksText"');
          
          await context.read<AssetAuditCubit>().postAssetAuditData(requests: requests);
          print('=== Surveillance POST: API call completed ===');
          
          // Refresh the data immediately after posting
          print('Refreshing Solar Surveillance data after posting...');
          context.read<AssetAuditCubit>().getAssetAuditData(
            siteType: widget.siteType,
            auditSchId: widget.auditSchId,
            siteAuditSchId: widget.siteAuditSchId,
          );
          
          // Restore the remarks text after refresh to ensure it's not overwritten
          if (currentRemarksText.isNotEmpty) {
            print('Solar Surveillance Screen: Restoring remarks text after refresh: "$currentRemarksText"');
            remarksController.text = currentRemarksText;
          }
        } else {
          print('=== Surveillance POST: No requests to post ===');
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error posting Surveillance data: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  String? _getRemarksAssetAuditSiteRespId() {
    final pcuData = widget.assetAuditData?.responseData.categories['CCTV'];
    if (pcuData != null && pcuData.remarks.isNotEmpty) {
      for (var remark in pcuData.remarks) {
        if (remark.assetAuditSiteRespId != null && remark.assetAuditSiteRespId > 0 && remark.itemType == 'Invertor') {
          return remark.assetAuditSiteRespId.toString();
        }
      }
      return pcuData.remarks.first.assetAuditSiteRespId?.toString();
    }
    return surveillanceCategoryData?.assets.isNotEmpty == true
        ? surveillanceCategoryData!.assets.first.assetAuditSiteRespId?.toString()
        : null;
  }

  void _fetchNextImage() {
    if (_fetchingImage || _imageQueue.isEmpty) return;
    _fetchingImage = true;
    final image = _imageQueue.removeAt(0);
    final photoId = image['photoId']!;
    _lastRequestedPhotoId = photoId;
    _retryCounts[photoId] = _retryCounts[photoId] ?? 0;
    context.read<AssetAuditGetImageCubit>().getImage(
      imgId: photoId,
      schId: widget.siteAuditSchId,
    );
  }

  Future<void> _handleImageLoadRetry(String photoId, String key) async {
    const maxRetries = 5;
    const retryDelay = Duration(seconds: 3);
    final currentRetryCount = _retryCounts[photoId] ?? 0;
    if (currentRetryCount < maxRetries) {
      _retryCounts[photoId] = currentRetryCount + 1;
      await Future.delayed(retryDelay);
      _imageQueue.insert(0, {'photoId': photoId, 'key': key});
      _fetchNextImage();
    } else {
      _retryCounts.remove(photoId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to load image after multiple attempts.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _showPhotoViewer(BuildContext context, String? photo, String siteAuditSchId) async {
    if (photo == null || photo.isEmpty) {
      showCustomToast(context, 'No photo available to view.');
      return;
    }
    String? imageData;
    if (photo.startsWith('data:image/')) {
      imageData = photo;
    } else if (await File(photo).exists()) {
      imageData = photo;
    } else if (_isNumeric(photo)) {
      final completer = Completer<String?>();
      late StreamSubscription subscription;
      subscription = context.read<AssetAuditGetImageCubit>().stream.listen((state) {
        if (state is AssetAuditGetImageSuccess && state.imageData.isNotEmpty) {
          final finalImageData = state.imageData.startsWith('data:image/')
              ? state.imageData
              : 'data:image/jpeg;base64,${state.imageData}';
          completer.complete(finalImageData);
          subscription.cancel();
        } else if (state is AssetAuditGetImageFailure) {
          showCustomToast(context, 'Failed to load image: ${state.errorMessage}');
          completer.complete(null);
          subscription.cancel();
        }
      });
      context.read<AssetAuditGetImageCubit>().getImage(
        imgId: photo,
        schId: siteAuditSchId,
      );
      imageData = await completer.future;
    }
    if (imageData != null && imageData.isNotEmpty) {
      showDialog(
        context: context,
        builder: (context) => Dialog(
          backgroundColor: Colors.black,
          child: Stack(
            children: [
              Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.7,
                  maxWidth: MediaQuery.of(context).size.width * 0.9,
                ),
                child: imageData!.startsWith('data:image/')
                    ? Image.memory(
                  base64Decode(imageData.split(',').last),
                  fit: BoxFit.contain,
                )
                    : Image.file(
                  File(imageData),
                  fit: BoxFit.contain,
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.red, size: 30),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      showCustomToast(context, 'Unable to load photo.');
    }
  }

  String? _getNextAvailableScreen() {
    return AssetAuditNavigationHelper.getNextAvailableScreen(widget.assetAuditData, 'CCTV');
  }

  String? _getPreviousAvailableScreen() {
    return AssetAuditNavigationHelper.getPreviousAvailableScreen(widget.assetAuditData, 'CCTV');
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
    return MultiBlocListener(
      listeners: [
        BlocListener<AssetAuditCubit, AssetAuditState>(
          listener: (context, state) {
            if (state is AssetAuditLoaded) {
              print('🔄 Surveillance: BlocListener AssetAuditLoaded received');
              print('🔄 Surveillance: Current savedSurveillanceItems length: ${savedSurveillanceItems.length}');
              
              // Only load data if savedSurveillanceItems is empty (preserve user-saved items)
              if (savedSurveillanceItems.isEmpty) {
                print('🔄 Surveillance: BlocListener loading data (savedSurveillanceItems is empty)');
                _loadExistingData();
              } else {
                print('🔄 Surveillance: BlocListener preserving user-saved items (${savedSurveillanceItems.length} items)');
              }
            } else if (state is AssetAuditPostSuccess) {
              // Only show toast if this screen initiated the post action
              if (mounted && state.responses.any((response) => response.itemTypeId == 8)) {
                showCustomToast(context, 'Surveillance data saved successfully!');
              }
              context.read<AssetAuditCubit>().getAssetAuditData(
                siteType: widget.siteType,
                auditSchId: widget.auditSchId,
                siteAuditSchId: widget.siteAuditSchId,
              );
            } else if (state is AssetAuditPostError) {
              // Only show toast if this screen initiated the post action
              if (mounted) {
                showCustomToast(context, 'Error saving Surveillance data: ${state.message}');
              }
            } else if (state is AssetAuditError) {
              showCustomToast(context, 'Error loading data: ${state.message}');
            }
          },
        ),
        BlocListener<AssetAuditPhotoUploadCubit, AssetAuditPhotoUploadState>(
          listener: (context, state) {
            if (state is AssetAuditPhotoUploadSuccess) {
              setState(() {
                uploadedImgId = state.response.imgId;
                uploadedPhotoPath = null;
              });
            } else if (state is AssetAuditPhotoUploadFailure) {
              showCustomToast(context, state.errorMessage);
            }
          },
        ),
        BlocListener<AssetAuditGetImageCubit, AssetAuditGetImageState>(
          listener: (context, state) {
            // Only handle images for the main form, not for saved items
            // This listener should only be triggered when editing an item from the main form
            if (state is AssetAuditGetImageSuccess && 
                state.imageData.isNotEmpty && 
                _isRequestingImage && 
                _currentRequestedImageId != null) {
              final finalImageData = state.imageData.startsWith('data:image/')
                  ? state.imageData
                  : 'data:image/jpeg;base64,${state.imageData}';
              setState(() {
                fetchedImageData = finalImageData;
                surveillancePhoto = finalImageData;
                isLoadingImage = false;
                surveillanceCardKey++;
                _isRequestingImage = false;
                _currentRequestedImageId = null;
              });
              _fetchingImage = false;
              _fetchNextImage();
            } else if (state is AssetAuditGetImageFailure && _isRequestingImage) {
              setState(() {
                isLoadingImage = false;
                surveillanceCardKey++;
                _isRequestingImage = false;
                _currentRequestedImageId = null;
              });
              _handleImageLoadRetry(_lastRequestedPhotoId ?? '', 'surveillance');
            } else if (state is AssetAuditGetImageLoading && _isRequestingImage) {
              setState(() {
                isLoadingImage = true;
              });
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
                onSaveAndExit: _saveAndExit,
                onDiscard: () => Navigator.of(context).pop(),
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
                    onSaveAndExit: _saveAndExit,
                    onDiscard: () => Navigator.of(context).pop(),
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
                          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 120),
                          child: Container(
                            padding: const EdgeInsets.only(top: 20, left: 16, right: 16, bottom: 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CustomFormField(
                                  label: "CCTV Make",
                                  hintText: "Text",
                                  isRequired: true,
                                  isEditable: false,
                                  initialValue: surveillanceCategoryData?.assets.isNotEmpty == true
                                      ? surveillanceCategoryData!.assets.first.oemName ?? "N/A"
                                      : "N/A",
                                ),
                                getHeight(15),
                                CustomFormField(
                                  label: "Capacity of CCTV",
                                  hintText: "Text",
                                  isRequired: false,
                                  isEditable: false,
                                  initialValue: surveillanceCategoryData?.assets.isNotEmpty == true
                                      ? surveillanceCategoryData!.assets.first.capacity ?? "N/A"
                                      : "N/A",
                                ),
                                getHeight(15),
                                CustomFormField(
                                  label: "Count of CCTV",
                                  initialValue: totalSurveillanceItems.toString(),
                                  isRequired: false,
                                  isEditable: false,
                                ),
                                getHeight(15),
                                Text(
                                  "CCTV Details",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white,
                                    fontFamily: fontFamilyMontserrat,
                                  ),
                                ),
                                getHeight(3),
                                CustomInfoCard(
                                  key: ValueKey('pcu_$surveillanceCardKey'),
                                  serialLabel: surveillanceCategoryData?.assets.isNotEmpty == true
                                      ? "CCTV (${surveillanceCategoryData!.assets.first.oemName ?? 'N/A'}) - Serial Number"
                                      : "CCTV - Serial Number",
                                  serialHintText: "CCTV Serial Number *",
                                  photoLabel: "Add a Photo",
                                  statusLabel: "Status",
                                  serialController: surveillanceSerialController,
                                  onSave: _saveSurveillanceForm,
                                  isStatusEditable: true,
                                  backendStatus: false,
                                  isRemarksEditable: true,
                                  showSaveButton: true,
                                  remarksLabel: "Rating",
                                  remarksController: ratingController,
                                  remarksHintText: surveillanceCategoryData?.assets.isNotEmpty == true
                                      ? surveillanceCategoryData!.assets.first.itemTypeRemark ?? "Rating"
                                      : "Rating",
                                  onRemarksChanged: (rating) {
                                    setState(() {
                                      hasUnsavedChanges = true;
                                    });
                                  },
                                  onPhotoTap: (photoPath) {
                                    setState(() {
                                      surveillancePhoto = photoPath;
                                      fetchedImageData = null; // Clear fetched image when new photo is selected
                                      hasUnsavedChanges = true;
                                    });
                                  },
                                  onStatusChanged: (val) {
                                    setState(() {
                                      surveillanceStatus = val ? "OK" : "Not OK";
                                      hasUnsavedChanges = true;
                                    });
                                  },
                                  onSerialChanged: (serialNumber) {
                                    setState(() {
                                      surveillanceSerialNumber = serialNumber;
                                      isQRCodeScanned = false;
                                      hasUnsavedChanges = true;
                                    });
                                  },
                                  initialStatus: surveillanceStatus == "OK" ? true : (surveillanceStatus == "Not OK" ? false : null),
                                  initialPhotoPath: surveillancePhoto, // Only use surveillancePhoto, not fetchedImageData
                                  isEditable: true,
                                ),
                                getHeight(8),
                                _buildPcuSavedItemsList(),
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
                                      showDialog(
                                        context: context,
                                        barrierDismissible: false,
                                        builder: (context) => const Center(child: CircularProgressIndicator()),
                                      );
                                      await _postSurveillanceData();
                                      Navigator.of(context).pop();
                                      if (nextScreen != null) {
                                        _navigateToNextScreen(context, nextScreen);
                                      } else {
                                        _saveAndExit();
                                      }
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
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPcuSavedItemsList() {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.symmetric(vertical: 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.green7,
            borderRadius: BorderRadius.circular(5),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: const Text(
                        "Serial No.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontFamily: fontFamilyMontserrat,
                          fontWeight: FontWeight.w400,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: const Text(
                        "Status",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontFamily: fontFamilyMontserrat,
                          fontWeight: FontWeight.w400,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: const Text(
                        "Scanned",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontFamily: fontFamilyMontserrat,
                          fontWeight: FontWeight.w400,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: const Text(
                        "Rating",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontFamily: fontFamilyMontserrat,
                          fontWeight: FontWeight.w400,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: const Text(
                        "Photo",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontFamily: fontFamilyMontserrat,
                          fontWeight: FontWeight.w400,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: const Text(
                        "Edit",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontFamily: fontFamilyMontserrat,
                          fontWeight: FontWeight.w400,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (savedSurveillanceItems.isNotEmpty) ...[
                ...savedSurveillanceItems.map((item) {
                  return Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            _formatSerialNumber(item["serialNumber"] ?? ""),
                            style: const TextStyle(
                              color: AppColors.color555555,
                              fontSize: 14,
                              fontFamily: fontFamilyMontserrat,
                              fontWeight: FontWeight.w400,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            item["status"] ?? "",
                            style: const TextStyle(
                              color: AppColors.color555555,
                              fontSize: 14,
                              fontFamily: fontFamilyMontserrat,
                              fontWeight: FontWeight.w400,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Expanded(
                          child: Icon(
                            item['isQRCodeScanned'] == true ? Icons.qr_code_scanner : Icons.close,
                            color: item['isQRCodeScanned'] == true ? Colors.blue : Colors.red,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            item["rating"]?.isNotEmpty == true ? item["rating"] : "N/A",
                            style: const TextStyle(
                              color: AppColors.color555555,
                              fontSize: 14,
                              fontFamily: fontFamilyMontserrat,
                              fontWeight: FontWeight.w400,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Expanded(
                          child: IconButton(
                            icon: Icon(
                              Icons.camera_alt,
                              color: item['photo'] != null && item['photo'].isNotEmpty ? AppColors.color555555 : Colors.grey,
                            ),
                            onPressed: item['photo'] != null && item['photo'].isNotEmpty
                                ? () => _showPhotoViewer(context, item['photo'], widget.siteAuditSchId)
                                : null,
                          ),
                        ),
                        Expanded(
                          child: IconButton(
                            icon: const Icon(
                              Icons.edit_calendar_outlined,
                              color: AppColors.color555555,
                            ),
                            onPressed: () => _editItem(item),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
