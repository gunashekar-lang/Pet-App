import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/chat_model.dart';
import '../models/pet_model.dart';
import '../utils/helpers.dart';
import 'chat_repository.dart';
import 'supabase_config.dart';

/// Buyer ↔ seller messaging.
///
/// The inbox starts empty: a thread only exists once the signed-in user
/// actually talks to someone, either by contacting a seller about a listing or
/// by answering an enquiry on one of their own listings.
///
/// Incoming messages arrive through [receive]. Two modes share the same UI:
///
///  * Offline (no Supabase session): [send] schedules a local stand-in reply
///    from the other party so both sides of the conversation are exercisable.
///  * Live (Supabase session): conversations are persisted to
///    `public.conversations` / `public.messages`, the inbox is loaded from the
///    backend by [bootstrap]/[refreshThreads] and new messages stream over
///    Realtime, so a buyer and a seller really do talk to each other.
class MessagingService extends ChangeNotifier {
  MessagingService({this.onMessageReceived});

  /// Called for every message that arrives from the other party.
  final void Function(ChatThread thread, ChatMessage message)?
  onMessageReceived;

  /// Kept newest-conversation-first.
  final List<ChatThread> _threads = [];
  final Map<String, Timer> _typingTimers = {};
  final Map<String, Timer> _replyTimers = {};

  /// The open Realtime channel, tracked so [reset]/[dispose] can close it.
  RealtimeChannel? _realtimeChannel;

  List<ChatThread> get threads => List.unmodifiable(_threads);

  bool get isEmpty => _threads.isEmpty;

  int get unreadCount =>
      _threads.fold(0, (total, thread) => total + thread.unreadCount);

  /// True when [send] persists to Supabase instead of simulating a reply.
  bool get isLive => ChatRepository.instance.isAvailable;

  /// Opens the connected inbox: loads every conversation the signed-in user is
  /// part of and starts listening for new messages. Offline it is a no-op.
  Future<void> bootstrap() async {
    _cancelRealtime();
    if (!ChatRepository.instance.isAvailable) return;
    try {
      await refreshThreads();
    } catch (_) {
      // A failed inbox load must not block the app; Realtime still catches the
      // next message and rebuilds the thread lazily.
    }
    _subscribeRealtime();
  }

  /// Pulls the conversations list from Supabase, merging every remote thread
  /// into the local inbox without disturbing unread counts. Local threads that
  /// have yet to touch the backend (an open compose form) survive the merge.
  Future<void> refreshThreads() async {
    if (!ChatRepository.instance.isAvailable) return;

    final rows = await ChatRepository.instance.fetchConversations();
    final rebuilt = <ChatThread>[];
    for (final row in rows) {
      final remote = _threadFromConversation(row);
      if (remote == null) continue;
      final existing = _mergeMatch(remote);
      rebuilt.add(
        existing == null
            ? remote
            : existing.copyWith(
                messages: remote.messages,
                participantName: remote.participantName,
                participantInitials: remote.participantInitials,
                participantAvatarUrl: remote.participantAvatarUrl,
              ),
      );
    }

    final present = {for (final t in rebuilt) t.id};
    final locals = _threads
        .where((t) => t.backendId.isEmpty && !present.contains(t.id))
        .toList();

    _threads
      ..clear()
      ..addAll([...rebuilt, ...locals]);
    _sortThreads();
    notifyListeners();
  }

  /// Loads the full history of an open conversation from Supabase. Called when
  /// a thread screen opens, so the inbox's one-line preview is never mistaken
  /// for the whole conversation. Offline it is a no-op — the local copy is
  /// already complete.
  Future<void> loadThreadHistory(String threadId) async {
    if (!ChatRepository.instance.isAvailable) return;
    final index = _threadIndexById(threadId);
    if (index == -1) return;
    final conversationId = _threads[index].backendId.isEmpty
        ? _threads[index].id
        : _threads[index].backendId;
    final messages = await ChatRepository.instance.fetchMessages(conversationId);
    if (messages.isEmpty) return;

    final after = _threadIndexById(threadId);
    if (after == -1) return;
    _replaced(_threads[after].copyWith(messages: messages), after);
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
      sellerId: role.isBuyer ? pet.seller.id : (ChatRepository.instance.userId ?? ''),
      messages: const [],
    );

