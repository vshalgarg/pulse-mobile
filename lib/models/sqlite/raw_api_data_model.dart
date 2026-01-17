import 'package:app/enum/activity_type_enum.dart';

class RawApiDataModel {
  final String siteAuditSchId;
  final String siteType;
  final String auditSchId;
  final ActivityTypeEnum activityType;
  final String pvTicketId;
  final String siteCode;
  final String cluster;
  final String operator;
  final String raisedDt;
  final String dueDt;
  final String status;
  final bool isDownloaded;
  final double latitude;
  final double longitude;
  final Map<String, dynamic> apiData;

  RawApiDataModel({
    required this.siteAuditSchId,
    required this.siteType,
    required this.auditSchId,
    required this.activityType,
    required this.pvTicketId,
    required this.siteCode,
    required this.cluster,
    required this.operator,
    required this.raisedDt,
    required this.dueDt,
    required this.status,
    required this.isDownloaded,
    required this.latitude,
    required this.longitude,
    required this.apiData,
  });

  /// Create RawApiDataModel from Map
  factory RawApiDataModel.fromMap(Map<String, dynamic> map) {
    return RawApiDataModel(
      siteAuditSchId: map['site_audit_sch_id'] as String,
      siteType: map['site_type'] as String,
      auditSchId: map['audit_sch_id'] as String,
      activityType: ActivityTypeEnum.fromString(map['activity_type'] as String),
      pvTicketId: map['pv_ticket_id'] as String,
      siteCode: map['site_code'] as String,
      cluster: map['cluster'] as String,
      operator: map['operator'] as String,
      raisedDt: map['raised_dt'] as String,
      dueDt: map['due_dt'] as String,
      status: map['status'] as String,
      isDownloaded: (map['is_downloaded'] as int) == 1,
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      apiData: map['api_data'] as Map<String, dynamic>,
    );
  }

  /// Convert RawApiDataModel to Map
  Map<String, dynamic> toMap() {
    return {
      'site_audit_sch_id': siteAuditSchId,
      'site_type': siteType,
      'audit_sch_id': auditSchId,
      'activity_type': activityType.value,
      'pv_ticket_id': pvTicketId,
      'site_code': siteCode,
      'cluster': cluster,
      'operator': operator,
      'raised_dt': raisedDt,
      'due_dt': dueDt,
      'status': status,
      'is_downloaded': isDownloaded ? 1 : 0,
      'latitude': latitude,
      'longitude': longitude,
      'api_data': apiData,
    };
  }

  @override
  String toString() {
    return 'RawApiDataModel(siteAuditSchId: $siteAuditSchId, siteType: $siteType, auditSchId: $auditSchId, activityType: $activityType, isDownloaded: $isDownloaded, latitude: $latitude, longitude: $longitude)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RawApiDataModel &&
        other.siteAuditSchId == siteAuditSchId &&
        other.siteType == siteType &&
        other.auditSchId == auditSchId &&
        other.activityType == activityType &&
        other.isDownloaded == isDownloaded &&
        other.latitude == latitude &&
        other.longitude == longitude;
  }

  @override
  int get hashCode {
    return siteAuditSchId.hashCode ^
        siteType.hashCode ^
        auditSchId.hashCode ^
        activityType.hashCode ^
        isDownloaded.hashCode ^
        latitude.hashCode ^
        longitude.hashCode;
  }
}
