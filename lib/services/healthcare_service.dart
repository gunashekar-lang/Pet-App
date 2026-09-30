import 'package:flutter/foundation.dart';

import '../data/health_data.dart';
import '../models/health_model.dart';
import '../utils/constants.dart';

/// Healthcare state. The hub is guidance-only: care tips and written guides.
/// Bookings and clinic directories are intentionally not modelled here.
class HealthcareService extends ChangeNotifier {
  HealthcareService();

  final List<HealthArticle> _articles = List<HealthArticle>.from(
    HealthData.articles,
  );

  String _articleQuery = '';
  bool _isLoading = false;

  // ---------------------------------------------------------------- getters

  bool get isLoading => _isLoading;
  List<HealthArticle> get articles => List.unmodifiable(_articles);
  List<HealthTip> get tips => HealthData.tips;
  List<(String, String)> get faqs => HealthData.faqs;
  String get articleQuery => _articleQuery;

  List<HealthArticle> get featuredArticles =>
      _articles.where((a) => a.isFeatured).toList();

  /// Guides filtered by the on-page search field.
  List<HealthArticle> get articleResults {
    final q = _articleQuery.trim().toLowerCase();
    if (q.isEmpty) return _articles;
    return _articles.where((a) {
      return a.title.toLowerCase().contains(q) ||
          a.summary.toLowerCase().contains(q) ||
          a.category.toLowerCase().contains(q) ||
          a.body.toLowerCase().contains(q);
    }).toList();
  }

  List<String> get articleCategories {
    final set = <String>{for (final a in _articles) a.category};
    return set.toList()..sort();
  }

  HealthArticle? articleById(String id) {
    for (final a in _articles) {
      if (a.id == id) return a;
    }
    return null;
  }

  // ---------------------------------------------------------------- actions

  Future<void> bootstrap() async {
    _isLoading = true;
    notifyListeners();
    await Future<void>.delayed(AppConstants.shortDelay);
    _isLoading = false;
    notifyListeners();
  }

  void setArticleQuery(String value) {
    if (_articleQuery == value) return;
    _articleQuery = value;
    notifyListeners();
  }

  Future<void> refresh() async {
    _isLoading = true;
    notifyListeners();
    await Future<void>.delayed(AppConstants.shortDelay);
    _isLoading = false;
    notifyListeners();
  }
}
