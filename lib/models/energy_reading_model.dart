import 'package:equatable/equatable.dart';

class EnergyReadingResponse extends Equatable {
  final List<EnergyReadingData> data;
  final String? message;
  final bool success;

  const EnergyReadingResponse({
    required this.data,
    this.message,
    required this.success,
  });

  factory EnergyReadingResponse.fromJson(List<dynamic> json) {
    return EnergyReadingResponse(
      data: json.map((item) => EnergyReadingData.fromJson(item)).toList(),
      success: true,
    );
  }

  @override
  List<Object?> get props => [data, message, success];
}

class EnergyReadingData extends Equatable {
  final int siteAuditSchId;
  final String circle;
  final String cluster;
  final String? district;
  final String clientName;
  final String siteCode;
  final String siteName;
  final String siteTypeName;
  final String indoorOutdoor;
  final String ebNonEb;
  final String op1Name;
  final String op2Name;
  final int siteId;

  const EnergyReadingData({
    required this.siteAuditSchId,
    required this.circle,
    required this.cluster,
    this.district,
    required this.clientName,
    required this.siteCode,
    required this.siteName,
    required this.siteTypeName,
    required this.indoorOutdoor,
    required this.ebNonEb,
    required this.op1Name,
    required this.op2Name,
    required this.siteId,
  });

  factory EnergyReadingData.fromJson(Map<String, dynamic> json) {
    return EnergyReadingData(
      siteAuditSchId: int.tryParse(json['site_audit_sch_id'].toString()) ?? 0,
      circle: json['circle'] ?? '',
      cluster: json['cluster'] ?? '',
      district: json['district'],
      clientName: json['client_name'] ?? '',
      siteCode: json['site_code'] ?? '',
      siteName: json['site_name'] ?? '',
      siteTypeName: json['site_type_name'] ?? '',
      indoorOutdoor: json['indoor_outdoor'] ?? '',
      ebNonEb: json['eb_non_eb'] ?? '',
      op1Name: json['op1_name'] ?? '',
      op2Name: json['op2_name'] ?? '',
      siteId: int.tryParse(json['site_id'].toString()) ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'site_audit_sch_id': siteAuditSchId,
      'circle': circle,
      'cluster': cluster,
      'district': district,
      'client_name': clientName,
      'site_code': siteCode,
      'site_name': siteName,
      'site_type_name': siteTypeName,
      'indoor_outdoor': indoorOutdoor,
      'eb_non_eb': ebNonEb,
      'op1_name': op1Name,
      'op2_name': op2Name,
      'site_id': siteId,
    };
  }

  @override
  List<Object?> get props => [
        siteAuditSchId,
        circle,
        cluster,
        district,
        clientName,
        siteCode,
        siteName,
        siteTypeName,
        indoorOutdoor,
        ebNonEb,
        op1Name,
        op2Name,
        siteId,
      ];
}

// Request model for creating/updating energy reading
class EnergyReadingRequest extends Equatable {
  final int energyReadingId;
  final int auditSchId;
  final int siteAuditSchId;
  final int siteId;
  final String connectionType;
  final String consumerNo;
  final String ebMeterStatus;
  final String ebConnectionType;
  final String ebMeterType;
  final String ebMeterNo;
  final double ebMeterReading;
  final double ebKwhInSebMeter;
  final double ebKvaInSebMeter;
  final double ebKwhInCcu;
  final double ebKvaInCcu;
  final double voltage;
  final double load;
  final String documentName;
  final String anyMajorHazardousPunchPoint;
  final int ebAttachmentFileId;
  final bool isActive;
  final String remarks;

  const EnergyReadingRequest({
    required this.energyReadingId,
    required this.auditSchId,
    required this.siteAuditSchId,
    required this.siteId,
    required this.connectionType,
    required this.consumerNo,
    required this.ebMeterStatus,
    required this.ebConnectionType,
    required this.ebMeterType,
    required this.ebMeterNo,
    required this.ebMeterReading,
    required this.ebKwhInSebMeter,
    required this.ebKvaInSebMeter,
    required this.ebKwhInCcu,
    required this.ebKvaInCcu,
    required this.voltage,
    required this.load,
    required this.documentName,
    required this.anyMajorHazardousPunchPoint,
    required this.ebAttachmentFileId,
    required this.isActive,
    required this.remarks,
  });

  Map<String, dynamic> toJson() {
    return {
      'energyReadingId': energyReadingId,
      'auditSchId': auditSchId,
      'siteAuditSchId': siteAuditSchId,
      'siteId': siteId,
      'connectionType': connectionType,
      'consumerNo': consumerNo,
      'ebMeterStatus': ebMeterStatus,
      'ebConnectionType': ebConnectionType,
      'ebMeterType': ebMeterType,
      'ebMeterNo': ebMeterNo,
      'ebMeterReading': ebMeterReading,
      'ebKwhInSebMeter': ebKwhInSebMeter,
      'ebKvaInSebMeter': ebKvaInSebMeter,
      'ebKwhInCcu': ebKwhInCcu,
      'ebKvaInCcu': ebKvaInCcu,
      'voltage': voltage,
      'load': load,
      'documentName': documentName,
      'anyMajorHazardousPunchPoint': anyMajorHazardousPunchPoint,
      'ebAttachmentFileId': ebAttachmentFileId,
      'isActive': isActive,
      'remarks': remarks,
    };
  }

  @override
  List<Object?> get props => [
        energyReadingId,
        auditSchId,
        siteAuditSchId,
        siteId,
        connectionType,
        consumerNo,
        ebMeterStatus,
        ebConnectionType,
        ebMeterType,
        ebMeterNo,
        ebMeterReading,
        ebKwhInSebMeter,
        ebKvaInSebMeter,
        ebKwhInCcu,
        ebKvaInCcu,
        voltage,
        load,
        documentName,
        anyMajorHazardousPunchPoint,
        ebAttachmentFileId,
        isActive,
        remarks,
      ];
}
