class UpdateAuditScheduleStatusRequest {
  final String status;
  final String siteAuditSchId;

  UpdateAuditScheduleStatusRequest({
    required this.status,
    required this.siteAuditSchId,
  });

  Map<String, String> toFormData() {
    return {
      'status': status,
      'siteAuditSchId': siteAuditSchId,
    };
  }
}

class UpdateAuditScheduleStatusResponse {
  final String message;

  UpdateAuditScheduleStatusResponse({
    required this.message,
  });

  factory UpdateAuditScheduleStatusResponse.fromJson(Map<String, dynamic> json) {
    return UpdateAuditScheduleStatusResponse(
      message: json['message'] ?? '',
    );
  }
}
