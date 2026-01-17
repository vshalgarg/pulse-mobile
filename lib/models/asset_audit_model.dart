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
  // Telecom fields
  final String? circle;
  final String? cluster;
  final String? indoorOutdoor;
  final String? ebNonEb;
  final String? op1Name;
  final String? op2Name;
  final int? siteId;
  // Solar fields
  final String? solarState;
  final String? solarDistrict;
  final String? auditDueDt;
  final String? siteDomainName;
  final String? status;
  // Common fields
  final String? district;
  final String clientName;
  final String siteCode;
  final String siteName;
  final String siteTypeName;
  final int? makerSelfieImageId;

  PageHeader({
    required this.siteAuditSchId,
    // Telecom fields
    this.circle,
    this.cluster,
    this.indoorOutdoor,
    this.ebNonEb,
    this.op1Name,
    this.op2Name,
    this.siteId,
    // Solar fields
    this.solarState,
    this.solarDistrict,
    this.auditDueDt,
    this.siteDomainName,
    this.status,
    // Common fields
    this.district,
    required this.clientName,
    required this.siteCode,
    required this.siteName,
    required this.siteTypeName,
    this.makerSelfieImageId,
  });

  factory PageHeader.fromJson(Map<String, dynamic> json) {
    return PageHeader(
      siteAuditSchId: json['site_audit_sch_id'] ?? 0,
      // Telecom fields
      circle: json['circle'],
      cluster: json['cluster'],
      indoorOutdoor: json['indoor_outdoor'],
      ebNonEb: json['eb_non_eb'],
      op1Name: json['op1_name'],
      op2Name: json['op2_name'],
      siteId: json['site_id'],
      // Solar fields
      solarState: json['solar_state'],
      solarDistrict: json['solar_district'],
      auditDueDt: json['audit_due_dt'],
      siteDomainName: json['site_domain_name'],
      status: json['status'],
      // Common fields
      district: json['district'],
      clientName: json['client_name'] ?? '',
      siteCode: json['site_code'] ?? '',
      siteName: json['site_name'] ?? '',
      siteTypeName: json['site_type_name'] ?? '',
      makerSelfieImageId: json['maker_selfie_image_id'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'site_audit_sch_id': siteAuditSchId,
      // Telecom fields
      'circle': circle,
      'cluster': cluster,
      'indoor_outdoor': indoorOutdoor,
      'eb_non_eb': ebNonEb,
      'op1_name': op1Name,
      'op2_name': op2Name,
      'site_id': siteId,
      // Solar fields
      'solar_state': solarState,
      'solar_district': solarDistrict,
      'audit_due_dt': auditDueDt,
      'site_domain_name': siteDomainName,
      'status': status,
      // Common fields
      'district': district,
      'client_name': clientName,
      'site_code': siteCode,
      'site_name': siteName,
      'site_type_name': siteTypeName,
      'maker_selfie_image_id': makerSelfieImageId,
    };
  }
}

class ResponseData {
  final Map<String, CategoryData> categories;

  ResponseData({
    required this.categories,
  });

  factory ResponseData.fromJson(Map<String, dynamic> json) {
    Map<String, CategoryData> categories = {};
    
    json.forEach((key, value) {
      if (value is Map<String, dynamic>) {
        // This is a category with assets/remarks/subcategories
        categories[key] = CategoryData.fromJson(value);
      } else if (value is List) {
        // This is a direct array (like "Boundary")
        // Create a CategoryData with empty assets/remarks but the list as subcategories
        categories[key] = CategoryData(
          assets: [],
          remarks: [],
          subCategories: {key: value.map((item) => AssetItem.fromJson(item)).toList()},
        );
      }
    });
    
    return ResponseData(categories: categories);
  }

  Map<String, dynamic> toJson() {
    Map<String, dynamic> result = {};
    categories.forEach((key, value) {
      result[key] = value.toJson();
    });
    return result;
  }

