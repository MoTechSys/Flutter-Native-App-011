// ============================================================
// CarCare - خدمة قاعدة البيانات المحلية (SQLite)
// تنفّذ عمليات CRUD الأربع: إضافة، جلب، تعديل، حذف
// ============================================================

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import '../models/models.dart';
import 'password_hasher.dart';

class StorageService extends ChangeNotifier {
  static final StorageService instance = StorageService._();
  StorageService._();

  late Database _db;

  // ذاكرة مؤقتة للقراءة السريعة في الواجهات (تُحدَّث من قاعدة البيانات)
  Car _car = Car(name: 'سيارتي', odometer: 0);
  List<MaintenanceRecord> _maintenance = [];
  List<FuelRecord> _fuel = [];
  List<RepairRecord> _repairs = [];

  Future<void> init() async {
    // على الويب (للمعاينة فقط) نستخدم نسخة الويب من SQLite؛ على أندرويد الأصلية
    if (kIsWeb) databaseFactory = databaseFactoryFfiWeb;
    final path = '${await getDatabasesPath()}/carcare.db';
    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, v) async {
        await db.execute('''
          CREATE TABLE users(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            email TEXT NOT NULL UNIQUE,
            password TEXT NOT NULL
          )''');
        await db.execute('''
          CREATE TABLE car(
            id INTEGER PRIMARY KEY,
            name TEXT NOT NULL,
            odometer INTEGER NOT NULL
          )''');
        await db.execute('''
          CREATE TABLE maintenance(
            id TEXT PRIMARY KEY,
            type INTEGER NOT NULL,
            date TEXT NOT NULL,
            odometer INTEGER NOT NULL,
            intervalKm INTEGER NOT NULL,
            intervalDays INTEGER NOT NULL,
            cost REAL NOT NULL,
            notes TEXT
          )''');
        await db.execute('''
          CREATE TABLE fuel(
            id TEXT PRIMARY KEY,
            date TEXT NOT NULL,
            odometer INTEGER NOT NULL,
            liters REAL NOT NULL,
            totalPrice REAL NOT NULL
          )''');
        await db.execute('''
          CREATE TABLE repairs(
            id TEXT PRIMARY KEY,
            date TEXT NOT NULL,
            odometer INTEGER NOT NULL,
            title TEXT NOT NULL,
            workshop TEXT,
            cost REAL NOT NULL,
            notes TEXT
          )''');
      },
    );
    await _reload();
  }

  /// إعادة تحميل كل البيانات من قاعدة البيانات (Read)
  Future<void> _reload() async {
    final carRows = await _db.query('car', limit: 1);
    _car = carRows.isEmpty
        ? Car(name: 'سيارتي', odometer: 0)
        : Car.fromMap(carRows.first);

    _maintenance =
        (await _db.query(
            'maintenance',
          )).map((e) => MaintenanceRecord.fromMap(e)).toList()
          ..sort((a, b) => b.date.compareTo(a.date));

    _fuel = (await _db.query('fuel')).map((e) => FuelRecord.fromMap(e)).toList()
      ..sort((a, b) => b.odometer.compareTo(a.odometer));

    _repairs =
        (await _db.query(
            'repairs',
          )).map((e) => RepairRecord.fromMap(e)).toList()
          ..sort((a, b) => b.date.compareTo(a.date));

    notifyListeners();
  }

  String _newId() => DateTime.now().microsecondsSinceEpoch.toString();

  // ================= المستخدمون (Auth) =================
  Future<String?> register(String name, String email, String password) async {
    final exists = await _db.query(
      'users',
      where: 'email = ?',
      whereArgs: [email.toLowerCase()],
    );
    if (exists.isNotEmpty) return 'البريد الإلكتروني مسجّل مسبقاً';
    // تخزين كلمة المرور مشفّرة (Salted SHA-256) وليس نصاً صريحاً
    await _db.insert('users', {
      'name': name,
      'email': email.toLowerCase(),
      'password': PasswordHasher.hash(password),
    });
    return null;
  }

  Future<Map<String, dynamic>?> login(String email, String password) async {
    final rows = await _db.query(
      'users',
      where: 'email = ?',
      whereArgs: [email.toLowerCase()],
    );
    if (rows.isEmpty) return null;
    final ok = PasswordHasher.verify(
      password,
      rows.first['password'] as String,
    );
    return ok ? rows.first : null;
  }

  Future<bool> emailExists(String email) async {
    final rows = await _db.query(
      'users',
      where: 'email = ?',
      whereArgs: [email.toLowerCase()],
    );
    return rows.isNotEmpty;
  }

  Future<void> resetPassword(String email, String newPassword) async {
    await _db.update(
      'users',
      {'password': PasswordHasher.hash(newPassword)},
      where: 'email = ?',
      whereArgs: [email.toLowerCase()],
    );
  }

  // ================= السيارة =================
  Car get car => _car;

  Future<void> saveCar(Car c) async {
    await _db.insert('car', {
      'id': 1,
      ...c.toMap(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    await _reload();
  }

  Future<void> updateOdometer(int km) async {
    if (km > _car.odometer) {
      await saveCar(Car(name: _car.name, odometer: km));
    }
  }

  // ================= الصيانة (CRUD) =================
  List<MaintenanceRecord> get maintenance => _maintenance;

  List<MaintenanceRecord> maintenanceOf(MaintenanceType t) =>
      _maintenance.where((m) => m.type == t).toList();

  MaintenanceRecord? lastOf(MaintenanceType t) {
    final l = maintenanceOf(t);
    return l.isEmpty ? null : l.first;
  }

  Future<void> addMaintenance(MaintenanceRecord r) async {
    r.id = r.id.isEmpty ? _newId() : r.id;
    await _db.insert('maintenance', r.toMap());
    await updateOdometer(r.odometer);
    await _reload();
  }

  Future<void> updateMaintenance(MaintenanceRecord r) async {
    await _db.update(
      'maintenance',
      r.toMap(),
      where: 'id = ?',
      whereArgs: [r.id],
    );
    await _reload();
  }

  Future<void> deleteMaintenance(String id) async {
    await _db.delete('maintenance', where: 'id = ?', whereArgs: [id]);
    await _reload();
  }

  HealthStatus statusOf(MaintenanceType t) {
    final last = lastOf(t);
    if (last == null) return HealthStatus.none;
    final kmLeft = last.nextKm - _car.odometer;
    final daysLeft = last.nextDate.difference(DateTime.now()).inDays;
    if (kmLeft <= 0 || daysLeft <= 0) return HealthStatus.overdue;
    if (kmLeft <= last.intervalKm * 0.2 || daysLeft <= 30) {
      return HealthStatus.warning;
    }
    return HealthStatus.good;
  }

  double progressOf(MaintenanceType t) {
    final last = lastOf(t);
    if (last == null) return 0;
    final used = _car.odometer - last.odometer;
    return (used / last.intervalKm).clamp(0.0, 1.0);
  }

  // ================= الوقود (CRUD) =================
  List<FuelRecord> get fuel => _fuel;

  Future<void> addFuel(FuelRecord r) async {
    r.id = r.id.isEmpty ? _newId() : r.id;
    await _db.insert('fuel', r.toMap());
    await updateOdometer(r.odometer);
    await _reload();
  }

  Future<void> updateFuel(FuelRecord r) async {
    await _db.update('fuel', r.toMap(), where: 'id = ?', whereArgs: [r.id]);
    await _reload();
  }

  Future<void> deleteFuel(String id) async {
    await _db.delete('fuel', where: 'id = ?', whereArgs: [id]);
    await _reload();
  }

  double get avgKmPerLiter {
    if (_fuel.length < 2) return 0;
    final distance = _fuel.first.odometer - _fuel.last.odometer;
    double liters = 0;
    for (int i = 0; i < _fuel.length - 1; i++) {
      liters += _fuel[i].liters;
    }
    return liters > 0 ? distance / liters : 0;
  }

  double get totalFuelCost => _fuel.fold(0, (s, r) => s + r.totalPrice);

  double get thisMonthFuelCost {
    final now = DateTime.now();
    return _fuel
        .where((r) => r.date.year == now.year && r.date.month == now.month)
        .fold(0, (s, r) => s + r.totalPrice);
  }

  // ================= الإصلاحات (CRUD) =================
  List<RepairRecord> get repairs => _repairs;

  Future<void> addRepair(RepairRecord r) async {
    r.id = r.id.isEmpty ? _newId() : r.id;
    await _db.insert('repairs', r.toMap());
    await updateOdometer(r.odometer);
    await _reload();
  }

  Future<void> updateRepair(RepairRecord r) async {
    await _db.update('repairs', r.toMap(), where: 'id = ?', whereArgs: [r.id]);
    await _reload();
  }

  Future<void> deleteRepair(String id) async {
    await _db.delete('repairs', where: 'id = ?', whereArgs: [id]);
    await _reload();
  }

  double get totalRepairCost => _repairs.fold(0, (s, r) => s + r.cost);
  double get totalMaintenanceCost => _maintenance.fold(0, (s, r) => s + r.cost);
}
