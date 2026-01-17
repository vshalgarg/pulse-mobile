import 'dart:convert';

class CMChecklistItem {
  final String checklistDesc;
  final String? respTypeValueMap;
  final String? impactedItemValueMap;
  final int itemTypeId;
  final String respType;
  final String itemType;
  final int? checkListGroupId;
  final int cmCheckListMstId;
  final bool isMandatory;
  final List<dynamic> childitemData;
  final int clOrder;
  final String subItemType;

  CMChecklistItem({
    required this.checklistDesc,
    this.respTypeValueMap,
    this.impactedItemValueMap,
    required this.itemTypeId,
    required this.respType,
    required this.itemType,
    this.checkListGroupId,
    required this.cmCheckListMstId,
    required this.isMandatory,
    required this.childitemData,
    required this.clOrder,
    required this.subItemType,
  });

  factory CMChecklistItem.fromJson(Map<String, dynamic> json) {
    // Debug logging

    String checklistDesc = json['checklist_desc']?.toString() ?? '';
    String respType = json['resp_type']?.toString() ?? '';
    String respTypeValueMap = json['resp_type_value_map']?.toString() ?? '';
    
    // Fix data inconsistencies from API
    if (checklistDesc == 'Phase (in case of DG)' && respTypeValueMap.isNotEmpty) {
      respType = 'RADIO';

    }
    
    if (checklistDesc == 'DG Canopy Cleanliness') {
      respTypeValueMap = '{"OK": "OK", "Not OK": "Not OK"}';

    }
    
    // Fix CCU and SMPS rectifier and MPPT fields to be dropdowns instead of multi-dynamic dropdowns
    if (checklistDesc == 'S No of Faulty Rectifier') {
      respType = 'DROPDOWN';
      respTypeValueMap = '{"SRN-2378": "SRN-2378", "SRN-1463": "SRN-1463", "SRN-9075": "SRN-9075"}';

    }
    
    if (checklistDesc == 'S No of Faulty MPPT') {
      respType = 'DROPDOWN';
      respTypeValueMap = '{"SRN-1001": "SRN-1001", "SRN-1002": "SRN-1002", "SRN-1003": "SRN-1003"}';

    }
    
    return CMChecklistItem(
      checklistDesc: checklistDesc,
      respTypeValueMap: respTypeValueMap.isNotEmpty ? respTypeValueMap : null,
      impactedItemValueMap: json['impacted_item_value_map']?.toString(),
      itemTypeId: json['item_type_id'] ?? 0,
      respType: respType,
      itemType: json['item_type'] ?? '',
      checkListGroupId: json['check_list_group_id'],
      cmCheckListMstId: json['cm_check_list_mst_id'] ?? 0,
      isMandatory: json['is_mandatory'] ?? false,
      childitemData: json['childitemData'] ?? [],
      clOrder: json['cl_order'] ?? 0,
      subItemType: json['sub_item_type'] ?? '',
    );
  }

  Map<String, String>? get radioOptions {
    if (respTypeValueMap == null) return null;
    try {
      final map = json.decode(respTypeValueMap!);
      return Map<String, String>.from(map);
    } catch (e) {

      return null;
    }
  }
}

class CMChecklistResponse {
  final Map<String, List<CMChecklistItem>> data;
  final Map<String, List<CMChecklistItem>> checkListDetails;
  final List<dynamic> additionalDetails;
  final List<dynamic> siteDeployedItems;

  CMChecklistResponse({
    required this.data,
    required this.checkListDetails,
    required this.additionalDetails,
    required this.siteDeployedItems,
  });

  factory CMChecklistResponse.fromJson(Map<String, dynamic> json) {
    final dataMap = <String, List<CMChecklistItem>>{};
    final checkListDetailsMap = <String, List<CMChecklistItem>>{};

    // Parse main data
    if (json['data'] != null) {
      json['data'].forEach((key, value) {
        if (value is List) {

          dataMap[key] = (value as List).map((item) => CMChecklistItem.fromJson(item)).toList();
        }
      });
    }
    
    // Parse checkListDetails
    if (json['checkListDetails'] != null) {
      json['checkListDetails'].forEach((key, value) {
        if (value is List) {

          checkListDetailsMap[key] = (value as List).map((item) => CMChecklistItem.fromJson(item)).toList();
        }
      });
    }
    
    return CMChecklistResponse(
      data: dataMap,
      checkListDetails: checkListDetailsMap,
      additionalDetails: json['additionalDetails'] ?? [],
      siteDeployedItems: json['siteDeployedItems'] ?? [],
    );
  }

  // 👇 UPDATED METHODS - Handle both uppercase and capitalized keys
  List<CMChecklistItem> getDGChecklist() {
    return data['DG'] ?? data['dg'] ?? [];
  }

  List<CMChecklistItem> getBatteryChecklist() {
    // Try multiple key variations - prioritize BATTERY (uppercase) as it's in the API response
    final result = data['BATTERY'] ?? 
           data['Battery'] ?? 
           data['battery'] ?? 
           checkListDetails['BATTERY'] ??
           checkListDetails['Battery'] ??
           checkListDetails['battery'] ?? 
           [];

    return result;
  }

  List<CMChecklistItem> getSolarChecklist() {
    return data['Solar'] ?? data['SOLAR'] ?? data['solar'] ?? [];
  }

  List<CMChecklistItem> getCCUChecklist() {
    // Try multiple key variations - prioritize CCU (uppercase) as it's in the API response
    final result = data['CCU'] ?? 
           data['Ccu'] ?? 
           data['ccu'] ?? 
           checkListDetails['CCU'] ??
           checkListDetails['Ccu'] ??
           checkListDetails['ccu'] ?? 
           [];

    return result;
  }

  List<CMChecklistItem> getSMPSChecklist() {
    return data['SMPS'] ?? data['Smps'] ?? data['smps'] ?? [];
  }

  // 👇 NEW: Get all available equipment types
  List<String> getAvailableEquipmentTypes() {
    final types = <String>[];
    
    // Check main data
    data.forEach((key, value) {
      if (value.isNotEmpty) types.add(key);
    });
    
    // Check checkListDetails
    checkListDetails.forEach((key, value) {
      if (value.isNotEmpty && !types.contains(key)) types.add(key);
    });

    return types;
  }

  // 👇 NEW: Get checklist by exact key
  List<CMChecklistItem> getChecklistByKey(String key) {
    return data[key] ?? checkListDetails[key] ?? [];
  }
}