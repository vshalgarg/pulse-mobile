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

// -------------------- Database --------------------

@DriftDatabase(tables: [Forms, Images, FormImages], daos: [FormDao, ImageDao, FormImageDao])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_open());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {},
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
