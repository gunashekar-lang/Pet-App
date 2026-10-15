import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../app/routes.dart';
import '../../models/pet_model.dart';
import '../../models/product_model.dart';
import '../../services/pet_service.dart';
import '../../services/store_service.dart';
import '../../utils/constants.dart';
import '../../utils/helpers.dart';
import '../../widgets/common.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/pet_card.dart';
import '../../widgets/product_card.dart';
import '../../widgets/section_header.dart';
import '../store/store_screen.dart';

/// Standalone marketplace route. The Buy tab uses [MarketplaceBrowser]
/// directly, so this is kept as a deep-linkable target.
class MarketplaceScreen extends StatelessWidget {
  const MarketplaceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(bottom: false, child: MarketplaceBrowser()),
    );
  }
}

/// The merged Buy experience: search, categories, filters, sorting and the
/// results grid in one scroll surface. [header] lets the Buy tab drop its
/// greeting bar above the browser.
class MarketplaceBrowser extends StatefulWidget {
  const MarketplaceBrowser({super.key, this.header});

  final Widget? header;

  @override
  State<MarketplaceBrowser> createState() => _MarketplaceBrowserState();
}

/// The Buy page can browse two catalogues: pets for adoption/sale and the
/// physical pet store. The slide toggle at the top switches between them.
enum BuyTab { pets, store }

class _MarketplaceBrowserState extends State<MarketplaceBrowser> {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();

