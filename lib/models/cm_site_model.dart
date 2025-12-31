class CMSite {
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
  final String? infraEngineerName;
  final String? infraEngineerContactNo;
  final String? clusterInchargeName;
  final String? clusterInchargeContactNo;
  final String? category;

  CMSite({
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
    this.infraEngineerName,
    this.infraEngineerContactNo,
    this.clusterInchargeName,
    this.clusterInchargeContactNo,
    this.category,
  });

  factory CMSite.fromJson(Map<String, dynamic> json) {

    final siteId = json['site_id'] ?? 0;
    final siteName = json['site_name']?.toString() ?? '';
    final siteCode = json['site_code']?.toString() ?? '';

    return CMSite(
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
      infraEngineerName: json['infra_engineer_name']?.toString() ?? json['infraEngineerName']?.toString(),
      infraEngineerContactNo: json['infra_engineer_contact_no']?.toString() ?? json['infraEngineerContactNo']?.toString(),
      clusterInchargeName: json['cluster_incharge_name']?.toString() ?? json['clusterInchargeName']?.toString(),
      clusterInchargeContactNo: json['cluster_incharge_contact_no']?.toString() ?? json['clusterInchargeContactNo']?.toString(),
      category: json['category']?.toString(),
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
      'infra_engineer_name': infraEngineerName,
      'infra_engineer_contact_no': infraEngineerContactNo,
      'cluster_incharge_name': clusterInchargeName,
      'cluster_incharge_contact_no': clusterInchargeContactNo,
      'category': category,
    };
  }

  @override
  String toString() {
    return 'CMSite{siteId: $siteId, siteName: "$siteName", siteCode: "$siteCode"}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CMSite && other.siteId == siteId;
  }

  @override
  int get hashCode => siteId.hashCode;
}