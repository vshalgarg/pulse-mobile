import 'package:app/constants/app_colors.dart';
import 'package:flutter/material.dart';

class ActivityTicketClosePopupResult {
  final String status;
  final DateTime? repetitionDate;
  final String remarks;

  const ActivityTicketClosePopupResult({
    required this.status,
    required this.repetitionDate,
    required this.remarks,
  });
}

Future<ActivityTicketClosePopupResult?> showActivityTicketClosePopup(
  BuildContext context, {
  String? initialStatus,
  DateTime? initialRepetitionDate,
  String? initialRemarks,
}) {
  return showDialog<ActivityTicketClosePopupResult>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: false,
    builder: (_) => ActivityTicketClosePopup(
      initialStatus: initialStatus,
      initialRepetitionDate: initialRepetitionDate,
      initialRemarks: initialRemarks,
    ),
  );
}

class ActivityTicketClosePopup extends StatefulWidget {
  final String? initialStatus;
  final DateTime? initialRepetitionDate;
  final String? initialRemarks;

  const ActivityTicketClosePopup({
    super.key,
    this.initialStatus,
    this.initialRepetitionDate,
    this.initialRemarks,
  });

  @override
  State<ActivityTicketClosePopup> createState() =>
      _ActivityTicketClosePopupState();
}

class _ActivityTicketClosePopupState extends State<ActivityTicketClosePopup> {
  static const List<String> _statusOptions = <String>['Completed', 'Repeat'];

  final TextEditingController _remarksController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  String? _status;
  DateTime? _repetitionDate;

  bool get _isRepeat => _status == 'Repeat';

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
    if (!_isRepeat) return;
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
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) return;
    Navigator.of(context).pop(
      ActivityTicketClosePopupResult(
        status: _status!,
        repetitionDate: _isRepeat ? _repetitionDate : null,
        remarks: _remarksController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF5B5B5B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Form(
          key: _formKey,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _label('Activity Status', required: true),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _status,
                  items: _statusOptions
                      .map(
                        (s) => DropdownMenuItem<String>(
                          value: s,
                          child: Text(s),
                        ),
                      )
                      .toList(),
                  decoration: _fieldDecoration(hint: 'Select'),
                  icon: const Icon(Icons.keyboard_arrow_down),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Please select status' : null,
                  onChanged: (v) {
                    setState(() {
                      _status = v;
                      if (!_isRepeat) _repetitionDate = null;
                    });
                  },
                ),
                const SizedBox(height: 8),
                _helper(
                  "To repeat this activity, choose 'Repeat'",
                ),
                const SizedBox(height: 12),
                _label('Activity Repetition Date', required: _isRepeat),
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
                        color: _isRepeat
                            ? AppColors.color555555
                            : AppColors.colorA0A0A0,
                      ),
                    ),
                    child: Text(
                      _repetitionDate == null ? '' : _fmtDate(_repetitionDate),
                      style: TextStyle(
                        color: _isRepeat
                            ? AppColors.color555555
                            : AppColors.colorA0A0A0,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
                if (_isRepeat && _repetitionDate == null)
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
                const SizedBox(height: 8),
                _helper(
                  "Enabled & Mandatory when 'Repeat' status selected",
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
                        onPressed: () => Navigator.of(context).pop(),
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
                          if (_isRepeat && _repetitionDate == null) {
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
