// lib/providers/payer_provider.dart
import 'package:flutter/material.dart';
import 'dart:developer' as developer; // สำหรับ logging
import '../models/payer.dart';
import '../services/database_helper.dart';
import 'package:sqflite/sqflite.dart' as sql; // เพิ่ม import นี้ด้วย ถ้าใช้ sql.ConflictAlgorithm

class PayerProvider with ChangeNotifier {
  List<Payer> _payers = [];

  List<Payer> get payers {
    return [..._payers];
  }

  // Constructor ของ Provider
  // จะเรียก fetchPayers ทันทีที่ Provider ถูกสร้างขึ้นมา
  PayerProvider() {
    developer.log('PayerProvider initialized. Fetching payers...', name: 'PayerProvider');
    fetchPayers(); // เรียก fetch Payers ทันทีที่ Provider ถูกสร้าง
  }

  // เมธอดสำหรับโหลด Payer ทั้งหมดจากฐานข้อมูล
  Future<void> fetchPayers() async {
    developer.log('Fetching all payers...', name: 'PayerProvider');
    try {
      final db = await DatabaseHelper().database;
      final List<Map<String, dynamic>> payerMaps = await db.query(DatabaseHelper.payerTable);

      _payers = payerMaps.map((item) => Payer.fromMap(item)).toList();
      notifyListeners(); // แจ้งเตือนผู้ฟัง (Widgets) ให้ rebuild
      developer.log('Fetched ${_payers.length} payers.', name: 'PayerProvider');
    } catch (e) {
      developer.log('Error fetching payers: $e', name: 'PayerProvider', error: e);
      // อาจจะจัดการ error ที่เหมาะสมกว่านี้
    }
  }

  // ฟังก์ชันสำหรับเพิ่ม Payer
  Future<void> addPayer(Payer payer) async {
    developer.log('Adding new payer: ${payer.name}', name: 'PayerProvider');
    try {
      final db = await DatabaseHelper().database;
      final id = await db.insert(
        DatabaseHelper.payerTable,
        payer.toMap(),
        conflictAlgorithm: sql.ConflictAlgorithm.abort, // หรือ .replace ตามที่คุณต้องการ
      );
      final newPayer = Payer(id: id, name: payer.name);
      _payers.add(newPayer);
      notifyListeners();
      developer.log('Payer added with ID: $id', name: 'PayerProvider');
    } catch (e) {
      developer.log('Error adding payer: $e', name: 'PayerProvider', error: e);
      rethrow;
    }
  }

  // ฟังก์ชันสำหรับอัปเดต Payer
  Future<void> updatePayer(Payer payer) async {
    developer.log('Updating payer with ID: ${payer.id}', name: 'PayerProvider');
    try {
      final db = await DatabaseHelper().database;
      await db.update(
        DatabaseHelper.payerTable,
        payer.toMap(),
        where: '${DatabaseHelper.payerId} = ?',
        whereArgs: [payer.id],
        conflictAlgorithm: sql.ConflictAlgorithm.abort,
      );
      final payerIndex = _payers.indexWhere((p) => p.id == payer.id);
      if (payerIndex >= 0) {
        _payers[payerIndex] = payer;
      }
      notifyListeners();
      developer.log('Payer updated with ID: ${payer.id}', name: 'PayerProvider');
    } catch (e) {
      developer.log('Error updating payer: $e', name: 'PayerProvider', error: e);
      rethrow;
    }
  }

  // ฟังก์ชันสำหรับลบ Payer
  Future<void> deletePayer(int id) async {
    developer.log('Deleting payer with ID: $id', name: 'PayerProvider');
    try {
      final db = await DatabaseHelper().database;
      await db.delete(
        DatabaseHelper.payerTable,
        where: '${DatabaseHelper.payerId} = ?',
        whereArgs: [id],
      );
      _payers.removeWhere((payer) => payer.id == id);
      notifyListeners();
      developer.log('Payer deleted with ID: $id', name: 'PayerProvider');
    } catch (e) {
      developer.log('Error deleting payer: $e', name: 'PayerProvider', error: e);
      rethrow;
    }
  }
}