  BuyTab _tab = BuyTab.pets;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _applyQuery(_searchController.text);
  }

  /// Routes the typed text to whichever catalogue is currently on screen.
  void _applyQuery(String value) {
    if (_tab == BuyTab.pets) {
      context.read<PetService>().setQuery(value);
    } else {
      context.read<StoreService>().setQuery(value);
    }
  }

  void _setTab(BuyTab tab) {
    if (_tab == tab) return;
    setState(() => _tab = tab);
    // Re-apply the current search text to the newly active catalogue so the
    // results grid immediately reflects what is already typed.
    _applyQuery(_searchController.text);
  }

  Future<void> _openFilters() async {
    if (_tab == BuyTab.pets) {
      final service = context.read<PetService>();
      final result = await showModalBottomSheet<PetFilter>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => PetFilterSheet(initial: service.filter),
      );
      if (result != null) service.setFilter(result);
    } else {
      await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => const StoreFilterSheet(),
      );
    }
  }

  Future<void> _openSort() async {
    if (_tab == BuyTab.pets) {
      final service = context.read<PetService>();
      final result = await showModalBottomSheet<PetSort>(
        context: context,
        builder: (_) => const SortSheet(),
      );
      if (result != null) service.setSort(result);
    } else {
      final store = context.read<StoreService>();
      final result = await showModalBottomSheet<StoreSort>(
        context: context,
        builder: (_) => const StoreSortSheet(),
      );
      if (result != null) store.setSort(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pets = context.watch<PetService>();
    final store = context.watch<StoreService>();
    final scheme = Theme.of(context).colorScheme;

    final isPets = _tab == BuyTab.pets;
    // Resolve the active catalogue once so the header, result row and grid
    // all agree without recomputing filters/sort more than necessary.
    final List<PetModel> petResults = isPets ? pets.results : const [];
    final List<ProductModel> storeResults = isPets ? const [] : store.results;
    final count = isPets ? petResults.length : storeResults.length;
    final filterCount = isPets ? pets.filter.activeCount : store.activeFilterCount;
    final sortLabel = isPets ? pets.sort.label : store.sort.label;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            if (widget.header != null) widget.header!,
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Marketplace',
                          style: TextStyle(
                            fontSize: 25,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.7,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isPets
                              ? '${pets.allPets.length} pets ready for a new home'
                              : '${store.allProducts.length} products in the store',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: scheme.onSurface.withValues(alpha: 0.55),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Gap.h14,
            // Slide toggle: Pets on the left, Store on the right.
            _BuyTabToggle(current: _tab, onChanged: _setTab),
            Gap.h12,
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _searchController,
                onSubmitted: (_) => FocusScope.of(context).unfocus(),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: isPets
                      ? 'Search by breed, name or location'
                      : 'Search food, toys, grooming…',
                  prefixIcon: const Icon(Icons.search_rounded, size: 21),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_searchController.text.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 19),
                          onPressed: () => _searchController.clear(),
                        ),
                      IconButton(
                        tooltip: 'Filters',
                        icon: Badge(
                          isLabelVisible: filterCount > 0,
                          label: Text('$filterCount'),
                          child: const Icon(Icons.tune_rounded, size: 20),
                        ),
                        onPressed: _openFilters,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Gap.h12,
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Text(
                    Helpers.plural(count, 'result'),
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  Gap.w8,
                  if (filterCount > 0) ...[
                    StatusPill(
                      label: '$filterCount filters',
                      icon: Icons.tune_rounded,
                      dense: true,
                    ),
                    Gap.w6,
                    GestureDetector(
                      onTap: isPets ? pets.clearFilter : store.clearFilters,
                      child: Text(
                        'Clear',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: scheme.error,
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                  OutlinedButton.icon(
                    onPressed: _openSort,
                    icon: const Icon(Icons.swap_vert_rounded, size: 18),
                    label: Text(
                      sortLabel,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 38),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      side: BorderSide(color: scheme.outline),
                    ),
                  ),
                ],
              ),
            ),
            Gap.h12,
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: isPets
                    ? _petResultsGrid(
                        pets,
                        petResults,
                        _searchController.text.isNotEmpty,
                      )
                    : _storeResultsGrid(
                        store,
                        storeResults,
                        _searchController.text.isNotEmpty,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _petResultsGrid(
    PetService pets,
    List<PetModel> results,
    bool hasQuery,
  ) {
    if (results.isEmpty) {
      return _NoResults(
        key: const ValueKey('empty-pets'),
        title: 'No pets found',
        hasQuery: hasQuery,
        onClear: () {
          _searchController.clear();
          pets.clearFilter();
          pets.setCategory('all');
        },
      );
    }
    return GridView.builder(
      key: const ValueKey('pet-grid'),
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 230,
        mainAxisExtent: 292,
        crossAxisSpacing: 12,
        mainAxisSpacing: 14,
      ),
      itemCount: results.length,
      itemBuilder: (context, i) {
        final pet = results[i];
        return PetCard(
          pet: pet,
          isFavorite: pets.favoriteIds.contains(pet.id),
          onFavoriteToggle: () {
            HapticFeedback.lightImpact();
            pets.toggleFavorite(pet.id);
          },
          onTap: () {
            pets.incrementViews(pet.id);
            Nav.push(context, AppRoutes.petDetails, PetDetailsArgs(pet.id));
          },
        );
      },
    );
  }

  Widget _storeResultsGrid(
    StoreService store,
    List<ProductModel> results,
    bool hasQuery,
  ) {
    if (results.isEmpty) {
      return _NoResults(
        key: const ValueKey('empty-store'),
        title: 'No products found',
        hasQuery: hasQuery,
        onClear: () {
          _searchController.clear();
          store.clearFilters();
        },
      );
    }
    return GridView.builder(
      key: const ValueKey('store-grid'),
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 230,
        mainAxisExtent: 292,
        crossAxisSpacing: 12,
        mainAxisSpacing: 14,
      ),
      itemCount: results.length,
      itemBuilder: (context, i) {
        final product = results[i];
        return ProductCard(
          product: product,
          isWishlisted: store.isInWishlist(product.id),
          onToggleWishlist: () => store.toggleWishlist(product.id),
          onAddToCart: () => _addToCart(store, product),
          onTap: () => Nav.push(
            context,
            AppRoutes.productDetails,
            ProductDetailsArgs(product.id),
          ),
        );
      },
    );
  }

  void _addToCart(StoreService store, ProductModel product) {
    store.addToCart(product);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('${product.name} added to cart'),
          duration: const Duration(seconds: 2),
          action: SnackBarAction(
            label: 'View cart',
            onPressed: () => Nav.push(context, AppRoutes.cart),
          ),
        ),
      );
  }
}

