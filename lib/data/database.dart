// lib/data/database.dart
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'database.g.dart';

// -------------------- Tables --------------------

class Forms extends Table {
  TextColumn get id => text()();                  // local UUID
  TextColumn get serverId => text().nullable()(); // after submit
  TextColumn get title => text().withDefault(const Constant(''))();
  TextColumn get dataJson => text().withDefault(const Constant('{}'))();
  TextColumn get status => text().withDefault(const Constant('draft'))(); // draft|submitted|error
  IntColumn get createdAt => integer()();         // epoch ms
  IntColumn get updatedAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class Images extends Table {
  TextColumn get id => text()();            // local UUID
  TextColumn get localPath => text()();
  TextColumn get remoteId => text().nullable()();
  TextColumn get uploadStatus => text().withDefault(const Constant('pending'))(); // pending|uploading|done|error
  TextColumn get errorMessage => text().nullable()();
  IntColumn get createdAt => integer()();   // epoch ms

  @override
  Set<Column> get primaryKey => {id};
}

class FormImages extends Table {
  TextColumn get formId => text()();
  TextColumn get imageId => text()();
  @override
  Set<Column> get primaryKey => {formId, imageId};

  @override
  List<String> get customConstraints => [
    'FOREIGN KEY(form_id) REFERENCES forms(id) ON DELETE CASCADE',
    'FOREIGN KEY(image_id) REFERENCES images(id) ON DELETE CASCADE',
  ];
}

// ==================== ASSET AUDIT TABLES ====================

@DataClassName('DbAssetAudit')
class AssetAudits extends Table {
  // Server PK (nullable until synced)
  IntColumn get assetAuditSiteRespId => integer().nullable()();

  // Local primary key (stable locally, used to link photos, etc.)
  IntColumn get localAuditLogId => integer()(); // your local ID

  IntColumn get auditSchId => integer()();
  IntColumn get siteAuditSchId => integer()();
  IntColumn get siteId => integer()();
  IntColumn get itemInstanceId => integer()();
  TextColumn get nexgenSerialNo => text()();
  IntColumn get itemTypeId => integer()();
  BoolColumn get qrCodeScanned => boolean()();
  TextColumn get qrCodeScannedTs => text().nullable()();

  // photoId from server (keep nullable; sometimes not set)
  TextColumn get photoId => text().nullable()();

  // Some APIs return photoTakenTs optional; keep nullable to be safe
  TextColumn get photoTakenTs => text().nullable()();

  TextColumn get assetStatus => text()();
  TextColumn get longitude => text().nullable()();
  TextColumn get latitude => text().nullable()();
  TextColumn get itemTypeRemark => text().nullable()();

  TextColumn get localQrCodeScannedTs => text()();
  TextColumn get localCreatedDt => text()();
  TextColumn get localModifiedDt => text()();

  IntColumn get syncProcessId => integer()();
  BoolColumn get isActive => boolean()();
  TextColumn get remarks => text().nullable()();

  // Local sync bookkeeping
  // draft | pending_upload | submitted | error
  TextColumn get syncStatus => text().withDefault(const Constant('draft'))();
  TextColumn get lastSyncError => text().nullable()();
  TextColumn get serverUpdatedAt => text().nullable()();

  TextColumn get screenName => text().nullable()();
  TextColumn get photoReflocalID => text().nullable()();

  // Make the local ID the primary key
  @override
  Set<Column> get primaryKey => {localAuditLogId};

  @override
  List<String> get customConstraints => [
    // Optional uniqueness on server ID when present
    'UNIQUE(asset_audit_site_resp_id) ON CONFLICT REPLACE'
  ];
}

@DataClassName('DbAuditPhoto')
class AuditPhotos extends Table {
  // Local photo row id (UUID or any string you like). Using text for flexibility.
  TextColumn get id => text()();            // local UUID for the photo row
  IntColumn get localAuditLogId => integer()(); // FK to AssetAudits.localAuditLogId

  // Local file info
  TextColumn get localPath => text()();     // device path
  TextColumn get fileName => text().nullable()();

  // Server response fields
  TextColumn get imgId => text().nullable()();  // from AssetAuditPhotoUploadResponse.imgId
  TextColumn get message => text().nullable()();
  TextColumn get status => text().nullable()();

  // Upload status: pending | uploading | done | error
  TextColumn get uploadStatus => text().withDefault(const Constant('pending'))();
  TextColumn get errorMessage => text().nullable()();

  IntColumn get createdAt => integer()();   // epoch ms
  IntColumn get updatedAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    'FOREIGN KEY(local_audit_log_id) REFERENCES asset_audits(local_audit_log_id) ON DELETE CASCADE'
  ];
}

// ==================== PM CHECKLIST ====================

