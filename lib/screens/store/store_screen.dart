import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/routes.dart';
import '../../models/pet_model.dart';
import '../../models/product_model.dart';
import '../../services/store_service.dart';
import '../../utils/constants.dart';
import '../../utils/helpers.dart';
import '../../widgets/category_card.dart';
import '../../widgets/common.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/product_card.dart';
import '../../widgets/search_bar.dart';
import '../../widgets/section_header.dart';

/// The Pet Store: categories, deals, best sellers, search and product grid.
class StoreScreen extends StatefulWidget {
  const StoreScreen({super.key});

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<StoreService>();
    final scheme = Theme.of(context).colorScheme;
    final isBrowsing =
        store.query.isNotEmpty ||
        store.category != null ||
        store.dealsOnly ||
        store.speciesTags.isNotEmpty;
    final results = store.results;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Pet Store',
                            style: TextStyle(
                              fontSize: 25,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.7,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Free delivery on orders over ₹499',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: scheme.onSurface.withValues(alpha: 0.55),
                            ),
                          ),
                        ],
                      ),
                    ),
                    CircleIconButton(
                      icon: Icons.shopping_bag_outlined,
                      badge: store.cartItemCount,
                      tooltip: 'Cart',
                      onTap: () => Nav.push(context, AppRoutes.cart),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: AppSearchBar(
                  hintText: 'Search food, toys, grooming…',
                  onChanged: store.setQuery,
                  onClear: () => store.setQuery(''),
                  filterCount: store.activeFilterCount,
                  onFilterTap: () => _openFilters(context, store),
                ),
              ),
            ),
            SliverToBoxAdapter(child: _SpeciesFilter(store: store)),
            if (!isBrowsing) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: SizedBox(
                    height: 38,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        for (final category in ProductCategory.values) ...[
                          StoreCategoryCard(
                            category: category,
                            label: category.label,
                            onTap: () => store.setCategory(category),
                          ),
                          Gap.w8,
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: _PromoBanner(onTap: () => store.setDealsOnly(true)),
                ),
              ),
              SliverToBoxAdapter(
                child: SectionHeader(
                  title: 'Deals of the week',
                  subtitle: 'Limited time discounts',
                  icon: Icons.local_offer_rounded,
                  actionLabel: 'See all',
                  onAction: () => store.setDealsOnly(true),
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 268,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: Helpers.pagePadding,
                    itemCount: store.dealProducts.length,
                    separatorBuilder: (_, _) => Gap.w12,
                    itemBuilder: (context, i) {
                      final product = store.dealProducts[i];
                      return ProductCard(
                        product: product,
                        width: 172,
                        isWishlisted: store.isInWishlist(product.id),
                        onToggleWishlist: () =>
                            store.toggleWishlist(product.id),
                        onAddToCart: () => _addToCart(context, store, product),
                        onTap: () => Nav.push(
                          context,
                          AppRoutes.productDetails,
                          ProductDetailsArgs(product.id),
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 26)),
              SliverToBoxAdapter(
                child: SectionHeader(
                  title: 'Best sellers',
                  subtitle: 'Loved by pet parents everywhere',
                  icon: Icons.workspace_premium_rounded,
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 268,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: Helpers.pagePadding,
                    itemCount: store.bestSellers.length,
                    separatorBuilder: (_, _) => Gap.w12,
                    itemBuilder: (context, i) {
                      final product = store.bestSellers[i];
                      return ProductCard(
                        product: product,
                        width: 172,
                        isWishlisted: store.isInWishlist(product.id),
                        onToggleWishlist: () =>
                            store.toggleWishlist(product.id),
                        onAddToCart: () => _addToCart(context, store, product),
                        onTap: () => Nav.push(
                          context,
                          AppRoutes.productDetails,
                          ProductDetailsArgs(product.id),
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 26)),
            ] else ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
                  child: Row(
                    children: [
                      Text(
                        Helpers.plural(results.length, 'product'),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Gap.w8,
                      if (store.activeFilterCount > 0)
                        GestureDetector(
                          onTap: store.clearFilters,
                          child: Text(
                            'Clear filters',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: scheme.error,
                            ),
                          ),
                        ),
                      const Spacer(),
                      OutlinedButton.icon(
                        onPressed: () => _openSort(context, store),
                        icon: const Icon(Icons.swap_vert_rounded, size: 18),
                        label: Text(
                          store.sort.label,
                          style: const TextStyle(
                            fontSize: 12,
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
              ),
            ],
            if (isBrowsing)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                sliver: results.isEmpty
                    ? SliverToBoxAdapter(
                        child: EmptyState(
                          icon: Icons.search_off_rounded,
                          title: 'No products found',
                          message:
                              'Try a different search term or clear your '
                              'filters to see everything.',
                          actionLabel: 'Clear filters',
                          onAction: store.clearFilters,
                        ),
                      )
                    : SliverGrid(
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 210,
                              mainAxisExtent: 296,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 14,
                            ),
                        delegate: SliverChildBuilderDelegate((context, i) {
                          final product = results[i];
                          return ProductCard(
                            product: product,
                            isWishlisted: store.isInWishlist(product.id),
                            onToggleWishlist: () =>
                                store.toggleWishlist(product.id),
                            onAddToCart: () =>
                                _addToCart(context, store, product),
                            onTap: () => Nav.push(
                              context,
                              AppRoutes.productDetails,
                              ProductDetailsArgs(product.id),
                            ),
                          );
                        }, childCount: results.length),
                      ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 110)),
          ],
        ),
      ),
    );
  }

  void _addToCart(
    BuildContext context,
    StoreService store,
    ProductModel product,
  ) {
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

  Future<void> _openFilters(BuildContext context, StoreService store) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const _StoreFilterSheet(),
    );
    if (result == true && context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Filters applied')));
    }
  }

  Future<void> _openSort(BuildContext context, StoreService store) async {
    final result = await showModalBottomSheet<StoreSort>(
      context: context,
      builder: (_) => const _StoreSortSheet(),
    );
    if (result != null) store.setSort(result);
  }
}

