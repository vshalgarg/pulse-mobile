import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/constants_strings.dart';

class CustomRadioButton extends StatefulWidget {
  final String? label;
  final List<OptionItem> options;
  final Function(String value)? onChanged;
  final String? initialValue;
  final bool isRequired;
  final String? errorText;
  final double horizontalSpacing;
  final double iconTextSpacing;
  final Color? textColor;
  final double iconSize;
  final double fontSize;

  const CustomRadioButton({
    super.key,
    this.label,
    required this.options,
    this.onChanged,
    this.initialValue,
    this.isRequired = false,
    this.errorText,
    this.horizontalSpacing = 60.0,
    this.iconTextSpacing = 15.0,
    this.textColor,
    this.iconSize = 28,
    this.fontSize = 16,
  });

  @override
  State<CustomRadioButton> createState() => _CustomRadioButtonState();
}

class _CustomRadioButtonState extends State<CustomRadioButton> {
  String? selectedValue;

  @override
  void initState() {
    super.initState();
    selectedValue = widget.initialValue;
  }

  @override
  void didUpdateWidget(CustomRadioButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialValue != oldWidget.initialValue) {
      selectedValue = widget.initialValue;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label with required mark
        if (widget.label != null) ...[
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: widget.label ?? '',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                    fontFamily: fontFamilyMontserrat,
                  ),
                ),
                if (widget.isRequired)
                  const TextSpan(
                    text: ' *',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: AppColors.errorColor,
                      fontFamily: fontFamilyMontserrat,
                    ),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 5),

        // Options Row - Horizontally Scrollable
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: widget.options.map((option) {
            final bool isSelected = option.value == selectedValue;
            return GestureDetector(
              onTap: () {
                if(widget.onChanged != null) {
                  setState(() => selectedValue = option.value);
                  widget.onChanged!(option.value);
                }
              },
              child: Container(
                margin: EdgeInsets.only(right: widget.horizontalSpacing),
                child: Row(
                  children: [
                    // Custom circle or icon
                    isSelected
                        ? Icon(option.selectedIcon, color: AppColors.bulletIcon, size: widget.iconSize)
                        : Icon(option.unselectedIcon, color: AppColors.bulletIcon, size: widget.iconSize),

                    SizedBox(width: widget.iconTextSpacing),

                    Text(
                      option.label,
                      style: TextStyle(
                          fontSize: widget.fontSize,
                          fontWeight: FontWeight.w400,
                          color: widget.textColor ?? Colors.white,
                          fontFamily: fontFamilyMontserrat
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
          ),
        ),

        if (widget.errorText != null && widget.errorText!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              widget.errorText!,
              style: const TextStyle(
                fontWeight: FontWeight.w400,
                fontFamily: fontFamilyMontserrat,
                color: AppColors.errorColor,
                fontSize: 13,
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
    this.selectedIcon = Icons.radio_button_checked,
    this.unselectedIcon = Icons.radio_button_unchecked,
  });
}

// CustomOptionSelector(
// label: "Battery ODC Lock status",
// isRequired: true,
// options: [
// OptionItem(
// value: "yes",
// label: "Yes",
// selectedIcon: Icons.check_circle,
// unselectedIcon: Icons.circle_outlined,
// ),
// OptionItem(
// value: "no",
// label: "No",
// selectedIcon: Icons.cancel,
// unselectedIcon: Icons.circle_outlined,
// ),
// ],
// onChanged: (value) {
// setState(() {
// selectedBatteryStatus = value;
// hasUnsavedChanges = true;
// });
// },
// ),
