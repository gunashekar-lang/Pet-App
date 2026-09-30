import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/pet_model.dart';
import '../models/user_model.dart';
import '../utils/constants.dart';

/// Sort options for marketplace results.
enum PetSort { newest, priceLowHigh, priceHighLow, popular }

extension PetSortX on PetSort {
  String get label => switch (this) {
    PetSort.newest => 'Newest first',
    PetSort.priceLowHigh => 'Price: low to high',
    PetSort.priceHighLow => 'Price: high to low',
    PetSort.popular => 'Most popular',
  };
}

/// Active marketplace filters.
class PetFilter {
  const PetFilter({
    this.species = const {},
    this.ages = const {},
    this.genders = const {},
    this.minPrice,
    this.maxPrice,
    this.vaccinatedOnly = false,
    this.verifiedOnly = false,
    this.negotiableOnly = false,
  });

  final Set<PetSpecies> species;
  final Set<PetAge> ages;
  final Set<String> genders;
  final double? minPrice;
  final double? maxPrice;
  final bool vaccinatedOnly;
  final bool verifiedOnly;
  final bool negotiableOnly;

  int get activeCount =>
      species.length +
      ages.length +
      genders.length +
      (minPrice != null || maxPrice != null ? 1 : 0) +
      (vaccinatedOnly ? 1 : 0) +
      (verifiedOnly ? 1 : 0) +
      (negotiableOnly ? 1 : 0);

  bool get isEmpty => activeCount == 0;

  PetFilter copyWith({
    Set<PetSpecies>? species,
    Set<PetAge>? ages,
    Set<String>? genders,
    double? minPrice,
    double? maxPrice,
    bool clearMinPrice = false,
    bool clearMaxPrice = false,
    bool? vaccinatedOnly,
    bool? verifiedOnly,
    bool? negotiableOnly,
  }) {
    return PetFilter(
      species: species ?? this.species,
      ages: ages ?? this.ages,
      genders: genders ?? this.genders,
      minPrice: clearMinPrice ? null : (minPrice ?? this.minPrice),
      maxPrice: clearMaxPrice ? null : (maxPrice ?? this.maxPrice),
      vaccinatedOnly: vaccinatedOnly ?? this.vaccinatedOnly,
      verifiedOnly: verifiedOnly ?? this.verifiedOnly,
      negotiableOnly: negotiableOnly ?? this.negotiableOnly,
    );
  }
}

/// Marketplace state: catalogue, search, filters, favourites, my listings and
/// buyer inquiries. This is the single source of truth for pet data.
class PetService extends ChangeNotifier {
  PetService();

  /// Starts empty — listings are created by the user or arrive from the API.
  List<PetModel> _pets = [];
  final List<ReviewModel> _reviews = [];

  String _query = '';
  String _selectedCategoryId = 'all';
  PetFilter _filter = const PetFilter();
  PetSort _sort = PetSort.newest;
  Set<String> _favoriteIds = {};
  bool _isLoading = false;
  bool _isSubmitting = false;

  final List<PetInquiry> _inquiries = [];
  final List<PetPurchase> _purchases = [];

  // ---------------------------------------------------------------- getters

  bool get isLoading => _isLoading;
  bool get isSubmitting => _isSubmitting;
  String get query => _query;
  String get selectedCategoryId => _selectedCategoryId;
  PetFilter get filter => _filter;
  PetSort get sort => _sort;
  List<ReviewModel> get reviews => _reviews;
  List<PetInquiry> get inquiries => List.unmodifiable(_inquiries);
  List<PetPurchase> get purchases => List.unmodifiable(_purchases);
  Set<String> get favoriteIds => Set.unmodifiable(_favoriteIds);

  /// All pets, newest first.
  List<PetModel> get allPets =>
      _pets.where((p) => p.status == PetStatus.available).toList();

  List<PetModel> get featuredPets => _pets
      .where((p) => p.isFeatured && p.status == PetStatus.available)
      .toList();

