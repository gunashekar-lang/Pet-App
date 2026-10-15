import 'dart:convert';

import '../../models/pet_model.dart';

/// Converts a [PetModel] to and from a `public.pets` row.
///
/// Kept separate from the service so the column names live in exactly one
/// place. The names must match `supabase/pets_backend.sql`; they are snake_case
/// conversions of the Dart field names, one to one.
class PetMapper {
  PetMapper._();

  /// Row for an INSERT. `id` is omitted so Postgres generates it.
  static Map<String, dynamic> toRow(PetModel pet) => {
    'seller_id': pet.ownerId,
    'name': pet.name,
    'species': pet.species.name,
    'breed': pet.breed,
    'age_in_months': pet.ageInMonths,
    'gender': pet.gender,
    'price': pet.price,
    'negotiable': pet.negotiable,
    'image_urls': pet.imageUrls,
    'description': pet.description,
    'location': pet.location,
    'vaccinated': pet.vaccinated,
    'dewormed': pet.dewormed,
    'health_checked': pet.healthChecked,
    'microchipped': pet.microchipped,
    'neutered': pet.neutered,
    'vaccine_details': pet.vaccineDetails,
    'vaccinations': _vaccinationsToJson(pet.vaccinations),
    'health_issues': pet.healthIssues,
    'status': pet.status.name,
    'condition': pet.condition.name,
    'is_featured': pet.isFeatured,
    'tags': pet.tags,
    'views': pet.views,
    'favorite_count': pet.favoriteCount,
  };

  /// Patch for an UPDATE. Only the columns that actually changed are sent, so
  /// two sellers editing different listings cannot clobber each other's fields.
  static Map<String, dynamic> toPatch(PetModel pet) => {
    'name': pet.name,
    'price': pet.price,
    'description': pet.description,
    'image_urls': pet.imageUrls,
    'location': pet.location,
    'health_issues': pet.healthIssues,
    'vaccinations': _vaccinationsToJson(pet.vaccinations),
    'status': pet.status.name,
    'negotiable': pet.negotiable,
  };

  static String _vaccinationsToJson(List<VaccinationRecord> records) =>
      jsonEncode(records.map((v) => v.toMap()).toList());

  /// Builds a model from a row.
  ///
  /// [sellerName] and [sellerAvatar] come from the joined `profiles` row; the
  /// pets table itself only stores the seller id.
  static PetModel fromRow(
    Map<String, dynamic> row, {
    String sellerName = 'Seller',
    String sellerAvatar = '',
    String sellerLocation = '',
  }) {
    final id = (row['id'] ?? '').toString();

    return PetModel(
      id: id,
      name: (row['name'] ?? '').toString(),
      species: _speciesOf(row['species']),
      breed: (row['breed'] ?? '').toString().isEmpty
          ? 'Mixed'
          : row['breed'].toString(),
      ageInMonths: (row['age_in_months'] as num?)?.toInt() ?? 12,
      age: _ageOf((row['age_in_months'] as num?)?.toInt() ?? 12),
      gender: (row['gender'] ?? 'Male').toString(),
      price: (row['price'] as num?)?.toDouble() ?? 0,
      imageUrls: _stringList(row['image_urls']),
      seller: SellerModel(
        id: (row['seller_id'] ?? '').toString(),
        name: sellerName,
        avatarUrl: sellerAvatar,
        location: sellerLocation,
      ),
      description: (row['description'] ?? '').toString(),
      vaccinated: row['vaccinated'] == true,
      dewormed: row['dewormed'] == true,
      healthChecked: row['health_checked'] == true,
      microchipped: row['microchipped'] == true,
      neutered: row['neutered'] == true,
      vaccineDetails: (row['vaccine_details'] ?? '').toString(),
      vaccinations: _vaccinationsFromJson(row['vaccinations']),
      healthIssues: (row['health_issues'] ?? '').toString(),
      location: (row['location'] ?? '').toString(),
      status: _statusOf(row['status']),
      condition: _conditionOf(row['condition']),
      isFeatured: row['is_featured'] == true,
      // The verification badge belongs to the seller, not the listing.
      isVerified: row['seller_is_verified'] == true,
      negotiable: row['negotiable'] == true,
      tags: _stringList(row['tags']),
      createdAt: DateTime.tryParse((row['created_at'] ?? '').toString()),
      views: (row['views'] as num?)?.toInt() ?? 0,
      favoriteCount: (row['favorite_count'] as num?)?.toInt() ?? 0,
      ownerId: (row['seller_id'] ?? '').toString(),
    );
  }

  static List<String> _stringList(Object? value) {
    if (value is List) return value.map((e) => e.toString()).toList();
    return const [];
  }

  static List<VaccinationRecord> _vaccinationsFromJson(Object? value) {
    // Postgres returns jsonb already decoded, but a driver or a cache may hand
    // back the raw string, so accept both.
    List<dynamic> entries = const [];
    if (value is List) {
      entries = value;
    } else if (value is String && value.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is List) entries = decoded;
      } catch (_) {
        return const [];
      }
    }

    return entries.whereType<Map>().map((e) {
      final map = Map<String, dynamic>.from(e);
      return VaccinationRecord(
        name: (map['name'] ?? 'Vaccination').toString(),
        dateGiven:
            DateTime.tryParse((map['dateGiven'] ?? '').toString()) ??
            DateTime.now(),
        nextDue: DateTime.tryParse((map['nextDue'] ?? '').toString()),
        vetName: (map['vetName'] ?? '').toString(),
        notes: (map['notes'] ?? '').toString(),
      );
    }).toList();
  }

  static PetSpecies _speciesOf(Object? value) {
    final name = (value ?? '').toString();
    return PetSpecies.values.firstWhere(
      (s) => s.name == name,
      orElse: () => PetSpecies.other,
    );
  }

  static PetStatus _statusOf(Object? value) {
    final name = (value ?? '').toString();
    return PetStatus.values.firstWhere(
      (s) => s.name == name,
      orElse: () => PetStatus.available,
    );
  }

  static PetCondition _conditionOf(Object? value) {
    final name = (value ?? '').toString();
    return PetCondition.values.firstWhere(
      (c) => c.name == name,
      orElse: () => PetCondition.excellent,
    );
  }

  /// Same bracket logic the sell form uses, kept in one place.
  static PetAge _ageOf(int months) => PetAge.values.firstWhere(
    (bracket) => months <= bracket.monthsApprox + 6,
    orElse: () => PetAge.senior,
  );
}