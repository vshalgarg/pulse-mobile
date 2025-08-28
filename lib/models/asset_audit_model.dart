class AssetAuditModel {
  final List<PageHeader> pageHeader;
  final ResponseData responseData;

  AssetAuditModel({
    required this.pageHeader,
    required this.responseData,
  });

  factory AssetAuditModel.fromJson(dynamic json) {
    // Handle case where response is a direct array
    if (json is List) {
      return AssetAuditModel(
        pageHeader: json.map((item) => PageHeader.fromJson(item as Map<String, dynamic>)).toList(),
        responseData: ResponseData.empty(), // Create empty response data
      );
    }
    
    // Handle case where response has pageHeader field
    if (json is Map<String, dynamic>) {
      return AssetAuditModel(
        pageHeader: (json['pageHeader'] as List?)
            ?.map((item) => PageHeader.fromJson(item as Map<String, dynamic>))
            .toList() ?? [],
        responseData: json['responseData'] != null 
            ? ResponseData.fromJson(json['responseData'] as Map<String, dynamic>)
            : ResponseData.empty(),
      );
    }
    
    // Default case - return empty model
    return AssetAuditModel(
      pageHeader: [],
      responseData: ResponseData.empty(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'pageHeader': pageHeader.map((item) => item.toJson()).toList(),
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
  final String indoorOutdoor;
  final String ebNonEb;
  final String op1Name;
  final String? op2Name;
  final int siteId;

  PageHeader({
    required this.siteAuditSchId,
    required this.circle,
    required this.cluster,
    this.district,
    required this.clientName,
    required this.siteCode,
    required this.siteName,
    required this.siteTypeName,
    required this.indoorOutdoor,
    required this.ebNonEb,
    required this.op1Name,
    this.op2Name,
    required this.siteId,
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
      indoorOutdoor: json['indoor_outdoor'] ?? '',
      ebNonEb: json['eb_non_eb'] ?? '',
      op1Name: json['op1_name'] ?? '',
      op2Name: json['op2_name'],
      siteId: json['site_id'] ?? 0,
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
    };
  }
}

class ResponseData {
  final List<AssetItem> vcb;
  final List<AssetItem>? rectifier;
  final List<AssetItem>? mppt;
  final List<AssetItem>? battery;
  final List<AssetItem>? cctv;
  final List<AssetItem>? smps;
  final List<AssetItem>? dg;
  final List<AssetItem>? solarPlates;
  final List<AssetItem>? fencing;
  final List<AssetItem>? extinguisher;
  final List<AssetItem>? floodLight;
  final List<AssetItem>? sandBuckets;

  ResponseData({
    required this.vcb,
    this.rectifier,
    this.mppt,
    this.battery,
    this.cctv,
    this.smps,
    this.dg,
    this.solarPlates,
    this.fencing,
    this.extinguisher,
    this.floodLight,
    this.sandBuckets,
  });

  factory ResponseData.fromJson(Map<String, dynamic> json) {
    return ResponseData(
      vcb: (json['VCB'] as List?)
              ?.map((item) => AssetItem.fromJson(item))
              .toList() ??
          [],
      rectifier: (json['Rectifier'] as List?)
              ?.map((item) => AssetItem.fromJson(item))
              .toList() ??
          [],
      mppt: (json['MPPT'] as List?)
              ?.map((item) => AssetItem.fromJson(item))
              .toList() ??
          [],
      battery: (json['Battery'] as List?)
              ?.map((item) => AssetItem.fromJson(item))
              .toList() ??
          [],
      cctv: (json['CCTV'] as List?)
              ?.map((item) => AssetItem.fromJson(item))
              .toList() ??
          [],
      smps: (json['SMPS'] as List?)
              ?.map((item) => AssetItem.fromJson(item))
              .toList() ??
          [],
      dg: (json['DG'] as List?)
              ?.map((item) => AssetItem.fromJson(item))
              .toList() ??
          [],
      solarPlates: (json['SolarPlates'] as List?)
              ?.map((item) => AssetItem.fromJson(item))
              .toList() ??
          [],
      fencing: (json['Fencing'] as List?)
              ?.map((item) => AssetItem.fromJson(item))
              .toList() ??
          [],
      extinguisher: (json['Extinguisher'] as List?)
              ?.map((item) => AssetItem.fromJson(item))
              .toList() ??
          [],
      floodLight: (json['FloodLight'] as List?)
              ?.map((item) => AssetItem.fromJson(item))
              .toList() ??
          [],
      sandBuckets: (json['SandBuckets'] as List?)
              ?.map((item) => AssetItem.fromJson(item))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'VCB': vcb.map((item) => item.toJson()).toList(),
      'Rectifier': rectifier?.map((item) => item.toJson()).toList(),
      'MPPT': mppt?.map((item) => item.toJson()).toList(),
      'Battery': battery?.map((item) => item.toJson()).toList(),
      'CCTV': cctv?.map((item) => item.toJson()).toList(),
      'SMPS': smps?.map((item) => item.toJson()).toList(),
      'DG': dg?.map((item) => item.toJson()).toList(),
      'SolarPlates': solarPlates?.map((item) => item.toJson()).toList(),
      'Fencing': fencing?.map((item) => item.toJson()).toList(),
      'Extinguisher': extinguisher?.map((item) => item.toJson()).toList(),
      'FloodLight': floodLight?.map((item) => item.toJson()).toList(),
      'SandBuckets': sandBuckets?.map((item) => item.toJson()).toList(),
    };
  }

  factory ResponseData.empty() {
    return ResponseData(
      vcb: [],
      rectifier: [],
      mppt: [],
      battery: [],
      cctv: [],
      smps: [],
      dg: [],
      solarPlates: [],
      fencing: [],
      extinguisher: [],
      floodLight: [],
      sandBuckets: [],
    );
  }
}

class AssetItem {
  final int assetAuditSiteRespId;
  final int siteAuditSchId;
  final int itemInstanceId;
  final String itemType;
  final String oemName;
  final String nexgenSerialNo;
  final String mfgSerialNo;
  final String? qrCodeScanned;
  final String? qrCodeScannedTs;
  final String? photoId;
  final String? imageName;
  final String longitude;
  final String latitude;
  final String? assetStatus;
  final String capacity;

  AssetItem({
    required this.assetAuditSiteRespId,
    required this.siteAuditSchId,
    required this.itemInstanceId,
    required this.itemType,
    required this.oemName,
    required this.nexgenSerialNo,
    required this.mfgSerialNo,
    this.qrCodeScanned,
    this.qrCodeScannedTs,
    this.photoId,
    this.imageName,
    required this.longitude,
    required this.latitude,
    this.assetStatus,
    required this.capacity,
  });

  factory AssetItem.fromJson(Map<String, dynamic> json) {
    return AssetItem(
      assetAuditSiteRespId: json['asset_audit_site_resp_id'] ?? 0,
      siteAuditSchId: json['site_audit_sch_id'] ?? 0,
      itemInstanceId: json['item_instance_id'] ?? 0,
      itemType: json['item_type'] ?? '',
      oemName: json['oem_name'] ?? '',
      nexgenSerialNo: json['nexgen_serial_no'] ?? '',
      mfgSerialNo: json['mfg_serial_no'] ?? '',
      qrCodeScanned: json['qr_code_scanned'],
      qrCodeScannedTs: json['qr_code_scanned_ts'],
      photoId: json['photo_id'],
      imageName: json['image_name'],
      longitude: json['longitude'] ?? '',
      latitude: json['latitude'] ?? '',
      assetStatus: json['asset_status'],
      capacity: json['capacity'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'asset_audit_site_resp_id': assetAuditSiteRespId,
      'site_audit_sch_id': siteAuditSchId,
      'item_instance_id': itemInstanceId,
      'item_type': itemType,
      'oem_name': oemName,
      'nexgen_serial_no': nexgenSerialNo,
      'mfg_serial_no': mfgSerialNo,
      'qr_code_scanned': qrCodeScanned,
      'qr_code_scanned_ts': qrCodeScannedTs,
      'photo_id': photoId,
      'image_name': imageName,
      'longitude': longitude,
      'latitude': latitude,
      'asset_status': assetStatus,
      'capacity': capacity,
    };
  }
}
