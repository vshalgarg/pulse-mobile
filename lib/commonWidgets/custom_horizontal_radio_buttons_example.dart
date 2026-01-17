import 'package:flutter/material.dart';
import 'custom_horizontal_radio_buttons.dart';
import '../constants/app_colors.dart';

/// Example usage of CustomHorizontalRadioButtons widget
/// This file demonstrates how to use the horizontal radio buttons widget
class CustomHorizontalRadioButtonsExample extends StatefulWidget {
  const CustomHorizontalRadioButtonsExample({super.key});

  @override
  State<CustomHorizontalRadioButtonsExample> createState() => _CustomHorizontalRadioButtonsExampleState();
}

class _CustomHorizontalRadioButtonsExampleState extends State<CustomHorizontalRadioButtonsExample> {
  String? selectedValue;

  // Example options array in the format [{label: "label", value: "value"}]
  final List<RadioOption> options = [
    const RadioOption(label: "Option 1", value: "option1"),
    const RadioOption(label: "Option 2", value: "option2"),
    const RadioOption(label: "Option 3", value: "option3"),
    const RadioOption(label: "Very Long Option Name", value: "option4"),
    const RadioOption(label: "Another Option", value: "option5"),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Horizontal Radio Buttons Example'),
        backgroundColor: AppColors.primaryGreen,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Horizontal Radio Buttons Demo',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            
            // Basic usage
            const Text(
              'Basic Usage:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            CustomHorizontalRadioButtons(
              options: options,
              selectedValue: selectedValue,
              onButtonSelected: (value) {
                setState(() {
                  selectedValue = value;
                });

              },
            ),
            
            const SizedBox(height: 30),
            
            // Custom styling
            const Text(
              'Custom Styling:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            CustomHorizontalRadioButtons(
              options: options,
              selectedValue: selectedValue,
              onButtonSelected: (value) {
                setState(() {
                  selectedValue = value;
                });
              },
              activeColor: AppColors.redColor,
              inactiveColor: AppColors.greyColor,
              textColor: AppColors.baseColorsHeadings,
              fontSize: 14.0,
              fontWeight: FontWeight.w500,
              spacing: 24.0,
            ),
            
            const SizedBox(height: 30),
            
            // Selected value display
            if (selectedValue != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.lightGreen,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Selected: $selectedValue',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.green0,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
