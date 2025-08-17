import 'package:app/commonWidgets/dashBoard_appBar.dart';
import 'package:app/constants/app_sizes.dart';
import 'package:app/constants/constants_methods.dart';
import 'package:app/constants/constants_strings.dart';
import 'package:app/screens/corrective_maintenance_screen.dart';
import 'package:app/screens/login_screen.dart';
import 'package:app/screens/ticket_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../commonWidgets/custom_ticket_status_card.dart';
import '../constants/app_colors.dart';
import '../constants/app_images.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Background
          Positioned.fill(
            child: SvgPicture.asset(AppImages.home, fit: BoxFit.cover),
          ),

          // AppBar on background image
          const DashBoardAppBar(),
          
          // User Detail on background image
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(top: 80, left: 16, right: 16), // Added top padding to avoid AppBar
              child: userDetail(),
            ),
          ),
          
          // Scrollable content below
          Positioned(
            top: 190, // Position below user details
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.green7,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(10),
                  topRight: Radius.circular(10),
                ),
              ),
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: Container(
                  constraints: BoxConstraints(
                    minHeight: MediaQuery.of(context).size.height - 200, // Ensure minimum height
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  child: Column(
                    children: [
                      assetAudit(),
                      const SizedBox(height: 5),
                      assetAuditTicketStatus(),
                      const SizedBox(height: 15),
                      pmAudit(),
                      const SizedBox(height: 5),
                      pmAuditTicketStatus(),
                      const SizedBox(height: 15),
                      energyReading(),
                      const SizedBox(height: 5),
                      energyReadingTicketStatus(),
                      const SizedBox(height: 15),
                      correctiveMaintenance(),
                      const SizedBox(height: 5),
                      correctiveMaintenanceTicketStatus(),
                      const SizedBox(height: 20), // Add bottom padding
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget userDetail() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hello Amit,',
              style: TextStyle(
                fontSize: AppSizes.twentyFour,
                fontFamily: dmSans,
                fontWeight: FontWeight.w700,
                color: AppColors.white,
              ),
            ),
            Text(
              'Here’s a quick look at your tasks.',
              style: TextStyle(
                fontSize: AppSizes.sixteen,
                fontFamily: dmSans,
                fontWeight: FontWeight.w400,
                color: AppColors.white,
              ),
            ),
          ],
        ),

        // Profile image with popup
        PopupMenuButton<int>(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          offset: const Offset(0, 50),
          color: Colors.white,
          onSelected: (value) {
            if (value == 1) {
             pushReplacementPage(context, LoginScreen());
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 1,
              child: SizedBox(
                width: 130,
                height: 20,
                child: Text(
                  "Log Out",
                  style: TextStyle(
                    color: Colors.black,
                    fontFamily: fontFamilyInter,
                    fontSize: 16
                  ),
                ),
              ),
            ),
          ],
          child: const CircleAvatar(
            radius: 20,
            backgroundImage: AssetImage(AppImages.userPlaceholder),
          ),
        ),
      ],
    );
  }


  Widget assetAudit() {
    return Container(
      height: 45,
      padding: EdgeInsets.symmetric(vertical: 10, horizontal: 15),
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.auditColor,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(10),
          topRight: Radius.circular(10),
          bottomLeft: Radius.circular(5),
          bottomRight: Radius.circular(5),
        ),
      ),
      child: Text(
        "Asset Audit",
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 18,
          fontFamily: dmSans,
          color: AppColors.white,
        ),
      ),
    );
  }
  Widget assetAuditTicketStatus() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: StatusCard(
                count: "02",
                title: "All Tickets",
                icon: Icons.menu,
                backgroundColor: const Color(0xFFFFF3E0),
                iconColor: Colors.orange,
                textColor: Colors.orange.shade800,
                onTap: () {
                  pushPage(context, TicketScreen(
                    auditName: "Asset Audit",
                    status: "All Tickets",
                  ));
                  print("All Tickets clicked");
                },
              ),
            ),
            getWidth(5),
            Expanded(
              child: StatusCard(
                count: "02",
                title: "In progress",
                icon: Icons.menu,
                backgroundColor: AppColors.progressColor,
                iconColor: Colors.orange,
                textColor: Colors.orange.shade800,
                onTap: () {
                  pushPage(context, TicketScreen(
                    auditName: "Asset Audit",
                    status: "In Progress",
                  ));
                  print("In Progress clicked");
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Row(
          children: [
            Expanded(
              child: StatusCard(
                count: "02",
                title: "Completed",
                icon: Icons.menu,
                backgroundColor:  AppColors.completedColor,
                iconColor: Colors.orange,
                textColor: Colors.orange.shade800,
                onTap: () {
                  pushPage(context, TicketScreen(
                    auditName: "Asset Audit",
                    status: "Completed",
                  ));
                  print("Completed clicked");
                },
              ),
            ),
            getWidth(5),
            Expanded(
              child: StatusCard(
                count: "02",
                title: "Closed",
                icon: Icons.menu,
                backgroundColor: AppColors.closedColor,
                iconColor: Colors.orange,
                textColor: Colors.orange.shade800,
                onTap: () {
                  pushPage(context, TicketScreen(
                    auditName: "Asset Audit",
                    status: "Closed",
                  ));
                  print("Closed clicked");
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Row(
          children: [
            Expanded(
              child: StatusCard(
                count: "02",
                title: "Missed DeadLine",
                icon: Icons.menu,
                backgroundColor: AppColors.missedColor,
                iconColor: Colors.orange,
                textColor: Colors.orange.shade800,
                onTap: () {
                  pushPage(context, TicketScreen(
                    auditName: "Asset Audit",
                    status: "Missed Deadline",
                  ));
                  print("Missed Deadline clicked");
                },
              ),
            ),
            Expanded(child: getWidth(10)),
          ],
        ),
        const SizedBox(height: 5),
      ],
    );
  }

  Widget pmAuditTicketStatus() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: StatusCard(
                count: "02",
                title: "All Tickets",
                icon: Icons.menu,
                backgroundColor: const Color(0xFFFFF3E0),
                iconColor: Colors.orange,
                textColor: Colors.orange.shade800,
                onTap: () {
                  pushPage(context, TicketScreen(
                    auditName: "PM",
                    status: "All Tickets",
                  ));
                  print("PM All Tickets clicked");
                },
              ),
            ),
            getWidth(5),
            Expanded(
              child: StatusCard(
                count: "02",
                title: "In progress",
                icon: Icons.menu,
                backgroundColor: AppColors.progressColor,
                iconColor: Colors.orange,
                textColor: Colors.orange.shade800,
                onTap: () {
                  pushPage(context, TicketScreen(
                    auditName: "PM",
                    status: "In Progress",
                  ));
                  print("PM In Progress clicked");
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Row(
          children: [
            Expanded(
              child: StatusCard(
                count: "02",
                title: "Completed",
                icon: Icons.menu,
                backgroundColor:  AppColors.completedColor,
                iconColor: Colors.orange,
                textColor: Colors.orange.shade800,
                onTap: () {
                  pushPage(context, TicketScreen(
                    auditName: "PM",
                    status: "Completed",
                  ));
                  print("PM Completed clicked");
                },
              ),
            ),
            getWidth(5),
            Expanded(
              child: StatusCard(
                count: "02",
                title: "Closed",
                icon: Icons.menu,
                backgroundColor: AppColors.closedColor,
                iconColor: Colors.orange,
                textColor: Colors.orange.shade800,
                onTap: () {
                  pushPage(context, TicketScreen(
                    auditName: "PM",
                    status: "Closed",
                  ));
                  print("PM Closed clicked");
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Row(
          children: [
            Expanded(
              child: StatusCard(
                count: "02",
                title: "Missed DeadLine",
                icon: Icons.menu,
                backgroundColor: AppColors.missedColor,
                iconColor: Colors.orange,
                textColor: Colors.orange.shade800,
                onTap: () {
                  pushPage(context, TicketScreen(
                    auditName: "PM",
                    status: "Missed Deadline",
                  ));
                  print("PM Missed Deadline clicked");
                },
              ),
            ),
            Expanded(child: getWidth(10)),
          ],
        ),
        const SizedBox(height: 5),
      ],
    );
  }

  // PM AUDIT------------
  Widget pmAudit() {
    return Container(
      height: 45,
      padding: EdgeInsets.symmetric(vertical: 10, horizontal: 15),
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.auditColor,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(10),
          topRight: Radius.circular(10),
          bottomLeft: Radius.circular(5),
          bottomRight: Radius.circular(5),
        ),
      ),
      child: Text(
        "Preventive Maintenance",
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 18,
          fontFamily: dmSans,
          color: AppColors.white,
        ),
      ),
    );
  }


  Widget energyReadingTicketStatus() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: StatusCard(
                count: "02",
                title: "All Tickets",
                icon: Icons.menu,
                backgroundColor: const Color(0xFFFFF3E0),
                iconColor: Colors.orange,
                textColor: Colors.orange.shade800,
                onTap: () {
                  pushPage(context, TicketScreen(
                    auditName: "ER",
                    status: "All Tickets",
                  ));
                  print("Energy Reading All Tickets clicked");
                },
              ),
            ),
            getWidth(5),
            Expanded(
              child: StatusCard(
                count: "02",
                title: "In progress",
                icon: Icons.menu,
                backgroundColor: AppColors.progressColor,
                iconColor: Colors.orange,
                textColor: Colors.orange.shade800,
                onTap: () {
                  pushPage(context, TicketScreen(
                    auditName: "ER",
                    status: "In Progress",
                  ));
                  print("Energy Reading In Progress clicked");
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Row(
          children: [
            Expanded(
              child: StatusCard(
                count: "02",
                title: "Completed",
                icon: Icons.menu,
                backgroundColor:  AppColors.completedColor,
                iconColor: Colors.orange,
                textColor: Colors.orange.shade800,
                onTap: () {
                  pushPage(context, TicketScreen(
                    auditName: "ER",
                    status: "Completed",
                  ));
                  print("Energy Reading Completed clicked");
                },
              ),
            ),
            getWidth(5),
            Expanded(
              child: StatusCard(
                count: "02",
                title: "Closed",
                icon: Icons.menu,
                backgroundColor: AppColors.closedColor,
                iconColor: Colors.orange,
                textColor: Colors.orange.shade800,
                onTap: () {
                  pushPage(context, TicketScreen(
                    auditName: "ER",
                    status: "Closed",
                  ));
                  print("Energy Reading Closed clicked");
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Row(
          children: [
            Expanded(
              child: StatusCard(
                count: "02",
                title: "Missed DeadLine",
                icon: Icons.menu,
                backgroundColor: AppColors.missedColor,
                iconColor: Colors.orange,
                textColor: Colors.orange.shade800,
                onTap: () {
                  pushPage(context, TicketScreen(
                    auditName: "ER",
                    status: "Missed Deadline",
                  ));
                  print("Energy Reading Missed Deadline clicked");
                },
              ),
            ),
            Expanded(child: getWidth(10)),
          ],
        ),
        const SizedBox(height: 5),
      ],
    );
  }

  Widget correctiveMaintenanceTicketStatus() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: StatusCard(
                count: "02",
                title: "All Tickets",
                icon: Icons.menu,
                backgroundColor: const Color(0xFFFFF3E0),
                iconColor: Colors.orange,
                textColor: Colors.orange.shade800,
                onTap: () {
                  pushPage(context, TicketScreen(
                    auditName: "CM",
                    status: "All Tickets",
                  ));
                  print("Corrective Maintenance All Tickets clicked");
                },
              ),
            ),
            getWidth(5),
            Expanded(
              child: StatusCard(
                count: "01",
                title: "In Progress",
                icon: Icons.refresh,
                backgroundColor: AppColors.progressColor,
                iconColor: Colors.purple,
                textColor: Colors.purple.shade800,
                onTap: () {
                  pushPage(context, TicketScreen(
                    auditName: "CM",
                    status: "In Progress",
                  ));
                  print("Corrective Maintenance In Progress clicked");
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Row(
          children: [
            Expanded(
              child: StatusCard(
                count: "03",
                title: "Assigned to Me",
                icon: Icons.check,
                backgroundColor: const Color(0xFFFFF8E1),
                iconColor: Colors.orange,
                textColor: Colors.orange.shade800,
                onTap: () {
                  pushPage(context, TicketScreen(
                    auditName: "CM",
                    status: "Assigned to Me",
                  ));
                  print("Corrective Maintenance Assigned to Me clicked");
                },
              ),
            ),
            getWidth(5),
            Expanded(
              child: StatusCard(
                count: "03",
                title: "Closed",
                icon: Icons.folder,
                backgroundColor: const Color(0xFFF3E5F5),
                iconColor: Colors.purple,
                textColor: Colors.purple.shade800,
                onTap: () {
                  pushPage(context, TicketScreen(
                    auditName: "CM",
                    status: "Closed",
                  ));
                  print("Corrective Maintenance Closed clicked");
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
      ],
    );
  }

  // Energy Reading---------------
  Widget energyReading() {
    return Container(
      height: 45,
      padding: EdgeInsets.symmetric(vertical: 10, horizontal: 15),
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.auditColor,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(10),
          topRight: Radius.circular(10),
          bottomLeft: Radius.circular(5),
          bottomRight: Radius.circular(5),
        ),
      ),
      child: Text(
        "Energy Reading",
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 18,
          fontFamily: dmSans,
          color: AppColors.white,
        ),
      ),
    );
  }

  // Corrective Maintenance---------------
  Widget correctiveMaintenance() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 45,
            padding: EdgeInsets.symmetric(vertical: 10, horizontal: 15),
            decoration: BoxDecoration(
              color: AppColors.auditColor,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(10),
                  topRight: Radius.circular(5),
                bottomLeft: Radius.circular(5),
                bottomRight: Radius.circular(5),
              ),
            ),
            child: Text(
              "Corrective Maintenance",
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 18,
                fontFamily: dmSans,
                color: AppColors.white,
              ),
            ),
          ),
        ),
        getWidth(8), // Distance between containers
        Container(
          height: 45,
          width: 45,
          decoration: BoxDecoration(
            color: AppColors.auditColor,
            borderRadius: BorderRadius.only(
              topRight: Radius.circular(10),
              topLeft:  Radius.circular(5),
              bottomRight: Radius.circular(5),
              bottomLeft: Radius.circular(5),
            ),
          ),
          child: IconButton(
            onPressed: () {
              pushPage(context, CorrectiveMaintenanceScreen());
            },
            icon: Icon(
              Icons.add,
              color: AppColors.white,
              size: 24,
            ),
            padding: EdgeInsets.zero,
            constraints: BoxConstraints(),
          ),
        ),
      ],
    );
  }


}
