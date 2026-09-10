// lib/utils/database_helper.dart
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
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
      version: 1,
      onCreate: _onCreate,
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
}