import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/product_model.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import 'common.dart';

/// Grid / carousel product card for the Pet Store.
class ProductCard extends StatelessWidget {
  const ProductCard({
    super.key,
    required this.product,
    required this.onTap,
    this.onAddToCart,
    this.onToggleWishlist,
    this.isWishlisted = false,
    this.width,
  });

  final ProductModel product;
  final VoidCallback onTap;
  final VoidCallback? onAddToCart;
  final VoidCallback? onToggleWishlist;
  final bool isWishlisted;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return SizedBox(
      width: width,
      child: Material(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppConstants.radiusMd),
              border: Border.all(color: scheme.outline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                AspectRatio(
                  aspectRatio: 1.05,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      AppImage(
                        url: product.imageUrl,
                        icon: product.category.icon,
                        gradientColors: [
                          scheme.secondary.withValues(alpha: 0.2),
                          scheme.secondary.withValues(alpha: 0.06),
                        ],
                      ),
                      if (product.onSale)
                        Positioned(
                          left: 8,
                          top: 8,
                          child: StatusPill(
                            label: '-${product.discountPercent}%',
                            color: AppColors.danger,
                            solid: true,
                            dense: true,
                          ),
                        ),
                      if (product.isBestSeller)
                        Positioned(
                          left: 8,
                          top: product.onSale ? 32 : 8,
                          child: const StatusPill(
                            label: 'Best seller',
                            icon: Icons.workspace_premium_rounded,
                            color: AppColors.warning,
                            solid: true,
                            dense: true,
                          ),
                        ),
                      if (onToggleWishlist != null)
                        Positioned(
                          right: 8,
                          top: 8,
                          child: Material(
                            color: Colors.white,
                            shape: CircleBorder(
                              side: BorderSide(
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              onTap: onToggleWishlist,
                              child: SizedBox(
                                width: 30,
                                height: 30,
                                child: Icon(
                                  isWishlisted
                                      ? Icons.favorite_rounded
                                      : Icons.favorite_border_rounded,
                                  size: 16,
                                  color: isWishlisted
                                      ? AppColors.danger
                                      : const Color(0xFF6B7280),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        product.brand.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                          color: scheme.onSurface.withValues(alpha: 0.45),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        product.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.star_rounded,
                            size: 14,
                            color: AppColors.warning,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            product.rating.toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            ' (${_compact(product.reviewCount)})',
                            style: TextStyle(
                              fontSize: 10.5,
                              color: scheme.onSurface.withValues(alpha: 0.45),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            Helpers.currencyPrecise(product.price),
                            style: TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w800,
                              color: scheme.primary,
                              letterSpacing: -0.3,
                            ),
                          ),
                          if (product.onSale) ...[
                            Gap.w6,
                            Text(
                              Helpers.currencyPrecise(product.oldPrice!),
                              style: TextStyle(
                                fontSize: 11,
                                color: scheme.onSurface.withValues(alpha: 0.4),
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                          ],
                          const Spacer(),
                          if (onAddToCart != null)
                            _AddButton(
                              enabled: product.inStock,
                              onTap: () {
                                HapticFeedback.lightImpact();
                                onAddToCart!();
                              },
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _compact(int value) {
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}k';
    return '$value';
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.onTap, required this.enabled});

  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: enabled ? scheme.primary : scheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: SizedBox(
          width: 32,
          height: 32,
          child: Icon(
            Icons.add_shopping_cart_rounded,
            size: 16,
            color: enabled
                ? Colors.white
                : scheme.onSurface.withValues(alpha: 0.4),
          ),
        ),
      ),
    );
  }
}

/// Horizontal product card used in carousel rows.
class ProductListTile extends StatelessWidget {
  const ProductListTile({
    super.key,
    required this.product,
    required this.onTap,
    this.onAddToCart,
    this.quantityInCart = 0,
  });

  final ProductModel product;
  final VoidCallback onTap;
  final VoidCallback? onAddToCart;
  final int quantityInCart;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(AppConstants.radiusMd),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppConstants.radiusMd),
            border: Border.all(color: scheme.outline),
          ),
          child: Row(
            children: [
              AppImage(
                url: product.imageUrl,
                width: 76,
                height: 76,
                borderRadius: BorderRadius.circular(AppConstants.radiusSm + 2),
                icon: product.category.icon,
              ),
              Gap.w12,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      product.brand.toUpperCase(),
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                        color: scheme.onSurface.withValues(alpha: 0.45),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          Helpers.currencyPrecise(product.price),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: scheme.primary,
                          ),
                        ),
                        if (product.onSale) ...[
                          Gap.w6,
                          Text(
                            Helpers.currencyPrecise(product.oldPrice!),
                            style: TextStyle(
                              fontSize: 11,
                              color: scheme.onSurface.withValues(alpha: 0.4),
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (onAddToCart != null)
                quantityInCart > 0
                    ? StatusPill(
                        label: '$quantityInCart',
                        icon: Icons.check_rounded,
                        color: AppColors.success,
                        solid: true,
                      )
                    : Material(
                        color: scheme.primary,
                        borderRadius: BorderRadius.circular(10),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: onAddToCart,
                          child: const SizedBox(
                            width: 34,
                            height: 34,
                            child: Icon(
                              Icons.add_shopping_cart_rounded,
                              size: 17,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
            ],
          ),
        ),
      ),
    );
  }
}
