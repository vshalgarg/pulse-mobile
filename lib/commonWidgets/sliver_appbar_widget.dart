import 'package:flutter/material.dart';

class SliversAppBarWidget extends StatelessWidget {
  final Widget? title;
  final bool floating;
  final double? expandedHeight;
  final Widget? flexibleSpace;
  final bool snap;
  final bool pinned;

  const SliversAppBarWidget({
    this.title,
    this.floating = false,
    this.expandedHeight,
    this.flexibleSpace,
    this.snap = false,
    this.pinned = false,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      title: title,
      floating: floating,
      expandedHeight: expandedHeight,
      flexibleSpace: flexibleSpace,
      snap: snap,
      pinned: pinned,
    );
  }
}
