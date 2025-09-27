import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class DatabaseHelper {
  static Database? _database;
  static const String dbName = 'expense_tracker.db';
  static const int dbVersion = 2; // กำหนดเวอร์ชันฐานข้อมูลเป็น 2

  // Table Names
  static const String categoryTable = 'categories';
  static const String expenseTable = 'expenses';
  static const String payerTable = 'payers';

  // Category Table Columns
  static const String categoryId = 'id';
  static const String categoryName = 'name';
  // เพิ่มคอลัมน์สีสำหรับ Category (ถ้ามีในโมเดลของคุณ)
  static const String categoryColor = 'color'; // ตรวจสอบว่าคุณได้เพิ่มคอลัมน์นี้ใน Category Model ด้วย

  // Expense Table Columns
  static const String expenseId = 'id';
  static const String expenseAmount = 'amount';
  static const String expenseDate = 'date';
  static const String expenseCategoryId = 'categoryId';
  static const String expenseDescription = 'description';
  static const String expenseImage = 'imagePath';
  static const String expensePayerId = 'payerId';

  // Payer Table Columns
  static const String payerId = 'id';
  static const String payerName = 'name';

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, dbName);
    print('Database path: $path');
    return await openDatabase(
      path,
      version: dbVersion,
      onCreate: _onCreate,
      onConfigure: _onConfigure,
      onUpgrade: _onUpgrade,
    );
  }

  // เพิ่ม onConfigure เพื่อเปิดใช้งาน Foreign Keys
  Future _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
    print('Foreign keys enabled.');
  }

  Future _onCreate(Database db, int version) async {
    // Create Categories Table
    await db.execute('''
      CREATE TABLE $categoryTable (
        $categoryId INTEGER PRIMARY KEY AUTOINCREMENT,
        $categoryName TEXT NOT NULL UNIQUE,
        $categoryColor INTEGER NOT NULL DEFAULT 0 -- เพิ่ม DEFAULT value สำหรับสี
      )
    ''');
    print('Category table created.');

    // Create Payers Table
    await db.execute('''
      CREATE TABLE $payerTable (
        $payerId INTEGER PRIMARY KEY AUTOINCREMENT,
        $payerName TEXT NOT NULL UNIQUE
      )
    ''');
    print('Payer table created.');

    // Create Expenses Table
    await db.execute('''
      CREATE TABLE $expenseTable (
        $expenseId INTEGER PRIMARY KEY AUTOINCREMENT,
        $expenseAmount REAL NOT NULL,
        $expenseDate TEXT NOT NULL,
        $expenseCategoryId INTEGER,
        $expenseDescription TEXT,
        $expenseImage TEXT,
        $expensePayerId INTEGER,
        FOREIGN KEY ($expenseCategoryId) REFERENCES $categoryTable($categoryId) ON DELETE SET NULL,
        FOREIGN KEY ($expensePayerId) REFERENCES $payerTable($payerId) ON DELETE SET NULL
      )
    ''');
    print('Expense table created.');
  }

  // เมธอด onUpgrade สำหรับจัดการการเปลี่ยนแปลงโครงสร้างฐานข้อมูล
  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    print('Upgrading database from version $oldVersion to $newVersion');
    if (oldVersion < 2) {
      // ตรวจสอบและเพิ่มคอลัมน์ payerId ในตาราง expenses
      var columns = await db.rawQuery("PRAGMA table_info($expenseTable)");
      var hasPayerId = columns.any((column) => column['name'] == expensePayerId);
      if (!hasPayerId) {
        await db.execute('ALTER TABLE $expenseTable ADD COLUMN $expensePayerId INTEGER');
        print('Added $expensePayerId to $expenseTable.');
      } else {
        print('$expensePayerId column already exists in $expenseTable.');
      }

      // ตรวจสอบและสร้างตาราง payers ถ้ายังไม่มี
      var tables = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name='$payerTable'");
      if (tables.isEmpty) {
        await db.execute('''
          CREATE TABLE $payerTable (
            $payerId INTEGER PRIMARY KEY AUTOINCREMENT,
            $payerName TEXT NOT NULL UNIQUE
          )
        ''');
        print('Payer table created during upgrade.');
      } else {
        print('$payerTable table already exists.');
      }

      // สำหรับ Category table: เพิ่มคอลัมน์สี
      var categoryColumns = await db.rawQuery("PRAGMA table_info($categoryTable)");
      var hasCategoryColor = categoryColumns.any((column) => column['name'] == categoryColor);
      if (!hasCategoryColor) {
        await db.execute('ALTER TABLE $categoryTable ADD COLUMN $categoryColor INTEGER NOT NULL DEFAULT 0');
        print('Added $categoryColor to $categoryTable.');
      }
    }
    // เพิ่มเงื่อนไข if (oldVersion < X) สำหรับการเปลี่ยนแปลงในเวอร์ชันถัดไป
  }

  // --- Category Operations ---
  Future<int> insertCategory(Map<String, dynamic> category) async {
    Database db = await database;
    try {
      final id = await db.insert(categoryTable, category, conflictAlgorithm: ConflictAlgorithm.abort);
      print('Inserted category with ID: $id and name: ${category[categoryName]}');
      return id;
    } on DatabaseException catch (e) {
      if (e.isUniqueConstraintError()) {
        throw Exception('Category name "${category[categoryName]}" already exists.');
      }
      rethrow;
    } catch (e) {
      print('Error inserting category: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getCategories() async {
    Database db = await database;
    return await db.query(categoryTable, orderBy: categoryName);
  }

  Future<int> deleteCategory(int id) async {
    Database db = await database;
    try {
      final rowsAffected = await db
          .delete(categoryTable, where: '$categoryId = ?', whereArgs: [id]);
      print('Deleted $rowsAffected rows from categories table for ID: $id');
      return rowsAffected;
    } catch (e) {
      print('Error deleting category: $e');
      rethrow;
    }
  }

  Future<int> updateCategory(int id, String newName, [int? newColor]) async {
    Database db = await database;
    try {
      final Map<String, dynamic> values = {categoryName: newName};
      if (newColor != null) {
        values[categoryColor] = newColor;
      }
      final rowsAffected = await db.update(
        categoryTable,
        values,
        where: '$categoryId = ?',
        whereArgs: [id],
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
      print('Updated $rowsAffected rows in categories table for ID: $id');
      return rowsAffected;
    } on DatabaseException catch (e) {
      if (e.isUniqueConstraintError()) {
        throw Exception('Category name "$newName" already exists.');
      }
      rethrow;
    } catch (e) {
      print('Error updating category: $e');
      rethrow;
    }
  }

  // --- Payer Operations ---
  Future<int> insertPayer(Map<String, dynamic> payer) async {
    Database db = await database;
    try {
      final id = await db.insert(payerTable, payer, conflictAlgorithm: ConflictAlgorithm.abort);
      print('Inserted payer with ID: $id and name: ${payer[payerName]}');
      return id;
    } on DatabaseException catch (e) {
      if (e.isUniqueConstraintError()) {
        throw Exception('Payer name "${payer[payerName]}" already exists.');
      }
      rethrow;
    } catch (e) {
      print('Error inserting payer: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getPayers() async {
    Database db = await database;
    return await db.query(payerTable, orderBy: payerName);
  }

  Future<int> deletePayer(int id) async {
    Database db = await database;
    try {
      final rowsAffected = await db
          .delete(payerTable, where: '$payerId = ?', whereArgs: [id]);
      print('Deleted $rowsAffected rows from payers table for ID: $id');
      return rowsAffected;
    } catch (e) {
      print('Error deleting payer: $e');
      rethrow;
    }
  }

  Future<int> updatePayer(int id, String newName) async {
    Database db = await database;
    try {
      final rowsAffected = await db.update(
        payerTable,
        {payerName: newName},
        where: '$payerId = ?',
        whereArgs: [id],
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
      print('Updated $rowsAffected rows in payers table for ID: $id');
      return rowsAffected;
    } on DatabaseException catch (e) {
      if (e.isUniqueConstraintError()) {
        throw Exception('Payer name "$newName" already exists.');
      }
      rethrow;
    } catch (e) {
      print('Error updating payer: $e');
      rethrow;
    }
  }

  // --- Expense Operations ---
  Future<int> insertExpense(Map<String, dynamic> expense) async {
    Database db = await database;
    try {
      final id = await db.insert(expenseTable, expense, conflictAlgorithm: ConflictAlgorithm.replace);
      print('Inserted expense with ID: $id and amount: ${expense[expenseAmount]}');
      return id;
    } catch (e) {
      print('Error inserting expense: $e');
      rethrow;
    }
  }

  Future<int> updateExpense(Map<String, dynamic> expense) async {
    Database db = await database;
    try {
      final rowsAffected = await db.update(
        expenseTable,
        expense,
        where: '$expenseId = ?',
        whereArgs: [expense[expenseId]],
      );
      print('Updated $rowsAffected rows in expenses table for ID: ${expense[expenseId]}');
      return rowsAffected;
    } catch (e) {
      print('Error updating expense: $e');
      rethrow;
    }
  }

  Future<int> deleteExpense(int id) async {
    Database db = await database;
    try {
      final rowsAffected = await db.delete(expenseTable, where: '$expenseId = ?', whereArgs: [id]);
      print('Deleted $rowsAffected rows from expenses table for ID: $id');
      return rowsAffected;
    } catch (e) {
      print('Error deleting expense: $e');
      rethrow;
    }
  }

  // ดึงข้อมูลค่าใช้จ่ายทั้งหมด พร้อมชื่อหมวดหมู่และชื่อผู้จ่าย
  Future<List<Map<String, dynamic>>> getExpenses() async {
    Database db = await database;
    return await db.rawQuery('''
      SELECT
        e.$expenseId AS id,
        e.$expenseAmount AS amount,
        e.$expenseDate AS date,
        e.$expenseCategoryId AS categoryId,
        e.$expenseDescription AS description,
        e.$expenseImage AS imagePath,
        e.$expensePayerId AS payerId,
        c.$categoryName AS categoryName,
        c.$categoryColor AS categoryColor, -- เพิ่ม categoryColor
        p.$payerName AS payerName
      FROM $expenseTable AS e
      LEFT JOIN $categoryTable AS c
        ON e.$expenseCategoryId = c.$categoryId
      LEFT JOIN $payerTable AS p
        ON e.$expensePayerId = p.$payerId
      ORDER BY e.$expenseDate DESC
    ''');
  }

  // ดึงวันที่ที่มีค่าใช้จ่ายสำหรับเดือนที่ระบุ (สำหรับ TableCalendar)
  Future<List<Map<String, dynamic>>> getDatesWithExpensesForMonth(int year, int month) async {
    Database db = await database;
    final DateTime startOfMonth = DateTime(year, month, 1);
    final DateTime endOfMonth = DateTime(year, month + 1, 0).endOfDay;

    return await db.rawQuery('''
      SELECT DISTINCT
        strftime('%Y-%m-%d', $expenseDate) AS expenseDay
      FROM $expenseTable
      WHERE $expenseDate BETWEEN ? AND ?
    ''', [
      startOfMonth.toIso8601String(),
      endOfMonth.toIso8601String(),
    ]);
  }

  // lib/services/database_helper.dart

  Future<List<int>> getDistinctExpenseYears() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
    SELECT DISTINCT strftime('%Y', ${DatabaseHelper.expenseDate}) AS year
    FROM ${DatabaseHelper.expenseTable}
    ORDER BY year DESC
  ''');
    return maps.map((map) => int.parse(map['year'] as String)).toList();
  }

// ถ้า ExpenseProvider ยังคงเรียกเมธอดนี้สำหรับดึงค่าใช้จ่ายรายวันพร้อม Join
// ควรใช้เมธอดนี้แทน getExpenses() หรือสร้างเมธอดเฉพาะสำหรับวัน
// แต่จากโค้ด ExpenseProvider ล่าสุดที่ผมให้ไป มันจะดึงทั้งหมดแล้วกรอง
// ดังนั้น getExpenses() ด้านบนน่าจะเพียงพอ
/*
  Future<List<Map<String, dynamic>>> getExpensesForSpecificDay(int year, int month, int day) async {
    Database db = await database;
    final DateTime startOfDay = DateTime(year, month, day);
    final DateTime endOfDay = startOfDay.endOfDay;

    return await db.rawQuery('''
      SELECT
        e.$expenseId AS id,
        e.$expenseAmount AS amount,
        e.$expenseDate AS date,
        e.$expenseCategoryId AS categoryId,
        e.$expenseDescription AS description,
        e.$expenseImage AS imagePath,
        e.$expensePayerId AS payerId,
        c.$categoryName AS categoryName,
        c.$categoryColor AS categoryColor,
        p.$payerName AS payerName
      FROM $expenseTable AS e
      LEFT JOIN $categoryTable AS c
        ON e.$expenseCategoryId = c.$categoryId
      LEFT JOIN $payerTable AS p
        ON e.$expensePayerId = p.$payerId
      WHERE e.$expenseDate BETWEEN ? AND ?
      ORDER BY e.$expenseDate DESC
    ''', [
      startOfDay.toIso8601String(),
      endOfDay.toIso8601String(),
    ]);
  }
  */
}

// Extension เพื่อช่วยในการหาจุดสิ้นสุดของวัน (รวมเวลา 23:59:59)
extension DateTimeExtension on DateTime {
  DateTime get endOfDay {
    return DateTime(year, month, day, 23, 59, 59, 999, 999);
  }
}

// Extension สำหรับ DatabaseException เพื่อตรวจสอบ Unique Constraint Error
extension DatabaseExceptionExtension on DatabaseException {
  bool isUniqueConstraintError() {
    // ตรวจสอบข้อความ Error ที่บ่งบอกถึง Unique Constraint
    // อาจแตกต่างกันไปในแต่ละเวอร์ชันของ SQLite หรือแพลตฟอร์ม
    return this.toString().contains('UNIQUE constraint failed') ||
        this.toString().contains('constraint failed');
  }
}