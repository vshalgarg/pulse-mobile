import 'package:app/constants/constants_strings.dart';
import 'package:flutter/material.dart';

class StatusCard extends StatelessWidget {
  final String count;
  final String title;
  final IconData icon;
  final Color backgroundColor;
  final Color iconColor;
  final Color textColor;
  final VoidCallback onTap;

  const StatusCard({
    super.key,
    required this.count,
    required this.title,
    required this.icon,
    required this.backgroundColor,
    required this.iconColor,
    required this.textColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  count,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    fontFamily: fontFamilyInter,
                    color: textColor,
                  ),
                ),
                Icon(icon, size: 28, color: iconColor),
              ],
            ),
            const SizedBox(height: 20),
            // Title
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w400,
                fontFamily: fontFamilyInter,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
