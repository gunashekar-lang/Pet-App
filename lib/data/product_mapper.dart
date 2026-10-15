import '../models/pet_model.dart';
import '../models/product_model.dart';

/// Converts a [ProductModel] to and from a `public.products` row.
///
/// Mirrors [PetMapper]: the column names live in exactly one place and stay in
/// snake_case, so camelCase never leaks into SQL. The names must match
/// `supabase/schema.sql`.
class ProductMapper {
  ProductMapper._();

  /// Row for an INSERT. `id` and `created_at` are omitted so Postgres owns
  /// them.
  static Map<String, dynamic> toRow(ProductModel product) => {
    'name': product.name,
    'brand': product.brand,
    'category': product.category.name,
    'price': product.price,
    'old_price': product.oldPrice,
    'image_url': product.imageUrl,
    'description': product.description,
    'highlights': product.highlights,
    'stock': product.stock,
    'sold_count': product.soldCount,
    'is_featured': product.isFeatured,
    'is_best_seller': product.isBestSeller,
    'free_shipping': product.freeShipping,
    'species_tags': product.speciesTags.map((s) => s.name).toList(),
    'seller_id': product.sellerId,
    'shop_name': product.shopName,
    'shop_verified': product.shopVerified,
    'rating': product.rating,
    'review_count': product.reviewCount,
  };

  /// Patch sent when a product changes. Deliberately excludes ownership and
  /// audit columns.
  static Map<String, dynamic> toPatch(ProductModel product) => {
    'name': product.name,
    'price': product.price,
    'stock': product.stock,
    'description': product.description,
    'image_url': product.imageUrl,
  };

  static ProductModel fromRow(Map<String, dynamic> row) => ProductModel(
    id: (row['id'] ?? '').toString(),
    name: (row['name'] ?? '').toString(),
    brand: (row['brand'] ?? '').toString(),
    category: ProductCategory.values.firstWhere(
      (c) => c.name == row['category'],
      orElse: () => ProductCategory.accessories,
    ),
    price: (row['price'] as num?)?.toDouble() ?? 0,
    oldPrice: (row['old_price'] as num?)?.toDouble(),
    imageUrl: (row['image_url'] ?? '').toString(),
    rating: (row['rating'] as num?)?.toDouble() ?? 4.5,
    reviewCount: (row['review_count'] as num?)?.toInt() ?? 0,
    description: (row['description'] ?? '').toString(),
    highlights: _stringList(row['highlights']),
    stock: (row['stock'] as num?)?.toInt() ?? 0,
    soldCount: (row['sold_count'] as num?)?.toInt() ?? 0,
    isFeatured: row['is_featured'] == true,
    isBestSeller: row['is_best_seller'] == true,
    freeShipping: row['free_shipping'] != false,
    speciesTags: _speciesOf(row['species_tags']),
    sellerId: (row['seller_id'] ?? '').toString(),
    shopName: (row['shop_name'] ?? '').toString(),
    shopVerified: row['shop_verified'] == true,
  );

  static List<String> _stringList(Object? value) {
    if (value is List) return value.map((e) => e.toString()).toList();
    return const [];
  }

  static List<PetSpecies> _speciesOf(Object? value) {
    if (value is! List) return const [];
    return value
        .map((e) => PetSpecies.values.firstWhere(
              (s) => s.name == e.toString(),
              orElse: () => PetSpecies.other,
            ))
        .toList();
  }
}