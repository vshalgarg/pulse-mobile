import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

class CustomAlignedGridViewComponent extends AlignedGridView {
  CustomAlignedGridViewComponent({
    super.key,
    required super.crossAxisCount,
    required super.itemCount,
    required super.itemBuilder,
    required super.padding,
    final double mainAxisSpacing = 0.0,
    final double crossAxisSpacing = 0.0,
    final ScrollController? scrollController,
    final Axis scrollDirection = Axis.vertical,
    final ScrollPhysics? physics,
  }) : super.count(
          shrinkWrap: true,
          mainAxisSpacing: mainAxisSpacing,
          crossAxisSpacing: crossAxisSpacing,
          controller: scrollController,
          scrollDirection: scrollDirection,
          physics: physics,
        );
}
