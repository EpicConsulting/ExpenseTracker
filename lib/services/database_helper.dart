import 'dart:io';
import 'dart:developer' as developer;
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';

class DatabaseHelper {
  static Database? _database;

  // Bump version from 3 -> 4 to add automatic color backfill for legacy categories
  static const String dbName = 'expense_tracker.db';
  static const int dbVersion = 4;

  // Table Names
  static const String categoryTable = 'categories';
  static const String expenseTable = 'expenses';
  static const String payerTable = 'payers';

  // Category Columns
  static const String categoryId = 'id';
  static const String categoryName = 'name';
  static const String categoryColor = 'color';

  // Expense Columns
  static const String expenseId = 'id';
  static const String expenseAmount = 'amount';
  static const String expenseDate = 'date';
  static const String expenseCategoryId = 'categoryId';
  static const String expenseDescription = 'description';
  static const String expenseImage = 'imagePath';
  static const String expensePayerId = 'payerId';
  static const String expensePaymentType = 'paymentType';

  // Payer Columns
  static const String payerId = 'id';
  static const String payerName = 'name';

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    // Post-open data hygiene (safe, idempotent)
    await _assignDefaultColorsIfNeeded(_database!);
    return _database!;
  }

  Future<Database> _initDatabase() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    final String path = join(documentsDirectory.path, dbName);
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
    developer.log(
      'Upgrading database from version $oldVersion to $newVersion',
      name: 'DatabaseHelper',
    );

    // Version < 2: add payer table, payerId in expenses, color in categories
    if (oldVersion < 2) {
      // Add payerId column if missing
      final expenseCols = await db.rawQuery("PRAGMA table_info($expenseTable)");
      final hasPayerId = expenseCols.any((c) => c['name'] == expensePayerId);
      if (!hasPayerId) {
        await db.execute('ALTER TABLE $expenseTable ADD COLUMN $expensePayerId INTEGER');
        developer.log('Added $expensePayerId to $expenseTable.', name: 'DatabaseHelper');
      }

      // Create payer table if missing
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='$payerTable'",
      );
      if (tables.isEmpty) {
        await db.execute('''
          CREATE TABLE $payerTable (
            $payerId INTEGER PRIMARY KEY AUTOINCREMENT,
            $payerName TEXT NOT NULL UNIQUE
          )
        ''');
        developer.log('Payer table created during upgrade.', name: 'DatabaseHelper');
      }

      // Add category color
      final categoryCols = await db.rawQuery("PRAGMA table_info($categoryTable)");
      final hasCategoryColor = categoryCols.any((c) => c['name'] == categoryColor);
      if (!hasCategoryColor) {
        await db.execute(
          'ALTER TABLE $categoryTable ADD COLUMN $categoryColor INTEGER NOT NULL DEFAULT 0',
        );
        developer.log('Added $categoryColor to $categoryTable.', name: 'DatabaseHelper');
      }
    }

    // Version < 3: add paymentType to expenses
    if (oldVersion < 3) {
      final expenseCols = await db.rawQuery("PRAGMA table_info($expenseTable)");
      final hasPaymentType =
          expenseCols.any((column) => column['name'] == expensePaymentType);
      if (!hasPaymentType) {
        await db.execute(
          'ALTER TABLE $expenseTable ADD COLUMN $expensePaymentType TEXT NOT NULL DEFAULT \'cash\'',
        );
        developer.log('Added $expensePaymentType to $expenseTable.', name: 'DatabaseHelper');
      }
    }

    // Version < 4: backfill category colors (previously 0 = transparent problem)
    if (oldVersion < 4) {
      await _assignDefaultColorsIfNeeded(db);
    }
  }

  // -------- Category CRUD --------
  Future<int> insertCategory(Map<String, dynamic> category) async {
    final db = await database;
    try {
      final id = await db.insert(
        categoryTable,
        category,
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
      developer.log(
        'Inserted category id=$id name=${category[categoryName]}',
        name: 'DatabaseHelper',
      );
      return id;
    } on DatabaseException catch (e) {
      if (e.isUniqueConstraintError()) {
        throw Exception('Category name "${category[categoryName]}" already exists.');
      }
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getCategories() async {
    final db = await database;
    return db.query(categoryTable, orderBy: categoryName);
  }

  Future<int> deleteCategory(int id) async {
    final db = await database;
    final rows = await db.delete(
      categoryTable,
      where: '$categoryId = ?',
      whereArgs: [id],
    );
    developer.log(
      'Deleted $rows category rows for id=$id',
      name: 'DatabaseHelper',
    );
    return rows;
  }

  Future<int> updateCategory(int id, String newName, [int? newColor]) async {
    final db = await database;
    try {
      final values = <String, Object?>{categoryName: newName};
      if (newColor != null) values[categoryColor] = newColor;
      final rows = await db.update(
        categoryTable,
        values,
        where: '$categoryId = ?',
        whereArgs: [id],
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
      developer.log(
        'Updated category id=$id rows=$rows (name/color)',
        name: 'DatabaseHelper',
      );
      return rows;
    } on DatabaseException catch (e) {
      if (e.isUniqueConstraintError()) {
        throw Exception('Category name "$newName" already exists.');
      }
      rethrow;
    }
  }

  // -------- Payer CRUD --------
  Future<int> insertPayer(Map<String, dynamic> payer) async {
    final db = await database;
    try {
      final id = await db.insert(
        payerTable,
        payer,
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
      developer.log(
        'Inserted payer id=$id name=${payer[payerName]}',
        name: 'DatabaseHelper',
      );
      return id;
    } on DatabaseException catch (e) {
      if (e.isUniqueConstraintError()) {
        throw Exception('Payer name "${payer[payerName]}" already exists.');
      }
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getPayers() async {
    final db = await database;
    return db.query(payerTable, orderBy: payerName);
  }

  Future<int> deletePayer(int id) async {
    final db = await database;
    final rows = await db.delete(
      payerTable,
      where: '$payerId = ?',
      whereArgs: [id],
    );
    developer.log('Deleted payer rows=$rows id=$id', name: 'DatabaseHelper');
    return rows;
  }

  Future<int> updatePayer(int id, String newName) async {
    final db = await database;
    try {
      final rows = await db.update(
        payerTable,
        {payerName: newName},
        where: '$payerId = ?',
        whereArgs: [id],
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
      developer.log('Updated payer id=$id rows=$rows', name: 'DatabaseHelper');
      return rows;
    } on DatabaseException catch (e) {
      if (e.isUniqueConstraintError()) {
        throw Exception('Payer name "$newName" already exists.');
      }
      rethrow;
    }
  }

  // -------- Expense CRUD --------
  Future<int> insertExpense(Map<String, dynamic> expense) async {
    final db = await database;
    try {
      final id = await db.insert(
        expenseTable,
        expense,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      developer.log(
        'Inserted expense id=$id amount=${expense[expenseAmount]}',
        name: 'DatabaseHelper',
      );
      return id;
    } catch (e) {
      developer.log('Error inserting expense: $e', name: 'DatabaseHelper', error: e);
      rethrow;
    }
  }

  Future<int> updateExpense(Map<String, dynamic> expense) async {
    final db = await database;
    final rows = await db.update(
      expenseTable,
      expense,
      where: '$expenseId = ?',
      whereArgs: [expense[expenseId]],
    );
    developer.log(
      'Updated expense id=${expense[expenseId]} rows=$rows',
      name: 'DatabaseHelper',
    );
    return rows;
  }

  Future<int> deleteExpense(int id) async {
    final db = await database;
    final rows = await db.delete(
      expenseTable,
      where: '$expenseId = ?',
      whereArgs: [id],
    );
    developer.log('Deleted expense id=$id rows=$rows', name: 'DatabaseHelper');
    return rows;
  }

  Future<List<Map<String, dynamic>>> getExpenses() async {
    final db = await database;
    // Return categoryColor too (already used in UI logic)
    return db.rawQuery('''
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
      FROM $expenseTable e
      LEFT JOIN $categoryTable c
        ON e.$expenseCategoryId = c.$categoryId
      LEFT JOIN $payerTable p
        ON e.$expensePayerId = p.$payerId
      ORDER BY e.$expenseDate DESC
    ''');
  }

  Future<List<Map<String, dynamic>>> getDatesWithExpensesForMonth(
    int year,
    int month,
  ) async {
    final db = await database;
    final DateTime startOfMonth = DateTime(year, month, 1);
    final DateTime endOfMonth = DateTime(year, month + 1, 0).endOfDay;
    return db.rawQuery('''
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
    final maps = await db.rawQuery('''
      SELECT DISTINCT strftime('%Y', $expenseDate) AS year
      FROM $expenseTable
      ORDER BY year DESC
    ''');
    return maps.map((m) => int.parse(m['year'] as String)).toList();
  }

  // -------- Color Backfill Logic --------
  /// Assigns default colors to categories that still have color = 0 (legacy rows)
  /// Idempotent: safe to call many times (will skip if none).
  Future<void> _assignDefaultColorsIfNeeded(Database db) async {
    try {
      final rows = await db.query(
        categoryTable,
        columns: [categoryId, categoryColor],
        where: '$categoryColor = ?',
        whereArgs: [0],
        orderBy: categoryId,
      );

      if (rows.isEmpty) {
        developer.log('No legacy categories needing color backfill.', name: 'DatabaseHelper');
        return;
      }

      developer.log(
        'Backfilling colors for ${rows.length} categories (color=0).',
        name: 'DatabaseHelper',
      );

      int i = 0;
      final batch = db.batch();
      for (final row in rows) {
        final int idVal = row[categoryId] as int;
        final int newColor = _fallbackColorForIndex(i++);
        batch.update(
          categoryTable,
            {categoryColor: newColor},
          where: '$categoryId = ?',
          whereArgs: [idVal],
        );
      }
      await batch.commit(noResult: true);
      developer.log(
        'Assigned default colors to ${rows.length} legacy categories.',
        name: 'DatabaseHelper',
      );
    } catch (e, st) {
      developer.log(
        'Error assigning default colors: $e',
        name: 'DatabaseHelper',
        error: e,
        stackTrace: st,
      );
    }
  }

  int _fallbackColorForIndex(int index) {
    switch (index % 5) {
      case 0:
        return 0xFF1976D2; // Blue
      case 1:
        return 0xFF388E3C; // Green
      case 2:
        return 0xFFF57C00; // Orange
      case 3:
        return 0xFF7B1FA2; // Purple
      case 4:
        return 0xFFD32F2F; // Red
      default:
        return 0xFF9E9E9E;
    }
  }
}

// -------- Extensions --------
extension DateTimeExtension on DateTime {
  DateTime get endOfDay =>
      DateTime(year, month, day, 23, 59, 59, 999, 999);
}

extension DatabaseExceptionExtension on DatabaseException {
  bool isUniqueConstraintError() {
    final message = toString();
    return message.contains('UNIQUE constraint failed') ||
        message.contains('constraint failed');
  }
}