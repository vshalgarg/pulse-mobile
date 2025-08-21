import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';

import '../models/auth_model.dart';
import '../models/forgot_password_model.dart';
import '../models/otp_verification_model.dart';
import '../models/reset_password_model.dart';
import '../services/api_service.dart';

class AuthRepository {
  final ApiService _apiService;

  AuthRepository(this._apiService);

  Future<ResponseResult<AuthModel>> login({
    required String username,
    required String password,
  }) async {
    try {
      print("AuthRepository: Attempting login for username: $username");
      
      final response = await _apiService.post<Map<String, dynamic>>(
        path: 'authenticate/login',
        data: {
          'username': username,
          'password': password,
        },
      );

      print("AuthRepository: Login response - isSuccess: ${response.isSuccess}, statusCode: ${response.statusCode}");
      print("AuthRepository: Login response data: ${response.data}");
      print("AuthRepository: Login error message: ${response.errorMessage}");

      if (response.isSuccess && response.data != null) {
        final authModel = AuthModel.fromJson(response.data!);
        print("AuthRepository: Login successful - token: ${authModel.token?.substring(0, 20)}...");
        return ResponseResult.success(authModel, response.statusCode);
      } else {
        String errorMessage = 'Login failed';
        if (response.errorMessage != null) {
          if (response.errorMessage!.contains('timeout')) {
            errorMessage = 'Login request timed out. Please check your connection and try again.';
          } else if (response.errorMessage!.contains('connection')) {
            errorMessage = 'Unable to connect to server. Please check your internet connection.';
          } else if (response.errorMessage!.contains('401')) {
            errorMessage = 'Invalid username or password. Please try again.';
          } else {
            errorMessage = response.errorMessage!;
          }
        }
        return ResponseResult.error(
          errorMessage: errorMessage,
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      print("AuthRepository: Login exception - $e");
      String errorMessage = 'Login failed';
      
      if (e.toString().contains('timeout')) {
        errorMessage = 'Login request timed out. Please check your connection and try again.';
      } else if (e.toString().contains('connection')) {
        errorMessage = 'Unable to connect to server. Please check your internet connection.';
      } else if (e.toString().contains('SocketException')) {
        errorMessage = 'No internet connection. Please check your network and try again.';
      } else {
        errorMessage = 'Login failed. Please try again.';
      }
      
      return ResponseResult.error(
        errorMessage: errorMessage,
      );
    }
  }

  // Forgot Password API
  Future<ResponseResult<ForgotPasswordModel?>> forgotPassword({
    required String email,
  }) async {
    try {
      final result = await _apiService.post<dynamic>(
        path: "authenticate/generateOtp",
        queryParameters: {
          'emailId': email,
        },
      );

      print("API Response: ${result.data}");
      print("Is Success: ${result.isSuccess}");
      print("Status Code: ${result.statusCode}");
      print("Error Message: ${result.errorMessage}");

      // Check if status code is 200 for success
      if (result.isSuccess && result.data != null) {
        print("Forgot password successful: ${result.data}");
        
        ForgotPasswordModel forgotPasswordModel;
        
        if (result.data is Map<String, dynamic>) {
          print("Processing as JSON response with message field");
          forgotPasswordModel = ForgotPasswordModel.fromJson(result.data);
        } else if (result.data is String) {
          print("Processing as String response");
          forgotPasswordModel = ForgotPasswordModel.fromString(result.data);
        } else {
          print("Processing as fallback response");
          forgotPasswordModel = ForgotPasswordModel.fromString("OTP sent successfully");
        }
        
        print("Created model: ${forgotPasswordModel.message}");
        return ResponseResult.success(forgotPasswordModel, result.statusCode);
      } else {
        String errorMessage = 'Failed to send OTP';
        if (result.errorMessage != null) {
          if (result.errorMessage!.contains('503')) {
            errorMessage = 'Service temporarily unavailable. Please try again later.';
          } else if (result.errorMessage!.contains('500')) {
            errorMessage = 'Server error. Please try again later.';
          } else {
            errorMessage = result.errorMessage!;
          }
        }
        return ResponseResult.error(errorMessage: errorMessage);
      }
    } catch (e) {
      print("Forgot password error: $e");
      String errorMessage = 'We could not process your forgot password request';
      
      if (e.toString().contains('503')) {
        errorMessage = 'Service temporarily unavailable. Please try again later.';
      } else if (e.toString().contains('500')) {
        errorMessage = 'Server error. Please try again later.';
      } else if (e.toString().contains('timeout')) {
        errorMessage = 'Request timed out. Please check your connection and try again.';
      }
      
      return ResponseResult.error(errorMessage: errorMessage);
    }
  }

  // Verify OTP API
  Future<ResponseResult<OtpVerificationModel?>> verifyOtp({
    required String emailId,
    required String otp,
  }) async {
    try {
      final result = await _apiService.post<dynamic>(
        path: "authenticate/verifyOtp",
        queryParameters: {
          'emailId': emailId,
          'otp': otp,
        },
      );

      print("OTP Verification API Response: ${result.data}");
      print("OTP Verification Is Success: ${result.isSuccess}");
      print("OTP Verification Status Code: ${result.statusCode}");
      print("OTP Verification Error Message: ${result.errorMessage}");

      // Check if status code is 200 for success
      if (result.isSuccess && result.data != null) {
        print("OTP verification successful: ${result.data}");
        
        OtpVerificationModel otpVerificationModel;
        
        if (result.data is Map<String, dynamic>) {
          print("Processing OTP verification as JSON response");
          otpVerificationModel = OtpVerificationModel.fromJson(result.data);
        } else if (result.data is String) {
          print("Processing OTP verification as String response");
          otpVerificationModel = OtpVerificationModel.fromString(result.data);
        } else {
          print("Processing OTP verification as fallback response");
          otpVerificationModel = OtpVerificationModel.fromString("OTP verified successfully");
        }
        
        print("Created OTP verification model: ${otpVerificationModel.message}");
        return ResponseResult.success(otpVerificationModel, result.statusCode);
      } else {
        String errorMessage = 'Failed to verify OTP';
        if (result.errorMessage != null) {
          if (result.errorMessage!.contains('503')) {
            errorMessage = 'Service temporarily unavailable. Please try again later.';
          } else if (result.errorMessage!.contains('500')) {
            errorMessage = 'Server error. Please try again later.';
          } else if (result.errorMessage!.contains('timeout')) {
            errorMessage = 'Request timed out. Please check your connection and try again.';
          } else {
            errorMessage = result.errorMessage!;
          }
        }
        return ResponseResult.error(errorMessage: errorMessage);
      }
    } catch (e) {
      print("OTP verification error: $e");
      String errorMessage = 'We could not process your OTP verification request';
      
      if (e.toString().contains('503')) {
        errorMessage = 'Service temporarily unavailable. Please try again later.';
      } else if (e.toString().contains('500')) {
        errorMessage = 'Server error. Please try again later.';
      } else if (e.toString().contains('timeout')) {
        errorMessage = 'Request timed out. Please check your connection and try again.';
      }
      
      return ResponseResult.error(errorMessage: errorMessage);
    }
  }

  // Resend OTP API
  Future<ResponseResult<ForgotPasswordModel?>> resendOtp({
    required String emailId,
  }) async {
    try {
      final result = await _apiService.post<dynamic>(
        path: "authenticate/generateOtp",
        queryParameters: {
          'emailId': emailId,
        },
      );

      print("Resend OTP API Response: ${result.data}");
      print("Resend OTP Is Success: ${result.isSuccess}");
      print("Resend OTP Status Code: ${result.statusCode}");
      print("Resend OTP Error Message: ${result.errorMessage}");

      // Check if status code is 200 for success
      if (result.isSuccess && result.data != null) {
        print("Resend OTP successful: ${result.data}");
        
        ForgotPasswordModel forgotPasswordModel;
        
        if (result.data is Map<String, dynamic>) {
          print("Processing resend OTP as JSON response");
          forgotPasswordModel = ForgotPasswordModel.fromJson(result.data);
        } else if (result.data is String) {
          print("Processing resend OTP as String response");
          forgotPasswordModel = ForgotPasswordModel.fromString(result.data);
        } else {
          print("Processing resend OTP as fallback response");
          forgotPasswordModel = ForgotPasswordModel.fromString("OTP resent successfully");
        }
        
        print("Created resend OTP model: ${forgotPasswordModel.message}");
        return ResponseResult.success(forgotPasswordModel, result.statusCode);
      } else {
        String errorMessage = 'Failed to resend OTP';
        if (result.errorMessage != null) {
          if (result.errorMessage!.contains('503')) {
            errorMessage = 'Service temporarily unavailable. Please try again later.';
          } else if (result.errorMessage!.contains('500')) {
            errorMessage = 'Server error. Please try again later.';
          } else if (result.errorMessage!.contains('timeout')) {
            errorMessage = 'Request timed out. Please check your connection and try again.';
          } else {
            errorMessage = result.errorMessage!;
          }
        }
        return ResponseResult.error(errorMessage: errorMessage);
      }
    } catch (e) {
      print("Resend OTP error: $e");
      String errorMessage = 'We could not process your resend OTP request';
      
      if (e.toString().contains('503')) {
        errorMessage = 'Service temporarily unavailable. Please try again later.';
      } else if (e.toString().contains('500')) {
        errorMessage = 'Server error. Please try again later.';
      } else if (e.toString().contains('timeout')) {
        errorMessage = 'Request timed out. Please check your connection and try again.';
      }
      
      return ResponseResult.error(errorMessage: errorMessage);
    }
  }

  // Reset Password API
  Future<ResponseResult<ResetPasswordModel?>> resetPassword({
    required String emailId,
    required String newPassword,
  }) async {
    try {
      final result = await _apiService.post<dynamic>(
        path: "authenticate/changePassword",
        queryParameters: {
          'emailId': emailId,
          'newPassword': newPassword,
        },
      );

      print("Reset Password API Response: ${result.data}");
      print("Reset Password Is Success: ${result.isSuccess}");
      print("Reset Password Status Code: ${result.statusCode}");
      print("Reset Password Error Message: ${result.errorMessage}");

      // Check if status code is 200 for success
      if (result.isSuccess && result.data != null) {
        print("Reset password successful: ${result.data}");
        
        ResetPasswordModel resetPasswordModel;
        
        if (result.data is Map<String, dynamic>) {
          print("Processing reset password as JSON response");
          resetPasswordModel = ResetPasswordModel.fromJson(result.data);
        } else if (result.data is String) {
          print("Processing reset password as String response");
          resetPasswordModel = ResetPasswordModel.fromString(result.data);
        } else {
          print("Processing reset password as fallback response");
          resetPasswordModel = ResetPasswordModel.fromString("Password changed successfully");
        }
        
        print("Created reset password model: ${resetPasswordModel.message}");
        return ResponseResult.success(resetPasswordModel, result.statusCode);
      } else {
        String errorMessage = 'Failed to reset password';
        if (result.errorMessage != null) {
          if (result.errorMessage!.contains('503')) {
            errorMessage = 'Service temporarily unavailable. Please try again later.';
          } else if (result.errorMessage!.contains('500')) {
            errorMessage = 'Server error. Please try again later.';
          } else if (result.errorMessage!.contains('timeout')) {
            errorMessage = 'Request timed out. Please check your connection and try again.';
          } else {
            errorMessage = result.errorMessage!;
          }
        }
        return ResponseResult.error(errorMessage: errorMessage);
      }
    } catch (e) {
      print("Reset password error: $e");
      String errorMessage = 'We could not process your reset password request';
      
      if (e.toString().contains('503')) {
        errorMessage = 'Service temporarily unavailable. Please try again later.';
      } else if (e.toString().contains('500')) {
        errorMessage = 'Server error. Please try again later.';
      } else if (e.toString().contains('timeout')) {
        errorMessage = 'Request timed out. Please check your connection and try again.';
      }
      
      return ResponseResult.error(errorMessage: errorMessage);
    }
  }
}

class ResponseResult<T> extends Equatable {
  final bool isSuccess;
  final T? data;
  final String? errorMessage;
  final int? statusCode;
  final DioExceptionType? dioErrorType;

  const ResponseResult._({
    required this.isSuccess,
    this.data,
    this.errorMessage,
    this.statusCode,
    this.dioErrorType,
  });

  factory ResponseResult.success(T data, [int? statusCode]) {
    return ResponseResult._(
      isSuccess: true,
      data: data,
      statusCode: statusCode,
    );
  }

  factory ResponseResult.error({
    String? errorMessage,
    int? statusCode,
    DioExceptionType? dioErrorType,
  }) {
    return ResponseResult._(
      isSuccess: false,
      errorMessage: errorMessage,
      statusCode: statusCode,
      dioErrorType: dioErrorType,
    );
  }

  @override
  List<Object?> get props => [isSuccess, data, errorMessage, statusCode, dioErrorType];
}
