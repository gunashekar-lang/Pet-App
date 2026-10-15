import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/routes.dart';
import '../../models/pet_model.dart';
import '../../services/messaging_service.dart';
import '../../services/pet_service.dart';
import '../../utils/constants.dart';
import '../../utils/helpers.dart';
import '../../widgets/category_card.dart';
import '../../widgets/common.dart';
import '../../widgets/section_header.dart';

/// Seller dashboard: manage, update, mark sold and delete your listings.
class MyListingsScreen extends StatefulWidget {
  const MyListingsScreen({super.key});

  @override
  State<MyListingsScreen> createState() => _MyListingsScreenState();
}

class _MyListingsScreenState extends State<MyListingsScreen> {
  String _tab = 'Active';

  static const List<String> _tabs = ['Active', 'Sold', 'All'];

  @override
  Widget build(BuildContext context) {
    final service = context.watch<PetService>();
    final all = service.myListings;

    final listings = switch (_tab) {
      'Active' => all.where((p) => p.status != PetStatus.sold).toList(),
      'Sold' => all.where((p) => p.status == PetStatus.sold).toList(),
      _ => all,
    };

    final active = all.where((p) => p.status != PetStatus.sold).length;
    final sold = all.where((p) => p.status == PetStatus.sold).length;
    final views = all.fold<int>(0, (sum, p) => sum + p.views);
    final value = all
        .where((p) => p.status != PetStatus.sold)
        .fold<double>(0, (sum, p) => sum + p.price);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My listings'),
        leading: IconButton(
          onPressed: () => Nav.pop(context),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Nav.push(context, AppRoutes.sellPet),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'New listing',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        children: [
          Row(
            children: [
              StatTile(
                label: 'Active',
                value: '$active',
                icon: Icons.pets_rounded,
                color: AppColors.brand,
              ),
              Gap.w10,
              StatTile(
                label: 'Sold',
                value: '$sold',
                icon: Icons.check_circle_rounded,
                color: AppColors.success,
              ),
              Gap.w10,
              StatTile(
                label: 'Views',
                value: '$views',
                icon: Icons.visibility_rounded,
                color: AppColors.accent,
              ),
              Gap.w10,
              StatTile(
                label: 'Value',
                value: Helpers.formatPrice(value),
                icon: Icons.savings_rounded,
                color: AppColors.plum,
              ),
            ],
          ),
          Gap.h20,
          Row(
            children: [
              for (final tab in _tabs) ...[
                if (tab != _tabs.first) Gap.w8,
                ChoiceChip(
                  label: Text(tab),
                  selected: _tab == tab,
                  onSelected: (_) => setState(() => _tab = tab),
                  showCheckmark: false,
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  selectedColor: Theme.of(context).colorScheme.primary,
                  labelStyle: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _tab == tab
                        ? Colors.white
                        : Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ],
          ),
          Gap.h16,
          if (listings.isEmpty)
            EmptyState(
              icon: Icons.inventory_2_outlined,
              title: _tab == 'Sold'
                  ? 'No sold listings yet'
                  : 'No listings here',
              message: _tab == 'Sold'
                  ? 'Listings you have rehomed will appear here.'
                  : 'Create a listing and reach thousands of verified buyers.',
              actionLabel: _tab == 'Sold' ? null : 'Create a listing',
              onAction: _tab == 'Sold'
                  ? null
                  : () => Nav.push(context, AppRoutes.sellPet),
            )
          else
            ...listings.map(
              (pet) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ListingCard(
                  pet: pet,
                  onEdit: () => _editListing(context, pet),
                  onMarkSold: () => _markSold(context, service, pet),
                  onDelete: () => _delete(context, service, pet),
                  onChat: () {
                    _openBuyerChat(context, pet);
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Seller side of the conversation: the other party is a buyer asking about
  /// this listing. Resolves the live conversation when one exists.
  Future<void> _openBuyerChat(BuildContext context, PetModel pet) async {
    final messaging = context.read<MessagingService>();
    final thread = await messaging.openSellerThread(pet);
    if (!context.mounted || thread == null) return;
    Nav.push(context, AppRoutes.chatThread, ChatThreadArgs(thread.id));
  }

  void _editListing(BuildContext context, PetModel pet) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text('Editing ${pet.name} — opens the listing form')),
      );
  }

  Future<void> _markSold(
    BuildContext context,
    PetService service,
    PetModel pet,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        ),
        title: Text('Mark ${pet.name} as sold?'),
        content: const Text(
          'The listing will be removed from the marketplace and added to your '
          'sales history. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Nav.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Nav.pop(context, true),
            child: const Text('Mark as sold'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;
    await service.markAsSold(pet.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('${pet.name} has been rehomed. Congratulations! 🎉'),
        ),
      );
  }

  Future<void> _delete(
    BuildContext context,
    PetService service,
    PetModel pet,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        ),
        title: Text('Delete ${pet.name}?'),
        content: const Text(
          'This permanently removes the listing. You can always create a new one.',
        ),
        actions: [
          TextButton(
            onPressed: () => Nav.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Nav.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;
    await service.deleteListing(pet.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('${pet.name} deleted')));
  }
}

class _ListingCard extends StatelessWidget {
  const _ListingCard({
    required this.pet,
    required this.onEdit,
    required this.onMarkSold,
    required this.onDelete,
    required this.onChat,
  });

  final PetModel pet;
  final VoidCallback onEdit;
  final VoidCallback onMarkSold;
  final VoidCallback onDelete;
  final VoidCallback onChat;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AppCard(
      padding: const EdgeInsets.all(12),
      onTap: () =>
          Nav.push(context, AppRoutes.petDetails, PetDetailsArgs(pet.id)),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppImage(
                url: pet.image,
                width: 76,
                height: 76,
                borderRadius: BorderRadius.circular(12),
                icon: pet.species.icon,
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
                            pet.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        StatusPill(
                          label: pet.status.label,
                          color: switch (pet.status) {
                            PetStatus.available => AppColors.success,
                            PetStatus.reserved => AppColors.warning,
                            PetStatus.sold => scheme.onSurface.withValues(
                              alpha: 0.5,
                            ),
                            PetStatus.pending => AppColors.accent,
                          },
                          dense: true,
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${pet.breed} • ${pet.ageLabel}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: scheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    Gap.h8,
                    Row(
                      children: [
                        Text(
                          Helpers.currency(pet.price),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: scheme.primary,
                          ),
                        ),
                        const Spacer(),
                        _Metric(
                          icon: Icons.visibility_rounded,
                          value: '${pet.views}',
                        ),
                        Gap.w10,
                        _Metric(
                          icon: Icons.favorite_rounded,
                          value: '${pet.favoriteCount}',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          Gap.h12,
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_rounded, size: 16),
                  label: const Text('Edit'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 40),
                    side: BorderSide(color: scheme.outline),
                    textStyle: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              Gap.w8,
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: pet.status == PetStatus.sold ? null : onMarkSold,
                  icon: const Icon(Icons.sell_rounded, size: 16),
                  label: const Text('Sold'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 40),
                    side: BorderSide(color: scheme.outline),
                    textStyle: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              Gap.w8,
              Semantics(
                button: true,
                label: 'Buyer messages for ${pet.name}',
                child: IconButton(
                  onPressed: onChat,
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                  color: scheme.primary,
                  style: IconButton.styleFrom(
                    minimumSize: const Size(40, 40),
                    side: BorderSide(color: scheme.outline),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              Gap.w8,
              Semantics(
                button: true,
                label: 'Delete listing',
                child: IconButton(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline_rounded, size: 20),
                  color: scheme.error,
                  style: IconButton.styleFrom(
                    minimumSize: const Size(40, 40),
                    side: BorderSide(color: scheme.outline),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.icon, required this.value});

  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: scheme.onSurface.withValues(alpha: 0.45)),
        Gap.w2,
        Text(
          value,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: scheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }
}
