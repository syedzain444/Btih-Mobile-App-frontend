// lib/utils/database_helper.dart
import 'dart:convert';

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/app_notification.dart';
import '../models/local_appointment.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'appointments.db');
    return await openDatabase(
      path,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE appointments(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        appointmentId TEXT,
        name TEXT,
        phoneNo TEXT,
        mrNo TEXT,
        email TEXT,
        weekId INTEGER,
        appointmentTime TEXT,
        status TEXT,
        doctorName TEXT,
        purpose TEXT,
        createdAt TEXT,
        doctorId INTEGER,
        departmentId INTEGER,
        isGuestAppointment INTEGER
      )
    ''');
    await _createNotificationsTable(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createNotificationsTable(db);
    }
  }

  Future<void> _createNotificationsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS notifications(
        id TEXT PRIMARY KEY,
        mrNo TEXT NOT NULL,
        type TEXT NOT NULL,
        category TEXT NOT NULL,
        priority TEXT NOT NULL,
        title TEXT NOT NULL,
        body TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        isRead INTEGER NOT NULL DEFAULT 0,
        payloadJson TEXT
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_notifications_mr ON notifications(mrNo, createdAt DESC)',
    );
  }

  // Insert appointment
  Future<int> insertAppointment(LocalAppointment appointment) async {
    Database db = await database;
    return await db.insert('appointments', appointment.toMap());
  }

  // Get all guest appointments
  Future<List<LocalAppointment>> getGuestAppointments() async {
    Database db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'appointments',
      where: 'isGuestAppointment = ?',
      whereArgs: [1],
      orderBy: 'createdAt DESC',
    );
    return List.generate(maps.length, (i) => LocalAppointment.fromMap(maps[i]));
  }

  Future<int> updateAppointmentStatus({
    required String appointmentId,
    required String status,
    String? purposeAppend,
  }) async {
    Database db = await database;
    final rows = await db.query(
      'appointments',
      where: 'appointmentId = ?',
      whereArgs: [appointmentId],
      limit: 1,
    );
    if (rows.isEmpty) return 0;

    final existingPurpose = rows.first['purpose']?.toString() ?? '';
    final updatedPurpose = purposeAppend == null || purposeAppend.isEmpty
        ? existingPurpose
        : existingPurpose.isEmpty
            ? purposeAppend
            : '$existingPurpose | $purposeAppend';

    return db.update(
      'appointments',
      {
        'status': status,
        'purpose': updatedPurpose,
      },
      where: 'appointmentId = ?',
      whereArgs: [appointmentId],
    );
  }

  // Delete appointment
  Future<int> deleteAppointment(int id) async {
    Database db = await database;
    return await db.delete(
      'appointments',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Delete all guest appointments (for logout)
  Future<int> deleteAllGuestAppointments() async {
    Database db = await database;
    return await db.delete(
      'appointments',
      where: 'isGuestAppointment = ?',
      whereArgs: [1],
    );
  }

  // Check if appointment already exists
  Future<bool> isAppointmentExists(String appointmentId) async {
    Database db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'appointments',
      where: 'appointmentId = ?',
      whereArgs: [appointmentId],
    );
    return maps.isNotEmpty;
  }

  // ── Notification history (permanent on-device SQLite) ──────────────────

  Future<void> replaceNotificationsForMr({
    required String mrNo,
    required List<AppNotification> notifications,
  }) async {
    final db = await database;
    final batch = db.batch();
    batch.delete('notifications', where: 'mrNo = ?', whereArgs: [mrNo]);
    for (final item in notifications) {
      batch.insert(
        'notifications',
        _notificationToMap(mrNo, item),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> upsertNotification({
    required String mrNo,
    required AppNotification notification,
  }) async {
    final db = await database;
    await db.insert(
      'notifications',
      _notificationToMap(mrNo, notification),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<AppNotification>> getNotificationsForMr(
    String mrNo, {
    int limit = 100,
  }) async {
    final db = await database;
    final rows = await db.query(
      'notifications',
      where: 'mrNo = ?',
      whereArgs: [mrNo],
      orderBy: 'createdAt DESC',
      limit: limit,
    );
    return rows.map(_notificationFromMap).toList();
  }

  Future<void> markNotificationRead({
    required String mrNo,
    required String id,
  }) async {
    final db = await database;
    await db.update(
      'notifications',
      {'isRead': 1},
      where: 'mrNo = ? AND id = ?',
      whereArgs: [mrNo, id],
    );
  }

  Future<void> markAllNotificationsRead(String mrNo) async {
    final db = await database;
    await db.update(
      'notifications',
      {'isRead': 1},
      where: 'mrNo = ?',
      whereArgs: [mrNo],
    );
  }

  Map<String, Object?> _notificationToMap(String mrNo, AppNotification item) {
    return {
      'id': item.id,
      'mrNo': mrNo,
      'type': item.type.name,
      'category': item.category.name,
      'priority': item.priority.name,
      'title': item.title,
      'body': item.body,
      'createdAt': item.createdAt.toIso8601String(),
      'isRead': item.isRead ? 1 : 0,
      'payloadJson':
          item.payload == null ? null : jsonEncode(item.payload),
    };
  }

  AppNotification _notificationFromMap(Map<String, Object?> row) {
    Map<String, dynamic>? payload;
    final rawPayload = row['payloadJson']?.toString();
    if (rawPayload != null && rawPayload.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawPayload);
        if (decoded is Map) {
          payload = Map<String, dynamic>.from(decoded);
        }
      } catch (_) {}
    }

    NotificationType type;
    try {
      type = NotificationType.values.byName(row['type']?.toString() ?? '');
    } catch (_) {
      type = NotificationType.hospitalAnnouncement;
    }

    NotificationCategory category;
    try {
      category =
          NotificationCategory.values.byName(row['category']?.toString() ?? '');
    } catch (_) {
      category = NotificationCategory.general;
    }

    NotificationPriority priority;
    try {
      priority =
          NotificationPriority.values.byName(row['priority']?.toString() ?? '');
    } catch (_) {
      priority = NotificationPriority.normal;
    }

    return AppNotification(
      id: row['id']?.toString() ?? '',
      type: type,
      category: category,
      priority: priority,
      title: row['title']?.toString() ?? 'Notification',
      body: row['body']?.toString() ?? '',
      createdAt: DateTime.tryParse(row['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      isRead: (row['isRead'] as int? ?? 0) == 1,
      payload: payload,
    );
  }
}
