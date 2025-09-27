import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart' as sql;
import 'dart:developer' as developer;

import '../models/expense.dart';
import '../services/database_helper.dart';
import '../models/category.dart';
import '../models/payer.dart';

class ExpenseProvider with ChangeNotifier {
  List<Expense> _expenses = [];
  final DatabaseHelper _dbHelper = DatabaseHelper(); // *** แก้ไข: เพิ่มบรรทัดนี้เข้ามา ***

  List<Expense> get expenses {
    return [..._expenses];
  }

  ExpenseProvider() {
    developer.log('ExpenseProvider initialized. Fetching expenses...', name: 'ExpenseProvider');
    fetchExpenses();
  }

  Future<void> addExpense(Expense expense) async {
    developer.log('Adding new expense: ${expense.amount}', name: 'ExpenseProvider');
    try {
      final db = await _dbHelper.database; // ใช้ _dbHelper
      final id = await db.insert(
        DatabaseHelper.expenseTable,
        expense.toMap(),
        conflictAlgorithm: sql.ConflictAlgorithm.replace,
      );

      final newExpense = Expense(
        id: id,
        amount: expense.amount,
        date: expense.date,
        categoryId: expense.categoryId,
        categoryName: expense.categoryName,
        description: expense.description,
        imagePath: expense.imagePath,
        payerId: expense.payerId,
        payerName: expense.payerName,
      );
      _expenses.add(newExpense);
      notifyListeners();
      developer.log('Expense added with ID: $id', name: 'ExpenseProvider');
    } catch (e) {
      developer.log('Error adding expense: $e', name: 'ExpenseProvider', error: e);
      rethrow;
    }
  }

  Future<void> updateExpense(Expense expense) async {
    developer.log('Updating expense with ID: ${expense.id}', name: 'ExpenseProvider');
    try {
      final db = await _dbHelper.database; // ใช้ _dbHelper
      await db.update(
        DatabaseHelper.expenseTable,
        expense.toMap(),
        where: '${DatabaseHelper.expenseId} = ?',
        whereArgs: [expense.id],
      );

      final expenseIndex = _expenses.indexWhere((exp) => exp.id == expense.id);
      if (expenseIndex >= 0) {
        _expenses[expenseIndex] = expense;
      }
      notifyListeners();
      developer.log('Expense updated with ID: ${expense.id}', name: 'ExpenseProvider');
    } catch (e) {
      developer.log('Error updating expense: $e', name: 'ExpenseProvider', error: e);
      rethrow;
    }
  }

  Future<void> deleteExpense(int id) async {
    developer.log('Deleting expense with ID: $id', name: 'ExpenseProvider');
    try {
      final db = await _dbHelper.database; // ใช้ _dbHelper
      await db.delete(
        DatabaseHelper.expenseTable,
        where: '${DatabaseHelper.expenseId} = ?',
        whereArgs: [id],
      );
      _expenses.removeWhere((expense) => expense.id == id);
      notifyListeners();
      developer.log('Expense deleted with ID: $id', name: 'ExpenseProvider');
    } catch (e) {
      developer.log('Error deleting expense: $e', name: 'ExpenseProvider', error: e);
      rethrow;
    }
  }

  Future<void> fetchExpenses() async {
    developer.log('Fetching all expenses...', name: 'ExpenseProvider');
    try {
      final db = await _dbHelper.database; // ใช้ _dbHelper
      final List<Map<String, dynamic>> expenseMaps = await db.rawQuery('''
        SELECT
          e.${DatabaseHelper.expenseId} AS id,
          e.${DatabaseHelper.expenseAmount} AS amount,
          e.${DatabaseHelper.expenseDate} AS date,
          e.${DatabaseHelper.expenseCategoryId} AS categoryId,
          e.${DatabaseHelper.expenseDescription} AS description,
          e.${DatabaseHelper.expenseImage} AS imagePath,
          e.${DatabaseHelper.expensePayerId} AS payerId,
          c.${DatabaseHelper.categoryName} AS categoryName,
          p.${DatabaseHelper.payerName} AS payerName
        FROM ${DatabaseHelper.expenseTable} AS e
        LEFT JOIN ${DatabaseHelper.categoryTable} AS c
          ON e.${DatabaseHelper.expenseCategoryId} = c.${DatabaseHelper.categoryId}
        LEFT JOIN ${DatabaseHelper.payerTable} AS p
          ON e.${DatabaseHelper.expensePayerId} = p.${DatabaseHelper.payerId}
        ORDER BY e.${DatabaseHelper.expenseDate} DESC
      ''');

      _expenses = expenseMaps.map((item) => Expense.fromMap(item)).toList();
      notifyListeners();
      developer.log('Fetched ${_expenses.length} expenses.', name: 'ExpenseProvider');
    } catch (e) {
      developer.log('Error fetching expenses: $e', name: 'ExpenseProvider', error: e);
      // อาจจะโยน exception หรือจัดการ error ที่เหมาะสมกว่านี้
    }
  }

  Future<List<Map<String, dynamic>>> getDatesWithExpensesForMonth(int year, int month) async {
    developer.log('Getting dates with expenses for month: $month/$year', name: 'ExpenseProvider');
    try {
      final db = await _dbHelper.database; // ใช้ _dbHelper
      final DateTime startOfMonth = DateTime(year, month, 1);
      final DateTime endOfMonth = DateTime(year, month + 1, 0).endOfDay;

      final List<Map<String, dynamic>> results = await db.rawQuery('''
        SELECT DISTINCT
          strftime('%Y-%m-%d', ${DatabaseHelper.expenseDate}) AS expenseDay
        FROM ${DatabaseHelper.expenseTable}
        WHERE ${DatabaseHelper.expenseDate} BETWEEN ? AND ?
      ''', [
        startOfMonth.toIso8601String(),
        endOfMonth.toIso8601String(),
      ]);

      developer.log('Found ${results.length} distinct dates with expenses.', name: 'ExpenseProvider');
      return results;
    } catch (e) {
      developer.log('Error getting dates with expenses: $e', name: 'ExpenseProvider', error: e);
      return [];
    }
  }

  Future<List<int>> getAvailableExpenseYears() async {
    developer.log('Fetching available expense years...', name: 'ExpenseProvider');
    try {
      final years = await _dbHelper.getDistinctExpenseYears();
      return years;
    } catch (e) {
      developer.log('Error fetching available expense years: $e', name: 'ExpenseProvider', error: e);
      return [];
    }
  }
}