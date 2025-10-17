class NotificationModel {
  final int? createdby;
  final String? createddt;
  final int? modifiedby;
  final String? modifieddt;
  final int? tenantId;
  final int? ntId;
  final String? notifyDt;
  final int? senderUserId;
  final int? receiverUserId;
  final int? receiverGroupId;
  final String? isUniversal;
  final String? notificationType;
  final String? heading;
  final String? message;
  final int? nsId;
  final String? priority;
  final String? pageLink;
  final String? notifiedDt;
  final String? bellDt;
  final String? seenDt;
  final String? notiStatusDt;
  final String? snoozeTime;
  final String? snoozeDt;
  final bool? isActive;
  final String? remarks;
  final String? formName;
  final String? operation;
  final String? tabName;
  final String? formPkId;
  final String? formPkId2;
  final String? formPkId3;

  NotificationModel({
    this.createdby,
    this.createddt,
    this.modifiedby,
    this.modifieddt,
    this.tenantId,
    this.ntId,
    this.notifyDt,
    this.senderUserId,
    this.receiverUserId,
    this.receiverGroupId,
    this.isUniversal,
    this.notificationType,
    this.heading,
    this.message,
    this.nsId,
    this.priority,
    this.pageLink,
    this.notifiedDt,
    this.bellDt,
    this.seenDt,
    this.notiStatusDt,
    this.snoozeTime,
    this.snoozeDt,
    this.isActive,
    this.remarks,
    this.formName,
    this.operation,
    this.tabName,
    this.formPkId,
    this.formPkId2,
    this.formPkId3,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      createdby: json['createdby'],
      createddt: json['createddt'],
      modifiedby: json['modifiedby'],
      modifieddt: json['modifieddt'],
      tenantId: json['tenantId'],
      ntId: json['ntId'],
      notifyDt: json['notifyDt'],
      senderUserId: json['senderUserId'],
      receiverUserId: json['receiverUserId'],
      receiverGroupId: json['receiverGroupId'],
      isUniversal: json['isUniversal'],
      notificationType: json['notificationType'],
      heading: json['heading'],
      message: json['message'],
      nsId: json['nsId'],
      priority: json['priority'],
      pageLink: json['pageLink'],
      notifiedDt: json['notifiedDt'],
      bellDt: json['bellDt'],
      seenDt: json['seenDt'],
      notiStatusDt: json['notiStatusDt'],
      snoozeTime: json['snoozeTime'],
      snoozeDt: json['snoozeDt'],
      isActive: json['isActive'],
      remarks: json['remarks'],
      formName: json['formName'],
      operation: json['operation'],
      tabName: json['tabName'],
      formPkId: json['formPkId'],
      formPkId2: json['formPkId2'],
      formPkId3: json['formPkId3'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'createdby': createdby,
      'createddt': createddt,
      'modifiedby': modifiedby,
      'modifieddt': modifieddt,
      'tenantId': tenantId,
      'ntId': ntId,
      'notifyDt': notifyDt,
      'senderUserId': senderUserId,
      'receiverUserId': receiverUserId,
      'receiverGroupId': receiverGroupId,
      'isUniversal': isUniversal,
      'notificationType': notificationType,
      'heading': heading,
      'message': message,
      'nsId': nsId,
      'priority': priority,
      'pageLink': pageLink,
      'notifiedDt': notifiedDt,
      'bellDt': bellDt,
      'seenDt': seenDt,
      'notiStatusDt': notiStatusDt,
      'snoozeTime': snoozeTime,
      'snoozeDt': snoozeDt,
      'isActive': isActive,
      'remarks': remarks,
      'formName': formName,
      'operation': operation,
      'tabName': tabName,
      'formPkId': formPkId,
      'formPkId2': formPkId2,
      'formPkId3': formPkId3,
    };
  }
}
