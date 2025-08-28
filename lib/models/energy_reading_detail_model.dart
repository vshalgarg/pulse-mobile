import 'package:equatable/equatable.dart';

// Request model for creating/updating energy reading details
class EnergyReadingDetailRequest extends Equatable {
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

  const EnergyReadingDetailRequest({
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

// Response model for energy reading detail operations
class EnergyReadingDetailResponse extends Equatable {
  final Map<String, dynamic>? data;
  final String? message;
  final bool success;

  const EnergyReadingDetailResponse({
    this.data,
    this.message,
    required this.success,
  });

  factory EnergyReadingDetailResponse.fromJson(Map<String, dynamic> json) {
    return EnergyReadingDetailResponse(
      data: json['data'],
      message: json['message'],
      success: json['success'] ?? true,
    );
  }

  @override
  List<Object?> get props => [data, message, success];
}
