import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../app/routes.dart';
import '../../models/chat_model.dart';
import '../../models/pet_model.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/messaging_service.dart';
import '../../services/notification_service.dart';
import '../../services/pet_service.dart';
import '../../utils/constants.dart';
import '../../utils/helpers.dart';
import '../../widgets/common.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/section_header.dart';

/// Compose and send an enquiry to a pet seller, then optionally complete the
/// purchase. This is the "Contact seller" flow required by the spec.
class ContactSellerScreen extends StatefulWidget {
  const ContactSellerScreen({super.key, required this.petId});

  final String petId;

  @override
  State<ContactSellerScreen> createState() => _ContactSellerScreenState();
}

class _ContactSellerScreenState extends State<ContactSellerScreen> {
  final _messageController = TextEditingController();
  bool _agreeToMeet = true;
  bool _sent = false;
  String? _threadId;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  String _defaultMessage(PetModel pet) =>
      'Hi ${pet.seller.name.split(' ').first}, I\'m interested in ${pet.name}. '
      'Could you tell me a bit more about ${pet.name == 'it' ? 'them' : pet.name} '
      'and whether they are still available?';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pet = context.read<PetService>().petById(widget.petId);
      if (pet != null) _messageController.text = _defaultMessage(pet);
    });
  }

  Future<void> _send() async {
    final pet = context.read<PetService>().petById(widget.petId);
    if (pet == null) return;

    final message = _messageController.text.trim();
    if (message.length < 10) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Please add a little more detail to your message'),
          ),
        );
      return;
    }

    final user = context.read<AuthService>().currentUser;
    await context.read<PetService>().contactSeller(
      pet: pet,
      buyerId: user.id,
      buyerName: user.fullName,
      message: message,
    );

    if (!mounted) return;
    // The enquiry opens a real conversation, so the seller's reply lands in
    // the Chat tab instead of a canned assistant.
    final thread = context.read<MessagingService>().openThread(
      pet: pet,
      role: ChatRole.buyer,
    );
    await context.read<MessagingService>().send(thread.id, message);

    if (!mounted) return;
    context.read<NotificationService>().enquirySent(
      petName: pet.name,
      petId: pet.id,
      threadId: thread.id,
    );
    HapticFeedback.mediumImpact();
    setState(() {
      _threadId = thread.id;
      _sent = true;
    });
  }

  Future<void> _buyNow(PetModel pet) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _ConfirmPurchaseDialog(pet: pet),
    );
    if (confirmed != true || !mounted) return;

    final user = context.read<AuthService>().currentUser;
    final purchase = await context.read<PetService>().purchasePet(
      pet: pet,
      buyerId: user.id,
    );

    if (!mounted) return;
    final thread = context.read<MessagingService>().openThread(
      pet: pet,
      role: ChatRole.buyer,
    );
    context.read<NotificationService>().purchaseCompleted(
      petName: pet.name,
      threadId: thread.id,
    );
    HapticFeedback.heavyImpact();
    await showDialog<void>(
      context: context,
      builder: (_) => _PurchaseSuccessDialog(
        purchase: purchase,
        pet: pet,
        onMessageSeller: () {
          Nav.pop(context);
          Nav.push(context, AppRoutes.chatThread, ChatThreadArgs(thread.id));
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<PetService>();
    final pet = service.petById(widget.petId);
    final scheme = Theme.of(context).colorScheme;

    if (pet == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Contact seller'),
          leading: IconButton(
            onPressed: () => Nav.pop(context),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
        ),
        body: EmptyState(
          icon: Icons.pets_rounded,
          title: 'Listing unavailable',
          message: 'This pet is no longer listed.',
          actionLabel: 'Go back',
          onAction: () => Nav.pop(context),
        ),
      );
    }

    if (_sent) {
      return _SentView(
        pet: pet,
        onBuy: () => _buyNow(pet),
        onOpenChat: () {
          final threadId = _threadId;
          if (threadId == null) return;
          Nav.push(context, AppRoutes.chatThread, ChatThreadArgs(threadId));
        },
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Contact seller'),
        leading: IconButton(
          onPressed: () => Nav.pop(context),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
        children: [
          AppCard(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                AppImage(
                  url: pet.image,
                  width: 68,
                  height: 68,
                  borderRadius: BorderRadius.circular(12),
                  icon: pet.species.icon,
                ),
                Gap.w12,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        pet.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        '${pet.breed} • ${pet.ageLabel}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: scheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        Helpers.currency(pet.price),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: scheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Gap.h20,
          Row(
            children: [
              AppAvatar(
                url: pet.seller.avatarUrl,
                initials: Helpers.initials(pet.seller.name),
                size: 46,
              ),
              Gap.w12,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            pet.seller.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (pet.seller.verified) ...[
                          Gap.w6,
                          Icon(
                            Icons.verified_rounded,
                            size: 15,
                            color: scheme.secondary,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${pet.seller.rating.toStringAsFixed(1)} ★ • ${pet.seller.location}',
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurface.withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                ),
              ),
              CircleIconButton(
                icon: Icons.call_rounded,
                tooltip: 'Call seller',
                onTap: () => ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    SnackBar(
                      content: Text('Calling ${pet.seller.name}…'),
                      duration: const Duration(seconds: 2),
                    ),
                  ),
              ),
            ],
          ),
          Gap.h20,
          const Text(
            'Your message',
            style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
          ),
          Gap.h8,
          TextField(
            controller: _messageController,
            maxLines: 6,
            minLines: 4,
            textCapitalization: TextCapitalization.sentences,
            style: const TextStyle(fontSize: 14, height: 1.5),
            decoration: const InputDecoration(
              hintText:
                  'Tell the seller about yourself and why you are '
                  'interested…',
              alignLabelWithHint: true,
            ),
          ),
          Gap.h12,
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final quick in [
                'Is ${pet.name} still available?',
                'Can I see the health records?',
                'Would you consider an offer?',
                'Can I collect this weekend?',
              ])
                ActionChip(
                  label: Text(quick, style: const TextStyle(fontSize: 12)),
                  onPressed: () =>
                      setState(() => _messageController.text = quick),
                  backgroundColor: scheme.surface,
                  side: BorderSide(color: scheme.outline),
                ),
            ],
          ),
          Gap.h16,
          AppCard(
            onTap: () => setState(() => _agreeToMeet = !_agreeToMeet),
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(
                  _agreeToMeet
                      ? Icons.check_box_rounded
                      : Icons.check_box_outline_blank_rounded,
                  size: 22,
                  color: _agreeToMeet ? AppColors.success : scheme.outline,
                ),
                Gap.w12,
                Expanded(
                  child: Text(
                    'I understand I should meet the pet in person before paying '
                    'any deposit.',
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.4,
                      color: scheme.onSurface.withValues(alpha: 0.75),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Gap.h16,
          InfoBanner(
            icon: Icons.shield_rounded,
            color: AppColors.warning,
            title: 'Stay safe',
            message:
                'Never send a deposit before meeting the pet and checking '
                'the records. PetHub will never ask you to wire money.',
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        decoration: BoxDecoration(
          color: scheme.surface,
          border: Border(top: BorderSide(color: scheme.outline)),
        ),
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              Expanded(
                child: CustomButton(
                  label: 'Buy now',
                  variant: ButtonVariant.secondary,
                  icon: Icons.shopping_bag_rounded,
                  isLoading: service.isSubmitting,
                  onPressed: () => _buyNow(pet),
                ),
              ),
              Gap.w10,
              Expanded(
                flex: 2,
                child: CustomButton(
                  label: 'Send message',
                  icon: Icons.send_rounded,
                  isLoading: service.isSubmitting,
                  onPressed: _agreeToMeet ? _send : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SentView extends StatelessWidget {
  const _SentView({
    required this.pet,
    required this.onBuy,
    required this.onOpenChat,
  });

  final PetModel pet;
  final VoidCallback onBuy;
  final VoidCallback onOpenChat;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Nav.pop(context),
          icon: const Icon(Icons.close_rounded),
        ),
        title: const Text('Message sent'),
      ),
      body: EmptyState(
        icon: Icons.mark_email_read_rounded,
        title: 'Your message is on its way',
        message:
            '${pet.seller.name} typically replies within an hour. Open the '
            'conversation to keep chatting, or buy ${pet.name} straight away.',
        actionLabel: 'Open conversation',
        onAction: onOpenChat,
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: CustomButton(
          label: 'Buy ${pet.name} now',
          variant: ButtonVariant.secondary,
          icon: Icons.shopping_bag_rounded,
          onPressed: onBuy,
        ),
      ),
    );
  }
}

class _ConfirmPurchaseDialog extends StatelessWidget {
  const _ConfirmPurchaseDialog({required this.pet});

  final PetModel pet;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppImage(
                url: pet.image,
                width: 56,
                height: 56,
                borderRadius: BorderRadius.circular(12),
                icon: pet.species.icon,
              ),
              Gap.w12,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Buy ${pet.name}?',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      pet.breed,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: scheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Gap.h20,
          _Line(label: 'Price', value: Helpers.currency(pet.price)),
          _Line(label: 'Platform fee', value: 'Free'),
          _Line(label: 'Total', value: Helpers.currency(pet.price), bold: true),
          Gap.h16,
          const Divider(),
          Gap.h12,
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.info_rounded,
                size: 16,
                color: AppColors.warning,
              ),
              Gap.w8,
              Expanded(
                child: Text(
                  'You will arrange collection with the seller directly. PetHub '
                  'holds payment until you confirm you received the pet.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.45,
                    color: scheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Nav.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Nav.pop(context, true),
          child: const Text('Confirm purchase'),
        ),
      ],
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.label, required this.value, this.bold = false});

  final String label;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: bold ? 14.5 : 13.5,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
              color: bold
                  ? scheme.onSurface
                  : scheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: bold ? 16 : 13.5,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              color: bold ? scheme.primary : scheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _PurchaseSuccessDialog extends StatelessWidget {
  const _PurchaseSuccessDialog({
    required this.purchase,
    required this.pet,
    required this.onMessageSeller,
  });

  final PetPurchase purchase;
  final PetModel pet;
  final VoidCallback onMessageSeller;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              color: Color(0x1A12B886),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_rounded,
              size: 38,
              color: AppColors.success,
            ),
          ),
          Gap.h20,
          const Text(
            'Congratulations! 🎉',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          Gap.h8,
          Text(
            '${pet.name} is officially yours. Contact ${pet.seller.name} to '
            'arrange collection and handover of the health records.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              height: 1.5,
              color: scheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          Gap.h16,
          AppCard(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                AppImage(
                  url: pet.image,
                  width: 52,
                  height: 52,
                  borderRadius: BorderRadius.circular(10),
                  icon: pet.species.icon,
                ),
                Gap.w12,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Order #${purchase.id}',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        Helpers.currency(purchase.amount),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: scheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(
          onPressed: () => Nav.pop(context),
          child: const Text('Done'),
        ),
        FilledButton(
          onPressed: onMessageSeller,
          child: const Text('Message seller'),
        ),
      ],
    );
  }
}
