import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../constants/constants_methods.dart';

class SpeechApi {
  static final _speech = SpeechToText();

  static Future<bool> toggleRecording({
    required Function(String text) onResult,
    required ValueChanged<bool> onListening,
  }) async {
    if (_speech.isListening) {
      _speech.stop();
      return true;
    }
    final isAvailable = await _speech.initialize(
      onStatus: (status) => onListening(_speech.isListening),
      onError: (e) => kDebugPrint(e),
    );
    if (isAvailable) {
      _speech.listen(
        onResult: (result) {
          onResult(result.recognizedWords);
        },
        pauseFor: const Duration(seconds: 10),
      );
    }
    return isAvailable;
  }
}
