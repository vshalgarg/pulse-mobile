import 'screen_permission.dart';

class UserRoleScreen {
  final int screenId;
  final String screenName;
  final String displayName;
  final int sequence;
  final List<String> operations;

  const UserRoleScreen({
    required this.screenId,
    required this.screenName,
    required this.displayName,
    required this.sequence,
    required this.operations,
  });

  ScreenPermission get permission => ScreenPermission(
        screenId: screenId,
        operations: operations,
      );

  factory UserRoleScreen.fromJson(Map<String, dynamic> json) {
    final rawOperations = json['operations'];
    final operations = rawOperations is List
        ? rawOperations.map((e) => e.toString().toUpperCase()).toList()
        : const <String>[];

    return UserRoleScreen(
      screenId: _toInt(json['screen_mst_id']),
      screenName: json['screen_name']?.toString() ?? '',
      displayName: json['screen_displayname']?.toString() ?? '',
      sequence: _toInt(json['screen_sequence']),
      operations: operations,
    );
  }

  static int _toInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
