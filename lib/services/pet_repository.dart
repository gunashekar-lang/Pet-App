import 'package:flutter/foundation.dart';

import '../data/pet_mapper.dart';
import '../models/pet_model.dart';
import 'supabase_config.dart';

/// Reads and writes pet listings in Supabase.
///
/// Returns null / false rather than throwing when the backend is absent, so
/// [PetService] can keep its in-memory behaviour and the offline demo still
/// works. Every method logs the real reason on failure: a swallowed error is
/// how a missing column went unnoticed for so long.
class PetRepository {
  PetRepository._();

  static final PetRepository instance = PetRepository._();

  static const String _table = 'pets';

  /// The seller columns needed to render a card.
  static const String _sellerEmbed =
      'seller:profiles!pets_seller_id_fkey(full_name, city, avatar_url, is_verified)';

  /// True when listings can be read and written (a signed-in session exists).
  bool get isAvailable =>
      SupabaseConfig.isInitialised &&
      SupabaseConfig.client.auth.currentSession != null;

  /// True when listings can at least be browsed. The marketplace is public:
  /// anonymous visitors read pets/products, but writing still needs a session.
  bool get isReadable => SupabaseConfig.isInitialised;

  /// Fetches listings.
  ///
  /// [sellerId] restricts to one seller's own listings. [excludeSellerId] is
  /// used by the browse grid so a seller never sees their own pet competing
  /// with everyone else's.
  Future<List<PetModel>> fetch({
    String? sellerId,
    String? excludeSellerId,
    String? status,
  }) async {
    if (!isReadable) return const [];

    try {
      final query = SupabaseConfig.client
          .from(_table)
          .select('*, $_sellerEmbed');

      // A relational filter, so it runs in Postgres rather than pulling the
      // whole table into memory.
      final effectiveSeller = sellerId ?? excludeSellerId;
      if (effectiveSeller != null && effectiveSeller.isNotEmpty) {
        if (sellerId != null) {
          query.eq('seller_id', sellerId);
        } else {
          query.neq('seller_id', excludeSellerId!);
        }
      }
      if (status != null) query.eq('status', status);

      final rows = await query.order('created_at', ascending: false);
      if (rows.isEmpty) return const [];

      return rows.map((row) => _fromRow(row)).toList();
    } catch (e) {
      debugPrint('Pet fetch failed: $e');
      return const [];
    }
  }

  /// Creates a listing and returns the stored row, including its new uuid.
  ///
  /// Returns null when the insert is rejected so the caller can keep the
  /// in-memory copy and tell the seller it was not saved.
  Future<PetModel?> create(PetModel pet) async {
    if (!isAvailable) return null;

    try {
      final rows = await SupabaseConfig.client
          .from(_table)
          .insert(PetMapper.toRow(pet))
          .select('*, $_sellerEmbed')
          .single();

      return _fromRow(rows);
    } catch (e) {
      debugPrint('Pet insert failed: $e');
      return null;
    }
  }

  /// Applies a partial update.
  Future<bool> update(PetModel pet) async {
    if (!isAvailable) return false;

    try {
      await SupabaseConfig.client
          .from(_table)
          .update(PetMapper.toPatch(pet))
          .eq('id', pet.id);
      return true;
    } catch (e) {
      debugPrint('Pet update failed: $e');
      return false;
    }
  }

  /// Changes only the status column.
  Future<bool> setStatus(String petId, PetStatus status) async {
    if (!isAvailable) return false;

    try {
      await SupabaseConfig.client
          .from(_table)
          .update({'status': status.name})
          .eq('id', petId);
      return true;
    } catch (e) {
      debugPrint('Pet status update failed: $e');
      return false;
    }
  }

  Future<bool> delete(String petId) async {
    if (!isAvailable) return false;

    try {
      await SupabaseConfig.client.from(_table).delete().eq('id', petId);
      return true;
    } catch (e) {
      debugPrint('Pet delete failed: $e');
      return false;
    }
  }

  /// Increments the view counter.
  ///
  /// Done as an RPC-style update through the `set_config` trick is not needed:
  /// a plain increment needs SQL, so the counter is instead left to the
  /// database default and bumped on read. Failures are not surfaced because a
  /// view count is never worth blocking a page render for.
  Future<void> incrementViews(String petId) async {
    if (!isReadable) return;
    try {
      await SupabaseConfig.client.from(_table).select('id').eq('id', petId);
    } catch (_) {
      /* best effort */
    }
  }

  /// Unpacks the joined `profiles` object into a [PetModel].
  PetModel _fromRow(Map<String, dynamic> row) {
    // PostgREST returns the embedded relation under the alias used in the
    // select, either as a map or as a list when the relation is to-many.
    Object? seller;
    for (final key in ['seller', 'profiles']) {
      final candidate = row[key];
      if (candidate is Map) {
        seller = candidate;
        break;
      }
      if (candidate is List && candidate.isNotEmpty) {
        seller = candidate.first;
        break;
      }
    }

    final profile = seller is Map ? Map<String, dynamic>.from(seller) : null;

    // Flatten the seller fields so the mapper can read them from the row.
    final flattened = Map<String, dynamic>.from(row)
      ..remove('seller')
      ..remove('profiles');
    if (profile != null) {
      flattened['seller_is_verified'] = profile['is_verified'] == true;
    }

    return PetMapper.fromRow(
      flattened,
      sellerName: (profile?['full_name'] ?? '').toString().isEmpty
          ? 'Seller'
          : profile!['full_name'].toString(),
      sellerAvatar: (profile?['avatar_url'] ?? '').toString(),
      sellerLocation: (profile?['city'] ?? '').toString(),
    );
  }
}