/// Sliding segmented control that switches the Buy page between the pet
/// listings and the pet store. The pill indicator animates between the two
/// halves.
class _BuyTabToggle extends StatelessWidget {
  const _BuyTabToggle({required this.current, required this.onChanged});

  final BuyTab current;
  final ValueChanged<BuyTab> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        height: 46,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(AppConstants.radiusLg),
          border: Border.all(color: scheme.outline),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final segmentWidth = constraints.maxWidth / 2;
            return Stack(
              children: [
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                  left: current == BuyTab.pets ? 0 : segmentWidth,
                  top: 0,
                  width: segmentWidth,
                  height: constraints.maxHeight,
                  child: Container(
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      borderRadius: BorderRadius.circular(AppConstants.radiusLg),
                      boxShadow: [
                        BoxShadow(
                          color: scheme.primary.withValues(alpha: 0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                  ),
                ),
                Row(
                  children: [
                    _segment(
                      scheme,
                      tab: BuyTab.pets,
                      icon: Icons.pets_rounded,
                      label: 'Pets',
                    ),
                    _segment(
                      scheme,
                      tab: BuyTab.store,
                      icon: Icons.storefront_rounded,
                      label: 'Store',
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _segment(
    ColorScheme scheme, {
    required BuyTab tab,
    required IconData icon,
    required String label,
  }) {
    final selected = current == tab;
    final muted = scheme.onSurface.withValues(alpha: 0.65);
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        onTap: () => onChanged(tab),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 17,
                color: selected ? Colors.white : muted,
              ),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                  color: selected
                      ? Colors.white
                      : scheme.onSurface.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoResults extends StatelessWidget {
  const _NoResults({
    super.key,
    required this.title,
    required this.hasQuery,
    required this.onClear,
  });

  final String title;
  final bool hasQuery;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.search_off_rounded,
      title: title,
      message: hasQuery
          ? 'Try a different search, or relax your filters.'
          : 'There are no listings matching these filters right now.',
      actionLabel: 'Clear all filters',
      onAction: onClear,
    );
  }
}

/// Bottom sheet listing every sort option.
class SortSheet extends StatelessWidget {
  const SortSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final current = context.watch<PetService>().sort;
    final scheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Sort by',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
            ),
            Gap.h4,
            Text(
              'Choose how results are ordered',
              style: TextStyle(
                fontSize: 13,
                color: scheme.onSurface.withValues(alpha: 0.55),
              ),
            ),
            Gap.h16,
            for (final option in PetSort.values) ...[
              ListTile(
                onTap: () => Nav.pop(context, option),
                contentPadding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                ),
                title: Text(
                  option.label,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                trailing: current == option
                    ? Icon(Icons.check_circle_rounded, color: scheme.primary)
                    : const Icon(Icons.circle_outlined, size: 20),
              ),
              if (option != PetSort.values.last) const Divider(),
            ],
          ],
        ),
      ),
    );
  }
}

/// Full filter sheet for the marketplace.
class PetFilterSheet extends StatefulWidget {
  const PetFilterSheet({super.key, required this.initial});

  final PetFilter initial;

  @override
  State<PetFilterSheet> createState() => _PetFilterSheetState();
}

class _PetFilterSheetState extends State<PetFilterSheet> {
  late PetFilter _filter = widget.initial;
  late final TextEditingController _minController = TextEditingController(
    text: _fmt(widget.initial.minPrice),
  );
  late final TextEditingController _maxController = TextEditingController(
    text: _fmt(widget.initial.maxPrice),
  );

  static String _fmt(double? v) => v == null ? '' : v.toStringAsFixed(0);

  @override
  void dispose() {
    _minController.dispose();
    _maxController.dispose();
    super.dispose();
  }

