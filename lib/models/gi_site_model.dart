class GISite {
  final int siteId;
  final int entityId;
  final String siteCode;
  final String siteName;
  final int clusterDistrictId;
  final String clusterDistrictName;
  final int circleStateId;
  final String circleStateName;
  final int? clientId;
  final String? clientName;
  final String? infraEngineerID;
  final String? infraEngineerName;
  final String? infraEngineerPhone;
  final String? ownerName;
  final String? ownerPhone;
  
  


  GISite({
    required this.siteId,
    required this.entityId,
    required this.siteCode,
    required this.siteName,
    required this.clusterDistrictId,
    required this.clusterDistrictName,
    required this.circleStateId,
    required this.circleStateName,
    this.clientId,
    this.clientName,
    this.infraEngineerID,
    this.infraEngineerName,
    this.infraEngineerPhone,
    this.ownerName,
    this.ownerPhone,
  });

  factory GISite.fromJson(Map<String, dynamic> json) {
    print('🔄 [CMSite] Parsing JSON: $json');
    
    final siteId = json['site_id'] ?? 0;
    final siteName = json['site_name']?.toString() ?? '';
    final siteCode = json['site_code']?.toString() ?? '';
 
    return GISite(
      siteId: siteId,
      entityId: json['entity_id'] ?? 0,
      siteCode: siteCode,
      siteName: siteName,
      clusterDistrictId: json['cluster_district_id'] ?? 0,
      clusterDistrictName: json['cluster_district_name']?.toString() ?? '',
      circleStateId: json['circle_state_id'] ?? 0,
      circleStateName: json['circle_state_name']?.toString() ?? '',
      clientId: json['client_id'],
      clientName: json['client_name']?.toString(),
      infraEngineerID: json['infra_engineer_id']?.toString() ?? '',
      infraEngineerName: json['infra_engineer_name']?.toString() ?? '',
      infraEngineerPhone: json['infra_engineer_phone']?.toString() ?? '',
      ownerName: json['owner_name']?.toString() ?? '',
      ownerPhone: json['owner_phone']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'site_id': siteId,
      'entity_id': entityId,
      'site_code': siteCode,
      'site_name': siteName,
      'cluster_district_id': clusterDistrictId,
      'cluster_district_name': clusterDistrictName,
      'circle_state_id': circleStateId,
      'circle_state_name': circleStateName,
      'client_id': clientId,
      'client_name': clientName,
      'infra_engineer_id': infraEngineerID,
      'infra_engineer_name': infraEngineerName,
      'infra_engineer_phone': infraEngineerPhone,
      'owner_name': ownerName,
      'owner_phone': ownerPhone,
    };
  }

  @override
  String toString() {
    return 'CMSite{siteId: $siteId, siteName: "$siteName", siteCode: "$siteCode"}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is GISite && other.siteId == siteId;
  }

  @override
  int get hashCode => siteId.hashCode;
}