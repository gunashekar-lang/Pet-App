import 'package:flutter/foundation.dart';

import '../models/chat_model.dart';
import 'supabase_config.dart';

/// Persisted buyer ↔ seller conversations on top of `public.conversations` and
/// `public.messages` (see supabase/schema.sql).
///
/// Mirrors the other repositories: returns empty / null / false rather than
/// throwing, and every write path checks for a signed-in session. Reading your
/// own inbox needs a session too, because RLS only admits the two participants
/// of a conversation.
class ChatRepository {
  ChatRepository._();

  static final ChatRepository instance = ChatRepository._();

  static const String _conversations = 'conversations';
  static const String _messages = 'messages';

  /// True when messaging can be read and written (a signed-in session exists).
  bool get isAvailable =>
      SupabaseConfig.isInitialised &&
      SupabaseConfig.client.auth.currentSession != null;

  String? get userId => SupabaseConfig.isInitialised
      ? SupabaseConfig.client.auth.currentUser?.id
      : null;

  /// The join shape used for both the inbox and a single conversation. The
  /// embedded `messages(order, limit)` takes only the latest row, which is all
  /// the inbox needs to render a preview.
  static const String _conversationSelect =
      'id, pet_id, buyer_id, seller_id, created_at, '
      'pet:pets!conversations_pet_id_fkey(name, image_urls), '
      'buyer:profiles!conversations_buyer_id_fkey(full_name, avatar_url), '
      'seller:profiles!conversations_seller_id_fkey(full_name, avatar_url), '
      'messages(order=created_at.desc,limit=1)';

  /// Finds the conversation for a buyer on a listing, creating it on first
  /// contact. Returns the conversation id, or null when the row cannot exist
  /// (e.g. the listing was never persisted).
  Future<String?> openConversation({
    required String petId,
    required String sellerId,
  }) async {
    if (!isAvailable) return null;
    final me = userId;
    if (me == null) return null;

    try {
      final existing = await SupabaseConfig.client
          .from(_conversations)
          .select('id')
          .eq('pet_id', petId)
          .eq('buyer_id', me)
          .maybeSingle();
      if (existing != null) return existing['id'].toString();

      try {
        final created = await SupabaseConfig.client
            .from(_conversations)
            .insert({'pet_id': petId, 'buyer_id': me, 'seller_id': sellerId})
            .select('id')
            .maybeSingle();
        if (created != null) return created['id'].toString();
      } catch (_) {
        // Two taps can race the unique(pet_id, buyer_id) index; fall through
        // and read back whatever row won.
      }

      final created = await SupabaseConfig.client
          .from(_conversations)
          .select('id')
          .eq('pet_id', petId)
          .eq('buyer_id', me)
          .maybeSingle();
      return created?['id']?.toString();
    } catch (e) {
      debugPrint('Chat openConversation failed: $e');
      return null;
    }
  }

  /// Conversations the signed-in user is part of, newest last-message first.
  Future<List<Map<String, dynamic>>> fetchConversations() async {
    if (!isAvailable) return const [];
    try {
      final rows = await SupabaseConfig.client
          .from(_conversations)
          .select(_conversationSelect)
          .order('created_at', ascending: false);
      return _castRows(rows);
    } catch (e) {
      debugPrint('Chat fetchConversations failed: $e');
      return const [];
    }
  }

  /// A single conversation — used when a realtime event arrives for one the
  /// inbox has not loaded yet.
  Future<Map<String, dynamic>?> fetchConversation(String conversationId) async {
    if (!isAvailable) return null;
    try {
      final row = await SupabaseConfig.client
          .from(_conversations)
          .select(_conversationSelect)
          .eq('id', conversationId)
          .maybeSingle();
      return row == null ? null : Map<String, dynamic>.from(row);
    } catch (e) {
      debugPrint('Chat fetchConversation failed: $e');
      return null;
    }
  }

  /// Buyer enquiries about one of the signed-in user's listings.
  Future<List<Map<String, dynamic>>> conversationsForPet({
    required String petId,
    required String sellerId,
  }) async {
    if (!isAvailable) return const [];
    try {
      final rows = await SupabaseConfig.client
          .from(_conversations)
          .select(_conversationSelect)
          .eq('pet_id', petId)
          .eq('seller_id', sellerId)
          .order('created_at', ascending: false);
      return _castRows(rows);
    } catch (e) {
      debugPrint('Chat conversationsForPet failed: $e');
      return const [];
    }
  }

  /// Full history of a conversation, oldest first.
  Future<List<ChatMessage>> fetchMessages(String conversationId) async {
    if (!isAvailable) return const [];
    try {
      final rows = await SupabaseConfig.client
          .from(_messages)
          .select('id, sender_id, body, created_at')
          .eq('conversation_id', conversationId)
          .order('created_at');
      return rows.map((r) => _messageFromRow(Map<String, dynamic>.from(r))).toList();
    } catch (e) {
      debugPrint('Chat fetchMessages failed: $e');
      return const [];
    }
  }

  /// Inserts a message. Returns false when rejected.
  Future<bool> send({required String conversationId, required String body}) async {
    if (!isAvailable) return false;
    final me = userId;
    if (me == null) return false;
    try {
      await SupabaseConfig.client.from(_messages).insert({
        'conversation_id': conversationId,
        'sender_id': me,
        'body': body,
      });
      return true;
    } catch (e) {
      debugPrint('Chat send failed: $e');
      return false;
    }
  }

  List<Map<String, dynamic>> _castRows(List<Map<String, dynamic>> rows) =>
      rows.map((r) => Map<String, dynamic>.from(r)).toList();

  ChatMessage _messageFromRow(Map<String, dynamic> row) => ChatMessage(
    id: (row['id'] ?? '').toString(),
    text: (row['body'] ?? '').toString(),
    isMine: (row['sender_id'] ?? '').toString() == userId,
    sentAt:
        DateTime.tryParse((row['created_at'] ?? '').toString()) ?? DateTime.now(),
  );
}