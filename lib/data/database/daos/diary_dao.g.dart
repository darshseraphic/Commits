// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'diary_dao.dart';

// ignore_for_file: type=lint
mixin _$DiaryDaoMixin on DatabaseAccessor<AppDatabase> {
  $DiaryPagesTable get diaryPages => attachedDatabase.diaryPages;
  DiaryDaoManager get managers => DiaryDaoManager(this);
}

class DiaryDaoManager {
  final _$DiaryDaoMixin _db;
  DiaryDaoManager(this._db);
  $$DiaryPagesTableTableManager get diaryPages =>
      $$DiaryPagesTableTableManager(_db.attachedDatabase, _db.diaryPages);
}