  void _apply() {
    Nav.pop(
      context,
      _filter.copyWith(
        minPrice: double.tryParse(_minController.text.replaceAll(',', '')),
        maxPrice: double.tryParse(_maxController.text.replaceAll(',', '')),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.86,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 12, 8),
            child: Row(
              children: [
                const Text(
                  'Filters',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => setState(() {
                    _filter = const PetFilter();
                    _minController.clear();
                    _maxController.clear();
                  }),
                  child: Text('Reset', style: TextStyle(color: scheme.error)),
                ),
                IconButton(
                  onPressed: () => Nav.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              children: [
                const _GroupTitle('Species'),
                Gap.h10,
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final species in PetSpecies.values)
                      _Choice(
                        label: species.label,
                        selected: _filter.species.contains(species),
                        onTap: () {
                          final next = Set<PetSpecies>.from(_filter.species);
                          if (!next.remove(species)) next.add(species);
                          setState(
                            () => _filter = _filter.copyWith(species: next),
                          );
                        },
                      ),
                  ],
                ),
                Gap.h24,
                const _GroupTitle('Age'),
                Gap.h10,
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final age in PetAge.values)
                      _Choice(
                        label: age.label,
                        selected: _filter.ages.contains(age),
                        onTap: () {
                          final next = Set<PetAge>.from(_filter.ages);
                          if (!next.remove(age)) next.add(age);
                          setState(
                            () => _filter = _filter.copyWith(ages: next),
                          );
                        },
                      ),
                  ],
                ),
                Gap.h24,
                const _GroupTitle('Gender'),
                Gap.h10,
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final gender in const ['Male', 'Female', 'Pair'])
                      _Choice(
                        label: gender,
                        selected: _filter.genders.contains(gender),
                        onTap: () {
                          final next = Set<String>.from(_filter.genders);
                          if (!next.remove(gender)) next.add(gender);
                          setState(
                            () => _filter = _filter.copyWith(genders: next),
                          );
                        },
                      ),
                  ],
                ),
                Gap.h24,
                const _GroupTitle('Price range'),
                Gap.h10,
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _minController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          hintText: 'Min',
                          prefixIcon: Icon(
                            Icons.currency_rupee_rounded,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        'to',
                        style: TextStyle(
                          color: scheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _maxController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          hintText: 'Max',
                          prefixIcon: Icon(
                            Icons.currency_rupee_rounded,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                Gap.h6,
                Wrap(
                  spacing: 8,
                  children: [
                    for (final preset in const [
                      10000.0,
                      25000.0,
                      50000.0,
                      100000.0,
                    ])
                      ActionChip(
                        label: Text('Under ${Helpers.currency(preset)}'),
                        onPressed: () => setState(() {
                          _maxController.text = preset.toStringAsFixed(0);
                        }),
                        backgroundColor: scheme.surface,
                        side: BorderSide(color: scheme.outline),
                        labelStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
                Gap.h24,
                const _GroupTitle('Seller & health'),
                Gap.h10,
                _SwitchRow(
                  label: 'Vaccinated only',
                  subtitle: 'Show pets with up-to-date vaccinations',
                  icon: Icons.vaccines_rounded,
                  value: _filter.vaccinatedOnly,
                  onChanged: (v) => setState(
                    () => _filter = _filter.copyWith(vaccinatedOnly: v),
                  ),
                ),
                _SwitchRow(
                  label: 'Verified sellers only',
                  subtitle: 'Identity-checked sellers with a rating',
                  icon: Icons.verified_user_rounded,
                  value: _filter.verifiedOnly,
                  onChanged: (v) => setState(
                    () => _filter = _filter.copyWith(verifiedOnly: v),
                  ),
                ),
                _SwitchRow(
                  label: 'Price negotiable',
                  subtitle: 'Seller will discuss offers',
                  icon: Icons.handshake_rounded,
                  value: _filter.negotiableOnly,
                  onChanged: (v) => setState(
                    () => _filter = _filter.copyWith(negotiableOnly: v),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            decoration: BoxDecoration(
              color: scheme.surface,
              border: Border(top: BorderSide(color: scheme.outline)),
            ),
            child: SafeArea(
              top: false,
              child: CustomButton(
                label: 'Show results',
                icon: Icons.check_rounded,
                onPressed: _apply,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupTitle extends StatelessWidget {
  const _GroupTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
  );
}

class _Choice extends StatelessWidget {
  const _Choice({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected ? scheme.primary : scheme.surface,
      borderRadius: BorderRadius.circular(999),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? scheme.primary : scheme.outline,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : scheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String subtitle;
  final IconData icon;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: scheme.primary),
          ),
          Gap.w12,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: scheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
