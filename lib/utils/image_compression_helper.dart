import 'dart:io';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:app/utils/logger.dart';

class ImageCompressionHelper {
  /// Recommended values for ImagePicker (use these where you call picker)
  static const double pickImageMaxWidth = 1024;
  static const double pickImageMaxHeight = 1024;
  static const int pickImageQuality = 40;

  static const int targetSizeBytes = 2 * 1024 * 1024; // 2MB

  /// 🔥 MAIN FUNCTION (SAFE + OPTIMIZED)
  static Future<File?> compressImageTo2MB(File file) async {
    try {
      if (!file.existsSync()) return null;

      final originalSize = await file.length();
      Logger.imageLog(
        'Original size: ${(originalSize / 1024 / 1024).toStringAsFixed(2)} MB',
      );

      /// ✅ Skip compression if already small
      if (originalSize <= targetSizeBytes) {
        Logger.imageLog('No compression needed');
        return file;
      }

      final tempDir = await getTemporaryDirectory();
      final fileName = file.path.split('/').last;

      File currentFile = file;

      /// 🔥 MAX 2 ATTEMPTS ONLY (memory safe)
      for (int attempt = 0; attempt < 2; attempt++) {
        final targetPath =
            '${tempDir.path}/cmp_${attempt}_${DateTime.now().millisecondsSinceEpoch}_$fileName';

        /// Adaptive quality
        int quality = attempt == 0 ? 60 : 40;

        Logger.imageLog(
            'Compression attempt $attempt with quality: $quality');

        final result = await FlutterImageCompress.compressAndGetFile(
          currentFile.path, // ✅ IMPORTANT: use previous result
          targetPath,
          quality: quality,

          /// 🔥 Balanced resize (safe for memory)
          minWidth: 1024,
          minHeight: 768,

          format: CompressFormat.jpeg,
        );

        if (result == null) {
          Logger.imageLog('Compression failed at attempt $attempt');
          break;
        }

        final compressedFile = File(result.path);

        if (!await compressedFile.exists()) {
          Logger.imageLog('Compressed file does not exist');
          break;
        }

        final newSize = await compressedFile.length();

        Logger.imageLog(
          'Attempt $attempt result: ${(newSize / 1024 / 1024).toStringAsFixed(2)} MB',
        );

        /// ✅ SUCCESS → stop early
        if (newSize <= targetSizeBytes) {
          Logger.imageLog('Compression successful under 2MB');
          return compressedFile;
        }

        /// 🔥 Use compressed file for next iteration (VERY IMPORTANT)
        currentFile = compressedFile;
      }

      /// ⚠️ Return best attempt (no crash scenario)
      final finalSize = await currentFile.length();
      Logger.imageLog(
        'Final size (best effort): ${(finalSize / 1024 / 1024).toStringAsFixed(2)} MB',
      );

      return currentFile;
    } catch (e) {
      Logger.errorLog('Compression error: $e');

      /// ✅ Never crash — fallback to original
      return file;
    }
  }

  /// 🔥 GENERIC TARGET SIZE FUNCTION (OPTIONAL)
  static Future<File?> compressImageToTargetSize(
    File file,
    double targetSizeMB,
  ) async {
    try {
      if (!file.existsSync()) return null;

      final targetBytes = (targetSizeMB * 1024 * 1024).toInt();
      final originalSize = await file.length();

      Logger.imageLog(
          'Target: $targetSizeMB MB, Original: ${(originalSize / 1024 / 1024).toStringAsFixed(2)} MB');

      if (originalSize <= targetBytes) {
        return file;
      }

      final tempDir = await getTemporaryDirectory();
      final fileName = file.path.split('/').last;

      File currentFile = file;

      /// 🔥 LIMITED ATTEMPTS (safe)
      for (int i = 0; i < 3; i++) {
        final path =
            '${tempDir.path}/target_${i}_${DateTime.now().millisecondsSinceEpoch}_$fileName';

        int quality = (70 - (i * 15)).clamp(30, 70);

        final result = await FlutterImageCompress.compressAndGetFile(
          currentFile.path,
          path,
          quality: quality,
          minWidth: (1024 ~/ (i + 1)).clamp(400, 1024),
          minHeight: (768 ~/ (i + 1)).clamp(300, 768),
          format: CompressFormat.jpeg,
        );

        if (result == null) break;

        final newFile = File(result.path);
        final size = await newFile.length();

        Logger.imageLog(
            'Attempt $i → ${(size / 1024 / 1024).toStringAsFixed(2)} MB');

        if (size <= targetBytes) {
          return newFile;
        }

        currentFile = newFile;
      }

      return currentFile;
    } catch (e) {
      Logger.errorLog('Target compression error: $e');
      return file;
    }
  }
}