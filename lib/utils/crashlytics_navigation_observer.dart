import 'package:flutter/widgets.dart';

import 'package:app/utils/CrashLogger.dart';

class CrashlyticsNavigationObserver extends NavigatorObserver {
  void _setScreen(Route<dynamic>? route) {
    final name = route?.settings.name;
    if (name != null && name.isNotEmpty) {
      CrashLogger().setCurrentScreen(name);
      return;
    }

    final fallback = route?.runtimeType.toString();
    CrashLogger().setCurrentScreen(fallback);
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _setScreen(route);
    super.didPush(route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _setScreen(newRoute);
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _setScreen(previousRoute);
    super.didPop(route, previousRoute);
  }
}
