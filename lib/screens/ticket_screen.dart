
import 'package:app/constants/constants_methods.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

import '../commonWidgets/ticket_card.dart';
import '../constants/app_colors.dart';
import '../constants/app_images.dart';
import '../constants/constants_strings.dart';
import '../routes/routes.dart';

class TicketScreen extends StatefulWidget {
  final String auditName;
  final String status;

  const TicketScreen({
    super.key,
    required this.auditName,
    required this.status,
  });

  @override
  State<TicketScreen> createState() => _TicketScreenState();
}

class _TicketScreenState extends State<TicketScreen> {
  final List<Map<String, dynamic>> ticketData = [
    {
      'ticketId': 'Telecom-23947',
      'siteCode': 'SITE-FBD',
      'siteId': 'SITE-38974',
      'location': 'Faridabad',
      'company': 'PTPL',
      'raisedOn': '23/04/2025',
      'dueDate': '25/04/2025',
      'statusText': 'Allocated',
      'statusColor': Colors.blue,
    },
    {
      'ticketId': 'Telecom-23948',
      'siteCode': 'SITE-DEL',
      'siteId': 'SITE-38975',
      'location': 'Delhi',
      'company': 'PTPL',
      'raisedOn': '24/04/2025',
      'dueDate': '26/04/2025',
      'statusText': 'In Progress',
      'statusColor': Colors.orange,
    },
    {
      'ticketId': 'Telecom-23949',
      'siteCode': 'SITE-MUM',
      'siteId': 'SITE-38976',
      'location': 'Mumbai',
      'company': 'PTPL',
      'raisedOn': '25/04/2025',
      'dueDate': '27/04/2025',
      'statusText': 'Completed',
      'statusColor': Colors.green,
    },
    {
      'ticketId': 'Telecom-23950',
      'siteCode': 'SITE-BLR',
      'siteId': 'SITE-38977',
      'location': 'Bangalore',
      'company': 'PTPL',
      'raisedOn': '26/04/2025',
      'dueDate': '28/04/2025',
      'statusText': 'Closed',
      'statusColor': Colors.grey,
    },
    {
      'ticketId': 'Telecom-23951',
      'siteCode': 'SITE-HYD',
      'siteId': 'SITE-38978',
      'location': 'Hyderabad',
      'company': 'PTPL',
      'raisedOn': '27/04/2025',
      'dueDate': '29/04/2025',
      'statusText': 'Missed',
      'statusColor': Colors.red,
    },
  ];

  void _navigateToAuditScreen() {
    switch (widget.auditName) {
      case "Asset Audit":
        Navigator.pushNamed(context, assetAuditScreen);
        break;
      case "PM":
        Navigator.pushNamed(context, preventiveMaintenanceScreen);
        break;
      case "CM":
        Navigator.pushNamed(context, correctiveMaintenanceScreen);
        break;
      case "ER":
        Navigator.pushNamed(context, energyReadingScreen);
        break;
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No specific audit screen for ${widget.auditName}'),
            backgroundColor: AppColors.errorColor,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: _buildCustomAppBar(),
      body: Stack(
        children: [
          Positioned.fill(
            child: SvgPicture.asset(
              AppImages.home,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
            ),
          ),
                    // Content
          SafeArea(
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  getHeight(15),
                  ticketRow(),
                  getHeight(20), // Add bottom padding
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildCustomAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      shadowColor: Colors.transparent,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      automaticallyImplyLeading: false,
      flexibleSpace: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(left: 16, top: 12, right: 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  "${widget.auditName} - ${widget.status}",
                  style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                    fontFamily: poppins,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.close,
                  color: AppColors.errorColor,
                  size: 30,
                ),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget ticketRow() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: ticketData.length,
      itemBuilder: (context, index) {
        final ticket = ticketData[index];
        return Padding(
          padding: EdgeInsets.only(bottom: index == ticketData.length - 1 ? 0 : 10),
          child: TicketCard(
            ticketId: ticket['ticketId'],
            siteCode: ticket['siteCode'],
            siteId: ticket['siteId'],
            location: ticket['location'],
            company: ticket['company'],
            raisedOn: ticket['raisedOn'],
            dueDate: ticket['dueDate'],
            statusText: ticket['statusText'],
            // statusColor: ticket['statusColor'],
            onTap: _navigateToAuditScreen,
            onDirectionTap: () {
              print("Open Google Maps or navigation for ${ticket['ticketId']}");
            },
            onDownloadTap: () {
              print("Download ticket details for ${ticket['ticketId']}");
            },
          ),
        );
      },
    );
  }
}
