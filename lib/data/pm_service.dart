import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../models/PmPostRequestModel.dart';
import '../models/energy_reading_detail_model.dart';
import 'database.dart';


class PmService {
  final AppDatabase db;
  final _uuid = const Uuid();

  PmService(this.db);

  // -------------------- PM RESPONSES --------------------

  Future<void> upsertPmFromRequest(PmPostRequest r) async {
    await db.pmResponseDao.upsert(PmResponsesCompanion(
      pmCheckListSiteRespId: Value(r.pmCheckListSiteRespId),
      pmCheckListMstId: Value(r.pmCheckListMstId),
      auditSchId: Value(r.auditSchId),
      siteAuditSchId: Value(r.siteAuditSchId),
      siteId: Value(r.siteId),
      pmItemType: Value(r.pmItemType),
      checklistDesc: Value(r.checklistDesc),
      resp: Value(r.resp),
      clOrder: Value(r.clOrder),
      photoId: Value(r.photoId),
      photoTakenTs: Value(r.photoTakenTs),
      longitude: Value(r.longitude),
      latitude: Value(r.latitude),
      localAuditLogId: Value(r.localAuditLogId),
      localCreatedDt: Value(r.localCreatedDt),
      localModifiedDt: Value(r.localModifiedDt),
      syncProcessId: Value(r.syncProcessId),
      isActive: Value(r.isActive),
      remarks: Value(r.remarks),
      // local sync flags
      syncStatus: const Value('draft'),
      lastSyncError: const Value(null),
      serverUpdatedAt: const Value(null),
    ));
  }

  Future<void> applyPmServerResponse(PmPostResponse res, {
    required int pmCheckListMstId,
    required int siteAuditSchId,
  }) async {
    await db.pmResponseDao.patch(
      pmCheckListMstId: pmCheckListMstId,
      siteAuditSchId: siteAuditSchId,
      data: PmResponsesCompanion(
        pmCheckListSiteRespId: Value(res.pmCheckListSiteRespId),
        syncStatus: Value(res.success ? 'submitted' : 'error'),
        lastSyncError: Value(res.success ? null : res.message),
        serverUpdatedAt: Value(DateTime.now().toIso8601String()),
      ),
    );
  }

  Future<List<DbPmResponse>> listPmForAudit(int siteAuditSchId) =>
      db.pmResponseDao.listForAudit(siteAuditSchId);

  // -------------------- PM PHOTOS --------------------

  Future<String> addLocalPmPhoto({
    required int localAuditLogId,
    required String localPath,
    String? fileName,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.pmPhotoDao.insertOne(PmPhotosCompanion.insert(
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


  Future<void> markPmPhotoUploading(String photoRowId) async {
    await db.pmPhotoDao.updateById(
      photoRowId,
      const PmPhotosCompanion(uploadStatus: Value('uploading')),
    );
  }

  Future<void> markPmPhotoUploaded({
    required String photoRowId,
    required String imgId,
    String? status,
    String? message,
  }) async {
    await db.pmPhotoDao.updateById(
      photoRowId,
      PmPhotosCompanion(
        imgId: Value(imgId),
        status: Value(status),
        message: Value(message),
        uploadStatus: const Value('done'),
        errorMessage: const Value.absent(),
        updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
  }

  Future<void> markPmPhotoError(String photoRowId, String error) async {
    await db.pmPhotoDao.updateById(
      photoRowId,
      PmPhotosCompanion(
        uploadStatus: const Value('error'),
        errorMessage: Value(error),
        updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
  }

  Future<List<DbPmPhoto>> listPmPhotos(int siteAuditSchId) =>
      db.pmPhotoDao.listForAudit(siteAuditSchId);

  // -------------------- ENERGY READINGS --------------------

  Future<void> upsertEnergyFromRequest(EnergyReadingDetailRequest r) async {
    await db.energyReadingDao.upsert(EnergyReadingsCompanion(
      energyReadingId: Value(r.energyReadingId),
      auditSchId: Value(r.auditSchId),
      siteAuditSchId: Value(r.siteAuditSchId),
      siteId: Value(r.siteId),
      connectionType: Value(r.connectionType),
      consumerNo: Value(r.consumerNo),
      ebMeterStatus: Value(r.ebMeterStatus),
      ebConnectionType: Value(r.ebConnectionType),
      ebMeterType: Value(r.ebMeterType),
      ebMeterNo: Value(r.ebMeterNo),
      ebMeterReading: Value(r.ebMeterReading),
      ebKwhInSebMeter: Value(r.ebKwhInSebMeter),
      ebKvaInSebMeter: Value(r.ebKvaInSebMeter),
      ebKwhInCcu: Value(r.ebKwhInCcu),
      ebKvaInCcu: Value(r.ebKvaInCcu),
      voltage: Value(r.voltage),
      load: Value(r.load),
      documentName: Value(r.documentName),
      anyMajorHazardousPunchPoint: Value(r.anyMajorHazardousPunchPoint),
      ebAttachmentFileId: Value(r.ebAttachmentFileId),
      isActive: Value(r.isActive),
      remarks: Value(r.remarks),
      syncStatus: const Value('draft'),
      lastSyncError: const Value(null),
      serverUpdatedAt: const Value(null),
    ));
  }

  Future<void> markEnergySubmitted({
    required int energyReadingId,
    required int siteAuditSchId,
    String? serverMessage,
  }) async {
    await db.energyReadingDao.patch(
      energyReadingId: energyReadingId,
      siteAuditSchId: siteAuditSchId,
      data: EnergyReadingsCompanion(
        syncStatus: const Value('submitted'),
        lastSyncError: Value(serverMessage),
        serverUpdatedAt: Value(DateTime.now().toIso8601String()),
      ),
    );
  }
}
