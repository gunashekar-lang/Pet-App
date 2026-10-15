import 'package:flutter/material.dart';

/// Which side of a conversation the signed-in user is on.
enum ChatRole {
  /// The user is buying — the other party is the seller.
  buyer,

  /// The user owns the listing — the other party is the buyer.
  seller;

  bool get isBuyer => this == ChatRole.buyer;
}

/// Delivery state of an outgoing message.
enum MessageStatus { sent, read }

/// A single chat message between the signed-in user and the other party.
@immutable
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.text,
    required this.isMine,
    required this.sentAt,
    this.status = MessageStatus.sent,
  });

  final String id;
  final String text;

  /// True when the signed-in user wrote it.
  final bool isMine;
  final DateTime sentAt;

  /// Only meaningful for outgoing messages.
  final MessageStatus status;

  ChatMessage copyWith({MessageStatus? status}) => ChatMessage(
    id: id,
    text: text,
    isMine: isMine,
    sentAt: sentAt,
    status: status ?? this.status,
  );
}

/// A buyer ↔ seller conversation about one pet listing.
@immutable
class ChatThread {
  const ChatThread({
    required this.id,
    required this.petId,
    required this.petName,
    required this.petImage,
    required this.participantName,
    required this.participantInitials,
    required this.role,
    required this.messages,
    this.participantAvatarUrl = '',
    this.isCounterpartyTyping = false,
    this.unreadCount = 0,
    this.sellerId = '',
    this.backendId = '',
  });

  /// Stable id derived from the listing and the side of the conversation, so
  /// the same listing never produces two threads. Backed by Supabase, this is
  /// the conversations row's uuid instead.
  final String id;
  final String petId;
  final String petName;
  final String petImage;

  /// The other party: a seller when [role] is buyer, otherwise a buyer.
  final String participantName;
  final String participantInitials;
  final String participantAvatarUrl;
  final ChatRole role;

  final List<ChatMessage> messages;
  final bool isCounterpartyTyping;
  final int unreadCount;

  /// The listing's seller profile id, needed to start a live conversation.
  final String sellerId;

  /// The Supabase `conversations` row id once one exists. The local [id] stays
  /// stable so an open chat screen keeps working while the backend id is being
  /// resolved.
  final String backendId;

  /// True when the other party is a buyer chasing one of the user's listings.
  bool get counterpartyIsBuyer => role == ChatRole.seller;

  String get counterpartLabel => counterpartyIsBuyer ? 'Buyer' : 'Seller';

  /// The pet or dog/cat the conversation is about.
  String get subject => petName;

  ChatMessage? get lastMessage => messages.isEmpty ? null : messages.last;

  ChatThread copyWith({
    List<ChatMessage>? messages,
    bool? isCounterpartyTyping,
    int? unreadCount,
    String? participantName,
    String? participantInitials,
    String? participantAvatarUrl,
    String? sellerId,
    String? backendId,
  }) => ChatThread(
    id: id,
    petId: petId,
    petName: petName,
    petImage: petImage,
    participantName: participantName ?? this.participantName,
    participantInitials: participantInitials ?? this.participantInitials,
    participantAvatarUrl: participantAvatarUrl ?? this.participantAvatarUrl,
    role: role,
    messages: messages ?? this.messages,
    isCounterpartyTyping: isCounterpartyTyping ?? this.isCounterpartyTyping,
    unreadCount: unreadCount ?? this.unreadCount,
    sellerId: sellerId ?? this.sellerId,
    backendId: backendId ?? this.backendId,
  );
}
