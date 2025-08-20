import 'package:equatable/equatable.dart';

class AuthModel extends Equatable {
  final String token;
  final String? userId;
  final String? email;
  final String? firstName;
  final String? lastName;

  const AuthModel({
    required this.token,
    this.userId,
    this.email,
    this.firstName,
    this.lastName,
  });

  factory AuthModel.fromJson(Map<String, dynamic> json) {
    return AuthModel(
      token: json['token'] ?? '',
      userId: json['user_id'] ?? json['userId'],
      email: json['email'],
      firstName: json['first_name'] ?? json['firstName'],
      lastName: json['last_name'] ?? json['lastName'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'token': token,
      'user_id': userId,
      'email': email,
      'first_name': firstName,
      'last_name': lastName,
    };
  }

  @override
  List<Object?> get props => [token, userId, email, firstName, lastName];
}

class LoginRequestModel {
  final String username; // Changed from email to username for mobile number
  final String password;

  LoginRequestModel({
    required this.username,
    required this.password,
  });

  Map<String, dynamic> toJson() {
    return {
      'username': username, // API expects username field
      'password': password,
    };
  }
}
