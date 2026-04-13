import 'package:equatable/equatable.dart';

class PmisActivityTicketDetail extends Equatable {
  final int atId;
  final int ppaId;
  final String currentStatus;
  final String? currentStatusDt;
  final int? makerDesignationMstId;
  final int? makerUserMstId;
  final String? makerAssignedDt;
  final String? plannedStartDt;
  final String? plannedEndDt;
  final String? actualStartDt;
  final String? actualEndDt;
  final bool isActive;
  final String? remarks;
  final List<PmisTicketChecker> ticketCheckers;
  final List<PmisTicketFieldValue> ticketFieldValues;
  final List<PmisTicketAttachment> ticketAttachments;
  final String? makerUserName;
  final String? makerDesignationName;
  final List<PmisOldDataItem> oldData;
  final bool showReviewBtns;
  final String? checkerLvl;
  final String? role;
  final List<Map<String, dynamic>> ticketStatusHistory;
  final bool isRepeating;
  final String? repeatDt;
  final List<String> allowedStatuses;

  const PmisActivityTicketDetail({
    required this.atId,
    required this.ppaId,
    required this.currentStatus,
    required this.currentStatusDt,
    required this.makerDesignationMstId,
    required this.makerUserMstId,
    required this.makerAssignedDt,
    required this.plannedStartDt,
    required this.plannedEndDt,
    required this.actualStartDt,
    required this.actualEndDt,
    required this.isActive,
    required this.remarks,
    required this.ticketCheckers,
    required this.ticketFieldValues,
    required this.ticketAttachments,
    required this.makerUserName,
    required this.makerDesignationName,
    required this.oldData,
    required this.showReviewBtns,
    required this.checkerLvl,
    required this.role,
    required this.ticketStatusHistory,
    required this.isRepeating,
    required this.repeatDt,
    required this.allowedStatuses,
  });

