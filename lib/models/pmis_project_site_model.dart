import 'package:equatable/equatable.dart';

/// Single site row from PMIS project-site-list API.
class PmisProjectSite extends Equatable {
  final int siteId;
  final String siteName;
  final String siteCode;
  final String distanceKm;
  final int? distanceM;
  final int completionPct;
  final String scheduleStatus;

  const PmisProjectSite({
    required this.siteId,
    required this.siteName,
    required this.siteCode,
    required this.distanceKm,
    required this.distanceM,
    required this.completionPct,
    required this.scheduleStatus,
  });

  factory PmisProjectSite.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic value) => int.tryParse(value?.toString() ?? '') ?? 0;
    String parseString(dynamic value) => value?.toString() ?? '';

    final dm = json['distance_m'];
    int? distanceMeters;
    if (dm != null) {
      distanceMeters = int.tryParse(dm.toString());
    }

    return PmisProjectSite(
      siteId: parseInt(json['site_id']),
      siteName: parseString(json['site_name']),
      siteCode: parseString(json['site_code']),
      distanceKm: parseString(json['distance_km']),
      distanceM: distanceMeters,
      completionPct: parseInt(json['completion_pct']),
      scheduleStatus: parseString(json['schedule_status']),
    );
  }

  @override
  List<Object?> get props => [
        siteId,
        siteName,
        siteCode,
        distanceKm,
        distanceM,
        completionPct,
        scheduleStatus,
      ];
}
