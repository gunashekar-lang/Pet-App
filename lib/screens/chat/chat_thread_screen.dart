import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/chat_model.dart';
import '../../services/messaging_service.dart';
import '../../utils/constants.dart';
import '../../utils/helpers.dart';
import '../../widgets/common.dart';

/// A real buyer ↔ seller conversation: bubbles, delivery state, typing
/// indicator and a message composer.
class ChatThreadScreen extends StatefulWidget {
  const ChatThreadScreen({super.key, required this.threadId});

  final String threadId;

  @override
  State<ChatThreadScreen> createState() => _ChatThreadScreenState();
}

class _ChatThreadScreenState extends State<ChatThreadScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _focus = FocusNode();
  int _lastMessageCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final messaging = context.read<MessagingService>();
      messaging.markRead(widget.threadId);
      _lastMessageCount =
          messaging.threadById(widget.threadId)?.messages.length ?? 0;
      _scrollToBottom();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _scrollToBottom({bool animated = false}) {
    if (!_scrollController.hasClients) return;
    final target = _scrollController.position.maxScrollExtent;
    if (animated) {
      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
    } else {
      _scrollController.jumpTo(target);
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    HapticFeedback.selectionClick();
    await context.read<MessagingService>().send(widget.threadId, text);
    if (mounted) _scrollToBottom(animated: true);
  }

  @override
  Widget build(BuildContext context) {
    final messaging = context.watch<MessagingService>();
    final thread = messaging.threadById(widget.threadId);
    final scheme = Theme.of(context).colorScheme;

    if (thread == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Conversation')),
        body: const EmptyConversation(),
      );
    }

    // Auto-follow the conversation as messages arrive.
    if (thread.messages.length != _lastMessageCount) {
      _lastMessageCount = thread.messages.length;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _scrollToBottom(animated: true),
      );
    }

    return Scaffold(
      appBar: _ThreadAppBar(thread: thread),
      body: Column(
        children: [
          Expanded(
            child: thread.messages.isEmpty
                ? _ConversationIntro(thread: thread)
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    itemCount:
                        thread.messages.length +
                        (thread.isCounterpartyTyping ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index >= thread.messages.length) {
                        return _TypingBubble(
                          avatarUrl: thread.participantAvatarUrl,
                          initials: thread.participantInitials,
                        );
                      }
                      final message = thread.messages[index];
                      final previous = index == 0
                          ? null
                          : thread.messages[index - 1];
                      final groupedWithPrevious =
                          previous != null &&
                          previous.isMine == message.isMine &&
                          message.sentAt.difference(previous.sentAt).inMinutes <
                              2;
                      return _MessageBubble(
                        message: message,
                        showTime: !groupedWithPrevious,
                        avatarUrl: thread.participantAvatarUrl,
                        initials: thread.participantInitials,
                      );
                    },
                  ),
          ),
          Container(
            decoration: BoxDecoration(
              color: scheme.surface,
              border: Border(top: BorderSide(color: scheme.outline)),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 120),
                        child: TextField(
                          controller: _controller,
                          focusNode: _focus,
                          minLines: 1,
                          maxLines: 4,
                          textCapitalization: TextCapitalization.sentences,
                          textInputAction: TextInputAction.newline,
                          decoration: InputDecoration(
                            hintText: 'Type a message…',
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(999),
                              borderSide: BorderSide(color: scheme.outline),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(999),
                              borderSide: BorderSide(color: scheme.outline),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(999),
                              borderSide: BorderSide(
                                color: scheme.primary,
                                width: 1.6,
                              ),
                            ),
                          ),
                          onSubmitted: (_) => _send(),
                        ),
                      ),
                    ),
                    Gap.w8,
                    _SendButton(
                      enabled: _controller.text.trim().isNotEmpty,
                      onTap: _send,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ThreadAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _ThreadAppBar({required this.thread});

  final ChatThread thread;

  @override
  Size get preferredSize => const Size.fromHeight(62);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final status = thread.isCounterpartyTyping
        ? 'typing…'
        : '${thread.counterpartLabel} • ${thread.petName}';

    return AppBar(
      toolbarHeight: 62,
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      titleSpacing: 0,
      title: Row(
        children: [
          AppAvatar(
            url: thread.participantAvatarUrl,
            initials: thread.participantInitials,
            size: 40,
            icon: thread.counterpartyIsBuyer
                ? Icons.person_rounded
                : Icons.storefront_rounded,
          ),
          Gap.w12,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  thread.participantName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  status,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: thread.isCounterpartyTyping
                        ? scheme.primary
                        : scheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.pets_rounded, size: 13, color: scheme.primary),
                  Gap.w2,
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 90),
                    child: Text(
                      thread.petName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: scheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.avatarUrl,
    required this.initials,
    this.showTime = true,
  });

  final ChatMessage message;
  final String avatarUrl;
  final String initials;
  final bool showTime;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final mine = message.isMine;

    final bubble = Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * 0.74,
      ),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
      decoration: BoxDecoration(
        color: mine
            ? scheme.primary
            : (scheme.brightness == Brightness.dark
                  ? scheme.surfaceContainerHigh
                  : AppColors.lavenderSoft),
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft: Radius.circular(mine ? 18 : 5),
          bottomRight: Radius.circular(mine ? 5 : 18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message.text,
            style: TextStyle(
              fontSize: 14.5,
              height: 1.4,
              fontWeight: FontWeight.w500,
              color: mine ? scheme.onPrimary : scheme.onSurface,
            ),
          ),
          if (showTime) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  Helpers.time(message.sentAt),
                  style: TextStyle(
                    fontSize: 10.5,
                    color: (mine ? scheme.onPrimary : scheme.onSurface)
                        .withValues(alpha: 0.65),
                  ),
                ),
                if (mine) ...[
                  const SizedBox(width: 4),
                  Icon(
                    message.status == MessageStatus.read
                        ? Icons.done_all_rounded
                        : Icons.done_rounded,
                    size: 12,
                    color: scheme.onPrimary.withValues(alpha: 0.8),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );

    return Padding(
      padding: EdgeInsets.only(top: showTime ? 10 : 2, bottom: 2),
      child: Row(
        mainAxisAlignment: mine
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!mine) ...[
            SizedBox(
              width: 26,
              child: showTime
                  ? AppAvatar(url: avatarUrl, initials: initials, size: 26)
                  : null,
            ),
            Gap.w8,
          ],
          bubble,
        ],
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble({required this.avatarUrl, required this.initials});

  final String avatarUrl;
  final String initials;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          AppAvatar(url: avatarUrl, initials: initials, size: 26),
          Gap.w8,
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            decoration: BoxDecoration(
              color: scheme.brightness == Brightness.dark
                  ? scheme.surfaceContainerHigh
                  : AppColors.lavenderSoft,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomRight: Radius.circular(18),
                bottomLeft: Radius.circular(5),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < 3; i++) ...[
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: scheme.onSurface.withValues(alpha: 0.45),
                      shape: BoxShape.circle,
                    ),
                  ),
                  if (i < 2) Gap.w4,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ConversationIntro extends StatelessWidget {
  const _ConversationIntro({required this.thread});

  final ChatThread thread;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppAvatar(
              url: thread.participantAvatarUrl,
              initials: thread.participantInitials,
              size: 74,
              icon: thread.counterpartyIsBuyer
                  ? Icons.person_rounded
                  : Icons.storefront_rounded,
            ),
            Gap.h16,
            Text(
              'Say hello to ${thread.participantName.split(' ').first}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
            Gap.h8,
            Text(
              thread.counterpartyIsBuyer
                  ? 'This buyer is asking about ${thread.petName}. Answer their '
                        'questions about availability, health and handover.'
                  : 'Ask about ${thread.petName} — its age, vaccinations, price '
                        'and where you can meet.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.5,
                color: scheme.onSurface.withValues(alpha: 0.65),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class EmptyConversation extends StatelessWidget {
  const EmptyConversation({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Text(
          'This conversation is no longer available.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({required this.enabled, required this.onTap});

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = enabled
        ? scheme.primary
        : scheme.onSurface.withValues(alpha: 0.2);

    return Semantics(
      button: true,
      enabled: enabled,
      label: 'Send message',
      child: Material(
        color: color,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? onTap : null,
          child: SizedBox(
            width: 46,
            height: 46,
            child: Icon(Icons.send_rounded, color: scheme.surface, size: 20),
          ),
        ),
      ),
    );
  }
}
