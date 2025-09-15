import 'package:app/commonWidgets/custom_buttons/arrow_botton.dart';
import 'package:app/constants/constants_methods.dart';
import 'package:app/utils/asset_audit_navigation_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:io';
import 'dart:async';

import '../../../bloc/asset_audit_cubit.dart';
import '../../../bloc/asset_audit_state.dart';
import '../../../bloc/asset_audit_photo_upload_cubit.dart';
import '../../../bloc/asset_audit_get_image_cubit.dart';
import '../../../bloc/audit_schedule_status_cubit.dart';
import '../../../data/asset_audit_service.dart' show AssetAuditService;
import '../../../data/database.dart' show AppDatabase;
import '../../../models/asset_audit_post_model.dart';
import 'dart:convert';
import '../../../commonWidgets/asset_type_card.dart';
import '../../../commonWidgets/custom_dialogs/unsaved_changes_dialog.dart';
import '../../../commonWidgets/custom_form_appbar.dart';
import '../../../commonWidgets/custom_form_field.dart';
import '../../../commonWidgets/custom_remark.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_images.dart';
import '../../../constants/constants_strings.dart';
import '../../../models/asset_audit_model.dart';
import '../../home_screen.dart';

class PCUScreen extends StatefulWidget {
  final String siteType;
  final String auditSchId;
  final String siteAuditSchId;
  final AssetAuditModel? assetAuditData; // Complete asset audit data

  const PCUScreen({
    super.key,
    required this.siteType,
    required this.auditSchId,
    required this.siteAuditSchId,
    this.assetAuditData, // Complete asset audit data
  });

  @override
  State<PCUScreen> createState() => _PCUScreenState();
}

