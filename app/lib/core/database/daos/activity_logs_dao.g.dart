// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'activity_logs_dao.dart';

// ignore_for_file: type=lint
mixin _$ActivityLogsDaoMixin on DatabaseAccessor<AppDatabase> {
  $ChildrenTable get children => attachedDatabase.children;
  $ActivityLogsTable get activityLogs => attachedDatabase.activityLogs;
  ActivityLogsDaoManager get managers => ActivityLogsDaoManager(this);
}

class ActivityLogsDaoManager {
  final _$ActivityLogsDaoMixin _db;
  ActivityLogsDaoManager(this._db);
  $$ChildrenTableTableManager get children =>
      $$ChildrenTableTableManager(_db.attachedDatabase, _db.children);
  $$ActivityLogsTableTableManager get activityLogs =>
      $$ActivityLogsTableTableManager(_db.attachedDatabase, _db.activityLogs);
}
