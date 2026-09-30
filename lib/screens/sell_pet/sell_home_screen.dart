import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/routes.dart';
import '../../services/store_service.dart';
import '../../utils/constants.dart';
import '../../widgets/common.dart';
import '../../widgets/section_header.dart';

/// Landing screen for the Sell tab. Offers the two things a user can list:
/// a pet, or a product from their own shop.
class SellHomeScreen extends StatelessWidget {
  const SellHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Sell')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
        children: [
          Text(
            'What do you want to sell?',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: scheme.onSurface,
            ),
          ),
          Gap.h6,
          Text(
            'List a pet for adoption, or open a product listing on your own '
            'shop.',
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: scheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          Gap.h24,
          _SellOptionCard(
            icon: Icons.pets_rounded,
            title: 'Sell a pet',
            subtitle:
                'Create a pet listing with photos, vaccination history and '
                'health details.',
            onTap: () => Nav.push(context, AppRoutes.sellPet),
          ),
          Gap.h12,
          _SellOptionCard(
            icon: Icons.inventory_2_rounded,
            title: 'Sell a product',
            subtitle:
                'Add stock to your shop. Your listings carry your shop name '
                'and verification badge.',
            onTap: () => Nav.push(context, AppRoutes.sellProduct),
          ),
          Gap.h24,
          const _MyShopCard(),
        ],
      ),
    );
  }
}

class _SellOptionCard extends StatelessWidget {
  const _SellOptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: scheme.onPrimaryContainer, size: 26),
          ),
          Gap.w12,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
                Gap.h4,
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color: scheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                Gap.h8,
                Row(
                  children: [
                    Text(
                      'Continue',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: scheme.primary,
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 16,
                      color: scheme.primary,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Summary of the seller's own shop: name, live listing count and whether the
/// shop is verified.
class _MyShopCard extends StatelessWidget {
  const _MyShopCard();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final store = context.watch<StoreService>();
    final verified = store.shopVerified;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.storefront_rounded,
                  color: scheme.onSurface.withValues(alpha: 0.75),
                ),
              ),
              Gap.w12,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            store.shopName,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w700,
                              color: scheme.onSurface,
                            ),
                          ),
                        ),
                        if (verified) ...[
                          Gap.w6,
                          Icon(
                            Icons.verified_rounded,
                            size: 17,
                            color: scheme.primary,
                          ),
                        ],
                      ],
                    ),
                    Gap.h4,
                    Text(
                      verified ? 'Verified shop' : 'Verification pending',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: verified
                            ? scheme.primary
                            : scheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Gap.h12,
          Text(
            '${store.shopProductCount} '
            '${store.shopProductCount == 1 ? 'listing' : 'listings'} in your shop',
            style: TextStyle(
              fontSize: 13,
              color: scheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          Gap.h12,
          if (!verified)
            InfoBanner(
              icon: Icons.shield_outlined,
              title: 'Complete verification to earn the badge',
              message:
                  'Verification unlocks a verified badge on your shop and '
                  'every product you list.',
            ),
        ],
      ),
    );
  }
}
