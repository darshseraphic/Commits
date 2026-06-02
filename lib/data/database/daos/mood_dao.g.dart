// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mood_dao.dart';

// ignore_for_file: type=lint
mixin _$MoodDaoMixin on DatabaseAccessor<AppDatabase> {
  $MoodLogsTable get moodLogs => attachedDatabase.moodLogs;
  MoodDaoManager get managers => MoodDaoManager(this);
}

class MoodDaoManager {
  final _$MoodDaoMixin _db;
  MoodDaoManager(this._db);
  $$MoodLogsTableTableManager get moodLogs =>
      $$MoodLogsTableTableManager(_db.attachedDatabase, _db.moodLogs);
}
