import 'package:flutter/material.dart';

import 'pet_model.dart';

enum ProductCategory {
  food,
  treats,
  toys,
  grooming,
  health,
  bedding,
  apparel,
  accessories,
  walking,
}

extension ProductCategoryX on ProductCategory {
  String get label => switch (this) {
    ProductCategory.food => 'Food',
    ProductCategory.treats => 'Treats',
    ProductCategory.toys => 'Toys',
    ProductCategory.grooming => 'Grooming',
    ProductCategory.health => 'Health',
    ProductCategory.bedding => 'Bedding',
    ProductCategory.apparel => 'Apparel',
    ProductCategory.accessories => 'Accessories',
    ProductCategory.walking => 'Walking',
  };

  IconData get icon => switch (this) {
    ProductCategory.food => Icons.restaurant_rounded,
    ProductCategory.treats => Icons.cookie_rounded,
    ProductCategory.toys => Icons.sports_baseball_rounded,
    ProductCategory.grooming => Icons.content_cut_rounded,
    ProductCategory.health => Icons.medical_services_rounded,
    ProductCategory.bedding => Icons.bed_rounded,
    ProductCategory.apparel => Icons.checkroom_rounded,
    ProductCategory.accessories => Icons.watch_rounded,
    ProductCategory.walking => Icons.directions_walk_rounded,
  };
}

@immutable
class ProductModel {
  const ProductModel({
    required this.id,
    required this.name,
    required this.brand,
    required this.category,
    required this.price,
    required this.imageUrl,
    this.oldPrice,
    this.rating = 4.5,
    this.reviewCount = 0,
    this.description = '',
    this.highlights = const [],
    this.stock = 20,
    this.soldCount = 0,
    this.isFeatured = false,
    this.isBestSeller = false,
    this.freeShipping = true,
    this.speciesTags = const [],
    this.sellerId = '',
    this.shopName = '',
    this.shopVerified = false,
  });

  final String id;
  final String name;
  final String brand;
  final ProductCategory category;
  final double price;
  final double? oldPrice;
  final String imageUrl;
  final double rating;
  final int reviewCount;
  final String description;
  final List<String> highlights;
  final int stock;
  final int soldCount;
  final bool isFeatured;
  final bool isBestSeller;
  final bool freeShipping;
  final List<PetSpecies> speciesTags;

  /// Owner of the listing. Empty for platform/stock products; set to the
  /// current user id for anything published through Sell a Product.
  final String sellerId;

  /// Shop the product belongs to, shown on the product card and details page.
  final String shopName;

  /// Whether the selling shop has completed verification.
  final bool shopVerified;

  /// True when the signed-in user owns this listing.
  bool ownedBy(String userId) => sellerId.isNotEmpty && sellerId == userId;

  /// True when the listing comes from a verified shop.
  bool get isVerifiedShopListing => shopVerified && shopName.isNotEmpty;

  bool get inStock => stock > 0;
  bool get isLowStock => stock > 0 && stock <= 5;
  bool get onSale => oldPrice != null && oldPrice! > price;

  int get discountPercent => onSale
      ? (((oldPrice! - price) / oldPrice!) * 100).round().clamp(1, 90)
      : 0;

  ProductModel copyWith({
    int? stock,
    int? soldCount,
    double? price,
    String? shopName,
    bool? shopVerified,
  }) {
    return ProductModel(
      id: id,
      name: name,
      brand: brand,
      category: category,
      price: price ?? this.price,
      oldPrice: oldPrice,
      imageUrl: imageUrl,
      rating: rating,
      reviewCount: reviewCount,
      description: description,
      highlights: highlights,
      stock: stock ?? this.stock,
      soldCount: soldCount ?? this.soldCount,
      isFeatured: isFeatured,
      isBestSeller: isBestSeller,
      freeShipping: freeShipping,
      speciesTags: speciesTags,
      sellerId: sellerId,
      shopName: shopName ?? this.shopName,
      shopVerified: shopVerified ?? this.shopVerified,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'brand': brand,
    'category': category.name,
    'price': price,
    'imageUrl': imageUrl,
    'stock': stock,
    'sellerId': sellerId,
    'shopName': shopName,
    'shopVerified': shopVerified,
  };

  factory ProductModel.fromMap(Map<String, dynamic> map) => ProductModel(
    id: map['id'] as String,
    name: map['name'] as String,
    brand: map['brand'] as String? ?? 'PetHub',
    category: ProductCategory.values.firstWhere(
      (c) => c.name == map['category'],
      orElse: () => ProductCategory.accessories,
    ),
    price: (map['price'] as num?)?.toDouble() ?? 0,
    imageUrl: map['imageUrl'] as String? ?? '',
    stock: (map['stock'] as num?)?.toInt() ?? 0,
    sellerId: map['sellerId'] as String? ?? '',
    shopName: map['shopName'] as String? ?? '',
    shopVerified: map['shopVerified'] as bool? ?? false,
  );
}

/// A single line item inside the cart.
@immutable
class CartItem {
  const CartItem({required this.product, this.quantity = 1});

  final ProductModel product;
  final int quantity;

  double get total => product.price * quantity;

  CartItem copyWith({int? quantity}) =>
      CartItem(product: product, quantity: quantity ?? this.quantity);

  Map<String, dynamic> toMap() => {
    'productId': product.id,
    'quantity': quantity,
  };
}
