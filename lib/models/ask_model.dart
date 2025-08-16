/// status : "success"
/// message : "Please improve the question"
/// chat_id : "65d44500afb13fa74e233338"
/// query_id : "65d44500afb13fa74e233339"
/// status_code : 200

class AskModel {
  AskModel({
    String? status,
    String? message,
    String? chatId,
    String? queryId,
    num? statusCode,
  }) {
    _status = status;
    _message = message;
    _chatId = chatId;
    _queryId = queryId;
    _statusCode = statusCode;
  }

  AskModel.fromJson(dynamic json) {
    _status = json['status'];
    _message = json['message'];
    _chatId = json['chat_id'];
    _queryId = json['query_id'];
    _statusCode = json['status_code'];
  }

  String? _status;
  String? _message;
  String? _chatId;
  String? _queryId;
  num? _statusCode;

  AskModel copyWith({
    String? status,
    String? message,
    String? chatId,
    String? queryId,
    num? statusCode,
  }) =>
      AskModel(
        status: status ?? _status,
        message: message ?? _message,
        chatId: chatId ?? _chatId,
        queryId: queryId ?? _queryId,
        statusCode: statusCode ?? _statusCode,
      );

  String? get status => _status;

  String? get message => _message;

  String? get chatId => _chatId;

  String? get queryId => _queryId;

  num? get statusCode => _statusCode;

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['status'] = _status;
    map['message'] = _message;
    map['chat_id'] = _chatId;
    map['query_id'] = _queryId;
    map['status_code'] = _statusCode;
    return map;
  }
}
