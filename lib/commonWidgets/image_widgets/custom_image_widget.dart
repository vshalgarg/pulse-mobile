import 'dart:io';

import 'package:flutter/material.dart';

import '../../constants/constants_methods.dart';
import '../../enum/image_type_enum.dart';

class CustomImageWidget extends StatelessWidget {
  final ImageTypeEnum imageType;
  final String imagePath;
  final double? height;
  final double? width;
  final BoxFit? boxFit;

  const CustomImageWidget({
    Key? key,
    this.imageType = ImageTypeEnum.asset,
    required this.imagePath,
    this.height,
    this.width,
    this.boxFit,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return imageWidget(imageType);
  }

  imageWidget(ImageTypeEnum imageType) {
    switch (imageType.name) {
      case 'asset':
        return Image.asset(
          '$assetImagePathIcons$imagePath',
          height: height,
          width: width,
          fit: boxFit ?? BoxFit.scaleDown,
          errorBuilder: (context, error, stackTrace) {
            return Image(image: getPlaceholder, height: height, width: width);
          },
        );
      case 'network':
        return Image.network(
          imagePath,
          height: height,
          width: width,
          fit: boxFit ?? BoxFit.scaleDown,
          errorBuilder: (context, error, stackTrace) {
            return Image(image: getPlaceholder, height: height, width: width);
          },
        );
      case 'networkWithFadeInImage':
        return FadeInImage(
          placeholder: getPlaceholder,
          image: Image.network(imagePath).image,
          height: height,
          width: width,
          fit: boxFit ?? BoxFit.scaleDown,
          imageErrorBuilder: (context, error, stackTrace) {
            return Image(image: getPlaceholder, height: height, width: width);
          },
        );
      case 'file':
        return Image.file(
          File(imagePath ?? ''),
          height: height,
          width: width,
          fit: boxFit ?? BoxFit.scaleDown,
          errorBuilder: (context, error, stackTrace) {
            return Image(image: getPlaceholder, height: height, width: width);
          },
        );
      default:
        return Image.asset(
          '$assetImagePathIcons$imagePath',
          height: height,
          width: width,
          fit: boxFit ?? BoxFit.scaleDown,
          errorBuilder: (context, error, stackTrace) {
            return Image(image: getPlaceholder, height: height, width: width);
          },
        );
    }
  }
}
