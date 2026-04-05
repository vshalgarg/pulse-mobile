import 'package:equatable/equatable.dart';

/// Single module row from PMIS `project-module-list` API.
class PmisProjectModule extends Equatable {
  final int ppmId;
  final String moduleName;
  final int completionPct;
  final String scheduleStatus;
  final String progressDeltaValue;
  final String progressDeltaColor;

  const PmisProjectModule({
    required this.ppmId,
    required this.moduleName,
    required this.completionPct,
    required this.scheduleStatus,
    required this.progressDeltaValue,
    required this.progressDeltaColor,
  });

  factory PmisProjectModule.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic value) => int.tryParse(value?.toString() ?? '') ?? 0;
    String parseString(dynamic value) => value?.toString() ?? '';

    return PmisProjectModule(
      ppmId: parseInt(json['ppm_id']),
      moduleName: parseString(json['module_name']),
      completionPct: parseInt(json['completion_pct']),
      scheduleStatus: parseString(json['schedule_status']),
      progressDeltaValue: parseString(json['progress_delta_value']),
      progressDeltaColor: parseString(json['progress_delta_color']),
    );
  }

  @override
  List<Object?> get props => [
        ppmId,
        moduleName,
        completionPct,
        scheduleStatus,
        progressDeltaValue,
        progressDeltaColor,
      ];
}
