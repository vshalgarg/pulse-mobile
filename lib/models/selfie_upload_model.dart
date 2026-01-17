import 'package:equatable/equatable.dart';

class SelfieUploadResponse extends Equatable {
  final String fileName;
  final String message;
  final String imgId;
  final String status;

  const SelfieUploadResponse({
    required this.fileName,
    required this.message,
    required this.imgId,
    required this.status,
  });

  factory SelfieUploadResponse.fromJson(Map<String, dynamic> json) {
    return SelfieUploadResponse(
      fileName: json['fileName'] ?? '',
      message: json['message'] ?? '',
      imgId: json['imgId']?.toString() ?? '',
      status: json['status'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'fileName': fileName,
      'message': message,
      'imgId': imgId,
      'status': status,
    };
  }

  @override
  List<Object?> get props => [fileName, message, imgId, status];
}
