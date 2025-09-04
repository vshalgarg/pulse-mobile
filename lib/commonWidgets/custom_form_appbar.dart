import 'package:app/constants/constants_methods.dart';
import 'package:flutter/material.dart';

class CustomFormAppbar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  // final String status;
  final VoidCallback onClose;

  const CustomFormAppbar({
    super.key,
    required this.title,
    // required this.status,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      shadowColor: Colors.transparent,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      automaticallyImplyLeading: false,
      flexibleSpace: Padding(
        padding: const EdgeInsets.only(left: 16, top: 60, right: 10),
        child: Row(
          children: [
            getHeight(80),
            Expanded(
              child: Text(
                "$title",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                  fontFamily: "Poppins",
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              icon: const Icon(
                Icons.close,
                color: Colors.red,
                size: 30,
              ),
              onPressed: onClose,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
