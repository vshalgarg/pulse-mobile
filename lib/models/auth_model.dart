import 'package:equatable/equatable.dart';
import '../utils.dart';

class AuthModel extends Equatable {
  final String token;
  final String? userId;
  final String? email;
  final String? firstName;
  final String? lastName;
  final DateTime? tokenExpiry;

  const AuthModel({
    required this.token,
    this.userId,
    this.email,
    this.firstName,
    this.lastName,
    this.tokenExpiry,
  });

  factory AuthModel.fromJson(Map<String, dynamic> json) {
    DateTime? tokenExpiry;
    if (json['token_expiry'] != null) {
      try {
        tokenExpiry = DateTime.parse(json['token_expiry']);
      } catch (e) {
        // If parsing fails, try to extract from JWT token
        final token = json['token'] ?? '';
        tokenExpiry = Utils.getTokenExpiration(token);
      }
    } else {
      // Extract expiry from JWT token if not provided
      final token = json['token'] ?? '';
      tokenExpiry = Utils.getTokenExpiration(token);
    }

    return AuthModel(
      token: json['token'] ?? '',
      userId: json['user_id'] ?? json['userId'],
      email: json['email'],
      firstName: json['first_name'] ?? json['firstName'],
      lastName: json['last_name'] ?? json['lastName'],
      tokenExpiry: tokenExpiry,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'token': token,
      'user_id': userId,
      'email': email,
      'first_name': firstName,
      'last_name': lastName,
      'token_expiry': tokenExpiry?.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [token, userId, email, firstName, lastName, tokenExpiry];
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
