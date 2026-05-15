import 'package:app/constants/app_colors.dart';
import 'package:app/constants/constants_strings.dart';
import 'package:app/models/raise_it_ticket_model.dart';
import 'package:flutter/material.dart';

class RaiseItTicketCard extends StatelessWidget {
  final RaiseItTicket ticket;
  final VoidCallback? onTap;

  const RaiseItTicketCard({
    super.key,
    required this.ticket,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (ticket.ticketNo.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8E0F5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Ticket No : ${ticket.ticketNo}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: Color(0xFF5B3E96),
                          fontFamily: fontFamilyMontserrat,
                        ),
                      ),
                    ),
                  const Spacer(),
                  if (ticket.status.isNotEmpty) _StatusChip(status: ticket.status),
                ],
              ),
              if (ticket.assetType.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  ticket.assetType,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    fontFamily: poppins,
                    color: AppColors.assetTypeColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ] else if (ticket.category.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  ticket.category,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    fontFamily: poppins,
                    color: AppColors.black,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
          
              // if (ticket.assetType.isNotEmpty) ...[
              //   const SizedBox(height: 4),
              //   Text(
              //     ticket.assetType,
              //     style: const TextStyle(
              //       color: AppColors.assetTypeColor,
              //       fontSize: 14,
              //       fontWeight: FontWeight.w400,
              //       fontFamily: fontFamilyMontserrat,
              //     ),
              //     overflow: TextOverflow.ellipsis,
              //     maxLines: 2,
              //   ),
              // ],

              if (ticket.issueTitle.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  ticket.issueTitle,
                  style: const TextStyle(
                    color: AppColors.locationColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    fontFamily: fontFamilyMontserrat,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ],
              const SizedBox(height: 4),
              const Divider(height: 0.5, color: AppColors.color555555),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      ticket.assignedToName.isNotEmpty
                          ? 'Assigned To : ${ticket.assignedToName}'
                          : 'Assigned To : —',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        fontFamily: fontFamilyMontserrat,
                        color: AppColors.color555555,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (ticket.priority.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    _PriorityChip(priority: ticket.priority),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final normalized = status.trim().toLowerCase();
    Color bg;
    if (normalized == 'open') {
      bg = Colors.orange;
    } else if (normalized == 'closed') {
      bg = AppColors.primaryGreen;
    } else {
      bg = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        _displayStatus(status),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontFamily: fontFamilyMontserrat,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  String _displayStatus(String raw) {
    if (raw.trim().isEmpty) return raw;
    final lower = raw.trim().toLowerCase();
    return lower[0].toUpperCase() + lower.substring(1);
  }
}

class _PriorityChip extends StatelessWidget {
  final String priority;

  const _PriorityChip({required this.priority});

  @override
  Widget build(BuildContext context) {
    final normalized = priority.trim().toLowerCase();
    Color bg;
    Color fg;
    switch (normalized) {
      case 'high':
        bg = const Color(0xFFFFE5E5);
        fg = const Color(0xFFC62828);
        break;
      case 'low':
        bg = const Color(0xFFFFF3E0);
        fg = const Color(0xFFE65100);
        break;
      case 'critical':
        bg = const Color(0xFFFFEBEE);
        fg = const Color(0xFFB71C1C);
        break;
      default:
        bg = const Color(0xFFF5F5F5);
        fg = AppColors.color555555;
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        priority.trim().isEmpty
            ? priority
            : priority.trim()[0].toUpperCase() +
                priority.trim().substring(1).toLowerCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: fg,
          fontFamily: fontFamilyMontserrat,
        ),
      ),
    );
  }
}
