import 'dart:io';
import 'dart:convert';

import 'package:app/app_config.dart';
import 'package:app/commonWidgets/activity_ticket_close_pop_up.dart';
import 'package:app/enum/activity_type_enum.dart';
import 'package:app/commonWidgets/custom_file_upload_new.dart';
import 'package:app/commonWidgets/custom_form_dropdown.dart';
import 'package:app/commonWidgets/custom_form_field.dart';
import 'package:app/commonWidgets/custom_image_upload_field.dart';
import 'package:app/commonWidgets/loader_widget.dart';
import 'package:app/commonWidgets/safe_svg_picture.dart';
import 'package:app/constants/app_colors.dart';
import 'package:app/constants/app_images.dart';
import 'package:app/constants/constants_strings.dart';
import 'package:app/models/pmis_activity_ticket_model.dart';
import 'package:app/services/location_service.dart';
import 'package:app/services/service_locator.dart';
import 'package:app/services/upload_dcouments.dart';
import 'package:app/utils/logger.dart';
import 'package:app/utils/toastbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

/// Main activity ticket flow screen (after approvals / checker list).
/// Renders [PmisActivityTicketDetail.ticketFieldValues] by [subActivityDataType].
class ActivityTicketScreen extends StatefulWidget {
  final String breadcrumbText;
  final String activityName;
  final String? summaryCardTitle;
  final PmisActivityTicketDetail detail;

  const ActivityTicketScreen({
    super.key,
    required this.breadcrumbText,
    required this.activityName,
    this.summaryCardTitle,
    required this.detail,
  });

  @override
  State<ActivityTicketScreen> createState() => _ActivityTicketScreenState();
}

class _ActivityTicketScreenState extends State<ActivityTicketScreen> {
  final Map<int, TextEditingController> _textByTfv = {};
  final Map<int, String?> _dropdownByTfv = {};
  final Map<int, List<File>> _filesByTfv = {};
  final Map<int, List<Map<String, dynamic>>> _uploadedAttachmentsByTfv = {};
  /// Base64 data URL, local path, or `data:image/...` for [ImageUploadField.externalImageUrl].
  final Map<int, String?> _imageExternalDataByTfv = {};
  late List<PmisTicketFieldValue> _sortedFields;
  /// Prevents overlapping GPS taps and disables the button while resolving.
  int? _capturingGpsTfvId;

  UploadDcoumentsService get _uploadService =>
      UploadDcoumentsService(apiService: ServiceLocator().apiService);

  static String _normDataType(PmisTicketFieldValue f) =>
      (f.subActivityDataType ?? '').trim().toUpperCase();

  /// Longitude if name clearly indicates longitude; latitude if it says
  /// "latitude" (avoids matching "long" inside "latitude").
  static bool _isLongitudeField(PmisTicketFieldValue f) {
    final n = (f.subActivityName ?? '').toLowerCase();
    if (n.contains('longitude')) return true;
    if (n.contains('lng')) return true;
    if (n.contains('latitude')) return false;
    return n.contains('long');
  }

  static Map<String, dynamic> _configMap(PmisTicketFieldValue f) {
    final c = f.configJson;
    if (c is Map) return Map<String, dynamic>.from(c);
    return const <String, dynamic>{};
  }

