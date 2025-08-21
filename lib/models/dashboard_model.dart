class DashboardModel {
  DashboardModel({
    Map<String, List<TicketData>>? data,
  }) {
    _data = data;
  }

  DashboardModel.fromJson(dynamic json) {
    _data = {};
    if (json != null) {
      json.forEach((key, value) {
        if (value is List) {
          _data![key] = value.map((item) => TicketData.fromJson(item)).toList();
        }
      });
    }
  }

  Map<String, List<TicketData>>? _data;

  DashboardModel copyWith({
    Map<String, List<TicketData>>? data,
  }) =>
      DashboardModel(
        data: data ?? _data,
      );

  Map<String, List<TicketData>>? get data => _data;

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    if (_data != null) {
      _data!.forEach((key, value) {
        map[key] = value.map((item) => item.toJson()).toList();
      });
    }
    return map;
  }
}

class TicketData {
  TicketData({
    String? activityType,
    String? ticketCode,
    int? ticketCnt,
  }) {
    _activityType = activityType;
    _ticketCode = ticketCode;
    _ticketCnt = ticketCnt;
  }

  TicketData.fromJson(dynamic json) {
    _activityType = json['activity_type'];
    _ticketCode = json['ticket_code'];
    _ticketCnt = json['ticket_cnt'];
  }

  String? _activityType;
  String? _ticketCode;
  int? _ticketCnt;

  TicketData copyWith({
    String? activityType,
    String? ticketCode,
    int? ticketCnt,
  }) =>
      TicketData(
        activityType: activityType ?? _activityType,
        ticketCode: ticketCode ?? _ticketCode,
        ticketCnt: ticketCnt ?? _ticketCnt,
      );

  String? get activityType => _activityType;
  String? get ticketCode => _ticketCode;
  int? get ticketCnt => _ticketCnt;

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['activity_type'] = _activityType;
    map['ticket_code'] = _ticketCode;
    map['ticket_cnt'] = _ticketCnt;
    return map;
  }
}
