import 'dart:convert';
import 'package:flutter/foundation.dart';

class JsonPrinter {
  /// Prints JSON data in a copyable format
  static void printCopyable(dynamic data, {String? label}) {
    try {
      String jsonString;
      if (data is String) {
        jsonString = data;
      } else {
        jsonString = const JsonEncoder.withIndent('  ').convert(data);
      }
      
      // Filter out image data to prevent log spam
      jsonString = _filterImageData(jsonString);
      
      if (label != null) {
        debugPrint('\n${'=' * 60}');
        debugPrint('📋 $label');
        debugPrint('${'=' * 60}');
      }
      
      debugPrint('```json');
      debugPrint(jsonString);
      debugPrint('```');
      
      if (label != null) {
        debugPrint('${'=' * 60}\n');
      }
    } catch (e) {
      debugPrint('Error formatting JSON: $e');
      debugPrint('Raw data: $data');
    }
  }
  
  /// Prints JSON data in a compact format for logs
  static void printCompact(dynamic data, {String? label}) {
    try {
      String jsonString;
      if (data is String) {
        jsonString = data;
      } else {
        jsonString = const JsonEncoder.withIndent('  ').convert(data);
      }
      
      // Filter out image data to prevent log spam
      jsonString = _filterImageData(jsonString);
      
      if (label != null) {
        debugPrint('📋 $label:');
      }
      
      final lines = jsonString.split('\n');
      for (final line in lines) {
        debugPrint('   $line');
      }
    } catch (e) {
      debugPrint('Error formatting JSON: $e');
      debugPrint('Raw data: $data');
    }
  }
  
  /// Returns JSON as a formatted string (useful for debugging)
  static String formatJson(dynamic data) {
    try {
      String jsonString;
      if (data is String) {
        jsonString = data;
      } else {
        jsonString = const JsonEncoder.withIndent('  ').convert(data);
      }
      
      // Filter out image data to prevent log spam
      return _filterImageData(jsonString);
    } catch (e) {
      return 'Error formatting JSON: $e\nRaw data: $data';
    }
  }
  
  static String _filterImageData(String jsonString) {
    // Filter out base64 image data
    String filtered = jsonString;
    
    // Remove base64 image data patterns
    filtered = filtered.replaceAllMapped(
      RegExp(r'"imageData":\s*"[^"]*"'),
      (match) => '"imageData": "[BASE64_IMAGE_DATA_REMOVED_FROM_LOGS]"',
    );
    
    // Remove data:image/ patterns
    filtered = filtered.replaceAllMapped(
      RegExp(r'data:image/[^;]+;base64,[A-Za-z0-9+/=]+'),
      (match) => 'data:image/jpeg;base64,[BASE64_IMAGE_DATA_REMOVED_FROM_LOGS]',
    );
    
    // Remove large base64 strings (likely images)
    filtered = filtered.replaceAllMapped(
      RegExp(r'"[A-Za-z0-9+/]{100,}={0,2}"'),
      (match) {
        final matchStr = match.group(0) ?? '';
        if (matchStr.length > 200) {
          return '"[LARGE_BASE64_DATA_REMOVED_FROM_LOGS]"';
        }
        return matchStr;
      },
    );
    
    // Remove image bytes patterns
    filtered = filtered.replaceAllMapped(
      RegExp(r'"imageBytes":\s*"[^"]*"'),
      (match) => '"imageBytes": "[IMAGE_BYTES_REMOVED_FROM_LOGS]"',
    );
    
    // Remove photo data patterns
    filtered = filtered.replaceAllMapped(
      RegExp(r'"photoData":\s*"[^"]*"'),
      (match) => '"photoData": "[PHOTO_DATA_REMOVED_FROM_LOGS]"',
    );
    
    // Remove any field containing large base64 data
    filtered = filtered.replaceAllMapped(
      RegExp(r'"[^"]*":\s*"[A-Za-z0-9+/]{500,}={0,2}"'),
      (match) => match.group(0)!.replaceAllMapped(
        RegExp(r'"[A-Za-z0-9+/]{500,}={0,2}"'),
        (innerMatch) => '"[LARGE_BASE64_DATA_REMOVED_FROM_LOGS]"',
      ),
    );
    
    return filtered;
  }
}
