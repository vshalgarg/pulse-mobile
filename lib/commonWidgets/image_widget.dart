
import 'dart:io';

import 'package:flutter/material.dart';

import '../constants/constants_methods.dart';
import '../enum/image_type_enum.dart';
import 'safe_file_image.dart';

class ImageWidget extends StatelessWidget {
  final ImageTypeEnum? imageType;
  final String? imagePath;
  final double? height;
  final double? width;
  final BoxFit? boxFit;

  const ImageWidget({Key? key, this.imageType, this.imagePath, this.height, this.width, this.boxFit}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return imageWidget(imageType ?? ImageTypeEnum.asset);
  }

  imageWidget(ImageTypeEnum imageType) {
    switch (imageType.name) {
      case 'asset':
        return Image.asset(
          '${assetImagePathIcons}$imagePath',
          height: height,
          width: width,
          fit: boxFit ?? BoxFit.scaleDown,
          errorBuilder: (context, error, stackTrace) =>
              const Icon(Icons.broken_image_outlined),
        );
      case 'network':
        return Image.network(
          '$imagePath',
          height: height,
          width: width,
          fit: boxFit ?? BoxFit.scaleDown,
          errorBuilder: (context, error, stackTrace) =>
              const Icon(Icons.broken_image_outlined),
        );
      case 'file':
        return SafeImageFile(
          file: File(imagePath ?? ''),
          height: height,
          width: width,
          fit: boxFit ?? BoxFit.scaleDown,
        );
      default:
        return Image.asset(
          '$assetImagePathIcons$imagePath',
          height: height,
          width: width,
          fit: boxFit ?? BoxFit.scaleDown,
          errorBuilder: (context, error, stackTrace) =>
              const Icon(Icons.broken_image_outlined),
        );
    }
  }
}
