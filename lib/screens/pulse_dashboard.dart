import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:app/constants/app_colors.dart';
import 'package:app/constants/app_images.dart';
import 'package:app/utils/toastbar.dart';
import 'package:app/utils/user_name_utils.dart';
import 'package:app/bloc/login_bloc/auth_cubit.dart';
import 'package:app/constants/constants_methods.dart';
import 'package:app/screens/login_screen.dart';
import 'package:app/screens/home_screen.dart';
import 'package:app/screens/my_tickets.dart';

class PulseDashboard extends StatefulWidget {
  const PulseDashboard({Key? key}) : super(key: key);

  @override
  State<PulseDashboard> createState() => _PulseDashboardState();
}

class _PulseDashboardState extends State<PulseDashboard> {
  final GlobalKey<PopupMenuButtonState> _profileMenuKey =
      GlobalKey<PopupMenuButtonState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Background - same as HomeScreen
          Positioned.fill(
            child: SvgPicture.asset(AppImages.home, fit: BoxFit.cover),
          ),

          // Header Section
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(child: _buildHeader()),
          ),

          // Greeting Section
          Positioned(
            top: 80,
            left: 0,
            right: 0,
            child: _buildGreetingSection(),
          ),

          // Main Content - Cards Grid
          Positioned(
            top: 200,
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildMainContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Logo - using the same image as HomeScreen
          Image.asset(
            AppImages.pulseImg,
            fit: BoxFit.cover,
            width: 113,
            height: 40,
          ),
          const Spacer(),
          // Notification bell - same as HomeScreen
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  Icons.notifications,
                  color: AppColors.bellColor,
                  size: 35,
                ),
              ),
              Positioned(
                right: 1,
                top: 4,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: AppColors.errorColor,
                    shape: BoxShape.circle,
                  ),
                  child: const Text(
                    "10",
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 10),
          // Profile dropdown - same as HomeScreen
          PopupMenuButton<String>(
            key: _profileMenuKey,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            offset: const Offset(0, 50),
            color: Colors.white,
            onSelected: (String value) {
              if (value == 'my_tickets') {
                _navigateToMyTickets();
              } else if (value == 'logout') {
                _handleLogout();
              }
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem<String>(
                value: 'my_tickets',
                child: Row(
                  children: [
                    Icon(Icons.assignment, color: Colors.grey),
                    SizedBox(width: 12),
                    Text('My Tickets'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, color: Colors.red),
                    SizedBox(width: 12),
                    Text('Logout'),
                  ],
                ),
              ),
            ],
            child: const CircleAvatar(
              radius: 20,
              backgroundImage: AssetImage(AppImages.userPlaceholder),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGreetingSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 50),
      decoration: BoxDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hello ${UserNameUtils.getUserDisplayName()},',

            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "Here's a quick look at your tasks.",
            style: TextStyle(
              fontSize: 16,
              color: Colors.white,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    return Container(
      margin: const EdgeInsets.only(top: 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(10),
          topRight: Radius.circular(10),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: GridView.count(
          crossAxisCount: 3,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 0.85,
          children: [
            _buildTaskCard(
              iconPath: AppImages.assetAudit,
              label: 'Asset Audit',
              onTap: () => _navigateToTask('Asset Audit'),
            ),
            _buildTaskCard(
              iconPath: AppImages.preventiveMaintenance,
              label: 'Preventive Maintenance',
              onTap: () => _navigateToTask('Preventive Maintenance'),
            ),
            _buildTaskCard(
              iconPath: AppImages.correctiveMaintenance,
              label: 'Corrective Maintenance',
              onTap: () => _navigateToTask('Corrective Maintenance'),
            ),
            _buildTaskCard(
              iconPath: AppImages.energyReading,
              label: 'Energy Reading',
              onTap: () => _navigateToTask('Energy Reading'),
            ),
            _buildTaskCard(
              iconPath: AppImages.siteaccess,
              label: 'Site Access',
              onTap: () => _navigateToTask('Site Access'),
              isComingSoon: true,
            ),
            _buildTaskCard(
              iconPath: AppImages.inspection,
              label: 'General Inspection',
              onTap: () => _navigateToTask('General Inspection'),
              isComingSoon: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskCard({
    required String iconPath,
    required String label,
    required VoidCallback onTap,
    bool isComingSoon = false,
  }) {
    return GestureDetector(
      onTap: isComingSoon ? null : onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 4),
          // Shaded icon box with Coming Soon badge
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.dashboardIconBoxColor,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 5,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: SvgPicture.asset(
                  iconPath,
                  fit: BoxFit.contain,
                  width: 0,
                  height: 0,
                  allowDrawingOutsideViewBox: true,
                  color: null,
                ),
              ),
              // Coming Soon badge in top right corner
              if (isComingSoon)
                Positioned(
                  top: -7, // move it slightly above the box
                  right: -20, // move it slightly outside the box
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 2,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.isComingSoonColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: const Text(
                      'Coming soon',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          // Label below
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: AppColors.dashboardTextColor,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  void _navigateToTask(String taskName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HomeScreen(selectedActivity: taskName),
      ),
    );
  }

  void _navigateToMyTickets() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const MyTicketsScreen(),
      ),
    );
  }

  void _handleLogout() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Logout'),
          content: const Text('Are you sure you want to logout?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                // Clear all authentication data before navigating to login
                await context.read<AuthCubit>().forceClearAllData();
                pushReplacementPage(context, LoginScreen());
                Toastbar.showSuccessToastbar(
                  'Logged out successfully',
                  context,
                );
              },
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );
  }
}