  List<PetModel> get newArrivals {
    final list = _pets.where((p) => p.status == PetStatus.available).toList()
      ..sort(
        (a, b) => (b.createdAt ?? DateTime(2000)).compareTo(
          a.createdAt ?? DateTime(2000),
        ),
      );
    return list;
  }

  /// Pets the current user has listed.
  List<PetModel> get myListings =>
      _pets.where((p) => p.ownerId == 'me').toList();

  List<PetModel> get favoritePets =>
      _pets.where((p) => _favoriteIds.contains(p.id)).toList();

  int get favoriteCount => _favoriteIds.length;

  /// Pets matching the current query, category, filter and sort.
  List<PetModel> get results {
    final q = _query.trim().toLowerCase();
    var list = _pets.where((p) => p.status == PetStatus.available).toList();

    if (_selectedCategoryId != 'all') {
      final species = CategoriesDataBridge.speciesFor(_selectedCategoryId);
      list = list.where((p) => p.species == species).toList();
    }

    if (q.isNotEmpty) {
      list = list.where((p) {
        return p.name.toLowerCase().contains(q) ||
            p.breed.toLowerCase().contains(q) ||
            p.species.label.toLowerCase().contains(q) ||
            p.description.toLowerCase().contains(q) ||
            p.location.toLowerCase().contains(q) ||
            p.tags.any((t) => t.toLowerCase().contains(q));
      }).toList();
    }

    final f = _filter;
    if (f.species.isNotEmpty) {
      list = list.where((p) => f.species.contains(p.species)).toList();
    }
    if (f.ages.isNotEmpty) {
      list = list.where((p) => f.ages.contains(p.age)).toList();
    }
    if (f.genders.isNotEmpty) {
      list = list.where((p) => f.genders.contains(p.gender)).toList();
    }
    if (f.minPrice != null) {
      list = list.where((p) => p.price >= f.minPrice!).toList();
    }
    if (f.maxPrice != null) {
      list = list.where((p) => p.price <= f.maxPrice!).toList();
    }
    if (f.vaccinatedOnly) {
      list = list.where((p) => p.vaccinated).toList();
    }
    if (f.verifiedOnly) {
      list = list.where((p) => p.seller.verified).toList();
    }
    if (f.negotiableOnly) {
      list = list.where((p) => p.negotiable).toList();
    }

    switch (_sort) {
      case PetSort.newest:
        list.sort(
          (a, b) => (b.createdAt ?? DateTime(2000)).compareTo(
            a.createdAt ?? DateTime(2000),
          ),
        );
      case PetSort.priceLowHigh:
        list.sort((a, b) => a.price.compareTo(b.price));
      case PetSort.priceHighLow:
        list.sort((a, b) => b.price.compareTo(a.price));
      case PetSort.popular:
        list.sort((a, b) => b.favoriteCount.compareTo(a.favoriteCount));
    }
    return list;
  }

  /// Quick "did you mean" suggestions for the search bar, derived from the
  /// live catalogue so there is nothing hard-coded.
  List<String> get searchSuggestions {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    final pool = <String>{
      ..._pets.map((p) => p.breed),
      ..._pets.map((p) => p.name),
      ..._pets.map((p) => p.species.label),
    };
    return pool.where((s) => s.toLowerCase().contains(q)).take(6).toList();
  }

  // ---------------------------------------------------------------- actions

