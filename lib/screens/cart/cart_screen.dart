import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/routes.dart';
import '../../models/product_model.dart';
import '../../services/notification_service.dart';
import '../../services/store_service.dart';
import '../../utils/constants.dart';
import '../../utils/helpers.dart';
import '../../widgets/common.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/section_header.dart';

/// Cart + checkout: line items, promo code, address, payment and place order.
class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final _promoController = TextEditingController();
  String _promoCode = '';

  static const String _promo = 'PETHUB10';

  @override
  void dispose() {
    _promoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<StoreService>();
    final scheme = Theme.of(context).colorScheme;
    final items = store.cart;
    final discount = _promoCode == _promo ? store.cartSubtotal * 0.1 : 0.0;
    final total = store.cartTotal - discount;
    final freeShippingGap = store.freeShippingGap;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your cart'),
        leading: IconButton(
          onPressed: () => Nav.pop(context),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        actions: [
          if (items.isNotEmpty)
            TextButton(
              onPressed: () => _confirmClear(store),
              child: Text(
                'Clear',
                style: TextStyle(
                  color: scheme.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
      body: items.isEmpty
          ? EmptyState(
              icon: Icons.shopping_cart_outlined,
              title: 'Your cart is empty',
              message:
                  'Browse the store and add the essentials your pet needs. '
                  'Free delivery kicks in at ₹499.',
              actionLabel: 'Start shopping',
              onAction: () => Nav.pop(context),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                if (freeShippingGap > 0) ...[
                  InfoBanner(
                    icon: Icons.local_shipping_rounded,
                    title:
                        'Add ${Helpers.currencyPrecise(freeShippingGap)} more for free delivery',
                    message:
                        'You are ${((store.cartSubtotal / freeShippingThreshold) * 100).clamp(0, 99).toStringAsFixed(0)}% of the way to free shipping.',
                    color: AppColors.accent,
                  ),
                  Gap.h16,
                ] else ...[
                  const InfoBanner(
                    icon: Icons.celebration_rounded,
                    title: 'You have earned free delivery',
                    message: 'Nice! Your order ships free of charge.',
                    color: AppColors.success,
                  ),
                  Gap.h16,
                ],
                for (final item in items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _CartItemTile(
                      item: item,
                      onIncrement: () => store.updateQuantity(
                        item.product.id,
                        item.quantity + 1,
                      ),
                      onDecrement: item.quantity == 1
                          ? () => store.removeFromCart(item.product.id)
                          : () => store.updateQuantity(
                              item.product.id,
                              item.quantity - 1,
                            ),
                      onRemove: () => store.removeFromCart(item.product.id),
                      onTap: () => Nav.push(
                        context,
                        AppRoutes.productDetails,
                        ProductDetailsArgs(item.product.id),
                      ),
                    ),
                  ),
                Gap.h4,
                _PromoField(
                  controller: _promoController,
                  applied: _promoCode.isNotEmpty,
                  onApply: _applyPromo,
                  onClear: () => setState(() => _promoCode = ''),
                ),
                Gap.h20,
                AppCard(
                  child: Column(
                    children: [
                      _SummaryRow(
                        label: 'Subtotal',
                        value: Helpers.currencyPrecise(store.cartSubtotal),
                      ),
                      Gap.h8,
                      _SummaryRow(
                        label: 'Delivery',
                        value: store.cartShipping == 0
                            ? 'Free'
                            : Helpers.currencyPrecise(store.cartShipping),
                        valueColor: store.cartShipping == 0
                            ? AppColors.success
                            : null,
                      ),
                      Gap.h8,
                      _SummaryRow(
                        label: 'Tax (8%)',
                        value: Helpers.currencyPrecise(store.cartTax),
                      ),
                      if (discount > 0) ...[
                        Gap.h8,
                        _SummaryRow(
                          label: 'Promo $_promo',
                          value: '-${Helpers.currencyPrecise(discount)}',
                          valueColor: AppColors.success,
                        ),
                      ],
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Divider(),
                      ),
                      Row(
                        children: [
                          const Text(
                            'Total',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            Helpers.currencyPrecise(total),
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: scheme.primary,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
      bottomNavigationBar: items.isEmpty
          ? null
          : Container(
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
              child: CustomButton(
                label: 'Checkout · ${Helpers.currencyPrecise(total)}',
                icon: Icons.lock_rounded,
                isLoading: store.isPlacingOrder,
                onPressed: () => _checkout(context, store, total),
              ),
            ),
    );
  }

  void _applyPromo() {
    final code = _promoController.text.trim().toUpperCase();
    setState(() => _promoCode = code == _promo ? code : '');
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            code == _promo
                ? 'Promo applied — you saved 10%'
                : 'That promo code is not valid',
          ),
        ),
      );
  }

  Future<void> _confirmClear(StoreService store) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Remove all items?'),
        content: const Text('Your cart will be emptied.'),
        actions: [
          TextButton(
            onPressed: () => Nav.pop(context, false),
            child: const Text('Keep items'),
          ),
          FilledButton(
            onPressed: () => Nav.pop(context, true),
            child: const Text('Clear cart'),
          ),
        ],
      ),
    );
    if (confirmed == true) store.clearCart();
  }

  Future<void> _checkout(
    BuildContext context,
    StoreService store,
    double total,
  ) async {
    final result = await showModalBottomSheet<_CheckoutResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const _CheckoutSheet(),
    );

    if (result == null || !context.mounted) return;

    try {
      final order = await store.placeOrder(
        address: result.address,
        paymentMethod: result.paymentLabel,
      );
      if (!context.mounted) return;
      context.read<NotificationService>().orderUpdate(
        orderId: order.id,
        message: 'We will notify you when your order is packed and on its way.',
      );
      await showDialog<void>(
        context: context,
        builder: (context) => _OrderSuccessDialog(orderId: order.id),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Could not place the order. Try again.'),
          ),
        );
    }
  }
}

class _CartItemTile extends StatelessWidget {
  const _CartItemTile({
    required this.item,
    required this.onIncrement,
    required this.onDecrement,
    required this.onRemove,
    required this.onTap,
  });

  final CartItem item;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onRemove;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AppCard(
      padding: const EdgeInsets.all(10),
      onTap: onTap,
      child: Row(
        children: [
          AppImage(
            url: item.product.imageUrl,
            width: 72,
            height: 72,
            borderRadius: BorderRadius.circular(12),
            icon: item.product.category.icon,
          ),
          Gap.w12,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.product.brand,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: scheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
                Gap.h8,
                Row(
                  children: [
                    _QtyButton(icon: Icons.remove_rounded, onTap: onDecrement),
                    Container(
                      width: 30,
                      alignment: Alignment.center,
                      child: Text(
                        '${item.quantity}',
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    _QtyButton(icon: Icons.add_rounded, onTap: onIncrement),
                    Gap.w8,
                    Text(
                      Helpers.currencyPrecise(item.total),
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: scheme.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.delete_outline_rounded, size: 20),
            color: scheme.onSurface.withValues(alpha: 0.45),
            tooltip: 'Remove',
          ),
        ],
      ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  const _QtyButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 28,
          height: 28,
          child: Icon(icon, size: 15, color: scheme.onSurface),
        ),
      ),
    );
  }
}

class _PromoField extends StatelessWidget {
  const _PromoField({
    required this.controller,
    required this.applied,
    required this.onApply,
    required this.onClear,
  });

  final TextEditingController controller;
  final bool applied;
  final VoidCallback onApply;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Icon(Icons.local_offer_outlined, size: 20, color: scheme.primary),
          Gap.w12,
          Expanded(
            child: TextField(
              controller: controller,
              textCapitalization: TextCapitalization.characters,
              readOnly: applied,
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: applied ? 'PETHUB10 applied' : 'Promo code',
                hintStyle: TextStyle(
                  fontSize: 13.5,
                  color: scheme.onSurface.withValues(alpha: 0.45),
                ),
              ),
            ),
          ),
          if (applied)
            TextButton(onPressed: onClear, child: const Text('Remove'))
          else
            FilledButton(
              onPressed: onApply,
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 38),
                padding: const EdgeInsets.symmetric(horizontal: 18),
              ),
              child: const Text('Apply'),
            ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13.5,
            color: scheme.onSurface.withValues(alpha: 0.65),
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}

