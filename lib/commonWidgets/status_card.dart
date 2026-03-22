import 'package:app/constants/app_colors.dart';
import 'package:app/constants/app_images.dart';
import 'package:app/constants/constants_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:app/commonWidgets/safe_svg_picture.dart';

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
        return AppImages.allTicket;
      case 'in progress':
        return AppImages.inProgress;
      case 'completed':
        return AppImages.completed;
      case 'closed':
        return AppImages.closed;
      case 'missed deadline':
        return AppImages.missed;
      case 'assigned to me':
        return Icons.schedule;
      default:
        return Icons.list_alt; // Default icon
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
                _buildIcon(title),
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

  Widget _buildIcon(String title) {
    final icon = _getIcon(title);
    
    if (icon is String) {
      // SVG asset
      return SafeSvgPicture.asset(
        icon,
        height: 24,
        width: 24,
        colorFilter: ColorFilter.mode(
          _getIconColor(title),
          BlendMode.srcIn,
        ),
      );
    } else if (icon is IconData) {
      // Material Icon
      return Icon(
        icon,
        size: 24,
        color: _getIconColor(title),
      );
    } else {
      // Default fallback
      return Icon(
        Icons.list_alt,
        size: 24,
        color: _getIconColor(title),
      );
    }
  }
}