  @override
  void initState() {
    super.initState();
    _sortedFields = List<PmisTicketFieldValue>.from(
      widget.detail.ticketFieldValues,
    )..sort((a, b) => (a.seqNo ?? 0).compareTo(b.seqNo ?? 0));

    for (final f in _sortedFields) {
      _textByTfv[f.tfvId] = TextEditingController(text: _initialText(f));
      final type = _normDataType(f);
      if (type == 'DROPDOWN') {
        final v = f.valText?.toString().trim();
        _dropdownByTfv[f.tfvId] =
            (v != null && v.isNotEmpty) ? v : null;
      }
      if (_isUploadType(type)) {
        _filesByTfv[f.tfvId] = [];
        _uploadedAttachmentsByTfv[f.tfvId] = [];
      }
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final f in _sortedFields) {
        if (_normDataType(f) == 'IMAGE') {
          _loadExistingActivityTicketImage(f);
        }
      }
    });
  }

  /// One image per checklist row: first server [attachmentId], else first id in [valText].
  static String? _primaryImageAttachmentServerId(PmisTicketFieldValue f) {
    for (final a in f.attachments) {
      final id = a['attachmentId'] ?? a['attachment_id'];
      final s = id?.toString().trim() ?? '';
      if (s.isNotEmpty && s != '0' && s.toLowerCase() != 'null') {
        return s;
      }
    }
    final vt = f.valText?.toString().trim() ?? '';
    if (vt.isEmpty) return null;
    final parts = vt.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty);
    final first = parts.isEmpty ? '' : parts.first;
    if (first.isEmpty || first == '0' || first.toLowerCase() == 'null') {
      return null;
    }
    return first;
  }

  static String? _formatActivityTicketImageDisplayString(String? raw) {
    if (raw == null) return null;
    final cleaned = raw.trim();
    if (cleaned.isEmpty) return null;
    if (cleaned.startsWith('data:image/')) {
      if (cleaned.startsWith('data:image/jpg')) {
        return cleaned.replaceFirst('data:image/jpg', 'data:image/jpeg');
      }
      return cleaned;
    }
    if (cleaned.startsWith('/') ||
        cleaned.startsWith('file://') ||
        cleaned.startsWith(r'file:\')) {
      return cleaned;
    }
    return 'data:image/jpeg;base64,$cleaned';
  }

  /// Loads existing attachment for display (same pattern as PM [ImageUploadField]).
  Future<void> _loadExistingActivityTicketImage(PmisTicketFieldValue f) async {
    final photoId = _primaryImageAttachmentServerId(f);
    if (photoId == null || photoId.isEmpty) return;

    try {
      final loc = ServiceLocator();
      String? imageDataLocal;

      if (int.tryParse(photoId) != null &&
          !photoId.contains('LOCAL_IMAGE_ID')) {
        final cachedImage =
            await loc.imageUploadService.getImagesByServerId(photoId);
        if (cachedImage != null && cachedImage.imageData != null &&
            cachedImage.imageData!.trim().isNotEmpty) {
          imageDataLocal = await loc.imageUploadService
              .getImageUsingUniqueId(cachedImage.uniqueId);
          imageDataLocal ??= cachedImage.imageData;
        } else {
          final uniqueId = await loc.imageUploadService.downloadImageUsingServerId(
            photoId,
            ActivityTypeEnum.activityTicket,
            widget.detail.atId.toString(),
          );
          if (uniqueId != null) {
            imageDataLocal =
                await loc.centralAssetAuditService.getImageAsDataUrl(uniqueId);
            imageDataLocal ??=
                await loc.imageUploadService.getImageUsingUniqueId(uniqueId);
          }
        }
      } else {
        imageDataLocal =
            await loc.centralAssetAuditService.getImageAsDataUrl(photoId);
        imageDataLocal ??=
            await loc.imageUploadService.getImageUsingUniqueId(photoId);
      }

      if (!mounted) return;
      final formatted = _formatActivityTicketImageDisplayString(imageDataLocal);
      if (formatted != null && formatted.isNotEmpty) {
        setState(() => _imageExternalDataByTfv[f.tfvId] = formatted);
      }
    } catch (_) {
      // Leave field empty if download/cache fails.
    }
  }

  String _initialText(PmisTicketFieldValue f) {
    final t = f.valText;
    if (t != null && t.toString().trim().isNotEmpty) {
      return t.toString().trim();
    }
    if (f.valNumeric != null && f.valNumeric.toString().trim().isNotEmpty) {
      return f.valNumeric.toString().trim();
    }
    if (f.valInt != null) return f.valInt.toString();
    final vd = f.valDate;
    if (vd != null && vd.toString().trim().isNotEmpty) {
      final parsed = DateTime.tryParse(vd.toString());
      if (parsed != null) {
        return _formatDisplayDate(parsed);
      }
      return vd.toString();
    }
    final type = _normDataType(f);
    if (type == 'COORDINATES') {
      final coord =
          _isLongitudeField(f) ? f.longitude : f.latitude;
      if (coord != null && coord.trim().isNotEmpty) return coord.trim();
    }
    return '';
  }

  bool _isUploadType(String type) {
    return type == 'IMAGE' || type == 'PDF' || type == 'VIDEO';
  }

  @override
  void dispose() {
    for (final c in _textByTfv.values) {
      c.dispose();
    }
    super.dispose();
  }

  String _summaryTitle() {
    final fromWidget = widget.summaryCardTitle?.trim();
    if (fromWidget != null && fromWidget.isNotEmpty) return fromWidget;
    final fromApi = widget.detail.makerDesignationName?.trim();
    if (fromApi != null && fromApi.isNotEmpty) return fromApi;
    return widget.activityName;
  }

  static String _formatPlanDate(String? value) {
    if (value == null || value.trim().isEmpty) return '-';
    final trimmed = value.trim();
    final match = RegExp(
      r'^(\d{2})/([A-Za-z]{3})/(\d{4})$',
    ).firstMatch(trimmed);
    if (match == null) return trimmed;

    final day = match.group(1)!;
    final rawMonth = match.group(2)!;
    final year = match.group(3)!;
    final month =
        '${rawMonth[0].toUpperCase()}${rawMonth.substring(1).toLowerCase()}';
    return '$day-$month-$year';
  }

  static const List<String> _monthNames = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  static String _formatDisplayDate(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}-'
        '${_monthNames[d.month - 1]}-${d.year}';
  }

  static DateTime? _tryParseDisplayDate(String s) {
    final t = s.trim();
    if (t.isEmpty) return null;
    final iso = DateTime.tryParse(t);
    if (iso != null) return iso;
    final m = RegExp(r'^(\d{1,2})-([A-Za-z]{3})-(\d{4})$').firstMatch(t);
    if (m == null) return null;
    final day = int.tryParse(m.group(1)!);
    final monTok = m.group(2)!;
    final year = int.tryParse(m.group(3)!);
    if (day == null || year == null) return null;
    final monNorm =
        '${monTok[0].toUpperCase()}${monTok.substring(1).toLowerCase()}';
    final monthIdx = _monthNames.indexOf(monNorm);
    if (monthIdx < 0) return null;
    return DateTime(year, monthIdx + 1, day);
  }

  List<String> _dropdownItems(PmisTicketFieldValue f) {
    final map = _configMap(f);
    final keys = map.keys.map((k) => k.toString()).toList()..sort();
    return keys;
  }

  Future<void> _pickDate(int tfvId) async {
    final now = DateTime.now();
    final initial = _tryParseDisplayDate(_textByTfv[tfvId]!.text) ?? now;
    final d = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (d != null && mounted) {
      setState(() {
        _textByTfv[tfvId]!.text = _formatDisplayDate(d);
      });
    }
  }

  String? _validateNumeric(PmisTicketFieldValue f, String? raw) {
    final req = f.isRequired == true;
    final v = raw?.trim() ?? '';
    if (req && v.isEmpty) return 'Required';
    if (v.isEmpty) return null;
    final n = num.tryParse(v);
    if (n == null) return 'Invalid number';
    final min = f.minVal;
    final max = f.maxVal;
    if (min != null) {
      final mn = num.tryParse(min.toString());
      if (mn != null && n < mn) return 'Min $mn';
    }
    if (max != null) {
      final mx = num.tryParse(max.toString());
      if (mx != null && n > mx) return 'Max $mx';
    }
    return null;
  }

  Future<void> _captureGps(PmisTicketFieldValue f) async {
    if (_capturingGpsTfvId != null) return;
    if (!mounted) return;
    setState(() => _capturingGpsTfvId = f.tfvId);
    LoaderWidget.showLoader(context);
    try {
      final loc = await LocationService.getCurrentLocationForForm();
      if (!mounted) return;
      final isLng = _isLongitudeField(f);
      final v = isLng ? loc.longitude : loc.latitude;
      _textByTfv[f.tfvId]!.text = v.toStringAsFixed(6);
      setState(() {});
    } catch (e) {
      if (mounted) {
        Toastbar.showErrorToastbar(e.toString(), context);
      }
    } finally {
      LoaderWidget.hideLoader();
      if (mounted) {
        setState(() => _capturingGpsTfvId = null);
      } else {
        _capturingGpsTfvId = null;
      }
    }
  }

  static const int _maxUploadBytes = 2 * 1024 * 1024;

  Future<String?> _uploadTicketFile(File file) async {
    final result = await _uploadService.uploadFile(
      file: file,
      id: '0',
      activityType: 'AT',
    );
    if (!result.isSuccess || (result.data ?? '').trim().isEmpty) {
      return null;
    }
    return (result.data ?? '').trim();
  }

  Future<Map<String, dynamic>> _buildAttachmentObject(
    String uploadedId,
    String fileType,
  ) async {
    double latitude = 0;
    double longitude = 0;
    try {
      final location = await LocationService.getCurrentLocation();
      latitude = location.latitude;
      longitude = location.longitude;
    } catch (_) {
      // Keep 0,0 when location isn't available.
    }

    return <String, dynamic>{
      'taId': 0,
      'fileType': fileType,
      'latitude': latitude,
      'longitude': longitude,
      'geoAccuracyM': 0,
      'geoSource': 'MOBILE',
      'capturedDt': _nowForBackend(),
      // Backend FK: 0 is not a valid pmis_module_mst id; Swagger often omits this.
      'taggedMmId': null,
      'attachmentId': int.tryParse(uploadedId) ?? 0,
      'isActive': true,
      'remarks': '',
    };
  }

  /// Upload + build attachment map for image fields; shows loader and toasts.
  Future<Map<String, dynamic>?> _uploadImageFileWithChecks(File file) async {
    final len = await file.length();
    if (len > _maxUploadBytes) {
      if (mounted) {
        Toastbar.showErrorToastbar(
          '${p.basename(file.path)} exceeds 2 MB',
          context,
        );
      }
      return null;
    }
    if (!mounted) return null;
    LoaderWidget.showLoader(context);
    try {
      final uploadedId = await _uploadTicketFile(file);
      if (uploadedId == null) {
        if (mounted) {
          Toastbar.showErrorToastbar(
            'Failed to upload ${p.basename(file.path)}',
            context,
          );
        }
        return null;
      }
      return await _buildAttachmentObject(uploadedId, 'IMAGE');
    } finally {
      LoaderWidget.hideLoader();
    }
  }

  Future<void> _handleSingleImageSelection(
    PmisTicketFieldValue f,
    File? file,
  ) async {
    final list = _filesByTfv[f.tfvId]!;
    final attachments =
        _uploadedAttachmentsByTfv[f.tfvId] ?? <Map<String, dynamic>>[];
    if (file == null) {
      setState(() {
        list.clear();
        attachments.clear();
        _uploadedAttachmentsByTfv[f.tfvId] = attachments;
        _imageExternalDataByTfv[f.tfvId] = null;
      });
      return;
    }
    final attachment = await _uploadImageFileWithChecks(file);
    if (attachment == null || !mounted) return;
    setState(() {
      list
        ..clear()
        ..add(file);
      attachments
        ..clear()
        ..add(attachment);
      _uploadedAttachmentsByTfv[f.tfvId] = attachments;
      _imageExternalDataByTfv[f.tfvId] = file.path;
    });
  }

  /// One file per row; new pick replaces the previous (PDF, video).
  Widget _buildSingleTicketFileUpload({
    required PmisTicketFieldValue f,
    required String label,
    required bool req,
    required String fileTypeForAttachment,
    required String acceptedFileTypes,
    List<String>? pickAllowedExtensions,
    String? placeholder,
    bool useVideoPicker = false,
  }) {
    final files = _filesByTfv[f.tfvId]!;
    return CustomFileUploadNew(
      key: ValueKey<Object>(
        'at_file_${f.tfvId}_$fileTypeForAttachment'
        '_${files.length}_${_uploadedAttachmentsByTfv[f.tfvId]?.length ?? 0}',
      ),
      label: label,
      placeholder: placeholder ?? 'Upload a File',
      isRequired: req,
      acceptedFileTypes: acceptedFileTypes,
      maxSizeText: '(Max Size: 2MB)',
      pickAllowedExtensions: pickAllowedExtensions,
      useVideoPicker: useVideoPicker,
      selectedFile: files.isNotEmpty ? files.first : null,
      uploadedFiles: const [],
      onFileSelected: (file) async {
        final attachments =
            _uploadedAttachmentsByTfv[f.tfvId] ?? <Map<String, dynamic>>[];
        if (file == null) {
          setState(() {
            files.clear();
            attachments.clear();
            _uploadedAttachmentsByTfv[f.tfvId] = attachments;
          });
          return;
        }

        final len = await file.length();
        if (len > _maxUploadBytes) {
          if (!mounted) return;
          Toastbar.showErrorToastbar(
            '${p.basename(file.path)} exceeds 2 MB',
            context,
          );
          return;
        }

        // Show the picked file name immediately (do not wait for upload / GPS).
        if (!mounted) return;
        setState(() {
          files
            ..clear()
            ..add(file);
        });

        LoaderWidget.showLoader(context);
        try {
          final uploadedId = await _uploadTicketFile(file);
          if (uploadedId == null) {
            if (!mounted) return;
            Toastbar.showErrorToastbar(
              'Failed to upload ${p.basename(file.path)}',
              context,
            );
            setState(() {
              files.clear();
              attachments.clear();
              _uploadedAttachmentsByTfv[f.tfvId] = attachments;
            });
            return;
          }
          // Build attachment (includes location) before hiding loader so the UI
          // does not sit in an intermediate state after the overlay dismisses.
          final attachment = await _buildAttachmentObject(
            uploadedId,
            fileTypeForAttachment,
          );
          if (!mounted) return;
          setState(() {
            attachments
              ..clear()
              ..add(attachment);
            _uploadedAttachmentsByTfv[f.tfvId] = attachments;
          });
        } finally {
          LoaderWidget.hideLoader();
        }
      },
      onFileDeleted: (_) {
        setState(() {
          files.clear();
          _uploadedAttachmentsByTfv[f.tfvId] = <Map<String, dynamic>>[];
        });
      },
    );
  }

  String _valTextForField(PmisTicketFieldValue f) {
    final type = _normDataType(f);
    if (type == 'DROPDOWN') {
      return (_dropdownByTfv[f.tfvId] ?? '').trim();
    }
    if (_isUploadType(type)) {
      final attachments =
          _uploadedAttachmentsByTfv[f.tfvId] ?? const <Map<String, dynamic>>[];
      if (attachments.isEmpty) return '';
      return attachments
          .map((e) => e['attachmentId']?.toString() ?? '')
          .where((e) => e.isNotEmpty && e != '0')
          .join(',');
    }
    return _textByTfv[f.tfvId]!.text.trim();
  }

  String _formatBackendDate(DateTime value) {
    final dd = value.day.toString().padLeft(2, '0');
    final mm = value.month.toString().padLeft(2, '0');
    final yyyy = value.year.toString();
    final hh = value.hour.toString().padLeft(2, '0');
    final min = value.minute.toString().padLeft(2, '0');
    final ss = value.second.toString().padLeft(2, '0');
    return '$dd/$mm/$yyyy $hh:$min:$ss';
  }

  String _nowForBackend() => _formatBackendDate(DateTime.now());

  String? _normalizeDateString(String? raw) {
    if (raw == null || raw.trim().isEmpty) return raw;
    final parsed = DateTime.tryParse(raw.trim());
    if (parsed == null) return raw;
    return _formatBackendDate(parsed);
  }

  Map<String, dynamic> _mapChecker(PmisTicketChecker c) {
    return <String, dynamic>{
      'tcId': c.tcId,
      'levelNo': c.levelNo,
      'designationMstId': c.designationMstId ?? 0,
      'checkerUserMstId': c.checkerUserMstId ?? 0,
      'decisionStatus': c.decisionStatus ?? '',
      'decisionBy': c.decisionBy ?? '',
      'decisionDt': _normalizeDateString(c.decisionDt),
      'decisionRemarks': c.decisionRemarks ?? '',
      'latitude': c.latitude ?? '0',
      'longitude': c.longitude ?? '0',
      'geoAccuracyM': c.geoAccuracyM ?? '0',
      'geoSource': c.geoSource ?? '',
      'isActive': c.isActive,
      'remarks': c.remarks ?? '',
      'decisionByName': c.decisionByName ?? '',
      'checkerUserName': c.checkerUserName ?? '',
      'designationName': c.designationName ?? '',
    };
  }

  Map<String, dynamic> _mapFieldValue(
    PmisTicketFieldValue f, {
    required String valText,
    required List<Map<String, dynamic>> attachments,
  }) {
    return <String, dynamic>{
      'tfvId': f.tfvId,
      'valText': valText,
      'valNumeric': f.valNumeric ?? 0,
      'valInt': f.valInt ?? 0,
      'valDate': _normalizeDateString(f.valDate?.toString()),
      'valJson': f.valJson,
      'latitude': f.latitude ?? '0',
      'longitude': f.longitude ?? '0',
      'geoAccuracyM': f.geoAccuracyM ?? '0',
      'geoSource': f.geoSource ?? '',
      'isActive': f.isActive,
      'remarks': f.remarks ?? '',
      'attachments': attachments.map(_normalizeAttachmentDate).toList(),
      'subActivityName': f.subActivityName ?? '',
      'subActivityDataType': f.subActivityDataType ?? '',
      'subActivityControlType': f.subActivityControlType ?? '',
      'isRequired': f.isRequired ?? false,
      'seqNo': f.seqNo ?? 0,
      'minVal': f.minVal ?? 0,
      'maxVal': f.maxVal ?? 0,
      'configJson': (f.configJson is Map)
          ? Map<String, dynamic>.from(f.configJson as Map)
          : {},
      'linkMmId': f.linkMmId ?? 0,
    };
  }

  Map<String, dynamic> _mapOldData(PmisOldDataItem item) {
    return <String, dynamic>{
      'actualStartDt': _normalizeDateString(item.actualStartDt),
      'actualEndDt': _normalizeDateString(item.actualEndDt),
      'ticketFieldValues': item.ticketFieldValues
          .map(
            (f) => _mapFieldValue(
              f,
              valText: f.valText?.toString() ?? '',
              attachments: f.attachments,
            ),
          )
          .toList(),
      'makerUserName': item.makerUserName ?? '',
      'isModified': item.isModified ?? false,
    };
  }

  Map<String, dynamic> _buildPostPayload(ActivityTicketClosePopupResult close) {
    final updatedValTextByTfv = <int, String>{
      for (final f in _sortedFields) f.tfvId: _valTextForField(f),
    };

    return <String, dynamic>{
      'atId': widget.detail.atId,
      'ppaId': widget.detail.ppaId,
      'currentStatus': close.currentStatus,
      'currentStatusDt': _nowForBackend(),
      'makerDesignationMstId': widget.detail.makerDesignationMstId ?? 0,
      'makerUserMstId': widget.detail.makerUserMstId ?? 0,
      'makerAssignedDt': _normalizeDateString(widget.detail.makerAssignedDt),
      'plannedStartDt': _normalizeDateString(widget.detail.plannedStartDt),
      'plannedEndDt': _normalizeDateString(widget.detail.plannedEndDt),
      'actualStartDt': _normalizeDateString(widget.detail.actualStartDt),
      'actualEndDt': _normalizeDateString(widget.detail.actualEndDt),
      'isActive': widget.detail.isActive,
      'remarks': close.remarks,
      'ticketCheckers': widget.detail.ticketCheckers.map(_mapChecker).toList(),
      'ticketFieldValues': widget.detail.ticketFieldValues.map((f) {
        final updatedAttachments = _uploadedAttachmentsByTfv[f.tfvId];
        return _mapFieldValue(
          f,
          valText: updatedValTextByTfv[f.tfvId] ?? '',
          attachments: updatedAttachments ?? f.attachments,
        );
      }).toList(),
      'ticketAttachments': widget.detail.ticketAttachments
          .map((a) => _normalizeAttachmentDate(Map<String, dynamic>.from(a.raw)))
          .toList(),
      'makerUserName': widget.detail.makerUserName ?? '',
      'makerDesignationName': widget.detail.makerDesignationName ?? '',
      'oldData': widget.detail.oldData.map(_mapOldData).toList(),
      'showReviewBtns': widget.detail.showReviewBtns,
      'checkerLvl': widget.detail.checkerLvl ?? '',
      'role': widget.detail.role ?? '',
      'ticketStatusHistory': widget.detail.ticketStatusHistory.map((e) {
        final mapped = Map<String, dynamic>.from(e);
        mapped['changedDt'] = _normalizeDateString(
          mapped['changedDt']?.toString(),
        );
        return mapped;
      }).toList(),
      'allowedStatuses': widget.detail.allowedStatuses.join(', '),
      // Close dialog: currentStatus, repeatDt, remarks, isRepeatNature (see ActivityTicketClosePopupResult).
      'isRepeatNature': close.isRepeatNature,
      'isRepeating': close.isRepeatNature,
      'repeatDt': close.repeatDt,
    };
  }

  Map<String, dynamic> _normalizeAttachmentDate(Map<String, dynamic> attachment) {
    final normalized = Map<String, dynamic>.from(attachment);
    normalized['capturedDt'] = _normalizeDateString(
      normalized['capturedDt']?.toString(),
    );
    final taggedRaw = normalized['taggedMmId'];
    final tagged =
        taggedRaw == null ? null : int.tryParse(taggedRaw.toString());
    if (tagged == null || tagged == 0) {
      normalized['taggedMmId'] = null;
    }
    return normalized;
  }

  bool _validateAll() {
    for (final f in _sortedFields) {
      final type = _normDataType(f);
      final req = f.isRequired == true;

      if (type == 'NUMERIC') {
        final err = _validateNumeric(f, _textByTfv[f.tfvId]!.text);
        if (err != null) {
          Toastbar.showErrorToastbar(
            '${f.subActivityName}: $err',
            context,
          );
          return false;
        }
        continue;
      }

      if (type == 'TEXT' || type == 'DATE' || type == 'COORDINATES') {
        if (req && _textByTfv[f.tfvId]!.text.trim().isEmpty) {
          Toastbar.showErrorToastbar(
            '${f.subActivityName} is required',
            context,
          );
          return false;
        }
      }

      if (type == 'DROPDOWN' && req) {
        final v = (_dropdownByTfv[f.tfvId] ?? '').trim();
        if (v.isEmpty) {
          Toastbar.showErrorToastbar(
            '${f.subActivityName} is required',
            context,
          );
          return false;
        }
      }

      if (_isUploadType(type) && req) {
        final files = _filesByTfv[f.tfvId];
        if (files == null || files.isEmpty) {
          Toastbar.showErrorToastbar(
            '${f.subActivityName} is required',
            context,
          );
          return false;
        }
      }
    }
    return true;
  }

  Future<void> _onSubmit() async {
    FocusScope.of(context).unfocus();
    if (!_validateAll()) return;
    final close = await showActivityTicketClosePopup(
      context,
      statusOptions: widget.detail.allowedStatuses,
    );
    if (!mounted) return;
    if (close == null) return;

    final postPayload = _buildPostPayload(close);
    final payloadJson = const JsonEncoder.withIndent('  ').convert(postPayload);
    Logger.infoLog('[AT_POST_REQUEST_START]');
    print('[AT_POST_REQUEST_START]');
    const chunkSize = 900;
    for (int i = 0; i < payloadJson.length; i += chunkSize) {
      final end = (i + chunkSize < payloadJson.length)
          ? i + chunkSize
          : payloadJson.length;
      final chunk = payloadJson.substring(i, end);
      print(chunk);
      Logger.infoLog(chunk);
    }
    Logger.infoLog('[AT_POST_REQUEST_END]');
    print('[AT_POST_REQUEST_END]');

    LoaderWidget.showLoader(context);
    try {
      final repository = AppConfig.of(context).pmisActivityTicketRepository;
      final response = await repository.postActivityTicket(payload: postPayload);
      final responseJson = const JsonEncoder.withIndent('  ')
          .convert(response.data ?? <String, dynamic>{});
      Logger.infoLog('[AT_POST_RESPONSE_START]');
      print('[AT_POST_RESPONSE_START]');
      for (int i = 0; i < responseJson.length; i += chunkSize) {
        final end = (i + chunkSize < responseJson.length)
            ? i + chunkSize
            : responseJson.length;
        final chunk = responseJson.substring(i, end);
        print(chunk);
        Logger.infoLog(chunk);
      }
      Logger.infoLog('[AT_POST_RESPONSE_END]');
      print('[AT_POST_RESPONSE_END]');

      if (!mounted) return;
      if (response.isSuccess) {
        Toastbar.showSuccessToastbar('Activity ticket saved', context);
        // Stay on activity ticket screen; only the close dialog was dismissed on Save.
      } else {
        Toastbar.showErrorToastbar(
          response.errorMessage ?? 'Failed to save activity ticket',
          context,
        );
      }
    } finally {
      LoaderWidget.hideLoader();
    }
  }

  Widget _buildField(PmisTicketFieldValue f) {
    final type = _normDataType(f);
    final label = f.subActivityName?.trim().isNotEmpty == true
        ? f.subActivityName!.trim()
        : 'Field';
    final req = f.isRequired == true;

    switch (type) {
      case 'TEXT':
        return CustomFormField(
          label: label,
          controller: _textByTfv[f.tfvId],
          hintText: label,
          isRequired: req,
          inputType: InputType.text,
          inputBorderRadius: 8,
        );
      case 'NUMERIC':
        return CustomFormField(
          label: label,
          controller: _textByTfv[f.tfvId],
          hintText: label,
          isRequired: req,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          maxDecimalDigits: 6,
          validator: (v) => _validateNumeric(f, v),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,6}$')),
          ],
          inputBorderRadius: 8,
        );
      case 'DATE':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _FieldLabel(label: label, isRequired: req),
            const SizedBox(height: 5),
            InkWell(
              onTap: () => _pickDate(f.tfvId),
              borderRadius: BorderRadius.circular(8),
              child: InputDecorator(
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 16,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  suffixIcon: const Icon(
                    Icons.calendar_today_outlined,
                    size: 18,
                    color: AppColors.color555555,
                  ),
                ),
                child: Text(
                  _textByTfv[f.tfvId]!.text.isEmpty
                      ? 'DD-MMM-YYYY'
                      : _textByTfv[f.tfvId]!.text,
                  style: TextStyle(
                    fontFamily: fontFamilyMontserrat,
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    color: _textByTfv[f.tfvId]!.text.isEmpty
                        ? AppColors.color555555.withValues(alpha: 0.5)
                        : AppColors.color555555,
                  ),
                ),
              ),
            ),
          ],
        );
      case 'DROPDOWN':
        final items = _dropdownItems(f);
        if (items.isEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _FieldLabel(label: label, isRequired: req),
              const SizedBox(height: 8),
              const Text(
                'No options configured',
                style: TextStyle(
                  color: AppColors.white,
                  fontFamily: poppins,
                  fontSize: 14,
                ),
              ),
            ],
          );
        }
        return CustomDropdown(
          key: ValueKey<int>(f.tfvId),
          label: label,
          items: items,
          initialValue: _dropdownByTfv[f.tfvId],
          isRequired: req,
          onChanged: (v) => setState(() => _dropdownByTfv[f.tfvId] = v),
        );
      case 'IMAGE':
        // One [ImageUploadField] per row (same as PM): ignore allowMultipleFiles.
        final ext = _imageExternalDataByTfv[f.tfvId];
        return ImageUploadField(
          key: ValueKey<String>(
            'at_img_${f.tfvId}_${ext?.length ?? 0}_${_filesByTfv[f.tfvId]?.length ?? 0}',
          ),
          label: label,
          placeholder: 'Upload a File',
          isRequired: req,
          uploadBoxHeight: 168,
          uploadBorderRadius: 8,
          onImageSelected: (file) => _handleSingleImageSelection(f, file),
          externalImageUrl: ext,
        );
      case 'PDF':
        // Same UX for every PDF row: document picker (PDF only), one file, replace on re-pick.
        return _buildSingleTicketFileUpload(
          f: f,
          label: label,
          req: req,
          fileTypeForAttachment: 'PDF',
          acceptedFileTypes: '(PDF only)',
          pickAllowedExtensions: const ['pdf'],
          placeholder: 'Add PDF',
        );
      case 'VIDEO':
        // Same UX for every video row: system video picker only, one file, replace on re-pick.
        return _buildSingleTicketFileUpload(
          f: f,
          label: label,
          req: req,
          fileTypeForAttachment: 'VIDEO',
          acceptedFileTypes: '(Video only)',
          pickAllowedExtensions: null,
          useVideoPicker: true,
          placeholder: 'Add video',
        );
      case 'COORDINATES':
        final isGps =
            (f.subActivityControlType ?? '').trim().toUpperCase() ==
                'GPSBUTTON';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CustomFormField(
              label: label,
              controller: _textByTfv[f.tfvId],
              hintText: _isLongitudeField(f) ? 'Longitude' : 'Latitude',
              isRequired: req,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true, signed: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^-?\d*\.?\d{0,8}$')),
              ],
              inputBorderRadius: 8,
            ),
            if (isGps) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _capturingGpsTfvId != null
                      ? null
                      : () => _captureGps(f),
                  icon: const Icon(Icons.my_location, color: AppColors.white),
                  label: const Text(
                    'Use current location',
                    style: TextStyle(
                      color: AppColors.white,
                      fontFamily: poppins,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ],
        );
      default:
        return CustomFormField(
          label: label,
          controller: _textByTfv[f.tfvId],
          hintText: label,
          isRequired: req,
          inputType: InputType.text,
          inputBorderRadius: 8,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final fields = _sortedFields;

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: SafeSvgPicture.asset(AppImages.home, fit: BoxFit.cover),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF0A3A47).withValues(alpha: 0.88),
                    const Color(0xFF0F6B5C).withValues(alpha: 0.82),
                    const Color(0xFF2E8B57).withValues(alpha: 0.76),
                  ],
                  stops: const [0.0, 0.42, 1.0],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _TicketFlowHeader(
                  title: widget.activityName,
                  breadcrumb: widget.breadcrumbText,
                  onBack: () => Navigator.of(context).pop(),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        
                        if (fields.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(
                                    alpha: 0.06,
                                  ),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Text(
                              'No checklist fields for this ticket',
                              style: TextStyle(
                                fontFamily: poppins,
                                fontSize: 14,
                                color: AppColors.color555555,
                              ),
                            ),
                          )
                        else
                          ...fields.map(
                            (f) => Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: _buildField(f),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFDAF0E7),
                            foregroundColor: const Color(0xFF0A5D4A),
                            disabledBackgroundColor: const Color(0xFFDAF0E7)
                                .withValues(alpha: 0.5),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 0,
                          ),
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text(
                            'Back',
                            style: TextStyle(
                              fontFamily: poppins,
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFDAF0E7),
                            foregroundColor: const Color(0xFF0A5D4A),
                            disabledBackgroundColor: const Color(0xFFDAF0E7)
                                .withValues(alpha: 0.5),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 0,
                          ),
                          onPressed: _onSubmit,
                          child: const Text(
                            'Submit',
                            style: TextStyle(
                              fontFamily: poppins,
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
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
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String label;
  final bool isRequired;

  const _FieldLabel({required this.label, required this.isRequired});

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: label,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.white,
              fontFamily: fontFamilyMontserrat,
            ),
          ),
          if (isRequired)
            const TextSpan(
              text: ' *',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.red,
                fontFamily: fontFamilyMontserrat,
              ),
            ),
        ],
      ),
    );
  }
}

