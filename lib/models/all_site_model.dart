class AllSiteModel {
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
  final String? oem;
  final int? oemId;
  final String self;
  final int selfId;
  final String? siteDomainName;
  final String? distanceKM;

  AllSiteModel({
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
    this.oem,
    this.oemId,
    required this.self,
    required this.selfId,
    this.siteDomainName,
     this.distanceKM,
  });

  factory AllSiteModel.fromJson(Map<String, dynamic> json) {
    final siteId = json['site_id'] ?? 0;
    final siteName = json['site_name']?.toString() ?? '';
    final siteCode = json['site_code']?.toString() ?? '';

    

    return AllSiteModel(
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
      oem: json['oem']?.toString(),
      oemId: json['oem_id'],
      self: json['self']?.toString() ?? '',
      selfId: json['self_id'] ?? 0,
      siteDomainName: json['site_domain_name']?.toString() ?? '',
      distanceKM: json['distance_km']?.toString() ?? '',
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
      'oem': oem,
      'oem_id': oemId,
      'self': self,
      'self_id': selfId,
      'site_domain_name': siteDomainName,
      'distance_km': distanceKM,
    };
  }

  @override
  String toString() {
    return 'AllSiteModel{siteId: $siteId, siteName: "$siteName", siteCode: "$siteCode"}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AllSiteModel && other.siteId == siteId;
  }

  @override
  int get hashCode => siteId.hashCode;
}
