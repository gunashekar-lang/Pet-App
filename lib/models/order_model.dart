import 'package:flutter/material.dart';

import 'product_model.dart';

enum OrderStatus { placed, confirmed, shipped, delivered, cancelled }

extension OrderStatusX on OrderStatus {
  String get label => switch (this) {
    OrderStatus.placed => 'Placed',
    OrderStatus.confirmed => 'Confirmed',
    OrderStatus.shipped => 'Shipped',
    OrderStatus.delivered => 'Delivered',
    OrderStatus.cancelled => 'Cancelled',
  };

  Color get color => switch (this) {
    OrderStatus.placed => const Color(0xFF2F80ED),
    OrderStatus.confirmed => const Color(0xFF8B5CF6),
    OrderStatus.shipped => const Color(0xFFF5A524),
    OrderStatus.delivered => const Color(0xFF12B886),
    OrderStatus.cancelled => const Color(0xFFEF4444),
  };

  IconData get icon => switch (this) {
    OrderStatus.placed => Icons.receipt_long_rounded,
    OrderStatus.confirmed => Icons.check_circle_outline_rounded,
    OrderStatus.shipped => Icons.local_shipping_rounded,
    OrderStatus.delivered => Icons.done_all_rounded,
    OrderStatus.cancelled => Icons.cancel_rounded,
  };
}

/// A store order with its line items and totals.
@immutable
class OrderModel {
  const OrderModel({
    required this.id,
    required this.items,
    required this.placedAt,
    required this.status,
    required this.deliveryAddress,
    this.paymentMethod = 'Card •••• 4242',
    this.trackingNumber,
    this.estimatedDelivery,
  });

  final String id;
  final List<CartItem> items;
  final DateTime placedAt;
  final OrderStatus status;
  final String deliveryAddress;
  final String paymentMethod;
  final String? trackingNumber;
  final DateTime? estimatedDelivery;

  int get itemCount => items.fold(0, (sum, i) => sum + i.quantity);

  double get subtotal =>
      items.fold(0, (sum, i) => sum + i.product.price * i.quantity);

  double get shipping {
    if (subtotal == 0) return 0;
    return subtotal >= 50 ? 0 : 5.99;
  }

  double get tax => (subtotal * 0.08).roundToDouble();

  double get total => subtotal + shipping + tax;

  bool get isActive =>
      status != OrderStatus.delivered && status != OrderStatus.cancelled;

  OrderModel copyWith({OrderStatus? status, String? trackingNumber}) {
    return OrderModel(
      id: id,
      items: items,
      placedAt: placedAt,
      status: status ?? this.status,
      deliveryAddress: deliveryAddress,
      paymentMethod: paymentMethod,
      trackingNumber: trackingNumber ?? this.trackingNumber,
      estimatedDelivery: estimatedDelivery,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'items': items.map((i) => i.toMap()).toList(),
    'placedAt': placedAt.toIso8601String(),
    'status': status.name,
    'deliveryAddress': deliveryAddress,
    'total': total,
  };

  factory OrderModel.fromMap(Map<String, dynamic> map) => OrderModel(
    id: map['id'] as String,
    items: const [],
    placedAt:
        DateTime.tryParse(map['placedAt'] as String? ?? '') ?? DateTime.now(),
    status: OrderStatus.values.firstWhere(
      (s) => s.name == map['status'],
      orElse: () => OrderStatus.placed,
    ),
    deliveryAddress: map['deliveryAddress'] as String? ?? '',
  );
}