  factory PmisActivityTicketDetail.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic v) => int.tryParse(v?.toString() ?? '') ?? 0;
    int? parseIntNullable(dynamic v) => v == null ? null : int.tryParse(v.toString());
    bool parseBool(dynamic v) =>
        v == true || v?.toString().toLowerCase() == 'true' || v == 1;
    String? parseStringNullable(dynamic v) => v == null ? null : v.toString();

    final checkers = (json['ticketCheckers'] as List<dynamic>? ?? [])
        .map((e) => PmisTicketChecker.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();

    final fieldValues = (json['ticketFieldValues'] as List<dynamic>? ?? [])
        .map((e) => PmisTicketFieldValue.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();

    final attachments = (json['ticketAttachments'] as List<dynamic>? ?? [])
        .map((e) => PmisTicketAttachment.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();

    final oldDataRaw = json['oldData'];
    final List<dynamic> oldDataList;
    if (oldDataRaw == null) {
      oldDataList = const [];
    } else if (oldDataRaw is List) {
      oldDataList = oldDataRaw;
    } else if (oldDataRaw is Map) {
      oldDataList = [oldDataRaw];
    } else {
      oldDataList = const [];
    }
    final oldDataItems = oldDataList
        .map((e) => PmisOldDataItem.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();

    final statusHistory = (json['ticketStatusHistory'] as List<dynamic>? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final allowedStatusesRaw = json['allowedStatuses'];
    final allowedStatuses = allowedStatusesRaw is List
        ? allowedStatusesRaw
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .toList()
        : (allowedStatusesRaw?.toString() ?? '')
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();

    return PmisActivityTicketDetail(
      atId: parseInt(json['atId']),
      ppaId: parseInt(json['ppaId']),
      currentStatus: (json['currentStatus'] ?? '').toString(),
      currentStatusDt: parseStringNullable(json['currentStatusDt']),
      makerDesignationMstId: parseIntNullable(json['makerDesignationMstId']),
      makerUserMstId: parseIntNullable(json['makerUserMstId']),
      makerAssignedDt: parseStringNullable(json['makerAssignedDt']),
      plannedStartDt: parseStringNullable(json['plannedStartDt']),
      plannedEndDt: parseStringNullable(json['plannedEndDt']),
      actualStartDt: parseStringNullable(json['actualStartDt']),
      actualEndDt: parseStringNullable(json['actualEndDt']),
      isActive: parseBool(json['isActive']),
      remarks: parseStringNullable(json['remarks']),
      ticketCheckers: checkers,
      ticketFieldValues: fieldValues,
      ticketAttachments: attachments,
      makerUserName: parseStringNullable(json['makerUserName']),
      makerDesignationName: parseStringNullable(json['makerDesignationName']),
      oldData: oldDataItems,
      showReviewBtns: parseBool(json['showReviewBtns']),
      checkerLvl: parseStringNullable(json['checkerLvl']),
      role: parseStringNullable(json['role']),
      ticketStatusHistory: statusHistory,
      isRepeating: parseBool(json['isRepeating']),
      repeatDt: parseStringNullable(json['repeatDt']),
      allowedStatuses: allowedStatuses,
    );
  }

  @override
  List<Object?> get props => [
        atId,
        ppaId,
        currentStatus,
        currentStatusDt,
        makerDesignationMstId,
        makerUserMstId,
        makerAssignedDt,
        plannedStartDt,
        plannedEndDt,
        actualStartDt,
        actualEndDt,
        isActive,
        remarks,
        ticketCheckers,
        ticketFieldValues,
        ticketAttachments,
        makerUserName,
        makerDesignationName,
        oldData,
        showReviewBtns,
        checkerLvl,
        role,
        ticketStatusHistory,
        isRepeating,
        repeatDt,
        allowedStatuses,
      ];
}

class PmisTicketChecker extends Equatable {
  final int tcId;
  final int levelNo;
  final int? designationMstId;
  final int? checkerUserMstId;
  final String? decisionStatus;
  final String? decisionBy;
  final String? decisionDt;
  final String? decisionRemarks;
  final String? latitude;
  final String? longitude;
  final String? geoAccuracyM;
  final String? geoSource;
  final bool isActive;
  final String? remarks;
  final String? decisionByName;
  final String? checkerUserName;
  final String? designationName;

  const PmisTicketChecker({
    required this.tcId,
    required this.levelNo,
    required this.designationMstId,
    required this.checkerUserMstId,
    required this.decisionStatus,
    required this.decisionBy,
    required this.decisionDt,
    required this.decisionRemarks,
    required this.latitude,
    required this.longitude,
    required this.geoAccuracyM,
    required this.geoSource,
    required this.isActive,
    required this.remarks,
    required this.decisionByName,
    required this.checkerUserName,
    required this.designationName,
  });

  factory PmisTicketChecker.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic v) => int.tryParse(v?.toString() ?? '') ?? 0;
    int? parseIntNullable(dynamic v) => v == null ? null : int.tryParse(v.toString());
    bool parseBool(dynamic v) =>
        v == true || v?.toString().toLowerCase() == 'true' || v == 1;
    String? s(dynamic v) => v == null ? null : v.toString();

    return PmisTicketChecker(
      tcId: parseInt(json['tcId']),
      levelNo: parseInt(json['levelNo']),
      designationMstId: parseIntNullable(json['designationMstId']),
      checkerUserMstId: parseIntNullable(json['checkerUserMstId']),
      decisionStatus: s(json['decisionStatus']),
      decisionBy: s(json['decisionBy']),
      decisionDt: s(json['decisionDt']),
      decisionRemarks: s(json['decisionRemarks']),
      latitude: s(json['latitude']),
      longitude: s(json['longitude']),
      geoAccuracyM: s(json['geoAccuracyM']),
      geoSource: s(json['geoSource']),
      isActive: parseBool(json['isActive']),
      remarks: s(json['remarks']),
      decisionByName: s(json['decisionByName']),
      checkerUserName: s(json['checkerUserName']),
      designationName: s(json['designationName']),
    );
  }

  @override
  List<Object?> get props => [
        tcId,
        levelNo,
        designationMstId,
        checkerUserMstId,
        decisionStatus,
        decisionBy,
        decisionDt,
        decisionRemarks,
        latitude,
        longitude,
        geoAccuracyM,
        geoSource,
        isActive,
        remarks,
        decisionByName,
        checkerUserName,
        designationName,
      ];
}

/// PMIS may send mixed shapes; only include real maps so [fromJson] never throws.
List<Map<String, dynamic>> _ticketFieldAttachmentsFromJson(dynamic raw) {
  if (raw is! List) return const <Map<String, dynamic>>[];
  final out = <Map<String, dynamic>>[];
  for (final e in raw) {
    if (e is Map) {
      out.add(Map<String, dynamic>.from(e));
    }
  }
  return out;
}

class PmisTicketFieldValue extends Equatable {
  final int tfvId;
  final dynamic valText;
  final dynamic valNumeric;
  final dynamic valInt;
  final dynamic valDate;
  final Map<String, dynamic> valJson;
  final String? latitude;
  final String? longitude;
  final String? geoAccuracyM;
  final String? geoSource;
  final bool isActive;
  final String? remarks;
  final List<Map<String, dynamic>> attachments;
  final String? subActivityName;
  final String? subActivityDataType;
  final String? subActivityControlType;
  final bool? isRequired;
  final int? seqNo;
  final dynamic minVal;
  final dynamic maxVal;
  final dynamic configJson;
  final int? linkMmId;

  const PmisTicketFieldValue({
    required this.tfvId,
    required this.valText,
    required this.valNumeric,
    required this.valInt,
    required this.valDate,
    required this.valJson,
    required this.latitude,
    required this.longitude,
    required this.geoAccuracyM,
    required this.geoSource,
    required this.isActive,
    required this.remarks,
    required this.attachments,
    required this.subActivityName,
    required this.subActivityDataType,
    required this.subActivityControlType,
    required this.isRequired,
    required this.seqNo,
    required this.minVal,
    required this.maxVal,
    required this.configJson,
    required this.linkMmId,
  });

  factory PmisTicketFieldValue.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic v) => int.tryParse(v?.toString() ?? '') ?? 0;
    int? parseIntNullable(dynamic v) => v == null ? null : int.tryParse(v.toString());
    bool parseBool(dynamic v) =>
        v == true || v?.toString().toLowerCase() == 'true' || v == 1;
    String? s(dynamic v) => v == null ? null : v.toString();

    return PmisTicketFieldValue(
      tfvId: parseInt(json['tfvId']),
      valText: json['valText'],
      valNumeric: json['valNumeric'],
      valInt: json['valInt'],
      valDate: json['valDate'],
      valJson: (json['valJson'] is Map)
          ? Map<String, dynamic>.from(json['valJson'] as Map)
          : const <String, dynamic>{},
      latitude: s(json['latitude']),
      longitude: s(json['longitude']),
      geoAccuracyM: s(json['geoAccuracyM']),
      geoSource: s(json['geoSource']),
      isActive: parseBool(json['isActive']),
      remarks: s(json['remarks']),
      attachments: _ticketFieldAttachmentsFromJson(json['attachments']),
      subActivityName: s(json['subActivityName']),
      subActivityDataType: s(json['subActivityDataType']),
      subActivityControlType: s(json['subActivityControlType']),
      isRequired: json['isRequired'] as bool?,
      seqNo: parseIntNullable(json['seqNo']),
      minVal: json['minVal'],
      maxVal: json['maxVal'],
      configJson: json['configJson'],
      linkMmId: parseIntNullable(json['linkMmId']),
    );
  }

  @override
  List<Object?> get props => [
        tfvId,
        valText,
        valNumeric,
        valInt,
        valDate,
        valJson,
        latitude,
        longitude,
        geoAccuracyM,
        geoSource,
        isActive,
        remarks,
        attachments,
        subActivityName,
        subActivityDataType,
        subActivityControlType,
        isRequired,
        seqNo,
        minVal,
        maxVal,
        configJson,
        linkMmId,
      ];
}

