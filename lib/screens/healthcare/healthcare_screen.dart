import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/routes.dart';
import '../../models/health_model.dart';
import '../../services/healthcare_service.dart';
import '../../utils/constants.dart';
import '../../widgets/common.dart';
import '../../widgets/section_header.dart';

/// Healthcare hub: care tips and written guidance only.
class HealthcareScreen extends StatefulWidget {
  const HealthcareScreen({super.key});

  @override
  State<HealthcareScreen> createState() => _HealthcareScreenState();
}

class _HealthcareScreenState extends State<HealthcareScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<HealthcareService>().bootstrap(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<HealthcareService>();
    // Honours the search box, so typing filters the guides in place.
    final articles = service.articleResults;
    final tips = service.tips;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: service.refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 110),
            children: [
              const Text(
                'Pet care tips',
                style: TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.7,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Small daily habits that keep your pet healthier',
                style: TextStyle(
                  fontSize: 12.5,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              Gap.h20,
              if (tips.isEmpty)
                const EmptyState(
                  icon: Icons.lightbulb_outline_rounded,
                  title: 'No tips yet',
                  message: 'Care tips will appear here.',
                  compact: true,
                )
              else
                for (final tip in tips)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: InfoBanner(
                      icon: tip.icon,
                      title: tip.title,
                      message: tip.message,
                      color: tip.color,
                    ),
                  ),
              Gap.h24,
              const SectionHeader(
                title: 'Guides & guidance',
                subtitle: 'Written by vets and experienced owners',
                padding: EdgeInsets.only(),
              ),
              Gap.h12,
              if (articles.isEmpty)
                const EmptyState(
                  icon: Icons.article_outlined,
                  title: 'No guides yet',
                  message: 'Long-form guidance will appear here.',
                  compact: true,
                )
              else ...[
                _SearchField(onChanged: service.setArticleQuery),
                Gap.h12,
                for (final article in articles)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _ArticleCard(
                      article: article,
                      onTap: () => Nav.push(
                        context,
                        AppRoutes.articleDetails,
                        ArticleDetailsArgs(article.id),
                      ),
                    ),
                  ),
              ],
              Gap.h24,
              const SectionHeader(
                title: 'Common questions',
                padding: EdgeInsets.only(),
              ),
              Gap.h12,
              for (final (question, answer) in service.faqs)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _FaqCard(question: question, answer: answer),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.onChanged});

  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Search guides',
        prefixIcon: const Icon(Icons.search_rounded, size: 20),
        isDense: true,
      ),
    );
  }
}

class _ArticleCard extends StatelessWidget {
  const _ArticleCard({required this.article, required this.onTap});

  final HealthArticle article;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AppCard(
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StatusPill(
                label: article.category,
                color: scheme.primary,
                dense: true,
              ),
              const Spacer(),
              Text(
                '${article.readMinutes} min read',
                style: TextStyle(
                  fontSize: 11,
                  color: scheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
          Gap.h10,
          Text(
            article.title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
          ),
          Gap.h6,
          Text(
            article.summary,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.5,
              color: scheme.onSurface.withValues(alpha: 0.65),
            ),
          ),
          Gap.h10,
          Row(
            children: [
              Text(
                'Read guide',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: scheme.primary,
                ),
              ),
              Gap.w4,
              Icon(
                Icons.arrow_forward_rounded,
                size: 15,
                color: scheme.primary,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FaqCard extends StatelessWidget {
  const _FaqCard({required this.question, required this.answer});

  final String question;
  final String answer;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.help_outline_rounded, size: 18, color: scheme.primary),
              Gap.w10,
              Expanded(
                child: Text(
                  question,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
          Gap.h8,
          Text(
            answer,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.55,
              color: scheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}
