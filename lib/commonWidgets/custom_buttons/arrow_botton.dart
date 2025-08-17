import 'package:app/constants/constants_methods.dart';
import 'package:app/constants/constants_strings.dart';
import 'package:flutter/material.dart';

class ArrowButton extends StatelessWidget {
  final String text;
  final bool isLeftArrow;
  final Color backgroundColor;
  final Color textColor;
  final VoidCallback onPressed;

  const ArrowButton({
    super.key,
    required this.text,
    required this.isLeftArrow,
    required this.backgroundColor,
    required this.textColor,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(5),
        ),
      ),
      onPressed: onPressed,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (isLeftArrow) ...[
            Icon(Icons.arrow_back, color: textColor),
            getWidth(15),
          ],
          Text(
            text,
            style: TextStyle(
                color: textColor,
                fontSize: 16,
                fontFamily: fontFamilyMontserrat,
                fontWeight: FontWeight.w600
            ),
          ),
          if (!isLeftArrow) ...[
            getWidth(15),
            Icon(Icons.arrow_forward, color: textColor),
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
