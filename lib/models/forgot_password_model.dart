import 'package:equatable/equatable.dart';

class ForgotPasswordModel extends Equatable {
  final String message;
  final bool success;

  const ForgotPasswordModel({
    required this.message,
    required this.success,
  });

  factory ForgotPasswordModel.fromJson(Map<String, dynamic> json) {
    return ForgotPasswordModel(
      message: json['message'] ?? '',
      success: true,
    );
  }

  factory ForgotPasswordModel.fromString(String message) {
    return ForgotPasswordModel(
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

class ForgotPasswordRequestModel {
  final String emailId;

  ForgotPasswordRequestModel({
    required this.emailId,
  });

  Map<String, dynamic> toJson() {
    return {
      'emailId': emailId,
    };
  }
}

