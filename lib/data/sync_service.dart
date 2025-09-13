// lib/data/sync_service.dart
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;

import '../services/api_service.dart';
import 'database.dart';
import 'form_service.dart';

class SyncService {
  final AppDatabase db;
  final FormService formService;
  final ApiService api;

  SyncService({
    required this.db,
    required this.formService,
    required this.api,
  });

  /// Call from your "Sync" button for a specific form.
  Future<void> syncFormById(String formId) async {
    // 1) Upload any images without remoteId
    final imgs = await formService.listImagesOfForm(formId);
    for (final img in imgs) {
      if (img.remoteId == null) {
        await _uploadImage(formId: formId, image: img);
      }
    }

    // 2) Submit the form as JSON with the server image IDs
    await formService.submitForm(
      formId: formId,
      sendToServer: ({
        required Map<String, dynamic> formData,
        required List<String> serverImageIds,
      }) async {
        final serverFormId = await _submitFormJson(
          formData: formData,
          serverImageIds: serverImageIds,
        );
        return (serverFormId: serverFormId);
      },
    );
  }

  /// Optional: Sync all drafts
  Future<void> syncAllDrafts() async {
    final drafts = await formService.listForms(status: 'draft');
    for (final f in drafts) {
      try {
        await syncFormById(f.id);
      } catch (_) {/* continue */}
    }
  }

  // -------------------- Helpers --------------------

  Future<void> _uploadImage({
    required String formId,
    required Image image,
  }) async {
    final file = File(image.localPath);
    if (!await file.exists()) {
      await formService.setImageError(image.id, 'Local file not found');
      throw Exception('File not found: ${image.localPath}');
    }

    await formService.setImageUploading(image.id);

    final mime = lookupMimeType(image.localPath) ?? 'application/octet-stream';
    final parts = mime.split('/');
    final mf = await MultipartFile.fromFile(
      image.localPath,
      filename: p.basename(image.localPath),
      contentType: MediaType(parts[0], parts[1])
      ,
    );

    final fields = <String, dynamic>{
      'meta': jsonEncode({
        'source': 'mobile',
        'formLocalId': formId,
      }),
    };

    // Uses ApiService.postMultipart (Option 1 helper)
    final res = await api.postMultipart<Map<String, dynamic>>(
      path: '/upload/image',    // TODO: adjust to your endpoint
      fields: fields,
      files: [mf],
      fileFieldName: 'file',    // TODO: change if your API expects another name
    );

    if (!res.isSuccess || res.data == null) {
      await formService.setImageError(
        image.id,
        res.errorMessage ?? 'Upload failed ${res.statusCode}',
      );
      throw Exception('Image upload failed: ${res.errorMessage ?? res.statusCode}');
    }

    // Expecting { "imageId": "abc123" }
    final remoteId = res.data!['imageId']?.toString();
    if (remoteId == null || remoteId.isEmpty) {
      await formService.setImageError(image.id, 'Missing imageId in response');
      throw Exception('Upload ok but missing imageId');
    }

    await formService.setImageUploaded(image.id, remoteId);
  }

  /// ✅ This is the missing method you need.
  Future<String> _submitFormJson({
    required Map<String, dynamic> formData,
    required List<String> serverImageIds,
  }) async {
    final payload = {
      'form': formData,
      'attachments': serverImageIds,
      'client': {'app': 'flutter', 'version': 1},
    };

    final res = await api.postJson<Map<String, dynamic>>(
      path: '/forms', // TODO: adjust to your endpoint
      body: payload,
    );

    if (!res.isSuccess || res.data == null) {
      throw Exception('Form submit failed: ${res.errorMessage ?? res.statusCode}');
    }

    final serverId = res.data!['formId']?.toString();
    if (serverId == null || serverId.isEmpty) {
      throw Exception('Submit ok but missing formId');
    }
    return serverId;
  }

  // -------------------- Optional: One-shot multipart --------------------

  /// If your backend prefers a single multipart with form JSON + files:
  Future<String> submitMultipartAll({required String formId}) async {
    final bundle = await formService.getFormWithImages(formId);
    if (bundle == null) throw Exception('Form not found');

    final fields = <String, dynamic>{
      'form': bundle.form.dataJson, // or jsonEncode(Map) if you store a Map
    };

    final filesMap = <String, List<MultipartFile>>{};
    int idx = 0;
    for (final img in bundle.images) {
      final f = File(img.localPath);
      if (!await f.exists()) { idx++; continue; }
      final mime = lookupMimeType(img.localPath) ?? 'application/octet-stream';
      final parts = mime.split('/');
      final mf = await MultipartFile.fromFile(
        img.localPath,
        filename: p.basename(img.localPath),
        contentType: MediaType(parts[0], parts[1])
        ,
      );
      filesMap['file$idx'] = [mf]; // separate field per file
      idx++;
    }

    final res = await api.postMultipart<Map<String, dynamic>>(
      path: '/forms/multipart', // TODO: adjust to your endpoint
      fields: fields,
      filesMap: filesMap,
    );

    if (!res.isSuccess || res.data == null) {
      throw Exception('Multipart submit failed: ${res.errorMessage ?? res.statusCode}');
    }

    final serverId = res.data!['formId']?.toString();
    if (serverId == null || serverId.isEmpty) {
      throw Exception('Multipart ok but missing formId');
    }

    await formService.setFormStatus(formId, 'submitted', serverId: serverId);
    return serverId;
  }
}
