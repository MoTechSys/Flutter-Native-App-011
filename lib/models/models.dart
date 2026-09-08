// ============================================================
// CarCare - سجل السيارة الذكي
// نماذج البيانات (Data Models)
// ============================================================

/// أنواع سجلات الصيانة
enum MaintenanceType { oil, tires, battery, periodic }

extension MaintenanceTypeX on MaintenanceType {
  String get label {
    switch (this) {
      case MaintenanceType.oil:
        return 'زيت المحرك';
      case MaintenanceType.tires:
        return 'الإطارات';
      case MaintenanceType.battery:
        return 'البطارية';
      case MaintenanceType.periodic:
        return 'صيانة دورية';
    }
  }

  /// الفاصل الافتراضي بالكيلومتر بين كل صيانة
  int get defaultIntervalKm {
    switch (this) {
      case MaintenanceType.oil:
        return 5000;
      case MaintenanceType.tires:
        return 40000;
      case MaintenanceType.battery:
        return 60000;
      case MaintenanceType.periodic:
        return 10000;
    }
  }

  /// الفاصل الافتراضي بالأيام
  int get defaultIntervalDays {
    switch (this) {
      case MaintenanceType.oil:
        return 180;
      case MaintenanceType.tires:
        return 1095; // 3 سنوات
      case MaintenanceType.battery:
        return 1095;
      case MaintenanceType.periodic:
        return 365;
    }
  }
}

/// بيانات السيارة
class Car {
  String name;
  int odometer; // عداد الكيلومترات الحالي

  Car({required this.name, required this.odometer});

  Map<String, dynamic> toMap() => {'name': name, 'odometer': odometer};

  factory Car.fromMap(Map map) =>
      Car(name: map['name'] ?? 'سيارتي', odometer: map['odometer'] ?? 0);
}

/// سجل صيانة (زيت / إطارات / بطارية / دورية)
class MaintenanceRecord {
  String id;
  MaintenanceType type;
  DateTime date;
  int odometer; // الكيلومتر عند الصيانة
  int intervalKm; // كل كم كيلومتر تتكرر
  int intervalDays; // كل كم يوم تتكرر
  double cost;
  String notes;

  MaintenanceRecord({
    required this.id,
    required this.type,
    required this.date,
    required this.odometer,
    required this.intervalKm,
    required this.intervalDays,
    this.cost = 0,
    this.notes = '',
  });

  /// الكيلومتر المستحق للصيانة القادمة
  int get nextKm => odometer + intervalKm;

  /// التاريخ المستحق للصيانة القادمة
  DateTime get nextDate => date.add(Duration(days: intervalDays));

  Map<String, dynamic> toMap() => {
    'id': id,
    'type': type.index,
    'date': date.toIso8601String(),
    'odometer': odometer,
    'intervalKm': intervalKm,
    'intervalDays': intervalDays,
    'cost': cost,
    'notes': notes,
  };

  factory MaintenanceRecord.fromMap(Map map) => MaintenanceRecord(
    id: map['id'],
    type: MaintenanceType.values[map['type'] ?? 0],
    date: DateTime.parse(map['date']),
    odometer: map['odometer'] ?? 0,
    intervalKm: map['intervalKm'] ?? 5000,
    intervalDays: map['intervalDays'] ?? 180,
    cost: (map['cost'] ?? 0).toDouble(),
    notes: map['notes'] ?? '',
  );
}

/// سجل تعبئة وقود
class FuelRecord {
  String id;
  DateTime date;
  int odometer;
  double liters;
  double totalPrice;

  FuelRecord({
    required this.id,
    required this.date,
    required this.odometer,
    required this.liters,
    required this.totalPrice,
  });

  double get pricePerLiter => liters > 0 ? totalPrice / liters : 0;

  Map<String, dynamic> toMap() => {
    'id': id,
    'date': date.toIso8601String(),
    'odometer': odometer,
    'liters': liters,
    'totalPrice': totalPrice,
  };

  factory FuelRecord.fromMap(Map map) => FuelRecord(
    id: map['id'],
    date: DateTime.parse(map['date']),
    odometer: map['odometer'] ?? 0,
    liters: (map['liters'] ?? 0).toDouble(),
    totalPrice: (map['totalPrice'] ?? 0).toDouble(),
  );
}

/// سجل إصلاح
class RepairRecord {
  String id;
  DateTime date;
  int odometer;
  String title;
  String workshop;
  double cost;
  String notes;

  RepairRecord({
    required this.id,
    required this.date,
    required this.odometer,
    required this.title,
    this.workshop = '',
    required this.cost,
    this.notes = '',
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'date': date.toIso8601String(),
    'odometer': odometer,
    'title': title,
    'workshop': workshop,
    'cost': cost,
    'notes': notes,
  };

  factory RepairRecord.fromMap(Map map) => RepairRecord(
    id: map['id'],
    date: DateTime.parse(map['date']),
    odometer: map['odometer'] ?? 0,
    title: map['title'] ?? '',
    workshop: map['workshop'] ?? '',
    cost: (map['cost'] ?? 0).toDouble(),
    notes: map['notes'] ?? '',
  );
}

/// حالة عنصر الصيانة (جيد / قريب / متأخر)
enum HealthStatus { good, warning, overdue, none }
