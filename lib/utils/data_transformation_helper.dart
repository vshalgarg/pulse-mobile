import 'dart:convert';

import 'package:app/utils/asset_audit_validation_helper.dart';

/// Utility class for data transformations between different naming conventions
class DataTransformationHelper {

  static List<dynamic> modifyData(List<dynamic> actualData, List<dynamic> modifiedData) {
    if(modifiedData.isEmpty || actualData.isEmpty) {
      return [];
    }
    List<dynamic> modifiedDataToReturn = [];
    for(dynamic data in modifiedData) {
      final serialNo = data['mfg_serial_no']?.toString() ?? "";
      final qrCodeScanned = data['qr_code_scanned']?.toString() == 'true';
      if(serialNo.isNotEmpty) {
        final asset = AssetAuditValidationHelper.findItemWithSerialNumber(serialNo, actualData, qrCodeScanned);
        if(asset != null) {
          asset['qr_code_scanned'] = data['qr_code_scanned'];
          asset['qr_code_scanned_ts'] = data['qr_code_scanned_ts'];
          asset['photo_id'] = data['photo_id'];
          asset['asset_status'] = data['asset_status'];
          modifiedDataToReturn.add(asset);
        }
      }
    }
    return modifiedDataToReturn;
  }

  static Map<String, dynamic> convertKeysToCamelCase(Map<String, dynamic> json) {
    return json.map((key, value) {
      final newKey = _snakeToCamel(key);
        return MapEntry(newKey, value);
    });
  }

  static String _snakeToCamel(String snake) {
    return snake.replaceAllMapped(
      RegExp(r'_([a-z])'),
          (match) => match.group(1)!.toUpperCase(),
    );
  }

  static List<dynamic> convertListToCamelCase(List<dynamic> data) {
    return data.map((e) => convertKeysToCamelCase(e)).toList();
  }

  /// Converts camelCase keys to snake_case in a Map
  static Map<String, dynamic> camelToSnakeCase(Map<String, dynamic> data) {
    final Map<String, dynamic> result = {};
    
    data.forEach((key, value) {
      final String snakeKey = _camelToSnake(key);
      
      if (value is Map<String, dynamic>) {
        // Recursively convert nested maps
        result[snakeKey] = camelToSnakeCase(value);
      } else if (value is List) {
        // Convert each item in the list
        result[snakeKey] = value.map((item) {
          if (item is Map<String, dynamic>) {
            return camelToSnakeCase(item);
          }
          return item;
        }).toList();
      } else {
        // Keep primitive values as is
        result[snakeKey] = value;
      }
    });
    
    return result;
  }
  
  /// Converts a single camelCase string to snake_case
  static String _camelToSnake(String camelCase) {
    if (camelCase.isEmpty) return camelCase;
    
    final StringBuffer result = StringBuffer();
    
    for (int i = 0; i < camelCase.length; i++) {
      final String char = camelCase[i];
      
      if (char == char.toUpperCase() && char != char.toLowerCase()) {
        // This is an uppercase letter
        if (i > 0) {
          result.write('_');
        }
        result.write(char.toLowerCase());
      } else {
        result.write(char);
      }
    }
    
    return result.toString();
  }

  /// Debug method to print transformation results
  static void debugTransformation(
    String label,
    Map<String, dynamic> original,
    Map<String, dynamic> transformed
  ) {
    print('🔄 $label Transformation:');
    print('📥 Original: ${jsonEncode(original)}');
    print('📤 Transformed: ${jsonEncode(transformed)}');
    print('---');
  }
}
