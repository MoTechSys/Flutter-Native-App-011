// ============================================================
// CarCare - خدمة التخزين المحلي (Hive)
// كل البيانات تُحفظ على الجهاز بدون إنترنت
// ============================================================

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/models.dart';

class StorageService extends ChangeNotifier {
  static final StorageService instance = StorageService._();
  StorageService._();

  late Box _carBox;
  late Box _maintenanceBox;
  late Box _fuelBox;
  late Box _repairBox;

  Future<void> init() async {
    await Hive.initFlutter();
    _carBox = await Hive.openBox('car');
    _maintenanceBox = await Hive.openBox('maintenance');
    _fuelBox = await Hive.openBox('fuel');
    _repairBox = await Hive.openBox('repairs');
  }

  String _newId() => DateTime.now().microsecondsSinceEpoch.toString();

  // ---------------- السيارة ----------------
  Car get car => _carBox.isEmpty
      ? Car(name: 'سيارتي', odometer: 0)
      : Car.fromMap(_carBox.get('car'));

  Future<void> saveCar(Car c) async {
    await _carBox.put('car', c.toMap());
    notifyListeners();
  }

  Future<void> updateOdometer(int km) async {
    final c = car;
    if (km > c.odometer) {
      c.odometer = km;
      await saveCar(c);
    }
  }

  // ---------------- الصيانة ----------------
  List<MaintenanceRecord> get maintenance {
    final list = _maintenanceBox.values
        .map((e) => MaintenanceRecord.fromMap(e))
        .toList();
    list.sort((a, b) => b.date.compareTo(a.date)); // الأحدث أولاً
    return list;
  }

  List<MaintenanceRecord> maintenanceOf(MaintenanceType t) =>
      maintenance.where((m) => m.type == t).toList();

  /// آخر صيانة من نوع معين
  MaintenanceRecord? lastOf(MaintenanceType t) {
    final l = maintenanceOf(t);
    return l.isEmpty ? null : l.first;
  }

  Future<void> addMaintenance(MaintenanceRecord r) async {
    r.id = r.id.isEmpty ? _newId() : r.id;
    await _maintenanceBox.put(r.id, r.toMap());
    await updateOdometer(r.odometer);
    notifyListeners();
  }

  Future<void> deleteMaintenance(String id) async {
    await _maintenanceBox.delete(id);
    notifyListeners();
  }

  /// حساب حالة عنصر الصيانة بناءً على العداد الحالي والتاريخ
  HealthStatus statusOf(MaintenanceType t) {
    final last = lastOf(t);
    if (last == null) return HealthStatus.none;
    final kmLeft = last.nextKm - car.odometer;
    final daysLeft = last.nextDate.difference(DateTime.now()).inDays;
    if (kmLeft <= 0 || daysLeft <= 0) return HealthStatus.overdue;
    if (kmLeft <= last.intervalKm * 0.2 || daysLeft <= 30) {
      return HealthStatus.warning;
    }
    return HealthStatus.good;
  }

  /// نسبة التقدم (0 = جديد، 1 = مستحق)
  double progressOf(MaintenanceType t) {
    final last = lastOf(t);
    if (last == null) return 0;
    final used = car.odometer - last.odometer;
    return (used / last.intervalKm).clamp(0.0, 1.0);
  }

  // ---------------- الوقود ----------------
  List<FuelRecord> get fuel {
    final list = _fuelBox.values.map((e) => FuelRecord.fromMap(e)).toList();
    list.sort((a, b) => b.odometer.compareTo(a.odometer));
    return list;
  }

  Future<void> addFuel(FuelRecord r) async {
    r.id = r.id.isEmpty ? _newId() : r.id;
    await _fuelBox.put(r.id, r.toMap());
    await updateOdometer(r.odometer);
    notifyListeners();
  }

  Future<void> deleteFuel(String id) async {
    await _fuelBox.delete(id);
    notifyListeners();
  }

  /// متوسط الاستهلاك كم/لتر (يحتاج تعبئتين على الأقل)
  double get avgKmPerLiter {
    final f = fuel;
    if (f.length < 2) return 0;
    final distance = f.first.odometer - f.last.odometer;
    // نحسب اللترات من كل التعبئات ما عدا الأولى (الأقدم)
    double liters = 0;
    for (int i = 0; i < f.length - 1; i++) {
      liters += f[i].liters;
    }
    return liters > 0 ? distance / liters : 0;
  }

  double get totalFuelCost => fuel.fold(0, (s, r) => s + r.totalPrice);

  double get thisMonthFuelCost {
    final now = DateTime.now();
    return fuel
        .where((r) => r.date.year == now.year && r.date.month == now.month)
        .fold(0, (s, r) => s + r.totalPrice);
  }

  // ---------------- الإصلاحات ----------------
  List<RepairRecord> get repairs {
    final list =
        _repairBox.values.map((e) => RepairRecord.fromMap(e)).toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  Future<void> addRepair(RepairRecord r) async {
    r.id = r.id.isEmpty ? _newId() : r.id;
    await _repairBox.put(r.id, r.toMap());
    await updateOdometer(r.odometer);
    notifyListeners();
  }

  Future<void> deleteRepair(String id) async {
    await _repairBox.delete(id);
    notifyListeners();
  }

  double get totalRepairCost => repairs.fold(0, (s, r) => s + r.cost);

  double get totalMaintenanceCost => maintenance.fold(0, (s, r) => s + r.cost);
}
