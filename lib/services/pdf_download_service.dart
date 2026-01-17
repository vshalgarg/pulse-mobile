import 'dart:io';
import 'package:dio/dio.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class PdfDownloadService {
  static final Dio _dio = Dio();

  static Future<String?> downloadPdf({
    required String reportUrl,
    required String fileName,
    String? token,
  }) async {
    try {
      // Request storage permission for public Downloads access
      PermissionStatus permissionStatus;
      if (Platform.isAndroid) {
        // Check Android version and request appropriate permissions
        final androidInfo = await DeviceInfoPlugin().androidInfo;

        if (androidInfo.version.sdkInt >= 30) {
          // Android 11+ - request manage external storage for public Downloads access
          permissionStatus = await Permission.manageExternalStorage.request();

          if (permissionStatus != PermissionStatus.granted) {
            // Fallback to storage permission
            permissionStatus = await Permission.storage.request();

          }
        } else {
          // Android 10 and below - use storage permission
          permissionStatus = await Permission.storage.request();

        }
      } else {
        permissionStatus = await Permission.storage.request();
      }

      if (permissionStatus != PermissionStatus.granted) {

      }

      // Get public Downloads directory using Environment.getExternalStoragePublicDirectory
      Directory downloadsPath;
      try {
        if (Platform.isAndroid) {
          // Use the proper method to get public Downloads directory
          final externalStorage = await getExternalStorageDirectory();
          if (externalStorage != null) {
            // Get the root of external storage (remove the app-specific path)
            final rootPath = externalStorage.path.split('/Android')[0];
            downloadsPath = Directory('$rootPath/Download');

            // Test if we can write to public Downloads
            try {
              if (!await downloadsPath.exists()) {
                await downloadsPath.create(recursive: true);
              }
              // Test write access
              final testFile = File('${downloadsPath.path}/test_write.tmp');
              await testFile.writeAsString('test');
              await testFile.delete();

            } catch (e) {

              // Try alternative public Downloads path
              downloadsPath = Directory('/storage/emulated/0/Download');

              try {
                if (!await downloadsPath.exists()) {
                  await downloadsPath.create(recursive: true);
                }
                // Test write access
                final testFile = File('${downloadsPath.path}/test_write.tmp');
                await testFile.writeAsString('test');
                await testFile.delete();

              } catch (e2) {

                // Final fallback to app's external storage
                downloadsPath = Directory('${externalStorage.path}/Downloads');

              }
            }
          } else {
            throw Exception('Could not access external storage');
          }
        } else {
          // For iOS, use documents directory
          downloadsPath = await getApplicationDocumentsDirectory();
        }
      } catch (e) {

        // Final fallback to app documents directory
        downloadsPath = await getApplicationDocumentsDirectory();

      }

      // Create downloads folder if it doesn't exist
      if (!await downloadsPath.exists()) {
        await downloadsPath.create(recursive: true);
      }

      final filePath = '${downloadsPath.path}/$fileName.pdf';

      // Prepare headers
      final headers = <String, String>{
        'User-Agent': 'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36',
      };

      // Add Authorization header if token is provided
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      // Download the PDF with proper headers
      await _dio.download(
        reportUrl,
        filePath,
        options: Options(
          headers: {
            'User-Agent': 'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36',
          },
        ),
      );

      return filePath;
    } catch (e) {

      return null;
    }
  }

  static Future<String?> downloadPdfWithFormData({
    required String url,
    required Map<String, String> formData,
    required String fileName,
    required String token,
  }) async {
    try {
      // Request storage permission for public Downloads access
      PermissionStatus permissionStatus;
      if (Platform.isAndroid) {
        // Check Android version and request appropriate permissions
        final androidInfo = await DeviceInfoPlugin().androidInfo;

        if (androidInfo.version.sdkInt >= 30) {
          // Android 11+ - request manage external storage for public Downloads access
          permissionStatus = await Permission.manageExternalStorage.request();

          if (permissionStatus != PermissionStatus.granted) {
            // Fallback to storage permission
            permissionStatus = await Permission.storage.request();

          }
        } else {
          // Android 10 and below - use storage permission
          permissionStatus = await Permission.storage.request();

        }
      } else {
        permissionStatus = await Permission.storage.request();
      }

      if (permissionStatus != PermissionStatus.granted) {

      }

      // Get public Downloads directory using Environment.getExternalStoragePublicDirectory
      Directory downloadsPath;
      try {
        if (Platform.isAndroid) {
          // Use the proper method to get public Downloads directory
          final externalStorage = await getExternalStorageDirectory();
          if (externalStorage != null) {
            // Get the root of external storage (remove the app-specific path)
            final rootPath = externalStorage.path.split('/Android')[0];
            downloadsPath = Directory('$rootPath/Download');

            // Test if we can write to public Downloads
            try {
              if (!await downloadsPath.exists()) {
                await downloadsPath.create(recursive: true);
              }
              // Test write access
              final testFile = File('${downloadsPath.path}/test_write.tmp');
              await testFile.writeAsString('test');
              await testFile.delete();

            } catch (e) {

              // Try alternative public Downloads path
              downloadsPath = Directory('/storage/emulated/0/Download');

              try {
                if (!await downloadsPath.exists()) {
                  await downloadsPath.create(recursive: true);
                }
                // Test write access
                final testFile = File('${downloadsPath.path}/test_write.tmp');
                await testFile.writeAsString('test');
                await testFile.delete();

              } catch (e2) {

                // Final fallback to app's external storage
                downloadsPath = Directory('${externalStorage.path}/Downloads');

              }
            }
          } else {
            throw Exception('Could not access external storage');
          }
        } else {
          // For iOS, use documents directory
          downloadsPath = await getApplicationDocumentsDirectory();
        }
      } catch (e) {

        // Final fallback to app documents directory
        downloadsPath = await getApplicationDocumentsDirectory();

      }

      // Create downloads folder if it doesn't exist
      if (!await downloadsPath.exists()) {
        await downloadsPath.create(recursive: true);
      }

      final filePath = '${downloadsPath.path}/$fileName.pdf';

      // Create FormData for the POST request
      final dioFormData = FormData.fromMap(formData);

      // Download the PDF with POST request and proper headers
      await _dio
          .post(
            url,
            data: dioFormData,
            options: Options(
              headers: {
                'Authorization': 'Bearer $token',
                'User-Agent':
                    'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36',
              },
              responseType: ResponseType.bytes,
            ),
            onReceiveProgress: (received, total) {
              if (total != -1) {
              }
            },
          )
          .then((response) async {
            // Save the response bytes to file
            final file = File(filePath);
            await file.writeAsBytes(response.data);

          });

      return filePath;
    } catch (e) {

      return null;
    }
  }
}
