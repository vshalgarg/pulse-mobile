import 'dart:io';
import 'dart:typed_data';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

/// Writes PDF (or other) bytes to public **Download** on Android when allowed,
/// otherwise app storage — mirrors [PdfDownloadService] path selection.
class DocumentBytesSaveService {
  DocumentBytesSaveService._();

  static Future<String?> savePdfBytes(Uint8List bytes, String fileName) async {
    try {
      await _requestStoragePermissions();
      final downloadsPath = await _resolveDownloadsDirectory();
      if (!await downloadsPath.exists()) {
        await downloadsPath.create(recursive: true);
      }

      var safeName = p.basename(fileName.trim());
      if (safeName.isEmpty) safeName = 'document.pdf';
      if (!safeName.toLowerCase().endsWith('.pdf')) {
        safeName = '$safeName.pdf';
      }
      safeName = safeName.replaceAll(RegExp(r'[/\\?%*:|"<>]'), '_');

      var out = File(p.join(downloadsPath.path, safeName));
      if (await out.exists()) {
        final base = p.basenameWithoutExtension(safeName);
        final ext = p.extension(safeName);
        out = File(
          p.join(
            downloadsPath.path,
            '${base}_${DateTime.now().millisecondsSinceEpoch}$ext',
          ),
        );
      }
      await out.writeAsBytes(bytes, flush: true);
      return out.path;
    } catch (_) {
      return null;
    }
  }

  static Future<void> _requestStoragePermissions() async {
    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      if (androidInfo.version.sdkInt >= 30) {
        var permissionStatus = await Permission.manageExternalStorage.request();
        if (permissionStatus != PermissionStatus.granted) {
          permissionStatus = await Permission.storage.request();
        }
      } else {
        await Permission.storage.request();
      }
    } else {
      await Permission.storage.request();
    }
  }

  static Future<Directory> _resolveDownloadsDirectory() async {
    try {
      if (Platform.isAndroid) {
        final externalStorage = await getExternalStorageDirectory();
        if (externalStorage != null) {
          final rootPath = externalStorage.path.split('/Android')[0];
          var downloadsPath = Directory('$rootPath/Download');
          try {
            if (!await downloadsPath.exists()) {
              await downloadsPath.create(recursive: true);
            }
            final testFile = File('${downloadsPath.path}/test_write.tmp');
            await testFile.writeAsString('test');
            await testFile.delete();
          } catch (_) {
            downloadsPath = Directory('/storage/emulated/0/Download');
            try {
              if (!await downloadsPath.exists()) {
                await downloadsPath.create(recursive: true);
              }
              final testFile = File('${downloadsPath.path}/test_write.tmp');
              await testFile.writeAsString('test');
              await testFile.delete();
            } catch (_) {
              downloadsPath = Directory('${externalStorage.path}/Downloads');
            }
          }
          return downloadsPath;
        }
        throw Exception('Could not access external storage');
      }
      return getApplicationDocumentsDirectory();
    } catch (_) {
      return getApplicationDocumentsDirectory();
    }
  }
}
