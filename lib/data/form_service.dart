import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'database.dart';

class FormService {
  final AppDatabase db;
  final _uuid = const Uuid();

  FormService(this.db);

  // -------------------- CREATE --------------------
  Future<String> createFormDraft({
    String title = '',
    Map<String, dynamic> data = const {},
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now().millisecondsSinceEpoch;

    await db.formDao.insertForm(FormsCompanion.insert(
      id: id,
      serverId: const Value.absent(),
      title: Value(title),
      dataJson: Value(jsonEncode(data)),
      status: Value('draft'),
      createdAt: now,
      updatedAt: Value(now),
    ));
    return id;
  }

  Future<String> addImage({required String localPath}) async {
    final id = _uuid.v4();
    final now = DateTime.now().millisecondsSinceEpoch;

    await db.imageDao.insertImage(ImagesCompanion.insert(
      id: id,
      localPath: localPath,
      remoteId: const Value.absent(),
      uploadStatus: Value('pending'),
      errorMessage: const Value.absent(),
      createdAt: now,
    ));
    return id;
  }

  Future<void> attachImageToForm({required String formId, required String imageId}) =>
      db.formImageDao.link(formId, imageId);

  // -------------------- UPDATE --------------------
  Future<void> updateFormData(String formId, Map<String, dynamic> patch) async {
    final f = await db.formDao.getForm(formId);
    if (f == null) return;
    final current = jsonDecode(f.dataJson) as Map<String, dynamic>;
    current.addAll(patch);
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.formDao.updateForm(formId, FormsCompanion(
      dataJson: Value(jsonEncode(current)),
      updatedAt: Value(now),
    ));
  }

  Future<void> setImageUploading(String imageId) =>
      db.imageDao.updateImage(imageId, const ImagesCompanion(uploadStatus: Value('uploading')));

  Future<void> setImageUploaded(String imageId, String remoteId) =>
      db.imageDao.updateImage(imageId, ImagesCompanion(
        remoteId: Value(remoteId),
        uploadStatus: const Value('done'),
        errorMessage: const Value.absent(),
      ));

  Future<void> setImageError(String imageId, String message) =>
      db.imageDao.updateImage(imageId, ImagesCompanion(
        uploadStatus: const Value('error'),
        errorMessage: Value(message),
      ));

  Future<void> setFormStatus(String formId, String status, {String? serverId}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.formDao.updateForm(formId, FormsCompanion(
      status: Value(status),
      serverId: serverId != null ? Value(serverId) : const Value.absent(),
      updatedAt: Value(now),
    ));
  }

  // -------------------- READ --------------------
  Future<FormWithImages?> getFormWithImages(String formId) async {
    final f = await db.formDao.getForm(formId);
    if (f == null) return null;
    final imgs = await db.formImageDao.imagesForForm(formId);
    return FormWithImages(f, imgs);
  }

  Future<List<Form>> listForms({String? status}) => db.formDao.listForms(status: status);

  Future<List<Image>> listImagesOfForm(String formId) => db.formImageDao.imagesForForm(formId);

  // -------------------- DELETE --------------------
  Future<void> detachImageFromForm(String formId, String imageId) =>
      db.formImageDao.unlink(formId, imageId);

  Future<void> deleteFormCascade(String formId) async {
    await db.transaction(() async {
      final ids = await db.formImageDao.imageIdsForForm(formId);
      for (final imgId in ids) {
        await db.formImageDao.unlink(formId, imgId);
      }
      await db.formDao.deleteForm(formId);
    });
  }

  Future<int> deleteOrphanImages() async {
    final allImgs = await (db.select(db.images)).get();
    final links = await (db.select(db.formImages)).get();
    final linked = links.map((e) => e.imageId).toSet();
    final orphans = allImgs.where((i) => !linked.contains(i.id)).toList();
    for (final o in orphans) {
      await db.imageDao.deleteImage(o.id);
    }
    return orphans.length;
  }

  // -------------------- Transactional submit --------------------
  Future<void> submitForm({
    required String formId,
    required Future<({String serverFormId})> Function({
    required Map<String, dynamic> formData,
    required List<String> serverImageIds,
    }) sendToServer,
  }) async {
    await db.transaction(() async {
      final bundle = await getFormWithImages(formId);
      if (bundle == null) {
        throw Exception('Form not found');
      }

      final data = jsonDecode(bundle.form.dataJson) as Map<String, dynamic>;
      final serverImageIds = <String>[];

      for (final img in bundle.images) {
        if (img.remoteId == null) {
          throw Exception('Image ${img.id} not uploaded yet');
        }
        serverImageIds.add(img.remoteId!);
      }

      final result = await sendToServer(
        formData: data,
        serverImageIds: serverImageIds,
      );

      await setFormStatus(formId, 'submitted', serverId: result.serverFormId);
    });
  }
}
