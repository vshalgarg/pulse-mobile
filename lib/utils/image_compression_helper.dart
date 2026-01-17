import 'dart:io';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:app/utils/logger.dart';

class ImageCompressionHelper {
  /// Compresses an image file to approximately 2MB or less
  /// Returns the compressed file path, or null if compression fails
  static Future<File?> compressImageTo2MB(File imageFile) async {
    try {
      // Get the file size in bytes
      final fileSize = await imageFile.length();
      Logger.imageLog('Original image size: ${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB');

      // If file is already under 2MB, return as is
      if (fileSize <= 2 * 1024 * 1024) {
        Logger.imageLog('Image is already under 2MB, no compression needed');
        return imageFile;
      }
      
      Logger.imageLog('Image needs compression - size: ${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB');

      // Get temporary directory
      final tempDir = await getTemporaryDirectory();
      final fileName = imageFile.path.split('/').last;
      final compressedPath = '${tempDir.path}/compressed_$fileName';
      
      Logger.imageLog('Temp directory: ${tempDir.path}');
      Logger.imageLog('Original file name: $fileName');
      Logger.imageLog('Compressed path: $compressedPath');

      // Calculate compression quality based on file size
      // Start with a lower quality for larger files
      int quality = 70; // Start with lower quality for better compression
      if (fileSize > 10 * 1024 * 1024) {
        quality = 40; // Very large files - more aggressive compression
      } else if (fileSize > 5 * 1024 * 1024) {
        quality = 50; // Large files - more aggressive compression
      } else if (fileSize > 3 * 1024 * 1024) {
        quality = 60; // Medium-large files - more aggressive compression
      }

      Logger.imageLog('Starting compression with quality: $quality');

      // Compress the image
      Logger.imageLog('Starting compression with path: ${imageFile.absolute.path}');
      Logger.imageLog('Output path: $compressedPath');
      
      final compressedXFile = await FlutterImageCompress.compressAndGetFile(
        imageFile.absolute.path,
        compressedPath,
        quality: quality,
        minWidth: 600, // Reduced minimum width for better compression
        minHeight: 400, // Reduced minimum height for better compression
        format: CompressFormat.jpeg, // Use JPEG for better compression
      );

      Logger.imageLog('Compression result: ${compressedXFile != null ? "Success" : "Failed"}');
      
      if (compressedXFile == null) {
        Logger.imageLog('Compression failed: compressedFile is null');
        return null;
      }

      // Convert XFile to File
      final compressedFile = File(compressedXFile.path);
      Logger.imageLog('Compressed file path: ${compressedFile.path}');
      Logger.imageLog('Compressed file exists: ${await compressedFile.exists()}');

      // Check if the compressed file is under 2MB
      final compressedSize = await compressedFile.length();
      Logger.imageLog('Compressed image size: ${(compressedSize / 1024 / 1024).toStringAsFixed(2)} MB');
      Logger.imageLog('Target size: 2.0 MB');
      Logger.imageLog('Is under 2MB: ${compressedSize <= 2 * 1024 * 1024}');

      // If still over 2MB, try with lower quality
      if (compressedSize > 2 * 1024 * 1024) {
        Logger.imageLog('Still over 2MB, trying with lower quality...');
        
        // Try with progressively lower quality
        for (int newQuality = quality - 15; newQuality >= 20; newQuality -= 15) {
          final newCompressedPath = '${tempDir.path}/compressed_${newQuality}_$fileName';
          
          final newCompressedXFile = await FlutterImageCompress.compressAndGetFile(
            imageFile.absolute.path,
            newCompressedPath,
            quality: newQuality,
            minWidth: 400, // Further reduce minimum dimensions for more compression
            minHeight: 300,
            format: CompressFormat.jpeg,
          );

          if (newCompressedXFile != null) {
            final newCompressedFile = File(newCompressedXFile.path);
            final newSize = await newCompressedFile.length();
            Logger.imageLog('Quality $newQuality: ${(newSize / 1024 / 1024).toStringAsFixed(2)} MB');
            
            if (newSize <= 2 * 1024 * 1024) {
              Logger.imageLog('Successfully compressed to under 2MB with quality: $newQuality');
              return newCompressedFile;
            }
          }
        }

        // If still over 2MB, try with even smaller dimensions
        Logger.imageLog('Trying with smaller dimensions...');
        final finalCompressedPath = '${tempDir.path}/compressed_final_$fileName';
        
        final finalCompressedXFile = await FlutterImageCompress.compressAndGetFile(
          imageFile.absolute.path,
          finalCompressedPath,
          quality: 20, // Very low quality
          minWidth: 300, // Very small dimensions
          minHeight: 200,
          format: CompressFormat.jpeg,
        );

        if (finalCompressedXFile != null) {
          final finalCompressedFile = File(finalCompressedXFile.path);
          final finalSize = await finalCompressedFile.length();
          Logger.imageLog('Final compressed size: ${(finalSize / 1024 / 1024).toStringAsFixed(2)} MB');
          return finalCompressedFile;
        }
      }

      return compressedFile;
    } catch (e) {
      Logger.errorLog('Error compressing image: $e');
      return null;
    }
  }

  /// Compresses an image file to a specific target size in MB
  /// Returns the compressed file path, or null if compression fails
  static Future<File?> compressImageToTargetSize(File imageFile, double targetSizeMB) async {
    try {
      final fileSize = await imageFile.length();
      final targetSizeBytes = (targetSizeMB * 1024 * 1024).round();
      
      Logger.imageLog('Original image size: ${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB');
      Logger.imageLog('Target size: ${targetSizeMB} MB');

      if (fileSize <= targetSizeBytes) {
        Logger.imageLog('Image is already under target size, no compression needed');
        return imageFile;
      }

      final tempDir = await getTemporaryDirectory();
      final fileName = imageFile.path.split('/').last;

      // Calculate initial quality based on size ratio
      double sizeRatio = fileSize / targetSizeBytes;
      int quality = (100 / sizeRatio).round().clamp(20, 95);
      
      Logger.imageLog('Starting compression with quality: $quality');

      for (int attempt = 0; attempt < 5; attempt++) {
        final compressedPath = '${tempDir.path}/compressed_${attempt}_$fileName';
        
        final compressedXFile = await FlutterImageCompress.compressAndGetFile(
          imageFile.absolute.path,
          compressedPath,
          quality: quality,
          minWidth: (800 / (attempt + 1)).round().clamp(200, 800),
          minHeight: (600 / (attempt + 1)).round().clamp(150, 600),
          format: CompressFormat.jpeg,
        );

        if (compressedXFile != null) {
          final compressedFile = File(compressedXFile.path);
          final compressedSize = await compressedFile.length();
          Logger.imageLog('Attempt ${attempt + 1}: Quality $quality, Size: ${(compressedSize / 1024 / 1024).toStringAsFixed(2)} MB');
          
          if (compressedSize <= targetSizeBytes) {
            Logger.imageLog('Successfully compressed to target size');
            return compressedFile;
          }
        }

        // Reduce quality for next attempt
        quality = (quality * 0.8).round().clamp(20, quality - 10);
      }

      Logger.imageLog('Could not compress to target size, returning best attempt');
      return null;
    } catch (e) {
      Logger.errorLog('Error compressing image to target size: $e');
      return null;
    }
  }
}
