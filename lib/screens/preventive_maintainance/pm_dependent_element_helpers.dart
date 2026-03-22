// Helper functions for working with dependent_elements in PM (uses Map instead of typed models).

/// Whether the **main** PM checklist row must have a response (`is_mandatory` from API).
///
/// - `is_mandatory: true` → required (unless [checklist_desc] is a remarks field).
/// - `is_mandatory: false` → optional.
/// - If `is_mandatory` is absent, falls back to legacy `mandatoryIfValue == true` on the item.
bool isPmMainFieldMandatory(Map<String, dynamic> pmItem) {
  final checklistDesc = pmItem['checklist_desc']?.toString().toLowerCase() ?? '';
  if (checklistDesc.contains('remarks')) {
    return false;
  }

  final im = pmItem['is_mandatory'];
  if (im == true || im == 1) {
    return true;
  }
  if (im == false || im == 0) {
    return false;
  }
  if (im is String) {
    final s = im.toLowerCase().trim();
    if (s == 'true' || s == '1') return true;
    if (s == 'false' || s == '0') return false;
  }

  final mandatoryIfValue = pmItem['mandatoryIfValue'];
  if (mandatoryIfValue == true) {
    return true;
  }
  return false;
}

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
/// 1. If visibleIfValue == null and mandatoryIfValue is a List → Visible only when parent matches that list (so red * and field vanish when parent is e.g. "OK")
/// 2. If visibleIfValue == null and no mandatoryIfValue list → Always visible (default)
/// 3. If visibleIfValue == true → Visible when parent has any response
/// 4. If visibleIfValue == false → Never visible
/// 5. If visibleIfValue is a List → Visible only when parent response matches
bool shouldDependentElementBeVisible(
  Map<String, dynamic> dependentElement,
  String? parentResponse,
) {
  final visibleIfValue = dependentElement['visibleIfValue'];
  final mandatoryIfValue = dependentElement['mandatoryIfValue'];

  if (visibleIfValue == null) {
    // When no visibleIfValue but mandatoryIfValue is a List (e.g. ["Not OK"]),
    // show dependent only when parent matches - so when user selects "OK" the field and red * vanish
    if (mandatoryIfValue is List && mandatoryIfValue.isNotEmpty) {
      if (parentResponse == null || parentResponse.isEmpty) return false;
      final mandatoryValues = mandatoryIfValue
          .map((e) => e.toString().trim().toLowerCase())
          .toList();
      final parentValueLower = parentResponse.trim().toLowerCase();
      return mandatoryValues.contains(parentValueLower);
    }
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

