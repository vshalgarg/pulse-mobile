import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../models/asset_audit_post_model.dart';
import 'database.dart';// put your model classes here (the ones you pasted)

class AssetAuditService {
  final AppDatabase db;
  final _uuid = const Uuid();

  AssetAuditService(this.db);

  // -------------------- CREATE / UPSERT --------------------

  /// Save or update a local asset audit record from a request model.
  Future<void> upsertFromRequest(AssetAuditPostRequest req) async {
    await db.assetAuditDao.upsert(AssetAuditsCompanion(
      assetAuditSiteRespId: Value(req.assetAuditSiteRespId),
      localAuditLogId: Value(req.localAuditLogId),

      auditSchId: Value(req.auditSchId),
      siteAuditSchId: Value(req.siteAuditSchId),
      siteId: Value(req.siteId),
      itemInstanceId: Value(req.itemInstanceId),
      nexgenSerialNo: Value(req.nexgenSerialNo),
      itemTypeId: Value(req.itemTypeId),
      qrCodeScanned: Value(req.qrCodeScanned),
      qrCodeScannedTs: Value(req.qrCodeScannedTs),

      photoId: Value(req.photoId),
      photoTakenTs: Value(req.photoTakenTs), // request had String non-null, but safe as Value()

      assetStatus: Value(req.assetStatus),
      longitude: Value(req.longitude),
      latitude: Value(req.latitude),
      itemTypeRemark: Value(req.itemTypeRemark),

      localQrCodeScannedTs: Value(req.localQrCodeScannedTs),
      localCreatedDt: Value(req.localCreatedDt),
      localModifiedDt: Value(req.localModifiedDt),

      syncProcessId: Value(req.syncProcessId),
      isActive: Value(req.isActive),
      remarks: Value(req.remarks),

      // local sync status
      syncStatus: const Value('draft'),
      lastSyncError: const Value(null),
      serverUpdatedAt: const Value(null),
    ));
  }

  /// After server POST returns response, persist server fields.
  Future<void> applyServerResponse(AssetAuditPostResponse res) async {
    await db.assetAuditDao.upsert(AssetAuditsCompanion(
      // Match by localAuditLogId (your local PK)
      localAuditLogId: Value(res.localAuditLogId),

      // Server-side fields that may have changed/been assigned
      assetAuditSiteRespId: Value(res.assetAuditSiteRespId),
      photoId: Value(res.photoId),
      photoTakenTs: Value(res.photoTakenTs),

      // If server echoes other fields and you want to trust server, set them too:
      auditSchId: Value(res.auditSchId),
      siteAuditSchId: Value(res.siteAuditSchId),
      siteId: Value(res.siteId),
      itemInstanceId: Value(res.itemInstanceId),
      nexgenSerialNo: Value(res.nexgenSerialNo),
      itemTypeId: Value(res.itemTypeId),
      qrCodeScanned: Value(res.qrCodeScanned),
      qrCodeScannedTs: Value(res.qrCodeScannedTs),
      assetStatus: Value(res.assetStatus),
      longitude: Value(res.longitude),
      latitude: Value(res.latitude),
      itemTypeRemark: Value(res.itemTypeRemark),
      localQrCodeScannedTs: Value(res.localQrCodeScannedTs),
      localCreatedDt: Value(res.localCreatedDt),
      localModifiedDt: Value(res.localModifiedDt),
      syncProcessId: Value(res.syncProcessId),
      isActive: Value(res.isActive),
      remarks: Value(res.remarks),

      // Mark submitted
      syncStatus: const Value('submitted'),
      lastSyncError: const Value(null),
      serverUpdatedAt: Value(DateTime.now().toIso8601String()),
    ));
  }

  // -------------------- PHOTOS --------------------

  /// Stage a photo row before upload.
  Future<String> addLocalPhoto({
    required int localAuditLogId,
    required String localPath,
    String? fileName,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.auditPhotoDao.insertOne(AuditPhotosCompanion.insert(
      id: id,
      localAuditLogId: localAuditLogId,
      localPath: localPath,
      fileName: Value(fileName),
      imgId: const Value.absent(),
      message: const Value.absent(),
      status: const Value('pending'),
      uploadStatus: const Value('pending'),
      errorMessage: const Value.absent(),
      createdAt: now,
      updatedAt: Value(now),
    ));
    return id;
  }

  Future<void> markPhotoUploading(String photoRowId) async {
    await db.auditPhotoDao.updateById(
      photoRowId,
      const AuditPhotosCompanion(
        uploadStatus: Value('uploading'),
      ),
    );
  }

  Future<void> markPhotoUploaded({
    required String photoRowId,
    required String imgId,
    String? status,
    String? message,
  }) async {
    await db.auditPhotoDao.updateById(
      photoRowId,
      AuditPhotosCompanion(
        imgId: Value(imgId),
        status: Value(status),
        message: Value(message),
        uploadStatus: const Value('done'),
        errorMessage: const Value.absent(),
        updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
  }

  Future<void> markPhotoError(String photoRowId, String error) async {
    await db.auditPhotoDao.updateById(
      photoRowId,
      AuditPhotosCompanion(
        uploadStatus: const Value('error'),
        errorMessage: Value(error),
        updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
  }

  Future<List<DbAuditPhoto>> photosForLocalAudit(int localAuditLogId) =>
      db.auditPhotoDao.listByLocalAuditLogId(localAuditLogId);

  // -------------------- READ / LIST --------------------

  Future<DbAssetAudit?> getByLocalId(int localAuditLogId) =>
      db.assetAuditDao.getByLocalId(localAuditLogId);

  Future<List<DbAssetAudit>> listDrafts() => db.assetAuditDao.listByStatus('draft');

  // -------------------- DELETE --------------------

  Future<void> deleteAuditCascade(int localAuditLogId) async {
    await db.transaction(() async {
      final photos = await db.auditPhotoDao.listByLocalAuditLogId(localAuditLogId);
      for (final p in photos) {
        await db.auditPhotoDao.deleteById(p.id);
      }
      await db.assetAuditDao.deleteByLocalId(localAuditLogId);
    });
  }
}
