import 'package:flutter/material.dart';

class RadioListTileWidget extends StatelessWidget {
  final int value;
  final int? groupValue;
  final String? title;
  final void Function(int?)? onChanged;

  const RadioListTileWidget({
    required this.value,
    required this.groupValue,
    this.title,
    this.onChanged,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return RadioListTile<int>(
      value: value,
      contentPadding: const EdgeInsets.all(0),
      groupValue: groupValue,
      visualDensity:
          const VisualDensity(horizontal: VisualDensity.minimumDensity, vertical: VisualDensity.minimumDensity),
      title: Text('$title'),
      onChanged: onChanged,
      controlAffinity: ListTileControlAffinity.leading,
    );
  }
}