class _CheckoutResult {
  const _CheckoutResult({required this.address, required this.paymentLabel});

  final String address;
  final String paymentLabel;
}

class _CheckoutSheet extends StatefulWidget {
  const _CheckoutSheet();

  @override
  State<_CheckoutSheet> createState() => _CheckoutSheetState();
}

class _CheckoutSheetState extends State<_CheckoutSheet> {
  final _addressController = TextEditingController(
    text: '18 Riverview Lane, Austin, TX 78704',
  );
  String _payment = 'Card •••• 4242';
  bool _sameAsProfile = true;

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const methods = [
      ('Card •••• 4242', Icons.credit_card_rounded),
      ('Apple Pay', Icons.phone_iphone_rounded),
      ('PayPal', Icons.account_balance_wallet_rounded),
      ('Cash on delivery', Icons.payments_rounded),
    ];

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      maxChildSize: 0.95,
      builder: (context, controller) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 12, 4),
            child: Row(
              children: [
                const Text(
                  'Checkout',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                const Spacer(),
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
              controller: controller,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              children: [
                const Text(
                  'Delivery address',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                ),
                Gap.h10,
                TextField(
                  controller: _addressController,
                  maxLines: 2,
                  readOnly: _sameAsProfile,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: scheme.surfaceContainerHighest.withValues(
                      alpha: 0.5,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: scheme.outline),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: scheme.outline),
                    ),
                    prefixIcon: const Icon(
                      Icons.location_on_outlined,
                      size: 20,
                    ),
                  ),
                ),
                SwitchListTile(
                  value: _sameAsProfile,
                  onChanged: (value) => setState(() => _sameAsProfile = value),
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Use my saved address',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Gap.h12,
                const Text(
                  'Payment method',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                ),
                Gap.h10,
                for (final (label, icon) in methods)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: AppCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      borderColor: _payment == label ? scheme.primary : null,
                      color: _payment == label
                          ? scheme.primary.withValues(alpha: 0.06)
                          : null,
                      onTap: () => setState(() => _payment = label),
                      child: Row(
                        children: [
                          Icon(icon, size: 20, color: scheme.onSurface),
                          Gap.w12,
                          Expanded(
                            child: Text(
                              label,
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Icon(
                            _payment == label
                                ? Icons.radio_button_checked_rounded
                                : Icons.radio_button_off_rounded,
                            size: 20,
                            color: _payment == label
                                ? scheme.primary
                                : scheme.onSurface.withValues(alpha: 0.35),
                          ),
                        ],
                      ),
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
                label: 'Place order',
                icon: Icons.lock_rounded,
                isLoading: context.watch<StoreService>().isPlacingOrder,
                onPressed: () => Nav.pop(
                  context,
                  _CheckoutResult(
                    address: _addressController.text.trim().isEmpty
                        ? '18 Riverview Lane, Austin, TX 78704'
                        : _addressController.text.trim(),
                    paymentLabel: _payment,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderSuccessDialog extends StatelessWidget {
  const _OrderSuccessDialog({required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              color: Color(0x1A12B886),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_rounded,
              size: 38,
              color: AppColors.success,
            ),
          ),
          Gap.h20,
          const Text(
            'Order confirmed! 🎉',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          Gap.h8,
          Text(
            'Order $orderId is being prepared. We will notify you when it ships.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              height: 1.5,
              color: scheme.onSurface.withValues(alpha: 0.65),
            ),
          ),
        ],
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(
          onPressed: () => Nav.pop(context),
          child: const Text('Keep shopping'),
        ),
        FilledButton(
          onPressed: () {
            Nav.pop(context);
            Nav.replace(context, AppRoutes.orders);
          },
          child: const Text('Track order'),
        ),
      ],
    );
  }
}
