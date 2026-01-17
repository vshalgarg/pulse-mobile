import 'package:equatable/equatable.dart';

class ResetPasswordModel extends Equatable {
  final String message;
  final bool success;

  const ResetPasswordModel({
    required this.message,
    required this.success,
  });

  factory ResetPasswordModel.fromJson(Map<String, dynamic> json) {
    return ResetPasswordModel(
      message: json['message'] ?? '',
      success: true,
    );
  }

  factory ResetPasswordModel.fromString(String message) {
    return ResetPasswordModel(
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

class ResetPasswordRequestModel {
  final String emailId;
  final String newPassword;

  ResetPasswordRequestModel({
    required this.emailId,
    required this.newPassword,
  });

  Map<String, dynamic> toJson() {
    return {
      'emailId': emailId,
      'newPassword': newPassword,
    };
  }
}
