import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/constants_strings.dart';

class CustomHorizontalRadioButtons extends StatelessWidget {
  final List<RadioOption> options;
  final String? selectedValue;
  final Function(String value)? onButtonSelected;
  final double spacing;
  final Color? activeColor;
  final Color? inactiveColor;
  final Color? textColor;
  final double fontSize;
  final FontWeight fontWeight;

  const CustomHorizontalRadioButtons({
    super.key,
    required this.options,
    this.selectedValue,
    this.onButtonSelected,
    this.spacing = 16.0,
    this.activeColor,
    this.inactiveColor,
    this.textColor,
    this.fontSize = 16.0,
    this.fontWeight = FontWeight.w400,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: options.map((option) {
          final bool isSelected = option.value == selectedValue;
          
          return GestureDetector(
            onTap: () {
              if (onButtonSelected != null) {
                onButtonSelected!(option.value);
              }
            },
            child: Container(
              margin: EdgeInsets.only(right: spacing),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Custom Radio Button
                  Container(
                    height: 20,
                    width: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected 
                            ? (activeColor ?? AppColors.primaryGreen)
                            : (inactiveColor ?? AppColors.greyColor),
                        width: 2.0,
                      ),
                    ),
                    child: Center(
                      child: isSelected
                          ? Container(
                              height: 10,
                              width: 10,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: activeColor ?? AppColors.primaryGreen,
                              ),
                            )
                          : null,
                    ),
                  ),
                  
                  const SizedBox(width: 8),
                  
                  // Label Text
                  Text(
                    option.label,
                    style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: fontWeight,
                      color: textColor ?? AppColors.baseColorsBody,
                      fontFamily: fontFamilyMontserrat,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class RadioOption {
  final String label;
  final String value;

  const RadioOption({
    required this.label,
    required this.value,
  });
}
