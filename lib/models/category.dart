class Category {
  final int? id;
  final String name;
  final int? color;

  Category({
    this.id,
    required this.name,
    this.color,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'color': color,
    };
  }

  factory Category.fromMap(Map<String, dynamic> map) {
    final rawColor = map['color'] as int?;
    return Category(
      id: map['id'] as int?,
      name: map['name'] as String,
      color: (rawColor == null || rawColor == 0) ? null : rawColor,
    );
  }
}