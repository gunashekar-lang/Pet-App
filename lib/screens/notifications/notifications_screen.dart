import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/routes.dart';
import '../../services/notification_service.dart';
import '../../utils/constants.dart';
import '../../utils/helpers.dart';
import '../../widgets/common.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/section_header.dart';

/// The notification inbox. Reads from [NotificationService], which is fed by
/// real app events, so this starts empty on a fresh account.
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = context.watch<NotificationService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (service.items.isNotEmpty)
            TextButton(
              onPressed: () => _confirmClear(context, service),
              child: const Text('Clear'),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: service.isEmpty
          ? EmptyState(
              icon: Icons.notifications_none_rounded,
              title: 'No notifications yet',
              message:
                  'Enquiries from buyers, order updates and listing reminders '
                  'will show up here.',
            )
          : RefreshIndicator(
              onRefresh: service.refresh,
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                itemCount: service.items.length,
                separatorBuilder: (_, _) => Gap.h10,
                itemBuilder: (context, i) {
                  final item = service.items[i];
                  return _NotificationTile(
                    notification: item,
                    onTap: () {
                      service.markRead(item.id);
                      final route = item.targetRoute;
                      if (route == null) return;
                      Nav.push(context, route, item.targetArguments);
                    },
                    onDismiss: () => service.remove(item.id),
                  );
                },
              ),
            ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.notification,
    required this.onTap,
    required this.onDismiss,
  });

  final AppNotification notification;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  (IconData, Color) get _style => switch (notification.kind) {
    NotificationKind.message => (Icons.chat_bubble_rounded, AppColors.plum),
    NotificationKind.listing => (Icons.pets_rounded, AppColors.brand),
    NotificationKind.order => (Icons.receipt_long_rounded, AppColors.accent),
    NotificationKind.health => (
      Icons.medical_services_rounded,
      AppColors.success,
    ),
    NotificationKind.system => (
      Icons.info_outline_rounded,
      AppColors.periwinkle,
    ),
  };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (icon, color) = _style;

    return Dismissible(
      key: ValueKey(notification.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDismiss(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: scheme.errorContainer,
          borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        ),
        child: Icon(
          Icons.delete_outline_rounded,
          color: scheme.onErrorContainer,
        ),
      ),
      child: AppCard(
        onTap: onTap,
        color: notification.isRead ? null : scheme.surfaceContainerLow,
        borderColor: notification.isRead
            ? scheme.outline
            : scheme.primary.withValues(alpha: 0.4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 20, color: color),
            ),
            Gap.w12,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            height: 1.3,
                          ),
                        ),
                      ),
                      if (!notification.isRead)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: scheme.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    notification.body,
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.45,
                      color: scheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                  Gap.h8,
                  Text(
                    Helpers.relativeTime(notification.createdAt),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface.withValues(alpha: 0.5),
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

/// Asks before wiping the inbox, since clearing cannot be undone.
Future<void> _confirmClear(
  BuildContext context,
  NotificationService service,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Clear notifications?'),
      content: Text(
        'This removes all ${service.items.length} notifications. '
        'This cannot be undone.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Clear'),
        ),
      ],
    ),
  );
  if (confirmed != true) return;
  service.clear();
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(const SnackBar(content: Text('Notifications cleared')));
}

/// Shown inside settings-style sheets when there is nothing to list.
class NotificationsEmptyHint extends StatelessWidget {
  const NotificationsEmptyHint({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        EmptyState(
          icon: Icons.notifications_active_outlined,
          title: 'You are all caught up',
          message: 'We will let you know as soon as something happens.',
          compact: true,
        ),
        Gap.h12,
        CustomButton(
          label: 'Back to buying',
          variant: ButtonVariant.secondary,
          onPressed: () => Nav.pop(context),
        ),
      ],
    );
  }
}