class PmisTicketAttachment extends Equatable {
  final Map<String, dynamic> raw;

  const PmisTicketAttachment({required this.raw});

  factory PmisTicketAttachment.fromJson(Map<String, dynamic> json) =>
      PmisTicketAttachment(raw: json);

  @override
  List<Object?> get props => [raw];
}

class PmisOldDataItem extends Equatable {
  final String? actualStartDt;
  final String? actualEndDt;
  final List<PmisTicketFieldValue> ticketFieldValues;
  final String? makerUserName;
  final bool? isModified;

  const PmisOldDataItem({
    required this.actualStartDt,
    required this.actualEndDt,
    required this.ticketFieldValues,
    required this.makerUserName,
    required this.isModified,
  });

  factory PmisOldDataItem.fromJson(Map<String, dynamic> json) {
    String? s(dynamic v) => v == null ? null : v.toString();
    return PmisOldDataItem(
      actualStartDt: s(json['actualStartDt']),
      actualEndDt: s(json['actualEndDt']),
      ticketFieldValues: (json['ticketFieldValues'] as List<dynamic>? ?? [])
          .map((e) => PmisTicketFieldValue.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      makerUserName: s(json['makerUserName']),
      isModified: json['isModified'] as bool?,
    );
  }

  @override
  List<Object?> get props =>
      [actualStartDt, actualEndDt, ticketFieldValues, makerUserName, isModified];
}

/// Attachment id from a PMIS `attachments` map (supports common API key variants).
String? pmisAttachmentIdString(Map<String, dynamic> a) {
  final v = a['attachmentId'] ??
      a['attachment_id'] ??
      a['AttachmentId'] ??
      a['attachmentID'] ??
      a['imgId'] ??
      a['ImgId'] ??
      a['imageId'] ??
      a['ImageId'] ??
      a['photoId'] ??
      a['PhotoId'];
  if (v == null) return null;
  final s = v.toString().trim();
  return s.isEmpty ? null : s;
}

/// Distinct positive ids for `GET /api/v1/common/DocumentById/{id}` from
/// IMAGE / VIDEO / PDF field rows on the current ticket payload.
List<int> collectPmisActivityTicketDocumentIds(PmisActivityTicketDetail detail) {
  final ids = <int>{};

  void collectFromField(PmisTicketFieldValue f) {
    final t = (f.subActivityDataType ?? '').trim().toUpperCase();
    if (t != 'IMAGE' && t != 'VIDEO' && t != 'PDF') return;
    for (final a in f.attachments) {
      final raw = pmisAttachmentIdString(a);
      if (raw == null) continue;
      final id = int.tryParse(raw);
      if (id != null && id > 0) ids.add(id);
    }
    final vt = f.valText?.toString().trim() ?? '';
    if (vt.isEmpty) return;
    for (final part in vt.split(',')) {
      final id = int.tryParse(part.trim());
      if (id != null && id > 0) ids.add(id);
    }
  }

  for (final f in detail.ticketFieldValues) {
    collectFromField(f);
  }
  for (final old in detail.oldData) {
    for (final f in old.ticketFieldValues) {
      collectFromField(f);
    }
  }
  for (final ta in detail.ticketAttachments) {
    final raw = pmisAttachmentIdString(ta.raw);
    if (raw == null) continue;
    final id = int.tryParse(raw);
    if (id != null && id > 0) ids.add(id);
  }
  return ids.toList()..sort();
}
