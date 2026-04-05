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
  /// When provided by API, used for maps / directions (same flow as [TicketCard]).
  final double? latitude;
  final double? longitude;

  const PmisProjectSite({
    required this.siteId,
    required this.siteName,
    required this.siteCode,
    required this.distanceKm,
    required this.distanceM,
    required this.completionPct,
    required this.scheduleStatus,
    this.latitude,
    this.longitude,
  });

  factory PmisProjectSite.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic value) => int.tryParse(value?.toString() ?? '') ?? 0;
    String parseString(dynamic value) => value?.toString() ?? '';
    double? parseDouble(dynamic value) =>
        value == null ? null : double.tryParse(value.toString());

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
      latitude: parseDouble(
        json['latitude'] ?? json['lat'] ?? json['site_latitude'],
      ),
      longitude: parseDouble(
        json['longitude'] ??
            json['lng'] ??
            json['long'] ??
            json['site_longitude'],
      ),
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
        latitude,
        longitude,
      ];
}
