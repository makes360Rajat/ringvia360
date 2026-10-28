import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import '../models/sales_track_models.dart';

class LocalDatabaseService {
  static final LocalDatabaseService instance = LocalDatabaseService._internal();
  LocalDatabaseService._internal();

  Database? _db;

  Future<Database?> get database async {
    try {
      if (_db != null && _db!.isOpen) return _db!;
      _db = await _initDb();
      return _db;
    } catch (_) {
      return null;
    }
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'sales_track_local.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE events (
            uid TEXT PRIMARY KEY,
            kind TEXT NOT NULL,
            time INTEGER NOT NULL,
            direction TEXT NOT NULL,
            number TEXT NOT NULL,
            name TEXT NOT NULL,
            sim INTEGER NOT NULL DEFAULT 1,
            duration INTEGER NOT NULL DEFAULT 0,
            recording INTEGER NOT NULL DEFAULT 0,
            media TEXT,
            app TEXT,
            text TEXT,
            source TEXT NOT NULL DEFAULT 'auto',
            recording_path TEXT,
            sync_status TEXT NOT NULL DEFAULT 'pending',
            recording_sync_status TEXT NOT NULL DEFAULT 'none',
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL
          )
        ''');

        await db.execute('CREATE INDEX idx_events_kind ON events (kind)');
        await db.execute('CREATE INDEX idx_events_sync_status ON events (sync_status)');
        await db.execute('CREATE INDEX idx_events_time ON events (time DESC)');
        await db.execute('CREATE INDEX idx_events_rec_sync ON events (recording_sync_status)');

        await db.execute('''
          CREATE TABLE outcomes (
            uid TEXT PRIMARY KEY,
            outcome TEXT NOT NULL,
            note TEXT,
            follow_up_at INTEGER,
            lead_status INTEGER,
            create_lead TEXT,
            sync_status TEXT NOT NULL DEFAULT 'pending',
            created_at INTEGER NOT NULL
          )
        ''');
      },
    );
  }

  /// Bulk upsert events while preserving already-synced status if new event is pending
  Future<void> saveEvents(List<SalesTrackEvent> events) async {
    if (events.isEmpty) return;
    final db = await database;
    if (db == null) return;
    final now = DateTime.now().millisecondsSinceEpoch;

    const chunkSize = 200;
    for (int i = 0; i < events.length; i += chunkSize) {
      final end = (i + chunkSize < events.length) ? i + chunkSize : events.length;
      final chunk = events.sublist(i, end);

      await db.transaction((txn) async {
        final batch = txn.batch();

        for (final ev in chunk) {
          final recSync = (ev.recordingPath != null && ev.recordingPath!.isNotEmpty)
              ? (ev.syncStatus == 'synced' ? 'synced' : 'pending')
              : 'none';

          batch.rawInsert('''
            INSERT INTO events (
              uid, kind, time, direction, number, name, sim, duration, recording,
              media, app, text, source, recording_path, sync_status, recording_sync_status,
              created_at, updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(uid) DO UPDATE SET
              name = excluded.name,
              duration = CASE WHEN excluded.duration > 0 THEN excluded.duration ELSE duration END,
              recording = CASE WHEN excluded.recording = 1 THEN 1 ELSE recording END,
              recording_path = COALESCE(excluded.recording_path, recording_path),
              sync_status = CASE WHEN sync_status = 'synced' THEN 'synced' ELSE excluded.sync_status END,
              recording_sync_status = CASE 
                WHEN recording_sync_status = 'synced' THEN 'synced'
                WHEN excluded.recording_path IS NOT NULL AND excluded.recording_path != '' AND recording_sync_status = 'none' THEN 'pending'
                ELSE recording_sync_status
              END,
              updated_at = ?
          ''', [
            ev.uid,
            ev.kind,
            ev.time,
            ev.direction,
            ev.number,
            ev.name,
            ev.sim,
            ev.duration,
            ev.recording ? 1 : 0,
            ev.media,
            ev.app,
            ev.text,
            ev.source,
            ev.recordingPath,
            ev.syncStatus,
            recSync,
            now,
            now,
            now,
          ]);
        }

        await batch.commit(noResult: true);
      });

      if (events.length > chunkSize) {
        await Future.delayed(Duration.zero);
      }
    }
  }

  /// Retrieve stored events by kind
  Future<List<SalesTrackEvent>> getEvents({
    String? kind,
    String? syncStatus,
    int limit = 50000,
    int offset = 0,
  }) async {
    final db = await database;
    if (db == null) return [];
    final whereClauses = <String>[];
    final whereArgs = <dynamic>[];

    if (kind != null && kind.isNotEmpty) {
      if (kind == 'whatsapp') {
        whereClauses.add("kind IN ('whatsapp_call', 'whatsapp_message')");
      } else if (kind == 'sms') {
        whereClauses.add("kind IN ('sms', 'notification')");
      } else {
        whereClauses.add('kind = ?');
        whereArgs.add(kind);
      }
    }
    if (syncStatus != null && syncStatus.isNotEmpty) {
      whereClauses.add('sync_status = ?');
      whereArgs.add(syncStatus);
    }

    final where = whereClauses.isNotEmpty ? whereClauses.join(' AND ') : null;

    final rows = await db.query(
      'events',
      where: where,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'time DESC',
      limit: limit,
      offset: offset,
    );

    return rows.map(_rowToEvent).toList();
  }

  /// Retrieve all pending events for server sync
  Future<List<SalesTrackEvent>> getPendingEvents({String? kind, int limit = 500}) async {
    final db = await database;
    if (db == null) return [];
    String query = "SELECT * FROM events WHERE sync_status != 'synced'";
    final args = <dynamic>[];

    if (kind != null && kind.isNotEmpty) {
      if (kind == 'sms') {
        query += " AND kind IN ('sms', 'notification')";
      } else if (kind == 'whatsapp') {
        query += " AND kind IN ('whatsapp_call', 'whatsapp_message')";
      } else {
        query += " AND kind = ?";
        args.add(kind);
      }
    }
    query += " ORDER BY time DESC LIMIT ?";
    args.add(limit);

    final rows = await db.rawQuery(query, args);
    return rows.map(_rowToEvent).toList();
  }

  /// Retrieve calls with recordings that need upload
  Future<List<SalesTrackEvent>> getPendingRecordings({int limit = 50, bool includeFailed = false}) async {
    final db = await database;
    if (db == null) return [];
    final statusClause = includeFailed 
        ? "recording_sync_status IN ('pending', 'failed')"
        : "recording_sync_status = 'pending'";
    final rows = await db.rawQuery('''
      SELECT * FROM events 
      WHERE kind = 'call' 
        AND recording_path IS NOT NULL 
        AND recording_path != '' 
        AND $statusClause
      ORDER BY time DESC 
      LIMIT ?
    ''', [limit]);

    return rows.map(_rowToEvent).toList();
  }

  /// Mark events as synced in SQLite
  Future<void> markEventsSynced(List<String> uids) async {
    if (uids.isEmpty) return;
    final db = await database;
    if (db == null) return;
    final now = DateTime.now().millisecondsSinceEpoch;

    await db.transaction((txn) async {
      for (final chunk in _chunks(uids, 100)) {
        final placeholders = List.filled(chunk.length, '?').join(',');
        await txn.rawUpdate('''
          UPDATE events 
          SET sync_status = 'synced', updated_at = ?
          WHERE uid IN ($placeholders)
        ''', [now, ...chunk]);
      }
    });
  }

  /// Mark recording as synced
  Future<void> markRecordingSynced(String uid) async {
    final db = await database;
    if (db == null) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.update(
      'events',
      {
        'recording_sync_status': 'synced',
        'updated_at': now,
      },
      where: 'uid = ?',
      whereArgs: [uid],
    );
  }

  /// Mark recording as failed
  Future<void> markRecordingFailed(String uid) async {
    final db = await database;
    if (db == null) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.update(
      'events',
      {
        'recording_sync_status': 'failed',
        'updated_at': now,
      },
      where: 'uid = ?',
      whereArgs: [uid],
    );
  }

  /// Reset all historical items to 'pending' to allow re-syncing / full upload
  Future<void> resetAllToPending({String? kind}) async {
    final db = await database;
    if (db == null) return;
    final now = DateTime.now().millisecondsSinceEpoch;

    if (kind != null && kind.isNotEmpty) {
      final kindClause = (kind == 'sms')
          ? "kind IN ('sms', 'notification')"
          : (kind == 'whatsapp')
              ? "kind IN ('whatsapp_call', 'whatsapp_message')"
              : "kind = '$kind'";
      await db.rawUpdate('''
        UPDATE events 
        SET sync_status = 'pending',
            recording_sync_status = CASE WHEN recording_path IS NOT NULL AND recording_path != '' THEN 'pending' ELSE recording_sync_status END,
            updated_at = ?
        WHERE $kindClause
      ''', [now]);
    } else {
      await db.rawUpdate('''
        UPDATE events 
        SET sync_status = 'pending',
            recording_sync_status = CASE WHEN recording_path IS NOT NULL AND recording_path != '' THEN 'pending' ELSE recording_sync_status END,
            updated_at = ?
      ''', [now]);
    }
  }

  /// Return counts for dashboard and pending tab
  Future<Map<String, int>> getPendingCounts() async {
    final db = await database;
    if (db == null) {
      return {
        'pendingTotal': 0,
        'pendingCalls': 0,
        'pendingWhatsApp': 0,
        'pendingSms': 0,
        'pendingRecordings': 0,
        'totalCalls': 0,
        'syncedCalls': 0,
      };
    }

    final pendingTotal = Sqflite.firstIntValue(await db.rawQuery(
      "SELECT COUNT(*) FROM events WHERE sync_status != 'synced'",
    )) ?? 0;

    final pendingCalls = Sqflite.firstIntValue(await db.rawQuery(
      "SELECT COUNT(*) FROM events WHERE kind = 'call' AND sync_status != 'synced'",
    )) ?? 0;

    final pendingWhatsApp = Sqflite.firstIntValue(await db.rawQuery(
      "SELECT COUNT(*) FROM events WHERE kind IN ('whatsapp_call', 'whatsapp_message') AND sync_status != 'synced'",
    )) ?? 0;

    final pendingSms = Sqflite.firstIntValue(await db.rawQuery(
      "SELECT COUNT(*) FROM events WHERE kind IN ('sms', 'notification') AND sync_status != 'synced'",
    )) ?? 0;

    final pendingRecs = Sqflite.firstIntValue(await db.rawQuery(
      "SELECT COUNT(*) FROM events WHERE kind = 'call' AND recording_path IS NOT NULL AND recording_path != '' AND recording_sync_status != 'synced'",
    )) ?? 0;

    final totalCalls = Sqflite.firstIntValue(await db.rawQuery(
      "SELECT COUNT(*) FROM events WHERE kind = 'call'",
    )) ?? 0;

    final syncedCalls = Sqflite.firstIntValue(await db.rawQuery(
      "SELECT COUNT(*) FROM events WHERE kind = 'call' AND sync_status = 'synced'",
    )) ?? 0;

    return {
      'pendingTotal': pendingTotal,
      'pendingCalls': pendingCalls,
      'pendingWhatsApp': pendingWhatsApp,
      'pendingSms': pendingSms,
      'pendingRecordings': pendingRecs,
      'totalCalls': totalCalls,
      'syncedCalls': syncedCalls,
    };
  }

  /// Clean up duplicate records stored in SQLite so local counts strictly match in-memory lists
  Future<int> cleanupDuplicates() async {
    final db = await database;
    if (db == null) return 0;
    int removed = 0;
    try {
      // 1. Remove duplicate calls where another record exists with same direction, number, and time within 120s
      final duplicateCalls = await db.rawQuery('''
        SELECT e2.uid as remove_uid, e1.uid as keep_uid, e2.duration as dur2, e1.duration as dur1,
               e2.sync_status as sync2, e1.sync_status as sync1,
               e2.recording_path as rec2, e1.recording_path as rec1
        FROM events e1
        INNER JOIN events e2 ON e1.kind = e2.kind
          AND e1.direction = e2.direction
          AND (
            e1.number = e2.number
            OR (
              LENGTH(e1.number) >= 10 AND LENGTH(e2.number) >= 10
              AND SUBSTR(REPLACE(REPLACE(REPLACE(REPLACE(e1.number, '+', ''), '-', ''), ' ', ''), '(', ''), -10) =
                  SUBSTR(REPLACE(REPLACE(REPLACE(REPLACE(e2.number, '+', ''), '-', ''), ' ', ''), '(', ''), -10)
            )
          )
          AND e1.uid != e2.uid
          AND e1.rowid < e2.rowid
          AND ABS(e1.time - e2.time) <= 120000
        WHERE e1.kind IN ('call', 'whatsapp_call') AND e1.number != ''
      ''');

      for (final d in duplicateCalls) {
        var removeUid = d['remove_uid'] as String?;
        var keepUid = d['keep_uid'] as String?;
        if (removeUid != null && keepUid != null) {
          final dur2 = (d['dur2'] as int?) ?? 0;
          final dur1 = (d['dur1'] as int?) ?? 0;
          final sync2 = d['sync2'] as String?;
          final rec2 = d['rec2'] as String?;
          final rec1 = d['rec1'] as String?;

          final updates = <String, dynamic>{};
          if (dur2 > dur1) updates['duration'] = dur2;
          if (sync2 == 'synced') updates['sync_status'] = 'synced';
          if ((rec1 == null || rec1.isEmpty) && rec2 != null && rec2.isNotEmpty) {
            updates['recording_path'] = rec2;
            updates['recording'] = 1;
          }

          // Delete duplicate record first to maintain database integrity
          await db.delete('events', where: 'uid = ?', whereArgs: [removeUid]);

          if (updates.isNotEmpty) {
            await db.update('events', updates, where: 'uid = ?', whereArgs: [keepUid]);
          }
          removed++;
        }
      }

      // 2. Remove duplicate SMS & messages where another record exists with same kind, direction, number, and time within 60s
      final duplicateSms = await db.rawQuery('''
        SELECT e2.uid as remove_uid, e1.uid as keep_uid, e2.sync_status as sync2, e2.text as text2, e1.text as text1
        FROM events e1
        INNER JOIN events e2 ON e1.kind = e2.kind
          AND e1.direction = e2.direction
          AND (
            e1.number = e2.number
            OR (
              LENGTH(e1.number) >= 10 AND LENGTH(e2.number) >= 10
              AND SUBSTR(REPLACE(REPLACE(REPLACE(REPLACE(e1.number, '+', ''), '-', ''), ' ', ''), '(', ''), -10) =
                  SUBSTR(REPLACE(REPLACE(REPLACE(REPLACE(e2.number, '+', ''), '-', ''), ' ', ''), '(', ''), -10)
            )
          )
          AND (e1.text IS NULL OR e2.text IS NULL OR e1.text = '' OR e2.text = '' OR e1.text = e2.text)
          AND e1.uid != e2.uid
          AND e1.rowid < e2.rowid
          AND ABS(e1.time - e2.time) <= 60000
        WHERE e1.kind IN ('sms', 'whatsapp_message', 'notification') AND e1.number != ''
      ''');

      for (final d in duplicateSms) {
        var removeUid = d['remove_uid'] as String?;
        var keepUid = d['keep_uid'] as String?;
        if (removeUid != null && keepUid != null) {
          final sync2 = d['sync2'] as String?;
          final text2 = d['text2'] as String?;
          final text1 = d['text1'] as String?;

          final updates = <String, dynamic>{};
          if (sync2 == 'synced') updates['sync_status'] = 'synced';
          if ((text1 == null || text1.isEmpty) && text2 != null && text2.isNotEmpty) {
            updates['text'] = text2;
          }

          await db.delete('events', where: 'uid = ?', whereArgs: [removeUid]);

          if (updates.isNotEmpty) {
            await db.update('events', updates, where: 'uid = ?', whereArgs: [keepUid]);
          }
          removed++;
        }
      }
    } catch (_) {}
    return removed;
  }

  /// Everything kept for a CRM this phone is no longer paired with.
  Future<void> clearAll() async {
    final db = await database;
    if (db == null) return;
    try {
      final tables = await db.rawQuery("SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%' AND name <> 'android_metadata'");
      for (final t in tables) {
        await db.delete(t['name'] as String);
      }
    } catch (_) {}
  }

  /// Offline outcome queue
  Future<void> saveOutcome(OutcomeSubmission submission) async {
    final db = await database;
    if (db == null) return;
    await db.insert(
      'outcomes',
      {
        'uid': submission.uid,
        'outcome': submission.outcome,
        'note': submission.note,
        'follow_up_at': submission.followUpAt,
        'lead_status': submission.leadStatus,
        'create_lead': submission.createLead != null ? jsonEncode(submission.createLead) : null,
        'sync_status': 'pending',
        'created_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<OutcomeSubmission>> getPendingOutcomes() async {
    final db = await database;
    if (db == null) return [];
    final rows = await db.query(
      'outcomes',
      where: "sync_status != 'synced'",
      orderBy: 'created_at ASC',
      limit: 50,
    );

    return rows.map((r) {
      Map<String, dynamic>? createLead;
      if (r['create_lead'] != null) {
        try {
          createLead = jsonDecode(r['create_lead'] as String);
        } catch (_) {}
      }
      return OutcomeSubmission(
        uid: r['uid'] as String,
        outcome: r['outcome'] as String,
        note: r['note'] as String?,
        followUpAt: (r['follow_up_at'] as num?)?.toInt(),
        leadStatus: (r['lead_status'] as num?)?.toInt(),
        createLead: createLead,
      );
    }).toList();
  }

  Future<void> markOutcomesSynced(List<String> uids) async {
    if (uids.isEmpty) return;
    final db = await database;
    if (db == null) return;
    final placeholders = List.filled(uids.length, '?').join(',');
    await db.rawUpdate('''
      UPDATE outcomes SET sync_status = 'synced' WHERE uid IN ($placeholders)
    ''', uids);
  }

  SalesTrackEvent _rowToEvent(Map<String, dynamic> r) {
    return SalesTrackEvent(
      uid: r['uid'] as String,
      kind: r['kind'] as String,
      time: (r['time'] as num).toInt(),
      direction: r['direction'] as String,
      number: r['number'] as String,
      name: r['name'] as String,
      sim: (r['sim'] as num?)?.toInt() ?? 1,
      duration: (r['duration'] as num?)?.toInt() ?? 0,
      recording: (r['recording'] as num?)?.toInt() == 1,
      media: r['media'] as String?,
      app: r['app'] as String?,
      text: r['text'] as String?,
      source: r['source'] as String? ?? 'auto',
      recordingPath: r['recording_path'] as String?,
      syncStatus: r['sync_status'] as String? ?? 'pending',
    );
  }

  List<List<T>> _chunks<T>(List<T> list, int size) {
    final chunks = <List<T>>[];
    for (var i = 0; i < list.length; i += size) {
      chunks.add(list.sublist(i, i + size > list.length ? list.length : i + size));
    }
    return chunks;
  }
}