@DataClassName('DbPmResponse')
class PmResponses extends Table {
  // Server PK (nullable until server returns it)
  IntColumn get pmCheckListSiteRespId => integer().nullable()();

  // Master/question identifier from server
  IntColumn get pmCheckListMstId => integer()();

  // Audit linkage
  IntColumn get auditSchId => integer()();
  IntColumn get siteAuditSchId => integer()();
  IntColumn get siteId => integer()();

  // Question / Answer
  TextColumn get pmItemType => text()();        // e.g., "DG"
  TextColumn get checklistDesc => text()();     // question text
  TextColumn get resp => text().nullable()();   // user's answer (TEXT/DROPDOWN/RADIO value)
  IntColumn get clOrder => integer()();

  // Optional photo and geo
  TextColumn get photoId => text().nullable()();
  TextColumn get photoTakenTs => text().nullable()();
  TextColumn get longitude => text().nullable()();
  TextColumn get latitude => text().nullable()();

  // Local bookkeeping (nullable because your request makes them optional)
  IntColumn get localAuditLogId => integer().nullable()();
  TextColumn get localCreatedDt => text().nullable()();
  TextColumn get localModifiedDt => text().nullable()();
  IntColumn get syncProcessId => integer().nullable()();

  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  TextColumn get remarks => text().nullable()();

  // Sync status: draft | pending_upload | submitted | error
  TextColumn get syncStatus => text().withDefault(const Constant('draft'))();
  TextColumn get lastSyncError => text().nullable()();
  TextColumn get serverUpdatedAt => text().nullable()();
  TextColumn get screenName => text().nullable()();
  TextColumn get photoReflocalID => text().nullable()();

  // Local primary key (composite) so you can have multiple rows for one audit
  @override
  Set<Column> get primaryKey => {pmCheckListMstId, siteAuditSchId};
}

// Optional: store PM photo upload responses (Selfie/IMG)
@DataClassName('DbPmPhoto')
class PmPhotos extends Table {
  // Local photo row id (UUID or any string you like). Using text for flexibility.
  TextColumn get id => text()();            // local UUID for the photo row
  IntColumn get localAuditLogId => integer()(); // FK to AssetAudits.localAuditLogId

  // Local file info
  TextColumn get localPath => text()();     // device path
  TextColumn get fileName => text().nullable()();

  // Server response fields
  TextColumn get imgId => text().nullable()();  // from AssetAuditPhotoUploadResponse.imgId
  TextColumn get message => text().nullable()();
  TextColumn get status => text().nullable()();

  // Upload status: pending | uploading | done | error
  TextColumn get uploadStatus => text().withDefault(const Constant('pending'))();
  TextColumn get errorMessage => text().nullable()();

  IntColumn get createdAt => integer()();   // epoch ms
  IntColumn get updatedAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    'FOREIGN KEY(local_audit_log_id) REFERENCES asset_audits(local_audit_log_id) ON DELETE CASCADE'
  ];
}

// ==================== ENERGY READING DETAILS ====================

@DataClassName('DbEnergyReading')
class EnergyReadings extends Table {
  // Server/business keys
  IntColumn get energyReadingId => integer()();   // provided by server or 0 for draft
  IntColumn get auditSchId => integer()();
  IntColumn get siteAuditSchId => integer()();
  IntColumn get siteId => integer()();

  TextColumn get connectionType => text()();
  TextColumn get consumerNo => text()();
  TextColumn get ebMeterStatus => text()();
  TextColumn get ebConnectionType => text()();
  TextColumn get ebMeterType => text()();
  TextColumn get ebMeterNo => text()();

  RealColumn get ebMeterReading => real()();
  RealColumn get ebKwhInSebMeter => real()();
  RealColumn get ebKvaInSebMeter => real()();
  RealColumn get ebKwhInCcu => real()();
  RealColumn get ebKvaInCcu => real()();
  RealColumn get voltage => real()();
  RealColumn get load => real()();

  TextColumn get documentName => text()();
  TextColumn get anyMajorHazardousPunchPoint => text()();
  IntColumn get ebAttachmentFileId => integer()();

  BoolColumn get isActive => boolean()();
  TextColumn get remarks => text()();

  // Sync status
  TextColumn get syncStatus => text().withDefault(const Constant('draft'))();
  TextColumn get lastSyncError => text().nullable()();
  TextColumn get serverUpdatedAt => text().nullable()();

  @override
  Set<Column> get primaryKey => {energyReadingId, siteAuditSchId};
}



// -------------------- DTO for joins --------------------

class FormWithImages {
  final Form form;
  final List<Image> images;
  FormWithImages(this.form, this.images);
}

// -------------------- DAOs --------------------

@DriftAccessor(tables: [Forms])
class FormDao extends DatabaseAccessor<AppDatabase> with _$FormDaoMixin {
  FormDao(AppDatabase db) : super(db);

