/// Helper functions for working with dependent_elements in PM (uses Map instead of typed models)

/// Parse dependent_elements from PM item Map
List<Map<String, dynamic>>? parseDependentElements(Map<String, dynamic> pmItem) {
  final dependentElements = pmItem['dependent_elements'];
  if (dependentElements == null) return null;
  
  if (dependentElements is List) {
    return dependentElements
        .where((e) => e is Map<String, dynamic>)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }
  
  return null;
}

/// Check if dependent element should be visible based on parent response
/// 
/// Rules:
/// 1. If visibleIfValue == null → Always visible (default)
/// 2. If visibleIfValue == true → Visible when parent has any response
/// 3. If visibleIfValue == false → Never visible
/// 4. If visibleIfValue is a List (e.g., ["No", "Not Ok"]) → Visible only when parent response matches
bool shouldDependentElementBeVisible(
  Map<String, dynamic> dependentElement,
  String? parentResponse,
) {
  final visibleIfValue = dependentElement['visibleIfValue'];
  
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
  if (visibleIfValue is List) {
    if (parentResponse == null || parentResponse.isEmpty) {
      return false; // No parent response, not visible
    }
    
    // Check if parent response matches any value in the array (case-insensitive)
    final visibleValues = visibleIfValue
        .map((e) => e.toString().trim().toLowerCase())
        .toList();
    final parentValueLower = parentResponse.trim().toLowerCase();
    
    return visibleValues.contains(parentValueLower);
  }
  
  return false;
}

/// Check if dependent element is mandatory based on parent response
/// 
/// Rules:
/// 1. If mandatoryIfValue == true → Always mandatory (for all parent responses)
/// 2. If mandatoryIfValue is a List (e.g., ["No", "Not Ok"]) → Mandatory only when parent response matches
bool isDependentElementMandatory(
  Map<String, dynamic> dependentElement,
  String? parentResponse,
) {
  final mandatoryIfValue = dependentElement['mandatoryIfValue'];
  
  if (mandatoryIfValue == null) {
    return false; // Default to not mandatory
  }
  
  if (mandatoryIfValue is bool) {
    return mandatoryIfValue;
  }
  
  if (mandatoryIfValue is List) {
    if (parentResponse == null || parentResponse.isEmpty) {
      return false; // No parent response, not mandatory
    }
    
    // Check if parent response matches any value in the array (case-insensitive)
    final mandatoryValues = mandatoryIfValue
        .map((e) => e.toString().trim().toLowerCase())
        .toList();
    final parentValueLower = parentResponse.trim().toLowerCase();
    
    return mandatoryValues.contains(parentValueLower);
  }
  
  return false;
}

