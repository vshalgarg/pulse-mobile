import 'dart:convert';

import 'gen_ins_checklist_model.dart';

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
  final String? officialIdImageId;
  final String? aadharCardImageId;
  final String? leavingStatusImageId;
  final List<GenInsCheckListData>? checklistItems;

  final String? visitorName;
  final String? visitorContactNo;
  final String? organisationName;
  final int? orgId;
  final String? roleDesignation;
  final String? reportingManager;

  final String? svlId;
  final String? giId;

  final String? lastPMDate;
  final String? lastCMDate;
  final String? installedAssetDetails;
  final String? clusterInchargeName;
  final String? clusterInchargeContactNo;
  final String? lastGIReportDate;
  final int? lastPMSiteAuditSchId;
  final int? lastPMAuditSchId;
  final int? lastCMSiteReqId;
  final String? lastAADate;
  final int? lastAASiteAuditSchId;
  final int? lastAAAuditSchId;

  final String? longitude;
  final String? latitude;

 


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
    this.officialIdImageId,
    this.aadharCardImageId,
    this.leavingStatusImageId,
    this.svlId,
    this.checklistItems,
    this.giId,

    this.visitorName,
    this.visitorContactNo,
    this.organisationName,
    this.orgId,
    this.roleDesignation,
    this.reportingManager,

    this.lastPMDate,
    this.lastCMDate,
    this.installedAssetDetails,
    this.clusterInchargeName,
    this.clusterInchargeContactNo,
    this.lastGIReportDate,
    this.lastPMSiteAuditSchId,
    this.lastPMAuditSchId,
    this.lastCMSiteReqId,
    this.lastAADate,
    this.lastAASiteAuditSchId,
    this.lastAAAuditSchId,

    this.longitude,
    this.latitude,
  });

  /// GI ticket GET payloads often use camelCase and `*SchdId` (e.g. `lastPmSiteAuditSchdId`).
  static String? _jsonStr(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final v = json[key];
      if (v != null) {
        final s = v.toString();
        if (s.isNotEmpty && s != 'null') return s;
      }
    }
    return null;
  }

  static int? _jsonInt(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final v = json[key];
      if (v == null) continue;
      if (v is int) return v;
      final p = int.tryParse(v.toString());
      if (p != null) return p;
    }
    return null;
  }

  /// Builds [AllSiteModel] from general-inspection `data` object (camelCase/snake_case, Sch/Schd ids).
  factory AllSiteModel.fromGeneralInspectionApi({
    required Map<String, dynamic> d,
    required int siteId,
    String? siteCodeFallback,
    String? siteNameFallback,
    String? clusterFallback,
    String? circleFallback,
    String? clientFallback,
    String? siteDomainName,
    List<GenInsCheckListData>? checklistItems,
  }) {
    return AllSiteModel(
      siteId: siteId,
      entityId: _jsonInt(d, ['entity_id', 'entityId']) ?? 0,
      siteCode: _jsonStr(d, ['site_code', 'siteCode']) ?? siteCodeFallback ?? '',
      siteName: _jsonStr(d, ['site_name', 'siteName']) ?? siteNameFallback ?? '',
      clusterDistrictId: _jsonInt(d, ['cluster_district_id', 'clusterDistrictId']) ?? 0,
      clusterDistrictName:
          _jsonStr(d, ['cluster_district_name', 'cluster']) ?? clusterFallback ?? '',
      circleStateId: _jsonInt(d, ['circle_state_id', 'circleStateId']) ?? 0,
      circleStateName:
          _jsonStr(d, ['circle_state_name', 'circle']) ?? circleFallback ?? '',
      clientId: _jsonInt(d, ['client_id', 'clientId']),
      clientName: _jsonStr(d, ['client_name', 'client']) ?? clientFallback,
      oem: _jsonStr(d, ['oem']),
      oemId: _jsonInt(d, ['oem_id', 'oemId']),
      self: '',
      selfId: 0,
      siteDomainName: siteDomainName ?? _jsonStr(d, ['site_domain_name', 'siteDomainName']),
      distanceKM: _jsonStr(d, ['distance_km', 'distanceKM']),
      infraEngineerName: _jsonStr(d, [
        'infra_district_engineer_name',
        'infraDistrictEngineerName',
      ]),
      infraEngineerPhone: _jsonStr(d, [
        'infra_district_engineer_contact_no',
        'infraDistrictEngineerContactNo',
      ]),
      ownerName: _jsonStr(d, ['owner_name', 'ownerName']),
      ownerPhone: _jsonStr(d, ['owner_contact_no', 'ownerContactNo']),
      visitorName: _jsonStr(d, ['visitor_name', 'visitorName']),
      visitorContactNo: _jsonStr(d, ['visitor_contact_no', 'visitorContactNo']),
      organisationName: _jsonStr(d, ['organisation_name', 'organisationName']),
      orgId: _jsonInt(d, ['org_id', 'orgId']),
      roleDesignation: _jsonStr(d, ['role_designation', 'roleDesignation']),
      reportingManager: _jsonStr(d, ['reporting_manager', 'reportingManager']),
      lastPMDate: _jsonStr(d, ['last_pm_date', 'lastPmDate']),
      lastCMDate: _jsonStr(d, ['last_cm_date', 'lastCmDate']),
      installedAssetDetails:
          _jsonStr(d, ['installed_asset_details', 'installedAssetDetails']),
      clusterInchargeName:
          _jsonStr(d, ['cluster_incharge_name', 'clusterInchargeName']),
      clusterInchargeContactNo: _jsonStr(d, [
        'cluster_incharge_contact_no',
        'clusterInchargeContactNo',
      ]),
      lastGIReportDate: _jsonStr(d, ['last_gi_report_date', 'lastGIReportDate']),
      lastPMSiteAuditSchId: _jsonInt(d, [
        'last_pm_site_audit_sch_id',
        'lastPmSiteAuditSchId',
        'lastPmSiteAuditSchdId',
      ]),
      lastPMAuditSchId: _jsonInt(d, [
        'last_pm_audit_sch_id',
        'lastPmAuditSchId',
        'lastPmAuditSchdId',
      ]),
      lastCMSiteReqId: _jsonInt(d, [
        'last_cm_site_req_id',
        'lastCMSiteReqId',
        'last_cm_req_id',
        'lastCmReqId',
      ]),
      lastAADate: _jsonStr(d, ['last_aa_date', 'lastAaDate']),
      lastAASiteAuditSchId: _jsonInt(d, [
        'last_aa_site_audit_sch_id',
        'lastAaSiteAuditSchId',
        'lastAaSiteAuditSchdId',
      ]),
      lastAAAuditSchId: _jsonInt(d, [
        'last_aa_audit_sch_id',
        'lastAaAuditSchId',
        'lastAaAuditSchdId',
      ]),
      siteVisitLogId: _jsonStr(d, ['site_visit_log_id', 'siteVisitLogId']),
      siteVisitLogDate: _jsonStr(d, ['site_visit_log_date', 'siteVisitLogDate']),
      purposeOfVisit: _jsonStr(d, ['purpose_of_visit', 'purposeOfVisit']),
      visitingPersonImageId:
          _jsonStr(d, ['visiting_person_image_id', 'visitingPersonImageId']),
      officialIdImageId:
          _jsonStr(d, ['official_id_image_id', 'officialIdImageId']),
      aadharCardImageId:
          _jsonStr(d, ['aadhar_card_image_id', 'aadharCardImageId']),
      leavingStatusImageId:
          _jsonStr(d, ['leaving_status_image_id', 'leavingStatusImageId']),
      svlId: _jsonStr(d, ['svl_id', 'svlId']),
      checklistItems: checklistItems,
      giId: _jsonStr(d, ['gi_id', 'giId']),
      longitude: _parseLatLngString(d, 'longitude'),
      latitude: _parseLatLngString(d, 'latitude'),
    );
  }

  /// Merges [site_snapshot_json] (if set) over the SQLite row so offline GI matches
  /// the full all-sites API model, including PM/CM/AA ids the row may omit.
  factory AllSiteModel.fromDownloadedSiteSqliteRow(Map<String, dynamic> row) {
    final snap = row['site_snapshot_json'];
    if (snap is String && snap.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(snap) as Map<String, dynamic>;
        final merged = Map<String, dynamic>.from(row);
        merged.addAll(decoded);
        return AllSiteModel.fromJson(merged);
      } catch (_) {}
    }
    return AllSiteModel.fromJson(Map<String, dynamic>.from(row));
  }

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
      clientName: _jsonStr(json, [
        'client_name',
        'clientName',
        'operator_name',
        'operatorName',
      ]),
      oem: json['oem']?.toString(),
      oemId: json['oem_id'],
      self: json['self']?.toString() ?? '',
      selfId: json['self_id'] ?? 0,
      siteDomainName: json['site_domain_name']?.toString() ?? '',
      distanceKM: json['distance_km']?.toString() ?? '',
      infraEngineerName: _jsonStr(json, [
            'infra_district_engineer_name',
            'infraDistrictEngineerName',
          ]) ??
          '',
      infraEngineerPhone: _jsonStr(json, [
            'infra_district_engineer_contact_no',
            'infraDistrictEngineerContactNo',
          ]) ??
          '',
      ownerName: _jsonStr(json, ['owner_name', 'ownerName']) ?? '',
      ownerPhone: _jsonStr(json, ['owner_contact_no', 'ownerContactNo']) ?? '',
      visitorName: json['visitor_name']?.toString() ?? '',
      visitorContactNo: json['visitor_contact_no']?.toString() ?? '',
      organisationName: json['organisation_name']?.toString() ?? '',
      orgId: json['org_id'] != null ? (json['org_id'] is int ? json['org_id'] as int : int.tryParse(json['org_id'].toString())) : null,
      roleDesignation: json['role_designation']?.toString() ?? '',
      reportingManager: json['reporting_manager']?.toString() ?? '',
      lastPMDate: _jsonStr(json, ['last_pm_date', 'lastPmDate']),
      lastCMDate: _jsonStr(json, ['last_cm_date', 'lastCmDate']),
      installedAssetDetails: _jsonStr(json, [
        'installed_asset_details',
        'installedAssetDetails',
      ]),
      clusterInchargeName: _jsonStr(json, [
        'cluster_incharge_name',
        'clusterInchargeName',
        'clusterIncharge',
      ]),
      clusterInchargeContactNo: _jsonStr(json, [
        'cluster_incharge_contact_no',
        'clusterInchargeContactNo',
        'cluster_incharge_phone',
      ]),
      lastPMSiteAuditSchId: _jsonInt(json, [
        'last_pm_site_audit_sch_id',
        'lastPmSiteAuditSchId',
        'lastPmSiteAuditSchdId',
      ]),
      lastPMAuditSchId: _jsonInt(json, [
        'last_pm_audit_sch_id',
        'lastPmAuditSchId',
        'lastPmAuditSchdId',
      ]),
      lastCMSiteReqId: _jsonInt(json, [
        'last_cm_site_req_id',
        'lastCMSiteReqId',
        'last_cm_req_id',
        'lastCmReqId',
      ]),
      lastAADate: _jsonStr(json, ['last_aa_date', 'lastAaDate']),
      lastAASiteAuditSchId: _jsonInt(json, [
        'last_aa_site_audit_sch_id',
        'lastAaSiteAuditSchId',
        'lastAaSiteAuditSchdId',
      ]),
      lastAAAuditSchId: _jsonInt(json, [
        'last_aa_audit_sch_id',
        'lastAaAuditSchId',
        'lastAaAuditSchdId',
      ]),

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
      officialIdImageId: json['official_id_image_id'] != null
          ? json['official_id_image_id'].toString()
          : json['officialIdImageId'] != null
              ? json['officialIdImageId'].toString()
              : null,
      aadharCardImageId: json['aadhar_card_image_id'] != null
          ? json['aadhar_card_image_id'].toString()
          : json['aadharCardImageId'] != null
              ? json['aadharCardImageId'].toString()
              : null,
      leavingStatusImageId: json['leaving_status_image_id'] != null
          ? json['leaving_status_image_id'].toString()
          : json['leavingStatusImageId'] != null
              ? json['leavingStatusImageId'].toString()
              : null,

      svlId: json['svl_id'] != null
          ? json['svl_id'].toString()
          : null,

      checklistItems: json['checklist_items'] != null
          ? (json['checklist_items'] as List)
              .map((item) => GenInsCheckListData.fromJson(item))
              .toList()
          : null,
          giId: json['gi_id'] != null
          ? json['gi_id'].toString()
          : null,


      longitude: _parseLatLngString(json, 'longitude'),
      latitude: _parseLatLngString(json, 'latitude'),
    );
  }

  /// Parse latitude or longitude from JSON, supporting multiple common API key names.
  static String? _parseLatLngString(Map<String, dynamic> json, String which) {
    const latKeys = ['latitude', 'lat', 'site_latitude', 'site_lat'];
    const lngKeys = ['longitude', 'lng', 'lon', 'site_longitude', 'site_lng'];
    final keys = which == 'latitude' ? latKeys : lngKeys;
    for (final key in keys) {
      final v = json[key];
      if (v != null && v.toString().trim().isNotEmpty) return v.toString().trim();
    }
    return null;
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
      'official_id_image_id': officialIdImageId,
      'aadhar_card_image_id': aadharCardImageId,
      'leaving_status_image_id': leavingStatusImageId,
      'svl_id': svlId,
      'checklist_items': checklistItems?.map((item) => item.toJson()).toList(),
      'gi_id': giId,

      'visitor_name': visitorName,
      'visitor_contact_no': visitorContactNo,
      'organisation_name': organisationName,
      'org_id': orgId,
      'role_designation': roleDesignation,
      'reporting_manager': reportingManager,

      'last_pm_date': lastPMDate,
      'last_cm_date': lastCMDate,
      'installed_asset_details': installedAssetDetails,
      'cluster_incharge_name': clusterInchargeName,
      'cluster_incharge_contact_no': clusterInchargeContactNo,
      'last_pm_site_audit_sch_id': lastPMSiteAuditSchId,
      'last_pm_audit_sch_id': lastPMAuditSchId,
      'last_cm_site_req_id': lastCMSiteReqId,
      'last_aa_date': lastAADate,
      'last_aa_site_audit_sch_id': lastAASiteAuditSchId,
      'last_aa_audit_sch_id': lastAAAuditSchId,

      'longitude': longitude,
      'latitude': latitude,
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