  Future<void> insertForm(FormsCompanion data) => into(forms).insert(data);
  Future<int> upsertForm(FormsCompanion data) => into(forms).insertOnConflictUpdate(data);
  Future<Form?> getForm(String id) => (select(forms)..where((t) => t.id.equals(id))).getSingleOrNull();
  Future<List<Form>> listForms({String? status}) {
    final q = select(forms)..orderBy([(t) => OrderingTerm.desc(t.createdAt)]);
    if (status != null) q.where((t) => t.status.equals(status));
    return q.get();
  }
  Future<int> updateForm(String id, FormsCompanion data) =>
      (update(forms)..where((t) => t.id.equals(id))).write(data);
  Future<int> deleteForm(String id) =>
      (delete(forms)..where((t) => t.id.equals(id))).go();
}

@DriftAccessor(tables: [Images])
class ImageDao extends DatabaseAccessor<AppDatabase> with _$ImageDaoMixin {
  ImageDao(AppDatabase db) : super(db);

  Future<void> insertImage(ImagesCompanion data) => into(images).insert(data);
  Future<int> upsertImage(ImagesCompanion data) => into(images).insertOnConflictUpdate(data);
  Future<Image?> getImage(String id) => (select(images)..where((t) => t.id.equals(id))).getSingleOrNull();
  Future<List<Image>> listImagesByIds(List<String> ids) =>
      (select(images)..where((t) => t.id.isIn(ids))).get();
  Future<int> updateImage(String id, ImagesCompanion data) =>
      (update(images)..where((t) => t.id.equals(id))).write(data);
  Future<int> deleteImage(String id) =>
      (delete(images)..where((t) => t.id.equals(id))).go();
}

@DriftAccessor(tables: [FormImages, Forms, Images])
class FormImageDao extends DatabaseAccessor<AppDatabase> with _$FormImageDaoMixin {
  FormImageDao(AppDatabase db) : super(db);

  Future<void> link(String formId, String imageId) =>
      into(formImages).insert(
        FormImagesCompanion.insert(formId: formId, imageId: imageId),
        mode: InsertMode.insertOrIgnore,
      );

  Future<int> unlink(String formId, String imageId) =>
      (delete(formImages)..where((t) => t.formId.equals(formId) & t.imageId.equals(imageId))).go();

  Future<List<String>> imageIdsForForm(String formId) async {
    final rows = await (select(formImages)..where((t) => t.formId.equals(formId))).get();
    return rows.map((r) => r.imageId).toList();
  }

  Future<List<Image>> imagesForForm(String formId) async {
    final ids = await imageIdsForForm(formId);
    if (ids.isEmpty) return [];
    return (select(images)..where((t) => t.id.isIn(ids))).get();
  }
}

@DriftAccessor(tables: [AssetAudits])
class AssetAuditDao extends DatabaseAccessor<AppDatabase> with _$AssetAuditDaoMixin {
  AssetAuditDao(AppDatabase db) : super(db);

  Future<void> insertOne(AssetAuditsCompanion data) => into(assetAudits).insert(data);

  Future<int> upsert(AssetAuditsCompanion data) =>
      into(assetAudits).insertOnConflictUpdate(data);

  Future<DbAssetAudit?> getByLocalId(int localAuditLogId) =>
      (select(assetAudits)..where((t) => t.localAuditLogId.equals(localAuditLogId))).getSingleOrNull();

  Future<List<DbAssetAudit>> listByStatus(String status) =>
      (select(assetAudits)..where((t) => t.syncStatus.equals(status)))
          .get();

  Future<int> updateByLocalId(int localAuditLogId, AssetAuditsCompanion patch) =>
      (update(assetAudits)..where((t) => t.localAuditLogId.equals(localAuditLogId))).write(patch);

  Future<int> deleteByLocalId(int localAuditLogId) =>
      (delete(assetAudits)..where((t) => t.localAuditLogId.equals(localAuditLogId))).go();
}

@DriftAccessor(tables: [AuditPhotos])
class AuditPhotoDao extends DatabaseAccessor<AppDatabase> with _$AuditPhotoDaoMixin {
  AuditPhotoDao(AppDatabase db) : super(db);

  Future<void> insertOne(AuditPhotosCompanion data) => into(auditPhotos).insert(data);
  Future<int> upsert(AuditPhotosCompanion data) => into(auditPhotos).insertOnConflictUpdate(data);

  Future<List<DbAuditPhoto>> listByLocalAuditLogId(int localAuditLogId) =>
      (select(auditPhotos)..where((t) => t.localAuditLogId.equals(localAuditLogId))).get();

