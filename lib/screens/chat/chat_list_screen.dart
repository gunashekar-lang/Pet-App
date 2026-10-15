import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/routes.dart';
import '../../models/chat_model.dart';
import '../../services/messaging_service.dart';
import '../../utils/constants.dart';
import '../../utils/helpers.dart';
import '../../widgets/app_bottom_navigation.dart';
import '../../widgets/common.dart';
import '../../widgets/section_header.dart';

/// The Chat tab: every buyer ↔ seller conversation the user is part of.
class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  @override
  void initState() {
    super.initState();
    // Open the live inbox on first visit as well as at splash, so a login that
    // happens mid-session still picks up conversations and Realtime.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<MessagingService>().bootstrap();
    });
  }

  @override
  Widget build(BuildContext context) {
    final messaging = context.watch<MessagingService>();
    final scheme = Theme.of(context).colorScheme;
    final unread = messaging.unreadCount;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Messages',
                      style: TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.7,
                      ),
                    ),
                  ),
                  if (unread > 0)
                    StatusPill(
                      label: '$unread new',
                      icon: Icons.mark_chat_unread_rounded,
                      color: scheme.primary,
                      solid: true,
                    ),
                ],
              ),
            ),
            Gap.h4,
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
              child: Text(
                messaging.isEmpty
                    ? 'Talk directly to buyers and sellers'
                    : 'Your conversations with buyers and sellers',
                style: TextStyle(
                  fontSize: 13,
                  color: scheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ),
            Gap.h16,
            Expanded(
              child: messaging.isEmpty
                  ? _EmptyInbox()
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                      itemCount: messaging.threads.length,
                      separatorBuilder: (_, _) => Gap.h10,
                      itemBuilder: (context, index) => _ThreadTile(
                        thread: messaging.threads[index],
                        onTap: () => Nav.push(
                          context,
                          AppRoutes.chatThread,
                          ChatThreadArgs(messaging.threads[index].id),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyInbox extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: EmptyState(
        icon: Icons.forum_outlined,
        title: 'No conversations yet',
        message:
            'Message a seller from any listing, and their replies land here. '
            'As a seller you will get every buyer enquiry in the same place.',
        actionLabel: 'Browse listings',
        onAction: () => AppShell.of(context)?.goToTab(0),
      ),
    );
  }
}

class _ThreadTile extends StatelessWidget {
  const _ThreadTile({required this.thread, required this.onTap});

  final ChatThread thread;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final last = thread.lastMessage;
    final unread = thread.unreadCount;

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(12),
      borderColor: unread > 0
          ? scheme.primary.withValues(alpha: 0.35)
          : scheme.outline,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              AppAvatar(
                url: thread.participantAvatarUrl,
                initials: thread.participantInitials,
                size: 50,
                icon: thread.counterpartyIsBuyer
                    ? Icons.person_rounded
                    : Icons.storefront_rounded,
              ),
              if (thread.isCounterpartyTyping)
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: AppColors.success,
                      shape: BoxShape.circle,
                      border: Border.all(color: scheme.surface, width: 2),
                    ),
                  ),
                ),
            ],
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
                        thread.participantName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: unread > 0
                              ? FontWeight.w800
                              : FontWeight.w700,
                        ),
                      ),
                    ),
                    if (last != null)
                      Text(
                        Helpers.relativeTime(last.sentAt),
                        style: TextStyle(
                          fontSize: 11,
                          color: scheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(
                      thread.counterpartyIsBuyer
                          ? Icons.shopping_bag_outlined
                          : Icons.sell_outlined,
                      size: 12,
                      color: scheme.primary.withValues(alpha: 0.75),
                    ),
                    Gap.w2,
                    Text(
                      '${thread.counterpartLabel} • ${thread.petName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: scheme.primary.withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  thread.isCounterpartyTyping
                      ? 'typing…'
                      : (last == null
                            ? 'Say hello to get started'
                            : (last.isMine ? 'You: ${last.text}' : last.text)),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.35,
                    fontWeight: unread > 0 ? FontWeight.w600 : FontWeight.w400,
                    color: last == null || !last.isMine || unread > 0
                        ? scheme.onSurface.withValues(alpha: 0.7)
                        : scheme.onSurface.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
          ),
          if (unread > 0) ...[
            Gap.w8,
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: scheme.primary,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                unread > 9 ? '9+' : '$unread',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
