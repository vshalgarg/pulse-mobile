import 'package:app/commonWidgets/custom_radio_options.dart';
import 'package:flutter/material.dart';

class WidgetHelper {
  static Widget buildDisabledRadioField({
    required String label,
    required bool isRequired,
    required String initialSelectedValue,
  }) {
    return CustomOptionSelector(
      label: label,
      isRequired: isRequired,
      options: [
        OptionItem(
          value: 'Yes',
          label: 'Yes',
          selectedIcon: Icons.radio_button_checked,
          unselectedIcon: Icons.radio_button_unchecked,
        ),
        OptionItem(
          value: 'No',
          label: 'No',
          selectedIcon: Icons.radio_button_checked,
          unselectedIcon: Icons.radio_button_unchecked,
        ),
      ],
      initialValue: initialSelectedValue,
      onChanged: null,
    );
  }

  static Widget buildRadioField({
    String? label,
    required bool isRequired,
    required String initialSelectedValue,
    required Function(String value) onChanged
  }) {
    return CustomOptionSelector(
      label: label,
      isRequired: isRequired,
      options: [
        OptionItem(
          value: 'Yes',
          label: 'Yes',
          selectedIcon: Icons.radio_button_checked,
          unselectedIcon: Icons.radio_button_unchecked,
        ),
        OptionItem(
          value: 'No',
          label: 'No',
          selectedIcon: Icons.radio_button_checked,
          unselectedIcon: Icons.radio_button_unchecked,
        ),
      ],
      initialValue: initialSelectedValue,
      onChanged: onChanged,
    );
  }
}