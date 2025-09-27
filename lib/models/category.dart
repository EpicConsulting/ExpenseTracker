class Category {
  final int? id;
  final String name;
  final int? color; // *** เพิ่ม: Field สำหรับเก็บค่าสีของหมวดหมู่ (ARGB int value) ***

  Category({
    this.id,
    required this.name,
    this.color, // *** เพิ่ม: ใน Constructor ***
  });

  // Convert a Category object into a Map object
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'color': color, // *** เพิ่ม: ใน toMap() ***
    };
  }

  // Convert a Map object into a Category object
  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id'] as int?,
      name: map['name'] as String,
      color: map['color'] as int?, // *** เพิ่ม: ใน fromMap() ***
    );
  }
}