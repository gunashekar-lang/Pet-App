import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/routes.dart';
import '../../models/pet_model.dart';
import '../../models/product_model.dart';
import '../../services/store_service.dart';
import '../../utils/constants.dart';
import '../../utils/helpers.dart';
import '../../widgets/common.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/product_card.dart';
import '../../widgets/section_header.dart';

class ProductDetailsScreen extends StatefulWidget {
  const ProductDetailsScreen({super.key, required this.productId});

  final String productId;

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  int _quantity = 1;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<StoreService>();
    final product = store.productById(widget.productId);

    if (product == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyState(
          icon: Icons.error_outline_rounded,
          title: 'Product not found',
          message: 'This product may have been removed from the store.',
        ),
      );
    }

    final scheme = Theme.of(context).colorScheme;
    final isWishlisted = store.isInWishlist(product.id);
    final inCart = store.cartQuantity(product.id);
    final related = store.relatedProducts(product.id);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 320,
            pinned: true,
            backgroundColor: scheme.surface,
            surfaceTintColor: Colors.transparent,
            leading: Padding(
              padding: const EdgeInsets.all(6),
              child: CircleIconButton(
                icon: Icons.arrow_back_rounded,
                onTap: () => Nav.pop(context),
                background: scheme.surface,
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.all(6),
                child: CircleIconButton(
                  icon: isWishlisted
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  foreground: isWishlisted ? AppColors.danger : null,
                  onTap: () => store.toggleWishlist(product.id),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 6, 12, 6),
                child: CircleIconButton(
                  icon: Icons.shopping_bag_outlined,
                  badge: store.cartItemCount,
                  onTap: () => Nav.push(context, AppRoutes.cart),
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  AppImage(
                    url: product.imageUrl,
                    icon: product.category.icon,
                    gradientColors: [
                      scheme.primary.withValues(alpha: 0.16),
                      scheme.primary.withValues(alpha: 0.04),
                    ],
                  ),
                  if (product.onSale)
                    Positioned(
                      left: 20,
                      bottom: 20,
                      child: StatusPill(
                        label: 'Save ${product.discountPercent}%',
                        icon: Icons.local_offer_rounded,
                        color: AppColors.danger,
                        solid: true,
                      ),
                    ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          product.brand.toUpperCase(),
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                            color: scheme.primary,
                          ),
                        ),
                      ),
                      if (product.isVerifiedShopListing) ...[
                        Gap.w6,
                        Icon(
                          Icons.verified_rounded,
                          size: 14,
                          color: scheme.primary,
                        ),
                        Gap.w4,
                        Flexible(
                          child: Text(
                            product.shopName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: scheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  Gap.h8,
                  Text(
                    product.name,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.6,
                      height: 1.2,
                    ),
                  ),
                  Gap.h8,
                  Row(
                    children: [
                      const Icon(
                        Icons.star_rounded,
                        size: 17,
                        color: AppColors.warning,
                      ),
                      Gap.w4,
                      Text(
                        product.rating.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '  ·  ${product.reviewCount} reviews  ·  ${product.soldCount} sold',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: scheme.onSurface.withValues(alpha: 0.55),
                        ),
                      ),
                    ],
                  ),
                  Gap.h16,
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        Helpers.currencyPrecise(product.price),
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.8,
                          color: scheme.primary,
                        ),
                      ),
                      if (product.onSale) ...[
                        Gap.w8,
                        Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: Text(
                            Helpers.currencyPrecise(product.oldPrice!),
                            style: TextStyle(
                              fontSize: 14,
                              color: scheme.onSurface.withValues(alpha: 0.4),
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                        ),
                      ],
                      const Spacer(),
                      if (!product.inStock)
                        const StatusPill(
                          label: 'Out of stock',
                          color: AppColors.danger,
                          solid: true,
                        )
                      else if (product.isLowStock)
                        StatusPill(
                          label: 'Only ${product.stock} left',
                          color: AppColors.warning,
                          solid: true,
                        ),
                    ],
                  ),
                  Gap.h20,
                  _InfoRow(product: product),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'About this product',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                  Gap.h8,
                  Text(
                    product.description,
                    style: TextStyle(
                      fontSize: 13.5,
                      height: 1.55,
                      color: scheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                  if (product.highlights.isNotEmpty) ...[
                    Gap.h16,
                    for (final highlight in product.highlights)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.check_circle_rounded,
                              size: 17,
                              color: AppColors.success,
                            ),
                            Gap.w8,
                            Expanded(
                              child: Text(
                                highlight,
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                  if (product.speciesTags.isNotEmpty) ...[
                    Gap.h12,
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final species in product.speciesTags)
                          StatusPill(
                            label: 'For ${species.label}',
                            icon: Icons.pets_rounded,
                            color: scheme.primary,
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (related.isNotEmpty) ...[
            const SliverToBoxAdapter(child: SizedBox(height: 26)),
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      'You may also like',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Gap.h12,
                  SizedBox(
                    height: 268,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: Helpers.pagePadding,
                      itemCount: related.length,
                      separatorBuilder: (_, _) => Gap.w12,
                      itemBuilder: (context, i) {
                        final item = related[i];
                        return ProductCard(
                          product: item,
                          width: 172,
                          isWishlisted: store.isInWishlist(item.id),
                          onToggleWishlist: () => store.toggleWishlist(item.id),
                          onAddToCart: () => _addToCart(store, item),
                          onTap: () => Nav.replace(
                            context,
                            AppRoutes.productDetails,
                            ProductDetailsArgs(item.id),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
      bottomNavigationBar: _AddToCartBar(
        product: product,
        quantity: _quantity,
        inCart: inCart,
        onIncrement: product.stock > inCart + _quantity
            ? () => setState(() => _quantity++)
            : null,
        onDecrement: _quantity > 1 ? () => setState(() => _quantity--) : null,
        onAdd: () => _addToCart(store, product, quantity: _quantity),
      ),
    );
  }

  void _addToCart(
    StoreService store,
    ProductModel product, {
    int quantity = 1,
  }) {
    store.addToCart(product, quantity: quantity);
    setState(() => _quantity = 1);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('${product.name} added to cart'),
          action: SnackBarAction(
            label: 'Checkout',
            onPressed: () => Nav.push(context, AppRoutes.cart),
          ),
        ),
      );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.product});

  final ProductModel product;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final items = <(IconData, String, String)>[
      (
        Icons.local_shipping_rounded,
        product.freeShipping ? 'Free delivery' : 'Paid delivery',
        product.freeShipping ? 'On this item' : 'Calculated at checkout',
      ),
      (Icons.autorenew_rounded, 'Easy returns', '30 day window'),
      (Icons.verified_user_rounded, 'Authenticity', 'Verified by PetHub'),
    ];

    return Row(
      children: [
        for (final (index, item) in items.indexed) ...[
          if (index > 0) Gap.w8,
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(AppConstants.radiusSm),
              ),
              child: Column(
                children: [
                  Icon(item.$1, size: 20, color: scheme.primary),
                  Gap.h8,
                  Text(
                    item.$2,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    item.$3,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 9.5,
                      color: scheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _AddToCartBar extends StatelessWidget {
  const _AddToCartBar({
    required this.product,
    required this.quantity,
    required this.inCart,
    required this.onIncrement,
    required this.onDecrement,
    required this.onAdd,
  });

  final ProductModel product;
  final int quantity;
  final int inCart;
  final VoidCallback? onIncrement;
  final VoidCallback? onDecrement;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final total = product.price * quantity;

    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        12 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: scheme.outline)),
      ),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: onDecrement,
                  icon: const Icon(Icons.remove_rounded, size: 18),
                  visualDensity: VisualDensity.compact,
                ),
                Text(
                  '$quantity',
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                IconButton(
                  onPressed: onIncrement,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
          Gap.w12,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (inCart > 0)
                  Text(
                    '$inCart already in cart',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                Text(
                  Helpers.currencyPrecise(total),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: scheme.primary,
                  ),
                ),
              ],
            ),
          ),
          Gap.w8,
          SizedBox(
            width: 140,
            child: CustomButton(
              label: 'Add to cart',
              icon: Icons.add_shopping_cart_rounded,
              expand: false,
              onPressed: product.inStock ? onAdd : null,
            ),
          ),
        ],
      ),
    );
  }
}
