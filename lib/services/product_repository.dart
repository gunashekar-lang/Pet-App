import 'package:flutter/foundation.dart';

import '../data/product_mapper.dart';
import '../models/product_model.dart';
import 'supabase_config.dart';

/// Reads and writes product listings in Supabase.
///
/// Mirrors [PetRepository]: returns empty / null / false rather than throwing
/// when the backend is absent or the request is rejected, and can keep the
/// in-memory behaviour of [StoreService] intact for the offline demo.
class ProductRepository {
  ProductRepository._();

  static final ProductRepository instance = ProductRepository._();

  static const String _table = 'products';

  /// True when products can be read and written (a signed-in session exists).
  bool get isAvailable =>
      SupabaseConfig.isInitialised &&
      SupabaseConfig.client.auth.currentSession != null;

  /// True when products can at least be browsed. The store is public:
  /// anonymous visitors read the catalogue, but writing still needs a session.
  bool get isReadable => SupabaseConfig.isInitialised;

  /// Fetches product listings.
  ///
  /// [sellerId] restricts to one seller's own products; [excludeSellerId] is
  /// used by the store grid so a seller never sees their own items competing
  /// with everyone else's.
  Future<List<ProductModel>> fetch({
    String? sellerId,
    String? excludeSellerId,
  }) async {
    if (!isReadable) return const [];

    try {
      final query = SupabaseConfig.client.from(_table).select('*');

      final effectiveSeller = sellerId ?? excludeSellerId;
      if (effectiveSeller != null && effectiveSeller.isNotEmpty) {
        if (sellerId != null) {
          query.eq('seller_id', sellerId);
        } else {
          query.neq('seller_id', excludeSellerId!);
        }
      }

      final rows = await query.order('created_at', ascending: false);
      return rows.map((row) => ProductMapper.fromRow(row)).toList();
    } catch (e) {
      debugPrint('Product fetch failed: $e');
      return const [];
    }
  }

  /// Creates a listing and returns the stored row, including its new uuid.
  ///
  /// Returns null when the insert is rejected so the caller can keep the
  /// in-memory copy and tell the seller it was not saved.
  Future<ProductModel?> create(ProductModel draft) async {
    if (!isAvailable) return null;

    try {
      final row = await SupabaseConfig.client
          .from(_table)
          .insert(ProductMapper.toRow(draft))
          .select('*')
          .single();

      return ProductMapper.fromRow(row);
    } catch (e) {
      debugPrint('Product insert failed: $e');
      return null;
    }
  }

  Future<bool> update(ProductModel product) async {
    if (!isAvailable) return false;

    try {
      await SupabaseConfig.client
          .from(_table)
          .update(ProductMapper.toPatch(product))
          .eq('id', product.id);
      return true;
    } catch (e) {
      debugPrint('Product update failed: $e');
      return false;
    }
  }

  /// Records a stock change (e.g. items sold). Narrow update so two sellers
  /// editing different fields cannot clobber each other.
  Future<bool> updateStock(String productId, int newStock) async {
    if (!isAvailable) return false;

    try {
      await SupabaseConfig.client
          .from(_table)
          .update({'stock': newStock})
          .eq('id', productId);
      return true;
    } catch (e) {
      debugPrint('Product stock update failed: $e');
      return false;
    }
  }

  Future<bool> delete(String productId) async {
    if (!isAvailable) return false;

    try {
      await SupabaseConfig.client.from(_table).delete().eq('id', productId);
      return true;
    } catch (e) {
      debugPrint('Product delete failed: $e');
      return false;
    }
  }
}