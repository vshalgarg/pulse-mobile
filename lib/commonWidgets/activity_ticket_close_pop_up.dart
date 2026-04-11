import 'package:app/constants/app_colors.dart';
import 'package:app/commonWidgets/custom_form_dropdown.dart';
import 'package:flutter/material.dart';

/// Lowercases and maps Unicode dash/minus to ASCII `-` for status comparisons.
String normalizeActivityTicketCloseStatusForCompare(String? raw) {
  if (raw == null) return '';
  var s = raw.trim().toLowerCase();
  for (final ch in <String>[
    '\u2013',
    '\u2014',
    '\u2015',
    '\u2212',
    '\uFE63',
    '\uFF0D',
  ]) {
    s = s.replaceAll(ch, '-');
  }
  return s;
}

/// PMIS `repeatDt` as date only: `dd/MM/yyyy` (no time component).
String _formatActivityRepetitionDateForRepeatDt(DateTime value) {
  final dd = value.day.toString().padLeft(2, '0');
  final mm = value.month.toString().padLeft(2, '0');
  final yyyy = value.year.toString();
  return '$dd/$mm/$yyyy';
}

class ActivityTicketClosePopupResult {
  final String status;
  final DateTime? repetitionDate;
  final String remarks;

  const ActivityTicketClosePopupResult({
    required this.status,
    required this.repetitionDate,
    required this.remarks,
  });

  /// POST `currentStatus` — same as [status] from the close dialog.
  String get currentStatus => status;

  /// POST `repeatDt` from Activity Repetition Date; null if not set.
  String? get repeatDt => repetitionDate == null
      ? null
      : _formatActivityRepetitionDateForRepeatDt(repetitionDate!);

  /// POST `isRepeatNature`: true for Completed or Completed – To Be Repeated only.
  bool get isRepeatNature {
    final n = normalizeActivityTicketCloseStatusForCompare(status);
    return n == 'completed' || n == 'completed - to be repeated';
  }
}

Future<ActivityTicketClosePopupResult?> showActivityTicketClosePopup(
  BuildContext context, {
  String? initialStatus,
  DateTime? initialRepetitionDate,
  String? initialRemarks,
  List<String>? statusOptions,
}) {
  return showDialog<ActivityTicketClosePopupResult>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: false,
    builder: (_) => ActivityTicketClosePopup(
      initialStatus: initialStatus,
      initialRepetitionDate: initialRepetitionDate,
      initialRemarks: initialRemarks,
      statusOptions: statusOptions,
    ),
  );
}

class ActivityTicketClosePopup extends StatefulWidget {
  final String? initialStatus;
  final DateTime? initialRepetitionDate;
  final String? initialRemarks;
  final List<String>? statusOptions;

  const ActivityTicketClosePopup({
    super.key,
    this.initialStatus,
    this.initialRepetitionDate,
    this.initialRemarks,
    this.statusOptions,
  });

  @override
  State<ActivityTicketClosePopup> createState() =>
      _ActivityTicketClosePopupState();
}

class _ActivityTicketClosePopupState extends State<ActivityTicketClosePopup> {
  static const List<String> _defaultStatusOptions = <String>[
    'Completed',
    'Repeat',
  ];

  final TextEditingController _remarksController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  String? _status;
  DateTime? _repetitionDate;
  bool _showStatusError = false;

  /// Completed, Completed – To Be Repeated, Repeat, Repeated.
  bool _repetitionDateEnabled(String? status) {
    final n = normalizeActivityTicketCloseStatusForCompare(status);
    return n == 'completed' ||
        n == 'completed - to be repeated' ||
        n == 'repeat' ||
        n == 'repeated';
  }

  /// Repeat / Repeated / Completed – To Be Repeated require a date before save.
  bool _repetitionDateRequired(String? status) {
    final n = normalizeActivityTicketCloseStatusForCompare(status);
    return n == 'repeat' ||
        n == 'repeated' ||
        n == 'completed - to be repeated';
  }
  List<String> get _statusOptions {
    final options = widget.statusOptions
        ?.map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (options == null || options.isEmpty) return _defaultStatusOptions;
    return options;
  }

  @override
  void initState() {
    super.initState();
    _status = widget.initialStatus;
    _repetitionDate = widget.initialRepetitionDate;
    _remarksController.text = widget.initialRemarks ?? '';
  }

