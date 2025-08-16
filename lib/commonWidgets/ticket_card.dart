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
  final Color statusColor;
  final Widget? rightIcon; // Optional right icon (like arrow/download)

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
    required this.statusColor,
    this.rightIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // First Row: Ticket ID + Status Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Ticket ID : $ticketId",
                  style: const TextStyle(fontSize: 14, color: Colors.black87),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 10),
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    statusText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Second Row: Site Code & Optional Icon
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "$siteCode (Site ID : $siteId)",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                if (rightIcon != null) rightIcon!,
              ],
            ),
            const SizedBox(height: 4),

            // Location
            Text(
              location,
              style: const TextStyle(
                color: Colors.blue,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),

            // Company
            Text(
              company,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
              ),
            ),

            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 8),

            // Dates Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Raised On : $raisedOn",
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
                Text(
                  "Due : $dueDate",
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

//
// TicketCard(
// ticketId: "Telecom-23947",
// siteCode: "SITE-FBD",
// siteId: "SITE-38974",
// location: "Faridabad",
// company: "PTPL",
// raisedOn: "23/04/2025",
// dueDate: "25/04/2025",
// statusText: "Allocated",
// statusColor: Colors.blue,
// ),
