import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';

class SuccessDialog extends StatelessWidget {
  final String ticketId;
  final String message;
  final VoidCallback onDone;

  const SuccessDialog({
    super.key,
    required this.ticketId,
    required this.message,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
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
              Container(
                width: 300,
                padding: const EdgeInsets.fromLTRB(20, 40, 20, 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Text(
                      "Ticket ID : $ticketId",
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Done button outside
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.doneColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding:
                  const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                ),
                onPressed: onDone,
                child: const Text(
                  "Done",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),

          // Green check icon
          const Positioned(
            top: -25,
            child: CircleAvatar(
              radius: 25,
              backgroundColor: AppColors.doneColor,
              child: Icon(Icons.check, color: Colors.white, size: 28),
            ),
          ),
        ],
      ),
    );
  }
}

