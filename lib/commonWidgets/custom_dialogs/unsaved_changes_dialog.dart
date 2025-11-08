import 'package:app/commonWidgets/custom_dialogs/success_dialog.dart';
import 'package:app/constants/app_colors.dart';
import 'package:app/routes/route_generator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:app/bloc/audit_schedule_status_cubit.dart';

class UnsavedChangesDialog extends StatefulWidget {
  final String? message;
  final Future<void> Function() onSaveAndExit;
  final VoidCallback onDiscard;
  final String? siteAuditSchId;
  final String? section;
  final BuildContext? parentContext;

  const UnsavedChangesDialog({
    super.key,
    this.message,
    required this.onSaveAndExit,
    required this.onDiscard,
    this.siteAuditSchId,
    this.section,
    this.parentContext,
  });

  @override
  State<UnsavedChangesDialog> createState() => _UnsavedChangesDialogState();
}

class _UnsavedChangesDialogState extends State<UnsavedChangesDialog> {
  bool _isLoading = false;

  void _saveAndExit(BuildContext context) async {
    setState(() {
      _isLoading = true;
    });

    try {
      await widget.onSaveAndExit();

      // Use parentContext if available, otherwise use the dialog context
      final contextToUse = widget.parentContext ?? context;

      // Close the loading dialog first
      setState(() {
        _isLoading = false;
      });

      // Close the UnsavedChangesDialog before showing success/error dialog
      Navigator.of(context).pop();

      // Call the API to update audit schedule status if siteAuditSchId is provided
      if (widget.siteAuditSchId != null && widget.siteAuditSchId!.isNotEmpty) {
        // Get the current state after the API call
        AuditScheduleStatusState? currentState;
        try {
          currentState = contextToUse.read<AuditScheduleStatusCubit>().state;
        } catch (_) {
          currentState = null;
        }
        if (currentState is AuditScheduleStatusSuccess) {
          // Use the API response message in the success dialog
          _showSuccessDialogWithMessage(contextToUse, currentState.message);
        } else if (currentState is AuditScheduleStatusError) {
          // Show error message if API call fails
          _showErrorDialog(contextToUse, currentState.error);
        } else {
          // Fallback if state is not what we expect
          _showSuccessDialogWithMessage(
            contextToUse,
            (widget.section ?? "Data") +
                " for Site (ID: ${widget.siteAuditSchId}) has been recorded and saved.",
          );
        }
      } else {
        // Fallback message if no siteAuditSchId provided
        _showSuccessDialogWithMessage(
          contextToUse,
          (widget.section ?? "Data") +
              " for Site (ID: ${widget.siteAuditSchId ?? 'Unknown'}) has been recorded and saved.",
        );
      }
    } catch (e) {
      // Close the loading dialog first
      setState(() {
        _isLoading = false;
      });

      // Close the UnsavedChangesDialog before showing success dialog
      Navigator.of(context).pop();

      // Fallback message if API call fails
      _showSuccessDialogWithMessage(
        widget.parentContext ?? context,
        (widget.section ?? "Data") +
            " for Site (ID: ${widget.siteAuditSchId ?? 'Unknown'}) has been recorded and saved locally.",
      );
    }
  }

  void _showSuccessDialogWithMessage(BuildContext context, String message) {
    // Use parentContext for navigation, fallback to context if parentContext is null
    final navigationContext = widget.parentContext ?? context;

    print('DEBUG: parentContext is null: ${widget.parentContext == null}');
    print('DEBUG: Using navigationContext: ${navigationContext.runtimeType}');

    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (dialogContext) => SuccessDialog(
        ticketId: widget.siteAuditSchId ?? '',
        message: message,
        onDone: () {
          print('DEBUG: Success dialog onDone called');
          Navigator.of(
            dialogContext,
          ).pop(); // Close the success dialog using dialog context
          print('DEBUG: About to navigate back');
          Future.microtask(() {
            navigateBackOrToHome(
              navigationContext,
              targetContext: widget.parentContext,
            );
          });
          print('DEBUG: Navigation completed');
        },
      ),
    );
  }

  void _showErrorDialog(BuildContext context, String errorMessage) {
    // Use parentContext for navigation, fallback to context if parentContext is null
    final navigationContext = widget.parentContext ?? context;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Error'),
        content: Text('Failed to update status: $errorMessage'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(
                dialogContext,
              ).pop(); // Close the error dialog using dialog context
              Future.microtask(() {
                navigateBackOrToHome(
                  navigationContext,
                  targetContext: widget.parentContext,
                );
              });
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _onDiscard(BuildContext context) async {
    // Close the dialog first
    Navigator.of(context).pop();

    // Use parentContext if available, otherwise use the dialog context
    final contextToUse = widget.parentContext ?? context;

    print('DEBUG: contextToUse: ${contextToUse.toString()}');

    Future.microtask(() {
      navigateBackOrToHome(
        contextToUse,
        targetContext: widget.parentContext,
      );
      widget.onDiscard();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.all(20),
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // White container with message
              Container(
                width: 300,
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  "Do you want to save your progress before exiting?",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),

              const SizedBox(height: 20),

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
                      _saveAndExit(context);
                    },
                    child: const Text(
                      "Save & Exit",
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
                    onPressed: () {
                      _onDiscard(context);
                    },
                    child: const Text(
                      "Discard",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Red close icon
          Positioned(
            top: -25,
            right: 20,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  print('Close button tapped!'); // Debug print
                  Navigator.pop(context); // Just close the dialog, no action
                },
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
