import 'package:flutter/material.dart';
import 'dart:developer' as developer;
import '../models/category.dart';
import '../services/database_helper.dart';

class CategoryProvider with ChangeNotifier {
  List<Category> _categories = [];
  final DatabaseHelper _dbHelper = DatabaseHelper();

  List<Category> get categories => [..._categories];

  CategoryProvider() {
    fetchCategories();
  }

  Future<void> fetchCategories() async {
    try {
      final dataList = await _dbHelper.getCategories();
      _categories = dataList.map((item) => Category.fromMap(item)).toList();
      notifyListeners();
      developer.log('Categories fetched: ${_categories.length} items', name: 'CategoryProvider');
    } catch (e) {
      developer.log('Error fetching categories: $e', name: 'CategoryProvider', error: e);
    }
  }

  // ปรับปรุงให้รับ Category object ที่มี color ด้วย
  Future<void> addCategory(Category category) async {
    try {
      await _dbHelper.insertCategory(category.toMap());
      developer.log('Category added: ${category.name}', name: 'CategoryProvider');
      await fetchCategories(); // รีเฟรชข้อมูลหลังจากเพิ่ม
    } catch (e) {
      developer.log('Error adding category: $e', name: 'CategoryProvider', error: e);
      rethrow;
    }
  }

  Future<void> deleteCategory(int id) async {
    try {
      await _dbHelper.deleteCategory(id);
      developer.log('Category deleted with ID: $id', name: 'CategoryProvider');
      await fetchCategories(); // รีเฟรชข้อมูลหลังจากลบ
    } catch (e) {
      developer.log('Error deleting category: $e', name: 'CategoryProvider', error: e);
      rethrow;
    }
  }

  // ปรับปรุงการเรียก _dbHelper.updateCategory ให้ตรงกับ signature ของ DatabaseHelper
  Future<void> updateCategory(int id, String newName, {int? newColor}) async {
    try {
      await _dbHelper.updateCategory(id, newName, newColor);
      developer.log('Category updated: ID=$id, New Name=$newName, New Color=$newColor', name: 'CategoryProvider');
      await fetchCategories(); // รีเฟรชข้อมูลหลังจากอัปเดต
    } catch (e) {
      developer.log('Error updating category: $e', name: 'CategoryProvider', error: e);
      rethrow;
    }
  }
}