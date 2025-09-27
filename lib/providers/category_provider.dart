// lib/providers/category_provider.dart
import 'package:flutter/material.dart';
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
      print('Categories fetched: ${_categories.length} items');
    } catch (e) {
      print('Error fetching categories: $e');
    }
  }

  // ปรับปรุงให้รับ Category object ที่มี color ด้วย
  Future<void> addCategory(Category category) async {
    try {
      await _dbHelper.insertCategory(category.toMap());
      print('Category added: ${category.name}');
      await fetchCategories(); // รีเฟรชข้อมูลหลังจากเพิ่ม
    } catch (e) {
      print('Error adding category: $e');
      rethrow;
    }
  }

  Future<void> deleteCategory(int id) async {
    try {
      await _dbHelper.deleteCategory(id);
      print('Category deleted with ID: $id');
      await fetchCategories(); // รีเฟรชข้อมูลหลังจากลบ
    } catch (e) {
      print('Error deleting category: $e');
      rethrow;
    }
  }

  // ปรับปรุงการเรียก _dbHelper.updateCategory ให้ตรงกับ signature ของ DatabaseHelper
  Future<void> updateCategory(int id, String newName, {int? newColor}) async {
    try {
      // ไม่ต้องสร้าง updatedCategory object แล้วส่ง toMap
      // ให้ส่งค่า id, newName, newColor ไปตรงๆ
      await _dbHelper.updateCategory(id, newName, newColor);
      print('Category updated: ID=$id, New Name=$newName, New Color=$newColor');
      await fetchCategories(); // รีเฟรชข้อมูลหลังจากอัปเดต
    } catch (e) {
      print('Error updating category: $e');
      rethrow;
    }
  }
}