import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/constants_strings.dart';

class CustomOptionSelector extends StatefulWidget {
  final String label; // e.g. "Battery ODC Lock status"
  final List<OptionItem> options; // custom icons + labels
  final Function(String value) onChanged;
  final String? initialValue;
  final bool isRequired;

  const CustomOptionSelector({
    super.key,
    required this.label,
    required this.options,
    required this.onChanged,
    this.initialValue,
    this.isRequired = false,
  });

  @override
  State<CustomOptionSelector> createState() => _CustomOptionSelectorState();
}

class _CustomOptionSelectorState extends State<CustomOptionSelector> {
  String? selectedValue;

  @override
  void initState() {
    super.initState();
    selectedValue = widget.initialValue;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label with required mark
        Row(
          children: [
            Text(
              widget.label,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: Colors.white,
                  fontFamily: fontFamilyMontserrat
              ),
            ),
            if (widget.isRequired)
              const Text(
                " *",
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    color: AppColors.errorColor,
                    fontFamily: fontFamilyMontserrat
                ),
              ),
          ],
        ),
        const SizedBox(height: 5),

        // Options Row
        Row(
          children: widget.options.map((option) {
            final bool isSelected = option.value == selectedValue;
            return GestureDetector(
              onTap: () {
                setState(() => selectedValue = option.value);
                widget.onChanged(option.value);
              },
              child: Container(
                margin: const EdgeInsets.only(right: 60),
                child: Row(
                  children: [
                    // Custom circle or icon
                    isSelected
                        ? Icon(option.selectedIcon, color: AppColors.bulletIcon, size: 28)
                        : Icon(option.unselectedIcon, color: AppColors.bulletIcon, size: 28),

                    const SizedBox(width: 15),

                    Text(
                      option.label,
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                          color: Colors.white,
                          fontFamily: fontFamilyMontserrat
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),

        // Validation
        if (widget.isRequired && selectedValue == null)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(
              "This field is required",
              style: TextStyle(
                  fontWeight: FontWeight.w400,
                  fontFamily: fontFamilyMontserrat,
                  color: AppColors.errorColor,
                  fontSize: 13
              ),
            ),
          ),
      ],
    );
  }
}


class OptionItem {
  final String value;
  final String label;
  final IconData selectedIcon;
  final IconData unselectedIcon;

  OptionItem({
    required this.value,
    required this.label,
    required this.selectedIcon,
    required this.unselectedIcon,
  });
}
