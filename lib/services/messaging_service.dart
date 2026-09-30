import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/chat_model.dart';
import '../models/pet_model.dart';
import '../utils/helpers.dart';

/// Buyer ↔ seller messaging.
///
/// The inbox starts empty: a thread only exists once the signed-in user
/// actually talks to someone, either by contacting a seller about a listing or
/// by answering an enquiry on one of their own listings.
///
/// Incoming messages arrive through [receive]. Until a chat API is connected,
/// [send] schedules a local stand-in reply from the other party so both sides of
/// the conversation (buyer → seller and seller → buyer) are exercisable; point
/// [onMessageReceived] at the notification layer to raise an alert for them.
class MessagingService extends ChangeNotifier {
  MessagingService({this.onMessageReceived});

  /// Called for every message that arrives from the other party.
  final void Function(ChatThread thread, ChatMessage message)?
  onMessageReceived;

  /// Kept newest-conversation-first.
  final List<ChatThread> _threads = [];
  final Map<String, Timer> _typingTimers = {};
  final Map<String, Timer> _replyTimers = {};

  List<ChatThread> get threads => List.unmodifiable(_threads);

  bool get isEmpty => _threads.isEmpty;

  int get unreadCount =>
      _threads.fold(0, (total, thread) => total + thread.unreadCount);

  ChatThread? threadById(String id) {
    for (final thread in _threads) {
      if (thread.id == id) return thread;
    }
    return null;
  }

  /// Opens the conversation about [pet], or returns the existing one.
  ///
  /// [role] decides who the other party is: [ChatRole.buyer] means the user is
  /// enquiring about someone else's listing, so the counterparty is the seller.
  /// [ChatRole.seller] means the listing belongs to the user, so the other party
  /// is a buyer and [counterpartyName] carries their name once known.
  ChatThread openThread({
    required PetModel pet,
    required ChatRole role,
    String? counterpartyName,
    String? counterpartyAvatarUrl,
  }) {
    final id = _threadId(pet.id, role);
    final existing = threadById(id);
    if (existing != null) return existing;

    final name = role.isBuyer
        ? pet.seller.name
        : (counterpartyName?.trim().isNotEmpty == true
              ? counterpartyName!.trim()
              : 'Buyer');

    final thread = ChatThread(
      id: id,
      petId: pet.id,
      petName: pet.name,
      petImage: pet.image,
      participantName: name,
      participantInitials: Helpers.initials(name),
      participantAvatarUrl: role.isBuyer
          ? pet.seller.avatarUrl
          : (counterpartyAvatarUrl ?? ''),
      role: role,
      messages: const [],
    );

    _threads.insert(0, thread);
    notifyListeners();
    return thread;
  }

  /// Sends a message and, until a backend exists, lets the other party reply.
  Future<void> send(String threadId, String text) async {
    final thread = threadById(threadId);
    final trimmed = text.trim();
    if (thread == null || trimmed.isEmpty) return;

    _append(
      threadId,
      ChatMessage(
        id: _messageId(),
        text: trimmed,
        isMine: true,
        sentAt: DateTime.now(),
      ),
    );
    _scheduleLocalReply(threadId);
  }

  /// Delivers a message from the other party. This is the entry point a chat
  /// API, WebSocket or push layer should call.
  void receive(String threadId, String text) {
    final index = _indexOf(threadId);
    final trimmed = text.trim();
    if (index == -1 || trimmed.isEmpty) return;

    final thread = _threads[index];
    final message = ChatMessage(
      id: _messageId(),
      text: trimmed,
      isMine: false,
      sentAt: DateTime.now(),
    );

    _replace(
      index,
      thread.copyWith(
        messages: [...thread.messages, message],
        isCounterpartyTyping: false,
        unreadCount: thread.unreadCount + 1,
      ),
    );
    onMessageReceived?.call(
      _threads.firstWhere((t) => t.id == threadId),
      message,
    );
  }

  /// Clears the unread badge and marks the user's own messages as read.
  void markRead(String threadId) {
    final index = _indexOf(threadId);
    if (index == -1) return;

    final thread = _threads[index];
    if (thread.unreadCount == 0 &&
        thread.messages.every(
          (m) => !m.isMine || m.status == MessageStatus.read,
        )) {
      return;
    }

    _replace(
      index,
      thread.copyWith(
        unreadCount: 0,
        messages: thread.messages
            .map((m) => m.isMine ? m.copyWith(status: MessageStatus.read) : m)
            .toList(),
      ),
    );
  }

  void deleteThread(String threadId) {
    _cancelTimers(threadId);
    final before = _threads.length;
    _threads.removeWhere((t) => t.id == threadId);
    if (_threads.length != before) notifyListeners();
  }

  void reset() {
    for (final id in [..._typingTimers.keys, ..._replyTimers.keys]) {
      _cancelTimers(id);
    }
    if (_threads.isEmpty) return;
    _threads.clear();
    notifyListeners();
  }

  // ------------------------------------------------------------- internals

  void _append(String threadId, ChatMessage message) {
    final index = _indexOf(threadId);
    if (index == -1) return;
    final thread = _threads[index];
    _replace(index, thread.copyWith(messages: [...thread.messages, message]));
  }

  void _replace(int index, ChatThread thread) {
    _threads[index] = thread;
    _sortThreads();
    notifyListeners();
  }

  int _indexOf(String threadId) => _threads.indexWhere((t) => t.id == threadId);

  /// Most recently active conversation first.
  void _sortThreads() {
    _threads.sort((a, b) {
      final aTime =
          a.lastMessage?.sentAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime =
          b.lastMessage?.sentAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bTime.compareTo(aTime);
    });
  }

  void _setTyping(String threadId, bool typing) {
    final index = _indexOf(threadId);
    if (index == -1) return;
    final thread = _threads[index];
    if (thread.isCounterpartyTyping == typing) return;
    _replace(index, thread.copyWith(isCounterpartyTyping: typing));
  }

  /// Local stand-in for the other side answering. Deleted once a real chat API
  /// drives [receive] instead.
  void _scheduleLocalReply(String threadId) {
    _cancelTimers(threadId);
    _typingTimers[threadId] = Timer(const Duration(milliseconds: 700), () {
      _typingTimers.remove(threadId);
      _setTyping(threadId, true);
    });
    _replyTimers[threadId] = Timer(const Duration(milliseconds: 2600), () {
      _replyTimers.remove(threadId);
      _setTyping(threadId, false);
      final thread = threadById(threadId);
      if (thread == null) return;
      receive(threadId, _standInReply(thread));
    });
  }

  void _cancelTimers(String threadId) {
    _typingTimers.remove(threadId)?.cancel();
    _replyTimers.remove(threadId)?.cancel();
  }

  /// Keeps the demo honest: replies are clearly about the listing and never
  /// pretend to be a real person on the other side.
  String _standInReply(ChatThread thread) {
    final speakingToSeller = thread.role.isBuyer;
    return speakingToSeller
        ? 'Thanks for your message about ${thread.petName}. The seller has been '
              'notified and usually replies within a few hours.'
        : 'Thanks for the details on ${thread.petName}. Could you share a photo '
              'and confirm the vaccination dates?';
  }

  String _threadId(String petId, ChatRole role) =>
      '${petId}_${role.isBuyer ? 'buyer' : 'seller'}';

  String _messageId() => 'm_${DateTime.now().microsecondsSinceEpoch}';

  @override
  void dispose() {
    for (final id in [..._typingTimers.keys, ..._replyTimers.keys]) {
      _cancelTimers(id);
    }
    super.dispose();
  }
}