class _SpeciesFilter extends StatelessWidget {
  const _SpeciesFilter({required this.store});

  final StoreService store;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const species = [
      PetSpecies.dog,
      PetSpecies.cat,
      PetSpecies.bird,
      PetSpecies.rabbit,
    ];

    return SizedBox(
      height: 62,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
        children: [
          Material(
            color: store.dealsOnly ? AppColors.danger : scheme.surface,
            borderRadius: BorderRadius.circular(999),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => store.setDealsOnly(!store.dealsOnly),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: store.dealsOnly ? AppColors.danger : scheme.outline,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.local_offer_rounded,
                      size: 15,
                      color: store.dealsOnly
                          ? Colors.white
                          : scheme.onSurface.withValues(alpha: 0.7),
                    ),
                    Gap.w6,
                    Text(
                      'Deals',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: store.dealsOnly
                            ? Colors.white
                            : scheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          for (final s in species) ...[
            Gap.w8,
            Material(
              color: store.speciesTags.contains(s)
                  ? scheme.primary
                  : scheme.surface,
              borderRadius: BorderRadius.circular(999),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => store.toggleSpeciesTag(s),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: store.speciesTags.contains(s)
                          ? scheme.primary
                          : scheme.outline,
                    ),
                  ),
                  child: Text(
                    s.label,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: store.speciesTags.contains(s)
                          ? Colors.white
                          : scheme.onSurface,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PromoBanner extends StatelessWidget {
  const _PromoBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      borderRadius: BorderRadius.circular(AppConstants.radiusMd),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppConstants.radiusMd),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.brand.withValues(alpha: 0.16),
                AppColors.plum.withValues(alpha: 0.14),
              ],
            ),
            border: Border.all(color: AppColors.brand.withValues(alpha: 0.24)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Up to 30% off',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Across food, treats and toys this week',
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.4,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.65),
                      ),
                    ),
                  ],
                ),
              ),
              Gap.w12,
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.local_offer_rounded,
                  color: AppColors.brand,
                  size: 24,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StoreFilterSheet extends StatelessWidget {
  const _StoreFilterSheet();

  @override
  Widget build(BuildContext context) {
    final store = context.watch<StoreService>();
    final scheme = Theme.of(context).colorScheme;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.9,
      builder: (context, scrollController) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 12, 8),
            child: Row(
              children: [
                const Text(
                  'Filter products',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                const Spacer(),
                TextButton(
                  onPressed: store.clearFilters,
                  child: Text('Reset', style: TextStyle(color: scheme.error)),
                ),
                IconButton(
                  onPressed: () => Nav.pop(context, true),
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
                const Text(
                  'Category',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                ),
                Gap.h10,
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final category in ProductCategory.values)
                      Material(
                        color: store.category == category
                            ? scheme.primary
                            : scheme.surface,
                        borderRadius: BorderRadius.circular(999),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () => store.setCategory(
                            store.category == category ? null : category,
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 9,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: store.category == category
                                    ? scheme.primary
                                    : scheme.outline,
                              ),
                            ),
                            child: Text(
                              category.label,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: store.category == category
                                    ? Colors.white
                                    : scheme.onSurface,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                Gap.h24,
                const Text(
                  'Suitable for',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                ),
                Gap.h10,
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final species in PetSpecies.values)
                      FilterChip(
                        label: Text(species.label),
                        selected: store.speciesTags.contains(species),
                        onSelected: (_) => store.toggleSpeciesTag(species),
                        showCheckmark: false,
                        backgroundColor: scheme.surface,
                        selectedColor: scheme.primary,
                        labelStyle: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: store.speciesTags.contains(species)
                              ? Colors.white
                              : scheme.onSurface,
                        ),
                      ),
                  ],
                ),
                Gap.h24,
                SwitchListTile(
                  value: store.dealsOnly,
                  onChanged: store.setDealsOnly,
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Deals and discounts only',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text('Show products currently reduced'),
                ),
                SwitchListTile(
                  value: store.inStockOnly,
                  onChanged: store.setInStockOnly,
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'In stock only',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text('Hide sold-out products'),
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
                onPressed: () => Nav.pop(context, true),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StoreSortSheet extends StatelessWidget {
  const _StoreSortSheet();

  @override
  Widget build(BuildContext context) {
    final current = context.watch<StoreService>().sort;
    final scheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Sort products',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
            ),
            Gap.h12,
            for (final option in StoreSort.values) ...[
              ListTile(
                onTap: () => Nav.pop(context, option),
                contentPadding: EdgeInsets.zero,
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
              if (option != StoreSort.values.last) const Divider(),
            ],
          ],
        ),
      ),
    );
  }
}
