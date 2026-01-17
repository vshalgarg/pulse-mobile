import 'package:flutter/material.dart';

class L10n {
  static final all = [
    const Locale('en'),
    const Locale('ar'),
    const Locale('hi'),
    const Locale('es'),
    const Locale('de'),
    const Locale('ur'),
  ];

  static String getFlag(String code) {
    switch (code) {
      case 'en':
        return '🇺🇸';
      case 'ar':
        return '🇦🇪';
      case 'hi':
        return '🇮🇳';
      case 'es':
        return '🇪🇸';
      case 'de':
        return '🇩🇪';
      case 'ur':
        return '🇮🇳';
      default:
        return '🇺🇸';
    }
  }
}
