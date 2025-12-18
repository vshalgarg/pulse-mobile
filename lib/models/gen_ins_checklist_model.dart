import 'dart:convert';

class GenInsCheckListData {
  final int giclmId;
  final int siteDomainId;
  final String checklistDesc;
  final String respType;
  final RespTypeValueMap? respTypeValueMap;
  final bool isMandatory;
  final int clOrder;
  final String? flag;
  final List<DependentElement>? dependentElements;

  GenInsCheckListData({
    required this.giclmId,
    required this.siteDomainId,
    required this.checklistDesc,
    required this.respType,
    this.respTypeValueMap,
    required this.isMandatory,
    required this.clOrder,
    this.flag,
    this.dependentElements,
  });

  factory GenInsCheckListData.fromJson(Map<String, dynamic> json) {
    // Parse dependent_elements - can be array or JSON string
    List<DependentElement>? dependentElements;
    if (json['dependent_elements'] != null) {
      if (json['dependent_elements'] is List) {
        dependentElements = (json['dependent_elements'] as List)
            .map((e) => DependentElement.fromJson(e as Map<String, dynamic>))
            .toList();
      } else if (json['dependent_elements'] is String) {
        try {
          final decoded = jsonDecode(json['dependent_elements'] as String);
          if (decoded is List) {
            dependentElements = decoded
                .map((e) => DependentElement.fromJson(e as Map<String, dynamic>))
                .toList();
          }
        } catch (e) {
          // If parsing fails, leave as null
        }
      }
    }

    return GenInsCheckListData(
      giclmId: json['giclm_id'] ?? 0,
      siteDomainId: json['site_domain_id'] ?? 0,
      checklistDesc: json['checklist_desc']?.toString() ?? '',
      respType: json['resp_type']?.toString() ?? '',
      respTypeValueMap: json['resp_type_value_map'] != null 
          ? RespTypeValueMap.fromJson(json['resp_type_value_map'])
          : null,
      isMandatory: json['is_mandatory'] ?? false,
      clOrder: json['cl_order'] ?? 0,
      flag: json['flag']?.toString(),
      dependentElements: dependentElements,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'giclm_id': giclmId,
      'site_domain_id': siteDomainId,
      'checklist_desc': checklistDesc,
      'resp_type': respType,
      'resp_type_value_map': respTypeValueMap?.toJson(),
      'is_mandatory': isMandatory,
      'cl_order': clOrder,
      'flag': flag,
      'dependent_elements': dependentElements?.map((e) => e.toJson()).toList(),
    };
  }

  @override
  String toString() {
    return 'GenInsCheckListData{giclmId: $giclmId, checklistDesc: "$checklistDesc", respType: "$respType"}';
  }
}

class RespTypeValueMap {
  final String type;
  final dynamic value; // Can be Map<String, dynamic> or String
  final bool isNull;

  RespTypeValueMap({
    required this.type,
    required this.value,
    required this.isNull,
  });

  factory RespTypeValueMap.fromJson(Map<String, dynamic> json) {
    dynamic value = json['value'];
    
    // If value is already a Map, keep it as is
    // If value is a String, try to parse it as JSON
    if (value is String && value.isNotEmpty) {
      try {
        final parsed = jsonDecode(value);
        if (parsed is Map) {
          value = parsed;
        }
      } catch (e) {
        // If parsing fails, keep as string
      }
    }
    
    return RespTypeValueMap(
      type: json['type']?.toString() ?? '',
      value: value,
      isNull: json['null'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'value': value is Map ? value : (value?.toString() ?? ''),
      'null': isNull,
    };
  }

  // Helper method to get value as Map
  Map<String, dynamic>? get valueAsMap {
    if (value is Map<String, dynamic>) {
      return value as Map<String, dynamic>;
    } else if (value is Map) {
      return Map<String, dynamic>.from(value);
    } else if (value is String && value.isNotEmpty) {
      try {
        final parsed = jsonDecode(value);
        if (parsed is Map) {
          return Map<String, dynamic>.from(parsed);
        }
      } catch (e) {
        // Return null if parsing fails
      }
    }
    return null;
  }

  // Helper method to get value as String (for backward compatibility)
  String get valueAsString {
    if (value is Map) {
      return jsonEncode(value);
    }
    return value?.toString() ?? '';
  }

  @override
  String toString() {
    return 'RespTypeValueMap{type: "$type", value: "$value"}';
  }
}

// Model for dependent elements
class DependentElement {
  final String respType;
  final String checklistDesc;
  final dynamic visibleIfValue; // bool or null
  final dynamic mandatoryIfValue; // bool, List<String>, or null

