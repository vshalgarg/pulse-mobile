import 'package:flutter/material.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import '../constants/app_colors.dart';
import '../constants/constants_strings.dart';

class GenericDropdown<T> extends StatefulWidget {
  final String? label;
  final List<T> items;
  final T? initialValue;
  final ValueChanged<T?> onChanged;
  final bool isRequired;
  final String Function(T)? displayText;
  final String? hintText;

  const GenericDropdown({
    super.key,
    this.label,
    required this.items,
    this.initialValue,
    required this.onChanged,
    this.isRequired = false,
    this.displayText,
    this.hintText = 'Select',
  });

  @override
  State<GenericDropdown<T>> createState() => _GenericDropdownState<T>();
}

class _GenericDropdownState<T> extends State<GenericDropdown<T>> {
  T? selectedValue;

  @override
  void initState() {
    super.initState();
    print('🔄 [GenericDropdown] Initializing dropdown widget');
    print('🔄 [GenericDropdown] Items count: ${widget.items.length}');
    print('🔄 [GenericDropdown] Initial value: ${widget.initialValue}');
    print('🔄 [GenericDropdown] Hint text: ${widget.hintText}');
    
    if (widget.initialValue != null && widget.items.contains(widget.initialValue)) {
      selectedValue = widget.initialValue;
      print('✅ [GenericDropdown] Set initial value: $selectedValue');
    } else {
      print('⚠️ [GenericDropdown] Initial value not found in items or is null');
    }
  }

  @override
  void didUpdateWidget(GenericDropdown<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    print('🔄 [GenericDropdown] Widget updated');
    print('🔄 [GenericDropdown] Old items count: ${oldWidget.items.length}');
    print('🔄 [GenericDropdown] New items count: ${widget.items.length}');
    print('🔄 [GenericDropdown] New initial value: ${widget.initialValue}');
    
    if (widget.initialValue != null && widget.items.contains(widget.initialValue)) {
      selectedValue = widget.initialValue;
      print('✅ [GenericDropdown] Updated selected value: $selectedValue');
    } else {
      selectedValue = null;
      print('⚠️ [GenericDropdown] Cleared selected value (not found in items or null)');
    }
  }

  String _getDisplayText(T item) {
    if (widget.displayText != null) {
      final displayText = widget.displayText!(item);
      print('🔄 [GenericDropdown] Display text for item $item: $displayText');
      return displayText;
    }
    final toString = item.toString();
    print('🔄 [GenericDropdown] Using toString for item $item: $toString');
    return toString;
  }

  @override
  Widget build(BuildContext context) {
    print('🔄 [GenericDropdown] Building dropdown widget');
    print('🔄 [GenericDropdown] Items count: ${widget.items.length}');
    print('🔄 [GenericDropdown] Selected value: $selectedValue');
    print('🔄 [GenericDropdown] Label: ${widget.label}');
    print('🔄 [GenericDropdown] Is required: ${widget.isRequired}');
    
    // Log first few items for debugging
    if (widget.items.isNotEmpty) {
      print('🔄 [GenericDropdown] First 3 items:');
      for (int i = 0; i < widget.items.length && i < 3; i++) {
        final item = widget.items[i];
        final displayText = _getDisplayText(item);
        print('   ${i + 1}. $item -> "$displayText"');
      }
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: RichText(
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
                      text: " *",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.red,
                        fontFamily: fontFamilyMontserrat,
                      ),
                    ),
                ],
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
        const SizedBox(height: 3),
        if (widget.items.isNotEmpty)
          Container(
            width: double.infinity,
            child: DropdownButtonHideUnderline(
              child: DropdownButton2<T>(
                isExpanded: true,
                hint: Text(
                  widget.hintText!,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    color: AppColors.color555555,
                    fontFamily: fontFamilyMontserrat,
                  ),
                ),
                items: widget.items.map((item) {
                  final displayText = _getDisplayText(item);
                  print('🔄 [GenericDropdown] Creating dropdown item: $item -> "$displayText"');
                  return DropdownMenuItem<T>(
                    value: item,
                    child: Text(
                      displayText,
                      style: const TextStyle(fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                value: selectedValue,
                onChanged: (value) {
                  print('🎯 [GenericDropdown] User selected: $value');
                  setState(() {
                    selectedValue = value;
                  });
                  widget.onChanged(value);
                },
                dropdownStyleData: DropdownStyleData(
                  maxHeight: 150,
                  direction: DropdownDirection.textDirection,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    color: Colors.white,
                  ),
                ),
                buttonStyleData: ButtonStyleData(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(6),
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 2,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                ),
                iconStyleData: const IconStyleData(
                  icon: Icon(Icons.keyboard_arrow_down),
                  openMenuIcon: Icon(Icons.keyboard_arrow_up),
                  iconEnabledColor: AppColors.color555555,
                ),
              ),
            ),
          )
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(6),
              color: Colors.grey.shade100,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.lock_outline,
                  size: 16,
                  color: Colors.grey.shade600,
                ),
                const SizedBox(width: 8),
                Text(
                  'Field disabled',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}