  factory ResponseData.empty() {
    return ResponseData(categories: {});
  }

  // Helper methods to get specific categories
  // Telecom categories
  CategoryData? get dg => categories['DG'];
  CategoryData? get ccu => categories['CCU'];
  CategoryData? get battery => categories['Battery'];
  CategoryData? get fencing => categories['Boundary'];
  
  // Solar categories
  CategoryData? get solarPlates => categories['Solar Plates'];
  CategoryData? get fireExtinguisher => categories['Fire Extinguisher'];
  CategoryData? get smps => categories['SMPS'];
  CategoryData? get cctv => categories['CCTV'];
  CategoryData? get boundary => categories['Boundary'];
  CategoryData? get spv => categories['SPV'];
  CategoryData? get dcdb => categories['DCDB'];
  CategoryData? get transformer => categories['Transformer'];
  CategoryData? get vcb => categories['VCB'];
  CategoryData? get ltdb => categories['LTDB'];
  CategoryData? get invertor => categories['Invertor'];
  CategoryData? get wms => categories['WMS'];
  CategoryData? get scada => categories['SCADA'];
  CategoryData? get acdb => categories['ACDB'];
  CategoryData? get pcu => categories['PCU'];
  CategoryData? get mms => categories['MMS'];

  // Helper methods to get specific items from categories
  List<AssetItem> get boundaryItems => getAllItemsFromCategory('Boundary');

  // Helper method to get all assets from a category
  List<AssetItem> getAllAssetsFromCategory(String categoryName) {
    final category = categories[categoryName];
    if (category == null) return [];
    
    List<AssetItem> allAssets = [];
    allAssets.addAll(category.assets);
    
    if (category.subCategories != null) {
      category.subCategories!.forEach((key, assets) {
        allAssets.addAll(assets);
      });
    }
    
    return allAssets;
  }

  // Helper method to get all remarks from a category
  List<AssetItem> getAllRemarksFromCategory(String categoryName) {
    final category = categories[categoryName];
    return category?.remarks ?? [];
  }

  // Helper method to get all items from a category (including subcategories)
  List<AssetItem> getAllItemsFromCategory(String categoryName) {
    final category = categories[categoryName];
    if (category == null) return [];
    
    List<AssetItem> allItems = [];
    allItems.addAll(category.assets);
    
    if (category.subCategories != null) {
      category.subCategories!.forEach((key, items) {
        allItems.addAll(items);
      });
    }
    
    return allItems;
  }
}

class CategoryData {
  final List<AssetItem> assets;
  final List<AssetItem> remarks;
  final Map<String, List<AssetItem>>? subCategories;

  CategoryData({
    required this.assets,
    this.remarks = const [],
    this.subCategories,
  });

  factory CategoryData.fromJson(Map<String, dynamic> json) {
    List<AssetItem> assets = [];
    List<AssetItem> remarks = [];
    Map<String, List<AssetItem>>? subCategories;

    json.forEach((key, value) {
      if (key == 'assets' && value is List) {
        assets = value.map((item) => AssetItem.fromJson(item)).toList();
      } else if (key == 'remarks' && value is List) {
        remarks = value.map((item) => AssetItem.fromJson(item)).toList();
      } else if (value is List) {
        // This is a subcategory
        subCategories ??= {};
        subCategories?[key] = value.map((item) => AssetItem.fromJson(item)).toList();
      }
    });

    return CategoryData(
      assets: assets,
      remarks: remarks,
      subCategories: subCategories,
    );
  }

  Map<String, dynamic> toJson() {
    Map<String, dynamic> result = {
      'assets': assets.map((item) => item.toJson()).toList(),
      'remarks': remarks.map((item) => item.toJson()).toList(),
    };

    if (subCategories != null) {
      subCategories!.forEach((key, value) {
        result[key] = value.map((item) => item.toJson()).toList();
      });
    }

    return result;
  }

