import 'dart:io';

import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../constants/constants_methods.dart';

class CustomImagePicker {
  CustomImagePicker._();

  // pick image
  static Future<File?> pickImage({
    required ImageSource source,
    CameraDevice preferredCameraDevice = CameraDevice.front,
  }) async {
    try {
      final image = await ImagePicker().pickImage(
        source: source,
        preferredCameraDevice: preferredCameraDevice,
      );

      if (image == null) return null;

      final tempImage = File(image.path);
      return tempImage;
    } on PlatformException catch (e) {
      kDebugPrint(e.message);
      return null;
    }
  }
}
