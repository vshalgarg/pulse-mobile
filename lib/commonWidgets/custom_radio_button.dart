import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

class CustomRadioButton extends StatelessWidget {
  final Color activeColor;
  final bool isSelected;

  const CustomRadioButton({
    super.key,
    this.activeColor = AppColors.liqourText,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 16,
      width: 16,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.liqourText,
          width: 1.0,
        ),
      ),
      child: Center(
        child: isSelected
            ? Container(
                decoration: BoxDecoration(shape: BoxShape.circle, color: Theme.of(context).primaryColor,),
                width: 15,
                height: 15,
              )
            : null,
      ),
    );
  }
}
