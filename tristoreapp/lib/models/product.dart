class ProductTag {
  const ProductTag({required this.id, required this.name});
  final String id;
  final String name;

  factory ProductTag.fromJson(Map<String, dynamic> json) {
    return ProductTag(
      id: json['id'] as String,
      name: json['name'] as String,
    );
  }
}

class Product {
  const Product({
    required this.id,
    required this.code,
    required this.name,
    required this.description,
    required this.images,
    required this.quantity,
    this.sellingPrice = 0,
    required this.tags,
    required this.createdAt,
    required this.updatedAt,
    this.lastContentUpdatedAt,
    this.lastQuantityUpdatedAt,
  });

  final String id;
  final String code;
  final String name;
  final String description;
  final List<String> images;
  final int quantity;
  /// Giá bán (đồng).
  final int sellingPrice;
  final List<ProductTag> tags;
  final DateTime createdAt;
  final DateTime updatedAt;
  /// Lần đổi mã/tên/mô tả/ảnh/thẻ (null nếu API không có / bản ghi cũ).
  final DateTime? lastContentUpdatedAt;
  /// Lần đổi số lượng (null nếu không có).
  final DateTime? lastQuantityUpdatedAt;

  factory Product.fromJson(Map<String, dynamic> json) {
    final imgs = json['images'];
    final images = imgs is List
        ? imgs.map((e) => e.toString()).where((s) => s.isNotEmpty).toList()
        : <String>[];
    final tagList = json['tags'];
    final tags = tagList is List
        ? tagList
            .map((e) => ProductTag.fromJson(e as Map<String, dynamic>))
            .toList()
        : <ProductTag>[];
    DateTime? parseOpt(String? s) {
      if (s == null || s.isEmpty) return null;
      return DateTime.tryParse(s);
    }

    return Product(
      id: json['id'] as String,
      code: json['code'] as String,
      name: json['name'] as String,
      description: (json['description'] as String?) ?? '',
      images: images,
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      sellingPrice: (json['sellingPrice'] as num?)?.toInt() ?? 0,
      tags: tags,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      lastContentUpdatedAt: parseOpt(json['lastContentUpdatedAt'] as String?),
      lastQuantityUpdatedAt: parseOpt(json['lastQuantityUpdatedAt'] as String?),
    );
  }
}
