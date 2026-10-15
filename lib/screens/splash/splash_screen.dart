import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';
import '../../services/healthcare_service.dart';
import '../../services/messaging_service.dart';
import '../../services/pet_service.dart';
import '../../services/store_service.dart';
import '../../utils/constants.dart';
import '../../widgets/section_header.dart';
import '../../app/routes.dart';

/// Launch screen. Restores the session then routes to onboarding, auth or home.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..forward();

  late final Animation<double> _fade = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOut,
  );

  late final Animation<double> _scale = Tween<double>(
    begin: 0.7,
    end: 1.0,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

  @override
  void initState() {
    super.initState();
    // Services notify listeners, so start after the first frame is built.
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final auth = context.read<AuthService>();

    // Capture the services before the first await: using BuildContext after an
    // async gap is unsafe, and the widget may be gone by then.
    final pets = context.read<PetService>();
    final store = context.read<StoreService>();
    final healthcare = context.read<HealthcareService>();
    final messaging = context.read<MessagingService>();

    // Auth first: it establishes the Supabase session, and the pet fetch below
    // needs it to resolve which listings are the seller's own. Running them in
    // parallel raced, and every fetch came back tagged as "not mine".
    await auth.bootstrap();

    // The remaining services have no dependency on each other.
    await Future.wait([
      pets.bootstrap(),
      store.bootstrap(),
      healthcare.bootstrap(),
      messaging.bootstrap(),
    ]);

    // Hold the splash briefly so the brand animation reads.
    await Future<void>.delayed(const Duration(milliseconds: 900));

    if (!mounted) return;

    final route = !auth.hasSeenOnboarding
        ? AppRoutes.onboarding
        : auth.isLoggedIn
        ? AppRoutes.shell
        : AppRoutes.login;

    await Nav.resetTo(context, route);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: Stack(
        children: [
          Positioned.fill(child: _backdrop(scheme)),
          Center(
            child: FadeTransition(
              opacity: _fade,
              child: ScaleTransition(
                scale: _scale,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const _Logo(size: 96),
                    Gap.h24,
                    Text(
                      AppConstants.appName,
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1.2,
                        color: scheme.onSurface,
                      ),
                    ),
                    Gap.h6,
                    Text(
                      AppConstants.appTagline,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 1.4,
                        color: scheme.onSurface.withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 56,
            child: FadeTransition(
              opacity: _fade,
              child: Column(
                children: [
                  SizedBox(
                    width: 130,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        minHeight: 4,
                        backgroundColor: scheme.onSurface.withValues(
                          alpha: 0.08,
                        ),
                      ),
                    ),
                  ),
                  Gap.h16,
                  Text(
                    'Loading your pet world…',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: scheme.onSurface.withValues(alpha: 0.45),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _backdrop(ColorScheme scheme) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          scheme.primary.withValues(alpha: 0.14),
          scheme.surface,
          scheme.secondary.withValues(alpha: 0.12),
        ],
      ),
    ),
  );
}

/// The PetHub paw logo, reused across onboarding and auth.
class _Logo extends StatelessWidget {
  const _Logo({this.size = 96});

  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.29),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [scheme.primary, AppColors.plum],
        ),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.35),
            blurRadius: 26,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Icon(Icons.pets_rounded, color: Colors.white, size: size * 0.48),
    );
  }
}

/// Public logo widget so other screens can reuse the brand mark.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 96, this.withShadow = true});

  final double size;
  final bool withShadow;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.29),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [scheme.primary, AppColors.plum],
        ),
        boxShadow: withShadow
            ? [
                BoxShadow(
                  color: scheme.primary.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: Icon(Icons.pets_rounded, color: Colors.white, size: size * 0.48),
    );
  }
}

/// Reusable branded loading state for auth and profile screens.
class AppLoadingView extends StatelessWidget {
  const AppLoadingView({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) => LoadingView(message: message);
}