    _threads.insert(0, thread);
    notifyListeners();
    return thread;
  }

  /// Seller side of an enquiry: resolves the live conversation a buyer started
  /// on [pet] (there can only be a few — one conversation per buyer), falling
  /// back to a local thread when no backend enquiry exists yet.
  Future<ChatThread?> openSellerThread(PetModel pet) async {
    if (!ChatRepository.instance.isAvailable) {
      return openThread(pet: pet, role: ChatRole.seller);
    }
    final sellerId = ChatRepository.instance.userId ?? '';
    final rows = await ChatRepository.instance.conversationsForPet(
      petId: pet.id,
      sellerId: sellerId,
    );
    if (rows.isEmpty) return openThread(pet: pet, role: ChatRole.seller);
    final remote = _threadFromConversation(rows.first);
    if (remote == null) return openThread(pet: pet, role: ChatRole.seller);

    final existing = threadById(remote.id);
    final merged = existing == null
        ? remote
        : existing.copyWith(
            messages: remote.messages,
            participantName: remote.participantName,
            participantInitials: remote.participantInitials,
            participantAvatarUrl: remote.participantAvatarUrl,
          );
    final index = _threadIndexById(merged.id);
    if (index == -1) {
      _threads.insert(0, merged);
      _sortThreads();
    } else {
      _replaced(merged, index);
    }
    return merged;
  }

  /// Sends a message. Live mode persists it and the other party receives it
  /// over Realtime; offline mode lets a local stand-in reply.
  Future<void> send(String threadId, String text) async {
    final thread = threadById(threadId);
    final trimmed = text.trim();
    if (thread == null || trimmed.isEmpty) return;

    if (ChatRepository.instance.isAvailable) {
      await _sendLive(threadId, thread, trimmed);
      return;
    }

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

  /// Delivers a message from the other party. This is what Realtime calls for
  /// every live message, and is also the offline entry point the demo used
  /// before the backend existed.
  void receive(String threadId, String text) {
    final trimmed = text.trim();
    if (_threadIndexById(threadId) == -1 || trimmed.isEmpty) return;

    _deliverIncoming(
      threadId,
      ChatMessage(
        id: _messageId(),
        text: trimmed,
        isMine: false,
        sentAt: DateTime.now(),
      ),
    );
  }

  /// Clears the unread badge and marks the user's own messages as read.
  void markRead(String threadId) {
    final index = _threadIndexById(threadId);
    if (index == -1) return;

    final thread = _threads[index];
    if (thread.unreadCount == 0 &&
        thread.messages.every(
          (m) => !m.isMine || m.status == MessageStatus.read,
        )) {
      return;
    }

    _replaced(
      thread.copyWith(
        unreadCount: 0,
        messages: thread.messages
            .map((m) => m.isMine ? m.copyWith(status: MessageStatus.read) : m)
            .toList(),
      ),
      index,
    );
  }

  void deleteThread(String threadId) {
    _cancelTimers(threadId);
    final before = _threads.length;
    _threads.removeWhere((t) => t.id == threadId || t.backendId == threadId);
    if (_threads.length != before) notifyListeners();
  }

  void reset() {
    _cancelRealtime();
    for (final id in [..._typingTimers.keys, ..._replyTimers.keys]) {
      _cancelTimers(id);
    }
    if (_threads.isEmpty) return;
    _threads.clear();
    notifyListeners();
  }

  // ------------------------------------------------------------- internals

  void _onRealtimeMessage(Map<String, dynamic> record) {
    final me = ChatRepository.instance.userId;
    if (me == null) return;
    // The sender also receives their own insert over Realtime; that message
    // was already appended optimistically by [send].
    if ((record['sender_id'] ?? '').toString() == me) return;

    final conversationId = (record['conversation_id'] ?? '').toString();
    final body = (record['body'] ?? '').toString().trim();
    if (conversationId.isEmpty || body.isEmpty) return;

    final message = ChatMessage(
      id: (record['id'] ?? '').toString(),
      text: body,
      isMine: false,
      sentAt:
          DateTime.tryParse((record['created_at'] ?? '').toString()) ??
          DateTime.now(),
    );

    if (threadById(conversationId) != null) {
      _deliverIncoming(conversationId, message);
      return;
    }
    _ensureThreadFromRemote(conversationId, message);
  }

  /// A Realtime message arrived for a conversation the inbox has not loaded
  /// yet. Fetch its metadata (pet, counterparty) so the thread can appear and
  /// raise an alert instead of being silently dropped.
  Future<void> _ensureThreadFromRemote(
    String conversationId,
    ChatMessage first,
  ) async {
    final row = await ChatRepository.instance.fetchConversation(conversationId);
    if (row == null) return;
    final thread = _threadFromConversation(row);
    if (thread == null) return;

    _threads.insert(0, thread.copyWith(messages: const []));
    notifyListeners();
    _deliverIncoming(conversationId, first);
  }

  void _subscribeRealtime() {
    _cancelRealtime();
    final me = ChatRepository.instance.userId;
    if (me == null) return;
    try {
      _realtimeChannel = SupabaseConfig.client
          .channel('pethub_messages')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'messages',
            callback: (payload) => _onRealtimeMessage(payload.newRecord),
          )
          .subscribe();
    } catch (e) {
      debugPrint('Chat realtime subscribe failed: $e');
    }
  }

  void _cancelRealtime() {
    _realtimeChannel?.unsubscribe();
    _realtimeChannel = null;
  }

  ChatThread? threadById(String id) {
    for (final t in _threads) {
      if (t.id == id || t.backendId == id) return t;
    }
    return null;
  }

  int _threadIndexById(String id) {
    for (var i = 0; i < _threads.length; i++) {
      if (_threads[i].id == id || _threads[i].backendId == id) return i;
    }
    return -1;
  }

  /// Finds the local thread that a freshly-fetched conversation row belongs to,
  /// matched by conversation id on either the thread's own id or [ChatThread.backendId].
  ChatThread? _mergeMatch(ChatThread remote) {
    for (final t in _threads) {
      if (t.id == remote.id || t.backendId == remote.id) return t;
    }
    return null;
  }

  void _deliverIncoming(String threadId, ChatMessage message) {
    final index = _threadIndexById(threadId);
    if (index == -1) return;

    final thread = _threads[index];
    _replaced(
      thread.copyWith(
        messages: [...thread.messages, message],
        isCounterpartyTyping: false,
        unreadCount: thread.unreadCount + 1,
      ),
      index,
    );
    onMessageReceived?.call(threadById(threadId) ?? thread, message);
  }

  Future<void> _sendLive(
    String threadId,
    ChatThread thread,
    String text,
  ) async {
    var conversationId = thread.backendId;
    if (conversationId.isEmpty && thread.sellerId.isNotEmpty) {
      conversationId =
          (await ChatRepository.instance.openConversation(
                petId: thread.petId,
                sellerId: thread.sellerId,
              )) ??
          '';
    }

    if (conversationId.isEmpty) {
      // No row to attach to (e.g. the listing was never persisted). Keep the
      // demo honest and let the local stand-in answer instead of pretending.
      _append(
        threadId,
        ChatMessage(id: _messageId(), text: text, isMine: true, sentAt: DateTime.now()),
      );
      _scheduleLocalReply(threadId);
      return;
    }

    final ok = await ChatRepository.instance.send(
      conversationId: conversationId,
      body: text,
    );

    final index = _threadIndexById(threadId);
    if (index == -1) return;
    final current = _threads[index];

    if (!ok) {
      _scheduleLocalReply(threadId);
      return;
    }

    _replaced(
      current.copyWith(
        backendId: current.backendId.isEmpty ? conversationId : current.backendId,
        messages: [
          ...current.messages,
          ChatMessage(id: _messageId(), text: text, isMine: true, sentAt: DateTime.now()),
        ],
      ),
      index,
    );
  }

  void _append(String threadId, ChatMessage message) {
    final index = _threadIndexById(threadId);
    if (index == -1) return;
    final thread = _threads[index];
    _replaced(thread.copyWith(messages: [...thread.messages, message]), index);
  }

  void _replaced(ChatThread thread, int index) {
    _threads[index] = thread;
    _sortThreads();
    notifyListeners();
  }

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
    final index = _threadIndexById(threadId);
    if (index == -1) return;
    final thread = _threads[index];
    if (thread.isCounterpartyTyping == typing) return;
    _replaced(thread.copyWith(isCounterpartyTyping: typing), index);
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

  /// Builds a [ChatThread] from a `conversations` row joined to the pet, the
  /// two profiles and the latest message. [ChatRepository.fetchConversations]
  /// already limits the embedded messages to one row.
  ChatThread? _threadFromConversation(Map<String, dynamic> row) {
    final me = ChatRepository.instance.userId;
    if (me == null) return null;

    final id = (row['id'] ?? '').toString();
    final sellerId = (row['seller_id'] ?? '').toString();
    final amSeller = sellerId == me;

    final pet = row['pet'] is Map
        ? Map<String, dynamic>.from(row['pet'] as Map)
        : const <String, dynamic>{};
    final images = pet['image_urls'];
    final petImage = images is List && images.isNotEmpty
        ? images.first.toString()
        : '';

    final profile = amSeller ? _mapOf(row['buyer']) : _mapOf(row['seller']);
    final name = _profileName(profile, fallback: amSeller ? 'Buyer' : 'Seller');

    final lastMap = row['messages'] is List && (row['messages'] as List).isNotEmpty
        ? Map<String, dynamic>.from((row['messages'] as List).last as Map)
        : null;
    final last = lastMap == null
        ? null
        : ChatMessage(
            id: (lastMap['id'] ?? '').toString(),
            text: (lastMap['body'] ?? '').toString(),
            isMine: (lastMap['sender_id'] ?? '').toString() == me,
            sentAt:
                DateTime.tryParse((lastMap['created_at'] ?? '').toString()) ??
                DateTime.now(),
          );

    return ChatThread(
      id: id,
      backendId: id,
      sellerId: sellerId,
      petId: (row['pet_id'] ?? '').toString(),
      petName: (pet['name'] ?? 'Pets').toString(),
      petImage: petImage,
      participantName: name,
      participantInitials: Helpers.initials(name),
      participantAvatarUrl: (profile['avatar_url'] ?? '').toString(),
      role: amSeller ? ChatRole.seller : ChatRole.buyer,
      messages: last == null ? const [] : [last],
    );
  }

  Map<String, dynamic> _mapOf(Object? value) => value is Map
      ? Map<String, dynamic>.from(value)
      : const <String, dynamic>{};

  /// `buyer_id` lives on the buyer's profile; anonymous guests never see the
  /// other user because anonymous browsing of profiles is blocked by RLS.
  String _profileName(Map<String, dynamic> profile, {required String fallback}) {
    final name = (profile['full_name'] ?? '').toString().trim();
    return name.isEmpty ? fallback : name;
  }

  @override
  void dispose() {
    _cancelRealtime();
    for (final id in [..._typingTimers.keys, ..._replyTimers.keys]) {
      _cancelTimers(id);
    }
    super.dispose();
  }
}