class _PCUScreenState extends State<PCUScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController serialController = TextEditingController();
  bool hasUnsavedChanges = false;
  bool showValidationErrors = false;
  String? pcuSerialNumber;
  String? pcuPhoto;
  String? pcuStatus;
  final remarksController = TextEditingController();
  final ratingController = TextEditingController();
  int pcuCardKey = 0;
  List<Map<String, dynamic>> savedPcuItems = [];
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

  final TextEditingController pcuSerialController = TextEditingController();

  int get totalPcuItems {
    return widget.assetAuditData?.responseData.categories['Invertor']?.assets.length ?? 0;
  }

  CategoryData? get pcuCategoryData {
    return widget.assetAuditData?.responseData.categories['Invertor'];
  }

  @override
  void initState() {
    super.initState();
    serialController.addListener(_onFormChanged);
    remarksController.addListener(_onFormChanged);
    ratingController.addListener(_onFormChanged);
    pcuSerialController.addListener(_onFormChanged);
    _loadExistingData();
  }

  @override
  void dispose() {
    serialController.removeListener(_onFormChanged);
    remarksController.removeListener(_onFormChanged);
    ratingController.removeListener(_onFormChanged);
    pcuSerialController.removeListener(_onFormChanged);
    serialController.dispose();
    remarksController.dispose();
    ratingController.dispose();
    pcuSerialController.dispose();
    super.dispose();
  }

  void _loadExistingData() {
    if (widget.assetAuditData != null) {
      final pcuData = widget.assetAuditData!.responseData.categories['Invertor'];
      if (pcuData != null && pcuData.assets.isNotEmpty) {
        setState(() {
          savedPcuItems = pcuData.assets
              .where((asset) => asset.photoId != null && asset.photoId.toString().isNotEmpty)
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
          // Only load remarks from API if user hasn't made changes
          if (pcuData.remarks.isNotEmpty && remarksController.text.isEmpty) {
            remarksController.text = pcuData.remarks.first.itemTypeRemark ?? '';
          }
          fetchedImageData = null; // Reset to prevent default image display
          pcuPhoto = null;
        });
      }
    }
  }

  void _onFormChanged() {
    setState(() {
      hasUnsavedChanges = pcuSerialController.text.isNotEmpty ||
          ratingController.text.isNotEmpty ||
          remarksController.text.isNotEmpty ||
          pcuPhoto != null ||
          uploadedPhotoPath != null ||
          uploadedImgId != null;

      if (showValidationErrors && _isFormValid()) {
        showValidationErrors = false;
      }
    });
  }

  bool _isFormValid() {
    return pcuSerialController.text.isNotEmpty &&
        pcuPhoto != null &&
        pcuPhoto!.isNotEmpty &&
        ratingController.text.isNotEmpty &&
        _validateSerialNumber(pcuSerialController.text, isQRCodeScanned);
  }

  bool _validateSerialNumber(String serialNumber, bool isQRCodeScanned) {
    if (widget.assetAuditData == null || lastValidatedSerial == serialNumber) return true;
    final pcuData = widget.assetAuditData!.responseData.categories['Invertor'];
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
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // Post PCU data to API first
      await _postPcuData();
      
      // Update audit schedule status
      await _updateAuditScheduleStatus("In Progress");

      // Close loading dialog
      Navigator.of(context).pop();

      // Navigate to home screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
            builder: (context) => HomeScreen()
          //     TicketScreen(
          //   auditName: "PM",
          //   status: "In Progress",
          // ),
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

  void _savePcuForm() async {
    if (savedPcuItems.length >= totalPcuItems) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Maximum number of PCU items ($totalPcuItems) already added.',
            style: const TextStyle(color: Colors.white, fontSize: 14, fontFamily: fontFamilyMontserrat),
          ),
          backgroundColor: AppColors.errorColor,
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    if (_isFormValid()) {
      String? photoImageId = pcuPhoto;
      if (pcuPhoto != null && !_isNumeric(pcuPhoto!) && !pcuPhoto!.startsWith('data:image/')) {
        try {
          final file = File(pcuPhoto!);
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
          'serialNumber': pcuSerialNumber,
          'photo': photoImageId,
          'status': pcuStatus ?? "OK",
          'rating': ratingController.text.trim(),
          'timestamp': DateTime.now(),
          'isQRCodeScanned': isQRCodeScanned,
        };
        savedPcuItems.add(currentFormData);
        pcuSerialNumber = null;
        pcuPhoto = null;
        pcuStatus = null;
        isQRCodeScanned = false;
        pcuSerialController.clear();
        ratingController.clear();
        uploadedPhotoPath = null;
        uploadedImgId = null;
        fetchedImageData = null;
        pcuCardKey++;
        hasUnsavedChanges = false;
        showValidationErrors = false;
      });

      final remainingPcu = totalPcuItems - savedPcuItems.length;
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
      pcuSerialNumber = item["serialNumber"];
      pcuPhoto = item["photo"];
      pcuStatus = item["status"];
      isQRCodeScanned = item["isQRCodeScanned"] ?? false;
      pcuSerialController.text = item["serialNumber"] ?? "";
      ratingController.text = item["rating"] ?? "";
      isLoadingImage = false;
      savedPcuItems.remove(item);
      hasUnsavedChanges = true;
      pcuCardKey++;
    });

    if (item["photo"] != null && _isNumeric(item["photo"])) {
      setState(() {
        _currentRequestedImageId = item["photo"];
        _isRequestingImage = true;
        isLoadingImage = true;
        fetchedImageData = null; // Clear before fetching
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


  String _formatDateForApi(DateTime dateTime) {
    return "${dateTime.day.toString().padLeft(2, '0')}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}";
  }

  Future<void> _postPcuData() async {
    if (savedPcuItems.isEmpty && remarksController.text.trim().isEmpty) return;

    try {
      final db = context.read<AppDatabase>();
      final assetAuditService = AssetAuditService(db);

      final state = context.read<AssetAuditCubit>().state;
      if (state is! AssetAuditLoaded || state.assetAuditData.pageHeader.isEmpty) {
        showCustomToast(context, 'Please wait for site data to load before saving');
        return;
      }

      final pageHeader = state.assetAuditData.pageHeader.first;

      final int auditSchId =
          int.tryParse((widget.auditSchId).toString()) ?? 0;
      final int siteAuditSchId =
          int.tryParse((widget.siteAuditSchId).toString()) ?? (pageHeader.siteAuditSchId ?? 0);
      final int siteId = pageHeader.siteId ?? 0;

      final nowIso = DateTime.now().toIso8601String();
      int saved = 0;

      // ---- Save each PCU row locally (NO UPLOADS) ----
      for (final item in savedPcuItems) {
        final serial = (item['serialNumber'] as String?)?.trim() ?? '';
        if (serial.isEmpty) continue;

        // Keep whatever is in 'photo': file path, data URL, or numeric id as string.
        final String localPhotoId = (item['photo'] as String?)?.trim() ?? '';

        final req = AssetAuditPostRequest(
          assetAuditSiteRespId: item['assetAuditSiteRespId'], // keep if present; else null
          localAuditLogId: 0,
          auditSchId: auditSchId,
          siteAuditSchId: siteAuditSchId,
          siteId: siteId,

          itemInstanceId: 0,
          nexgenSerialNo: serial,
          itemTypeId: 6, // PCU (kept as in your original code)

          qrCodeScanned: (item['isQRCodeScanned'] as bool?) ?? false,
          qrCodeScannedTs: null, // local-only
          photoId: null,         // keep null; pass localPhotoId to upsert
          photoTakenTs: (item['timestamp'] is DateTime)
              ? (item['timestamp'] as DateTime).toIso8601String()
              : nowIso,

          assetStatus: (item['status'] as String?) ?? 'OK',
          longitude: null,
          latitude: null,
          // Store rating (if any) as both remark fields commonly used in your codebase
          itemTypeRemark: (item['rating'] as String?)?.trim(),
          remarks: (item['rating'] as String?)?.trim(),

          localQrCodeScannedTs: nowIso,
          localCreatedDt: nowIso,
          localModifiedDt: nowIso,

          syncProcessId: 0,
          isActive: true,
        );

        await assetAuditService.upsertFromRequest(req, 'solar_pcu', localPhotoId);
        saved++;
      }

      // ---- Save remarks as its own local row (if any) ----
      final remarksText = remarksController.text.trim();
      if (remarksText.isNotEmpty) {
        final reqRemarks = AssetAuditPostRequest(
          assetAuditSiteRespId: _getRemarksAssetAuditSiteRespId(),
          localAuditLogId: 0,
          auditSchId: auditSchId,
          siteAuditSchId: siteAuditSchId,
          siteId: siteId,

          itemInstanceId: 0,
          nexgenSerialNo: 'REMARKS',
          itemTypeId: 6, // PCU

          qrCodeScanned: false,
          qrCodeScannedTs: null,
          photoId: null,
          photoTakenTs: nowIso,

          assetStatus: 'OK',
          longitude: null,
          latitude: null,
          itemTypeRemark: remarksText,
          remarks: remarksText,

          localQrCodeScannedTs: nowIso,
          localCreatedDt: nowIso,
          localModifiedDt: nowIso,

          syncProcessId: 0,
          isActive: true,
        );

        await assetAuditService.upsertFromRequest(reqRemarks, 'solar_pcu', "");
        saved++;
      }

      if (mounted) {
        showCustomToast(context, saved > 0 ? 'PCU saved locally ($saved)' : 'Nothing to save');
      }
    } catch (e, st) {
      debugPrint('PCU local save failed: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Local save failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }


  Future<void> _postPcuData_api() async {
    if (savedPcuItems.isEmpty && remarksController.text.trim().isEmpty) return;
    try {
      final now = DateTime.now();
      List<Map<String, dynamic>> allItemsToPost = [];

      for (var item in savedPcuItems) {
        String? photoId = item['photo'];
        int? numericPhotoId;
        if (photoId != null) {
          if (_isNumeric(photoId)) {
            numericPhotoId = int.tryParse(photoId);
          } else if (!photoId.startsWith('data:image/')) {
            final file = File(photoId);
            if (await file.exists()) {
              photoId = await _uploadPcuPhoto(file);
              numericPhotoId = photoId != null ? int.tryParse(photoId) : null;
              if (numericPhotoId == null) continue;
            } else {
              continue;
            }
          } else {
            continue; // Skip base64 images, as they need to be uploaded
          }
        }
        allItemsToPost.add({
          'assetAuditSiteRespId': (item['assetAuditSiteRespId'] is int) ? item['assetAuditSiteRespId'] : int.tryParse(item['assetAuditSiteRespId']?.toString() ?? '0') ?? 0,
          'auditSchId': int.parse(widget.auditSchId),
          'siteAuditSchId': int.parse(widget.siteAuditSchId),
          'itemInstanceId': 0, // Default value
          'nexgenSerialNo': item['serialNumber'],
          'itemTypeId': 6,
          'qrCodeScanned': item['isQRCodeScanned'] ?? false,
          'qrCodeScannedTs': item['isQRCodeScanned'] == true ? _formatDateForApi(now) : null,
          'photoId': numericPhotoId,
          'photoTakenTs': _formatDateForApi(now),
          'assetStatus': item['status'] ?? 'OK',
          'itemTypeRemark': item['rating'] ?? '',
          'localAuditLogId': 0,
          'localQrCodeScannedTs': item['isQRCodeScanned'] == true ? _formatDateForApi(now) : null,
          'localCreatedDt': _formatDateForApi(now),
          'localModifiedDt': _formatDateForApi(now),
          'syncProcessId': 0,
          'isActive': true,
          'remarks': item['rating'] ?? '',
        });
      }

      if (remarksController.text.trim().isNotEmpty) {
        allItemsToPost.add({
          'assetAuditSiteRespId': _getRemarksAssetAuditSiteRespId() ?? 0,
          'auditSchId': int.parse(widget.auditSchId),
          'siteAuditSchId': int.parse(widget.siteAuditSchId),
          'itemInstanceId': 0,
          'nexgenSerialNo': 'REMARKS',
          'itemTypeId': 6,
          'qrCodeScanned': false,
          'qrCodeScannedTs': null,
          'photoId': null,
          'photoTakenTs': _formatDateForApi(now),
          'assetStatus': 'OK',
          'itemTypeRemark': remarksController.text.trim(),
          'localAuditLogId': 0,
          'localQrCodeScannedTs': null,
          'localCreatedDt': _formatDateForApi(now),
          'localModifiedDt': _formatDateForApi(now),
          'syncProcessId': 0,
          'isActive': true,
          'remarks': remarksController.text.trim(),
        });
      }

      if (allItemsToPost.isNotEmpty) {
        print('=== PCU Creating Requests Debug ===');
        print('allItemsToPost.length: ${allItemsToPost.length}');
        print('First item keys: ${allItemsToPost.first.keys}');
        print('First item auditSchId: ${allItemsToPost.first['auditSchId']} (${allItemsToPost.first['auditSchId'].runtimeType})');
        print('First item siteAuditSchId: ${allItemsToPost.first['siteAuditSchId']} (${allItemsToPost.first['siteAuditSchId'].runtimeType})');
        print('=== End PCU Creating Requests Debug ===');
        
        final requests = allItemsToPost.map((item) => AssetAuditPostRequest(
          assetAuditSiteRespId: (item['assetAuditSiteRespId'] is int) ? item['assetAuditSiteRespId'] as int? : int.tryParse(item['assetAuditSiteRespId']?.toString() ?? '0'),
          auditSchId: (item['auditSchId'] is int) ? item['auditSchId'] as int : int.parse(item['auditSchId'].toString()),
          siteAuditSchId: (item['siteAuditSchId'] is int) ? item['siteAuditSchId'] as int : int.parse(item['siteAuditSchId'].toString()),
          siteId: 0, // Default value
          itemInstanceId: (item['itemInstanceId'] is int) ? item['itemInstanceId'] as int? ?? 0 : int.tryParse(item['itemInstanceId']?.toString() ?? '0') ?? 0,
          nexgenSerialNo: item['nexgenSerialNo'] as String,
          itemTypeId: (item['itemTypeId'] is int) ? item['itemTypeId'] as int : int.parse(item['itemTypeId'].toString()),
          qrCodeScanned: item['qrCodeScanned'] as bool,
          qrCodeScannedTs: item['qrCodeScannedTs'] as String?,
          photoId: (item['photoId'] is int) ? item['photoId'] as int? : int.tryParse(item['photoId']?.toString() ?? ''),
          photoTakenTs: item['photoTakenTs'] as String,
          assetStatus: item['assetStatus'] as String,
          longitude: item['longitude'] as String?,
          latitude: item['latitude'] as String?,
          itemTypeRemark: item['itemTypeRemark'] as String?,
          localAuditLogId: (item['localAuditLogId'] is int) ? item['localAuditLogId'] as int : int.parse(item['localAuditLogId'].toString()),
          localQrCodeScannedTs: (item['localQrCodeScannedTs'] as String?) ?? _formatDateForApi(DateTime.now()),
          localCreatedDt: item['localCreatedDt'] as String,
          localModifiedDt: item['localModifiedDt'] as String,
          syncProcessId: (item['syncProcessId'] is int) ? item['syncProcessId'] as int : int.parse(item['syncProcessId'].toString()),
          isActive: item['isActive'] as bool,
          remarks: item['remarks'] as String?,
        )).toList();
        
        // Store the current remarks text before posting
        final currentRemarksText = remarksController.text;
        print('PCU Screen: Storing current remarks text: "$currentRemarksText"');
        
        context.read<AssetAuditCubit>().postAssetAuditData(requests: requests);
        
        // Refresh the data immediately after posting
        print('Refreshing PCU data after posting...');
        context.read<AssetAuditCubit>().getAssetAuditData(
          siteType: widget.siteType,
          auditSchId: widget.auditSchId,
          siteAuditSchId: widget.siteAuditSchId,
        );
        
        // Restore the remarks text after refresh to ensure it's not overwritten
        if (currentRemarksText.isNotEmpty) {
          print('PCU Screen: Restoring remarks text after refresh: "$currentRemarksText"');
          remarksController.text = currentRemarksText;
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error posting PCU data: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }


  int? _getRemarksAssetAuditSiteRespId() {
    final pcuData = widget.assetAuditData?.responseData.categories['Invertor'];
    if (pcuData != null && pcuData.remarks.isNotEmpty) {
      for (var remark in pcuData.remarks) {
        if (remark.assetAuditSiteRespId != null && remark.assetAuditSiteRespId > 0 && remark.itemType == 'Invertor') {
          return remark.assetAuditSiteRespId;
        }
      }
      return pcuData.remarks.first.assetAuditSiteRespId;
    }
    return pcuCategoryData?.assets.isNotEmpty == true
        ? pcuCategoryData!.assets.first.assetAuditSiteRespId
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
    return AssetAuditNavigationHelper.getNextAvailableScreen(widget.assetAuditData, 'Invertor');
  }

  String? _getPreviousAvailableScreen() {
    return AssetAuditNavigationHelper.getPreviousAvailableScreen(widget.assetAuditData, 'Invertor');
  }

  void _navigateToNextScreen(BuildContext context, String screenName) {
    print('=== PCU Navigation Debug ===');
    print('Navigating to: $screenName');
    print('auditSchId: ${widget.auditSchId} (${widget.auditSchId.runtimeType})');
    print('siteAuditSchId: ${widget.siteAuditSchId} (${widget.siteAuditSchId.runtimeType})');
    print('siteType: ${widget.siteType}');
    print('assetAuditData: ${widget.assetAuditData != null}');
    print('=== End PCU Navigation Debug ===');
    
    try {
      AssetAuditNavigationHelper.navigateToNextScreen(
        context,
        screenName,
        widget.siteType,
        widget.auditSchId,
        widget.siteAuditSchId,
        widget.assetAuditData,
      );
    } catch (e, stackTrace) {
      print('=== PCU Navigation Error ===');
      print('Error: $e');
      print('Stack trace: $stackTrace');
      print('=== End PCU Navigation Error ===');
      rethrow;
    }
  }

  String _getCancelMessage() {
    // final siteId = _id();
    return "Do you want to cancel the Earthing section for Solar Site (ID: ${widget.siteAuditSchId}) ?";
  }


  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<AssetAuditCubit, AssetAuditState>(
          listener: (context, state) {
            if (state is AssetAuditLoaded) {
              _loadExistingData();
            } else if (state is AssetAuditPostSuccess) {
              context.read<AssetAuditCubit>().getAssetAuditData(
                siteType: widget.siteType,
                auditSchId: widget.auditSchId,
                siteAuditSchId: widget.siteAuditSchId,
              );
            } else if (state is AssetAuditPostError) {
              print("for error ${state.message}");
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
            // Only handle images requested by this screen to prevent repeated processing
            if (state is AssetAuditGetImageSuccess && 
                state.imageData.isNotEmpty && 
                _isRequestingImage && 
                _currentRequestedImageId != null) {
              final finalImageData = state.imageData.startsWith('data:image/')
                  ? state.imageData
                  : 'data:image/jpeg;base64,${state.imageData}';
              setState(() {
                fetchedImageData = finalImageData;
                pcuPhoto = finalImageData;
                isLoadingImage = false;
                pcuCardKey++;
                _isRequestingImage = false;
                _currentRequestedImageId = null;
              });
              _fetchingImage = false;
              _fetchNextImage();
            } else if (state is AssetAuditGetImageFailure && _isRequestingImage) {
              setState(() {
                isLoadingImage = false;
                pcuCardKey++;
                _isRequestingImage = false;
                _currentRequestedImageId = null;
              });
              _handleImageLoadRetry(_lastRequestedPhotoId ?? '', 'pcu');
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
                message: _getCancelMessage(),
                onSaveAndExit: () async {
                  Navigator.of(context).pop(); // Pop dialog
                  _saveAndExit();
                },
                onDiscard: () async {
                  Navigator.of(context).pop(); // Pop dialog
                  await _updateAuditScheduleStatus("in-progress"); // Added for consistency
                  setState(() {
                    hasUnsavedChanges = false;
                  });
                  Navigator.pop(context); // Pop page (now canPop=true)
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
                                  label: "Inverter Make",
                                  hintText: "Text",
                                  isRequired: true,
                                  isEditable: false,
                                  initialValue: pcuCategoryData?.assets.isNotEmpty == true
                                      ? pcuCategoryData!.assets.first.oemName ?? "N/A"
                                      : "N/A",
                                ),
                                getHeight(15),
                                CustomFormField(
                                  label: "Capacity of Inverter",
                                  hintText: "Text",
                                  isRequired: false,
                                  isEditable: false,
                                  initialValue: pcuCategoryData?.assets.isNotEmpty == true
                                      ? pcuCategoryData!.assets.first.capacity ?? "N/A"
                                      : "N/A",
                                ),
                                getHeight(15),
                                CustomFormField(
                                  label: "Count of PCU",
                                  initialValue: totalPcuItems.toString(),
                                  isRequired: false,
                                  isEditable: false,
                                ),
                                getHeight(15),
                                Text(
                                  "Inverter Details",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white,
                                    fontFamily: fontFamilyMontserrat,
                                  ),
                                ),
                                getHeight(3),
                                CustomInfoCard(
                                  key: ValueKey('pcu_$pcuCardKey'),
                                  serialLabel: pcuCategoryData?.assets.isNotEmpty == true
                                      ? "Inverter (${pcuCategoryData!.assets.first.oemName ?? 'N/A'}) - Serial Number"
                                      : "Inverter - Serial Number",
                                  serialHintText: "Inverter Serial Number *",
                                  photoLabel: "Add a Photo",
                                  statusLabel: "Status",
                                  serialController: pcuSerialController,
                                  onSave: _savePcuForm,
                                  isStatusEditable: true,
                                  backendStatus: false,
                                  isRemarksEditable: true,
                                  showSaveButton: true,
                                  remarksLabel: "Rating",
                                  remarksController: ratingController,
                                  remarksHintText: pcuCategoryData?.assets.isNotEmpty == true
                                      ? pcuCategoryData!.assets.first.itemTypeRemark ?? "Rating"
                                      : "Rating",
                                  onRemarksChanged: (rating) {
                                    setState(() {
                                      hasUnsavedChanges = true;
                                    });
                                  },
                                  onPhotoTap: (photoPath) {
                                    setState(() {
                                      pcuPhoto = photoPath;
                                      fetchedImageData = null; // Clear fetched image when new photo is selected
                                      hasUnsavedChanges = true;
                                    });
                                  },
                                  onStatusChanged: (val) {
                                    setState(() {
                                      pcuStatus = val ? "OK" : "Not OK";
                                      hasUnsavedChanges = true;
                                    });
                                  },
                                  onSerialChanged: (serialNumber) {
                                    setState(() {
                                      pcuSerialNumber = serialNumber;
                                      isQRCodeScanned = false;
                                      hasUnsavedChanges = true;
                                    });
                                  },
                                  initialStatus: pcuStatus == "OK" ? true : (pcuStatus == "Not OK" ? false : null),
                                  initialPhotoPath: pcuPhoto, // Only use pcuPhoto, not fetchedImageData
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
                                      await _postPcuData();
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
              if (savedPcuItems.isNotEmpty) ...[
                ...savedPcuItems.map((item) {
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
