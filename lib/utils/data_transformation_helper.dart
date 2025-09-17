import 'dart:convert';

/// Utility class for data transformations between different naming conventions
class DataTransformationHelper {
  
  /// Converts snake_case keys to camelCase in a Map
  static Map<String, dynamic> snakeToCamelCase(Map<String, dynamic> data) {
    final Map<String, dynamic> result = {};
    
    data.forEach((key, value) {
      final String camelKey = _snakeToCamel(key);
      
      if (value is Map<String, dynamic>) {
        // Recursively convert nested maps
        result[camelKey] = snakeToCamelCase(value);
      } else if (value is List) {
        // Convert each item in the list
        result[camelKey] = value.map((item) {
          if (item is Map<String, dynamic>) {
            return snakeToCamelCase(item);
          }
          return item;
        }).toList();
      } else {
        // Keep primitive values as is
        result[camelKey] = value;
      }
    });
    
    return result;
  }
  
  /// Converts a single snake_case string to camelCase
  static String _snakeToCamel(String snakeCase) {
    if (snakeCase.isEmpty) return snakeCase;
    
    final List<String> parts = snakeCase.split('_');
    if (parts.length == 1) return snakeCase;
    
    final String firstPart = parts[0].toLowerCase();
    final String remainingParts = parts
        .skip(1)
        .map((part) => part.isNotEmpty 
            ? part[0].toUpperCase() + part.substring(1).toLowerCase()
            : part)
        .join('');
    
    return firstPart + remainingParts;
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
  
  /// Transforms a list of asset audit data from snake_case to camelCase
  static List<Map<String, dynamic>> transformAssetAuditData(
    List<dynamic> dataList
  ) {
    return dataList.map((item) {
      if (item is Map<String, dynamic>) {
        return snakeToCamelCase(item);
      }
      return item as Map<String, dynamic>;
    }).toList();
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
