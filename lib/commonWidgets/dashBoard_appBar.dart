import 'package:app/constants/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

import '../constants/app_images.dart';
import '../services/service_locator.dart';

class DashBoardAppBar extends StatelessWidget implements PreferredSizeWidget {
  const DashBoardAppBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(120); // Taller than default

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.transparentColor,
      shadowColor: AppColors.transparentColor,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      automaticallyImplyLeading: false,
      flexibleSpace: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(left: 16, top: 12, ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () async {
                  try {
                    // Clear all asset audit data
                    await ServiceLocator().centralAssetAuditService.clearAllData();
                    
                    // Show success message
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('All asset audit data cleared successfully!'),
                        backgroundColor: AppColors.primaryGreen,
                      ),
                    );
                  } catch (e) {
                    // Show error message
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error clearing data: $e'),
                        backgroundColor: AppColors.errorColor,
                      ),
                    );
                  }
                },
                child: SvgPicture.asset(AppImages.pulseImg, fit: BoxFit.cover, width: 113, height: 40,),
              ),
              const Spacer(),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications,
                        color: AppColors.bellColor, size: 35),
                    onPressed: () {},
                  ),
                  Positioned(
                    right: 1,
                    top: 4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color:AppColors.errorColor,
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

            ],
          ),
        ),
      ),
    );
  }
}
