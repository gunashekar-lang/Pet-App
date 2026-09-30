import 'package:flutter/material.dart';

/// A category used across the marketplace and the store.
enum CategoryType { pet, product, service }

@immutable
class CategoryModel {
  const CategoryModel({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    this.type = CategoryType.pet,
    this.subtitle,
  });

  final String id;
  final String name;
  final IconData icon;
  final Color color;
  final CategoryType type;
  final String? subtitle;

  CategoryModel copyWith({String? name, IconData? icon, Color? color}) {
    return CategoryModel(
      id: id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      type: type,
      subtitle: subtitle,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is CategoryModel && other.id == id && other.type == type;

  @override
  int get hashCode => Object.hash(id, type);
}

/// Pet species / breed groupings.
enum PetSpecies { dog, cat, bird, rabbit, fish, reptile, smallPet, other }

extension PetSpeciesX on PetSpecies {
  String get label => switch (this) {
    PetSpecies.dog => 'Dog',
    PetSpecies.cat => 'Cat',
    PetSpecies.bird => 'Bird',
    PetSpecies.rabbit => 'Rabbit',
    PetSpecies.fish => 'Fish',
    PetSpecies.reptile => 'Reptile',
    PetSpecies.smallPet => 'Small Pet',
    PetSpecies.other => 'Other',
  };

  IconData get icon => switch (this) {
    PetSpecies.dog => Icons.pets_rounded,
    PetSpecies.cat => Icons.pets_rounded,
    PetSpecies.bird => Icons.flutter_dash_rounded,
    PetSpecies.rabbit => Icons.cruelty_free_rounded,
    PetSpecies.fish => Icons.water_rounded,
    PetSpecies.reptile => Icons.eco_rounded,
    PetSpecies.smallPet => Icons.radar_rounded,
    PetSpecies.other => Icons.category_rounded,
  };
}

/// Listing condition for a pet.
enum PetCondition { newArrival, excellent, good, needsCare }

extension PetConditionX on PetCondition {
  String get label => switch (this) {
    PetCondition.newArrival => 'New arrival',
    PetCondition.excellent => 'Excellent',
    PetCondition.good => 'Good',
    PetCondition.needsCare => 'Needs care',
  };
}

/// Listing / order status for a pet sale.
enum PetStatus { available, reserved, sold, pending }

extension PetStatusX on PetStatus {
  String get label => switch (this) {
    PetStatus.available => 'Available',
    PetStatus.reserved => 'Reserved',
    PetStatus.sold => 'Sold',
    PetStatus.pending => 'Under review',
  };
}

/// Age bracket used in filters and listings.
enum PetAge { puppy, young, adult, senior }

extension PetAgeX on PetAge {
  String get label => switch (this) {
    PetAge.puppy => 'Puppy',
    PetAge.young => 'Young',
    PetAge.adult => 'Adult',
    PetAge.senior => 'Senior',
  };

  /// Representative age used when a seller picks a bracket.
  int get monthsApprox => switch (this) {
    PetAge.puppy => 5,
    PetAge.young => 18,
    PetAge.adult => 48,
    PetAge.senior => 108,
  };
}

@immutable
class SellerModel {
  const SellerModel({
    required this.id,
    required this.name,
    required this.avatarUrl,
    this.rating = 4.8,
    this.reviewCount = 0,
    this.location = '',
    this.verified = false,
    this.memberSince,
    this.phone,
    this.responseTime = 'Usually replies within an hour',
  });

  final String id;
  final String name;
  final String avatarUrl;
  final double rating;
  final int reviewCount;
  final String location;
  final bool verified;
  final DateTime? memberSince;
  final String? phone;
  final String responseTime;
}

/// A single vaccination record captured when a pet is listed.
@immutable
class VaccinationRecord {
  const VaccinationRecord({
    required this.name,
    required this.dateGiven,
    this.nextDue,
    this.vetName = '',
    this.notes = '',
  });

  final String name;
  final DateTime dateGiven;
  final DateTime? nextDue;
  final String vetName;
  final String notes;

  bool get isOverdue => nextDue != null && nextDue!.isBefore(DateTime.now());

  String get formattedDate => _format(dateGiven);
  String? get formattedNextDue => nextDue == null ? null : _format(nextDue!);

  static String _format(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  Map<String, dynamic> toMap() => {
    'name': name,
    'dateGiven': dateGiven.toIso8601String(),
    'nextDue': nextDue?.toIso8601String(),
    'vetName': vetName,
    'notes': notes,
  };
}

/// A pet listing — the core entity of the marketplace.
@immutable
class PetModel {
  const PetModel({
    required this.id,
    required this.name,
    required this.species,
    required this.breed,
    required this.age,
    required this.gender,
    required this.price,
    required this.imageUrls,
    required this.seller,
    required this.description,
    this.ageInMonths = 12,
    this.vaccinated = true,
    this.dewormed = true,
    this.healthChecked = true,
    this.microchipped = false,
    this.neutered = false,
    this.vaccineDetails = '',
    this.vaccinations = const [],
    this.healthIssues = '',
    this.location = '',
    this.status = PetStatus.available,
    this.condition = PetCondition.excellent,
    this.isFeatured = false,
    this.isVerified = true,
    this.negotiable = true,
    this.tags = const [],
    this.createdAt,
    this.views = 0,
    this.favoriteCount = 0,
    this.ownerId = '',
  });

  final String id;
  final String name;
  final PetSpecies species;
  final String breed;
  final int ageInMonths;
  final PetAge age;
  final String gender;
  final double price;
  final List<String> imageUrls;
  final SellerModel seller;
  final String description;
  final bool vaccinated;
  final bool dewormed;
  final bool healthChecked;
  final bool microchipped;
  final bool neutered;
  final String vaccineDetails;

  /// Structured vaccination history entered by the seller.
  final List<VaccinationRecord> vaccinations;

  /// Free-text health notes from the seller — known conditions, allergies,
  /// medication, or "None known".
  final String healthIssues;

  final String location;
  final PetStatus status;
  final PetCondition condition;
  final bool isFeatured;
  final bool isVerified;
  final bool negotiable;
  final List<String> tags;
  final DateTime? createdAt;
  final int views;
  final int favoriteCount;
  final String ownerId;

  String get image => imageUrls.isEmpty ? '' : imageUrls.first;

  String get ageLabel {
    if (ageInMonths < 12) return '$ageInMonths months';
    final years = ageInMonths ~/ 12;
    final months = ageInMonths % 12;
    if (months == 0) return '$years ${years == 1 ? 'year' : 'years'}';
    return '$years ${years == 1 ? 'yr' : 'yrs'} $months mo';
  }

  /// True when the seller recorded at least one vaccination.
  bool get hasVaccinations => vaccinations.isNotEmpty;

  /// True when the seller flagged a known health issue.
  bool get hasHealthIssues =>
      healthIssues.trim().isNotEmpty &&
      healthIssues.trim().toLowerCase() != 'none known';

  /// Health score (0-100) derived from the recorded care history. Based on the
  /// vaccination log and whether any health issue was disclosed.
  int get healthScore {
    var score = 55;
    if (hasVaccinations) score += 35;
    if (!hasHealthIssues) score += 10;
    return score.clamp(0, 100);
  }

  List<(IconData, String)> get healthHighlights => [
    if (hasVaccinations)
      (
        Icons.vaccines_rounded,
        vaccinations.length == 1
            ? '1 vaccination'
            : '${vaccinations.length} vaccinations',
      ),
    if (hasHealthIssues)
      (Icons.medical_information_rounded, 'Health issue noted'),
    if (!hasHealthIssues && !hasVaccinations)
      (Icons.info_outline_rounded, 'No health info shared'),
  ];

  PetModel copyWith({
    String? name,
    double? price,
    PetStatus? status,
    bool? isFeatured,
    String? description,
    List<String>? imageUrls,
    int? views,
    int? favoriteCount,
    PetCondition? condition,
    List<VaccinationRecord>? vaccinations,
    String? healthIssues,
  }) {
    return PetModel(
      id: id,
      name: name ?? this.name,
      species: species,
      breed: breed,
      age: age,
      gender: gender,
      price: price ?? this.price,
      imageUrls: imageUrls ?? this.imageUrls,
      seller: seller,
      description: description ?? this.description,
      ageInMonths: ageInMonths,
      vaccinated: vaccinated,
      dewormed: dewormed,
      healthChecked: healthChecked,
      microchipped: microchipped,
      neutered: neutered,
      vaccineDetails: vaccineDetails,
      vaccinations: vaccinations ?? this.vaccinations,
      healthIssues: healthIssues ?? this.healthIssues,
      location: location,
      status: status ?? this.status,
      condition: condition ?? this.condition,
      isFeatured: isFeatured ?? this.isFeatured,
      isVerified: isVerified,
      negotiable: negotiable,
      tags: tags,
      createdAt: createdAt,
      views: views ?? this.views,
      favoriteCount: favoriteCount ?? this.favoriteCount,
      ownerId: ownerId,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'species': species.name,
    'breed': breed,
    'ageInMonths': ageInMonths,
    'gender': gender,
    'price': price,
    'imageUrls': imageUrls,
    'description': description,
    'status': status.name,
    'vaccinations': vaccinations.map((v) => v.toMap()).toList(),
  };

  factory PetModel.fromMap(Map<String, dynamic> map) {
    return PetModel(
      id: map['id'] as String,
      name: map['name'] as String,
      species: PetSpecies.values.firstWhere(
        (s) => s.name == map['species'],
        orElse: () => PetSpecies.other,
      ),
      breed: map['breed'] as String? ?? 'Mixed',
      ageInMonths: (map['ageInMonths'] as num?)?.toInt() ?? 12,
      age: PetAge.adult,
      gender: map['gender'] as String? ?? 'Male',
      price: (map['price'] as num?)?.toDouble() ?? 0,
      imageUrls: List<String>.from(map['imageUrls'] as List? ?? const []),
      seller: SellerModel(id: 'remote', name: 'Seller', avatarUrl: ''),
      description: map['description'] as String? ?? '',
      status: PetStatus.values.firstWhere(
        (s) => s.name == map['status'],
        orElse: () => PetStatus.available,
      ),
      vaccinations: (map['vaccinations'] as List? ?? const [])
          .whereType<Map>()
          .map(
            (e) => VaccinationRecord(
              name: e['name'] as String? ?? 'Vaccination',
              dateGiven:
                  DateTime.tryParse(e['dateGiven'] as String? ?? '') ??
                  DateTime.now(),
              nextDue: DateTime.tryParse(e['nextDue'] as String? ?? ''),
              vetName: e['vetName'] as String? ?? '',
              notes: e['notes'] as String? ?? '',
            ),
          )
          .toList(),
    );
  }
}
