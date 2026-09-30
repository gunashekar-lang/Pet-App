import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../app/routes.dart';
import '../../data/categories_data.dart';
import '../../models/pet_model.dart';
import '../../services/pet_service.dart';
import '../../utils/constants.dart';
import '../../utils/helpers.dart';
import '../../widgets/common.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/pet_card.dart';
import '../../widgets/section_header.dart';

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

class _MarketplaceBrowserState extends State<MarketplaceBrowser> {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();

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
    // PetService notifies listeners, so the results grid rebuilds on its own.
    context.read<PetService>().setQuery(_searchController.text);
  }

  Future<void> _openFilters() async {
    final service = context.read<PetService>();
    final result = await showModalBottomSheet<PetFilter>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => PetFilterSheet(initial: service.filter),
    );
    if (result != null) service.setFilter(result);
  }

  Future<void> _openSort() async {
    final service = context.read<PetService>();
    final result = await showModalBottomSheet<PetSort>(
      context: context,
      builder: (_) => const SortSheet(),
    );
    if (result != null) service.setSort(result);
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<PetService>();
    final scheme = Theme.of(context).colorScheme;
    final results = service.results;
    final favorites = service.favoriteIds;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            if (widget.header != null) widget.header!,
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
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
                          '${service.allPets.length} pets ready for a new home',
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _searchController,
                onSubmitted: (_) => FocusScope.of(context).unfocus(),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Search by breed, name or location',
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
                          isLabelVisible: service.filter.activeCount > 0,
                          label: Text('${service.filter.activeCount}'),
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
            _CategoryTabs(
              selectedId: service.selectedCategoryId,
              onSelect: service.setCategory,
            ),
            Gap.h12,
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Text(
                    Helpers.plural(results.length, 'result'),
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  Gap.w8,
                  if (service.filter.activeCount > 0) ...[
                    StatusPill(
                      label: '${service.filter.activeCount} filters',
                      icon: Icons.tune_rounded,
                      dense: true,
                    ),
                    Gap.w6,
                    GestureDetector(
                      onTap: service.clearFilter,
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
                      service.sort.label,
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
                child: results.isEmpty
                    ? _NoResults(
                        key: const ValueKey('empty'),
                        hasQuery: _searchController.text.isNotEmpty,
                        onClear: () {
                          _searchController.clear();
                          service.clearFilter();
                          service.setCategory('all');
                        },
                      )
                    : GridView.builder(
                        key: const ValueKey('grid'),
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
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
                            isFavorite: favorites.contains(pet.id),
                            onFavoriteToggle: () {
                              HapticFeedback.lightImpact();
                              service.toggleFavorite(pet.id);
                            },
                            onTap: () {
                              service.incrementViews(pet.id);
                              Nav.push(
                                context,
                                AppRoutes.petDetails,
                                PetDetailsArgs(pet.id),
                              );
                            },
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryTabs extends StatelessWidget {
  const _CategoryTabs({required this.selectedId, required this.onSelect});

  final String selectedId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          _Tab(
            label: 'All pets',
            selected: selectedId == 'all',
            onTap: () => onSelect('all'),
          ),
          for (final category in CategoriesData.all) ...[
            Gap.w8,
            _Tab(
              label: category.name,
              selected: selectedId == category.id,
              color: category.color,
              onTap: () => onSelect(category.id),
            ),
          ],
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.label,
    required this.selected,
    required this.onTap,
    this.color,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = color ?? scheme.primary;

    return Material(
      color: selected ? accent : scheme.surface,
      borderRadius: BorderRadius.circular(999),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 15),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: selected ? accent : scheme.outline),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : scheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

class _NoResults extends StatelessWidget {
  const _NoResults({super.key, required this.hasQuery, required this.onClear});

  final bool hasQuery;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.search_off_rounded,
      title: 'No pets found',
      message: hasQuery
          ? 'Try a different breed, name or location, or relax your filters.'
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
