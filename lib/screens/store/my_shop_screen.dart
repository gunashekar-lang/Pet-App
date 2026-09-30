import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/routes.dart';
import '../../models/product_model.dart';
import '../../services/store_service.dart';
import '../../utils/constants.dart';
import '../../utils/helpers.dart';
import '../../widgets/common.dart';
import '../../widgets/section_header.dart';

/// The seller's own shop: their product listings plus the shop's verification
/// state. Reached after publishing a product.
class MyShopScreen extends StatelessWidget {
  const MyShopScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final store = context.watch<StoreService>();
    final products = store.myShopProducts;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My shop'),
        actions: [
          TextButton.icon(
            onPressed: () => Nav.push(context, AppRoutes.sellProduct),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Add'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.storefront_rounded,
                        color: scheme.onPrimaryContainer,
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
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    color: scheme.onSurface,
                                  ),
                                ),
                              ),
                              if (store.shopVerified) ...[
                                Gap.w6,
                                Icon(
                                  Icons.verified_rounded,
                                  size: 18,
                                  color: scheme.primary,
                                ),
                              ],
                            ],
                          ),
                          Gap.h4,
                          Text(
                            store.shopVerified
                                ? 'Verified shop'
                                : 'Verification pending',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: store.shopVerified
                                  ? scheme.primary
                                  : scheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (store.shopTagline.isNotEmpty) ...[
                  Gap.h12,
                  Text(
                    store.shopTagline,
                    style: TextStyle(
                      fontSize: 13.5,
                      height: 1.5,
                      color: scheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ],
                Gap.h16,
                Row(
                  children: [
                    _Stat(
                      label: 'Listings',
                      value: '${store.shopProductCount}',
                    ),
                    Gap.w24,
                    _Stat(
                      label: 'In stock',
                      value: '${products.where((p) => p.inStock).length}',
                    ),
                  ],
                ),
              ],
            ),
          ),
          Gap.h16,
          if (!store.shopVerified) ...[
            InfoBanner(
              icon: Icons.shield_outlined,
              title: 'Shop not verified yet',
              message:
                  'Buyers see a verification badge once your shop is '
                  'verified. It applies to every product you list.',
              trailing: TextButton(
                onPressed: () => _showVerificationSheet(context),
                child: const Text('Start'),
              ),
            ),
            Gap.h16,
          ],
          Text(
            'Your listings',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: scheme.onSurface,
            ),
          ),
          Gap.h12,
          if (products.isEmpty)
            EmptyState(
              icon: Icons.inventory_2_outlined,
              title: 'No products yet',
              message:
                  'List your first product and it will appear here with your '
                  'shop name.',
              actionLabel: 'List a product',
              onAction: () => Nav.push(context, AppRoutes.sellProduct),
            )
          else
            for (final product in products)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _ShopProductTile(product: product),
              ),
        ],
      ),
    );
  }

  void _showVerificationSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => const _VerificationSheet(),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: scheme.onSurface,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            color: scheme.onSurface.withValues(alpha: 0.65),
          ),
        ),
      ],
    );
  }
}

class _ShopProductTile extends StatelessWidget {
  const _ShopProductTile({required this.product});

  final ProductModel product;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AppCard(
      onTap: () => Nav.push(
        context,
        AppRoutes.productDetails,
        ProductDetailsArgs(product.id),
      ),
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          AppImage(
            url: product.imageUrl,
            width: 58,
            height: 58,
            borderRadius: BorderRadius.circular(10),
            icon: Icons.inventory_2_rounded,
          ),
          Gap.w12,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
                Gap.h4,
                Row(
                  children: [
                    if (product.shopVerified) ...[
                      Icon(
                        Icons.verified_rounded,
                        size: 13,
                        color: scheme.primary,
                      ),
                      Gap.w4,
                    ],
                    Flexible(
                      child: Text(
                        product.shopName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: scheme.onSurface.withValues(alpha: 0.65),
                        ),
                      ),
                    ),
                  ],
                ),
                Gap.h4,
                Text(
                  Helpers.currency(product.price),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: scheme.primary,
                  ),
                ),
              ],
            ),
          ),
          if (!product.inStock)
            Text(
              'Out of stock',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: scheme.error,
              ),
            ),
        ],
      ),
    );
  }
}

/// Local stand-in for the backend verification review. In production this
/// sheet submits documents and waits for an admin decision; here it flips the
/// local flag so the badge flow is testable.
class _VerificationSheet extends StatefulWidget {
  const _VerificationSheet();

  @override
  State<_VerificationSheet> createState() => _VerificationSheetState();
}

class _VerificationSheetState extends State<_VerificationSheet> {
  final _nameController = TextEditingController();
  final _taglineController = TextEditingController();
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    final store = context.read<StoreService>();
    _nameController.text = store.shopName;
    _taglineController.text = store.shopTagline;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _taglineController.dispose();
    super.dispose();
  }

  void _submit() {
    final store = context.read<StoreService>();
    store.updateShop(
      name: _nameController.text,
      tagline: _taglineController.text,
    );
    store.setShopVerified(true);
    setState(() => _submitted = true);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (_submitted) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.verified_rounded, size: 56, color: scheme.primary),
            Gap.h16,
            Text(
              'Shop verified',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: scheme.onSurface,
              ),
            ),
            Gap.h6,
            Text(
              'Your verified badge now shows on ${_nameController.text.trim()} '
              'and every product you list.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.5,
                color: scheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            Gap.h40,
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Done'),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        24,
        20,
        24 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Verify your shop',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: scheme.onSurface,
              ),
            ),
            Gap.h6,
            Text(
              'Verification is reviewed before the badge appears. In this '
              'build it is applied immediately.',
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: scheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            Gap.h40,
            TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Shop name'),
            ),
            Gap.h12,
            TextField(
              controller: _taglineController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Tagline',
                hintText: 'What your shop sells',
              ),
            ),
            Gap.h40,
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _nameController.text.trim().isEmpty ? null : _submit,
                icon: const Icon(Icons.shield_rounded, size: 18),
                label: const Text('Submit for verification'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
