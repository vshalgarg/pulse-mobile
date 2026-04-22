import 'package:app/constants/app_colors.dart';
import 'package:app/constants/constants_strings.dart';
import 'package:flutter/material.dart';

enum ActivityTicketCheckerAction {
  save,
  saveAndApprove,
  reject,
}

class ActivityTicketCheckerClosePopupResult {
  final String remarks;
  final ActivityTicketCheckerAction action;

  const ActivityTicketCheckerClosePopupResult({
    required this.remarks,
    required this.action,
  });
}

Future<ActivityTicketCheckerClosePopupResult?>
showActivityTicketCheckerClosePopup(
  BuildContext context, {
  bool showReviewBtns = true,
}) {
  return showDialog<ActivityTicketCheckerClosePopupResult>(
    context: context,
    barrierDismissible: true,
    useRootNavigator: true,
    builder: (dialogContext) => GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(dialogContext, rootNavigator: true).pop(),
      child: GestureDetector(
        onTap: () {},
        child: ActivityTicketCheckerClosePopup(
          showReviewBtns: showReviewBtns,
        ),
      ),
    ),
  );
}

class ActivityTicketCheckerClosePopup extends StatefulWidget {
  final bool showReviewBtns;

  const ActivityTicketCheckerClosePopup({
    super.key,
    this.showReviewBtns = true,
  });

  @override
  State<ActivityTicketCheckerClosePopup> createState() =>
      _ActivityTicketCheckerClosePopupState();
}

class _ActivityTicketCheckerClosePopupState
    extends State<ActivityTicketCheckerClosePopup> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _remarksController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _remarksController.text = '';
  }

  @override
  void dispose() {
    _remarksController.dispose();
    super.dispose();
  }

  void _submit(ActivityTicketCheckerAction action) {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) return;
    Navigator.of(context, rootNavigator: true).pop(
      ActivityTicketCheckerClosePopupResult(
        remarks: _remarksController.text.trim(),
        action: action,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 18),
      backgroundColor: const Color(0xFF5A5A5A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RichText(
                text: const TextSpan(
                  style: TextStyle(
                    fontFamily: poppins,
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    color: Colors.white,
                  ),
                  children: [
                    TextSpan(text: 'Remarks'),
                    TextSpan(
                      text: ' *',
                      style: TextStyle(color: AppColors.errorColor),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _remarksController,
                maxLines: 5,
                decoration: InputDecoration(
                  hintText: 'Remarks',
                  hintStyle: const TextStyle(
                    color: Color(0xFFB9B9B9),
                    fontFamily: poppins,
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF2F2F2),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFFDFDFDF),
                      width: 1.2,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFFDFDFDF),
                      width: 1.2,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFFDFDFDF),
                      width: 1.2,
                    ),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: AppColors.errorColor,
                      width: 1.2,
                    ),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: AppColors.errorColor,
                      width: 1.2,
                    ),
                  ),
                ),
                style: const TextStyle(
                  color: Color(0xFF5A5A5A),
                  fontFamily: poppins,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Remarks are required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              if (widget.showReviewBtns)
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: _actionButton(
                        label: 'Save',
                        labelColor: const Color(0xFF2A6F60),
                        backgroundColor: const Color(0xFFCFE2DB),
                        onTap: () => _submit(ActivityTicketCheckerAction.save),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 6,
                      child: _actionButton(
                        label: 'Save & Approve',
                        labelColor: const Color(0xFF2A6F60),
                        backgroundColor: const Color(0xFFCFE2DB),
                        onTap: () =>
                            _submit(ActivityTicketCheckerAction.saveAndApprove),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 3,
                      child: _actionButton(
                        label: 'Reject',
                        labelColor: AppColors.errorColor,
                        backgroundColor: const Color(0xFFF1EFEF),
                        onTap: () => _submit(ActivityTicketCheckerAction.reject),
                      ),
                    ),
                  ],
                )
              else
                SizedBox(
                  width: double.infinity,
                  child: _actionButton(
                    label: 'Save',
                    labelColor: const Color(0xFF2A6F60),
                    backgroundColor: const Color(0xFFCFE2DB),
                    onTap: () => _submit(ActivityTicketCheckerAction.save),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionButton({
    required String label,
    required Color labelColor,
    required Color backgroundColor,
    required VoidCallback onTap,
  }) {
    return SizedBox(
     
      child: ElevatedButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: labelColor,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          minimumSize: const Size(0, 40),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: labelColor,
            fontFamily: poppins,
            fontSize: 12,
            fontWeight: FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
