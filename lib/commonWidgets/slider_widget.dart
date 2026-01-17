import 'package:flutter/material.dart';

class SliderWidget extends StatefulWidget {
  Function(int) range;

  SliderWidget(this.range);

  @override
  State<SliderWidget> createState() => _SliderWidgetState();
}

class _SliderWidgetState extends State<SliderWidget> {
  double rangeSliderValue = 0;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.remove_circle_outline),
        Expanded(
          child: Slider(
            value: rangeSliderValue,
            activeColor: changeActiveColor(rangeSliderValue.toInt()),
            inactiveColor: changeInActiveColor(rangeSliderValue.toInt()),
            thumbColor: changeActiveColor(rangeSliderValue.toInt()),
            onChanged: (value) {
              setState(() {
                rangeSliderValue = value;
                widget.range(rangeSliderValue.toInt());
              });
            },
            min: 0,
            max: 10,
            divisions: 10,
            label: rangeSliderValue.toInt().toString(),
          ),
        ),
        const Icon(Icons.add_circle_outline),
      ],
    );
  }

  Color changeActiveColor(int range) {
    if (range < 4) {
      return Colors.red;
    } else if (range < 8) {
      return Colors.yellow;
    }
    return Colors.green;
  }

  Color changeInActiveColor(int range) {
    if (range < 4) {
      return Colors.red.shade200;
    } else if (range < 8) {
      return Colors.yellow.shade200;
    }
    return Colors.green.shade200;
  }
}