class _TicketFlowHeader extends StatelessWidget {
  final String title;
  final String breadcrumb;
  final VoidCallback onBack;

  const _TicketFlowHeader({
    required this.title,
    required this.breadcrumb,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 4, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(
                  Icons.arrow_back_sharp,
                  color: AppColors.white,
                  size: 24,
                ),
                onPressed: onBack,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                alignment: Alignment.centerLeft,
              ),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    fontFamily: poppins,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 8, top: 4, right: 8),
            child: Text(
              breadcrumb,
              style: TextStyle(
                color: AppColors.white.withValues(alpha: 0.92),
                fontSize: 12,
                fontWeight: FontWeight.w400,
                fontFamily: poppins,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TicketSummaryCard extends StatelessWidget {
  final String title;
  final String planStart;
  final String planEnd;
  final String actualStart;
  final String actualEnd;

  const _TicketSummaryCard({
    required this.title,
    required this.planStart,
    required this.planEnd,
    required this.actualStart,
    required this.actualEnd,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontFamily: fontFamilyMontserrat,
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.locationColor,
            ),
          ),
          const SizedBox(height: 12),
          Divider(
            height: 1,
            thickness: 1,
            color: Colors.black.withValues(alpha: 0.12),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _planLine('Plan Start', planStart),
                    const SizedBox(height: 10),
                    _planLine('Actual Start', actualStart),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _planLine('Plan End', planEnd),
                    const SizedBox(height: 10),
                    _planLine('Actual End', actualEnd),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _planLine(String label, String value) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(
          fontFamily: poppins,
          fontSize: 12,
          fontWeight: FontWeight.w400,
          height: 1.3,
        ),
        children: [
          TextSpan(
            text: '$label : ',
            style: TextStyle(
              color: AppColors.color555555.withValues(alpha: 0.85),
            ),
          ),
          TextSpan(
            text: value,
            style: const TextStyle(
              color: AppColors.color555555,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
