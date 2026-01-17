import 'dart:ffi';

import 'package:app/enum/activity_type_enum.dart';

class ImageModel {

  final String uniqueId;
  final String? serverId;
  final String? imageData;
  final bool isSelfie;
  final ActivityTypeEnum activityType;
  final int createdAt;
  final String? schId;

  ImageModel({
    required this.uniqueId,
    this.serverId,
    this.imageData,
    this.isSelfie = false,
    required this.activityType,
    required this.createdAt,
    this.schId,
  });

}