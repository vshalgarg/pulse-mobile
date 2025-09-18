import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

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
      pageNo: int.tryParse(json['pageNo'].toString()) ?? 1,
      pageSize: int.tryParse(json['pageSize'].toString()) ?? 50,
      totalRecords: int.tryParse(json['totalRecords'].toString()) ?? 0,
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
  final String? siteDomainName;
  final String? status;

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
    this.siteDomainName,
    this.status,
  });

  factory Ticket.fromJson(Map<String, dynamic> json) {
    // Helper function to safely convert to double
    double? parseDouble(dynamic value) {
      if (value == null) return null;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) {
        try {
          return double.parse(value);
        } catch (e) {
          debugPrint("⚠️ Warning: Could not parse '$value' to double: $e");
          return null;
        }
      }
      return null;
    }

    // Debug logging for status field
    debugPrint("🔍 Ticket.fromJson: Raw status field = '${json['status']}'");
    debugPrint("🔍 Ticket.fromJson: Status field type = ${json['status'].runtimeType}");
    
    final ticket = Ticket(
      ticketSchId: int.tryParse(json['ticket_sch_id'].toString()) ?? 0,
      pvTicketId: json['pv_ticket_id'] ?? '',
      siteCode: json['site_code'],
      cluster: json['cluster'],
      operator: json['operator'],
      raisedDt: json['raised_dt'] ?? '',
      dueDt: json['due_dt'] ?? '',
      auditSchId: json['audit_sch_id'] != null ? int.tryParse(json['audit_sch_id'].toString()) : null,
      longitude: parseDouble(json['longitude']),
      latitude: parseDouble(json['latitude']),
      siteDomainName: json['site_domain_name'],
      status: json['status'],
    );
    
    // Debug logging for final ticket object
    debugPrint("🔍 Ticket.fromJson: Final ticket status = '${ticket.status}'");
    
    return ticket;
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
      'site_domain_name': siteDomainName,
      'status': status,
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
        siteDomainName,
        status,
      ];
}

// Ticket filter parameters
class TicketFilterParams extends Equatable {
  final String activityType; // AA, PM, ER
  final String type; // ALL, IN_PROGRESS, COMPLETED, CLOSED, MISSED_DEADLINE
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

// Ticket type constants
class TicketType {
  static const String all = 'ALL';
  static const String open = 'IN_PROGRESS';
  static const String completed = 'COMPLETED';
  static const String closed = 'CLOSED';
  static const String missedDeadline = 'MISSED_DEADLINE';
}
