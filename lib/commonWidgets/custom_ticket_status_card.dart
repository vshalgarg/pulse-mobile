import 'package:app/constants/app_colors.dart';
import 'package:app/constants/constants_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class StatusCard extends StatelessWidget {
  final String count;
  final String title;
  final VoidCallback onTap;

  const StatusCard({
    super.key,
    required this.count,
    required this.title,
    required this.onTap,
  });

  Color _getBackgroundColor(String title) {
    switch (title.toLowerCase()) {
      case 'all tickets':
        return Color(0xFFFFF4DE);
      case 'in progress':
        return Color(0xFFDEF2FF);
      case 'completed':
        return Color(0xFFE0FFEA);
      case 'closed':
        return Color(0xFFF3E8FF);
      case 'missed deadlines':
        return Color(0xFFFFE6EB);
      case 'assigned to me':
        return Color(0xFFFFF4DE);
      default:
        return AppColors.greyBackgroundColor; // Default color
    }
  }

  // Method to get icon color based on title
  Color _getIconColor(String title) {
    switch (title.toLowerCase()) {
      case 'all tickets':
        return AppColors.forgotColor;
      case 'in progress':
        return AppColors.pendingColor;
      case 'completed':
        return AppColors.doneColor;
      case 'closed':
        return AppColors.assignedColor;
      case 'assigned to me':
        return AppColors.bellColor;
      default:
        return AppColors.greyColor; // Default color
    }
  }

  // Method to get text color based on title
  Color _getTextColor(String title) {
    switch (title.toLowerCase()) {
      case 'all tickets':
        return Color(0xFFFF9479);
      case 'in progress':
        return Color(0xFF7982FF);
      case 'completed':
        return Color(0xFF54B790);
      case 'closed':
        return Color(0xFFC282FF);
      case 'missed deadline':
        return Color(0xFFEA5455);
      case 'assigned to me':
        return AppColors.bellColor;
      default:
        return AppColors.greyColor; // Default color
    }
  }

  // Method to get icon based on title
  dynamic _getIcon(String title) {
    switch (title.toLowerCase()) {
      case 'all tickets':
        return "assets/images/allticket.svg";
      case 'in progress':
        return "assets/images/inPg.svg";
      case 'completed':
        return "assets/images/comp.svg";
      case 'closed':
        return "assets/images/close.svg";
      case 'missed deadline':
        return "assets/images/miss.svg";
      case 'assigned to me':
        return Icons.schedule;
      default:
        return Icons.list_alt; // Default icon
    }
  }

  // Method to build icon widget based on type
  Widget _buildIcon(dynamic icon, Color color) {
    if (icon is String) {
      return SvgPicture.asset(
        icon,
        height: 24,
        width: 24,
        errorBuilder: (BuildContext context, Object exception, StackTrace? stackTrace) {
          return Container(
            height: 24,
            width: 24,
            color: Colors.red.withOpacity(0.3),
            child: Icon(Icons.error, size: 16, color: Colors.red),
          );
        },
      );
    } else if (icon is IconData) {
      // Material Icon
      return Icon(
        icon,
        size: 24,
        color: color,
      );
    } else {
      // Default fallback
      return Icon(
        Icons.list_alt,
        size: 24,
        color: color,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _getBackgroundColor(title),
          borderRadius: BorderRadius.circular(5),
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
                    color: _getTextColor(title),
                  ),
                ),
                _buildIcon(_getIcon(title), _getIconColor(title))
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
                color: _getTextColor(title),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
