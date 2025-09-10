import 'package:app/commonWidgets/custom_buttons/arrow_botton.dart';
import 'package:app/constants/constants_methods.dart';
import 'package:app/screens/asset_audit/asset_audit_solar/fire_extinguisher_screen.dart';
import 'package:app/screens/asset_audit/asset_audit_solar/solar_survelliance_screen.dart';
import 'package:app/screens/asset_audit/asset_audit_solar/boundary_screen.dart';
import 'package:app/utils/asset_audit_navigation_helper.dart';
import 'package:app/utils/asset_audit_post_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:io';
import 'dart:async';
import 'dart:convert';

import '../../../bloc/asset_audit_cubit.dart';
import '../../../bloc/asset_audit_state.dart';
import '../../../bloc/asset_audit_photo_upload_cubit.dart';
import '../../../bloc/asset_audit_get_image_cubit.dart';
import '../../../bloc/audit_schedule_status_cubit.dart';
import '../../../commonWidgets/asset_type_card.dart';
import '../../../commonWidgets/custom_dialogs/success_dialog.dart';
import '../../../commonWidgets/custom_dialogs/unsaved_changes_dialog.dart';
import '../../../commonWidgets/custom_form_appbar.dart';
import '../../../commonWidgets/custom_form_field.dart';
import '../../../commonWidgets/custom_remark.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_images.dart';
import '../../../constants/constants_strings.dart';
import '../../../models/asset_audit_model.dart';
import '../../home_screen.dart';

class SCADAScreen extends StatefulWidget {
  final String siteType;
  final String auditSchId;
  final String siteAuditSchId;
  final AssetAuditModel? assetAuditData; // Complete asset audit data

  const SCADAScreen({
    super.key,
    required this.siteType,
    required this.auditSchId,
    required this.siteAuditSchId,
    this.assetAuditData, // Complete asset audit data
  });

  @override
  State<SCADAScreen> createState() => _SCADAScreenState();
}


