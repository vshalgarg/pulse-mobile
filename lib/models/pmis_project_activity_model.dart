import 'package:equatable/equatable.dart';

class PmisProjectActivity extends Equatable {
  final String siteName;
  final String moduleName;
  final String subModuleName;
  final String activityName;
  final String currentStatus;
  final String status;
  final String plannedStartDt;
  final String plannedEndDt;
  final String? actualStartDt;
  final String? actualEndDt;
  final bool isGeoFenced;
  final String state;
  final String distanceKm;
  final int? distanceM;
  final double? latitude;
  final double? longitude;

  /// Activity ticket id for `pmis/api/v1/project-plan/activity-ticket/{atId}`.
  final int? atId;

  const PmisProjectActivity({
    required this.siteName,
    required this.moduleName,
    required this.subModuleName,
    required this.activityName,
    required this.currentStatus,
    required this.status,
    required this.plannedStartDt,
    required this.plannedEndDt,
    required this.actualStartDt,
    required this.actualEndDt,
    required this.isGeoFenced,
    required this.state,
    required this.distanceKm,
    required this.distanceM,
    this.latitude,
    this.longitude,
    this.atId,
  });

  factory PmisProjectActivity.fromJson(Map<String, dynamic> json) {
    int? parseIntNullable(dynamic value) {
      if (value == null) return null;
      return int.tryParse(value.toString());
    }
    double? parseDoubleNullable(dynamic value) {
      if (value == null) return null;
      return double.tryParse(value.toString());
    }

    final int? atId = parseIntNullable(
      json['atId'] ??
          json['at_id'] ??
          json['activityTicketId'] ??
          json['activity_ticket_id'],
    );

    return PmisProjectActivity(
      siteName: (json['site_name'] ?? '').toString(),
      moduleName: (json['module_name'] ?? '').toString(),
      subModuleName: (json['sub_module_name'] ?? '').toString(),
      activityName: (json['activity_name'] ?? '').toString(),
      currentStatus: (json['current_status'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      plannedStartDt: (json['planned_start_dt'] ?? '').toString(),
      plannedEndDt: (json['planned_end_dt'] ?? '').toString(),
      actualStartDt: json['actual_start_dt'] == null
          ? null
          : json['actual_start_dt'].toString(),
      actualEndDt: json['actual_end_dt'] == null ? null : json['actual_end_dt'].toString(),
      isGeoFenced: json['is_geo_fenced'] == true,
      state: (json['state'] ?? '').toString(),
      distanceKm: (json['distance_km'] ?? '').toString(),
      distanceM: parseIntNullable(json['distance_m']),
      latitude: parseDoubleNullable(
        json['latitude'] ?? json['lat'] ?? json['site_latitude'],
      ),
      longitude: parseDoubleNullable(
        json['longitude'] ??
            json['lng'] ??
            json['long'] ??
            json['site_longitude'],
      ),
      atId: atId,
    );
  }

  @override
  List<Object?> get props => [
        siteName,
        moduleName,
        subModuleName,
        activityName,
        currentStatus,
        status,
        plannedStartDt,
        plannedEndDt,
        actualStartDt,
        actualEndDt,
        isGeoFenced,
        state,
        distanceKm,
        distanceM,
        latitude,
        longitude,
        atId,
      ];
}

