import 'package:app/constants/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:dropdown_button2/dropdown_button2.dart';

import '../constants/constants_strings.dart';

class CustomDropdown extends StatefulWidget {
  final String? label;
  final List<String> items;
  final String? initialValue;
  final ValueChanged<String?> onChanged;
  // final bool isRequired;

  const CustomDropdown({
    super.key,
     this.label,
    required this.items,
    this.initialValue,
    required this.onChanged,
    // this.isRequired,
  });

  @override
  State<CustomDropdown> createState() => _CustomDropdownState();
}

class _CustomDropdownState extends State<CustomDropdown> {
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
        Row(
          children: [
            Text(
              "${widget.label}",
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.white,
                fontFamily: fontFamilyMontserrat,
              ),
            ),
              const Text(
                " *",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.errorColor,
                  fontFamily: fontFamilyMontserrat,
                ),
              ),
          ],
        ),
        const SizedBox(height: 5),
        DropdownButtonHideUnderline(
          child: DropdownButton2<String>(
            isExpanded: true,
            hint: const Text(
              'Select',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: AppColors.color555555,
                  fontFamily: fontFamilyMontserrat,
                 ),
            ),
            items: widget.items.map((item) {
              return DropdownMenuItem<String>(
                value: item,
                child: Text(
                  item,
                  style: const TextStyle(fontSize: 14),
                ),
              );
            }).toList(),
            value: selectedValue,
            onChanged: (value) {
              setState(() {
                selectedValue = value;
              });
              widget.onChanged(value);
            },
            dropdownStyleData: DropdownStyleData(
              maxHeight: 200,
              direction: DropdownDirection.textDirection,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Colors.white,
              ),
            ),

            buttonStyleData: ButtonStyleData(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(5),
                color: Colors.white,
              ),
            ),

            iconStyleData: const IconStyleData(
              icon: Icon(Icons.keyboard_arrow_down),
              openMenuIcon: Icon(Icons.keyboard_arrow_up),
              iconEnabledColor: AppColors.color555555,
            ),
          ),
        ),
      ],
    );
  }
}
// CustomDropdown(
// label: "Type",
// items: ["Battery", "DC"],
// initialValue: selectedType,
// onChanged: (value) {
// setState(() {
// selectedType = value;
// hasUnsavedChanges = true;
// });
// },
// ),