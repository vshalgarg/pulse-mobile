class SolarPmDataModel {
  final List<PageHeader> pageHeader;
  final SolarResponseData responseData;

  SolarPmDataModel({
    required this.pageHeader,
    required this.responseData,
  });

  factory SolarPmDataModel.fromJson(Map<String, dynamic> json) {
    return SolarPmDataModel(
      pageHeader: (json['pageHeader'] as List<dynamic>?)
              ?.map((v) => PageHeader.fromJson(v))
              .toList() ??
          [],
      responseData: SolarResponseData.fromJson(json['responseData'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'pageHeader': pageHeader.map((v) => v.toJson()).toList(),
      'responseData': responseData.toJson(),
    };
  }
}

class PageHeader {
  final int siteAuditSchId;
  final String circle;
  final String cluster;
  final String? district;
  final String clientName;
  final String siteCode;
  final String siteName;
  final String siteTypeName;
  final String? indoorOutdoor;
  final String? ebNonEb;
  final String? op1Name;
  final String? op2Name;
  final int siteId;
  final String auditDueDt;
  final int? makerSelfieImageId;

  PageHeader({
    required this.siteAuditSchId,
    required this.circle,
    required this.cluster,
    this.district,
    required this.clientName,
    required this.siteCode,
    required this.siteName,
    required this.siteTypeName,
    this.indoorOutdoor,
    this.ebNonEb,
    this.op1Name,
    this.op2Name,
    required this.siteId,
    required this.auditDueDt,
    this.makerSelfieImageId,
  });

  factory PageHeader.fromJson(Map<String, dynamic> json) {
    return PageHeader(
      siteAuditSchId: json['site_audit_sch_id'] ?? 0,
      circle: json['circle'] ?? '',
      cluster: json['cluster'] ?? '',
      district: json['district'],
      clientName: json['client_name'] ?? '',
      siteCode: json['site_code'] ?? '',
      siteName: json['site_name'] ?? '',
      siteTypeName: json['site_type_name'] ?? '',
      indoorOutdoor: json['indoor_outdoor'],
      ebNonEb: json['eb_non_eb'],
      op1Name: json['op1_name'],
      op2Name: json['op2_name'],
      siteId: json['site_id'] ?? 0,
      auditDueDt: json['audit_due_dt'] ?? '',
      makerSelfieImageId: json['maker_selfie_image_id'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'site_audit_sch_id': siteAuditSchId,
      'circle': circle,
      'cluster': cluster,
      'district': district,
      'client_name': clientName,
      'site_code': siteCode,
      'site_name': siteName,
      'site_type_name': siteTypeName,
      'indoor_outdoor': indoorOutdoor,
      'eb_non_eb': ebNonEb,
      'op1_name': op1Name,
      'op2_name': op2Name,
      'site_id': siteId,
      'audit_due_dt': auditDueDt,
      'maker_selfie_image_id': makerSelfieImageId,
    };
  }
}

class SolarResponseData {
  final List<SolarPmItem>? earthing;
  final List<SolarPmItem>? civilStructures;
  final List<SolarPmItem>? bos;
  final List<SolarPmItem>? transformer;
  final List<SolarPmItem>? safetySystems;
  final List<SolarPmItem>? spv;
  final List<SolarPmItem>? inverters;
  final List<SolarPmItem>? performanceMonitoring;
  final List<SolarPmItem>? cables;
  final List<SolarPmItem>? hygiene;

  SolarResponseData({
    this.earthing,
    this.civilStructures,
    this.bos,
    this.transformer,
    this.safetySystems,
    this.spv,
    this.inverters,
    this.performanceMonitoring,
    this.cables,
    this.hygiene,
  });

  factory SolarResponseData.fromJson(Map<String, dynamic> json) {
    return SolarResponseData(
      earthing: json['Earthing'] != null
          ? (json['Earthing'] as List<dynamic>)
              .map((v) => SolarPmItem.fromJson(v))
              .toList()
          : null,
      civilStructures: json['Civil & Structures'] != null
          ? (json['Civil & Structures'] as List<dynamic>)
              .map((v) => SolarPmItem.fromJson(v))
              .toList()
          : null,
      bos: json['BOS (Balance of system)'] != null
          ? (json['BOS (Balance of system)'] as List<dynamic>)
              .map((v) => SolarPmItem.fromJson(v))
              .toList()
          : null,
      transformer: json['Transformer'] != null
          ? (json['Transformer'] as List<dynamic>)
              .map((v) => SolarPmItem.fromJson(v))
              .toList()
          : null,
      safetySystems: json['Safety Systems'] != null
          ? (json['Safety Systems'] as List<dynamic>)
              .map((v) => SolarPmItem.fromJson(v))
              .toList()
          : null,
      spv: json['SPV'] != null
          ? (json['SPV'] as List<dynamic>)
              .map((v) => SolarPmItem.fromJson(v))
              .toList()
          : null,
      inverters: json['Inverters'] != null
          ? (json['Inverters'] as List<dynamic>)
              .map((v) => SolarPmItem.fromJson(v))
              .toList()
          : null,
      performanceMonitoring: json['Performance Monitoring'] != null
          ? (json['Performance Monitoring'] as List<dynamic>)
              .map((v) => SolarPmItem.fromJson(v))
              .toList()
          : null,
      cables: json['Cables'] != null
          ? (json['Cables'] as List<dynamic>)
              .map((v) => SolarPmItem.fromJson(v))
              .toList()
          : null,
      hygiene: json['Hygiene'] != null
          ? (json['Hygiene'] as List<dynamic>)
              .map((v) => SolarPmItem.fromJson(v))
              .toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'Earthing': earthing?.map((v) => v.toJson()).toList(),
      'Civil & Structures': civilStructures?.map((v) => v.toJson()).toList(),
      'BOS (Balance of system)': bos?.map((v) => v.toJson()).toList(),
      'Transformer': transformer?.map((v) => v.toJson()).toList(),
      'Safety Systems': safetySystems?.map((v) => v.toJson()).toList(),
      'SPV': spv?.map((v) => v.toJson()).toList(),
      'Inverters': inverters?.map((v) => v.toJson()).toList(),
      'Performance Monitoring': performanceMonitoring?.map((v) => v.toJson()).toList(),
      'Cables': cables?.map((v) => v.toJson()).toList(),
      'Hygiene': hygiene?.map((v) => v.toJson()).toList(),
    };
  }

  // Get all available sections with their data
  Map<String, List<SolarPmItem>> getAvailableSections() {
    final sections = <String, List<SolarPmItem>>{};
    
    if (earthing != null && earthing!.isNotEmpty) {
      sections['Earthing'] = earthing!;
    }
    if (civilStructures != null && civilStructures!.isNotEmpty) {
      sections['Civil & Structures'] = civilStructures!;
    }
    if (bos != null && bos!.isNotEmpty) {
      sections['BOS (Balance of system)'] = bos!;
    }
    if (transformer != null && transformer!.isNotEmpty) {
      sections['Transformer'] = transformer!;
    }
    if (safetySystems != null && safetySystems!.isNotEmpty) {
      sections['Safety Systems'] = safetySystems!;
    }
    if (spv != null && spv!.isNotEmpty) {
      sections['SPV'] = spv!;
    }
    if (inverters != null && inverters!.isNotEmpty) {
      sections['Inverters'] = inverters!;
    }
    if (performanceMonitoring != null && performanceMonitoring!.isNotEmpty) {
      sections['Performance Monitoring'] = performanceMonitoring!;
    }
    if (cables != null && cables!.isNotEmpty) {
      sections['Cables'] = cables!;
    }
    if (hygiene != null && hygiene!.isNotEmpty) {
      sections['Hygiene'] = hygiene!;
    }
    
    return sections;
  }
}

class SolarPmItem {
  final int pmCheckListSiteRespId;
  final int auditSchId;
  final int siteAuditSchId;
  final int siteId;
  final String pmItemType;
  final String checklistDesc;
  final String? resp;
  final int clOrder;
  final String? photoId;
  final String? photoTakenTs;
  final double? longitude;
  final double? latitude;
  final String? remarks;
  final int siteDomainId;
  final String siteDomainName;
  final String respType;

  SolarPmItem({
    required this.pmCheckListSiteRespId,
    required this.auditSchId,
    required this.siteAuditSchId,
    required this.siteId,
    required this.pmItemType,
    required this.checklistDesc,
    this.resp,
    required this.clOrder,
    this.photoId,
    this.photoTakenTs,
    this.longitude,
    this.latitude,
    this.remarks,
    required this.siteDomainId,
    required this.siteDomainName,
    required this.respType,
  });

  factory SolarPmItem.fromJson(Map<String, dynamic> json) {
    return SolarPmItem(
      pmCheckListSiteRespId: json['pm_check_list_site_resp_id'] ?? 0,
      auditSchId: json['audit_sch_id'] ?? 0,
      siteAuditSchId: json['site_audit_sch_id'] ?? 0,
      siteId: json['site_id'] ?? 0,
      pmItemType: json['pm_item_type'] ?? '',
      checklistDesc: json['checklist_desc'] ?? '',
      resp: json['resp'],
      clOrder: json['cl_order'] ?? 0,
      photoId: json['photo_id'],
      photoTakenTs: json['photo_taken_ts'],
      longitude: json['longitude']?.toDouble(),
      latitude: json['latitude']?.toDouble(),
      remarks: json['remarks'],
      siteDomainId: json['site_domain_id'] ?? 0,
      siteDomainName: json['site_domain_name'] ?? '',
      respType: json['resp_type'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'pm_check_list_site_resp_id': pmCheckListSiteRespId,
      'audit_sch_id': auditSchId,
      'site_audit_sch_id': siteAuditSchId,
      'site_id': siteId,
      'pm_item_type': pmItemType,
      'checklist_desc': checklistDesc,
      'resp': resp,
      'cl_order': clOrder,
      'photo_id': photoId,
      'photo_taken_ts': photoTakenTs,
      'longitude': longitude,
      'latitude': latitude,
      'remarks': remarks,
      'site_domain_id': siteDomainId,
      'site_domain_name': siteDomainName,
      'resp_type': respType,
    };
  }

  // Check if this item requires a photo
  bool get requiresPhoto => respType.contains('IMG');
  
  // Check if this item requires text input
  bool get requiresText => respType.contains('TEXT');
  
  // Check if this item requires dropdown selection
  bool get requiresDropdown => respType.contains('DROPDOWN');
}
