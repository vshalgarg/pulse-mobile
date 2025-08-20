

import 'package:flutter/material.dart';

import '../commonWidgets/custom_radio_options.dart';

enum FieldType { textField, dropdown, serial, upload, optionSelector }

class FieldConfig {
  final FieldType type;
  final String label;
  final String? initialValue;
  final bool isRequired;
  final bool isEditable;
  final List<String>? items; // For dropdown
  final List<OptionItem>? options; // For selector
  final TextEditingController? controller;

  FieldConfig({
    required this.type,
    required this.label,
    this.initialValue,
    this.isRequired = false,
    this.isEditable = true,
    this.items,
    this.options,
    this.controller,
  });
}
