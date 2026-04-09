import 'dart:io';

import 'package:app/commonWidgets/activity_ticket_close_pop_up.dart';
import 'package:app/commonWidgets/custom_file_upload_new.dart';
import 'package:app/commonWidgets/custom_form_dropdown.dart';
import 'package:app/commonWidgets/custom_form_field.dart';
import 'package:app/commonWidgets/custom_image_upload_field.dart';
import 'package:app/commonWidgets/safe_svg_picture.dart';
import 'package:app/constants/app_colors.dart';
import 'package:app/constants/app_images.dart';
import 'package:app/constants/constants_strings.dart';
import 'package:app/models/pmis_activity_ticket_model.dart';
import 'package:app/services/location_service.dart';
import 'package:app/utils/toastbar.dart';
import 'package:file_picker/file_picker.dart';
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
  late List<PmisTicketFieldValue> _sortedFields;

  static String _normDataType(PmisTicketFieldValue f) =>
      (f.subActivityDataType ?? '').trim().toUpperCase();

  static bool _isLongitudeField(PmisTicketFieldValue f) {
    final n = (f.subActivityName ?? '').toLowerCase();
    return n.contains('long') || n.contains('lng');
  }

  static Map<String, dynamic> _configMap(PmisTicketFieldValue f) {
    final c = f.configJson;
    if (c is Map) return Map<String, dynamic>.from(c);
    return const <String, dynamic>{};
  }

  static bool _allowMultiple(PmisTicketFieldValue f) {
    final m = _configMap(f)['allowMultipleFiles'];
    return m == true || m == 1 || m?.toString().toLowerCase() == 'true';
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
      }
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
    try {
      final loc = await LocationService.getCurrentLocation();
      if (!mounted) return;
      final isLng = _isLongitudeField(f);
      final v = isLng ? loc.longitude : loc.latitude;
      setState(() {
        _textByTfv[f.tfvId]!.text = v.toStringAsFixed(6);
      });
    } catch (e) {
      if (mounted) {
        Toastbar.showErrorToastbar(e.toString(), context);
      }
    }
  }

  static const int _maxUploadBytes = 2 * 1024 * 1024;

  Future<void> _addUploadFiles(PmisTicketFieldValue f) async {
    final type = _normDataType(f);
    final multi = _allowMultiple(f);
    FilePickerResult? result;
    if (type == 'IMAGE') {
      result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: multi,
      );
    } else if (type == 'VIDEO') {
      result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: multi,
      );
    } else if (type == 'PDF') {
      result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: multi,
      );
    }
    if (result == null || !mounted) return;

    final paths =
        result.files.map((e) => e.path).whereType<String>().toList();
    final valid = <File>[];
    for (final path in paths) {
      final file = File(path);
      final len = await file.length();
      if (len > _maxUploadBytes) {
        if (!mounted) return;
        Toastbar.showErrorToastbar(
          '${p.basename(path)} exceeds 2 MB',
          context,
        );
        continue;
      }
      valid.add(file);
    }
    if (valid.isEmpty) return;

    setState(() {
      final list = _filesByTfv[f.tfvId]!;
      if (!multi) list.clear();
      if (multi) {
        list.addAll(valid);
      } else {
        list
          ..clear()
          ..add(valid.first);
      }
    });
  }

  String _valTextForField(PmisTicketFieldValue f) {
    final type = _normDataType(f);
    if (type == 'DROPDOWN') {
      return (_dropdownByTfv[f.tfvId] ?? '').trim();
    }
    if (_isUploadType(type)) {
      final files = _filesByTfv[f.tfvId] ?? [];
      if (files.isEmpty) return '';
      return files.map((e) => e.path).join(',');
    }
    return _textByTfv[f.tfvId]!.text.trim();
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

  List<Map<String, dynamic>> _buildValTextPayload() {
    return _sortedFields
        .map(
          (f) => <String, dynamic>{
            'tfvId': f.tfvId,
            'valText': _valTextForField(f),
          },
        )
        .toList();
  }

  Future<void> _onSubmit() async {
    FocusScope.of(context).unfocus();
    if (!_validateAll()) return;
    final payload = _buildValTextPayload();
    final close = await showActivityTicketClosePopup(context);
    if (!mounted) return;
    if (close == null) return;
    Navigator.of(context).pop(<String, dynamic>{
      'ticketFieldValues': payload,
      'closeStatus': close.status,
      'closeRepetitionDate': close.repetitionDate,
      'closeRemarks': close.remarks,
    });
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
        final multi = _allowMultiple(f);
        if (multi) {
          return _multiFileUploadBlock(
            f: f,
            label: label,
            req: req,
            addLabel: 'Add photo',
            emptyHint: 'Upload a File',
          );
        }
        return ImageUploadField(
          label: label,
          placeholder: 'Upload a File',
          isRequired: req,
          uploadBoxHeight: 168,
          uploadBorderRadius: 8,
          onImageSelected: (file) {
            setState(() {
              final list = _filesByTfv[f.tfvId]!;
              list
                ..clear()
                ..addAll(file != null ? [file] : []);
            });
          },
          externalImageUrl: null,
        );
      case 'PDF':
      case 'VIDEO':
        final multi = _allowMultiple(f);
        if (multi) {
          return _multiFileUploadBlock(
            f: f,
            label: label,
            req: req,
            addLabel: type == 'PDF' ? 'Add PDF' : 'Add video',
            emptyHint: type == 'PDF'
                ? 'Upload a File'
                : 'Upload a File',
          );
        }
        final files = _filesByTfv[f.tfvId]!;
        return CustomFileUploadNew(
          label: label,
          placeholder: 'Upload a File',
          isRequired: req,
          acceptedFileTypes:
              type == 'PDF' ? '(PDF only)' : '(Video only)',
          maxSizeText: '(Max Size: 2MB)',
          selectedFile: files.isNotEmpty ? files.first : null,
          uploadedFiles: const [],
          onFileSelected: (file) {
            setState(() {
              files
                ..clear()
                ..addAll(file != null ? [file] : []);
            });
          },
          onFileDeleted: (_) {
            setState(() => files.clear());
          },
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
                  onPressed: () => _captureGps(f),
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

  Widget _multiFileUploadBlock({
    required PmisTicketFieldValue f,
    required String label,
    required bool req,
    required String addLabel,
    required String emptyHint,
  }) {
    final files = _filesByTfv[f.tfvId]!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label: label, isRequired: req),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => _addUploadFiles(f),
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 140),
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.upload_file, color: AppColors.color555555),
                const SizedBox(height: 8),
                Text(
                  files.isEmpty ? emptyHint : '$addLabel (tap to add more)',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: fontFamilyMontserrat,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.color555555,
                  ),
                ),
                const Text(
                  '(Max 2 MB per file)',
                  style: TextStyle(
                    fontFamily: fontFamilyMontserrat,
                    fontSize: 11,
                    color: AppColors.color555555,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (files.isNotEmpty) ...[
          const SizedBox(height: 8),
          ...files.map(
            (file) => Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      p.basename(file.path),
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.color555555,
                        fontFamily: fontFamilyMontserrat,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => setState(() => files.remove(file)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
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
                        _TicketSummaryCard(
                          title: _summaryTitle(),
                          planStart: _formatPlanDate(
                            widget.detail.plannedStartDt,
                          ),
                          planEnd: _formatPlanDate(widget.detail.plannedEndDt),
                          actualStart: _formatPlanDate(
                            widget.detail.actualStartDt,
                          ),
                          actualEnd: _formatPlanDate(
                            widget.detail.actualEndDt,
                          ),
                        ),
                        const SizedBox(height: 16),
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
