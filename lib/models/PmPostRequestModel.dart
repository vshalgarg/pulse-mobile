class PmPostRequest {
  final int? pmCheckListSiteRespId;
  final int pmCheckListMstId;
  final int auditSchId;
  final int siteAuditSchId;
  final int siteId;
  final String pmItemType;
  final String checklistDesc;
  final String resp;
  final int clOrder;
  final int? photoId;
  final String? photoTakenTs;
  final String? longitude;
  final String? latitude;
  final int? localAuditLogId;
  final String? localCreatedDt;
  final String? localModifiedDt;
  final int? syncProcessId;
  final bool isActive;
  final String? remarks;


  PmPostRequest({
    this.pmCheckListSiteRespId,
    required this.pmCheckListMstId,
    required this.auditSchId,
    required this.siteAuditSchId,
    required this.siteId,
    required this.pmItemType,
    required this.checklistDesc,
    required this.resp,
    required this.clOrder,
    this.photoId,
    this.photoTakenTs,
    this.longitude,
    this.latitude,
    this.localAuditLogId,
    this.localCreatedDt,
    this.localModifiedDt,
    this.syncProcessId,
    this.isActive = true,
    this.remarks,

  });

  Map<String, dynamic> toJson() {
    return {
      'pmCheckListSiteRespId': pmCheckListSiteRespId,
      'pmCheckListMstId': pmCheckListMstId,
      'auditSchId': auditSchId,
      'siteAuditSchId': siteAuditSchId,
      'siteId': siteId,
      'pmItemType': pmItemType,
      'checklistDesc': checklistDesc,
      'resp': resp,
      'clOrder': clOrder,
      'photoId': photoId,
      'photoTakenTs': photoTakenTs,
      'longitude': longitude,
      'latitude': latitude,
      'localAuditLogId': localAuditLogId,
      'localCreatedDt': localCreatedDt,
      'localModifiedDt': localModifiedDt,
      'syncProcessId': syncProcessId,
      'isActive': isActive,
      'remarks': remarks,

    };
  }

  factory PmPostRequest.fromJson(Map<String, dynamic> json) {
    return PmPostRequest(
      pmCheckListSiteRespId: json['pmCheckListSiteRespId'],
      pmCheckListMstId: json['pmCheckListMstId'],
      auditSchId: json['auditSchId'],
      siteAuditSchId: json['siteAuditSchId'],
      siteId: json['siteId'],
      pmItemType: json['pmItemType'],
      checklistDesc: json['checklistDesc'],
      resp: json['resp'],
      clOrder: json['clOrder'],
      photoId: json['photoId'],
      photoTakenTs: json['photoTakenTs'],
      longitude: json['longitude'],
      latitude: json['latitude'],
      localAuditLogId: json['localAuditLogId'],
      localCreatedDt: json['localCreatedDt'],
      localModifiedDt: json['localModifiedDt'],
      syncProcessId: json['syncProcessId'],
      isActive: json['isActive'] ?? true,
      remarks: json['remarks'],

    );
  }
}

class PmPostResponse {
  final int pmCheckListSiteRespId;
  final String message;
  final bool success;

  PmPostResponse({
    required this.pmCheckListSiteRespId,
    required this.message,
    required this.success,
  });

  factory PmPostResponse.fromJson(Map<String, dynamic> json) {
    return PmPostResponse(
      pmCheckListSiteRespId: json['pmCheckListSiteRespId'] ?? 0,
      message: json['message'] ?? '',
      success: json['success'] ?? false,
    );
  }
}
