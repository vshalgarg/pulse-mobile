import 'package:flutter/material.dart';

class InkWellWidget extends InkWell {
  final GestureTapCallback? onClicked;

  const InkWellWidget({super.key, this.onClicked, super.child})
      : super(
          onTap: onClicked,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
        );
}
