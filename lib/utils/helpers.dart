import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Small formatting / convenience helpers used across screens.
class Helpers {
  Helpers._();

  /// Indian Rupee formatting. `en_IN` gives lakh/crore grouping
  /// (1,20,000 rather than 120,000).
  static final NumberFormat _currency = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );
  static final NumberFormat _currencyPrecise = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  );
  static final NumberFormat _grouped = NumberFormat.decimalPattern('en_IN');
  static final DateFormat _shortDate = DateFormat('d MMM yyyy');
  static final DateFormat _dayMonth = DateFormat('d MMM');
  static final DateFormat _time = DateFormat('h:mm a');

  static String currency(num value) => _currency.format(value);

  static String currencyPrecise(num value) => _currencyPrecise.format(value);

  /// Bare number with Indian grouping, for input fields that add their own
  /// currency symbol.
  static String grouped(num value) => _grouped.format(value);

  static String formatPrice(num value) {
    if (value >= 100000) {
      final lakh = value / 100000;
      final text = lakh % 1 == 0
          ? lakh.toStringAsFixed(0)
          : lakh.toStringAsFixed(1);
      return '₹${text}L';
    }
    if (value >= 1000) {
      final k = value / 1000;
      final text = k % 1 == 0 ? k.toStringAsFixed(0) : k.toStringAsFixed(1);
      return '₹${text}k';
    }
    return currency(value);
  }

  static String date(DateTime value) => _shortDate.format(value);

  static String dayMonth(DateTime value) => _dayMonth.format(value);

  static String time(DateTime value) => _time.format(value);

  static String relativeTime(DateTime value) {
    final diff = DateTime.now().difference(value);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return _shortDate.format(value);
  }

  static String greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  static String initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  static String plural(int count, String singular, [String? plural]) =>
      count == 1 ? '$count $singular' : '$count ${plural ?? '${singular}s'}';

  /// Picks a readable foreground colour for a background [color].
  static Color contrastColor(Color color) =>
      ThemeData.estimateBrightnessForColor(color) == Brightness.dark
      ? Colors.white
      : const Color(0xFF15171C);

  /// Constrains content width on tablets / large phones while keeping
  /// the layout centred.
  static Widget centerContent({required Widget child}) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 720),
      child: child,
    ),
  );

  /// Sliver-aware horizontal padding that stays readable on wide screens.
  static EdgeInsets get pagePadding =>
      const EdgeInsets.symmetric(horizontal: 20);
}
