import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../constants/constants_strings.dart';

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
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Success icon - centered at top
            Center(
              child: Container(
                width: 60,
                height: 60,
                decoration: const BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check,
                  color: Colors.white,
                  size: 30,
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Ticket ID
            Text(
              "Ticket ID : $ticketId",
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
                fontFamily: fontFamilyMontserrat,
              ),
            ),
            
            const SizedBox(height: 10),
            
            // Success message
            Text(
              message,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.black87,
                fontFamily: fontFamilyMontserrat,
              ),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 25),
            
            // Done button - properly positioned within dialog
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  onDone();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  "Done",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    fontFamily: fontFamilyMontserrat,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
