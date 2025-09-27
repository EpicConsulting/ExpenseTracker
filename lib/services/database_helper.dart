import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:developer' as developer;

class DatabaseHelper {
  static Database? _database;
  static const String dbName = 'expense_tracker.db';
  static const int dbVersion = 3; // กำหนดเวอร์ชันฐานข้อมูลเป็น 3

  // Table Names
  static const String categoryTable = 'categories';
  static const String expenseTable = 'expenses';
  static const String payerTable = 'payers';

  // Category Table Columns
  static const String categoryId = 'id';
  static const String categoryName = 'name';
  static const String categoryColor = 'color';

  // Expense Table Columns
  static const String expenseId = 'id';
  static const String expenseAmount = 'amount';
  static const String expenseDate = 'date';
  static const String expenseCategoryId = 'categoryId';
  static const String expenseDescription = 'description';
  static const String expenseImage = 'imagePath';
  static const String expensePayerId = 'payerId';
  static const String expensePaymentType = 'paymentType';

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
    developer.log('Database path: $path', name: 'DatabaseHelper');
    return await openDatabase(
      path,
      version: dbVersion,
      onCreate: _onCreate,
      onConfigure: _onConfigure,
      onUpgrade: _onUpgrade,
    );
  }

  Future _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
    developer.log('Foreign keys enabled.', name: 'DatabaseHelper');
  }

  Future _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $categoryTable (
        $categoryId INTEGER PRIMARY KEY AUTOINCREMENT,
        $categoryName TEXT NOT NULL UNIQUE,
        $categoryColor INTEGER NOT NULL DEFAULT 0
      )
    ''');
    developer.log('Category table created.', name: 'DatabaseHelper');

    await db.execute('''
      CREATE TABLE $payerTable (
        $payerId INTEGER PRIMARY KEY AUTOINCREMENT,
        $payerName TEXT NOT NULL UNIQUE
      )
    ''');
    developer.log('Payer table created.', name: 'DatabaseHelper');

    await db.execute('''
      CREATE TABLE $expenseTable (
        $expenseId INTEGER PRIMARY KEY AUTOINCREMENT,
        $expenseAmount REAL NOT NULL,
        $expenseDate TEXT NOT NULL,
        $expenseCategoryId INTEGER,
        $expenseDescription TEXT,
        $expenseImage TEXT,
        $expensePayerId INTEGER,
        $expensePaymentType TEXT NOT NULL DEFAULT 'cash',
        FOREIGN KEY ($expenseCategoryId) REFERENCES $categoryTable($categoryId) ON DELETE SET NULL,
        FOREIGN KEY ($expensePayerId) REFERENCES $payerTable($payerId) ON DELETE SET NULL
      )
    ''');
    developer.log('Expense table created.', name: 'DatabaseHelper');
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    developer.log('Upgrading database from version $oldVersion to $newVersion', name: 'DatabaseHelper');
    if (oldVersion < 2) {
      var columns = await db.rawQuery("PRAGMA table_info($expenseTable)");
      var hasPayerId = columns.any((column) => column['name'] == expensePayerId);
      if (!hasPayerId) {
        await db.execute('ALTER TABLE $expenseTable ADD COLUMN $expensePayerId INTEGER');
        developer.log('Added $expensePayerId to $expenseTable.', name: 'DatabaseHelper');
      } else {
        developer.log('$expensePayerId column already exists in $expenseTable.', name: 'DatabaseHelper');
      }

      var tables = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name='$payerTable'");
      if (tables.isEmpty) {
        await db.execute('''
          CREATE TABLE $payerTable (
            $payerId INTEGER PRIMARY KEY AUTOINCREMENT,
            $payerName TEXT NOT NULL UNIQUE
          )
        ''');
        developer.log('Payer table created during upgrade.', name: 'DatabaseHelper');
      } else {
        developer.log('$payerTable table already exists.', name: 'DatabaseHelper');
      }

      var categoryColumns = await db.rawQuery("PRAGMA table_info($categoryTable)");
      var hasCategoryColor = categoryColumns.any((column) => column['name'] == categoryColor);
      if (!hasCategoryColor) {
        await db.execute('ALTER TABLE $categoryTable ADD COLUMN $categoryColor INTEGER NOT NULL DEFAULT 0');
        developer.log('Added $categoryColor to $categoryTable.', name: 'DatabaseHelper');
      }
    }
    if (oldVersion < 3) {
      var columns = await db.rawQuery("PRAGMA table_info($expenseTable)");
      var hasPaymentType = columns.any((column) => column['name'] == expensePaymentType);
      if (!hasPaymentType) {
        await db.execute(
            'ALTER TABLE $expenseTable ADD COLUMN $expensePaymentType TEXT NOT NULL DEFAULT \'cash\'');
        developer.log('Added $expensePaymentType to $expenseTable.', name: 'DatabaseHelper');
      } else {
        developer.log('$expensePaymentType column already exists in $expenseTable.', name: 'DatabaseHelper');
      }
    }
  }

  // --- Category Operations ---
  Future<int> insertCategory(Map<String, dynamic> category) async {
    Database db = await database;
    try {
      final id =
          await db.insert(categoryTable, category, conflictAlgorithm: ConflictAlgorithm.abort);
      developer.log('Inserted category with ID: $id and name: ${category[categoryName]}',
          name: 'DatabaseHelper');
      return id;
    } on DatabaseException catch (e) {
      if (e.isUniqueConstraintError()) {
        throw Exception('Category name "${category[categoryName]}" already exists.');
      }
      rethrow;
    } catch (e) {
      developer.log('Error inserting category: $e', name: 'DatabaseHelper', error: e);
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
      final rowsAffected =
          await db.delete(categoryTable, where: '$categoryId = ?', whereArgs: [id]);
      developer.log('Deleted $rowsAffected rows from categories table for ID: $id',
          name: 'DatabaseHelper');
      return rowsAffected;
    } catch (e) {
      developer.log('Error deleting category: $e', name: 'DatabaseHelper', error: e);
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
      developer.log('Updated $rowsAffected rows in categories table for ID: $id',
          name: 'DatabaseHelper');
      return rowsAffected;
    } on DatabaseException catch (e) {
      if (e.isUniqueConstraintError()) {
        throw Exception('Category name "$newName" already exists.');
      }
      rethrow;
    } catch (e) {
      developer.log('Error updating category: $e', name: 'DatabaseHelper', error: e);
      rethrow;
    }
  }

  // --- Payer Operations ---
  Future<int> insertPayer(Map<String, dynamic> payer) async {
    Database db = await database;
    try {
      final id =
          await db.insert(payerTable, payer, conflictAlgorithm: ConflictAlgorithm.abort);
      developer.log('Inserted payer with ID: $id and name: ${payer[payerName]}',
          name: 'DatabaseHelper');
      return id;
    } on DatabaseException catch (e) {
      if (e.isUniqueConstraintError()) {
        throw Exception('Payer name "${payer[payerName]}" already exists.');
      }
      rethrow;
    } catch (e) {
      developer.log('Error inserting payer: $e', name: 'DatabaseHelper', error: e);
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
      final rowsAffected =
          await db.delete(payerTable, where: '$payerId = ?', whereArgs: [id]);
      developer.log('Deleted $rowsAffected rows from payers table for ID: $id',
          name: 'DatabaseHelper');
      return rowsAffected;
    } catch (e) {
      developer.log('Error deleting payer: $e', name: 'DatabaseHelper', error: e);
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
      developer.log('Updated $rowsAffected rows in payers table for ID: $id',
          name: 'DatabaseHelper');
      return rowsAffected;
    } on DatabaseException catch (e) {
      if (e.isUniqueConstraintError()) {
        throw Exception('Payer name "$newName" already exists.');
      }
      rethrow;
    } catch (e) {
      developer.log('Error updating payer: $e', name: 'DatabaseHelper', error: e);
      rethrow;
    }
  }

  // --- Expense Operations ---
  Future<int> insertExpense(Map<String, dynamic> expense) async {
    Database db = await database;
    try {
      final id =
          await db.insert(expenseTable, expense, conflictAlgorithm: ConflictAlgorithm.replace);
      developer.log('Inserted expense with ID: $id and amount: ${expense[expenseAmount]}',
          name: 'DatabaseHelper');
      return id;
    } catch (e) {
      developer.log('Error inserting expense: $e', name: 'DatabaseHelper', error: e);
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
      developer.log('Updated $rowsAffected rows in expenses table for ID: ${expense[expenseId]}',
          name: 'DatabaseHelper');
      return rowsAffected;
    } catch (e) {
      developer.log('Error updating expense: $e', name: 'DatabaseHelper', error: e);
      rethrow;
    }
  }

  Future<int> deleteExpense(int id) async {
    Database db = await database;
    try {
      final rowsAffected =
          await db.delete(expenseTable, where: '$expenseId = ?', whereArgs: [id]);
      developer.log('Deleted $rowsAffected rows from expenses table for ID: $id',
          name: 'DatabaseHelper');
      return rowsAffected;
    } catch (e) {
      developer.log('Error deleting expense: $e', name: 'DatabaseHelper', error: e);
      rethrow;
    }
  }

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
        e.$expensePaymentType AS paymentType,
        c.$categoryName AS categoryName,
        c.$categoryColor AS categoryColor,
        p.$payerName AS payerName
      FROM $expenseTable AS e
      LEFT JOIN $categoryTable AS c
        ON e.$expenseCategoryId = c.$categoryId
      LEFT JOIN $payerTable AS p
        ON e.$expensePayerId = p.$payerId
      ORDER BY e.$expenseDate DESC
    ''');
  }

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

  Future<List<int>> getDistinctExpenseYears() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT DISTINCT strftime('%Y', $expenseDate) AS year
      FROM $expenseTable
      ORDER BY year DESC
    ''');
    return maps.map((map) => int.parse(map['year'] as String)).toList();
  }
}

extension DateTimeExtension on DateTime {
  DateTime get endOfDay {
    return DateTime(year, month, day, 23, 59, 59, 999, 999);
  }
}

extension DatabaseExceptionExtension on DatabaseException {
  bool isUniqueConstraintError() {
    // Removed unnecessary 'this.' qualifiers per lint
    final message = toString();
    return message.contains('UNIQUE constraint failed') ||
        message.contains('constraint failed');
  }
}