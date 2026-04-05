import 'package:equatable/equatable.dart';

/// Single sub-module row from PMIS `project-submodule-list` API.
class PmisProjectSubModule extends Equatable {
  final int ppsmId;
  final String subModuleName;
  final int completionPct;
  final String scheduleStatus;
  final String progressDeltaValue;
  final String progressDeltaColor;

  const PmisProjectSubModule({
    required this.ppsmId,
    required this.subModuleName,
    required this.completionPct,
    required this.scheduleStatus,
    required this.progressDeltaValue,
    required this.progressDeltaColor,
  });

  factory PmisProjectSubModule.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic value) => int.tryParse(value?.toString() ?? '') ?? 0;
    String parseString(dynamic value) => value?.toString() ?? '';

    return PmisProjectSubModule(
      ppsmId: parseInt(json['ppsm_id']),
      subModuleName: parseString(json['sub_module_name']),
      completionPct: parseInt(json['completion_pct']),
      scheduleStatus: parseString(json['schedule_status']),
      progressDeltaValue: parseString(json['progress_delta_value']),
      progressDeltaColor: parseString(json['progress_delta_color']),
    );
  }

  @override
  List<Object?> get props => [
        ppsmId,
        subModuleName,
        completionPct,
        scheduleStatus,
        progressDeltaValue,
        progressDeltaColor,
      ];
}
