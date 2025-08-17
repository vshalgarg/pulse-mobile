import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../constants/constants_strings.dart';

class UnsavedChangesDialog extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback onSaveAndExit;
  final VoidCallback onDiscard;
  final VoidCallback? onCancel;

  const UnsavedChangesDialog({
    super.key,
    required this.title,
    required this.message,
    required this.onSaveAndExit,
    required this.onDiscard,
    this.onCancel,
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
            // Close button - positioned at top-right corner
            Align(
              alignment: Alignment.topRight,
              child: GestureDetector(
                onTap: onCancel ?? () => Navigator.of(context).pop(),
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 10),
            
            // Title
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
                fontFamily: fontFamilyMontserrat,
              ),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 15),
            
            // Message
            Text(
              message,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black54,
                fontFamily: fontFamilyMontserrat,
              ),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 25),
            
            // Action buttons - properly positioned within dialog
            Row(
              children: [
                // Save & Exit button
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      onSaveAndExit();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.buttonColorBg,
                      foregroundColor: AppColors.buttonColorSite,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      "Save & Exit",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        fontFamily: fontFamilyMontserrat,
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(width: 12),
                
                // Discard button
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      onDiscard();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      "Discard",
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
          ],
        ),
      ),
    );
  }
}
