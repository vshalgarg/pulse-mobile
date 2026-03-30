import 'package:equatable/equatable.dart';

/// Single project row from PMIS dashboard project-list API.
class PmisProject extends Equatable {
  final int pmId;
  final String projectName;
  final int totalActivities;
  final int completedActivities;
  final int completionPercentage;
  final String status;
  final String growth;
  final String growthColor;

  const PmisProject({
    required this.pmId,
    required this.projectName,
    required this.totalActivities,
    required this.completedActivities,
    required this.completionPercentage,
    required this.status,
    required this.growth,
    required this.growthColor,
  });

  factory PmisProject.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic value) =>
        int.tryParse(value?.toString() ?? '') ?? 0;
    String parseString(dynamic value) => value?.toString() ?? '';

    return PmisProject(
      pmId: parseInt(json['pm_id']),
      projectName: parseString(json['project_name']),
      totalActivities:
          parseInt(json['total_activities']),
      completedActivities:
          parseInt(json['completed_activities']),
      // API key change:
      // - completion_percentage -> completion_pct
      // - status -> schedule_status
      // - growth -> progress_delta_value
      // - growth_color -> progress_delta_color
      completionPercentage: parseInt(
        json['completion_pct'] ?? json['completion_percentage'],
      ),
      status: parseString(
        json['schedule_status'] ?? json['status'],
      ),
      growth: parseString(
        json['progress_delta_value'] ?? json['growth'],
      ),
      growthColor: parseString(
        json['progress_delta_color'] ?? json['growth_color'],
      ),
    );
  }

  Map<String, dynamic> toJson() => {
        'pm_id': pmId,
        'project_name': projectName,
        'total_activities': totalActivities,
        'completed_activities': completedActivities,
        // Keep old names for serialization (not used by your UI).
        'completion_percentage': completionPercentage,
        'status': status,
        'growth': growth,
        'growth_color': growthColor,
      };

  @override
  List<Object?> get props => [
        pmId,
        projectName,
        totalActivities,
        completedActivities,
        completionPercentage,
        status,
        growth,
        growthColor,
      ];
}
