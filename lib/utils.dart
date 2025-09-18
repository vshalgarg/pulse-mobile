import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher_string.dart';

import 'constants/app_colors.dart';
import 'constants/constants_methods.dart';
import 'models/device_info/device_info.dart';

import 'services/local_storage_db.dart';

class Utils {

  /// Convert current date time to ISO 8601 format with timezone offset
  /// Returns format: 2025-09-12T15:25:00.000+00:00
  static String getCurrentDateTimeForAPICall() {
    final now = DateTime.now();
    final formatter = DateFormat('dd-MM-yyyy HH:mm');
    return formatter.format(now);
  }

  static String? getTmeFromMSForAPICall(int? milliseconds) {
    if(milliseconds == null) return null;
    final now = DateTime.fromMillisecondsSinceEpoch(milliseconds);
    final formatter = DateFormat('dd-MM-yyyy HH:mm');
    return formatter.format(now);
  }

  // Check if JWT token is expired
  static bool isTokenExpired(String? token) {
    if (token == null || token.isEmpty) return true;
    
    try {
      final parts = token.split('.');
      if (parts.length != 3) return true;
      
      final payload = parts[1];
      final normalized = base64Url.normalize(payload);
      final resp = utf8.decode(base64Url.decode(normalized));
      final payloadMap = json.decode(resp);
      
      final exp = payloadMap['exp'];
      if (exp == null) return true;
      
      final expiry = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
      final now = DateTime.now();
      
      return now.isAfter(expiry);
    } catch (e) {
      print('Error checking token expiration: $e');
      return true;
    }
  }

  // Get token expiration time
  static DateTime? getTokenExpiration(String? token) {
    if (token == null || token.isEmpty) return null;
    
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      
      final payload = parts[1];
      final normalized = base64Url.normalize(payload);
      final resp = utf8.decode(base64Url.decode(normalized));
      final payloadMap = json.decode(resp);
      
      final exp = payloadMap['exp'];
      if (exp == null) return null;
      
      return DateTime.fromMillisecondsSinceEpoch(exp * 1000);
    } catch (e) {
      print('Error getting token expiration: $e');
      return null;
    }
  }
}