class _SCADAScreenState extends State<SCADAScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController serialController = TextEditingController();
  bool hasUnsavedChanges = false;
  bool showValidationErrors = false;
  // SCADA field values
  String? scadaSerialNumber;
  String? scadaPhoto;
  String? scadaStatus;
  bool isQRCodeScanned = false;
  final remarksController = TextEditingController();
  int scadaCardKey = 0;
  List<Map<String, dynamic>> savedScadaItems = [];

  // Controllers for CustomInfoCard
  final TextEditingController scadaSerialController = TextEditingController();

  // Photo upload and image display
  String? uploadedPhotoId;
  String? displayedImageBase64;
  bool isUploadingPhoto = false;
  bool isLoadingImage = false;
  
  // Image loading tracking to prevent repeated processing
  String? _currentRequestedImageId;
  bool _isRequestingImage = false;

  // Stream subscriptions
  StreamSubscription? _assetAuditSubscription;

  // Get SCADA data from API
  int totalScadaItems = 0;
  bool _isSavingItem = false; // Flag to prevent listener from overriding during save

  // Get SCADA category data
  CategoryData? get scadaCategoryData {
    return widget.assetAuditData?.responseData.categories['SCADA'];
  }

  @override
  void initState() {
    super.initState();
    serialController.addListener(_onFormChanged);
    scadaSerialController.addListener(_onFormChanged);
    remarksController.addListener(_onFormChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Sync initial data from widget.assetAuditData
    if (widget.assetAuditData != null) {
      final scadaData = widget.assetAuditData!.responseData.categories['SCADA'];
      if (scadaData != null) {
        setState(() {
          totalScadaItems = scadaData.assets.length;
          savedScadaItems = scadaData.assets.where((asset) =>
            asset.assetAuditSiteRespId != null &&
            (asset.photoId != null || asset.qrCodeScanned == true) // true for QR scanned, false for manual entry
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
          // Only load remarks from API if user hasn't made changes
          if (remarksController.text.isEmpty) {
            remarksController.text = scadaData.remarks.isNotEmpty
                ? scadaData.remarks.first.itemTypeRemark ?? ''
                : '';
          }
        });
      }
    }

    // Setup asset audit listener
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupAssetAuditListener();
    });

    // Only load fresh data if we don't already have it
    if (widget.assetAuditData == null) {
      context.read<AssetAuditCubit>().getAssetAuditData(
        siteType: widget.siteType,
        auditSchId: widget.auditSchId,
        siteAuditSchId: widget.siteAuditSchId,
      );
    }
  }

  void _setupAssetAuditListener() {
    _assetAuditSubscription?.cancel(); // Cancel previous subscription to avoid leaks
    _assetAuditSubscription = context.read<AssetAuditCubit>().stream.listen((state) {
      if (state is AssetAuditLoaded && mounted && !_isSavingItem) {
        print('=== SCADA Asset Audit Listener Triggered ===');
        print('Current savedScadaItems count: ${savedScadaItems.length}');
        print('_isSavingItem flag: $_isSavingItem');

        setState(() {
          final scadaData = state.assetAuditData.responseData.categories['SCADA'];
          if (scadaData != null) {
            final postedItems = scadaData.assets.where((asset) =>
            asset.assetAuditSiteRespId != null &&
                (asset.photoId != null || asset.qrCodeScanned == true) // true for QR scanned, false for manual entry
            ).map((asset) {
              return {
                'serialNumber': asset.mfgSerialNo ?? asset.nexgenSerialNo ?? '',
                'photo': asset.photoId?.toString(),
                'status': asset.assetStatus ?? 'OK',
                'timestamp': DateTime.now(),
                'isQRCodeScanned': asset.qrCodeScanned ?? false,
                'assetAuditSiteRespId': asset.assetAuditSiteRespId,
              };
            }).toList();

            print('Posted items from API: ${postedItems.length}');
            print('Local items before merge: ${savedScadaItems.length}');

            // Only update if we have posted items from API, otherwise preserve local items
            if (postedItems.isNotEmpty) {
              // Merge local items with posted items from API
              final localItems = savedScadaItems.where((item) =>
              item['assetAuditSiteRespId'] == null
              ).toList();
              savedScadaItems = [...localItems, ...postedItems];
              print('After merge - Local items: ${localItems.length}, Posted items: ${postedItems.length}, Total: ${savedScadaItems.length}');
            } else {
              print('No posted items from API, keeping existing local items: ${savedScadaItems.length}');
            }

            totalScadaItems = scadaData.assets.length;
            // Only load remarks from API if user hasn't made changes
            if (remarksController.text.isEmpty) {
              remarksController.text = scadaData.remarks.isNotEmpty
                  ? scadaData.remarks.first.itemTypeRemark ?? ''
                  : '';
            }
          }
        });
      } else if (_isSavingItem) {
        print('=== SCADA Asset Audit Listener Skipped (Saving Item) ===');
      }
    }, onError: (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error in SCADA audit listener: $error'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    });
  }

  @override
  void dispose() {
    serialController.removeListener(_onFormChanged);
    scadaSerialController.removeListener(_onFormChanged);
    remarksController.removeListener(_onFormChanged);
    serialController.dispose();
    scadaSerialController.dispose();
    remarksController.dispose();
    _assetAuditSubscription?.cancel();
    super.dispose();
  }

  void _onFormChanged() {
    setState(() {
      final hasLocalPhoto = scadaPhoto != null && scadaPhoto!.isNotEmpty;
      final hasImageData = displayedImageBase64 != null && displayedImageBase64!.isNotEmpty;

      hasUnsavedChanges = serialController.text.isNotEmpty ||
          scadaSerialController.text.isNotEmpty ||
          hasLocalPhoto ||
          hasImageData ||
          savedScadaItems.isNotEmpty ||
          remarksController.text.isNotEmpty;
    });
  }

  void _saveAndExit() async {
    try {
      showDialog(context: context, barrierDismissible: false, builder: (context) => const Center(child: CircularProgressIndicator()));
      await _postScadaData();
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

  bool _isFormValid() {
    if (scadaSerialController.text.isEmpty) {
      return false;
    }

    // Check if either photo is provided OR item is QR scanned
    bool hasPhoto = scadaPhoto != null && scadaPhoto!.isNotEmpty;
    bool isQRScanned = isQRCodeScanned; // This will be true for QR scanned, false for manual entry
    
    if (!hasPhoto && !isQRScanned) {
      return false;
    }

    if (!_validateSerialNumber(scadaSerialController.text, isQRCodeScanned)) {
      return false;
    }

    return true;
  }

  bool _validateSerialNumber(String serialNumber, bool isQrScanned) {
    if (scadaCategoryData?.assets == null || scadaCategoryData!.assets.isEmpty) {
      return false;
    }

    for (var asset in scadaCategoryData!.assets) {
      if (isQrScanned) {
        if (asset.nexgenSerialNo == serialNumber) {
          return true;
        }
      } else {
        if (asset.mfgSerialNo == serialNumber) {
          return true;
        }
      }
    }
    return false;
  }

  void _saveScadaForm() async {
    if (savedScadaItems.length >= totalScadaItems) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Maximum number of SCADA items ($totalScadaItems) already added.',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontFamily: fontFamilyMontserrat,
            ),
          ),
          backgroundColor: AppColors.errorColor,
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    if (_isFormValid()) {
      // Set flag to prevent asset audit listener from interfering
      _isSavingItem = true;
      print('=== SCADA Save Started - Setting _isSavingItem = true ===');
      
      String? photoImageId = scadaPhoto;

      // Only upload photo if it exists and is a file path
      if (scadaPhoto != null && scadaPhoto!.isNotEmpty && !scadaPhoto!.startsWith('http') && !_isNumeric(scadaPhoto!)) {
        try {
          final file = File(scadaPhoto!);
          if (await file.exists()) {
            print('📤 Uploading SCADA photo: ${scadaPhoto}');
            photoImageId = await _uploadScadaPhoto(file);
            print('✅ SCADA photo uploaded successfully, image ID: $photoImageId');
          } else {
            print('❌ SCADA photo file does not exist: ${scadaPhoto}');
            photoImageId = null; // Set to null if file doesn't exist
          }
        } catch (e) {
          print('❌ Error uploading SCADA photo: $e');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error uploading photo: $e'),
              backgroundColor: Colors.red,
            ),
          );
          _isSavingItem = false; // Reset flag on error
          return;
        }
      } else {
        print('ℹ️ No SCADA photo to upload or already has image ID');
      }

      setState(() {
        Map<String, dynamic> currentFormData = {
          'serialNumber': scadaSerialNumber,
          'photo': photoImageId,
          'status': scadaStatus ?? "OK",
          'timestamp': DateTime.now(),
          'isQRCodeScanned': isQRCodeScanned,
        };

        print('=== SCADA Item Saved ===');
        print('Adding item: $currentFormData');
        print('Before adding - savedScadaItems count: ${savedScadaItems.length}');

        final existingItemIndex = savedScadaItems.indexWhere(
              (item) => item['serialNumber'] == scadaSerialNumber,
        );

        if (existingItemIndex >= 0) {
          savedScadaItems[existingItemIndex] = currentFormData;
        } else {
          savedScadaItems.add(currentFormData);
        }

        print('After adding - savedScadaItems count: ${savedScadaItems.length}');
        print('Saved items: $savedScadaItems');

        scadaSerialNumber = null;
        scadaPhoto = null;
        scadaStatus = null;
        isQRCodeScanned = false;
        displayedImageBase64 = null;

        scadaSerialController.clear();

        scadaCardKey++;

        hasUnsavedChanges = false;
        showValidationErrors = false;
      });

      int remainingScada = totalScadaItems - savedScadaItems.length;

      print('=== SCADA Save Complete ===');
      print('Final savedScadaItems count: ${savedScadaItems.length}');
      print('Final saved items: $savedScadaItems');

      // Reset flag immediately
      _isSavingItem = false;
      print('=== SCADA Save Flag Reset - _isSavingItem = false ===');
    }
  }

  String _formatSerialNumber(String serialNumber) {
    if (serialNumber.length <= 7) {
      return serialNumber;
    }
    return "${serialNumber.substring(0, 5)}...";
  }

  void _editItem(Map<String, dynamic> item) {
    setState(() {
      scadaSerialNumber = item['serialNumber'];
      scadaPhoto = item['photo'];
      scadaStatus = item['status'];
      isQRCodeScanned = item['isQRCodeScanned'] ?? false;
      scadaSerialController.text = item['serialNumber'] ?? '';
      displayedImageBase64 = null;
      isLoadingImage = true;
      savedScadaItems.remove(item);
      hasUnsavedChanges = true;
      scadaCardKey++;
    });

    if (scadaPhoto != null && scadaPhoto!.isNotEmpty && _isNumeric(scadaPhoto!)) {
      print('=== SCADA Edit: Fetching image for photo ID: $scadaPhoto ===');
      setState(() {
        _currentRequestedImageId = scadaPhoto;
        _isRequestingImage = true;
        isLoadingImage = true;
      });
      context.read<AssetAuditGetImageCubit>().getImage(
        imgId: scadaPhoto!,
        schId: widget.siteAuditSchId,
      );
    } else {
      setState(() {
        isLoadingImage = false;
      });
    }

  }

  Future<void> _postScadaData() async {
    try {
      if (savedScadaItems.isEmpty && remarksController.text.trim().isEmpty) {
        return;
      }

      final assetAuditState = context.read<AssetAuditCubit>().state;
      if (assetAuditState is! AssetAuditLoaded || assetAuditState.assetAuditData.pageHeader.isEmpty) {
        return;
      }

      List<Map<String, dynamic>> allItemsToPost = [];

      if (savedScadaItems.isNotEmpty) {
        final enhancedItems = AssetAuditPostHelper.enhanceSavedItems(
          savedItems: savedScadaItems,
          screenName: 'solar_scada',
        );
        allItemsToPost.addAll(enhancedItems);
      }

      if (remarksController.text.trim().isNotEmpty) {
        final remarksAssetAuditSiteRespId = _getRemarksAssetAuditSiteRespId();
        if (remarksAssetAuditSiteRespId != null) {
          Map<String, dynamic> remarksData = {
            'recordType': 'remarks',
            'itemType': 'SCADA',
            'remarks': remarksController.text.trim(),
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
        itemType: 'SCADA',
        itemTypeId: 8,
        screenName: 'solar_scada',
        context: context,
        auditSchId: widget.auditSchId,
      );

      if (requests.isNotEmpty) {
        // Store the current remarks text before posting
        final currentRemarksText = remarksController.text;
        print('SCADA Screen: Storing current remarks text: "$currentRemarksText"');
        
        context.read<AssetAuditCubit>().postAssetAuditData(requests: requests);
        
        // Refresh the data immediately after posting
        print('Refreshing SCADA data after posting...');
        context.read<AssetAuditCubit>().getAssetAuditData(
          siteType: widget.siteType,
          auditSchId: widget.auditSchId,
          siteAuditSchId: widget.siteAuditSchId,
        );
        
        // Restore the remarks text after refresh to ensure it's not overwritten
        if (currentRemarksText.isNotEmpty) {
          print('SCADA Screen: Restoring remarks text after refresh: "$currentRemarksText"');
          remarksController.text = currentRemarksText;
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error posting SCADA data: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  String? _getRemarksAssetAuditSiteRespId() {
    final scadaData = widget.assetAuditData?.responseData.categories['SCADA'];
    if (scadaData != null && scadaData.remarks.isNotEmpty) {
      for (var remark in scadaData.remarks) {
        if (remark.assetAuditSiteRespId != null &&
            remark.assetAuditSiteRespId > 0 &&
            (remark.itemType == 'SCADA' || remark.itemType == null)) {
          return remark.assetAuditSiteRespId.toString();
        }
      }
      if (scadaData.remarks.isNotEmpty) {
        return scadaData.remarks.first.assetAuditSiteRespId?.toString();
      }
    }
    if (scadaCategoryData?.assets.isNotEmpty == true) {
      return scadaCategoryData!.assets.first.assetAuditSiteRespId?.toString();
    }
    return null;
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

  bool _isNumeric(String str) {
    return int.tryParse(str) != null;
  }

  Future<String?> _uploadScadaPhoto(File file) async {
    try {
      print('=== SCADA Photo Upload Started ===');
      print('File path: ${file.path}');
      print('File exists: ${await file.exists()}');
      print('File size: ${await file.length()} bytes');

      final assetAuditState = context.read<AssetAuditCubit>().state;
      if (assetAuditState is AssetAuditLoaded && assetAuditState.assetAuditData.pageHeader.isNotEmpty) {
        final schId = assetAuditState.assetAuditData.pageHeader.first.siteAuditSchId.toString();
        print('Site Audit Sch ID: $schId');

        final imgIdToUse = "0";
        print('Image ID to use: $imgIdToUse');

        final completer = Completer<String?>();
        
        late StreamSubscription subscription;
        subscription = context.read<AssetAuditPhotoUploadCubit>().stream.listen((state) {
          print('=== AssetAuditPhotoUploadCubit State Changed ===');
          print('State type: ${state.runtimeType}');
          
          if (state is AssetAuditPhotoUploadSuccess) {
            print('✅ SCADA Photo upload successful: ${state.response.imgId}');
            subscription.cancel();
            completer.complete(state.response.imgId);
          } else if (state is AssetAuditPhotoUploadFailure) {
            print('❌ SCADA Photo upload failed: ${state.errorMessage}');
            subscription.cancel();
            completer.completeError(Exception(state.errorMessage));
          } else if (state is AssetAuditPhotoUploadLoading) {
            print('⏳ SCADA Photo upload in progress...');
          }
        });

        print('📤 Starting SCADA photo upload...');
        context.read<AssetAuditPhotoUploadCubit>().uploadPhoto(
          file: file,
          imgId: imgIdToUse,
          schId: schId,
        );

        return await completer.future;
      } else {
        throw Exception('Asset audit data not available');
      }
    } catch (e) {
      print('❌ Error uploading SCADA photo: $e');
      rethrow;
    }
  }

  Future<void> _showPhotoViewer(BuildContext context, String? photo, String siteAuditSchId) async {
    if (photo == null || photo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No photo available to view.'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
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
                  icon: const Icon(
                    Icons.close,
                    color: Colors.red,
                    size: 30,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to load photo.'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<AssetAuditGetImageCubit, AssetAuditGetImageState>(
          listener: (context, state) {
            // Only handle images for the main form, not for saved items
            // This listener should only be triggered when editing an item from the main form
            if (state is AssetAuditGetImageSuccess && 
                _isRequestingImage && 
                _currentRequestedImageId != null) {
              print('=== SCADA Screen: Image fetch success for requested image ===');
              String finalImageData = state.imageData.startsWith('data:image/')
                  ? state.imageData
                  : 'data:image/jpeg;base64,${state.imageData}';
              setState(() {
                displayedImageBase64 = finalImageData;
                isLoadingImage = false;
                scadaCardKey++;
                _isRequestingImage = false;
                _currentRequestedImageId = null;
              });
            } else if (state is AssetAuditGetImageFailure && _isRequestingImage) {
              print('=== SCADA Screen: Image fetch failed for requested image ===');
              setState(() {
                displayedImageBase64 = null;
                isLoadingImage = false;
                scadaCardKey++;
                _isRequestingImage = false;
                _currentRequestedImageId = null;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Failed to load image: ${state.errorMessage}'),
                  backgroundColor: Colors.red,
                  duration: const Duration(seconds: 3),
                ),
              );
            } else if (state is AssetAuditGetImageLoading && scadaPhoto != null && _isNumeric(scadaPhoto!)) {
              setState(() {
                isLoadingImage = true;
              });
            }
          },
        ),
        BlocListener<AssetAuditCubit, AssetAuditState>(
          listener: (context, state) {
            if (state is AssetAuditLoaded && !_isSavingItem) {
              print('=== SCADA Screen: AssetAuditLoaded ===');
              final scadaData = state.assetAuditData.responseData.categories['SCADA'];
              if (scadaData != null) {
                setState(() {
                  final postedItems = scadaData.assets.where((asset) =>
                  asset.assetAuditSiteRespId != null &&
                      (asset.photoId != null || asset.qrCodeScanned == true) // true for QR scanned, false for manual entry
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

                  // Only update if we have posted items from API, otherwise preserve local items
                  if (postedItems.isNotEmpty) {
                    // Merge local unsaved items with posted items from API
                    final localItems = savedScadaItems.where((item) =>
                    item['assetAuditSiteRespId'] == null
                    ).toList();
                    savedScadaItems = [...localItems, ...postedItems];
                  }

                  totalScadaItems = scadaData.assets.length;
                  // Only load remarks from API if user hasn't made changes
                  if (remarksController.text.isEmpty) {
                    remarksController.text = scadaData.remarks.isNotEmpty
                        ? scadaData.remarks.first.itemTypeRemark ?? ''
                        : '';
                  }
                });
                print('SCADA items updated from API: ${savedScadaItems.length} items');
              }
            } else if (state is AssetAuditError) {
              print('=== SCADA Screen: AssetAuditError ===');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message ?? 'Error loading data'),
                  backgroundColor: Colors.red,
                  duration: const Duration(seconds: 3),
                ),
              );
            } else if (state is AssetAuditPostSuccess) {
              print('=== SCADA Screen: AssetAuditPostSuccess ===');
              // Only refresh data if we don't have local unsaved items
              if (savedScadaItems.where((item) => item['assetAuditSiteRespId'] == null).isEmpty) {
                context.read<AssetAuditCubit>().getAssetAuditData(
                  siteType: widget.siteType,
                  auditSchId: widget.auditSchId,
                  siteAuditSchId: widget.siteAuditSchId,
                );
              }
            } else if (state is AssetAuditPostError) {
              print('=== SCADA Screen: AssetAuditPostError ===');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message ?? 'Error saving data'),
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
                scadaPhoto = state.response.imgId;
              });
              print('SCADA Screen: Photo uploaded successfully with ID: ${state.response.imgId}');
            } else if (state is AssetAuditPhotoUploadFailure) {
              setState(() {
                isUploadingPhoto = false;
              });
              print('SCADA Screen: Photo upload failed: ${state.errorMessage}');
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
                    message: "Do you want to cancel the Asset Audit for Site (ID: SITE-38974)?",
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
                                CustomFormField(
                                  label: "Data Loger / SCADA Make",
                                  hintText: "Text",
                                  initialValue: scadaCategoryData?.assets.isNotEmpty == true
                                      ? scadaCategoryData!.assets.first.oemName ?? "N/A"
                                      : "N/A",
                                  isRequired: true,
                                  isEditable: false,
                                ),
                                getHeight(15),
                                Text(
                                  "Data Loger / SCADA Make Details",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white,
                                    fontFamily: fontFamilyMontserrat,
                                  ),
                                ),
                                getHeight(3),
                                CustomInfoCard(
                                  key: ValueKey('scada_$scadaCardKey'),
                                  serialLabel: "Data Loger / SCADA Make - Serial Number",
                                  serialHintText: "Data Loger / SCADA Make Serial Number *",
                                  photoLabel: "Add a Photo",
                                  statusLabel: "Status",
                                  serialController: scadaSerialController,
                                  onSave: _saveScadaForm,
                                  isStatusEditable: true,
                                  backendStatus: false,
                                  remarksLabel: scadaCategoryData?.assets.isNotEmpty == true
                                      ? 'SCADA (${scadaCategoryData!.assets.first.capacity ?? 'N/A'})'
                                      : 'SCADA (Capacity)',
                                  remarksHintText: scadaCategoryData?.assets.isNotEmpty == true
                                      ? scadaCategoryData!.assets.first.capacity ?? "N/A"
                                      : "N/A",
                                  remarksController: null,
                                  isRemarksEditable: false,
                                  onPhotoTap: (photoPath) {
                                    setState(() {
                                      scadaPhoto = photoPath;
                                      displayedImageBase64 = null;
                                      hasUnsavedChanges = true;
                                    });
                                  },
                                  onStatusChanged: (val) {
                                    setState(() {
                                      scadaStatus = val ? "OK" : "Not OK";
                                      hasUnsavedChanges = true;
                                    });
                                  },
                                  onSerialChanged: (serialNumber) {
                                    setState(() {
                                      scadaSerialNumber = serialNumber;
                                      isQRCodeScanned = false;
                                      hasUnsavedChanges = true;
                                    });
                                  },
                                  initialStatus: scadaStatus == "OK"
                                      ? true
                                      : (scadaStatus == "Not OK" ? false : null),
                                  initialPhotoPath: displayedImageBase64 ?? scadaPhoto,
                                  isEditable: true,
                                ),
                                getHeight(8),
                                _buildScadaSavedItemsList(),
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
                                  await _postScadaData();
                                  final nextScreen = _getNextAvailableScreen();
                                  if (nextScreen != null) {
                                    _navigateToNextScreen(context, nextScreen);
                                  } else {
                                    _saveAndExit();
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

  Widget _buildScadaSavedItemsList() {
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

              if (savedScadaItems.where((item) {
                // Only show items that have either a photo OR are QR scanned
                bool hasPhoto = item['photo'] != null && item['photo'].toString().isNotEmpty;
                bool isQRScanned = item['isQRCodeScanned'] == true; // true for QR scanned, false for manual entry
                return hasPhoto || isQRScanned;
              }).isNotEmpty) ...[
                ...savedScadaItems.where((item) {
                  // Only show items that have either a photo OR are QR scanned
                  bool hasPhoto = item['photo'] != null && item['photo'].toString().isNotEmpty;
                  bool isQRScanned = item['isQRCodeScanned'] == true;
                  return hasPhoto || isQRScanned;
                }).map((item) {
                  return Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            _formatSerialNumber(item['serialNumber'] ?? ''),
                            style: const TextStyle(
                              color: AppColors.color555555,
                              fontSize: 14,
                              fontFamily: fontFamilyMontserrat,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            item['status'] ?? '',
                            style: const TextStyle(
                              color: AppColors.color555555,
                              fontSize: 14,
                              fontFamily: fontFamilyMontserrat,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Icon(
                            item['isQRCodeScanned'] == true
                                ? Icons.qr_code_scanner
                                : Icons.close,
                            color: item['isQRCodeScanned'] == true
                                ? Colors.blue
                                : Colors.red,
                          ),
                        ),
                        Expanded(
                          child: IconButton(
                            icon: Icon(
                              Icons.camera_alt,
                              color: item['photo'] != null && item['photo'].isNotEmpty
                                  ? AppColors.color555555
                                  : Colors.grey,
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
                            onPressed: () {
                              _editItem(item);
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ] else ...[
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.all(12),
                  child: const Text(
                    'No items added yet.',
                    style: TextStyle(
                      color: AppColors.color555555,
                      fontSize: 14,
                      fontFamily: fontFamilyMontserrat,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}


//
// class _SCADAScreenState extends State<SCADAScreen> {
//   final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
//   final TextEditingController serialController = TextEditingController();
//   bool hasUnsavedChanges = false;
//   bool showValidationErrors = false;
//   // SCADA field values
//   String? scadaSerialNumber;
//   String? scadaPhoto;
//   String? scadaStatus;
//   bool isQRCodeScanned = false;
//   final remarksController = TextEditingController();
//   int scadaCardKey = 0;
//   List<Map<String, dynamic>> savedScadaItems = [];
//   bool _isSavingItem = false; // Flag to prevent listener from overriding during save
//
//   // Controllers for CustomInfoCard
//   final TextEditingController scadaSerialController = TextEditingController();
//
//   // Photo upload and image display
//   String? uploadedPhotoId;
//   String? displayedImageBase64;
//   bool isUploadingPhoto = false;
//   bool isLoadingImage = false;
//
//   // Stream subscriptions
//   StreamSubscription<AssetAuditPhotoUploadState>? _photoUploadSubscription;
//   StreamSubscription<AssetAuditGetImageState>? _getImageSubscription;
//   StreamSubscription? _assetAuditSubscription;
//
//   // Get SCADA data from API
//   int get totalScadaItems {
//     if (widget.assetAuditData?.responseData.categories['SCADA']?.assets != null) {
//       return widget.assetAuditData!.responseData.categories['SCADA']!.assets.length;
//     }
//     return 0;
//   }
//
//   // Get SCADA category data
//   CategoryData? get scadaCategoryData {
//     return widget.assetAuditData?.responseData.categories['SCADA'];
//   }
//
//   @override
//   void initState() {
//     super.initState();
//     serialController.addListener(_onFormChanged);
//     _setupPhotoUploadListener();
//     _setupGetImageListener();
//
//     // Setup asset audit listener after the build is complete
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       _setupAssetAuditListener();
//     });
//   }
//
//   void _setupAssetAuditListener() {
//     _assetAuditSubscription = context.read<AssetAuditCubit>().stream.listen((state) {
//       if (state is AssetAuditLoaded && mounted && !_isSavingItem) {
//         print('=== SCADA Asset Audit Listener Triggered ===');
//         print('Current savedScadaItems count: ${savedScadaItems.length}');
//         print('_isSavingItem flag: $_isSavingItem');
//
//         setState(() {
//           final scadaData = state.assetAuditData.responseData.categories['SCADA'];
//           if (scadaData != null) {
//             final postedItems = scadaData.assets.where((asset) =>
//               asset.assetAuditSiteRespId != null &&
//               asset.photoId != null
//             ).map((asset) {
//               return {
//                 'serialNumber': asset.mfgSerialNo ?? asset.nexgenSerialNo ?? '',
//                 'photo': asset.photoId?.toString(),
//                 'status': asset.assetStatus ?? 'OK',
//                 'timestamp': DateTime.now(),
//                 'isQRCodeScanned': asset.qrCodeScanned ?? false,
//                 'assetAuditSiteRespId': asset.assetAuditSiteRespId,
//               };
//             }).toList();
//
//             print('Posted items from API: ${postedItems.length}');
//             print('Local items before merge: ${savedScadaItems.length}');
//
//             // Only update if we have posted items from API, otherwise preserve local items
//             if (postedItems.isNotEmpty) {
//               // Merge local items with posted items from API
//               final localItems = savedScadaItems.where((item) =>
//                 item['assetAuditSiteRespId'] == null
//               ).toList();
//               savedScadaItems = [...localItems, ...postedItems];
//               print('After merge - Local items: ${localItems.length}, Posted items: ${postedItems.length}, Total: ${savedScadaItems.length}');
//             } else {
//               print('No posted items from API, keeping existing local items: ${savedScadaItems.length}');
//             }
//
//             remarksController.text = scadaData.remarks.isNotEmpty
//                 ? scadaData.remarks.first.itemTypeRemark ?? ''
//                 : '';
//           }
//         });
//       } else if (_isSavingItem) {
//         print('=== SCADA Asset Audit Listener Skipped (Saving Item) ===');
//       }
//     });
//   }
//
//   @override
//   void dispose() {
//     serialController.removeListener(_onFormChanged);
//     serialController.dispose();
//     scadaSerialController.dispose();
//     remarksController.dispose();
//     _photoUploadSubscription?.cancel();
//     _getImageSubscription?.cancel();
//     _assetAuditSubscription?.cancel();
//     super.dispose();
//   }
//
//   void _onFormChanged() {
//     setState(() {
//       hasUnsavedChanges = serialController.text.isNotEmpty;
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
//           scadaPhoto = state.response.imgId; // Store photo ID
//         });
//         print('SCADA Screen: Photo uploaded successfully with ID: ${state.response.imgId}');
//       } else if (state is AssetAuditPhotoUploadFailure) {
//         setState(() {
//           isUploadingPhoto = false;
//         });
//         print('SCADA Screen: Photo upload failed: ${state.errorMessage}');
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
//         });
//         print('SCADA Screen: Image loaded successfully');
//       } else if (state is AssetAuditGetImageFailure) {
//         setState(() {
//           isLoadingImage = false;
//         });
//         print('SCADA Screen: Image load failed: ${state.errorMessage}');
//       }
//     });
//   }
//
//   void _saveAndExit() async {
//     Navigator.of(context).pop();
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
//   bool _isFormValid() {
//     if (scadaSerialController.text.isEmpty) {
//       return false;
//     }
//
//     if (scadaPhoto == null || scadaPhoto!.isEmpty) {
//       return false;
//     }
//
//     return true;
//   }
//
//   // Serial number validation
//   bool _validateSerialNumber(String serialNumber, bool isQrScanned) {
//     if (scadaCategoryData?.assets == null || scadaCategoryData!.assets.isEmpty) {
//       return false;
//     }
//
//     for (var asset in scadaCategoryData!.assets) {
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
//   // bool get _isFormValid {
//   //   if (scadaSerialController.text.isEmpty) {
//   //     return false;
//   //   }
//   //
//   //   if (scadaPhoto == null || scadaPhoto!.isEmpty) {
//   //     return false;
//   //   }
//   //
//   //   return true;
//   // }
//
//   void _saveScadaForm() async {
//     if (savedScadaItems.length >= totalScadaItems) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text(
//             'Maximum number of SCADA items ($totalScadaItems) already added.',
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
//     if (scadaSerialController.text.isNotEmpty && scadaPhoto != null && scadaPhoto!.isNotEmpty) {
//       // Set flag to prevent asset audit listener from interfering
//       _isSavingItem = true;
//       print('=== SCADA Save Started - Setting _isSavingItem = true ===');
//       String? photoImageId = scadaPhoto;
//
//       // If photo is a file path, upload it and get image ID
//       if (scadaPhoto != null && scadaPhoto!.isNotEmpty && !scadaPhoto!.startsWith('http') && !_isNumeric(scadaPhoto!)) {
//         try {
//           final file = File(scadaPhoto!);
//           if (await file.exists()) {
//             print('📤 Uploading SCADA photo: ${scadaPhoto}');
//             photoImageId = await _uploadScadaPhoto(file);
//             print('✅ SCADA photo uploaded successfully, image ID: $photoImageId');
//           } else {
//             print('❌ SCADA photo file does not exist: ${scadaPhoto}');
//           }
//         } catch (e) {
//           print('❌ Error uploading SCADA photo: $e');
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(
//               content: Text('Error uploading photo: $e'),
//               backgroundColor: Colors.red,
//             ),
//           );
//           return;
//         }
//       } else {
//         print('ℹ️ No SCADA photo to upload or already has image ID');
//       }
//
//       setState(() {
//         Map<String, dynamic> currentFormData = {
//           'serialNumber': scadaSerialNumber,
//           'photo': photoImageId, // Use image ID instead of file path
//           'status': scadaStatus ?? "OK",
//           'timestamp': DateTime.now(),
//           'isQRCodeScanned': isQRCodeScanned, // Store whether it was scanned or manual
//         };
//
//         print('=== SCADA Item Saved ===');
//         print('Adding item: $currentFormData');
//         print('Before adding - savedScadaItems count: ${savedScadaItems.length}');
//
//         savedScadaItems.add(currentFormData);
//
//         print('After adding - savedScadaItems count: ${savedScadaItems.length}');
//         print('Saved items: $savedScadaItems');
//
//         scadaSerialNumber = null;
//         scadaPhoto = null;
//         scadaStatus = null;
//         isQRCodeScanned = false;
//         displayedImageBase64 = null;
//
//         scadaSerialController.clear();
//
//         scadaCardKey++;
//
//         hasUnsavedChanges = false;
//       });
//
//       int remainingScada = totalScadaItems - savedScadaItems.length;
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text(
//             'SCADA item saved successfully! ${remainingScada > 0 ? '(${remainingScada} remaining)' : '(All items added)'}',
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
//
//       print('=== SCADA Save Complete ===');
//       print('Final savedScadaItems count: ${savedScadaItems.length}');
//       print('Final saved items: $savedScadaItems');
//
//       // Reset flag after a short delay to allow any pending state changes to complete
//       Future.delayed(const Duration(milliseconds: 500), () {
//         _isSavingItem = false;
//         print('=== SCADA Save Flag Reset - _isSavingItem = false ===');
//       });
//     }
//   }
//
//   String _formatSerialNumber(String serialNumber) {
//     if (serialNumber.length <= 7) {
//       return serialNumber;
//     }
//     return "${serialNumber.substring(0, 5)}...";
//   }
//
//   void _editItem(Map<String, dynamic> item) {
//     setState(() {
//       scadaSerialNumber = item["serialNumber"];
//       scadaPhoto = item["photo"];
//       scadaStatus = item["status"];
//       isQRCodeScanned = item["isQRCodeScanned"] ?? false;
//
//       scadaSerialController.text = item["serialNumber"] ?? "";
//       displayedImageBase64 = null; // Clear Base64 to avoid showing old image
//       isLoadingImage = false; // Reset loading state
//
//       savedScadaItems.remove(item);
//
//       hasUnsavedChanges = true;
//
//       // Force rebuild of the CustomInfoCard to show restored values
//       scadaCardKey++;
//     });
//
//     // Load image asynchronously to avoid blocking UI
//     if (scadaPhoto != null && scadaPhoto!.isNotEmpty && _isNumeric(scadaPhoto!)) {
//       print('=== SCADA Edit: Fetching image for photo ID: $scadaPhoto ===');
//       setState(() {
//         isLoadingImage = true;
//       });
//
//       // Use Future.microtask to load image in next frame
//       Future.microtask(() {
//         context.read<AssetAuditGetImageCubit>().getImage(
//           imgId: scadaPhoto!,
//           schId: widget.siteAuditSchId,
//         );
//       });
//     }
//
//     ScaffoldMessenger.of(context).showSnackBar(
//       const SnackBar(
//         content: Text(
//           'Item loaded for editing. Make changes and save again.',
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
//   // POST SCADA data to API
//   Future<void> _postScadaData() async {
//     try {
//       print('SCADA Screen: Starting to post SCADA data...');
//
//       // Get current location
//       Position position = await Geolocator.getCurrentPosition(
//         desiredAccuracy: LocationAccuracy.high,
//       );
//
//       final assetAuditState = context.read<AssetAuditCubit>().state;
//       if (assetAuditState is! AssetAuditLoaded) {
//         print('SCADA Screen: Asset audit data not loaded');
//         return;
//       }
//
//       final siteData = assetAuditState.assetAuditData?.pageHeader.first;
//       if (siteData == null) {
//         print('SCADA Screen: Site data is null');
//         return;
//       }
//
//       // Prepare all items to post (including remarks)
//       final List<Map<String, dynamic>> allItemsToPost = [];
//
//       // Add saved SCADA items
//       if (savedScadaItems.isNotEmpty) {
//         final enhancedItems = AssetAuditPostHelper.enhanceSavedItems(
//           savedItems: savedScadaItems,
//           screenName: 'solar_scada',
//         );
//         allItemsToPost.addAll(enhancedItems);
//       }
//
//       // Add remarks as a separate item if any
//       if (remarksController.text.isNotEmpty) {
//         print('Adding SCADA remarks to post: ${remarksController.text}');
//         final remarksAssetAuditSiteRespId = _getRemarksAssetAuditSiteRespId();
//         if (remarksAssetAuditSiteRespId != null) {
//           allItemsToPost.add({
//             'assetAuditSiteRespId': remarksAssetAuditSiteRespId,
//             'auditSchId': widget.auditSchId,
//             'siteAuditSchId': widget.siteAuditSchId,
//             'siteId': siteData.siteId.toString(),
//             'itemInstanceId': null,
//             'nexgenSerialNo': null,
//             'itemTypeId': null,
//             'qrCodeScanned': false,
//             'qrCodeScannedTs': null,
//             'photoId': null,
//             'photoTakenTs': null,
//             'assetStatus': null,
//             'longitude': position.longitude,
//             'latitude': position.latitude,
//             'itemTypeRemark': null,
//             'localAuditLogId': null,
//             'localQrCodeScannedTs': null,
//             'localCreatedDt': null,
//             'localModifiedDt': null,
//             'syncProcessId': null,
//             'isActive': true,
//             'remarks': remarksController.text,
//           });
//         }
//       }
//
//       // Convert to AssetAuditPostRequest
//       final requests = await AssetAuditPostHelper.convertSavedItemsToPostRequest(
//         savedItems: allItemsToPost,
//         assetAuditData: assetAuditState.assetAuditData,
//         itemType: 'SCADA',
//         itemTypeId: 8, // SCADA item type ID
//         screenName: 'solar_scada',
//         context: context,
//         auditSchId: widget.auditSchId,
//       );
//
//       print('SCADA Screen: Converted ${requests.length} items to post requests');
//
//       // Post each request
//       for (final request in requests) {
//         print('Posting SCADA request: ${request.nexgenSerialNo ?? 'remarks'}');
//         print('Request details: ${request.toJson()}');
//         // TODO: Implement actual POST API call here
//       }
//
//       print('SCADA Screen: All SCADA data posted successfully');
//     } catch (e) {
//       print('SCADA Screen: Error posting data: $e');
//     }
//   }
//
//   // Helper method to get remarks asset audit site resp ID
//   String? _getRemarksAssetAuditSiteRespId() {
//     if (scadaCategoryData?.assets.isNotEmpty == true) {
//       return scadaCategoryData!.assets.first.assetAuditSiteRespId.toString();
//     }
//     return null;
//   }
//
//   // Helper method to get the next available screen based on data availability
//   String? _getNextAvailableScreen() {
//     return AssetAuditNavigationHelper.getNextAvailableScreen(widget.assetAuditData, 'SCADA');
//   }
//
//   // Helper method to get the previous available screen based on data availability
//   String? _getPreviousAvailableScreen() {
//     return AssetAuditNavigationHelper.getPreviousAvailableScreen(widget.assetAuditData, 'SCADA');
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
//   /// Upload SCADA photo and return image ID
//   Future<String?> _uploadScadaPhoto(File file) async {
//     try {
//       print('=== SCADA Photo Upload Started ===');
//       print('File path: ${file.path}');
//       print('File exists: ${await file.exists()}');
//       print('File size: ${await file.length()} bytes');
//
//       final assetAuditState = context.read<AssetAuditCubit>().state;
//       if (assetAuditState is AssetAuditLoaded && assetAuditState.assetAuditData.pageHeader.isNotEmpty) {
//         final schId = assetAuditState.assetAuditData.pageHeader.first.siteAuditSchId.toString();
//         print('Site Audit Sch ID: $schId');
//
//         final imgIdToUse = "0";
//         print('Image ID to use: $imgIdToUse');
//
//         final completer = Completer<String?>();
//
//         late StreamSubscription subscription;
//         subscription = context.read<AssetAuditPhotoUploadCubit>().stream.listen((state) {
//           print('=== AssetAuditPhotoUploadCubit State Changed ===');
//           print('State type: ${state.runtimeType}');
//
//           if (state is AssetAuditPhotoUploadSuccess) {
//             print('✅ SCADA Photo upload successful: ${state.response.imgId}');
//             subscription.cancel();
//             completer.complete(state.response.imgId);
//           } else if (state is AssetAuditPhotoUploadFailure) {
//             print('❌ SCADA Photo upload failed: ${state.errorMessage}');
//             subscription.cancel();
//             completer.completeError(Exception(state.errorMessage));
//           } else if (state is AssetAuditPhotoUploadLoading) {
//             print('⏳ SCADA Photo upload in progress...');
//           }
//         });
//
//         print('📤 Starting SCADA photo upload...');
//         context.read<AssetAuditPhotoUploadCubit>().uploadPhoto(
//           file: file,
//           imgId: imgIdToUse,
//           schId: schId,
//         );
//
//         return await completer.future;
//       } else {
//         throw Exception('Asset audit data not available');
//       }
//     } catch (e) {
//       print('❌ Error uploading SCADA photo: $e');
//       rethrow;
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return BlocBuilder<AssetAuditCubit, AssetAuditState>(
//       builder: (context, state) {
//         return PopScope(
//           canPop: !hasUnsavedChanges,
//           onPopInvoked: (didPop) async {
//             if (didPop) return;
//
//             if (hasUnsavedChanges) {
//               showDialog(
//                 context: context,
//                 barrierDismissible: false,
//                 builder: (context) =>
//                     UnsavedChangesDialog(
//                       message:
//                       "Do you want to cancel the Asset Audit for Site (ID: SITE-38974) ?",
//                       onSaveAndExit: () {
//                         _saveAndExit();
//                       },
//                       onDiscard: () {
//                         Navigator.of(context).pop();
//                       },
//                     ),
//               );
//             }
//           },
//           child: Scaffold(
//             extendBodyBehindAppBar: true,
//             resizeToAvoidBottomInset: false,
//             appBar: CustomFormAppbar(
//               title: "Asset Audit",
//               onClose: () async {
//                 if (hasUnsavedChanges) {
//                   showDialog(
//                     context: context,
//                     barrierDismissible: false,
//                     builder: (context) =>
//                         UnsavedChangesDialog(
//                           message:
//                           "Do you want to cancel the Asset Audit for Site (ID: SITE-38974) ?",
//                           onSaveAndExit: () {
//                             _saveAndExit();
//                           },
//                           onDiscard: () {
//                             Navigator.of(context).pop();
//                           },
//                         ),
//                   );
//                 } else {
//                   Navigator.pop(context);
//                 }
//               },
//             ),
//             body: Stack(
//               children: [
//                 Positioned.fill(
//                   child: SvgPicture.asset(
//                     AppImages.home,
//                     fit: BoxFit.cover,
//                     width: double.infinity,
//                     height: double.infinity,
//                   ),
//                 ),
//                 SafeArea(
//                   child: Form(
//                     key: _formKey,
//                     child: Column(
//                       children: [
//                         Expanded(
//                           child: SingleChildScrollView(
//                             padding: EdgeInsets.only(
//                               bottom:
//                               MediaQuery
//                                   .of(context)
//                                   .viewInsets
//                                   .bottom + 120,
//                             ),
//                             child: Container(
//                               padding: const EdgeInsets.only(
//                                 top: 20,
//                                 left: 16,
//                                 right: 16,
//                                 bottom: 20,
//                               ),
//                               child: Column(
//                                 crossAxisAlignment: CrossAxisAlignment.start,
//                                 children: [
//                                   CustomFormField(
//                                     label: "Data Loger / SCADA Make",
//                                     hintText: "Text",
//                                     initialValue: scadaCategoryData!.assets.first.oemName ,
//                                     isRequired: true,
//                                     isEditable: false,
//                                   ),
//                                   getHeight(15),
//                                   // CustomFormField(
//                                   //   label: "Count of VCB",
//                                   //   initialValue: "2",
//                                   //   isRequired: false,
//                                   //   isEditable: false,
//                                   // ),
//                                   // getHeight(15),
//                                   Text(
//                                     "Data Loger / SCADA Make Details",
//                                     style: TextStyle(
//                                       fontSize: 16,
//                                       fontWeight: FontWeight.w500,
//                                       color: Colors.white,
//                                       fontFamily: fontFamilyMontserrat,
//                                     ),
//                                   ),
//                                   getHeight(3),
//                                   CustomInfoCard(
//                                     key: ValueKey('scada_$scadaCardKey'),
//                                     serialLabel: "Data Loger / SCADA Make - Serial Number",
//                                     serialHintText: "Data Loger / SCADA Make Serial Number *",
//                                     photoLabel: "Add a Photo",
//                                     statusLabel: "Status",
//                                     serialController: scadaSerialController,
//                                     onSave: _saveScadaForm,
//                                     isStatusEditable: true,
//                                     backendStatus: false,
//                                     remarksLabel: 'Capacity',
//                                     remarksHintText: scadaCategoryData?.assets
//                                         .isNotEmpty == true
//                                         ? scadaCategoryData!.assets.first
//                                         .capacity ?? "5 KW"
//                                         : "5 KW",
//                                     onPhotoTap: (photoPath) {
//                                       setState(() {
//                                         scadaPhoto = photoPath;
//                                         hasUnsavedChanges = true;
//                                       });
//                                     },
//                                     onStatusChanged: (val) {
//                                       setState(() {
//                                         scadaStatus = val ? "OK" : "Not OK";
//                                         hasUnsavedChanges = true;
//                                       });
//                                     },
//                                     onSerialChanged: (serialNumber) {
//                                       setState(() {
//                                         scadaSerialNumber = serialNumber;
//                                         hasUnsavedChanges = true;
//                                       });
//                                     },
//                                     initialStatus: scadaStatus == "OK"
//                                         ? true
//                                         : (scadaStatus == "Not OK"
//                                         ? false
//                                         : null),
//                                     initialPhotoPath: scadaPhoto,
//                                     isEditable: true,
//                                   ),
//                                   getHeight(8),
//                                   _buildScadaSavedItemsList(),
//                                   getHeight(15),
//                                   CustomRemarksField(
//                                     label: "Add Remarks",
//                                     hintText: "Remarks",
//                                     controller: remarksController,
//                                   ),
//                                   if (scadaSerialController.text.isNotEmpty && scadaPhoto != null && scadaPhoto!.isNotEmpty)
//                                     Container(
//                                       width: double.infinity,
//                                       child: ElevatedButton(
//                                         onPressed: () {
//                                           showDialog(
//                                             context: context,
//                                             barrierDismissible: false,
//                                             builder: (context) =>
//                                                 SuccessDialog(
//                                                   ticketId: "UVORKJR00044",
//                                                   message:
//                                                   "Asset Audit for Site (ID: SITE-38974) has been recorded and saved.",
//                                                   onDone: () {
//                                                     Navigator.of(context).pop();
//                                                     Navigator.of(context).pop();
//                                                   },
//                                                 ),
//                                           );
//                                         },
//                                         style: ElevatedButton.styleFrom(
//                                           backgroundColor: AppColors
//                                               .primaryGreen,
//                                           padding: const EdgeInsets.symmetric(
//                                             vertical: 12,
//                                           ),
//                                           shape: RoundedRectangleBorder(
//                                             borderRadius: BorderRadius.circular(
//                                                 8),
//                                           ),
//                                         ),
//                                         child: const Text(
//                                           "Save",
//                                           style: TextStyle(
//                                             color: Colors.white,
//                                             fontSize: 16,
//                                             fontWeight: FontWeight.w600,
//                                             fontFamily: fontFamilyMontserrat,
//                                           ),
//                                         ),
//                                       ),
//                                     ),
//                                 ],
//                               ),
//                             ),
//                           ),
//                         ),
//
//                         Container(
//                           padding: const EdgeInsets.all(16),
//                           width: double.infinity,
//                           child: Row(
//                             children: [
//                               Expanded(
//                                 child: ArrowButton(
//                                   text: _getPreviousAvailableScreen() ?? "Back",
//                                   isLeftArrow: true,
//                                   backgroundColor: AppColors.buttonColorBackBg,
//                                   textColor: AppColors.buttonColorTextBg,
//                                   onPressed: () {
//                                     final previousScreen = _getPreviousAvailableScreen();
//                                     if (previousScreen != null) {
//                                       _navigateToNextScreen(
//                                           context, previousScreen);
//                                     } else {
//                                       Navigator.pop(context);
//                                     }
//                                   },
//                                 ),
//                               ),
//                               getWidth(14),
//                               Expanded(
//                                 child: ArrowButton(
//                                   text: _getNextAvailableScreen() ?? "Submit",
//                                   isLeftArrow: false,
//                                   backgroundColor: AppColors.buttonColorBg,
//                                   textColor: AppColors.buttonColorSite,
//                                   onPressed: () async {
//                                     // Post data before navigating
//                                     await _postScadaData();
//
//                                     final nextScreen = _getNextAvailableScreen();
//                                     if (nextScreen != null) {
//                                       _navigateToNextScreen(
//                                           context, nextScreen);
//                                     } else {
//                                       // All screens completed, show success dialog
//                                       _saveAndExit();
//                                     }
//                                   },
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         );
//       });
//   }
//
//   Widget _buildScadaSavedItemsList()
//     {
//       return Column(
//         children: [
//           Container(
//             margin: const EdgeInsets.symmetric(vertical: 10),
//             padding: const EdgeInsets.all(16),
//             decoration: BoxDecoration(
//               color: AppColors.green7,
//               borderRadius: BorderRadius.circular(5),
//             ),
//             child: Column(
//               children: [
//                 Row(
//                   children: [
//                     Expanded(
//                       child: Container(
//                         padding: const EdgeInsets.symmetric(horizontal: 4),
//                         child: const Text(
//                           "Serial No.",
//                           textAlign: TextAlign.center,
//                           style: TextStyle(
//                             color: Colors.white,
//                             fontSize: 14,
//                             fontFamily: fontFamilyMontserrat,
//                             fontWeight: FontWeight.w400,
//                           ),
//                           maxLines: 1,
//                           overflow: TextOverflow.ellipsis,
//                         ),
//                       ),
//                     ),
//                     Expanded(
//                       child: Container(
//                         padding: const EdgeInsets.symmetric(horizontal: 4),
//                         child: const Text(
//                           "Status",
//                           textAlign: TextAlign.center,
//                           style: TextStyle(
//                             color: Colors.white,
//                             fontSize: 14,
//                             fontFamily: fontFamilyMontserrat,
//                             fontWeight: FontWeight.w400,
//                           ),
//                           maxLines: 1,
//                           overflow: TextOverflow.ellipsis,
//                         ),
//                       ),
//                     ),
//                      Expanded(
//                        child: Container(
//                          padding: const EdgeInsets.symmetric(horizontal: 4),
//                          child: const Text(
//                            "Entry Type",
//                            textAlign: TextAlign.center,
//                            style: TextStyle(
//                              color: Colors.white,
//                              fontSize: 14,
//                              fontFamily: fontFamilyMontserrat,
//                              fontWeight: FontWeight.w400,
//                            ),
//                            maxLines: 1,
//                            overflow: TextOverflow.ellipsis,
//                          ),
//                        ),
//                      ),
//                     Expanded(
//                       child: Container(
//                         padding: const EdgeInsets.symmetric(horizontal: 4),
//                         child: const Text(
//                           "Photo",
//                           textAlign: TextAlign.center,
//                           style: TextStyle(
//                             color: Colors.white,
//                             fontSize: 14,
//                             fontFamily: fontFamilyMontserrat,
//                             fontWeight: FontWeight.w400,
//                           ),
//                           maxLines: 1,
//                           overflow: TextOverflow.ellipsis,
//                         ),
//                       ),
//                     ),
//                     Expanded(
//                       child: Container(
//                         padding: const EdgeInsets.symmetric(horizontal: 4),
//                         child: const Text(
//                           "Edit",
//                           textAlign: TextAlign.center,
//                           style: TextStyle(
//                             color: Colors.white,
//                             fontSize: 14,
//                             fontFamily: fontFamilyMontserrat,
//                             fontWeight: FontWeight.w400,
//                           ),
//                           maxLines: 1,
//                           overflow: TextOverflow.ellipsis,
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//                 const SizedBox(height: 8),
//
//                 if (savedScadaItems.isNotEmpty) ...[
//                   ...savedScadaItems.map((item) {
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
//                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                         children: [
//                           Expanded(
//                             child: Text(
//                               _formatSerialNumber(item["serialNumber"] ?? ""),
//                               style: const TextStyle(
//                                 color: AppColors.color555555,
//                                 fontSize: 14,
//                                 fontFamily: fontFamilyMontserrat,
//                                 fontWeight: FontWeight.w400,
//                               ),
//                             ),
//                           ),
//                           Expanded(
//                             child: Text(
//                               item["status"] ?? "",
//                               style: const TextStyle(
//                                 color: AppColors.color555555,
//                                 fontSize: 14,
//                                 fontFamily: fontFamilyMontserrat,
//                                 fontWeight: FontWeight.w400,
//                               ),
//                             ),
//                           ),
//                            Expanded(
//                              child: Icon(
//                                item["isQRCodeScanned"] == true
//                                    ? Icons.qr_code_scanner
//                                    : Icons.close,
//                                color: item["isQRCodeScanned"] == true
//                                    ? Colors.blue
//                                    : Colors.red,
//                              ),
//                            ),
//                           Expanded(
//                             child: IconButton(
//                               icon: const Icon(
//                                 Icons.camera_alt,
//                                 color: AppColors.color555555,
//                               ),
//                               onPressed: () {
//                                 // handle photo click
//                               },
//                             ),
//                           ),
//                           Expanded(
//                             child: IconButton(
//                               icon: const Icon(
//                                 Icons.edit_calendar_outlined,
//                                 color: AppColors.color555555,
//                               ),
//                               onPressed: () {
//                                 _editItem(item);
//                               },
//                             ),
//                           ),
//                         ],
//                       ),
//                     );
//                   }).toList(),
//                 ],
//               ],
//             ),
//           ),
//         ],
//       );
//     }
// }
