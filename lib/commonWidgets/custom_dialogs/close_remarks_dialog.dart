import 'package:app/commonWidgets/custom_remark.dart';
import 'package:app/constants/app_colors.dart';
import 'package:app/utils/toastbar.dart';
import 'package:flutter/material.dart';

class CloseRemarksDialog extends StatefulWidget {
  final VoidCallback onCancel;
  final Function(String) onSubmit;

  const CloseRemarksDialog({
    super.key,
    required this.onCancel,
    required this.onSubmit,
  });

  @override
  State<CloseRemarksDialog> createState() => _CloseRemarksDialogState();
}

class _CloseRemarksDialogState extends State<CloseRemarksDialog> {
  late final TextEditingController _remarksController;

  @override
  void initState() {
    super.initState();
    _remarksController = TextEditingController();
  }

  @override
  void dispose() {
    _remarksController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 20),
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // White container with content
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width - 40,
                ),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                  decoration: BoxDecoration(
                    color: AppColors.color555555,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                     
                      const SizedBox(height: 20),
                      CustomRemarksField(
                        label: 'Add Ticket Closing Remark',
                        hintText: 'Enter closing remarks',
                        controller: _remarksController,
                        maxLines: 4,
                        isDisabled: false,
                        isRequired: true,
                        

                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // Buttons outside container
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.doneColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                    onPressed: () {
                      final remarks = _remarksController.text.trim();
                      if (remarks.isEmpty) {
                        Toastbar.showErrorToastbar(
                          'Please enter closing remarks',
                          context,
                        );
                        return;
                      }
                      widget.onSubmit(remarks);
                    },
                    child: const Text(
                      "Submit",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.heartColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                    onPressed: widget.onCancel,
                    child: const Text(
                      "Cancel",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Red close icon
          Positioned(
            top: -20,
            right: 15,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.onCancel,
                borderRadius: BorderRadius.circular(20),
                splashColor: Colors.white.withOpacity(0.3),
                highlightColor: Colors.white.withOpacity(0.1),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: AppColors.heartColor,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 20),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

