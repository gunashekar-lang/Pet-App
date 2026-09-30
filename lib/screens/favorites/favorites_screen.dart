import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/routes.dart';
import '../../services/pet_service.dart';
import '../../utils/helpers.dart';
import '../../widgets/pet_card.dart';
import '../../widgets/section_header.dart';

/// Shortlisted pets, split into a grid with quick remove / view actions.
class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = context.watch<PetService>();
    final pets = service.favoritePets;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Favourites'),
        leading: IconButton(
          onPressed: () => Nav.pop(context),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        actions: [
          if (pets.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  Helpers.plural(pets.length, 'saved pet'),
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.55),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: pets.isEmpty
          ? EmptyState(
              icon: Icons.favorite_border_rounded,
              title: 'No favourites yet',
              message:
                  'Tap the heart on any listing to shortlist it here. We '
                  'will nudge you if a saved pet drops in price.',
              actionLabel: 'Browse pets',
              onAction: () => Nav.pop(context),
            )
          : GridView.builder(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 230,
                mainAxisExtent: 292,
                crossAxisSpacing: 12,
                mainAxisSpacing: 14,
              ),
              itemCount: pets.length,
              itemBuilder: (context, i) {
                final pet = pets[i];
                return PetCard(
                  pet: pet,
                  isFavorite: true,
                  onFavoriteToggle: () => service.toggleFavorite(pet.id),
                  onTap: () => Nav.push(
                    context,
                    AppRoutes.petDetails,
                    PetDetailsArgs(pet.id),
                  ),
                );
              },
            ),
    );
  }
}
