class RaiseTicketAssignedTo {
  final int userMstId;
  final String fullName;
  final int entityId;
  final String roleName;

  const RaiseTicketAssignedTo({
    required this.userMstId,
    required this.fullName,
    required this.entityId,
    required this.roleName,
  });

  factory RaiseTicketAssignedTo.fromJson(Map<String, dynamic> json) {
    return RaiseTicketAssignedTo(
      userMstId: int.tryParse(json['user_mst_id']?.toString() ?? '') ?? 0,
      fullName: json['full_name']?.toString() ?? '',
      entityId: int.tryParse(json['entity_id']?.toString() ?? '') ?? 0,
      roleName: json['role_name']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_mst_id': userMstId,
      'full_name': fullName,
      'entity_id': entityId,
      'role_name': roleName,
    };
  }
}
