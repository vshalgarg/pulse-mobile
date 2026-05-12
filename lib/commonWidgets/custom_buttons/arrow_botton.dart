import 'package:app/constants/constants_methods.dart';
import 'package:app/constants/constants_strings.dart';
import 'package:flutter/material.dart';

class ArrowButton extends StatelessWidget {
  final String text;
  final bool isLeftArrow;
  final bool showArrow;
  final Color backgroundColor;
  final Color textColor;
  final VoidCallback? onPressed;

  const ArrowButton({
    super.key,
    required this.text,
    required this.isLeftArrow,
    this.showArrow = true,
    required this.backgroundColor,
    required this.textColor,
     this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(5),
        ),
        minimumSize: const Size(0, 0), // Allow button to size based on content
        fixedSize: const Size(0, 56), // Fixed height to prevent height increase
      ),
      onPressed: onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min, // Take minimum space needed
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (showArrow && isLeftArrow) ...[
            Icon(Icons.arrow_back, color: textColor, size: 20),
            getWidth(8),
          ],
          Flexible(
            child: Text(
              text,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: textColor,
                fontSize: 12, // Smaller font to fit in same height
                fontFamily: fontFamilyMontserrat,
                fontWeight: FontWeight.w600,
                height: 1.0, // Compact line height to fit in same space
              ),
            ),
          ),
          if (showArrow && !isLeftArrow) ...[
            getWidth(8),
            Icon(Icons.arrow_forward, color: textColor, size: 20),
          ],
        ],
      ),
    );
  }
}

// class ArrowButtonRow extends StatelessWidget {
//   const ArrowButtonRow({super.key});
//
//   @override
//   Widget build(BuildContext context) {
//     return Row(
//       children: [
//         ArrowButton(
//           text: "DG",
//           isLeftArrow: true,
//           backgroundColor: const Color(0xFFDDE1F3), // Light lavender
//           textColor: const Color(0xFF223366),
//           onPressed: () {},
//         ),
//         const SizedBox(width: 12),
//         ArrowButton(
//           text: "Hygiene",
//           isLeftArrow: false,
//           backgroundColor: const Color(0xFFDFF4E5), // Light green
//           textColor: const Color(0xFF114422),
//           onPressed: () {},
//         ),
//       ],
//     );
//   }
// }
