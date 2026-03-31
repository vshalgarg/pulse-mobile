import 'package:equatable/equatable.dart';

class PmisProjectState extends Equatable {
  final int stateId;
  final String state;
  final int completionPct;
  final String scheduleStatus;
  final String progressDeltaValue;
  final String progressDeltaColor;

  const PmisProjectState({
    required this.stateId,
    required this.state,
    required this.completionPct,
    required this.scheduleStatus,
    required this.progressDeltaValue,
    required this.progressDeltaColor,
  });

  factory PmisProjectState.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic value) => int.tryParse(value?.toString() ?? '') ?? 0;
    String parseString(dynamic value) => value?.toString() ?? '';

    return PmisProjectState(
      stateId: parseInt(json['state_id']),
      state: parseString(json['state']),
      completionPct: parseInt(json['completion_pct']),
      scheduleStatus: parseString(json['schedule_status']),
      progressDeltaValue: parseString(json['progress_delta_value']),
      progressDeltaColor: parseString(json['progress_delta_color']),
    );
  }

  @override
  List<Object?> get props => [
        stateId,
        state,
        completionPct,
        scheduleStatus,
        progressDeltaValue,
        progressDeltaColor,
      ];
}
