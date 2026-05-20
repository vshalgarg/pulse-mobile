class RaiseItTicketStatus {
  final int iaismId;
  final String statusCode;
  final int tenantMstId;

  const RaiseItTicketStatus({
    required this.iaismId,
    required this.statusCode,
    required this.tenantMstId,
  });

  factory RaiseItTicketStatus.fromJson(Map<String, dynamic> json) {
    return RaiseItTicketStatus(
      iaismId: int.tryParse(
            json['iaism_id']?.toString() ?? json['iaismId']?.toString() ?? '',
          ) ??
          0,
      statusCode: json['status_code']?.toString() ??
          json['statusCode']?.toString() ??
          '',
      tenantMstId: int.tryParse(
            json['tenant_mst_id']?.toString() ??
                json['tenantMstId']?.toString() ??
                '',
          ) ??
          0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'iaism_id': iaismId,
      'status_code': statusCode,
      'tenant_mst_id': tenantMstId,
    };
  }
}
