class AssetAuditPostRequest {
  final int? assetAuditSiteRespId;
  final int auditSchId;
  final int siteAuditSchId;
  final int siteId;
  final int itemInstanceId;
  final String nexgenSerialNo;
  final int itemTypeId;
  final bool qrCodeScanned;
  final String? qrCodeScannedTs;
  final int photoId;
  final String photoTakenTs;
  final String assetStatus;
  final String? longitude;
  final String? latitude;
  final String? itemTypeRemark;
  final int localAuditLogId;
  final String localQrCodeScannedTs;
  final String localCreatedDt;
  final String localModifiedDt;
  final int syncProcessId;
  final bool isActive;
  final String? remarks;


  AssetAuditPostRequest({
    this.assetAuditSiteRespId,
    required this.auditSchId,
    required this.siteAuditSchId,
    required this.siteId,
    required this.itemInstanceId,
    required this.nexgenSerialNo,
    required this.itemTypeId,
    required this.qrCodeScanned,
    this.qrCodeScannedTs,
    required this.photoId,
    required this.photoTakenTs,
    required this.assetStatus,
    this.longitude,
    this.latitude,
    this.itemTypeRemark,
    required this.localAuditLogId,
    required this.localQrCodeScannedTs,
    required this.localCreatedDt,
    required this.localModifiedDt,
    required this.syncProcessId,
    required this.isActive,
    this.remarks,
  });

  Map<String, dynamic> toJson() {
    return {
      if (assetAuditSiteRespId != null) 'assetAuditSiteRespId': assetAuditSiteRespId,
      'auditSchId': auditSchId,
      'siteAuditSchId': siteAuditSchId,
      'siteId': siteId,
      'itemInstanceId': itemInstanceId,
      'nexgenSerialNo': nexgenSerialNo,
      'itemTypeId': itemTypeId,
      'qrCodeScanned': qrCodeScanned,
      if (qrCodeScannedTs != null) 'qrCodeScannedTs': qrCodeScannedTs,
      // Only include photoId if it's valid (not 0 or null)
      if (photoId != null && photoId > 0) 'photoId': photoId,
      // Only include photoTakenTs if it's not null
      if (photoTakenTs != null) 'photoTakenTs': photoTakenTs,
      'assetStatus': assetStatus,
      if (longitude != null) 'longitude': longitude,
      if (latitude != null) 'latitude': latitude,
      if (itemTypeRemark != null) 'itemTypeRemark': itemTypeRemark,
      'localAuditLogId': localAuditLogId,
      'localQrCodeScannedTs': localQrCodeScannedTs,
      'localCreatedDt': localCreatedDt,
      'localModifiedDt': localModifiedDt,
      'syncProcessId': syncProcessId,
      'isActive': isActive,
      if (remarks != null) 'remarks': remarks,
    };
  }

  factory AssetAuditPostRequest.fromJson(Map<String, dynamic> json) {
    return AssetAuditPostRequest(
      assetAuditSiteRespId: json['assetAuditSiteRespId'],
      auditSchId: json['auditSchId'],
      siteAuditSchId: json['siteAuditSchId'],
      siteId: json['siteId'],
      itemInstanceId: json['itemInstanceId'],
      nexgenSerialNo: json['nexgenSerialNo'],
      itemTypeId: json['itemTypeId'],
      qrCodeScanned: json['qrCodeScanned'],
      qrCodeScannedTs: json['qrCodeScannedTs'],
      photoId: json['photoId'],
      photoTakenTs: json['photoTakenTs'],
      assetStatus: json['assetStatus'],
      longitude: json['longitude'],
      latitude: json['latitude'],
      itemTypeRemark: json['itemTypeRemark'],
      localAuditLogId: json['localAuditLogId'],
      localQrCodeScannedTs: json['localQrCodeScannedTs'],
      localCreatedDt: json['localCreatedDt'],
      localModifiedDt: json['localModifiedDt'],
      syncProcessId: json['syncProcessId'],
      isActive: json['isActive'],
      remarks: json['remarks'],
    );
  }
}

class AssetAuditPostResponse {
  final int assetAuditSiteRespId;
  final int auditSchId;
  final int siteAuditSchId;
  final int siteId;
  final int itemInstanceId;
  final String nexgenSerialNo;
  final int itemTypeId;
  final bool qrCodeScanned;
  final String? qrCodeScannedTs;
  final int? photoId;
  final String? photoTakenTs;
  final String assetStatus;
  final String? longitude;
  final String? latitude;
  final String? itemTypeRemark;
  final int localAuditLogId;
  final String localQrCodeScannedTs;
  final String localCreatedDt;
  final String localModifiedDt;
  final int syncProcessId;
  final bool isActive;
  final String? remarks;

  AssetAuditPostResponse({
    required this.assetAuditSiteRespId,
    required this.auditSchId,
    required this.siteAuditSchId,
    required this.siteId,
    required this.itemInstanceId,
    required this.nexgenSerialNo,
    required this.itemTypeId,
    required this.qrCodeScanned,
    this.qrCodeScannedTs,
     this.photoId,
     this.photoTakenTs,
    required this.assetStatus,
    this.longitude,
    this.latitude,
    this.itemTypeRemark,
    required this.localAuditLogId,
    required this.localQrCodeScannedTs,
    required this.localCreatedDt,
    required this.localModifiedDt,
    required this.syncProcessId,
    required this.isActive,
    this.remarks,
  });

  factory AssetAuditPostResponse.fromJson(Map<String, dynamic> json) {
    return AssetAuditPostResponse(
      assetAuditSiteRespId: json['assetAuditSiteRespId'],
      auditSchId: json['auditSchId'],
      siteAuditSchId: json['siteAuditSchId'],
      siteId: json['siteId'],
      itemInstanceId: json['itemInstanceId'],
      nexgenSerialNo: json['nexgenSerialNo'],
      itemTypeId: json['itemTypeId'],
      qrCodeScanned: json['qrCodeScanned'],
      qrCodeScannedTs: json['qrCodeScannedTs'],
      photoId: json['photoId'],
      photoTakenTs: json['photoTakenTs'],
      assetStatus: json['assetStatus'],
      longitude: json['longitude'],
      latitude: json['latitude'],
      itemTypeRemark: json['itemTypeRemark'],
      localAuditLogId: json['localAuditLogId'],
      localQrCodeScannedTs: json['localQrCodeScannedTs'],
      localCreatedDt: json['localCreatedDt'],
      localModifiedDt: json['localModifiedDt'],
      syncProcessId: json['syncProcessId'],
      isActive: json['isActive'],
      remarks: json['remarks'],
    );
  }
}
