// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'activity_dao.dart';

// ignore_for_file: type=lint
mixin _$ActivityDaoMixin on DatabaseAccessor<AppDatabase> {
  $ActivityLogTable get activityLog => attachedDatabase.activityLog;
  ActivityDaoManager get managers => ActivityDaoManager(this);
}

class ActivityDaoManager {
  final _$ActivityDaoMixin _db;
  ActivityDaoManager(this._db);
  $$ActivityLogTableTableManager get activityLog =>
      $$ActivityLogTableTableManager(_db.attachedDatabase, _db.activityLog);
}