  @override
  void dispose() {
    _remarksController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    if (!_repetitionDateEnabled(_status)) return;
    final now = DateTime.now();
    final initial = _repetitionDate ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: now.subtract(const Duration(days: 3650)),
      lastDate: now.add(const Duration(days: 3650)),
    );
    if (picked == null) return;
    setState(() {
      _repetitionDate = picked;
    });
  }

  String _fmtDate(DateTime? dt) {
    if (dt == null) return '';
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final y = dt.year.toString();
    return '$d-$m-$y';
  }

  void _onSave() {
    final hasStatus = _status != null && _status!.trim().isNotEmpty;
    if (!hasStatus) {
      setState(() {
        _showStatusError = true;
      });
      return;
    }
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) return;
    // Match showDialog(useRootNavigator: true) so we only dismiss this dialog.
    Navigator.of(context, rootNavigator: true).pop(
      ActivityTicketClosePopupResult(
        status: _status!,
        repetitionDate:
            _repetitionDateEnabled(_status) ? _repetitionDate : null,
        remarks: _remarksController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final maxDialogHeight = MediaQuery.of(context).size.height * 0.8;
    return Dialog(
      backgroundColor: const Color(0xFF5B5B5B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 560, maxHeight: maxDialogHeight),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _label('Activity Status', required: true),
                const SizedBox(height: 8),
                CustomDropdown(
                  items: _statusOptions,
                  initialValue: _status,
                  onChanged: (v) {
                    setState(() {
                      _status = v;
                      _showStatusError = false;
                      if (!_repetitionDateEnabled(v)) _repetitionDate = null;
                    });
                  },
                ),
                if (_showStatusError)
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text(
                      'Please select status',
                      style: TextStyle(
                        color: AppColors.errorColor,
                        fontSize: 12,
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                _helper(
                  'Activity Repetition Date is available when status is '
                  'Completed, Completed – To Be Repeated, or Repeat.',
                ),
                const SizedBox(height: 12),
                _label(
                  'Activity Repetition Date',
                  required: _repetitionDateRequired(_status),
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(8),
                  child: InputDecorator(
                    decoration: _fieldDecoration(
                      hint: 'DD-MM-YYYY',
                    ).copyWith(
                      suffixIcon: Icon(
                        Icons.calendar_month_outlined,
                        color: _repetitionDateEnabled(_status)
                            ? AppColors.color555555
                            : AppColors.colorA0A0A0,
                      ),
                    ),
                    child: Text(
                      _repetitionDate == null ? '' : _fmtDate(_repetitionDate),
                      style: TextStyle(
                        color: _repetitionDateEnabled(_status)
                            ? AppColors.color555555
                            : AppColors.colorA0A0A0,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
                if (_repetitionDateRequired(_status) && _repetitionDate == null)
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text(
                      'Please select repetition date',
                      style: TextStyle(
                        color: AppColors.errorColor,
                        fontSize: 12,
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                _label('Remarks', required: true),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _remarksController,
                  maxLines: 4,
                  decoration: _fieldDecoration(hint: 'Remarks'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Remarks are required' : null,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () =>
                            Navigator.of(context, rootNavigator: true).pop(),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: const Color(0xFFF0EEEE),
                          side: BorderSide.none,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          minimumSize: const Size.fromHeight(52),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            color: AppColors.errorColor,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          if (_repetitionDateRequired(_status) &&
                              _repetitionDate == null) {
                            setState(() {});
                            return;
                          }
                          _onSave();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFCFE3DB),
                          foregroundColor: const Color(0xFF2D6C53),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          minimumSize: const Size.fromHeight(52),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Save',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String text, {bool required = false}) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        children: [
          TextSpan(text: text),
          if (required)
            const TextSpan(
              text: ' *',
              style: TextStyle(color: AppColors.errorColor),
            ),
        ],
      ),
    );
  }

  Widget _helper(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 1),
          child: Icon(
            Icons.info_outline,
            size: 16,
            color: Color(0xFFE0E0E0),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Color(0xFFE0E0E0),
              fontSize: 13,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      ],
    );
  }

  InputDecoration _fieldDecoration({required String hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        color: Color(0xFFB9B9B9),
        fontSize: 16,
      ),
      filled: true,
      fillColor: const Color(0xFFF2F2F2),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFDADADA)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFDADADA)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.primaryGreen, width: 1.2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.errorColor),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.errorColor, width: 1.2),
      ),
    );
  }
}
