class Expense {
  final int? id;
  final double amount;
  final DateTime date;
  final int? categoryId; // Category ID (FK)
  final String description;
  final String? imagePath;
  final int? payerId; // ID ของผู้จ่าย (FK)
  final String? payerName; // ชื่อผู้จ่าย (สำหรับแสดงผล)
  final String? categoryName; // ชื่อหมวดหมู่ (สำหรับแสดงผล)
  final String paymentType;

  Expense({
    this.id,
    required this.amount,
    required this.date,
    this.categoryId,
    required this.description,
    this.imagePath,
    this.payerId,
    this.payerName,
    this.categoryName,
    required this.paymentType,    
  });

  factory Expense.fromMap(Map<String, dynamic> map) {
    return Expense(
      id: map['id'] as int?,
      amount: (map['amount'] as num).toDouble(),  // <-- แก้ตรงนี้
      date: DateTime.parse(map['date'] as String),
      categoryId: map['categoryId'] as int?,
      description: map['description'] as String,
      imagePath: map['imagePath'] as String?,
      payerId: map['payerId'] as int?,
      payerName: map['payerName'] as String?,
      categoryName: map['categoryName'] as String?,
      paymentType: map['paymentType'] as String,
    );
  }

  /// แปลง Expense object เป็น Map (สำหรับบันทึกลงฐานข้อมูล)
  ///
  /// จะไม่รวม payerName และ categoryName เนื่องจากเป็นข้อมูลที่ได้จากการ JOIN
  /// ไม่ได้จัดเก็บในตาราง expenses โดยตรง
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'amount': amount,
      'date': date.toIso8601String(),
      'categoryId': categoryId,
      'description': description,
      'imagePath': imagePath,
      'payerId': payerId,
      'paymentType': paymentType,      
    };
  }

  @override
  String toString() {
    return 'Expense(id: $id, amount: $amount, date: $date, categoryId: $categoryId, description: $description, imagePath: $imagePath, payerId: $payerId, payerName: $payerName, categoryName: $categoryName, paymentType: $paymentType)';
  }
}