  Future<void> bootstrap() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getStringList(AppConstants.keyFavorites) ?? [];
      _favoriteIds = stored.toSet();
    } catch (_) {
      /* no-op */
    }
    _isLoading = true;
    notifyListeners();
    await Future<void>.delayed(AppConstants.shortDelay);
    _isLoading = false;
    notifyListeners();
  }

  /// Simulates a network fetch so swap-in API calls look natural in the UI.
  Future<void> refresh() async {
    _isLoading = true;
    notifyListeners();
    await Future<void>.delayed(AppConstants.shortDelay);
    _isLoading = false;
    notifyListeners();
  }

  void setQuery(String value) {
    if (_query == value) return;
    _query = value;
    notifyListeners();
  }

  void setCategory(String categoryId) {
    if (_selectedCategoryId == categoryId) return;
    _selectedCategoryId = categoryId;
    notifyListeners();
  }

  void setFilter(PetFilter value) {
    _filter = value;
    notifyListeners();
  }

  void clearFilter() {
    _filter = const PetFilter();
    notifyListeners();
  }

  void setSort(PetSort value) {
    if (_sort == value) return;
    _sort = value;
    notifyListeners();
  }

  bool isFavorite(String petId) => _favoriteIds.contains(petId);

  void toggleFavorite(String petId) {
    final pet = petById(petId);
    if (_favoriteIds.contains(petId)) {
      _favoriteIds.remove(petId);
      if (pet != null) {
        _replace(
          pet.copyWith(
            favoriteCount: (pet.favoriteCount - 1).clamp(0, 1 << 30),
          ),
        );
      }
    } else {
      _favoriteIds.add(petId);
      if (pet != null) {
        _replace(pet.copyWith(favoriteCount: pet.favoriteCount + 1));
      }
    }
    notifyListeners();
    _persistFavorites();
  }

  PetModel? petById(String id) {
    for (final p in _pets) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// Similar pets shown at the bottom of the details screen.
  List<PetModel> relatedPets(String petId, {int limit = 6}) {
    final pet = petById(petId);
    if (pet == null) return const [];
    return _pets
        .where(
          (p) =>
              p.id != petId &&
              p.status == PetStatus.available &&
              (p.species == pet.species || p.breed == pet.breed),
        )
        .take(limit)
        .toList();
  }

  void incrementViews(String petId) {
    final pet = petById(petId);
    if (pet == null) return;
    _replace(pet.copyWith(views: pet.views + 1));
    notifyListeners();
  }

  /// Registers a new listing. Returns the created pet.
  Future<PetModel> createListing({
    required String name,
    required PetSpecies species,
    required String breed,
    required int ageInMonths,
    required String gender,
    required double price,
    required String description,
    required String location,
    required String healthIssues,
    required bool negotiable,
    List<String> imagePaths = const [],
    List<VaccinationRecord> vaccinations = const [],
    List<String> tags = const [],
    SellerModel? seller,
  }) async {
    _isSubmitting = true;
    notifyListeners();
    await Future<void>.delayed(AppConstants.networkDelay);

    final pet = PetModel(
      id: 'pet_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      species: species,
      breed: breed,
      ageInMonths: ageInMonths,
      age: _ageFromMonths(ageInMonths),
      gender: gender,
      price: price,
      imageUrls: List<String>.from(imagePaths),
      seller:
          seller ??
          SellerModel(id: 'me', name: 'You', avatarUrl: '', location: location),
      description: description,
      vaccinated: vaccinations.isNotEmpty,
      healthIssues: healthIssues,
      vaccinations: List<VaccinationRecord>.from(vaccinations),
      location: location,
      status: PetStatus.available,
      isFeatured: false,
      negotiable: negotiable,
      tags: tags,
      createdAt: DateTime.now(),
      ownerId: 'me',
    );

    _pets = [pet, ..._pets];
    _isSubmitting = false;
    notifyListeners();
    return pet;
  }

  /// Replaces the photos on an existing listing.
  void updateListingImages(String petId, List<String> imagePaths) {
    final pet = petById(petId);
    if (pet == null) return;
    _replace(pet.copyWith(imageUrls: List<String>.from(imagePaths)));
    notifyListeners();
  }

  /// Replaces the vaccination history on an existing listing.
  void updateVaccinations(String petId, List<VaccinationRecord> records) {
    final pet = petById(petId);
    if (pet == null) return;
    _replace(pet.copyWith(vaccinations: List<VaccinationRecord>.from(records)));
    notifyListeners();
  }

  Future<void> deleteListing(String petId) async {
    _isSubmitting = true;
    notifyListeners();
    await Future<void>.delayed(AppConstants.shortDelay);
    _pets = _pets.where((p) => p.id != petId).toList();
    _isSubmitting = false;
    notifyListeners();
  }

  Future<void> markAsSold(String petId) async {
    final pet = petById(petId);
    if (pet == null) return;
    _replace(pet.copyWith(status: PetStatus.sold));
    notifyListeners();
  }

  Future<void> updateListingStatus(String petId, PetStatus status) async {
    final pet = petById(petId);
    if (pet == null) return;
    _replace(pet.copyWith(status: status));
    notifyListeners();
  }

  /// Sends an enquiry to the seller and records it in the user's activity.
  Future<PetInquiry> contactSeller({
    required PetModel pet,
    required String buyerId,
    required String buyerName,
    required String message,
  }) async {
    _isSubmitting = true;
    notifyListeners();
    await Future<void>.delayed(AppConstants.shortDelay);

    final inquiry = PetInquiry(
      id: 'inq_${DateTime.now().millisecondsSinceEpoch}',
      petId: pet.id,
      petName: pet.name,
      sellerId: pet.seller.id,
      sellerName: pet.seller.name,
      buyerId: buyerId,
      sellerRole: buyerName,
      createdAt: DateTime.now(),
      message: message,
    );
    _inquiries.insert(0, inquiry);
    _isSubmitting = false;
    notifyListeners();
    return inquiry;
  }

  /// Completes a purchase of [pet] for [buyerId].
  Future<PetPurchase> purchasePet({
    required PetModel pet,
    required String buyerId,
  }) async {
    _isSubmitting = true;
    notifyListeners();
    await Future<void>.delayed(AppConstants.networkDelay);

    _replace(pet.copyWith(status: PetStatus.sold));

    final purchase = PetPurchase(
      id: 'pch_${DateTime.now().millisecondsSinceEpoch}',
      petId: pet.id,
      petName: pet.name,
      petImage: pet.image,
      sellerName: pet.seller.name,
      amount: pet.price,
      purchasedAt: DateTime.now(),
    );
    _purchases.insert(0, purchase);
    _inquiries.insert(
      0,
      PetInquiry(
        id: 'inq_${DateTime.now().millisecondsSinceEpoch}',
        petId: pet.id,
        petName: pet.name,
        sellerId: pet.seller.id,
        sellerName: pet.seller.name,
        buyerId: buyerId,
        sellerRole: 'Purchase',
        createdAt: DateTime.now(),
        message: 'Purchase completed',
        status: PetInquiryStatus.closed,
      ),
    );
    _isSubmitting = false;
    notifyListeners();
    return purchase;
  }

  void _replace(PetModel updated) {
    _pets = _pets.map((p) => p.id == updated.id ? updated : p).toList();
  }

  Future<void> _persistFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        AppConstants.keyFavorites,
        _favoriteIds.toList(),
      );
    } catch (_) {
      /* no-op */
    }
  }

  static PetAge _ageFromMonths(int months) {
    if (months < 12) return PetAge.puppy;
    if (months < 24) return PetAge.young;
    if (months < 84) return PetAge.adult;
    return PetAge.senior;
  }
}

/// Small indirection so the service does not import UI-layer data classes.
/// Keeps [PetService] reusable if the category set moves to an API.
class CategoriesDataBridge {
  CategoriesDataBridge._();

  static PetSpecies speciesFor(String id) => switch (id) {
    'dogs' => PetSpecies.dog,
    'cats' => PetSpecies.cat,
    'birds' => PetSpecies.bird,
    'rabbits' => PetSpecies.rabbit,
    'fish' => PetSpecies.fish,
    'reptiles' => PetSpecies.reptile,
    _ => PetSpecies.smallPet,
  };
}
