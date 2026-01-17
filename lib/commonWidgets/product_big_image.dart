import 'package:flutter/material.dart';

class ProductBigImage extends StatelessWidget {
  final String imageUrl;

  ProductBigImage({required this.imageUrl, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: 'image',
      child: Image(
        image: NetworkImage(imageUrl),
      ),
    );
  }
}
