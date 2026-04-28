class ScreenPermission {
  final int screenId;
  final List<String> operations;

  const ScreenPermission({
    required this.screenId,
    required this.operations,
  });

  bool get canAdd => operations.contains('ADD');

  bool get canEdit => operations.contains('EDIT');

  bool get canView => operations.contains('VIEW');

  bool get canRefresh => operations.contains('REFRESH');
}
