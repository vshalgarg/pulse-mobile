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
  final String? infraEngineerName;
  final String? infraEngineerPhone;
  final String? ownerName;
  final String? ownerPhone;

  final String? siteVisitLogId;
  final String? siteVisitLogDate;
  final String? purposeOfVisit;
  final String? visitingPersonImageId;

  final String? svlId;

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
    this.infraEngineerName,
    this.infraEngineerPhone,
    this.ownerName,
    this.ownerPhone,
    this.siteVisitLogId,
    this.siteVisitLogDate,
    this.purposeOfVisit,
    this.visitingPersonImageId,
    this.svlId,
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
      infraEngineerName: json['infra_district_engineer_name']?.toString() ?? '',
      infraEngineerPhone:
          json['infra_district_engineer_contact_no']?.toString() ?? '',
      ownerName: json['owner_name']?.toString() ?? '',
      ownerPhone: json['owner_contact_no']?.toString() ?? '',

      // site visit log data
      siteVisitLogId: json['site_visit_log_id'] != null
          ? json['site_visit_log_id'].toString()
          : null,
      siteVisitLogDate: json['site_visit_log_date'] != null
          ? json['site_visit_log_date'].toString()
          : null,
      purposeOfVisit: json['purpose_of_visit'] != null
          ? json['purpose_of_visit'].toString()
          : null,
      visitingPersonImageId: json['visiting_person_image_id'] != null
          ? json['visiting_person_image_id'].toString()
          : null,

      svlId: json['svl_id'] != null
          ? json['svl_id'].toString()
          : null,
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
      'site_visit_log_id': siteVisitLogId,
      'site_visit_log_date': siteVisitLogDate,
      'purpose_of_visit': purposeOfVisit,
      'visiting_person_image_id': visitingPersonImageId,
      'svl_id': svlId,
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
