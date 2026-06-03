// lib/data/services/export_service.dart — Hardcore fix: no MoodLog type

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../database/app_database.dart';
import '../database/daos/mood_dao.dart';
import '../repositories/diary_repository.dart';
import '../../core/encryption/encryption_service.dart';

class ExportService {
  const ExportService({
    required AppDatabase db,
    required DiaryRepository diaryRepository,
  })  : _db = db,
        _diaryRepo = diaryRepository;

  final AppDatabase _db;
  final DiaryRepository _diaryRepo;

  // ── Encrypted Export ──────────────────────────────────────────────────────

  Future<void> exportEncrypted() async {
    try {
      final json    = await _buildJsonPayload();
      final jsonStr = jsonEncode(json);
      final payload = EncryptionService().encrypt(jsonStr);

      // Pack: [16 bytes IV][N bytes ciphertext]
      final bytes = Uint8List(16 + payload.ciphertext.length);
      bytes.setRange(0, 16, payload.iv);
      bytes.setRange(16, bytes.length, payload.ciphertext);

      final file = await _writeToTemp(bytes, _encFilename());
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/octet-stream')],
        subject: 'ASRIO Encrypted Backup',
      );
    } catch (e) {
      debugPrint('[ExportService] Encrypted export failed: $e');
      rethrow;
    }
  }

  // ── Plaintext Export ──────────────────────────────────────────────────────

  Future<void> exportPlaintext() async {
    try {
      final json    = await _buildJsonPayload();
      final jsonStr = const JsonEncoder.withIndent('  ').convert(json);
      final bytes   = Uint8List.fromList(utf8.encode(jsonStr));

      final file = await _writeToTemp(bytes, _jsonFilename());
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/json')],
        subject: 'ASRIO Backup',
      );
    } catch (e) {
      debugPrint('[ExportService] Plaintext export failed: $e');
      rethrow;
    }
  }

  // ── Data Collection ───────────────────────────────────────────────────────

  Future<Map<String, dynamic>> _buildJsonPayload() async {
    // ── Tasks ────────────────────────────────────────────────────────────────
    final tasks = await _db.tasksDao.watchAllTasks().first;
    final tasksJson = tasks.map((t) => {
          'id':          t.id,
          'title':       t.title,
          'description': t.description,
          'type':        t.type,
          'priority':    t.priority,
          'isCompleted': t.isCompleted,
          'createdAt':   t.createdAt.toIso8601String(),
          'dueDate':     t.dueDate?.toIso8601String(),
          'sortOrder':   t.sortOrder,
        }).toList();

    // ── Diary (decrypted) ─────────────────────────────────────────────────────
    final diaryDates = await _db.diaryDao.getActiveDiaryDates();
    final diaryJson  = <Map<String, dynamic>>[];
    for (final date in diaryDates) {
      final pages = await _diaryRepo.getPagesForDate(date);
      for (final page in pages) {
        diaryJson.add({
          'id':         page.id,
          'entryDate':  page.entryDate.toIso8601String(),
          'pageNumber': page.pageNumber,
          'content':    page.content,
          'updatedAt':  page.updatedAt.toIso8601String(),
        });
      }
    }

    // ── Habits ───────────────────────────────────────────────────────────────
    final habits = await _db.habitsDao.watchAllHabits().first;
    final habitsJson = habits.map((h) => {
          'id':          h.id,
          'title':       h.title,
          'description': h.description,
          'iconName':    h.iconName,
          'category':    h.category,
          'isArchived':  h.isArchived,
          'createdAt':   h.createdAt.toIso8601String(),
        }).toList();

    // ── Mood Logs (raw SQL — no MoodLog type) ─────────────────────────────────
    final moodRows = await _db.moodDao
        .watchMoodHistory(days: 3650)
        .first;
    final moodJson = moodRows.map((r) => {
          'id':       r.idField,
          'position': r.moodValueField,
          'loggedAt': r.loggedAtField.toIso8601String(),
        }).toList();

    return {
      'exportedAt': DateTime.now().toIso8601String(),
      'version':    4,
      'tasks':      tasksJson,
      'diary':      diaryJson,
      'habits':     habitsJson,
      'moodLogs':   moodJson,
    };
  }

  // ── File Helpers ──────────────────────────────────────────────────────────

  Future<File> _writeToTemp(Uint8List bytes, String filename) async {
    final dir  = await getTemporaryDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  String _encFilename() =>
      'asrio_backup_${DateFormat('yyyyMMdd').format(DateTime.now())}.enc';

  String _jsonFilename() =>
      'asrio_backup_${DateFormat('yyyyMMdd').format(DateTime.now())}.json';
}