  Future<DbAuditPhoto?> getById(String id) =>
      (select(auditPhotos)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<int> updateById(String id, AuditPhotosCompanion patch) =>
      (update(auditPhotos)..where((t) => t.id.equals(id))).write(patch);

  Future<int> deleteById(String id) =>
      (delete(auditPhotos)..where((t) => t.id.equals(id))).go();
}

@DriftAccessor(tables: [PmResponses])
class PmResponseDao extends DatabaseAccessor<AppDatabase> with _$PmResponseDaoMixin {
  PmResponseDao(AppDatabase db) : super(db);

  Future<int> upsert(PmResponsesCompanion data) =>
      into(pmResponses).insertOnConflictUpdate(data);

  Future<DbPmResponse?> getOne({required int pmCheckListMstId, required int siteAuditSchId}) =>
      (select(pmResponses)
        ..where((t) => t.pmCheckListMstId.equals(pmCheckListMstId) & t.siteAuditSchId.equals(siteAuditSchId)))
          .getSingleOrNull();

  Future<List<DbPmResponse>> listForAudit(int siteAuditSchId) =>
      (select(pmResponses)..where((t) => t.siteAuditSchId.equals(siteAuditSchId)))
          .get();

  Future<int> patch({required int pmCheckListMstId, required int siteAuditSchId, required PmResponsesCompanion data}) =>
      (update(pmResponses)
        ..where((t) => t.pmCheckListMstId.equals(pmCheckListMstId) & t.siteAuditSchId.equals(siteAuditSchId)))
          .write(data);

  Future<int> deleteForAudit(int siteAuditSchId) =>
      (delete(pmResponses)..where((t) => t.siteAuditSchId.equals(siteAuditSchId))).go();
}

@DriftAccessor(tables: [PmPhotos])
class PmPhotoDao extends DatabaseAccessor<AppDatabase> with _$PmPhotoDaoMixin {
  PmPhotoDao(AppDatabase db) : super(db);

  Future<void> insertOne(PmPhotosCompanion data) => into(pmPhotos).insert(data);
  Future<int> upsert(PmPhotosCompanion data) => into(pmPhotos).insertOnConflictUpdate(data);
  Future<List<DbPmPhoto>> listForAudit(int siteAuditSchId) =>
      (select(pmPhotos)..where((t) => t.localAuditLogId.equals(siteAuditSchId))).get();
  Future<int> updateById(String id, PmPhotosCompanion data) =>
      (update(pmPhotos)..where((t) => t.id.equals(id))).write(data);
  Future<int> deleteById(String id) =>
      (delete(pmPhotos)..where((t) => t.id.equals(id))).go();
}

@DriftAccessor(tables: [EnergyReadings])
class EnergyReadingDao extends DatabaseAccessor<AppDatabase> with _$EnergyReadingDaoMixin {
  EnergyReadingDao(AppDatabase db) : super(db);

  Future<int> upsert(EnergyReadingsCompanion data) =>
      into(energyReadings).insertOnConflictUpdate(data);

  Future<DbEnergyReading?> getOne({required int energyReadingId, required int siteAuditSchId}) =>
      (select(energyReadings)
        ..where((t) => t.energyReadingId.equals(energyReadingId) & t.siteAuditSchId.equals(siteAuditSchId)))
          .getSingleOrNull();

  Future<List<DbEnergyReading>> listForAudit(int siteAuditSchId) =>
      (select(energyReadings)..where((t) => t.siteAuditSchId.equals(siteAuditSchId))).get();

  Future<int> patch({required int energyReadingId, required int siteAuditSchId, required EnergyReadingsCompanion data}) =>
      (update(energyReadings)
        ..where((t) => t.energyReadingId.equals(energyReadingId) & t.siteAuditSchId.equals(siteAuditSchId)))
          .write(data);

  Future<int> deleteForAudit(int siteAuditSchId) =>
      (delete(energyReadings)..where((t) => t.siteAuditSchId.equals(siteAuditSchId))).go();
}

// -------------------- Database --------------------

@DriftDatabase(
  tables: [Forms, Images, FormImages, AssetAudits, AuditPhotos, PmResponses, PmPhotos, EnergyReadings],
  daos: [FormDao, ImageDao, FormImageDao, AssetAuditDao, AuditPhotoDao,PmResponseDao, PmPhotoDao, EnergyReadingDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_open());

  @override
  int get schemaVersion => 5; // bump if you had 1 before

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from == 1) {
        await m.createTable(assetAudits);
        await m.createTable(auditPhotos);
        await m.createTable(pmResponses);
        await m.createTable(pmPhotos);
        await m.createTable(energyReadings);
      }
    },
  );
}


QueryExecutor _open() => driftDatabase(
  name: 'app_data.db',
  native: DriftNativeOptions(databaseDirectory: _dbFolder),
);

Future<Directory> _dbFolder() async {
  final dir = await getApplicationSupportDirectory();
  return Directory(p.join(dir.path, 'db'));
}
