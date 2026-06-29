import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

class Children extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get color => text()();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
}

class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get emoji => text()();
  IntColumn get sortOrder => integer()();
}

class ChoreTemplates extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get categoryId => integer().references(Categories, #id)();
  TextColumn get name => text()();
  IntColumn get points => integer()();
  BoolColumn get isActive =>
      boolean().withDefault(const Constant(true))();
  IntColumn get sortOrder => integer()();
}

class ActivityLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get childId => integer().references(Children, #id)();
  TextColumn get choreName => text()();
  IntColumn get points => integer()();
  DateTimeColumn get recordedAt =>
      dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();
}

@DriftDatabase(tables: [Children, Categories, ChoreTemplates, ActivityLogs])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 1;
}

AppDatabase openAppDatabase() => AppDatabase(_openConnection());

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'ouchi_master.db'));
    return NativeDatabase.createInBackground(file);
  });
}
