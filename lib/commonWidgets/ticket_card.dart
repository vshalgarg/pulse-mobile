import 'package:app/constants/app_colors.dart';
import 'package:app/constants/constants_strings.dart';
import 'package:app/models/ticket_model.dart';
import 'package:app/utils.dart';
import 'package:flutter/material.dart';

class TicketCard extends StatelessWidget {
  final Ticket ticket;
  final String ticketId;
  final String siteCode;
  final String siteId;
  final String location;
  final String company;
  final String raisedOn;
  final String dueDate;
  final String statusText;
  final Color? statusColor;
  final Future<bool> Function(Ticket) isDownloadedFunc;
  final VoidCallback? onDownloadTap;
  final VoidCallback? onDirectionTap;
  final VoidCallback? onTap;
  final VoidCallback? onPdfDownloadTap;

  const TicketCard({
    super.key,
    required this.ticket,
    required this.ticketId,
    required this.siteCode,
    required this.siteId,
    required this.location,
    required this.company,
    required this.raisedOn,
    required this.dueDate,
    required this.statusText,
    required this.isDownloadedFunc,
    this.statusColor,
    this.onDownloadTap,
    this.onDirectionTap,
    this.onTap,
    this.onPdfDownloadTap,
  });

  // Method to get status color based on status text
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'allocated':
        return AppColors.forgotColor;
      case 'completed':
        return AppColors.green8;
      case 'missed deadline':
      case 'missed_deadline':
        return AppColors.missedLineColor;
      case 'in progress':
      case 'in-progress':
        return AppColors.pendingColor;
      case 'pending':
        return AppColors.bellColor;
      case 'assigned to me':
        return AppColors.assignedColor;
      case 'closed':
        return AppColors.green8; // Use green for closed status
      case 'due':
        return AppColors.bellColor; // Use bell color for due status
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
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      "Ticket ID : $ticketId",
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                        fontWeight: FontWeight.w400,
                        fontFamily: fontFamilyMontserrat,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 4,
                      horizontal: 10,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor ?? _getStatusColor(statusText),
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
                  Expanded(
                    child: Text(
                      "$siteCode",
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        fontFamily: poppins,
                        color: AppColors.black,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
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
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      company,
                      style: const TextStyle(fontSize: 14, color: AppColors.black),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  
                  // Add document icon for completed/closed tickets
                  if (statusText.toLowerCase() == 'completed' || 
                      statusText.toLowerCase() == 'closed')
                    IconButton(
                      icon: const Icon(
                        Icons.description,
                        color: Colors.blue,
                        size: 24,
                      ),
                      onPressed: onPdfDownloadTap,
                      tooltip: 'Download PDF Report',
                    ),
                  
                  // Keep existing download/check icon
                  FutureBuilder<bool>(
                    future: isDownloadedFunc(ticket),
                    builder: (context, snapshot) {
                      final isDownloaded = snapshot.data ?? false;
                      return isDownloaded
                          ? IconButton(
                              icon: const Icon(
                                Icons.check_circle,
                                color: AppColors.primaryGreen,
                              ),
                              onPressed: null,
                            )
                          : IconButton(
                              icon: const Icon(
                                Icons.file_download_outlined,
                                color: AppColors.downloadIconColor,
                              ),
                              onPressed: onDownloadTap,
                            );
                    },
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
                  Expanded(
                    flex: 1,
                    child: Text(
                      "Raised On : ${Utils.formatDataForTicketCard(raisedOn)}",
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        fontFamily: fontFamilyMontserrat,
                        color: AppColors.color555555,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 1,
                    child: Text(
                      "Due : ${Utils.formatDataForTicketCard(dueDate)}",
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        fontFamily: fontFamilyMontserrat,
                        color: AppColors.color555555,
                      ),
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
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
