import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app.dart';
import '../../app/routes.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/messaging_service.dart';
import '../../services/pet_service.dart';
import '../../services/store_service.dart';
import '../../utils/constants.dart';
import '../../utils/helpers.dart';
import '../../widgets/common.dart';
import '../../widgets/section_header.dart';

/// Account hub: profile header, quick stats and every settings destination.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  /// Mirrors the app's active brightness so the settings switch starts in the
  /// right position. The app itself is the source of truth once toggled.
  bool _isDarkMode = false;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final pets = context.watch<PetService>();
    final store = context.watch<StoreService>();
    final messaging = context.watch<MessagingService>();
    final scheme = Theme.of(context).colorScheme;
    final user = auth.currentUser;
    _isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Profile',
                  style: TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.7,
                  ),
                ),
              ],
            ),
            Gap.h20,
            _ProfileCard(user: user),
            Gap.h24,
            const SectionHeader(
              title: 'My activity',
              padding: EdgeInsets.only(),
            ),
            Gap.h10,
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _MenuTile(
                    icon: Icons.forum_rounded,
                    title: 'Messages',
                    subtitle: messaging.isEmpty
                        ? 'No conversations yet'
                        : '${messaging.threads.length} conversations'
                              '${messaging.unreadCount > 0 ? ' • ${messaging.unreadCount} unread' : ''}',
                    color: AppColors.plum,
                    onTap: () => Nav.push(context, AppRoutes.messages),
                  ),
                  const Divider(height: 1),
                  _MenuTile(
                    icon: Icons.sell_rounded,
                    title: 'My listings',
                    subtitle: 'Manage, edit or mark pets as sold',
                    color: AppColors.brand,
                    onTap: () => Nav.push(context, AppRoutes.myListings),
                  ),
                  const Divider(height: 1),
                  _MenuTile(
                    icon: Icons.favorite_rounded,
                    title: 'Favourites',
                    subtitle: '${pets.favoriteIds.length} shortlisted pets',
                    color: AppColors.rose,
                    onTap: () => Nav.push(context, AppRoutes.favorites),
                  ),
                  const Divider(height: 1),
                  _MenuTile(
                    icon: Icons.receipt_long_rounded,
                    title: 'My orders',
                    subtitle:
                        '${store.activeOrders.length} active • '
                        '${store.pastOrders.length} past',
                    color: AppColors.accent,
                    onTap: () => Nav.push(context, AppRoutes.orders),
                  ),
                  const Divider(height: 1),
                  _MenuTile(
                    icon: Icons.shopping_bag_rounded,
                    title: 'Cart',
                    subtitle: store.cartItemCount == 0
                        ? 'Nothing in your cart'
                        : '${store.cartItemCount} items • '
                              '${Helpers.currencyPrecise(store.cartTotal)}',
                    color: AppColors.plum,
                    onTap: () => Nav.push(context, AppRoutes.cart),
                  ),
                  const Divider(height: 1),
                  _MenuTile(
                    icon: Icons.storefront_rounded,
                    title: 'My shop',
                    subtitle: store.shopVerified
                        ? '${store.shopName} • Verified'
                        : '${store.shopName} • '
                              '${store.shopProductCount} listings',
                    color: AppColors.mint,
                    onTap: () => Nav.push(context, AppRoutes.myShop),
                  ),
                  const Divider(height: 1),
                  _MenuTile(
                    icon: _isDarkMode
                        ? Icons.dark_mode_rounded
                        : Icons.light_mode_rounded,
                    title: 'Dark mode',
                    subtitle: _isDarkMode
                        ? 'On - using the dark theme'
                        : 'Off - using the light theme',
                    color: AppColors.accent,
                    onTap: () => setState(() {
                      _isDarkMode = !_isDarkMode;
                      ThemeSwitcher.setDarkMode(context, _isDarkMode);
                    }),
                  ),
                ],
              ),
            ),
            Gap.h24,
            const SectionHeader(
              title: 'Care & support',
              padding: EdgeInsets.only(),
            ),
            Gap.h10,
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _MenuTile(
                    icon: Icons.medical_services_rounded,
                    title: 'Healthcare',
                    subtitle: 'Care tips and written guides',
                    color: AppColors.mint,
                    onTap: () => Nav.push(context, AppRoutes.healthcare),
                  ),
                ],
              ),
            ),
            Gap.h24,
            const SectionHeader(title: 'Support', padding: EdgeInsets.only()),
            Gap.h10,
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _MenuTile(
                    icon: Icons.help_center_rounded,
                    title: 'Help centre',
                    subtitle: 'Answers to common questions',
                    color: AppColors.accent,
                    onTap: () => _showInfoSheet(
                      context,
                      title: 'Help centre',
                      message:
                          'Find answers about listings, messages, orders and '
                          'your shop.\n\n'
                          '• Listing a pet or product\n'
                          '• Talking to buyers and sellers\n'
                          '• Placing and tracking orders\n'
                          '• Shop verification',
                    ),
                  ),
                  const Divider(height: 1),
                  _MenuTile(
                    icon: Icons.privacy_tip_rounded,
                    title: 'Privacy & policy',
                    subtitle: 'How your data is handled',
                    color: AppColors.plum,
                    onTap: () => _showInfoSheet(
                      context,
                      title: 'Privacy & policy',
                      message:
                          'Your listings, messages and profile are only shared '
                          'with people you interact with on PetHub.\n\n'
                          '• We never sell your personal data\n'
                          '• Photos you upload stay on your listings\n'
                          '• You can clear your notifications at any time\n'
                          '• You control your own shop listings',
                    ),
                  ),
                ],
              ),
            ),
            Gap.h24,
            OutlinedButton.icon(
              onPressed: () => _confirmLogout(context, auth),
              icon: const Icon(Icons.logout_rounded, size: 18),
              label: const Text('Log out'),
              style: OutlinedButton.styleFrom(
                foregroundColor: scheme.error,
                side: BorderSide(color: scheme.error.withValues(alpha: 0.5)),
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            Gap.h16,
            Center(
              child: Text(
                '${AppConstants.appName} v1.0.0 • Made with care for pets',
                style: TextStyle(
                  fontSize: 11.5,
                  color: scheme.onSurface.withValues(alpha: 0.45),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context, AuthService auth) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Log out of PetHub?'),
        content: const Text(
          'You will need to sign in again to see your listings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Nav.pop(context, false),
            child: const Text('Stay signed in'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Nav.pop(context, true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await auth.logout();
    if (!context.mounted) return;
    Nav.resetTo(context, AppRoutes.login);
  }

  /// Simple read-only sheet used for Help centre and Privacy & policy.
  void _showInfoSheet(
    BuildContext context, {
    required String title,
    required String message,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) {
        final scheme = Theme.of(sheetContext).colorScheme;

        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          builder: (context, scrollController) => ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: scheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Gap.h20,
              Text(
                title,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: scheme.onSurface,
                ),
              ),
              Gap.h12,
              Text(
                message,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.6,
                  color: scheme.onSurface.withValues(alpha: 0.75),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Large identity card: photo, name, contact details and a tappable edit
/// action that leads to the photo picker.
class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.user});

  final UserModel user;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  scheme.primary.withValues(alpha: 0.28),
                  scheme.surface,
                  const Color(0xFF221D30),
                ]
              : [AppColors.lavender, AppColors.lavenderSoft, scheme.surface],
        ),
        border: Border.all(
          color: isDark
              ? scheme.primary.withValues(alpha: 0.28)
              : AppColors.brand.withValues(alpha: 0.14),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.brand.withValues(alpha: isDark ? 0.18 : 0.12),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [scheme.primary, AppColors.accent],
                      ),
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: scheme.surface,
                        shape: BoxShape.circle,
                      ),
                      child: AppAvatar(
                        url: user.avatarUrl,
                        initials: user.initials,
                        size: 92,
                      ),
                    ),
                  ),
                  Positioned(
                    right: -2,
                    bottom: 2,
                    child: Semantics(
                      button: true,
                      label: 'Edit profile',
                      child: Material(
                        color: scheme.primary,
                        shape: const CircleBorder(),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () => Nav.push(context, AppRoutes.editProfile),
                          child: SizedBox(
                            width: 32,
                            height: 32,
                            child: Icon(
                              Icons.edit_rounded,
                              size: 15,
                              color: scheme.onPrimary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              Gap.w20,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            user.fullName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.6,
                              height: 1.15,
                            ),
                          ),
                        ),
                        if (user.isVerified) ...[
                          Gap.w6,
                          const Icon(
                            Icons.verified_rounded,
                            size: 19,
                            color: AppColors.accent,
                          ),
                        ],
                      ],
                    ),
                    Gap.h4,
                    Text(
                      user.email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: scheme.onSurface.withValues(alpha: 0.65),
                      ),
                    ),
                    if (user.city.isNotEmpty) ...[
                      Gap.h8,
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.surface.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: scheme.outline.withValues(alpha: 0.6),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.location_on_rounded,
                              size: 13,
                              color: scheme.primary,
                            ),
                            Gap.w2,
                            Text(
                              user.city,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: scheme.onSurface.withValues(alpha: 0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          Gap.h20,
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => Nav.push(context, AppRoutes.editProfile),
              icon: const Icon(Icons.photo_camera_outlined, size: 18),
              label: Text(
                user.avatarUrl.isEmpty ? 'Add a photo' : 'Edit profile',
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: scheme.primary,
                backgroundColor: scheme.surface.withValues(alpha: 0.65),
                side: BorderSide(color: scheme.primary.withValues(alpha: 0.3)),
                minimumSize: const Size(double.infinity, 46),
                textStyle: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Icon(icon, size: 19, color: color),
      ),
      title: Text(
        title,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 11.5,
          color: scheme.onSurface.withValues(alpha: 0.55),
        ),
      ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: scheme.onSurface.withValues(alpha: 0.35),
      ),
    );
  }
}