  // Helper methods to get subcategories
  // Telecom subcategories
  List<AssetItem>? get ccuCabinet => subCategories?['CCU Cabinet'];
  List<AssetItem>? get ccuRectifiers => subCategories?['CCU Rectifiers'];
  List<AssetItem>? get ccuMppt => subCategories?['CCU MPPT'];
  List<AssetItem>? get batteryCabinet => subCategories?['Battery Cabinet'];
  List<AssetItem>? get cbms => subCategories?['CBMS'];
  List<AssetItem>? get lspu => subCategories?['LSPU'];
  
  // Solar subcategories
  List<AssetItem>? get smpsRectifiers => subCategories?['SMPS Rectifiers'];
  List<AssetItem>? get smpsMppt => subCategories?['SMPS MPPT'];
  List<AssetItem>? get smpsCabinet => subCategories?['SMPS Cabinet'];
  List<AssetItem>? get acdb => subCategories?['ACDB'];
  List<AssetItem>? get floodLight => subCategories?['Flood Light'];
  List<AssetItem>? get sandBucket => subCategories?['Sand Bucket'];
  List<AssetItem>? get spv => subCategories?['SPV'];
  List<AssetItem>? get boundary => subCategories?['Boundary'];
  List<AssetItem>? get boundaryItems => subCategories?['Boundary'];

  // Helper method to get all assets including subcategories
  List<AssetItem> getAllAssets() {
    List<AssetItem> allAssets = [];
    allAssets.addAll(assets);
    
    if (subCategories != null) {
      subCategories!.forEach((key, assets) {
        allAssets.addAll(assets);
      });
    }
    
    return allAssets;
  }

  // Helper method to check if category has any data
  bool get hasData => assets.isNotEmpty || (subCategories?.isNotEmpty ?? false) || remarks.isNotEmpty;
}

class AssetItem {
  final int assetAuditSiteRespId;
  final int siteAuditSchId;
  final int? itemInstanceId;
  final String? itemType;
  final String? oemName;
  final String? nexgenSerialNo;
  final String? mfgSerialNo;
  final bool? qrCodeScanned;
  final String? qrCodeScannedTs;
  final int? photoId;
  final String? imageName;
  final String? longitude;
  final String? latitude;
  final String? assetStatus;
  final String? capacity;
  final String? itemTypeGroup;
  final String? recordType;
  final String? itemTypeRemark;

  AssetItem({
    required this.assetAuditSiteRespId,
    required this.siteAuditSchId,
    this.itemInstanceId,
    this.itemType,
    this.oemName,
    this.nexgenSerialNo,
    this.mfgSerialNo,
    this.qrCodeScanned,
    this.qrCodeScannedTs,
    this.photoId,
    this.imageName,
    this.longitude,
    this.latitude,
    this.assetStatus,
    this.capacity,
    this.itemTypeGroup,
    this.recordType,
    this.itemTypeRemark,
  });

  factory AssetItem.fromJson(Map<String, dynamic> json) {
    return AssetItem(
      assetAuditSiteRespId: json['asset_audit_site_resp_id'] ?? 0,
      siteAuditSchId: json['site_audit_sch_id'] ?? 0,
      itemInstanceId: json['item_instance_id'],
      itemType: json['item_type'],
      oemName: json['oem_name'],
      nexgenSerialNo: json['nexgen_serial_no'],
      mfgSerialNo: json['mfg_serial_no'],
      qrCodeScanned: json['qr_code_scanned'],
      qrCodeScannedTs: json['qr_code_scanned_ts'],
      photoId: json['photo_id'],
      imageName: json['image_name'],
      longitude: json['longitude'],
      latitude: json['latitude'],
      assetStatus: json['asset_status'],
      capacity: json['capacity'],
      itemTypeGroup: json['item_type_group'],
      recordType: json['record_type'],
      itemTypeRemark: json['item_type_remark'],
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
      'item_type_group': itemTypeGroup,
      'record_type': recordType,
      'item_type_remark': itemTypeRemark,
    };
  }
}
