import 'package:app/constants/app_colors.dart';
import 'package:app/constants/constants_strings.dart';
import 'package:flutter/material.dart';

class TicketCard extends StatelessWidget {
  final String ticketId;
  final String siteCode;
  final String siteId;
  final String location;
  final String company;
  final String raisedOn;
  final String dueDate;
  final String statusText;
  final VoidCallback? onDownloadTap;
  final VoidCallback? onDirectionTap;
  final VoidCallback? onTap;

  const TicketCard({
    super.key,
    required this.ticketId,
    required this.siteCode,
    required this.siteId,
    required this.location,
    required this.company,
    required this.raisedOn,
    required this.dueDate,
    required this.statusText,
    this.onDownloadTap,
    this.onDirectionTap,
    this.onTap,
  });

  // Method to get status color based on status text
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'allocated':
        return AppColors.forgotColor;
      case 'completed':
        return AppColors.green8;
      case 'missed deadline':
        return AppColors.missedLineColor;
      case 'in progress':
        return AppColors.pendingColor;
      case 'pending':
        return AppColors.bellColor;
      case 'assigned to me':
        return AppColors.assignedColor;
      default:
        return Colors.grey; // Default color for unknown status
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 3,
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Ticket ID : $ticketId",
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                      fontWeight: FontWeight.w400,
                      fontFamily: fontFamilyMontserrat,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 4,
                      horizontal: 10,
                    ),
                    decoration: BoxDecoration(
                      color: _getStatusColor(statusText),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      statusText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontFamily: fontFamilyMontserrat,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "$siteCode (Site ID : $siteId)",
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      fontFamily: poppins,
                      color: AppColors.black,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.directions,
                      color: Colors.amber,
                      size: 24,
                    ),
                    onPressed: onDirectionTap,
                  ),
                ],
              ),
              Text(
                location,
                style: const TextStyle(
                  color: AppColors.locationColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  fontFamily: fontFamilyMontserrat,
                ),
              ),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    company,
                    style: const TextStyle(fontSize: 14, color: AppColors.black),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.file_download_outlined,
                      color: AppColors.downloadIconColor,
                    ),

                    onPressed: onDownloadTap,
                  ),
                ],
              ),

              const SizedBox(height: 4),
              const Divider(height: 0.5, color: AppColors.color555555),
              const SizedBox(height: 4),

              // Dates Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Raised On : $raisedOn",
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      fontFamily: fontFamilyMontserrat,
                      color: AppColors.color555555,
                    ),
                  ),
                  Text(
                    "Due : $dueDate",
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      fontFamily: fontFamilyMontserrat,
                      color: AppColors.color555555,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
