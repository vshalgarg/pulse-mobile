import 'package:flutter/material.dart';

extension FullName on Locale {
  String fullName() {
    switch (languageCode) {
      case 'en':
        return 'English';
      case 'en-US':
        return 'English';
      case 'hi':
        return 'Hindi';
      case 'hi-IN':
        return 'Hindi';
      case 'ar':
        return 'العربية';
    }
    return '';
  }
}
