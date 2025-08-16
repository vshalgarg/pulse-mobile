import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

class SaveFileInDeviceStorage {
  // save file type in device storage
  static Future<String?> saveDataInDeviceStorage(Uint8List image) async {
    bool dirDownloadExists = true;
    var directory;
    if (Platform.isIOS) {
      directory = await getDownloadsDirectory();
    } else {
      directory = "/storage/emulated/0/Download/";

      dirDownloadExists = await Directory(directory).exists();
      if (dirDownloadExists) {
        directory = "/storage/emulated/0/Download";
      } else {
        directory = "/storage/emulated/0/Downloads";
      }
    }
    final dir = await Directory('$directory/sample').create(recursive: true);
    if (!await dir.exists()) {
      return null;
    }
    final fullPath = '$directory/sample';
    final fileName = '${DateTime.now().millisecondsSinceEpoch}.png';

    final imgFile = File('$fullPath/$fileName'); // if writing on disk
    // final imgFile = File('$fullPath'); if capturing as Screenshot
    try {
      imgFile.writeAsBytesSync(image);
      return fullPath;
    } catch (e) {
      return null;
    }
  }
}
