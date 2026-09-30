import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/pet_model.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import 'common.dart';
import 'custom_button.dart';

/// Grid-style pet card used across Home, Marketplace, Favourites and
/// related-lists carousels.
class PetCard extends StatelessWidget {
  const PetCard({
    super.key,
    required this.pet,
    required this.onTap,
    this.onFavoriteToggle,
    this.isFavorite = false,
    this.width,
    this.showSeller = false,
  });

  final PetModel pet;
  final VoidCallback onTap;
  final VoidCallback? onFavoriteToggle;
  final bool isFavorite;
  final double? width;
  final bool showSeller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return SizedBox(
      width: width,
      child: Material(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppConstants.radiusMd),
              border: Border.all(color: scheme.outline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _image(context),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              pet.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ),
                          if (pet.isVerified)
                            Icon(
                              Icons.verified_rounded,
                              size: 16,
                              color: scheme.secondary,
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
                      if (showSeller) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            AppAvatar(
                              url: pet.seller.avatarUrl,
                              initials: Helpers.initials(pet.seller.name),
                              size: 20,
                            ),
                            Gap.w6,
                            Expanded(
                              child: Text(
                                pet.seller.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: scheme.onSurface.withValues(
                                    alpha: 0.7,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 10),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            Helpers.currency(pet.price),
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: scheme.primary,
                              letterSpacing: -0.4,
                            ),
                          ),
                          Gap.w4,
                          Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Text(
                              pet.negotiable ? 'negotiable' : 'firm',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w500,
                                color: scheme.onSurface.withValues(alpha: 0.45),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _image(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AspectRatio(
      aspectRatio: 1.15,
      child: Stack(
        fit: StackFit.expand,
        children: [
          AppImage(
            url: pet.image,
            fit: BoxFit.cover,
            icon: pet.species.icon,
            gradientColors: [
              scheme.primary.withValues(alpha: 0.25),
              scheme.primary.withValues(alpha: 0.08),
            ],
          ),
          // Bottom scrim so the white badges stay legible.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.28),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.05),
                  ],
                  stops: const [0, 0.35, 1],
                ),
              ),
            ),
          ),
          if (pet.imageUrls.length > 1)
            Positioned(
              right: 10,
              top: 10,
              child: _imageCounter(pet.imageUrls.length),
            ),
          if (onFavoriteToggle != null)
            Positioned(
              right: 10,
              bottom: 10,
              child: IconActionButton(
                icon: isFavorite
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                isActive: isFavorite,
                activeColor: AppColors.danger,
                foreground: isFavorite ? Colors.white : AppColors.danger,
                size: 34,
                iconSize: 18,
                tooltip: isFavorite
                    ? 'Remove from favourites'
                    : 'Save to favourites',
                onTap: () {
                  HapticFeedback.lightImpact();
                  onFavoriteToggle!();
                },
              ),
            ),
          Positioned(left: 10, top: 10, child: _badges(context)),
        ],
      ),
    );
  }

  Widget _badges(BuildContext context) {
    final badges = <Widget>[];

    if (pet.condition == PetCondition.newArrival) {
      badges.add(
        const StatusPill(
          label: 'NEW',
          icon: Icons.auto_awesome_rounded,
          color: AppColors.accent,
          solid: true,
          dense: true,
        ),
      );
    } else if (pet.status == PetStatus.reserved) {
      badges.add(
        const StatusPill(
          label: 'Reserved',
          color: AppColors.warning,
          solid: true,
          dense: true,
        ),
      );
    }

    if (pet.vaccinated && pet.healthChecked) {
      badges.add(
        Container(
          margin: const EdgeInsets.only(left: 6),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: AppColors.success,
            borderRadius: BorderRadius.circular(999),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.verified_rounded, size: 11, color: Colors.white),
              SizedBox(width: 3),
              Text(
                'HEALTHY',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Row(mainAxisSize: MainAxisSize.min, children: badges);
  }

  Widget _imageCounter(int count) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.photo_library_rounded, size: 11, color: Colors.white),
        const SizedBox(width: 3),
        Text(
          '$count',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

/// Wide, horizontal pet card for list-style layouts.
class PetListTile extends StatelessWidget {
  const PetListTile({
    super.key,
    required this.pet,
    required this.onTap,
    this.onFavoriteToggle,
    this.isFavorite = false,
    this.trailing,
  });

  final PetModel pet;
  final VoidCallback onTap;
  final VoidCallback? onFavoriteToggle;
  final bool isFavorite;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(AppConstants.radiusMd),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppConstants.radiusMd),
            border: Border.all(color: scheme.outline),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppImage(
                url: pet.image,
                width: 92,
                height: 92,
                borderRadius: BorderRadius.circular(AppConstants.radiusSm + 2),
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
                              letterSpacing: -0.3,
                            ),
                          ),
                        ),
                        if (pet.isVerified)
                          Icon(
                            Icons.verified_rounded,
                            size: 15,
                            color: scheme.secondary,
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${pet.breed} • ${pet.ageLabel} • ${pet.gender}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 5,
                      runSpacing: 5,
                      children: [
                        if (pet.vaccinated)
                          StatusPill(
                            label: 'Vaccinated',
                            icon: Icons.vaccines_rounded,
                            color: AppColors.success,
                            dense: true,
                          ),
                        if (pet.microchipped)
                          StatusPill(
                            label: 'Chipped',
                            icon: Icons.qr_code_2_rounded,
                            dense: true,
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          Helpers.currency(pet.price),
                          style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w800,
                            color: scheme.primary,
                          ),
                        ),
                        Gap.w8,
                        Icon(
                          Icons.location_on_rounded,
                          size: 12,
                          color: scheme.onSurface.withValues(alpha: 0.4),
                        ),
                        Gap.w2,
                        Expanded(
                          child: Text(
                            pet.location,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: scheme.onSurface.withValues(alpha: 0.5),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (trailing != null)
                trailing!
              else if (onFavoriteToggle != null)
                IconActionButton(
                  icon: isFavorite
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  isActive: isFavorite,
                  activeColor: AppColors.danger,
                  foreground: isFavorite ? Colors.white : AppColors.danger,
                  background: scheme.surfaceContainerLow,
                  size: 34,
                  iconSize: 17,
                  onTap: onFavoriteToggle!,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
