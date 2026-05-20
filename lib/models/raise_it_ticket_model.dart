import 'package:app/models/ticket_model.dart';

class RaiseItTicket {
  final int ticketSchId;
  final String ticketNo;
  final String status;
  final String category;
  final String issueTitle;
  final String assignedToName;
  final String priority;
  final String assetType;
  final String assetCode;
  final String assetAcronym;
  

  /// Same as [ticketSchId] — API `iait_id` / `iaitId`.
  int get iaitId => ticketSchId;

  const RaiseItTicket({
    required this.ticketSchId,
    this.ticketNo = '',
    this.status = '',
    this.category = '',
    this.issueTitle = '',
    this.assignedToName = '',
    this.priority = '',
    this.assetType = '',
    this.assetCode = '',
    this.assetAcronym = '',
  });

  factory RaiseItTicket.fromJson(Map<String, dynamic> json) {
    return RaiseItTicket(
      ticketSchId: _intVal(
        json['iait_id'] ??
            json['iaitId'] ??
            json['ticket_sch_id'] ??
            json['ticketSchId'],
      ),
      ticketNo: _str(
        json['raise_ticket_id'] ??
            json['raiseTicketId'] ??
            json['ticketNumber'] ??
            json['pv_ticket_id'] ??
            json['ticket_no'] ??
            json['ticketNo'] ??
            json['ticket_number'],
      ),
      status: _str(
        json['ticketStatus'] ?? json['status'] ?? json['Status'],
      ),
      category: _str(
        json['category'] ??
            json['asset_category'] ??
            json['device_category'] ??
            json['site_domain_name'] ??
            json['cluster'],
      ),
      issueTitle: _str(
        json['issue_title'] ??
            json['issueTitle'] ??
            json['issue'] ??
            json['problem_summary'] ??
            json['problemSummary'] ??
            json['fault_description'] ??
            json['faultDescription'],
      ),
      assignedToName: _str(
        json['assigned_to_name'] ??
            json['assignedToName'] ??
            json['assigned_to'] ??
            json['assignedTo'],
      ),
      assetType: _str(json['assetType'] ?? json['asset_type']),
      assetCode: _str(json['assetCode'] ?? json['asset_code']),
      assetAcronym: _str(json['assetAcronym'] ?? json['asset_acronym']),
      priority: _str(json['priority'] ?? json['Priority']),
    );
  }

  static List<RaiseItTicket> listFromResponse(dynamic data) {
    final rawList = _extractList(data);
    final tickets = <RaiseItTicket>[];
    for (var i = 0; i < rawList.length; i++) {
      try {
        final item = rawList[i];
        if (item is Map<String, dynamic>) {
          tickets.add(RaiseItTicket.fromJson(item));
        } else if (item is Map) {
          tickets.add(
            RaiseItTicket.fromJson(Map<String, dynamic>.from(item)),
          );
        }
      } catch (_) {
        // Skip malformed rows.
      }
    }
    return tickets;
  }

  static List<dynamic> _extractList(dynamic data) {
    if (data == null) return [];
    if (data is List) return data;
    if (data is Map) {
      final map = data is Map<String, dynamic>
          ? data
          : Map<String, dynamic>.from(data);
      for (final key in [
        'data',
        'tickets',
        'itRaiseTickets',
        'ItRaiseTickets',
        'records',
        'items',
      ]) {
        final value = map[key];
        if (value is List) return value;
      }
    }
    return [];
  }

  factory RaiseItTicket.fromTicket(Ticket ticket) {
    return RaiseItTicket(
      ticketSchId: ticket.ticketSchId,
      ticketNo: ticket.pvTicketId,
      status: ticket.status ?? '',
      category: ticket.category ?? ticket.cluster ?? '',
      issueTitle: ticket.issueTitle ?? '',
      assignedToName: ticket.assignedToName ?? '',
      priority: ticket.priority ?? '',
      assetType: ticket.category ?? '',
      assetCode: '',
      assetAcronym: '',
    );
  }

  static String _str(dynamic value) {
    if (value == null) return '';
    final s = value.toString().trim();
    if (s.isEmpty || s.toLowerCase() == 'null') return '';
    return s;
  }

  static int _intVal(dynamic value) {
    if (value == null) return 0;
    return int.tryParse(value.toString()) ?? 0;
  }
}
