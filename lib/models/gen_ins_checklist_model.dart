class GenInsCheckListData {
  final int giclmId;
  final int siteDomainId;
  final String checklistDesc;
  final String respType;
  final RespTypeValueMap? respTypeValueMap;
  final bool isMandatory;
  final int clOrder;

  GenInsCheckListData({
    required this.giclmId,
    required this.siteDomainId,
    required this.checklistDesc,
    required this.respType,
    this.respTypeValueMap,
    required this.isMandatory,
    required this.clOrder,
  });

  factory GenInsCheckListData.fromJson(Map<String, dynamic> json) {
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
    };
  }

  @override
  String toString() {
    return 'GenInsCheckListData{giclmId: $giclmId, checklistDesc: "$checklistDesc", respType: "$respType"}';
  }
}

class RespTypeValueMap {
  final String type;
  final String value;
  final bool isNull;

  RespTypeValueMap({
    required this.type,
    required this.value,
    required this.isNull,
  });

  factory RespTypeValueMap.fromJson(Map<String, dynamic> json) {
    return RespTypeValueMap(
      type: json['type']?.toString() ?? '',
      value: json['value']?.toString() ?? '',
      isNull: json['null'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'value': value,
      'null': isNull,
    };
  }

  @override
  String toString() {
    return 'RespTypeValueMap{type: "$type", value: "$value"}';
  }
}
