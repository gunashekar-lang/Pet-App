import 'package:flutter/foundation.dart';

import '../app/routes.dart';
import '../utils/constants.dart';

/// How severe a notification is, used for icon and colour selection.
enum NotificationKind { message, listing, order, health, system }

/// A single in-app notification. Replace the repository behind
/// [NotificationService] with an API/push source in production.
@immutable
class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    this.kind = NotificationKind.system,
    this.isRead = false,
    this.targetRoute,
    this.targetArguments,
  });

  final String id;
  final String title;
  final String body;
  final DateTime createdAt;
  final NotificationKind kind;
  final bool isRead;
  final String? targetRoute;
  final Object? targetArguments;

  AppNotification copyWith({bool? isRead}) {
    return AppNotification(
      id: id,
      title: title,
      body: body,
      createdAt: createdAt,
      kind: kind,
      isRead: isRead ?? this.isRead,
      targetRoute: targetRoute,
      targetArguments: targetArguments,
    );
  }
}

/// Holds the notification inbox for the signed-in user.
///
/// The list starts empty and is populated by real app events (new enquiry,
/// order status change, listing expiry) plus whatever a push/API layer pushes
/// in through [push].
class NotificationService extends ChangeNotifier {
  NotificationService();

  final List<AppNotification> _items = [];

  /// Newest first.
  List<AppNotification> get items => List.unmodifiable(_items);

  int get unreadCount => _items.where((n) => !n.isRead).length;

  bool get isEmpty => _items.isEmpty;

  /// Adds a notification and notifies listeners so the bell badge updates.
  void push(AppNotification notification) {
    _items.insert(0, notification);
    notifyListeners();
  }

  void markRead(String id) {
    final index = _items.indexWhere((n) => n.id == id);
    if (index == -1 || _items[index].isRead) return;
    _items[index] = _items[index].copyWith(isRead: true);
    notifyListeners();
  }

  void markAllRead() {
    var changed = false;
    for (var i = 0; i < _items.length; i++) {
      if (_items[i].isRead) continue;
      _items[i] = _items[i].copyWith(isRead: true);
      changed = true;
    }
    if (changed) notifyListeners();
  }

  void clear() {
    if (_items.isEmpty) return;
    _items.clear();
    notifyListeners();
  }

  /// Pull-to-refresh. Notifications are local-only, so there is nothing to
  /// re-fetch yet; this keeps the gesture working and settles the spinner.
  Future<void> refresh() async {
    await Future<void>.delayed(AppConstants.shortDelay);
    notifyListeners();
  }

  void remove(String id) {
    final before = _items.length;
    _items.removeWhere((n) => n.id == id);
    if (_items.length != before) notifyListeners();
  }

  // ------------------------------------------------------- event shorthands

  /// The user sent an enquiry to a seller.
  AppNotification enquirySent({
    required String petName,
    required String petId,
    String? threadId,
  }) {
    final n = AppNotification(
      id: _newId(),
      title: 'Enquiry sent',
      body: 'Your message about $petName was sent to the seller.',
      createdAt: DateTime.now(),
      kind: NotificationKind.message,
      targetRoute: threadId == null
          ? AppRoutes.petDetails
          : AppRoutes.chatThread,
      targetArguments: threadId == null
          ? PetDetailsArgs(petId)
          : ChatThreadArgs(threadId),
    );
    push(n);
    return n;
  }

  /// The user completed a purchase of a pet.
  AppNotification purchaseCompleted({
    required String petName,
    required String threadId,
  }) {
    final n = AppNotification(
      id: _newId(),
      title: 'Purchase complete',
      body:
          '$petName is yours. Arrange collection with the seller in the '
          'conversation.',
      createdAt: DateTime.now(),
      kind: NotificationKind.order,
      targetRoute: AppRoutes.chatThread,
      targetArguments: ChatThreadArgs(threadId),
    );
    push(n);
    return n;
  }

  /// A buyer or seller sent a message in one of the user's conversations.
  AppNotification messageReceived({
    required String threadId,
    required String senderName,
    required String preview,
  }) {
    final n = AppNotification(
      id: _newId(),
      title: senderName,
      body: preview,
      createdAt: DateTime.now(),
      kind: NotificationKind.message,
      targetRoute: AppRoutes.chatThread,
      targetArguments: ChatThreadArgs(threadId),
    );
    push(n);
    return n;
  }

  /// A listing the user created went live.
  AppNotification listingPublished({
    required String petName,
    required String petId,
  }) {
    final n = AppNotification(
      id: _newId(),
      title: 'Listing published',
      body: '$petName is now visible to buyers.',
      createdAt: DateTime.now(),
      kind: NotificationKind.listing,
      targetRoute: AppRoutes.petDetails,
      targetArguments: PetDetailsArgs(petId),
    );
    push(n);
    return n;
  }

  /// A new enquiry arrived on one of the user's listings.
  AppNotification newEnquiry({
    required String petName,
    required String petId,
    required String buyerName,
  }) {
    final n = AppNotification(
      id: _newId(),
      title: 'New enquiry',
      body: '$buyerName is interested in $petName.',
      createdAt: DateTime.now(),
      kind: NotificationKind.message,
      targetRoute: AppRoutes.petDetails,
      targetArguments: PetDetailsArgs(petId),
    );
    push(n);
    return n;
  }

  /// A store order changed state.
  AppNotification orderUpdate({
    required String orderId,
    required String message,
  }) {
    final n = AppNotification(
      id: _newId(),
      title: 'Order update',
      body: message,
      createdAt: DateTime.now(),
      kind: NotificationKind.order,
      targetRoute: AppRoutes.orderDetails,
      targetArguments: OrderDetailsArgs(orderId),
    );
    push(n);
    return n;
  }

  /// Something the user has not acted on yet.
  AppNotification reminder({
    required String title,
    required String body,
    String? targetRoute,
    Object? targetArguments,
  }) {
    final n = AppNotification(
      id: _newId(),
      title: title,
      body: body,
      createdAt: DateTime.now(),
      kind: NotificationKind.system,
      targetRoute: targetRoute,
      targetArguments: targetArguments,
    );
    push(n);
    return n;
  }

  /// Clears the inbox, e.g. on logout.
  void reset() {
    if (_items.isEmpty) return;
    _items.clear();
    notifyListeners();
  }

  String _newId() => 'n_${DateTime.now().microsecondsSinceEpoch}';
}
