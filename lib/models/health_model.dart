import 'package:flutter/material.dart';

/// A care tip shown at the top of the healthcare hub.
@immutable
class HealthTip {
  const HealthTip({
    required this.id,
    required this.title,
    required this.message,
    required this.icon,
    required this.color,
  });

  final String id;
  final String title;
  final String message;
  final IconData icon;
  final Color color;
}

/// A long-form, written guide. Healthcare is guidance-only, so articles have
/// no image and no associated service or clinic.
@immutable
class HealthArticle {
  const HealthArticle({
    required this.id,
    required this.title,
    required this.summary,
    required this.category,
    required this.readMinutes,
    required this.body,
    this.isFeatured = false,
  });

  final String id;
  final String title;
  final String summary;
  final String category;
  final int readMinutes;
  final String body;
  final bool isFeatured;
}
