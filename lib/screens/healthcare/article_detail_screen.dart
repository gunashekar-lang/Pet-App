import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/routes.dart';
import '../../models/health_model.dart';
import '../../services/healthcare_service.dart';
import '../../utils/constants.dart';
import '../../widgets/common.dart';
import '../../widgets/section_header.dart';

/// Long-form vet guide with a readable article layout.
class ArticleDetailScreen extends StatelessWidget {
  const ArticleDetailScreen({super.key, required this.articleId});

  final String articleId;

  @override
  Widget build(BuildContext context) {
    final service = context.watch<HealthcareService>();
    final scheme = Theme.of(context).colorScheme;
    final article = service.articleById(articleId);

    if (article == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyState(
          icon: Icons.article_outlined,
          title: 'Guide not found',
          message: 'This article is no longer available.',
        ),
      );
    }

    final related = service.articles
        .where((a) => a.id != article.id && a.category == article.category)
        .take(3)
        .toList();

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: scheme.surface,
            surfaceTintColor: Colors.transparent,
            leading: Padding(
              padding: const EdgeInsets.all(6),
              child: CircleIconButton(
                icon: Icons.arrow_back_rounded,
                onTap: () => Nav.pop(context),
              ),
            ),
            title: Text(
              article.category,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  StatusPill(
                    label: article.category,
                    icon: Icons.local_hospital_rounded,
                    color: scheme.primary,
                  ),
                  Gap.h12,
                  Text(
                    article.title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.7,
                      height: 1.2,
                    ),
                  ),
                  Gap.h10,
                  Row(
                    children: [
                      Text(
                        '${article.readMinutes} min read',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurface.withValues(alpha: 0.55),
                        ),
                      ),
                      Gap.w10,
                      Container(
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          color: scheme.onSurface.withValues(alpha: 0.3),
                          shape: BoxShape.circle,
                        ),
                      ),
                      Gap.w10,
                      const Text(
                        'Reviewed by a PetHub vet',
                        style: TextStyle(fontSize: 12.5),
                      ),
                    ],
                  ),
                  Gap.h16,
                  AppCard(
                    color: scheme.primary.withValues(alpha: 0.06),
                    borderColor: scheme.primary.withValues(alpha: 0.2),
                    child: Text(
                      article.summary,
                      style: TextStyle(
                        fontSize: 14.5,
                        height: 1.55,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                  Gap.h20,
                  ..._buildBody(article, scheme),
                  Gap.h20,
                  const InfoBanner(
                    icon: Icons.info_outline_rounded,
                    title: 'Not medical advice',
                    message:
                        'This guide is for general information. Always confirm '
                        'with your own vet before changing your pet\'s care.',
                    color: AppColors.accent,
                  ),
                  if (related.isNotEmpty) ...[
                    Gap.h24,
                    const Text(
                      'Related guides',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Gap.h12,
                    for (final item in related)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: AppCard(
                          padding: const EdgeInsets.all(10),
                          onTap: () => Nav.replace(
                            context,
                            AppRoutes.articleDetails,
                            ArticleDetailsArgs(item.id),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 58,
                                height: 58,
                                decoration: BoxDecoration(
                                  color: scheme.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  Icons.article_rounded,
                                  color: scheme.primary,
                                ),
                              ),
                              Gap.w12,
                              Expanded(
                                child: Text(
                                  item.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                    height: 1.3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                  Gap.h40,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Splits the article body into paragraphs and renders bullet lines so the
  /// static content reads like a real guide without a markdown dependency.
  List<Widget> _buildBody(HealthArticle article, ColorScheme scheme) {
    final blocks = <Widget>[];

    for (final rawLine in article.body.split('\n')) {
      final line = rawLine.trim();
      if (line.isEmpty) {
        blocks.add(const SizedBox(height: 12));
        continue;
      }
      if (line.startsWith('## ')) {
        blocks.add(const SizedBox(height: 8));
        blocks.add(
          Text(
            line.substring(3),
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
        );
        blocks.add(const SizedBox(height: 8));
        continue;
      }
      if (line.startsWith('- ') || line.startsWith('• ')) {
        blocks.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.only(top: 7, right: 10),
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),
                Expanded(
                  child: Text(
                    line.replaceFirst(RegExp(r'^[-•]\s*'), ''),
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.55,
                      color: scheme.onSurface.withValues(alpha: 0.78),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
        continue;
      }
      blocks.add(
        Text(
          line,
          style: TextStyle(
            fontSize: 14,
            height: 1.6,
            color: scheme.onSurface.withValues(alpha: 0.78),
          ),
        ),
      );
    }
    return blocks;
  }
}
