import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';


class Base64ImageWidget extends StatelessWidget {
  final String base64Data;
  final double? height;
  final double? width;
  final BoxFit? boxFit;
  final Widget? placeholder;
  final Widget? errorWidget;

  const Base64ImageWidget({
    Key? key,
    required this.base64Data,
    this.height,
    this.width,
    this.boxFit,
    this.placeholder,
    this.errorWidget,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: _decodeBase64(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildPlaceholder();
        }
        
        if (snapshot.hasError || snapshot.data == null) {
          return _buildErrorWidget();
        }
        
        return Image.memory(
          snapshot.data!,
          height: height,
          width: width,
          fit: boxFit ?? BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _buildErrorWidget();
          },
        );
      },
    );
  }

  Future<Uint8List?> _decodeBase64() async {
    try {
      // Remove data:image/jpg;base64, prefix if present
      final cleanBase64 = base64Data.contains(',') 
          ? base64Data.split(',').last 
          : base64Data;
      
      return Uint8List.fromList(base64.decode(cleanBase64));
    } catch (e) {
      debugPrint('Error decoding base64 image: $e');
      return null;
    }
  }

  Widget _buildPlaceholder() {
    return placeholder ?? Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Center(
        child: Icon(
          Icons.image,
          color: Colors.grey,
          size: 24,
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return errorWidget ?? Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Center(
        child: Icon(
          Icons.broken_image,
          color: Colors.grey,
          size: 24,
        ),
      ),
    );
  }
}