  DependentElement({
    required this.respType,
    required this.checklistDesc,
    this.visibleIfValue,
    this.mandatoryIfValue,
  });

  factory DependentElement.fromJson(Map<String, dynamic> json) {
    return DependentElement(
      respType: json['resp_type']?.toString() ?? '',
      checklistDesc: json['checklist_desc']?.toString() ?? '',
      visibleIfValue: json['visibleIfValue'],
      mandatoryIfValue: json['mandatoryIfValue'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'resp_type': respType,
      'checklist_desc': checklistDesc,
      'visibleIfValue': visibleIfValue,
      'mandatoryIfValue': mandatoryIfValue,
    };
  }

  // Helper method to check if element should be visible based on parent response
  /// 
  /// Rules:
  /// 1. If visibleIfValue == null → Always visible (default)
  /// 2. If visibleIfValue == true → Visible when parent has any response
  /// 3. If visibleIfValue == false → Never visible
  /// 4. If visibleIfValue is a List (e.g., ["No", "Not Ok"]) → Visible only when parent response matches
  bool shouldBeVisible(String? parentResponse) {
    if (visibleIfValue == null) {
      return true; // Default to visible if not specified
    }
    
    // Case 1: Boolean true - show when parent has a response
    if (visibleIfValue is bool && visibleIfValue == true) {
      return parentResponse != null && parentResponse.isNotEmpty;
    }
    
    // Case 2: Boolean false - never show
    if (visibleIfValue is bool && visibleIfValue == false) {
      return false;
    }
    
    // Case 3: Array of values - show only when parent response matches
    // Example: visibleIfValue: ["No", "Not Ok"]
    // This means: visible ONLY when parent response is "No" or "Not Ok"
    if (visibleIfValue is List) {
      if (parentResponse == null || parentResponse.isEmpty) {
        return false; // No parent response, not visible
      }
      
      // Check if parent response matches any value in the array (case-insensitive)
      final visibleValues = (visibleIfValue as List)
          .map((e) => e.toString().trim().toLowerCase())
          .toList();
      final parentValueLower = parentResponse.trim().toLowerCase();
      
      // Return true only if parent response matches one of the visible values
      // Example: 
      //   - visibleIfValue: ["No", "Not Ok"]
      //   - parent = "OK" → returns false (not visible)
      //   - parent = "Not OK" → returns true (visible, matches "Not Ok" case-insensitively)
      return visibleValues.contains(parentValueLower);
    }
    
    return false;
  }

  // Helper method to check if element is mandatory based on parent response
  bool isMandatoryForResponse(String? parentResponse) {
    if (mandatoryIfValue == null) {
      return false; // Default to not mandatory
    }
    
    if (mandatoryIfValue is bool) {
      return mandatoryIfValue as bool;
    }
    
    if (mandatoryIfValue is List) {
      final mandatoryValues = (mandatoryIfValue as List)
          .map((e) => e.toString().toLowerCase())
          .toList();
      final parentValue = parentResponse?.toLowerCase() ?? '';
      return mandatoryValues.contains(parentValue);
    }
    
    return false;
  }

  @override
  String toString() {
    return 'DependentElement{respType: "$respType", checklistDesc: "$checklistDesc"}';
  }
}
