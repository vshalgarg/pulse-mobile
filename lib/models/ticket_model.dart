import 'package:equatable/equatable.dart';

class TicketResponse extends Equatable {
  final int pageNo;
  final int pageSize;
  final int totalRecords;
  final List<Ticket> tickets;

  const TicketResponse({
    required this.pageNo,
    required this.pageSize,
    required this.totalRecords,
    required this.tickets,
  });

  factory TicketResponse.fromJson(Map<String, dynamic> json) {
    return TicketResponse(
      pageNo: json['pageNo'] ?? 1,
      pageSize: json['pageSize'] ?? 50,
      totalRecords: json['totalRecords'] ?? 0,
      tickets: (json['tickets'] as List<dynamic>?)
              ?.map((ticket) => Ticket.fromJson(ticket))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'pageNo': pageNo,
      'pageSize': pageSize,
      'totalRecords': totalRecords,
      'tickets': tickets.map((ticket) => ticket.toJson()).toList(),
    };
  }

  @override
  List<Object?> get props => [pageNo, pageSize, totalRecords, tickets];
}

class Ticket extends Equatable {
  final int ticketSchId;
  final String pvTicketId;
  final String? siteCode;
  final String? cluster;
  final String? operator;
  final String raisedDt;
  final String dueDt;
  final int? auditSchId;
  final double? longitude;
  final double? latitude;

  const Ticket({
    required this.ticketSchId,
    required this.pvTicketId,
    this.siteCode,
    this.cluster,
    this.operator,
    required this.raisedDt,
    required this.dueDt,
    this.auditSchId,
    this.longitude,
    this.latitude,
  });

  factory Ticket.fromJson(Map<String, dynamic> json) {
    return Ticket(
      ticketSchId: json['ticket_sch_id'] ?? 0,
      pvTicketId: json['pv_ticket_id'] ?? '',
      siteCode: json['site_code'],
      cluster: json['cluster'],
      operator: json['operator'],
      raisedDt: json['raised_dt'] ?? '',
      dueDt: json['due_dt'] ?? '',
      auditSchId: json['audit_sch_id'],
      longitude: json['longitude']?.toDouble(),
      latitude: json['latitude']?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'ticket_sch_id': ticketSchId,
      'pv_ticket_id': pvTicketId,
      'site_code': siteCode,
      'cluster': cluster,
      'operator': operator,
      'raised_dt': raisedDt,
      'due_dt': dueDt,
      'audit_sch_id': auditSchId,
      'longitude': longitude,
      'latitude': latitude,
    };
  }

  @override
  List<Object?> get props => [
        ticketSchId,
        pvTicketId,
        siteCode,
        cluster,
        operator,
        raisedDt,
        dueDt,
        auditSchId,
        longitude,
        latitude,
      ];
}

// Ticket filter parameters
class TicketFilterParams extends Equatable {
  final String activityType; // AA, PM, ER
  final String type; // ALL, OPEN, COMPLETED, CLOSED, MISSED DEADLINE
  final int? pageSize;
  final int? pageNo;

  const TicketFilterParams({
    required this.activityType,
    required this.type,
    this.pageSize,
    this.pageNo,
  });

  Map<String, dynamic> toQueryParams() {
    final params = <String, dynamic>{
      'ActivityType': activityType,
      'type': type,
    };

    if (pageSize != null) {
      params['pageSize'] = pageSize;
    }
    if (pageNo != null) {
      params['pageNo'] = pageNo;
    }

    return params;
  }

  @override
  List<Object?> get props => [activityType, type, pageSize, pageNo];
}

// Activity type constants
class ActivityType {
  static const String assetAudit = 'AA';
  static const String preventiveMaintenance = 'PM';
  static const String energyReading = 'ER';
}

// Ticket type constants
class TicketType {
  static const String all = 'ALL';
  static const String open = 'OPEN';
  static const String completed = 'COMPLETED';
  static const String closed = 'CLOSED';
  static const String missedDeadline = 'MISSED DEADLINE';
}
