import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/routes.dart';
import '../../services/auth_service.dart';
import '../../services/notification_service.dart';
import '../../utils/constants.dart';
import '../../utils/helpers.dart';
import '../../widgets/common.dart';
import '../marketplace/marketplace_screen.dart';

/// The Buy tab. Home and Marketplace are one experience: the greeting bar sits
/// directly above the search, category, filter and results grid, so browsing
/// and discovery no longer require a second screen.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().currentUser;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: MarketplaceBrowser(
          header: _TopBar(
            name: user.fullName,
            avatarUrl: user.avatarUrl,
            initials: user.initials,
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.name,
    required this.avatarUrl,
    required this.initials,
  });

  final String name;
  final String avatarUrl;
  final String initials;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final unreadCount = context.watch<NotificationService>().unreadCount;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                colors: [scheme.primary, AppColors.plum],
              ),
            ),
            child: const Icon(
              Icons.pets_rounded,
              color: Colors.white,
              size: 21,
            ),
          ),
          Gap.w12,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${Helpers.greeting()},',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: scheme.onSurface.withValues(alpha: 0.55),
                  ),
                ),
                Text(
                  name.split(' ').first,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                ),
              ],
            ),
          ),
          CircleIconButton(
            icon: Icons.notifications_none_rounded,
            badge: unreadCount,
            onTap: () => Nav.push(context, AppRoutes.notifications),
          ),
          Gap.w8,
          GestureDetector(
            onTap: () => Nav.push(context, AppRoutes.profile),
            child: AppAvatar(url: avatarUrl, initials: initials, size: 42),
          ),
        ],
      ),
    );
  }
}
