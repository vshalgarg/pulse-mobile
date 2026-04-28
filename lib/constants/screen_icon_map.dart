import 'package:flutter/material.dart';

const Map<int, IconData> screenIconMap = {
  76: Icons.assignment_turned_in,
  77: Icons.build,
  78: Icons.flash_on,
  79: Icons.search,
  80: Icons.report,
  81: Icons.settings_backup_restore,
  82: Icons.folder,
  83: Icons.security,
  84: Icons.warehouse,
  85: Icons.upload,
  86: Icons.list_alt,
  87: Icons.touch_app,
};

IconData iconForScreenId(int screenId) {
  return screenIconMap[screenId] ?? Icons.apps;
}
