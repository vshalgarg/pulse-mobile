class IncidentCheckListSiteResp {
  final int iclsrId;
  final int iclmId;
  final int siteId;
  final String incidentItemType;
  final String? checklistDesc;
  final String resp; // "true" or "false" as string
  final int clOrder;
  final String? longitude;
  final String? latitude;
  final int? localAuditLogId;
  final String? localCreatedDt;
  final String? localModifiedDt;
  final int? syncProcessId;
  final bool isActive;
  final String? remarks;

  IncidentCheckListSiteResp({
    this.iclsrId = 0,
    required this.iclmId,
    required this.siteId,
    required this.incidentItemType,
    this.checklistDesc,
    required this.resp,
    required this.clOrder,
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
      'iclsrId': iclsrId,
      'iclmId': iclmId,
      'siteId': siteId,
      'incidentItemType': incidentItemType,
      'checklistDesc': checklistDesc,
      'resp': resp,
      'clOrder': clOrder,
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
}

class IncidentTicketRequest {
  final int incidentTicketId;
  final String incidentItemType;
  final int siteId;
  final String currentSiteStatus;
  final String status;
  final String? incidentRemarks;
  final int? incidentImgId;
  final String incidentTicketReason;
  final int? closedBy;
  final String? closedDt;
  final String? closedRemarks;
  final bool isActive;
  final String? remarks;
  final List<IncidentCheckListSiteResp> incidentCheckListSiteResp;
  final String? incidentImageName;

  IncidentTicketRequest({
    this.incidentTicketId = 0,
    required this.incidentItemType,
    required this.siteId,
    required this.currentSiteStatus,
    required this.status,
    this.incidentRemarks,
    this.incidentImgId,
    required this.incidentTicketReason,
    this.closedBy,
    this.closedDt,
    this.closedRemarks,
    this.isActive = true,
    this.remarks,
    required this.incidentCheckListSiteResp,
    this.incidentImageName,
  });

  Map<String, dynamic> toJson() {
    return {
      'incidentTicketId': incidentTicketId,
      'incidentItemType': incidentItemType,
      'siteId': siteId,
      'currentSiteStatus': currentSiteStatus,
      'status': status,
      'incidentRemarks': incidentRemarks,
      'incidentImgId': incidentImgId ?? 0,
      'incidentTicketReason': incidentTicketReason,
      'closedBy': closedBy,
      'closedDt': closedDt,
      'closedRemarks': closedRemarks,
      'isActive': isActive,
      'remarks': remarks,
      'incidentCheckListSiteResp':
          incidentCheckListSiteResp.map((e) => e.toJson()).toList(),
      'incidentImageName': incidentImageName,
    };
  }
}

