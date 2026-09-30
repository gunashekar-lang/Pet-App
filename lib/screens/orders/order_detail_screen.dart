import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/routes.dart';
import '../../models/order_model.dart';
import '../../models/product_model.dart';
import '../../services/store_service.dart';
import '../../utils/constants.dart';
import '../../utils/helpers.dart';
import '../../widgets/common.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/section_header.dart';
import 'orders_screen.dart';

class OrderDetailScreen extends StatelessWidget {
  const OrderDetailScreen({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<StoreService>();
    final scheme = Theme.of(context).colorScheme;
    OrderModel? match;

    for (final o in store.orders) {
      if (o.id == orderId) {
        match = o;
        break;
      }
    }
    final order = match;

    if (order == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyState(
          icon: Icons.receipt_long_outlined,
          title: 'Order not found',
          message: 'We could not find that order. It may have been removed.',
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Order details'),
        leading: IconButton(
          onPressed: () => Nav.pop(context),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      bottomNavigationBar: order.status == OrderStatus.delivered
          ? Container(
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
                label: 'Buy again',
                icon: Icons.refresh_rounded,
                onPressed: () {
                  for (final item in order.items) {
                    store.addToCart(item.product, quantity: item.quantity);
                  }
                  Nav.push(context, AppRoutes.cart);
                },
              ),
            )
          : null,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          AppCard(
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: order.status.color.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        order.status.icon,
                        size: 22,
                        color: order.status.color,
                      ),
                    ),
                    Gap.w12,
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            order.status.label,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            order.status == OrderStatus.delivered
                                ? 'Delivered ${Helpers.dayMonth(order.placedAt)}'
                                : 'Placed ${Helpers.date(order.placedAt)} at ${Helpers.time(order.placedAt)}',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: scheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (order.isActive) ...[
                  Gap.h16,
                  OrderProgress(status: order.status),
                ],
              ],
            ),
          ),
          Gap.h20,
          const Text(
            'Items',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          Gap.h12,
          for (final item in order.items)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: AppCard(
                padding: const EdgeInsets.all(10),
                onTap: () => Nav.push(
                  context,
                  AppRoutes.productDetails,
                  ProductDetailsArgs(item.product.id),
                ),
                child: Row(
                  children: [
                    AppImage(
                      url: item.product.imageUrl,
                      width: 58,
                      height: 58,
                      borderRadius: BorderRadius.circular(10),
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
                          const SizedBox(height: 3),
                          Text(
                            'Qty ${item.quantity} · ${Helpers.currencyPrecise(item.product.price)} each',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: scheme.onSurface.withValues(alpha: 0.55),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      Helpers.currencyPrecise(item.total),
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Gap.h8,
          AppCard(
            child: Column(
              children: [
                _Line(
                  label: 'Subtotal',
                  value: Helpers.currencyPrecise(order.subtotal),
                ),
                Gap.h8,
                _Line(
                  label: 'Delivery',
                  value: order.shipping == 0
                      ? 'Free'
                      : Helpers.currencyPrecise(order.shipping),
                ),
                Gap.h8,
                _Line(label: 'Tax', value: Helpers.currencyPrecise(order.tax)),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Divider(),
                ),
                Row(
                  children: [
                    const Text(
                      'Total paid',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      Helpers.currencyPrecise(order.total),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: scheme.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Gap.h20,
          const Text(
            'Delivery & payment',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          Gap.h12,
          AppCard(
            child: Column(
              children: [
                _DetailRow(
                  icon: Icons.location_on_outlined,
                  title: 'Delivery address',
                  value: order.deliveryAddress,
                ),
                Gap.h12,
                _DetailRow(
                  icon: Icons.credit_card_rounded,
                  title: 'Payment method',
                  value: order.paymentMethod,
                ),
                if (order.trackingNumber != null) ...[
                  Gap.h12,
                  _DetailRow(
                    icon: Icons.local_shipping_rounded,
                    title: 'Tracking number',
                    value: order.trackingNumber!,
                  ),
                ],
                if (order.estimatedDelivery != null) ...[
                  Gap.h12,
                  _DetailRow(
                    icon: Icons.event_available_rounded,
                    title: 'Estimated delivery',
                    value:
                        '${Helpers.dayMonth(order.estimatedDelivery!)} • ${Helpers.time(order.estimatedDelivery!)}',
                  ),
                ],
              ],
            ),
          ),
          Gap.h20,
          if (order.isActive)
            OutlinedButton.icon(
              onPressed: () => _confirmCancel(context, store, order),
              icon: const Icon(Icons.cancel_rounded, size: 18),
              label: const Text('Cancel order'),
              style: OutlinedButton.styleFrom(
                foregroundColor: scheme.error,
                side: BorderSide(color: scheme.error.withValues(alpha: 0.5)),
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _confirmCancel(
    BuildContext context,
    StoreService store,
    OrderModel order,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Cancel this order?'),
        content: Text('Order ${order.id} will be cancelled and refunded.'),
        actions: [
          TextButton(
            onPressed: () => Nav.pop(context, false),
            child: const Text('Keep order'),
          ),
          FilledButton(
            onPressed: () => Nav.pop(context, true),
            child: const Text('Cancel order'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    store.cancelOrder(order.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Order cancelled')));
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.label, required this.value});

  final String label;
  final String value;

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
          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: scheme.primary),
        Gap.w12,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: scheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
