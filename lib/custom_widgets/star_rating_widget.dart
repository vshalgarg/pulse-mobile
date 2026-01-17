import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

typedef void RatingChangeCallback(double rating);

class StarRating extends StatelessWidget {
  final int starCount;
  final double rating;
  final RatingChangeCallback? onRatingChanged;
  final Color? color;
  final double iconSize;

  StarRating({super.key, this.starCount = 5, this.rating = 2.5, this.onRatingChanged, this.color, this.iconSize = 15});

  Widget buildStar(BuildContext context, int index) {
    Icon icon;
    if (index >= rating) {
      icon = Icon(
        Icons.star_border,
        color: color ?? AppColors.blackColor,
        size: iconSize,
      );
    } else if (index > rating - 1 && index < rating) {
      icon = Icon(
        Icons.star_half,
        color: color ?? AppColors.blackColor,
        size: iconSize,
      );
    } else {
      icon = Icon(
        Icons.star,
        color: color ?? AppColors.blackColor,
        size: iconSize,
      );
    }
    return InkResponse(
      onTap: onRatingChanged == null ? null : () => onRatingChanged!(index + 1.0),
      child: icon,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(children: List.generate(starCount, (index) => buildStar(context, index)));
  }
}
