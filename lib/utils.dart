import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

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
    return _formatDataTimeForApiCall(now);
  }

  static String? getTmeFromMSForAPICall(int? milliseconds) {
    if(milliseconds == null) return null;
    final now = DateTime.fromMillisecondsSinceEpoch(milliseconds);
    return _formatDataTimeForApiCall(now);
  }

  static String _formatDataTimeForApiCall(DateTime date) {
    final formatter = DateFormat("yyyy-MM-dd HH:mm:ss.SSS");
    return formatter.format(date);
  }

  static String formatDataForTicketCard(String date) {
    final dateTime = DateFormat("yyyy-MM-dd").parse(date);
    return DateFormat("dd-MMM-yy").format(dateTime);
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

  static Future<File?> buildImageFromBytesData(String byteData) async {
    try {
      String base64Data;
      
      // Handle both formats: "data:image/...,base64data" or raw base64
      if (byteData.startsWith('data:image/')) {
        // Remove data URL prefix
        final parts = byteData.split(',');
        if (parts.length == 2 && parts[1].isNotEmpty) {
          base64Data = parts[1];
        } else {
          print('Error: Invalid data URL format');
          return null;
        }
      } else {
        // Assume it's raw base64
        base64Data = byteData;
      }
      
      if (base64Data.isEmpty) {
        print('Error: Empty base64 data');
        return null;
      }
      
      final bytes = base64Decode(base64Data);

      // Get temporary directory
      final tempDir = await getTemporaryDirectory();
      
      // Create a unique filename
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'image_$timestamp.jpg';
      final file = File('${tempDir.path}/$fileName');
      
      // Write bytes to file
      await file.writeAsBytes(bytes);
      
      return file;
    } catch (e) {
      print('Error creating file from bytes data: $e');
    }
    return null;
  }
}
