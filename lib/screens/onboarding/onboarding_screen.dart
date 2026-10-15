import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../app/routes.dart';
import '../../services/auth_service.dart';
import '../../utils/constants.dart';
import '../../utils/helpers.dart';
import '../../widgets/custom_button.dart';
import '../splash/splash_screen.dart' show AppLogo;

/// Three-slide introduction shown on first launch.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _page = 0;

  static const List<_Slide> _slides = [
    _Slide(
      icon: Icons.pets_rounded,
      color: AppColors.brand,
      title: 'Find your best friend',
      message:
          'Browse pets from trusted sellers. Filter by species, age, budget and '
          'location, and message sellers directly.',
      highlights: [
        'Health records on every listing',
        'Direct seller messaging',
      ],
    ),
    _Slide(
      icon: Icons.medical_services_rounded,
      color: AppColors.accent,
      title: 'Know how to care for them',
      message:
          'Practical care tips and long-form guides on feeding, vaccinations, '
          'training and spotting illness early.',
      highlights: ['Daily care tips', 'Written vet guidance'],
    ),
    _Slide(
      icon: Icons.sell_rounded,
      color: AppColors.mint,
      title: 'Sell your pet with ease',
      message:
          'Create a listing in minutes with your own photos and vaccination '
          'history, and reach serious buyers.',
      highlights: ['Add your own photos', 'Free to list'],
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    HapticFeedback.mediumImpact();
    await context.read<AuthService>().completeOnboarding();
    if (!mounted) return;
    await Nav.resetTo(context, AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 8, top: 4),
                child: TextButton(
                  onPressed: _finish,
                  child: const Text('Skip'),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (context, i) =>
                    _SlideView(slide: _slides[i], key: ValueKey(i)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < _slides.length; i++)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: _page == i ? 24 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _page == i
                                ? scheme.primary
                                : scheme.onSurface.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                    ],
                  ),
                  Gap.h24,
                  CustomButton(
                    label: _page == _slides.length - 1 ? 'Get started' : 'Next',
                    iconTrailing: _page == _slides.length - 1
                        ? null
                        : Icons.arrow_forward_rounded,
                    onPressed: () {
                      if (_page == _slides.length - 1) {
                        _finish();
                      } else {
                        HapticFeedback.selectionClick();
                        _controller.nextPage(
                          duration: const Duration(milliseconds: 320),
                          curve: Curves.easeOutCubic,
                        );
                      }
                    },
                  ),
                  Gap.h8,
                  TextButton(
                    onPressed: _finish,
                    child: Text(
                      'I already have an account',
                      style: TextStyle(
                        fontSize: 13.5,
                        color: scheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Slide {
  const _Slide({
    required this.icon,
    required this.color,
    required this.title,
    required this.message,
    required this.highlights,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String message;
  final List<String> highlights;
}

class _SlideView extends StatelessWidget {
  const _SlideView({super.key, required this.slide});

  final _Slide slide;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Helpers.centerContent(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1.05,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppConstants.radiusXl),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      slide.color.withValues(alpha: 0.22),
                      slide.color.withValues(alpha: 0.06),
                    ],
                  ),
                  border: Border.all(
                    color: slide.color.withValues(alpha: 0.18),
                  ),
                ),
                child: Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 150,
                        height: 150,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: slide.color.withValues(alpha: 0.12),
                        ),
                      ),
                      Container(
                        width: 104,
                        height: 104,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              slide.color,
                              slide.color.withValues(alpha: 0.7),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: slide.color.withValues(alpha: 0.35),
                              blurRadius: 26,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Icon(slide.icon, size: 50, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Gap.h32,
            Text(
              slide.title,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.8,
                height: 1.2,
              ),
            ),
            Gap.h12,
            Text(
              slide.message,
              style: TextStyle(
                fontSize: 15,
                height: 1.55,
                color: scheme.onSurface.withValues(alpha: 0.65),
              ),
            ),
            Gap.h20,
            for (final highlight in slide.highlights) ...[
              Row(
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: slide.color.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check_rounded,
                      size: 14,
                      color: slide.color,
                    ),
                  ),
                  Gap.w12,
                  Expanded(
                    child: Text(
                      highlight,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              Gap.h12,
            ],
          ],
        ),
      ),
    );
  }
}

/// Shared auth-screen scaffold with the logo, title and a bottom action area.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
    this.footer,
    this.showBack = true,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;
  final Widget? footer;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: Helpers.centerContent(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (showBack)
                            IconButton(
                              onPressed: () => Nav.pop(context),
                              icon: const Icon(Icons.arrow_back_rounded),
                              visualDensity: VisualDensity.compact,
                            )
                          else
                            const AppLogo(size: 40),
                          if (showBack) const Spacer(),
                        ],
                      ),
                      Gap.h8,
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 27,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.8,
                        ),
                      ),
                      Gap.h6,
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 14.5,
                          height: 1.45,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.6,
                          ),
                        ),
                      ),
                      Gap.h24,
                      ...children,
                    ],
                  ),
                ),
              ),
            ),
            if (footer != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: Helpers.centerContent(child: footer!),
              ),
          ],
        ),
      ),
    );
  }
}
