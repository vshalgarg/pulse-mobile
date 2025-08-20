import 'package:equatable/equatable.dart';

class OtpVerificationModel extends Equatable {
  final String message;
  final bool success;

  const OtpVerificationModel({
    required this.message,
    required this.success,
  });

  factory OtpVerificationModel.fromJson(Map<String, dynamic> json) {
    return OtpVerificationModel(
      message: json['message'] ?? '',
      success: true,
    );
  }

  factory OtpVerificationModel.fromString(String message) {
    return OtpVerificationModel(
      message: message,
      success: true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'message': message,
      'success': success,
    };
  }

  @override
  List<Object?> get props => [message, success];
}

class OtpVerificationRequestModel {
  final String emailId;
  final String otp;

  OtpVerificationRequestModel({
    required this.emailId,
    required this.otp,
  });

  Map<String, dynamic> toJson() {
    return {
      'emailId': emailId,
      'otp': otp,
    };
  }
}
