import 'package:app/commonWidgets/dashBoard_appBar.dart';
import 'package:app/constants/app_sizes.dart';
import 'package:app/constants/constants_methods.dart';
import 'package:app/constants/constants_strings.dart';
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

          // Foreground
          SafeArea(
            child: Column(
              children: [
                // Fixed AppBar + User Detail
                Column(
                  children: [
                    const DashBoardAppBar(),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: userDetail(),
                    ),
                  ],
                ),
                // Scrollable content below
                Expanded(
                  child: SingleChildScrollView(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppColors.green7,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(10),
                          topRight: Radius.circular(10),
                        ),
                      ),
                      child: Column(
                        children: [
                          assetAudit(),
                          const SizedBox(height: 5),
                          ticketStatus(),
                          const SizedBox(height: 15),
                          pmAudit(),
                          const SizedBox(height: 5),
                          ticketStatus(),
                          const SizedBox(height: 15),
                          energyReading(),
                          const SizedBox(height: 5),
                          ticketStatus(),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
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
        const CircleAvatar(
          radius: 20,
          backgroundImage: AssetImage(AppImages.userPlaceholder),
        ),
      ],
    );
  }

  //asset audit


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
  Widget ticketStatus() {
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
                  print("All Tickets clicked");
                },
              ),
            ),
            getWidth(5),
            Expanded(
              child: StatusCard(
                count: "02",
                title: "All Tickets",
                icon: Icons.menu,
                backgroundColor: AppColors.progressColor,
                iconColor: Colors.orange,
                textColor: Colors.orange.shade800,
                onTap: () {
                  print("All Tickets clicked");
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
                title: "All Tickets",
                icon: Icons.menu,
                backgroundColor:  AppColors.completedColor,
                iconColor: Colors.orange,
                textColor: Colors.orange.shade800,
                onTap: () {
                  print("All Tickets clicked");
                },
              ),
            ),
            getWidth(5),
            Expanded(
              child: StatusCard(
                count: "02",
                title: "All Tickets",
                icon: Icons.menu,
                backgroundColor: AppColors.closedColor,
                iconColor: Colors.orange,
                textColor: Colors.orange.shade800,
                onTap: () {
                  print("All Tickets clicked");
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
                title: "All Tickets",
                icon: Icons.menu,
                backgroundColor: AppColors.missedColor,
                iconColor: Colors.orange,
                textColor: Colors.orange.shade800,
                onTap: () {
                  print("All Tickets clicked");
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

  // PM aUDIT------------
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


}
