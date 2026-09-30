import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/routes.dart';
import '../../models/order_model.dart';
import '../../models/product_model.dart';
import '../../services/store_service.dart';
import '../../utils/constants.dart';
import '../../utils/helpers.dart';
import '../../widgets/common.dart';
import '../../widgets/section_header.dart';

/// Order history with Active / Past tabs and inline status tracking.
class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  String _tab = 'Active';

  @override
  Widget build(BuildContext context) {
    final store = context.watch<StoreService>();
    final orders = _tab == 'Active' ? store.activeOrders : store.pastOrders;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My orders'),
        leading: IconButton(
          onPressed: () => Nav.pop(context),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Row(
              children: [
                for (final tab in ['Active', 'Past']) ...[
                  if (tab != 'Active') Gap.w8,
                  ChoiceChip(
                    label: Text(tab),
                    selected: _tab == tab,
                    onSelected: (_) => setState(() => _tab = tab),
                    showCheckmark: false,
                    backgroundColor: Theme.of(context).colorScheme.surface,
                    selectedColor: Theme.of(context).colorScheme.primary,
                    labelStyle: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _tab == tab
                          ? Colors.white
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: orders.isEmpty
                ? EmptyState(
                    icon: _tab == 'Active'
                        ? Icons.local_shipping_outlined
                        : Icons.history_rounded,
                    title: _tab == 'Active'
                        ? 'No active orders'
                        : 'No past orders',
                    message: _tab == 'Active'
                        ? 'When you place an order it will show up here with live '
                              'tracking.'
                        : 'Completed and cancelled orders will appear here.',
                    actionLabel: _tab == 'Active' ? 'Browse the store' : null,
                    onAction: _tab == 'Active' ? () => Nav.pop(context) : null,
                  )
                : RefreshIndicator(
                    onRefresh: store.refresh,
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                      itemCount: orders.length,
                      itemBuilder: (context, i) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _OrderCard(
                          order: orders[i],
                          onTap: () => Nav.push(
                            context,
                            AppRoutes.orderDetails,
                            OrderDetailsArgs(orders[i].id),
                          ),
                          onCancel: () => _cancel(context, store, orders[i]),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _cancel(
    BuildContext context,
    StoreService store,
    OrderModel order,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Cancel this order?'),
        content: Text(
          'Order ${order.id} will be cancelled. Any amount paid is refunded to '
          'your original payment method within 3-5 business days.',
        ),
        actions: [
          TextButton(
            onPressed: () => Nav.pop(context, false),
            child: const Text('Keep order'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
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

class _OrderCard extends StatelessWidget {
  const _OrderCard({
    required this.order,
    required this.onTap,
    required this.onCancel,
  });

  final OrderModel order;
  final VoidCallback onTap;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final preview = order.items.take(3).toList();
    final extra = order.items.length - preview.length;

    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Order ${order.id}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Gap.w8,
              StatusPill(
                label: order.status.label,
                icon: order.status.icon,
                color: order.status.color,
                solid: true,
                dense: true,
              ),
              const Spacer(),
              Text(
                Helpers.relativeTime(order.placedAt),
                style: TextStyle(
                  fontSize: 11.5,
                  color: scheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
          Gap.h12,
          Row(
            children: [
              for (final item in preview) ...[
                AppImage(
                  url: item.product.imageUrl,
                  width: 52,
                  height: 52,
                  borderRadius: BorderRadius.circular(10),
                  icon: item.product.category.icon,
                ),
                Gap.w8,
              ],
              if (extra > 0)
                Container(
                  width: 52,
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '+$extra',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${order.itemCount} ${order.itemCount == 1 ? 'item' : 'items'}',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: scheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    Helpers.currencyPrecise(order.total),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: scheme.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (order.isActive) ...[
            Gap.h12,
            OrderProgress(status: order.status),
            Gap.h12,
            Row(
              children: [
                if (order.trackingNumber != null) ...[
                  Icon(
                    Icons.local_shipping_outlined,
                    size: 15,
                    color: scheme.onSurface.withValues(alpha: 0.5),
                  ),
                  Gap.w4,
                  Text(
                    order.trackingNumber!,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: scheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
                const Spacer(),
                TextButton(
                  onPressed: onCancel,
                  style: TextButton.styleFrom(
                    foregroundColor: scheme.error,
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Compact horizontal status tracker for a store order.
class OrderProgress extends StatelessWidget {
  const OrderProgress({super.key, required this.status});

  final OrderStatus status;

  static const List<OrderStatus> _steps = [
    OrderStatus.placed,
    OrderStatus.confirmed,
    OrderStatus.shipped,
    OrderStatus.delivered,
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (status == OrderStatus.cancelled) {
      return InfoBanner(
        icon: Icons.cancel_rounded,
        title: 'Order cancelled',
        message: 'This order was cancelled and any refund is on its way.',
        color: AppColors.danger,
      );
    }

    final currentIndex = _steps.indexOf(status);

    return Row(
      children: [
        for (final (index, step) in _steps.indexed) ...[
          if (index > 0)
            Expanded(
              child: Container(
                height: 3,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: index <= currentIndex
                      ? AppColors.success
                      : scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: index <= currentIndex
                      ? AppColors.success
                      : scheme.surfaceContainerHighest,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  index < currentIndex ? Icons.check_rounded : step.icon,
                  size: 12,
                  color: index <= currentIndex
                      ? Colors.white
                      : scheme.onSurface.withValues(alpha: 0.4),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                step.label,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                  color: index <= currentIndex
                      ? scheme.onSurface
                      : scheme.onSurface.withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
